import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../../../domain/models/assessment_draft.dart';
import '../../../../domain/models/assessment_rubric.dart';
import '../../../../domain/repositories/assessment_rubric_generator.dart';
import 'assessment_draft_controller.dart';

class AssessmentRubricController extends ChangeNotifier {
  AssessmentRubricController({
    required this.draft,
    required this._generator,
    required this._lessonTitle,
    required this._lessonSteps,
  });

  final AssessmentDraftController draft;
  final AssessmentRubricGenerator? _generator;
  final String _lessonTitle;
  final List<String> _lessonSteps;
  final _queue = Queue<AssessmentQuestion>();
  final _pending = <AssessmentQuestion>{};
  final _errors = <AssessmentQuestion, String>{};
  var _running = 0;
  var _disposed = false;

  bool get canUseAI => _generator != null;
  bool isDrafting(AssessmentQuestion question) => _pending.contains(question);
  String? errorFor(AssessmentQuestion question) => _errors[question];

  void prepareMissing() {
    final questions = draft.draft.questions;
    _errors.removeWhere((question, _) => !questions.contains(question));
    for (final question in questions) {
      if (question.rubric == null && !_errors.containsKey(question)) {
        request(question);
      }
    }
  }

  void request(AssessmentQuestion question) {
    if (!canUseAI || !_pending.add(question)) return;
    _errors.remove(question);
    _queue.add(question);
    notifyListeners();
    _runQueued();
  }

  void _runQueued() {
    while (!_disposed && _running < 2 && _queue.isNotEmpty) {
      final question = _queue.removeFirst();
      if (!draft.draft.questions.contains(question)) {
        _pending.remove(question);
        continue;
      }
      _running++;
      unawaited(_generate(question));
    }
  }

  Future<void> _generate(AssessmentQuestion question) async {
    try {
      final rubric = await _generator!.generate(
        question: question,
        lessonTitle: _lessonTitle,
        lessonSteps: _lessonSteps,
      );
      if (!_disposed) {
        // A teacher action may have replaced or removed the original question.
        final index = draft.draft.questions.indexOf(question);
        if (index >= 0) update(index, (_) => rubric);
      }
    } on RubricGenerationFailure catch (error) {
      _errors[question] = error.message;
    } catch (_) {
      _errors[question] =
          'Could not reach AI. Retry or enter an answer manually.';
    } finally {
      _pending.remove(question);
      _running--;
      if (!_disposed) {
        notifyListeners();
        _runQueued();
      }
    }
  }

  void update(int index, QuestionRubric Function(QuestionRubric) edit) {
    final assessment = draft.draft;
    final questions = [...assessment.questions];
    final question = questions[index];
    questions[index] = question.withRubric(
      edit(question.rubric ?? const QuestionRubric()),
    );
    _errors.remove(question);
    draft.update(assessment.copyWith(questions: questions));
  }

  Future<QuestionRubric> revise(
    AssessmentQuestion question,
    String instruction,
  ) => _generator!.generate(
    question: question,
    lessonTitle: _lessonTitle,
    lessonSteps: _lessonSteps,
    teacherRequest: instruction,
  );

  void remove(int index) {
    final assessment = draft.draft;
    final questions = [...assessment.questions];
    _errors.remove(questions.removeAt(index));
    draft.update(assessment.copyWith(questions: questions));
  }

  @override
  void dispose() {
    _disposed = true;
    _queue.clear();
    super.dispose();
  }
}

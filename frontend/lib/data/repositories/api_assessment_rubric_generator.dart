import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/assessment_draft.dart';
import '../../domain/models/assessment_rubric.dart';
import '../../domain/repositories/assessment_rubric_generator.dart';

class ApiAssessmentRubricGenerator implements AssessmentRubricGenerator {
  const ApiAssessmentRubricGenerator(this._base, this._client);

  final Uri _base;
  final http.Client _client;

  @override
  Future<QuestionRubric> generate({
    required AssessmentQuestion question,
    required String lessonTitle,
    required List<String> lessonSteps,
    String? teacherRequest,
  }) async {
    final response = await _client
        .post(
          _base.resolve('/v1/assessments/rubric/draft'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'lesson': {'title': lessonTitle, 'steps': lessonSteps},
            'question': question.toJson()..remove('rubric'),
            'teacher_request': ?teacherRequest,
            if (teacherRequest != null && question.rubric != null)
              'previous': question.rubric!.toJson(forApi: true),
          }),
        )
        .timeout(const Duration(seconds: 70));

    if (response.statusCode == 503) {
      throw const RubricGenerationFailure(
        'OpenAI is not configured on the backend.',
      );
    }
    if (response.statusCode != 200) {
      throw const RubricGenerationFailure(
        'Could not draft an answer. Try again or enter it manually.',
      );
    }
    final json = jsonDecode(utf8.decode(response.bodyBytes));
    if (json is! Map<String, Object?>) {
      throw const FormatException('Invalid rubric response.');
    }
    final rubric = QuestionRubric.fromJson(json);
    final option = rubric.correctOption;
    final options = question.kind == AssessmentQuestionKind.trueFalse
        ? 2
        : question.options.length;
    if ((option != null && (option < 0 || option >= options)) ||
        (rubric.criteria.isNotEmpty &&
            !rubric.matchesQuestionPoints(question.points))) {
      throw const FormatException(
        'Rubric response does not match the question.',
      );
    }
    return rubric.copyWith(approved: false, keptByTeacher: false);
  }
}

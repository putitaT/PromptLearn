import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:promptlearn/domain/models/homework_check.dart';
import 'package:promptlearn/domain/models/homework_submission.dart';
import 'package:promptlearn/domain/repositories/homework_checker.dart';
import 'package:promptlearn/ui/core/theme/app_theme.dart';
import 'package:promptlearn/ui/features/assessment/views/student_homework_view.dart';
import 'package:promptlearn/ui/features/assessment/widgets/homework_notebook.dart';

void main() {
  setUpAll(() async {
    final inter = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter-Variable.ttf'));
    await inter.load();
  });

  testWidgets('Submit reviews every paper and opens the scored progress view', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1366, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final notebook = HomeworkNotebook();
    for (var index = 0; index < HomeworkNotebook.questions.length; index++) {
      notebook.activeIndex = index;
      notebook.draft.addInk(PaperTool.pen, const [
        Offset(0.2, 0.3),
        Offset(0.4, 0.3),
      ]);
    }
    notebook.activeIndex = 0;
    final checker = _SubmissionChecker();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StudentHomeworkView(
            notebook: notebook,
            checker: checker,
            onBack: () {},
          ),
        ),
      ),
    );
    final submit = find.widgetWithText(FilledButton, 'Submit');
    final onSubmit = tester.widget<FilledButton>(submit).onPressed!;
    await tester.runAsync(() async {
      checker.completed = Completer<void>();
      onSubmit();
      await checker.completed.future.timeout(const Duration(seconds: 8));
    });
    await tester.pumpAndSettle();
    expect(checker.checked, {
      for (final question in HomeworkNotebook.questions) question.id,
    });
    expect(checker.submittedIDs, [
      for (final question in HomeworkNotebook.questions)
        'review-${question.id}',
    ]);
    expect(notebook.submitted, isTrue);
    expect(find.text('My progress · Unit 3'), findsOneWidget);
    expect(find.text('2 / 4 pts'), findsOneWidget);
    expect(find.text('Your answer'), findsOneWidget);
    expect(find.text('Mistakes to watch'), findsOneWidget);
    expect(find.text('Solve for x: x + 7 = 22.').hitTestable(), findsOneWidget);
    expect(find.text('How could you keep both sides equal?'), findsNothing);
    for (final (index, question) in HomeworkNotebook.questions.indexed) {
      final row = find.text(question.prompt);
      final work = find.text(_recognizedWork[index]);
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'opening Q${index + 1}');
      await tester.ensureVisible(work);
      expect(work.hitTestable(), findsOneWidget);
      expect(find.text('Recognized work').hitTestable(), findsOneWidget);
      expect(find.text('Reviewed.').hitTestable(), findsOneWidget);
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(work, findsNothing);
    }
    await tester.tap(find.text('Review mistakes'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('22 + 7 · 1', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.text('How could you keep both sides equal?').hitTestable(),
      findsOneWidget,
    );
    expect(find.text('Solve for x: x + 7 = 22.').hitTestable(), findsNothing);
    expect(find.text('2 / 4 pts').hitTestable(), findsOneWidget);
    await tester.binding.setSurfaceSize(const Size(1024, 600));
    await tester.pumpAndSettle();
    expect(
      find.text('How could you keep both sides equal?').hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.text('Your answer'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Solve for x: x + 7 = 22.'));
    expect(find.text('Solve for x: x + 7 = 22.').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(const Size(1366, 1024));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back to homework'));
    await tester.pumpAndSettle();
    expect(find.text('View results'), findsOneWidget);
    await tester.tap(find.text('View results'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 4 pts'), findsOneWidget);
  });
}

const _recognizedWork = [
  'x² · x³\nx^(2 + 3) = x⁵',
  '(a³)²\na^(3 × 2) = a⁶',
  'y⁶ ÷ y²',
  'x + 7 = 22\nx = 22 + 7',
];

class _SubmissionChecker implements HomeworkChecker, HomeworkSubmitter {
  final checked = <String>{};
  List<String>? submittedIDs;
  late Completer<void> completed;

  @override
  Future<HomeworkFeedback> check(HomeworkCheckRequest request) async {
    expect(request.paperPng.take(4), [137, 80, 78, 71]);
    expect(checked.add(request.question.id), isTrue);
    return HomeworkFeedback(
      'Reviewed.',
      reviewId: 'review-${request.question.id}',
    );
  }

  @override
  Future<HomeworkSubmissionReport> submit(
    String assignmentId,
    List<String> reviewIds,
  ) async {
    expect(assignmentId, HomeworkNotebook.assignmentId);
    submittedIDs = reviewIds;
    completed.complete();
    return HomeworkSubmissionReport(
      id: 'result',
      points: 2,
      maximum: 4,
      pending: 1,
      questions: [
        for (final (index, question) in HomeworkNotebook.questions.indexed)
          HomeworkSubmittedQuestion(
            position: index + 1,
            prompt: question.prompt,
            work: [
              r'x² \cdot x³'
                  '\nx^(2 + 3) = x⁵',
              '(a³)²\n'
                  r'a^(3 \times 2) = a⁶',
              r'y⁶ \div y²',
              _recognizedWork[3],
            ][index],
            status: index == 3
                ? HomeworkReviewStatus.needsRevision
                : index == 2
                ? HomeworkReviewStatus.unreadable
                : HomeworkReviewStatus.correct,
            message: 'Reviewed.',
            maximum: 1,
            points: index == 3
                ? 0
                : index == 2
                ? null
                : 1,
          ),
      ],
      mistakes: const [
        HomeworkMistake(
          position: 4,
          kind: 'equivalence',
          work: r'x = 22 + 7 \cdot 1',
          observation: 'Compare this line with the one before it.',
          hint: 'How could you keep both sides equal?',
        ),
      ],
    );
  }
}

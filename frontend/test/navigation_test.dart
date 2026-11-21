import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:promptlearn/app/prompt_learn_app.dart';
import 'package:promptlearn/domain/models/assessment_draft.dart';
import 'package:promptlearn/domain/models/assessment_rubric.dart';
import 'package:promptlearn/domain/models/user_role.dart';
import 'package:promptlearn/domain/repositories/assessment_draft_repository.dart';
import 'package:promptlearn/domain/repositories/assessment_rubric_generator.dart';
import 'package:promptlearn/domain/repositories/role_repository.dart';
import 'package:promptlearn/domain/services/class_recording_service.dart';
import 'package:promptlearn/ui/features/home/views/student_home_view.dart';
import 'package:promptlearn/ui/features/home/views/teacher_home_view.dart';
import 'package:promptlearn/ui/features/home/widgets/home_header.dart';
import 'package:promptlearn/ui/features/syllabus/models/syllabus_schedule.dart';
import 'package:promptlearn/ui/features/syllabus/views/syllabus_editor_view.dart';
import 'package:promptlearn/ui/features/syllabus/views/teacher_syllabus_dialog.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  setUpAll(() async {
    final inter = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter-Variable.ttf'));
    await inter.load();
  });

  testWidgets('The app uses the PromptLearn typography and palette', (
    tester,
  ) async {
    await _openApp(tester, _MemoryRoleRepository(UserRole.teacher));
    final theme = Theme.of(tester.element(find.byType(HomeHeader)));

    expect(theme.textTheme.titleLarge?.fontFamily, 'Inter');
    expect(theme.textTheme.titleLarge?.fontSize, 26);
    expect(theme.textTheme.bodyMedium?.fontSize, 15);
    expect(theme.textTheme.bodySmall?.fontSize, 13);
    expect(theme.colorScheme.primary, const Color(0xFF32A060));
    expect(theme.colorScheme.primaryContainer, const Color(0xFF52C883));
    expect(theme.colorScheme.secondaryContainer, const Color(0xFFAFE6A2));
    expect(theme.colorScheme.tertiaryContainer, const Color(0xFFB8E68C));
    expect(theme.colorScheme.secondary, const Color(0xFF6AC08F));
  });

  for (final size in [
    const Size(1366, 1024),
    const Size(800, 1200),
    const Size(620, 480),
    const Size(360, 640),
    const Size(800, 360),
  ]) {
    testWidgets('Navigation and notifications work at $size', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _openApp(tester, _MemoryRoleRepository(UserRole.student));
      expect(find.textContaining('Alexander P.'), findsOneWidget);
      expect(find.byTooltip('Switch login role'), findsOneWidget);

      final notifications = find.byTooltip('Notifications');
      expect(tester.getSize(notifications), const Size.square(48));
      if (size.width == 1366) {
        expect(tester.getSize(find.byType(HomeHeader)).height, 100);
      }
      await tester.tap(notifications);
      await tester.pumpAndSettle();
      expect(find.text('Welcome to PromptLearn.'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      for (final destination in ['Courses', 'Learning tools', 'Profile']) {
        await tester.tap(find.byTooltip(destination));
        await tester.pumpAndSettle();
        expect(find.text(destination), findsOneWidget);
      }

      await tester.tap(find.byTooltip('Home'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Alexander P.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [
    const Size(1366, 1024),
    const Size(800, 1200),
    const Size(360, 640),
  ]) {
    testWidgets('Teacher dashboard and assessment builder work at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _openApp(tester, _MemoryRoleRepository(UserRole.teacher));

      final startClass = find.text('Start Class');
      final today = find.text('Today');
      final lessonPlan = find.text('Lesson Plan');
      expect(find.text('Needs your attention'), findsOneWidget);
      expect(find.text('Class pulse'), findsOneWidget);
      expect(find.text('My syllabus'), findsOneWidget);

      if (size.width == 1366) {
        expect(tester.getSize(find.byType(HomeHeader)).height, 100);
        expect(
          tester.getSize(find.byTooltip('Notifications')),
          const Size.square(48),
        );
        expect(tester.widget<Text>(today).style?.fontSize, 16);
        expect(tester.widget<Text>(startClass).style?.fontSize, 14);

        final dashboard = find.descendant(
          of: find.byType(TeacherHomeView),
          matching: find.byType(Scrollable),
        );
        final position = tester.state<ScrollableState>(dashboard).position;
        expect(position.maxScrollExtent, 0);
        expect(find.text('Create syllabus').hitTestable(), findsOneWidget);
        expect(
          tester.getTopLeft(today).dx,
          greaterThan(tester.getTopLeft(startClass).dx),
        );
        expect(
          tester.getTopLeft(today).dy,
          lessThan(tester.getTopLeft(startClass).dy),
        );
      } else {
        expect(
          tester.getTopLeft(today).dy,
          greaterThan(tester.getTopLeft(startClass).dy),
        );
      }

      await tester.ensureVisible(lessonPlan);
      await tester.tap(lessonPlan);
      await tester.pumpAndSettle();
      expect(find.text('Create Assessment'), findsOneWidget);
      expect(find.text('Write in app').hitTestable(), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(lessonPlan.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Assessment fits the tablet header and Settings at 1164 dp', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1164, 777));
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 32, bottom: 16);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    final repository = _MemoryAssessmentDraftRepository()
      ..stored = const AssessmentDraft(
        questions: [
          AssessmentQuestion(
            kind: AssessmentQuestionKind.shortAnswer,
            prompt: 'Simplify the expression.',
            points: 1,
          ),
          AssessmentQuestion(
            kind: AssessmentQuestionKind.showWork,
            prompt: 'Explain each step.',
            points: 1,
          ),
        ],
      );

    await _openApp(
      tester,
      _MemoryRoleRepository(UserRole.teacher),
      assessment: repository,
    );
    await tester.tap(find.text('Lesson Plan'));
    await tester.pumpAndSettle();

    final preview = tester.getCenter(find.text('Preview as student'));
    final rubric = tester.getCenter(find.text('Next: Scoring rubric'));
    expect(preview.dy, closeTo(rubric.dy, 1));
    expect(preview.dx, lessThan(rubric.dx));
    expect(find.text('Shuffle question order').hitTestable(), findsOneWidget);

    final header = tester.getTopLeft(find.text('Create Assessment'));
    await tester.drag(find.text('Questions'), const Offset(0, -250));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Create Assessment')), header);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Teacher drafts, edits, approves and removes rubric questions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1164, 777));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _MemoryAssessmentDraftRepository()
      ..stored = const AssessmentDraft(
        questions: [
          AssessmentQuestion(
            kind: AssessmentQuestionKind.showWork,
            prompt: 'Simplify (x²)(x⁵). Show each step.',
            points: 1,
          ),
          AssessmentQuestion(
            kind: AssessmentQuestionKind.multipleChoice,
            prompt: 'Which organelle performs photosynthesis?',
            points: 1,
            options: ['Nucleus', 'Chloroplast'],
          ),
        ],
      );
    final generator = _FixtureRubricGenerator();
    await _openApp(
      tester,
      _MemoryRoleRepository(UserRole.teacher),
      assessment: repository,
      rubricGenerator: generator,
    );
    await tester.tap(find.text('Lesson Plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next: Scoring rubric'));
    await tester.pumpAndSettle();

    expect(generator.requests, hasLength(2));
    expect(
      generator.requests.every((title) => title.contains('powers')),
      isTrue,
    );
    expect(find.textContaining('Multiplied exponents'), findsOneWidget);
    final title = find.textContaining('Scoring rubric ·');
    final headerPosition = tester.getTopLeft(title);
    final approve = find.widgetWithText(FilledButton, 'Approve answer');

    await tester.enterText(
      find.byKey(const ValueKey('Criterion 1 full points')),
      '0.75',
    );
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(approve).onPressed, isNull);
    expect(find.textContaining('Full credit must add up'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('Criterion 2 full points')),
      '0.25',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(approve);
    await tester.tap(approve);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(title), headerPosition);
    expect(repository.stored!.questions.first.rubric!.approved, isTrue);
    expect(
      repository.stored!.questions.first.rubric!.criteria.first.fullScore,
      '0.75',
    );

    await tester.tap(find.text('Back to questions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next: Scoring rubric'));
    await tester.pumpAndSettle();
    expect(find.text('Answer approved'), findsOneWidget);
    expect(generator.requests, hasLength(2));

    await tester.tap(find.text('Multiple choice'));
    await tester.pumpAndSettle();
    expect(find.textContaining('photosynthesis is outside'), findsOneWidget);
    final remove = find.text('Remove question');
    await tester.ensureVisible(remove);
    await tester.tap(remove);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Remove question'),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.stored!.questions, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Teacher saves and previews all four assessment question types', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1366, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final role = _MemoryRoleRepository(UserRole.teacher);
    final draftRepository = _MemoryAssessmentDraftRepository();
    await _openApp(tester, role, assessment: draftRepository);

    Future<void> tap(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    Future<void> type(String label, String value) async {
      final field = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == label,
      );
      await tester.ensureVisible(field);
      await tester.enterText(field, value);
      await tester.pumpAndSettle();
    }

    Future<void> addQuestion(
      String kind,
      String prompt, {
      int points = 1,
      List<String> options = const [],
      bool checkValidation = false,
    }) async {
      await tap(find.text('Write in app'));
      await tap(
        find.descendant(
          of: find.byType(SimpleDialog),
          matching: find.text(kind),
        ),
      );
      final save = find.text('Save question');
      if (checkValidation) {
        await tap(save);
        expect(find.text('Enter a question.'), findsOneWidget);
      }
      await type(kind == 'True or false' ? 'Statement' : 'Question', prompt);
      await type('Points', points.toString());
      for (var index = 0; index < options.length; index++) {
        await type('Option ${String.fromCharCode(65 + index)}', options[index]);
      }
      await tap(save);
      expect(find.text(prompt), findsOneWidget);
    }

    await tap(find.text('Lesson Plan'));
    expect(find.text('0 questions · 0 pts'), findsNWidgets(2));
    await tap(find.text('Homework'));
    expect(find.text('Homework · Exponents'), findsOneWidget);
    await addQuestion(
      'Short answer',
      'Write the result as a single power.',
      checkValidation: true,
    );
    await addQuestion(
      'Show work',
      'Expand each factor and show your steps.',
      points: 3,
    );
    await addQuestion(
      'Multiple choice',
      'Which is equal to 3⁴ × 3²?',
      points: 2,
      options: ['3⁸', '3⁶'],
    );
    await addQuestion(
      'True or false',
      'Powers with the same base have the same value.',
    );
    expect(find.text('4 questions · 7 pts'), findsNWidgets(2));
    expect(find.text('Draft · auto-saved'), findsOneWidget);
    expect(
      draftRepository.stored?.questions.map((question) => question.kind),
      AssessmentQuestionKind.values,
    );

    await tap(find.byTooltip('Question 2 actions'));
    await tap(find.text('Move up'));
    expect(
      draftRepository.stored?.questions.first.kind,
      AssessmentQuestionKind.showWork,
    );

    await tap(find.text('Preview as student'));
    final preview = find.byType(AlertDialog);
    expect(
      find.descendant(of: preview, matching: find.text('True')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: preview, matching: find.text('3⁶')),
      findsOneWidget,
    );
    expect(find.byType(ChoiceChip), findsNWidgets(4));
    await tap(find.text('Close preview'));

    await tester.pumpWidget(const SizedBox.shrink());
    await _openApp(tester, role, assessment: draftRepository);
    await tap(find.text('Lesson Plan'));
    expect(find.text('Homework · Exponents'), findsOneWidget);
    expect(find.text('4 questions · 7 pts'), findsNWidgets(2));
    expect(find.text('Which is equal to 3⁴ × 3²?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(1366, 1024), const Size(360, 640)]) {
    testWidgets('Teacher can configure and teach without recording at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _openApp(tester, _MemoryRoleRepository(UserRole.teacher));

      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await tap(find.text('Start Class'));

      final title = find.text('M.1/1 · Period 25').hitTestable();
      final position = tester.getTopLeft(title);
      final options = find.text('Before you start');
      final plan = find.text('This period’s plan');
      expect(find.text('Start teaching & recording'), findsOneWidget);
      if (size.width == 1366) {
        expect(tester.getTopLeft(plan).dy, tester.getTopLeft(options).dy);
        expect(
          tester.getTopLeft(plan).dx,
          greaterThan(tester.getTopLeft(options).dx),
        );
      } else {
        expect(
          tester.getTopLeft(plan).dy,
          greaterThan(tester.getTopLeft(options).dy),
        );
      }

      await tap(find.text('Open lesson plan'));
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Warm-up'),
        ),
        findsOneWidget,
      );
      await tap(find.text('Close'));
      await tap(find.text('Whole screen'));
      await tap(find.byType(Switch).first);
      await tap(find.text('Test mic & screen'));
      expect(
        find.textContaining('Selected source: Whole screen'),
        findsOneWidget,
      );
      await tap(find.text('Close'));
      expect(tester.getTopLeft(title), position);

      await tap(find.text('Start teaching'));
      expect(find.text('Teaching · M.1/1'), findsOneWidget);
      expect(find.text('Recording off'), findsOneWidget);
      expect(find.textContaining('slide 1 / 14'), findsOneWidget);
      await tap(find.byTooltip('Next slide'));
      expect(find.textContaining('slide 2 / 14'), findsOneWidget);
      expect(
        find.text('Invite one student to read the expression aloud.'),
        findsOneWidget,
      );
      await tap(find.byTooltip('Previous slide'));
      expect(find.textContaining('slide 1 / 14'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('End this class?'), findsOneWidget);
      await tap(find.text('Keep teaching'));
      await tap(find.text('Stop & end class'));
      expect(find.text('Start Class').hitTestable(), findsOneWidget);
      await tap(find.text('Start Class'));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Start Class').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Ending a recording opens the saved file and supports playback and seeking',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1366, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final recording = _FakeClassRecordingService();
      addTearDown(recording.dispose);
      final originalPlayer = VideoPlayerPlatform.instance;
      final video = _FakeVideoPlayerPlatform();
      VideoPlayerPlatform.instance = video;
      addTearDown(() => VideoPlayerPlatform.instance = originalPlayer);
      await _openApp(
        tester,
        _MemoryRoleRepository(UserRole.teacher),
        recording: recording,
      );

      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await tap(find.text('Start Class'));
      await tap(find.text('Whole screen'));
      recording.cancelNextStart = true;
      await tap(find.text('Start teaching & recording'));
      expect(find.text('Screen sharing was cancelled.'), findsOneWidget);
      expect(find.text('Start teaching & recording'), findsOneWidget);

      await tap(find.text('Start teaching & recording'));
      expect(recording.source, RecordingSource.screen);
      expect(find.text('Starting recording…'), findsOneWidget);
      expect(find.text('Teaching · M.1/1'), findsNothing);

      recording.emit(
        const RecordingStatus(
          phase: RecordingPhase.recording,
          source: RecordingSource.screen,
          elapsed: Duration(seconds: 3),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('REC  00:00:03'), findsOneWidget);

      await tap(find.byTooltip('Home'));
      expect(find.text('Teaching · M.1/1'), findsOneWidget);

      await tap(find.text('Stop & end class'));
      expect(recording.stopCount, 1);
      expect(find.text('Saving recording…'), findsOneWidget);

      recording.emit(
        const RecordingStatus(
          phase: RecordingPhase.saved,
          source: RecordingSource.screen,
          clip: RecordingClip(
            path: '/recordings/class.mp4',
            name: 'class.mp4',
            sizeBytes: 1024,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Class ended · M.1/1'), findsOneWidget);
      expect(find.text('Recorded 00:46'), findsOneWidget);
      expect(video.source?.sourceType, DataSourceType.file);
      expect(
        Uri.parse(video.source!.uri!).toFilePath(),
        '/recordings/class.mp4',
      );
      expect(
        tester
            .widget<FilledButton>(
              find.ancestor(
                of: find.text('Publish Lesson & Assignment'),
                matching: find.byWidgetPredicate(
                  (widget) => widget is FilledButton,
                ),
              ),
            )
            .onPressed,
        isNull,
      );

      await tap(find.byTooltip('Play clip'));
      expect(video.playCount, 1);
      final slider = tester.widget<Slider>(find.byType(Slider));
      slider.onChanged!(15000);
      slider.onChangeEnd!(15000);
      await tester.pumpAndSettle();
      expect(video.position, const Duration(seconds: 15));

      await tester.binding.setSurfaceSize(const Size(360, 640));
      await tester.pumpAndSettle();
      expect(video.createCount, 1);
      expect(find.text('00:15 / 00:46'), findsOneWidget);

      await tap(find.byTooltip('Pause clip'));
      await tap(find.byTooltip('Back to Teacher Home'));
      expect(find.text('Class ended · M.1/1'), findsNothing);
      expect(find.text('Start Class').hitTestable(), findsOneWidget);
      await tap(find.text('Start Class'));
      await tap(find.text('Last recording'));
      expect(find.text('Class ended · M.1/1'), findsOneWidget);
      expect(video.createCount, 2);
      await tap(find.byTooltip('Back to Teacher Home'));
      expect(find.text('Class ended · M.1/1'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Teacher Home keeps the lesson summary alongside on a tablet', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1164, 777));
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 32, bottom: 16);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    await _openApp(tester, _MemoryRoleRepository(UserRole.teacher));

    final startClass = find.text('Start Class');
    final today = find.text('Today');
    final flow = find.text('Lesson flow · 50 min');
    expect(
      tester.getTopLeft(flow).dx,
      greaterThan(tester.getTopLeft(startClass).dx),
    );
    expect(
      tester.getTopLeft(flow).dy,
      lessThan(tester.getTopLeft(startClass).dy),
    );
    expect(
      tester.getTopLeft(today).dx,
      greaterThan(tester.getTopLeft(flow).dx),
    );
    expect(find.text('Needs your attention').hitTestable(), findsOneWidget);

    await tester.ensureVisible(find.text('Create syllabus'));
    await tester.pumpAndSettle();
    expect(find.text('Create syllabus').hitTestable(), findsOneWidget);
    expect(tester.getSize(find.byType(HomeHeader)).height, 100);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(1366, 768), const Size(360, 640)]) {
    testWidgets('Teacher header stays visible when scrolling at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _openApp(tester, _MemoryRoleRepository(UserRole.teacher));

      final header = find.byType(HomeHeader);
      final notifications = find.byTooltip('Notifications');
      final navigation = find.byTooltip('Home');
      final cards = find.descendant(
        of: find.byType(TeacherHomeView),
        matching: find.byType(SingleChildScrollView),
      );
      final today = find.text('Today');
      final headerPosition = tester.getTopLeft(header);
      final navPosition = tester.getCenter(navigation);
      final initialTodayY = tester.getTopLeft(today).dy;

      await tester.drag(cards, const Offset(0, -350));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(today).dy, lessThan(initialTodayY));
      expect(tester.getTopLeft(header), headerPosition);
      expect(tester.getCenter(navigation), navPosition);

      await tester.tap(notifications);
      await tester.pumpAndSettle();
      expect(find.text('Welcome to PromptLearn.'), findsOneWidget);
    });
  }

  for (final size in [const Size(1366, 1024), const Size(360, 640)]) {
    testWidgets('See all opens the syllabus catalog at $size', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _openApp(tester, _MemoryRoleRepository(UserRole.teacher));

      final seeAll = find.text('See all');
      await tester.ensureVisible(seeAll);
      await tester.tap(seeAll);
      await tester.pumpAndSettle();

      final modal = find.byType(TeacherSyllabusDialog);
      Finder inModal(String label) =>
          find.descendant(of: modal, matching: find.text(label));

      expect(inModal('My Syllabus'), findsOneWidget);
      expect(inModal('Published'), findsNWidgets(3));
      expect(inModal('Draft · step 3 of 6'), findsOneWidget);
      expect(inModal('3 classes · 94 students'), findsOneWidget);
      expect(inModal('Math 102'), findsOneWidget);

      final math101 = tester.getTopLeft(inModal('Math 101'));
      final math201 = tester.getTopLeft(inModal('Math 201'));
      final math301 = tester.getTopLeft(inModal('Math 301'));
      final math102 = tester.getTopLeft(inModal('Math 102'));
      if (size.width == 1366) {
        expect(math201.dy, math101.dy);
        expect(math301.dy, math101.dy);
        expect(math201.dx, greaterThan(math101.dx));
        expect(math301.dx, greaterThan(math201.dx));
        expect(math102.dy, greaterThan(math101.dy));
      } else {
        expect(math201.dx, math101.dx);
        expect(math201.dy, greaterThan(math101.dy));
      }

      final create = inModal('Create syllabus');
      await tester.ensureVisible(create);
      await tester.pumpAndSettle();
      await tester.tap(create);
      await tester.pumpAndSettle();
      final editor = find.byType(SyllabusEditorView);
      final courseName = find.byType(TextFormField).first;
      expect(editor, findsOneWidget);
      expect(find.text('New course: basics & timetable'), findsOneWidget);
      final periods = find.byKey(const ValueKey('available-teaching-periods'));
      expect(tester.widget<Text>(periods).data, '54');

      await tester.enterText(courseName, 'Grade 7 Mathematics');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      final slot = find.byKey(const ValueKey('slot-1-2'));
      await tester.ensureVisible(slot);
      await tester.tap(slot);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(periods).data, '35');

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Learning standards'), findsOneWidget);
      expect(find.text('4 indicators selected'), findsOneWidget);
      final exponent = find.byKey(const ValueKey('ค 1.1 ม.1/2'));
      await tester.ensureVisible(exponent);
      await tester.tap(exponent);
      await tester.pumpAndSettle();
      expect(find.text('3 indicators selected'), findsOneWidget);

      expect(tester.widget<CheckboxListTile>(exponent).value, isFalse);
      final disclosure = find.text('Additional indicators');
      await tester.ensureVisible(disclosure);
      await tester.tap(disclosure);
      await tester.pumpAndSettle();
      final extra = find.byKey(const ValueKey('ค 1.3 ม.1/1'));
      await tester.ensureVisible(extra);
      expect(
        tester.getTopLeft(extra).dy,
        greaterThan(tester.getTopLeft(disclosure).dy),
      );
      await tester.tap(extra);
      await tester.pumpAndSettle();
      expect(extra, findsOneWidget);
      expect(tester.widget<CheckboxListTile>(extra).value, isTrue);
      expect(
        tester.getTopLeft(extra).dy,
        greaterThan(tester.getTopLeft(disclosure).dy),
      );
      expect(tester.widget<CheckboxListTile>(exponent).value, isFalse);
      expect(find.text('4 indicators selected'), findsOneWidget);

      final chooseBook = find.text('Choose a textbook');
      await tester.ensureVisible(chooseBook);
      await tester.tap(chooseBook);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mathematics M.1 Foundations'));
      await tester.pumpAndSettle();
      expect(find.text('Mathematics M.1 Foundations'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Back'));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(periods).data, '35');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('4 indicators selected'), findsOneWidget);
      expect(find.text('Mathematics M.1 Foundations'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Period budget'), findsOneWidget);
      expect(find.text('of 35 periods planned'), findsOneWidget);
      expect(find.text('Working with integers'), findsOneWidget);
      expect(find.text('Powers and exponents'), findsNothing);
      final firstUnit = find.byKey(const ValueKey('unit-card-1'));
      final secondUnit = find.byKey(const ValueKey('unit-card-2'));
      Color borderColor(Finder finder) =>
          ((tester.widget<Container>(finder).decoration! as BoxDecoration)
                      .border!
                  as Border)
              .top
              .color;
      final firstToggle = find.byTooltip('Show lessons in unit 1');
      await tester.ensureVisible(firstToggle);
      await tester.tap(firstToggle);
      await tester.pumpAndSettle();
      expect(borderColor(firstUnit), const Color(0xFF4ABE7A));
      expect(find.text('1.1 Positive and negative integers'), findsOneWidget);
      final secondToggle = find.byTooltip('Show lessons in unit 2');
      await tester.ensureVisible(secondToggle);
      await tester.tap(secondToggle);
      await tester.pumpAndSettle();
      expect(borderColor(secondUnit), const Color(0xFF0F6E6E));
      expect(find.text('1.1 Positive and negative integers'), findsNothing);
      expect(borderColor(firstUnit), const Color(0xFFE6ECE8));

      final budgetBar = find.byKey(const ValueKey('period-budget-bar'));
      final segments = find.descendant(
        of: budgetBar,
        matching: find.byType(ColoredBox),
      );
      expect(segments, findsWidgets);
      expect(tester.getSize(segments.first).height, 14);
      expect(tester.getSize(segments.first).width, greaterThan(0));
      final closeSecond = find.byTooltip('Hide lessons in unit 2');
      await tester.ensureVisible(closeSecond);
      await tester.tap(closeSecond);
      await tester.pumpAndSettle();

      final handle = find.byTooltip('Drag to reorder unit 1');
      await tester.ensureVisible(handle);
      final start = tester.getCenter(handle);
      expect(handle.hitTestable(), findsOneWidget);
      final destination = Offset(start.dx, tester.getCenter(secondUnit).dy);
      final drag = await tester.startGesture(start);
      await tester.pump(const Duration(milliseconds: 600));
      await drag.moveTo(destination);
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(secondUnit).dy,
        lessThan(tester.getTopLeft(firstUnit).dy),
      );
      expect(find.text('Unit 1 · Constructing figures'), findsOneWidget);
      final movedToggle = find.byTooltip('Show lessons in unit 1');
      await tester.ensureVisible(movedToggle);
      await tester.tap(movedToggle);
      await tester.pumpAndSettle();
      expect(borderColor(secondUnit), const Color(0xFF0F6E6E));

      await tester.tap(find.byTooltip('Back to teacher home'));
      await tester.pumpAndSettle();
      expect(editor, findsNothing);
      expect(modal, findsNothing);
      expect(seeAll, findsOneWidget);

      final createFromHome = find.text('Create syllabus');
      await tester.ensureVisible(createFromHome);
      await tester.tap(createFromHome);
      await tester.pumpAndSettle();
      expect(editor, findsOneWidget);
      expect(find.text('Grade 7 Mathematics'), findsOneWidget);
      expect(tester.widget<Text>(periods).data, '35');
      await tester.tap(find.byTooltip('Back to teacher home'));
      await tester.pumpAndSettle();
      expect(editor, findsNothing);
      expect(createFromHome, findsOneWidget);
    });
  }

  for (final size in [const Size(1366, 1024), const Size(360, 640)]) {
    testWidgets(
      'Assessment updates the score split and keeps the draft at $size',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await _openApp(tester, _MemoryRoleRepository(UserRole.teacher));

        final create = find.text('Create syllabus');
        await tester.ensureVisible(create);
        await tester.tap(create);
        await tester.pumpAndSettle();
        for (var step = 0; step < 3; step++) {
          await tester.tap(find.text('Continue'));
          await tester.pumpAndSettle();
        }

        expect(find.text('Score split'), findsOneWidget);
        expect(find.text('5 quizzes × 5 points'), findsOneWidget);
        expect(find.text('100 / 100'), findsOneWidget);
        final scoreBar = find.byKey(const ValueKey('assessment-score-bar'));
        final segments = find.descendant(
          of: scoreBar,
          matching: find.byType(ColoredBox),
        );
        expect(segments, findsNWidgets(5));
        expect(tester.getSize(segments.first).height, 24);

        final quizzes = find.byKey(const ValueKey('assessment-quizzes'));
        await tester.ensureVisible(quizzes);
        await tester.enterText(quizzes, '20');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(find.text('95 / 100'), findsOneWidget);
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(
          find.text('Set assessment scores to a total of 100 points.'),
          findsOneWidget,
        );

        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        final split = find.byType(DropdownButtonFormField<int>);
        await tester.ensureVisible(split);
        await tester.tap(split);
        await tester.pumpAndSettle();
        await tester.tap(find.text('60 : 40').last);
        await tester.pumpAndSettle();
        expect(find.text('100 / 100'), findsOneWidget);

        await tester.tap(find.widgetWithText(OutlinedButton, 'Back'));
        await tester.pumpAndSettle();
        expect(find.text('Period budget'), findsOneWidget);
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(find.text('60 : 40'), findsOneWidget);
        expect(find.text('100 / 100'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'Schedule places periods, moves a card and applies the order to another class',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1366, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _openApp(tester, _MemoryRoleRepository(UserRole.teacher));
      await tester.tap(find.text('Create syllabus'));
      await tester.pumpAndSettle();
      expect(find.text('Create Syllabus'), findsOneWidget);
      for (var step = 0; step < 4; step++) {
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(find.text('Create Syllabus'), findsOneWidget);
      }

      expect(find.text('Teaching schedule'), findsOneWidget);
      expect(find.text('All 54 periods placed · 0 left over'), findsOneWidget);
      expect(find.text('Holiday · Queen’s Birthday'), findsOneWidget);
      expect(find.text('Week 19'), findsOneWidget);
      final first = find.byKey(const ValueKey('schedule-slot-0'));
      final second = find.byKey(const ValueKey('schedule-slot-1'));
      Finder orientation(Finder slot) =>
          find.descendant(of: slot, matching: find.text('Orientation'));
      expect(orientation(first), findsOneWidget);
      final drag = await tester.startGesture(tester.getCenter(first));
      await tester.pump(const Duration(milliseconds: 600));
      await drag.moveTo(tester.getCenter(second));
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();
      expect(orientation(second), findsOneWidget);

      await tester.tap(find.text('Apply to all classes'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'M.1/2'));
      await tester.pumpAndSettle();
      expect(find.text('Mon P3'), findsOneWidget);
      expect(orientation(second), findsOneWidget);

      final draft = tester
          .widget<SyllabusEditorView>(find.byType(SyllabusEditorView))
          .draft;
      final ics = scheduleCalendarFile(
        course: draft.courseName,
        room: 'M.1/2',
        slots: draft.scheduleFor(1),
        generatedAt: DateTime.utc(2026, 11, 21),
      );
      expect('BEGIN:VEVENT'.allMatches(ics), hasLength(54));
      expect(ics, contains('DTSTART;VALUE=DATE:20260518'));
      expect(ics, isNot(contains('DTSTART;VALUE=DATE:20260603')));

      await tester.tap(find.text('Regenerate'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Regenerate'));
      await tester.pumpAndSettle();
      expect(orientation(first), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Create Syllabus'), findsOneWidget);
      expect(find.text('Next: learning plans for each period'), findsOneWidget);
      expect(find.text('Generate 54 learning plans'), findsOneWidget);
      final approaches = ['Inquiry-based (IBL)', '5E model', 'CPA', 'Flipped'];
      final cards = [
        for (final approach in approaches)
          tester.getTopLeft(find.widgetWithText(CheckboxListTile, approach)),
      ];
      expect(cards.map((card) => card.dy).toSet(), hasLength(1));
      for (var index = 1; index < cards.length; index++) {
        expect(cards[index].dx, greaterThan(cards[index - 1].dx));
      }
      expect(find.byTooltip('Courses'), findsOneWidget);

      final inquiry = find.widgetWithText(
        CheckboxListTile,
        'Inquiry-based (IBL)',
      );
      final fiveE = find.widgetWithText(CheckboxListTile, '5E model');
      final cpa = find.widgetWithText(CheckboxListTile, 'CPA');
      expect(tester.widget<CheckboxListTile>(inquiry).value, isTrue);
      await tester.ensureVisible(fiveE);
      await tester.tap(fiveE);
      await tester.pumpAndSettle();
      await tester.ensureVisible(cpa);
      await tester.tap(cpa);
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(inquiry).value, isTrue);
      expect(tester.widget<CheckboxListTile>(fiveE).value, isTrue);
      expect(tester.widget<CheckboxListTile>(cpa).value, isTrue);

      final indicatorOption = find.text('Indicator codes');
      await tester.ensureVisible(indicatorOption);
      await tester.tap(indicatorOption);
      await tester.pumpAndSettle();
      final studentPreview = find.text('Preview as a student');
      await tester.ensureVisible(studentPreview);
      await tester.tap(studentPreview);
      await tester.pumpAndSettle();
      expect(find.text('ค 1.1 ม.1/1'), findsOneWidget);
      await tester.tap(find.byTooltip('Close student preview'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(fiveE).value, isTrue);
      expect(tester.widget<CheckboxListTile>(cpa).value, isTrue);

      await tester.tap(find.text('Save as draft'));
      await tester.pumpAndSettle();
      expect(find.byType(SyllabusEditorView), findsNothing);
      expect(draft.teachingApproaches.length, 3);
    },
  );

  for (final size in [const Size(1366, 1024), const Size(360, 640)]) {
    testWidgets('Course details open from Home and My Syllabus at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _openApp(tester, _MemoryRoleRepository(UserRole.teacher));

      final math101 = find.text('Math 101').last;
      await tester.ensureVisible(math101);
      await tester.tap(math101);
      await tester.pumpAndSettle();
      expect(find.text('Teaching Schedule'), findsOneWidget);
      expect(find.text('24 / 54 periods'), findsOneWidget);
      expect(find.text('3.3 Dividing powers'), findsOneWidget);
      final next = find.byTooltip('Next page');
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.text('4.1 Decimals and fractions'), findsOneWidget);

      final search = find.byType(TextField);
      await tester.ensureVisible(search);
      await tester.enterText(search, 'no matching topic');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('No periods match these filters.'), findsOneWidget);

      final assessment = find.text('Assessment');
      await tester.ensureVisible(assessment);
      await tester.tap(assessment);
      await tester.pumpAndSettle();
      expect(find.text('Scored events'), findsOneWidget);
      expect(find.text('Quiz · Unit 3 Exponents (5 pts)'), findsOneWidget);

      await tester.tap(find.byTooltip('Back from course details'));
      await tester.pumpAndSettle();
      final seeAll = find.text('See all');
      await tester.ensureVisible(seeAll);
      await tester.tap(seeAll);
      await tester.pumpAndSettle();

      final math102 = find.text('Math 102');
      await tester.ensureVisible(math102);
      await tester.tap(math102);
      await tester.pumpAndSettle();
      expect(find.text('Math 102'), findsOneWidget);
      expect(find.text('2.1 Equivalent ratios'), findsNWidgets(2));
      expect(find.text('3.3 Dividing powers'), findsNothing);
      await tester.tap(find.byTooltip('Back from course details'));
      await tester.pumpAndSettle();
      expect(find.byType(TeacherSyllabusDialog), findsOneWidget);
    });
  }

  testWidgets('Math homework on Student Home opens the worksheet', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1366, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _openApp(tester, _MemoryRoleRepository(UserRole.student));

    final assignment = find.text('HW 3.1 · Exponent practice');
    await tester.ensureVisible(assignment);
    await tester.pumpAndSettle();
    await tester.tap(assignment);
    await tester.pumpAndSettle();

    final title = find.text('HW 3.1 · Mathematics');
    expect(title, findsOneWidget);
    expect(find.text('Question 1'), findsOneWidget);
    await tester.tap(find.byTooltip('Next question'));
    await tester.pumpAndSettle();

    await tester.binding.setSurfaceSize(const Size(800, 480));
    await tester.pumpAndSettle();
    final headerOffset = tester.getTopLeft(title);
    final question = find.text('Question 2');
    final questionOffset = tester.getTopLeft(question);
    await tester.drag(question, const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(question).dy, lessThan(questionOffset.dy));
    expect(tester.getTopLeft(title), headerOffset);

    await tester.binding.setSurfaceSize(const Size(1366, 1024));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back to Home'));
    await tester.pumpAndSettle();
    expect(assignment.hitTestable(), findsOneWidget);
    await tester.tap(assignment);
    await tester.pumpAndSettle();
    expect(find.text('Question 2'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(assignment.hitTestable(), findsOneWidget);
  });

  testWidgets('Remembers the login role until the logo is tapped', (
    tester,
  ) async {
    final repository = _MemoryRoleRepository();
    await _openApp(tester, repository);
    expect(find.text('Login as Teacher'), findsOneWidget);
    expect(find.text('Login as Student'), findsOneWidget);

    await tester.tap(find.text('Login as Teacher'));
    await tester.pumpAndSettle();
    expect(find.byType(TeacherHomeView), findsOneWidget);
    expect(find.byType(StudentHomeView), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await _openApp(tester, repository);
    expect(find.byType(TeacherHomeView), findsOneWidget);
    expect(find.byType(StudentHomeView), findsNothing);

    await tester.tap(find.byTooltip('Courses'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch login role'));
    await tester.pumpAndSettle();
    expect(repository.role, isNull);
    expect(find.text('Login as Student'), findsOneWidget);

    await tester.tap(find.text('Login as Student'));
    await tester.pumpAndSettle();
    expect(repository.role, UserRole.student);
    expect(find.byType(StudentHomeView), findsOneWidget);
    expect(find.byType(TeacherHomeView), findsNothing);
    expect(find.textContaining('Alexander P.'), findsOneWidget);
  });
}

Future<void> _openApp(
  WidgetTester tester,
  RoleRepository repository, {
  ClassRecordingService? recording,
  AssessmentDraftRepository? assessment,
  AssessmentRubricGenerator? rubricGenerator,
}) async {
  final drafts = assessment ?? _MemoryAssessmentDraftRepository();
  await tester.pumpWidget(
    recording == null
        ? PromptLearnApp(
            roleRepository: repository,
            assessmentDraftRepository: drafts,
            assessmentRubricGenerator: rubricGenerator,
          )
        : PromptLearnApp(
            roleRepository: repository,
            classRecording: recording,
            assessmentDraftRepository: drafts,
            assessmentRubricGenerator: rubricGenerator,
          ),
  );
  await tester.pumpAndSettle();
}

class _MemoryRoleRepository implements RoleRepository {
  _MemoryRoleRepository([this.role]);

  UserRole? role;

  @override
  Future<UserRole?> load() async => role;

  @override
  Future<void> save(UserRole role) async {
    this.role = role;
  }

  @override
  Future<void> clear() async {
    role = null;
  }
}

class _FakeClassRecordingService implements ClassRecordingService {
  final _updates = StreamController<RecordingStatus>.broadcast();
  RecordingStatus _status = const RecordingStatus();
  RecordingSource? source;
  bool cancelNextStart = false;
  int stopCount = 0;

  @override
  bool get isSupported => true;

  @override
  Stream<RecordingStatus> get updates => _updates.stream;

  void emit(RecordingStatus status) {
    _status = status;
    _updates.add(status);
  }

  @override
  Future<RecordingStatus> status() async => _status;

  @override
  Future<void> start(RecordingSource source) async {
    this.source = source;
    if (cancelNextStart) {
      cancelNextStart = false;
      throw PlatformException(
        code: 'cancelled',
        message: 'Screen sharing was cancelled.',
      );
    }
    emit(RecordingStatus(phase: RecordingPhase.starting, source: source));
  }

  @override
  Future<void> stop() async {
    stopCount++;
    emit(RecordingStatus(phase: RecordingPhase.saving, source: source));
  }

  @override
  Future<List<RecordingClip>> savedClips() async => [?_status.clip];

  Future<void> dispose() => _updates.close();
}

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  final _streams = <int, StreamController<VideoEvent>>{};
  DataSource? source;
  int playCount = 0;
  int createCount = 0;
  Duration position = Duration.zero;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    source = options.dataSource;
    position = Duration.zero;
    return ++createCount;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    final stream = StreamController<VideoEvent>();
    _streams[playerId] = stream;
    stream.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 46),
        size: const Size(1600, 1000),
      ),
    );
    return stream.stream;
  }

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const SizedBox.expand();

  @override
  Future<void> dispose(int playerId) async {
    await _streams.remove(playerId)?.close();
  }

  @override
  Future<void> play(int playerId) async => playCount++;

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<Duration> getPosition(int playerId) async => position;

  @override
  Future<void> seekTo(int playerId, Duration position) async =>
      this.position = position;

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
}

class _MemoryAssessmentDraftRepository implements AssessmentDraftRepository {
  AssessmentDraft? stored;

  @override
  Future<AssessmentDraft?> load() async => stored;

  @override
  Future<void> save(AssessmentDraft draft) async {
    stored = draft;
  }
}

class _FixtureRubricGenerator implements AssessmentRubricGenerator {
  final requests = <String>[];

  @override
  Future<QuestionRubric> generate({
    required AssessmentQuestion question,
    required String lessonTitle,
    required List<String> lessonSteps,
    String? teacherRequest,
  }) async {
    expect(lessonSteps, isNotEmpty);
    requests.add(lessonTitle);
    return question.kind == AssessmentQuestionKind.showWork
        ? const QuestionRubric(
            answer: '(x²)(x⁵) = x²⁺⁵ = x⁷',
            alignment: RubricAlignment.aligned,
            note: 'Split credit between method and final answer.',
            criteria: [
              RubricCriterion(
                name: 'Method',
                fullScore: '0.5',
                partialScore: '0.25',
              ),
              RubricCriterion(name: 'Answer', fullScore: '0.5'),
            ],
            mistakes: [RubricMistake('x¹⁰', 'Multiplied exponents')],
          )
        : const QuestionRubric(
            answer: 'Chloroplast',
            correctOption: 1,
            alignment: RubricAlignment.outOfScope,
            alignmentReason:
                'The topic of photosynthesis is outside this lesson.',
          );
  }
}

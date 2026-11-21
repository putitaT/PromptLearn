import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:promptlearn/app/prompt_learn_app.dart';
import 'package:promptlearn/domain/models/user_role.dart';
import 'package:promptlearn/domain/repositories/role_repository.dart';
import 'package:promptlearn/ui/features/home/views/student_home_view.dart';
import 'package:promptlearn/ui/features/home/views/teacher_home_view.dart';
import 'package:promptlearn/ui/features/home/widgets/home_header.dart';
import 'package:promptlearn/ui/features/syllabus/models/syllabus_schedule.dart';
import 'package:promptlearn/ui/features/syllabus/views/syllabus_editor_view.dart';
import 'package:promptlearn/ui/features/syllabus/views/teacher_syllabus_dialog.dart';

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

  for (final size in [const Size(1366, 1024), const Size(360, 640)]) {
    testWidgets('Teacher dashboard and lesson plan work at $size', (
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
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Warm-up'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

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

Future<void> _openApp(WidgetTester tester, RoleRepository repository) async {
  await tester.pumpWidget(PromptLearnApp(roleRepository: repository));
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

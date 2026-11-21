import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:promptlearn/ui/core/theme/app_theme.dart';
import 'package:promptlearn/ui/features/home/views/student_home_view.dart';

void main() {
  testWidgets(
    'Selected timetable survives resizing and homework details open',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 950));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: StudentHomeView(
              displayName: 'Alexander P.',
              now: DateTime(2026, 7, 15, 10, 15),
              onOpenHomework: () {},
            ),
          ),
        ),
      );
      expect(find.text('● Now'), findsOneWidget);
      expect(find.text('1 of 2 submitted'), findsOneWidget);
      final monday = find.text('Mon');
      await tester.tap(monday);
      await tester.pump();
      expect(find.text('● Now'), findsNothing);
      expect(
        find.text('CSS101 Basic Programming'),
        findsOneWidget,
      ); // Homework list only.
      await tester.binding.setSurfaceSize(const Size(360, 640));
      await tester.pump();
      expect(find.text('● Now'), findsNothing);
      expect(tester.takeException(), isNull);
      final assignment = find.text('Lab report on force and motion');
      final notifications = find.byTooltip('Notifications');
      final headerPosition = tester.getTopLeft(notifications);
      final taskPosition = tester.getTopLeft(assignment);
      await tester.ensureVisible(assignment);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(assignment).dy, lessThan(taskPosition.dy));
      expect(tester.getTopLeft(notifications), headerPosition);
      expect(notifications.hitTestable(), findsOneWidget);
      await tester.tap(assignment);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('Due Tomorrow · 16:00'), findsOneWidget);
    },
  );
}

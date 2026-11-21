import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:promptlearn/app/prompt_learn_app.dart';
import 'package:promptlearn/domain/models/user_role.dart';
import 'package:promptlearn/domain/repositories/assistant_repository.dart';
import 'package:promptlearn/domain/repositories/role_repository.dart';

void main() {
  setUpAll(() async {
    final inter = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter-Variable.ttf'));
    await inter.load();
  });

  testWidgets(
    'Launcher hint is padded, expires after 5 seconds, and chat still opens',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1366, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        PromptLearnApp(roleRepository: _Roles(UserRole.student)),
      );
      await tester.pump();

      final hint = find.text(
        'don’t understand. Ask Prompt Learn!',
        findRichText: true,
      );
      expect(hint, findsOneWidget);
      final bubble = find
          .ancestor(of: hint, matching: find.byType(DecoratedBox))
          .first;
      final textBounds = tester.getRect(hint);
      final bubbleBounds = tester.getRect(bubble);
      expect(textBounds.left - bubbleBounds.left, greaterThanOrEqualTo(16));
      expect(bubbleBounds.right - textBounds.right, greaterThanOrEqualTo(16));

      await tester.pump(const Duration(seconds: 4));
      expect(hint, findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(hint, findsNothing);

      await tester.tap(find.byTooltip('Ask Prompt Learn'));
      await tester.pumpAndSettle();
      expect(find.text('What can I help you with?'), findsOneWidget);
      await tester.tap(find.byTooltip('Close PL AI'));
      await tester.pumpAndSettle();
      expect(hint, findsNothing);
    },
  );

  testWidgets('Dragged launcher stays visible after resizing the screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1366, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      PromptLearnApp(roleRepository: _Roles(UserRole.student)),
    );
    await tester.pumpAndSettle();

    final launcher = find.byTooltip('Ask Prompt Learn');
    await tester.drag(launcher, const Offset(500, 500));
    await tester.pumpAndSettle();
    final tabletPosition = tester.getRect(launcher);
    expect(tabletPosition.right, lessThanOrEqualTo(1366));
    expect(tabletPosition.bottom, lessThanOrEqualTo(1024));
    expect(tabletPosition.right, greaterThan(1302));

    await tester.binding.setSurfaceSize(const Size(360, 640));
    await tester.pumpAndSettle();
    final phonePosition = tester.getRect(launcher);
    expect(phonePosition.right, lessThanOrEqualTo(360));
    expect(phonePosition.bottom, lessThanOrEqualTo(640));
    expect(launcher.hitTestable(), findsOneWidget);

    await tester.drag(launcher, const Offset(-500, -800));
    await tester.pumpAndSettle();
    final movedPosition = tester.getRect(launcher);
    expect(movedPosition.left, greaterThanOrEqualTo(0));
    expect(movedPosition.top, greaterThanOrEqualTo(0));
    expect(movedPosition.center.dx, lessThan(100));
    expect(movedPosition.center.dy, lessThan(100));
    expect(find.text('What can I help you with?'), findsNothing);
  });

  for (final size in [const Size(1366, 1024), const Size(360, 640)]) {
    testWidgets('Create Syllabus keeps the shared launcher position at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        PromptLearnApp(roleRepository: _Roles(UserRole.teacher)),
      );
      await tester.pumpAndSettle();

      final launcher = find.byTooltip('Ask Prompt Learn');
      final homePosition = tester.getCenter(launcher);
      final create = find.text('Create syllabus');
      await tester.ensureVisible(create);
      await tester.pumpAndSettle();
      await tester.tap(create);
      await tester.pumpAndSettle();
      expect(find.text('Create Syllabus'), findsOneWidget);
      expect(tester.getCenter(launcher), homePosition);

      await tester.drag(launcher, const Offset(-140, -200));
      await tester.pumpAndSettle();
      final movedPosition = tester.getCenter(launcher);
      expect(movedPosition, isNot(homePosition));
      for (var step = 0; step < 5; step++) {
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(tester.getCenter(launcher), movedPosition);
      }

      await tester.tap(find.text('Save as draft'));
      await tester.pumpAndSettle();
      expect(find.text('Create Syllabus'), findsNothing);
      expect(tester.getCenter(launcher), movedPosition);
    });
  }

  testWidgets('Assistant spans pushed routes and clears when switching roles', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1366, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final assistant = _Assistant();
    await tester.pumpWidget(
      PromptLearnApp(
        roleRepository: _Roles(UserRole.teacher),
        assistantRepository: assistant,
      ),
    );
    await tester.pumpAndSettle();
    final launcher = find.byTooltip('Ask Prompt Learn');
    final initialPosition = tester.getCenter(launcher);
    final hint = find.text(
      'don’t understand. Ask Prompt Learn!',
      findRichText: true,
    );
    await tester.drag(launcher, const Offset(-1000, -320));
    await tester.pumpAndSettle();
    final movedPosition = tester.getCenter(launcher);
    expect(movedPosition.dx, closeTo(initialPosition.dx - 1000, 1));
    expect(movedPosition.dy, closeTo(initialPosition.dy - 320, 1));
    expect(tester.getTopLeft(hint).dx, greaterThan(movedPosition.dx));
    expect(find.text('What can I help you with?'), findsNothing);

    await tester.tap(launcher);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'Plan a lesson on exponents',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send question'));
    await tester.pumpAndSettle();
    expect(assistant.role, UserRole.teacher);
    expect(assistant.messages.single.text, 'Plan a lesson on exponents');
    expect(find.text('PL AI is thinking…'), findsOneWidget);
    assistant.result.complete('Start by asking students to compare powers.');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close PL AI'));
    await tester.pumpAndSettle();

    final create = find.text('Create syllabus');
    await tester.ensureVisible(create);
    await tester.pumpAndSettle();
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(find.text('Create Syllabus'), findsOneWidget);
    expect(tester.getCenter(launcher), movedPosition);
    await tester.tap(launcher);
    await tester.pumpAndSettle();
    expect(
      find.text('Start by asking students to compare powers.'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Close PL AI'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Switch login role'));
    await tester.pumpAndSettle();
    expect(launcher, findsNothing);
    await tester.tap(find.text('Login as Student'));
    await tester.pumpAndSettle();
    await tester.tap(launcher);
    await tester.pumpAndSettle();
    expect(find.text('What can I help you with?'), findsOneWidget);
    expect(find.text('Plan a lesson on exponents'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A failed question can be retried on a compact homework page', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final assistant = _Assistant();
    await tester.pumpWidget(
      PromptLearnApp(
        roleRepository: _Roles(UserRole.student),
        assistantRepository: assistant,
      ),
    );
    await tester.pumpAndSettle();
    final homework = find.text('HW 3.1 · Exponent practice');
    await tester.ensureVisible(homework);
    await tester.pumpAndSettle();
    await tester.tap(homework);
    await tester.pumpAndSettle();
    expect(find.text('HW 3.1 · Mathematics'), findsOneWidget);

    await tester.tap(find.byTooltip('Ask Prompt Learn'));
    await tester.pumpAndSettle();
    final question = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Ask PL AI here!',
    );
    await tester.enterText(question, 'ขอคำใบ้เรื่องเลขยกกำลัง');
    await tester.pump();
    await tester.tap(find.byTooltip('Send question'));
    assistant.result.completeError(Exception('Network unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('Could not get a reply. Try again.'), findsOneWidget);
    expect(assistant.role, UserRole.student);

    assistant.result = Completer<String>();
    await tester.tap(find.text('Retry'));
    expect(assistant.messages.single.text, 'ขอคำใบ้เรื่องเลขยกกำลัง');
    assistant.result.complete('ลองเขียนแต่ละพจน์ให้อยู่ในรูปการคูณ');
    await tester.pumpAndSettle();
    expect(find.text('ลองเขียนแต่ละพจน์ให้อยู่ในรูปการคูณ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _Assistant implements AssistantRepository {
  var result = Completer<String>();
  late List<AssistantMessage> messages;
  UserRole? role;

  @override
  Future<String> reply(UserRole role, List<AssistantMessage> messages) {
    this.role = role;
    this.messages = messages;
    return result.future;
  }
}

class _Roles implements RoleRepository {
  _Roles(this._role);

  UserRole? _role;

  @override
  Future<UserRole?> load() async => _role;

  @override
  Future<void> clear() async => _role = null;

  @override
  Future<void> save(UserRole role) async => _role = role;
}

import 'dart:convert';
import 'dart:ui' show PointerDeviceKind;

import 'package:chucker_flutter/chucker_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:promptlearn/data/repositories/api_homework_checker.dart';
import 'package:promptlearn/data/repositories/mock_homework_checker.dart';
import 'package:promptlearn/domain/models/homework_check.dart';
import 'package:promptlearn/domain/repositories/homework_checker.dart';
import 'package:promptlearn/ui/features/assessment/views/student_homework_view.dart';
import 'package:promptlearn/ui/features/assessment/widgets/homework_notebook.dart';
import 'package:promptlearn/ui/features/assessment/widgets/homework_paper.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Android debug logs a shortened image and the review JSON', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    ChuckerFlutter.configure(showNotification: false);
    addTearDown(ChuckerFlutter.configure);
    SharedPreferences.setMockInitialValues({});

    const path = '/v1/assignments/hw-3-1/items/q5/reviews';
    final paperPng = Uint8List.fromList(List.generate(48, (index) => index));
    final image = base64Encode(paperPng);
    const result = {
      'review_id': 'saved-review',
      'assignment_id': 'hw-3-1',
      'item_id': 'q5',
      'status': 'correct',
      'message': 'Your work is correct.',
      'issues': [],
    };
    var calls = 0;
    final client = MockClient((actual) async {
      calls++;
      expect(jsonDecode(actual.body), {
        'image_data_url': 'data:image/png;base64,$image',
        'language': 'en',
      });
      return http.Response(
        jsonEncode({...result, 'extra': 'not-reviewed'}),
        200,
      );
    });
    addTearDown(client.close);

    final response =
        await ApiHomeworkChecker(Uri.parse('http://localhost'), client).check(
          HomeworkCheckRequest(
            assignmentId: HomeworkNotebook.assignmentId,
            question: HomeworkNotebook.questions[3],
            paperPng: paperPng,
            imageWidth: 1,
            imageHeight: 1,
          ),
        );
    expect(response.status, HomeworkReviewStatus.correct);
    expect(response.hint, 'Your work is correct.');
    expect(calls, 1);
    final preferences = await SharedPreferences.getInstance();
    final history = preferences.getString('api_responses')!;
    final record = (jsonDecode(history) as List<dynamic>).single;
    expect(record['method'], 'POST');
    expect(record['path'], path);
    expect(record['statusCode'], 200);
    expect(record['request'], {
      'image_data_url': 'data:image/png;base64,${image.substring(0, 24)}...',
      'language': 'en',
    });
    expect(record['body'], result);
    expect(history, isNot(contains(image)));
  });

  test('Each draft keeps its own undo and redo history', () {
    final notebook = HomeworkNotebook()..activeIndex = 0;
    final draft = notebook.draft;
    draft.addInk(PaperTool.pen, const [Offset(0.2, 0.5), Offset(0.8, 0.5)]);

    notebook.activeIndex = 1;
    expect(notebook.draft.content.hasWork, isFalse);
    notebook.activeIndex = 0;
    expect(notebook.draft, same(draft));

    draft.commit(
      draft.content.eraseBetween(
        const Offset(0.5, 0.3),
        const Offset(0.5, 0.7),
      ),
    );
    expect(draft.content.hasWork, isFalse);
    draft.undo();
    expect(draft.content.hasWork, isTrue);
    draft.redo();
    expect(draft.content.hasWork, isFalse);
    draft.undo();
    draft.addInk(PaperTool.highlighter, const [Offset(0.3, 0.3)]);
    expect(draft.canRedo, isFalse);
  });

  test('Mock acknowledges a snapshot without marking student work', () async {
    const checker = MockHomeworkChecker();
    final result = await checker.check(
      HomeworkCheckRequest(
        assignmentId: HomeworkNotebook.assignmentId,
        question: HomeworkNotebook.questions.first,
        paperPng: Uint8List(1),
        imageWidth: 100,
        imageHeight: 100,
      ),
    );

    expect(result.hint, 'Snapshot received.');
    expect(result.region, isNull);
  });

  testWidgets('Previous and Next switch between blank question drafts', (
    tester,
  ) async {
    final notebook = HomeworkNotebook();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudentHomeworkView(
            notebook: notebook,
            checker: _UnusedChecker(),
            onBack: () {},
          ),
        ),
      ),
    );

    IconButton arrow(String label) => tester.widget<IconButton>(
      find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == label,
      ),
    );

    ColorFilter? toolColor(String label) => tester
        .widget<SvgPicture>(
          find.descendant(
            of: find.byTooltip(label),
            matching: find.byType(SvgPicture),
          ),
        )
        .colorFilter;
    const selectedColor = ColorFilter.mode(Color(0xFF206D50), BlendMode.srcIn);
    const unselectedColor = ColorFilter.mode(Colors.black, BlendMode.srcIn);

    expect(notebook.activeIndex, 0);
    expect(notebook.draft.content.hasWork, isFalse);
    expect(arrow('Previous question').onPressed, isNull);
    expect(toolColor('Pen'), selectedColor);
    expect(toolColor('Eraser'), unselectedColor);

    await tester.tap(find.byTooltip('Eraser'));
    await tester.pump();
    expect(toolColor('Pen'), unselectedColor);
    expect(toolColor('Eraser'), selectedColor);

    final firstDraft = notebook.draft;
    firstDraft.addInk(PaperTool.pen, const [Offset(0.5, 0.5)]);
    await tester.tap(find.byTooltip('Next question'));
    await tester.pump();
    expect(notebook.activeIndex, 1);
    expect(notebook.draft.content.hasWork, isFalse);
    expect(find.text('Question 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous question'));
    await tester.pump();
    expect(notebook.draft, same(firstDraft));
    expect(notebook.draft.content.hasWork, isTrue);

    expect(find.byTooltip('Question 5'), findsNothing);
    await tester.tap(find.byTooltip('Question 4'));
    await tester.pump();
    expect(find.text('Solve for x: x + 7 = 22.'), findsOneWidget);
    expect(arrow('Next question').onPressed, isNull);
    expect(notebook.draft.content.hasWork, isFalse);
  });

  testWidgets(
    'Submit requires ink in every question and records the current drafts',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final notebook = HomeworkNotebook();
      final lastQuestion = HomeworkNotebook.questions.length - 1;
      for (var index = 0; index < lastQuestion; index++) {
        notebook.activeIndex = index;
        notebook.draft.addInk(PaperTool.pen, const [Offset(0.5, 0.5)]);
      }
      notebook.activeIndex = lastQuestion;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudentHomeworkView(
              notebook: notebook,
              checker: _UnusedChecker(),
              onBack: () {},
            ),
          ),
        ),
      );

      final submit = find.widgetWithText(FilledButton, 'Submit');
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      expect(notebook.submit(), isFalse);
      final pen = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('homework-paper'))),
        kind: PointerDeviceKind.stylus,
      );
      await pen.up();
      await tester.pump();
      expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);

      await tester.tap(submit);
      await tester.pump();
      expect(notebook.submitted, isTrue);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Submitted'),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(find.byTooltip('Undo'));
      await tester.pump();
      expect(notebook.submitted, isFalse);
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    },
  );

  testWidgets(
    'Eraser hides whole strokes while down and undo groups the drag',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final notebook = HomeworkNotebook()..activeIndex = 0;
      final draft = notebook.draft;
      draft.addInk(PaperTool.pen, const [Offset(0.2, 0.4), Offset(0.8, 0.4)]);
      draft.addInk(PaperTool.pen, const [Offset(0.2, 0.6), Offset(0.8, 0.6)]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudentHomeworkView(
              notebook: notebook,
              checker: _UnusedChecker(),
              onBack: () {},
            ),
          ),
        ),
      );

      final finder = find.byType(HomeworkPaper);
      final paper = tester.getRect(finder);
      final first = Offset(paper.center.dx, paper.top + paper.height * 0.4);
      final second = Offset(paper.center.dx, paper.top + paper.height * 0.6);
      int visibleStrokes() =>
          tester.widget<HomeworkPaper>(finder).visibleContent.strokes.length;

      expect(find.byTooltip('Lasso'), findsNothing);
      await tester.tap(find.byTooltip('Eraser'));
      await tester.pump();

      final cancelled = await tester.startGesture(
        first,
        kind: PointerDeviceKind.stylus,
      );
      await tester.pump();
      expect(visibleStrokes(), 1);
      await cancelled.cancel();
      await tester.pump();
      expect(visibleStrokes(), 2);

      final drag = await tester.startGesture(
        first,
        kind: PointerDeviceKind.stylus,
      );
      await tester.pump();
      expect(visibleStrokes(), 1);
      await drag.moveTo(second);
      await tester.pump();
      expect(visibleStrokes(), 0);
      expect(draft.content.strokes, hasLength(2));
      await drag.up();
      await tester.pump();
      expect(draft.content.strokes, isEmpty);

      await tester.tap(find.byTooltip('Undo'));
      await tester.pump();
      expect(visibleStrokes(), 2);
      await tester.tap(find.byTooltip('Redo'));
      await tester.pump();
      expect(visibleStrokes(), 0);
    },
  );

  testWidgets('A feedback underline uses the bottom of its paper region', (
    tester,
  ) async {
    final draft = HomeworkDraft();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 448,
            child: HomeworkPaper(
              captureKey: GlobalKey(),
              draft: draft,
              visibleContent: draft.content,
              tool: PaperTool.pen,
              activeTrace: const [],
              feedback: const HomeworkFeedback(
                'Recheck this step.',
                region: PaperRegion(0.25, 0.25, 0.5, 0.25),
                markStyle: HomeworkMarkStyle.underline,
              ),
              onDown: (_, _) {},
              onMove: (_, _) {},
              onEnd: (_, {required cancelled}) {},
            ),
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byType(HomeworkPaper));
    expect(
      find.byType(CustomPaint).last,
      paints..line(
        p1: Offset(size.width * 0.25, size.height * 0.5),
        p2: Offset(size.width * 0.75, size.height * 0.5),
      ),
    );
  });

  testWidgets(
    'API sends the full PNG and fills the returned highlight regions',
    (tester) async {
      final transport = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/v1/assignments/hw-3-1/items/q1/reviews');
        expect(request.headers['content-type'], startsWith('application/json'));
        expect(jsonDecode(request.body), {
          'image_data_url': 'data:image/png;base64,iVBORw==',
          'language': 'en',
        });
        return http.Response(
          jsonEncode({
            'review_id': 'saved-review',
            'assignment_id': 'hw-3-1',
            'item_id': 'q1',
            'status': 'needs_revision',
            'message': 'Check the highlighted steps.',
            'issues': [
              {
                'box': {'x': 0.1, 'y': 0.4, 'width': 0.3, 'height': 0.1},
                'observation': 'Check how you combined the powers.',
                'hint': 'How many factors are there in all?',
              },
              {
                'box': {'x': 0.6, 'y': 0.7, 'width': 0.2, 'height': 0.16},
                'observation': 'Check this calculation.',
                'hint': 'Can you verify it one operation at a time?',
              },
            ],
          }),
          200,
        );
      });
      addTearDown(transport.close);
      final feedback =
          await ApiHomeworkChecker(
            Uri.parse('http://127.0.0.1:8080'),
            transport,
          ).check(
            HomeworkCheckRequest(
              assignmentId: HomeworkNotebook.assignmentId,
              question: HomeworkNotebook.questions.first,
              paperPng: Uint8List.fromList([137, 80, 78, 71]),
              imageWidth: 448,
              imageHeight: 200,
            ),
          );
      expect(feedback.status, HomeworkReviewStatus.needsRevision);
      expect(feedback.issues.first.hint, 'How many factors are there in all?');

      final draft = HomeworkDraft();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 448,
              child: HomeworkPaper(
                captureKey: GlobalKey(),
                draft: draft,
                visibleContent: draft.content,
                tool: PaperTool.pen,
                activeTrace: const [],
                feedback: feedback,
                onDown: (_, _) {},
                onMove: (_, _) {},
                onEnd: (_, {required cancelled}) {},
              ),
            ),
          ),
        ),
      );
      final size = tester.getSize(find.byType(HomeworkPaper));
      RRect expectedBox(PaperRegion region) => RRect.fromRectAndRadius(
        Rect.fromLTWH(
          region.x * size.width,
          region.y * size.height,
          region.width * size.width,
          region.height * size.height,
        ),
        const Radius.circular(6),
      );
      expect(
        find.byType(CustomPaint).last,
        paints
          ..rrect(
            rrect: expectedBox(const PaperRegion(0.1, 0.4, 0.3, 0.1)),
            style: PaintingStyle.fill,
            color: const Color(0x59FF7373),
          )
          ..rrect(
            rrect: expectedBox(const PaperRegion(0.6, 0.7, 0.2, 0.16)),
            style: PaintingStyle.fill,
            color: const Color(0x59FF7373),
          ),
      );
    },
  );

  testWidgets('Fingers zoom and pan while stylus ink follows the paper', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final notebook = HomeworkNotebook();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudentHomeworkView(
            notebook: notebook,
            checker: _UnusedChecker(),
            onBack: () {},
          ),
        ),
      ),
    );

    final paper = tester.getRect(find.byKey(const ValueKey('homework-paper')));
    final center = paper.center;
    final left = await tester.startGesture(
      center.translate(-40, 0),
      pointer: 1,
    );
    final right = await tester.startGesture(
      center.translate(40, 0),
      pointer: 2,
    );
    await left.moveBy(const Offset(-40, 0));
    await right.moveBy(const Offset(40, 0));
    await left.up();
    await right.up();
    await tester.pump();

    final pan = await tester.startGesture(center, pointer: 3);
    await pan.moveBy(Offset(paper.width * 0.10, 0));
    await pan.up();
    await tester.pump();
    expect(notebook.draft.content.strokes, isEmpty);

    final pen = await tester.startGesture(
      center + Offset(paper.width * 0.25, paper.height * 0.10),
      pointer: 4,
      kind: PointerDeviceKind.stylus,
    );
    final palm = await tester.startGesture(center, pointer: 5);
    await palm.moveBy(const Offset(30, 20));
    await pen.moveBy(const Offset(12, 6));
    await palm.up();
    await pen.up();
    await tester.pump();

    final stroke = notebook.draft.content.strokes.single;
    expect(stroke.points.first.dx, closeTo(0.575, 0.001));
    expect(stroke.points.first.dy, closeTo(0.55, 0.001));
    expect(
      stroke.points.last.dx - stroke.points.first.dx,
      closeTo(12 / (paper.width * 2), 0.001),
    );

    final pinchLeft = await tester.startGesture(
      center.translate(-80, 0),
      pointer: 6,
    );
    final pinchRight = await tester.startGesture(
      center.translate(80, 0),
      pointer: 7,
    );
    await pinchLeft.moveBy(const Offset(40, 0));
    await pinchRight.moveBy(const Offset(-40, 0));
    await pinchLeft.up();
    await pinchRight.up();
    await tester.pump();

    final penAfterZoomOut = await tester.startGesture(
      center,
      pointer: 8,
      kind: PointerDeviceKind.stylus,
    );
    await penAfterZoomOut.up();
    await tester.pump();
    expect(
      notebook.draft.content.strokes.last.points.first.dx,
      closeTo(0.5, 0.001),
    );
  });

  testWidgets('Automatic check waits for the pen to lift and a 2.5 s pause', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final checker = _UnusedChecker();
    final notebook = HomeworkNotebook();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudentHomeworkView(
            notebook: notebook,
            checker: checker,
            onBack: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(notebook.automatic, isTrue);

    final paper = find.byKey(const ValueKey('homework-paper'));
    final gesture = await tester.startGesture(
      tester.getCenter(paper),
      kind: PointerDeviceKind.stylus,
    );
    await gesture.moveBy(const Offset(12, 3));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Checking…'), findsNothing);

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 2499));
    expect(find.text('Checking…'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Checking…'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(checker.calls, 0);
  });
}

class _UnusedChecker implements HomeworkChecker {
  int calls = 0;

  @override
  Future<HomeworkFeedback> check(HomeworkCheckRequest request) async {
    calls++;
    return const HomeworkFeedback('Test feedback');
  }
}

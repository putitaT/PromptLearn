import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../domain/models/homework_check.dart';
import '../../../core/theme/app_theme.dart';
import 'homework_notebook.dart';

class HomeworkPaper extends StatefulWidget {
  const HomeworkPaper({
    super.key,
    required this.captureKey,
    required this.draft,
    required this.visibleContent,
    required this.tool,
    required this.activeTrace,
    required this.feedback,
    required this.onDown,
    required this.onMove,
    required this.onEnd,
  });

  final GlobalKey captureKey;
  final HomeworkDraft draft;
  final PaperContent visibleContent;
  final PaperTool tool;
  final List<Offset> activeTrace;
  final HomeworkFeedback? feedback;
  final void Function(int pointer, Offset point) onDown;
  final void Function(int pointer, Offset point) onMove;
  final void Function(int pointer, {required bool cancelled}) onEnd;

  @override
  State<HomeworkPaper> createState() => _HomeworkPaperState();
}

class _HomeworkPaperState extends State<HomeworkPaper> {
  static const _penKinds = {
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
  };

  final _fingers = <int, Offset>{};
  int? _penPointer;
  double _zoom = 1;
  Offset _pan = Offset.zero;

  @override
  void didUpdateWidget(covariant HomeworkPaper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draft != widget.draft) {
      _fingers.clear();
      _penPointer = null;
      _zoom = 1;
      _pan = Offset.zero;
    }
  }

  Offset _viewportPoint(PointerEvent event, Size size) => Offset(
    event.localPosition.dx / size.width,
    event.localPosition.dy / size.height,
  );

  Offset _paperPoint(Offset viewportPoint) {
    final point = (viewportPoint - _pan) / _zoom;
    return Offset(point.dx.clamp(0.0, 1.0), point.dy.clamp(0.0, 1.0));
  }

  void _down(PointerDownEvent event, Size size) {
    if (_penPointer != null) return;

    final point = _viewportPoint(event, size);
    if (_penKinds.contains(event.kind)) {
      _fingers.clear();
      _penPointer = event.pointer;
      widget.onDown(event.pointer, _paperPoint(point));
    } else if (event.kind == PointerDeviceKind.touch) {
      _fingers[event.pointer] = point;
    }
  }

  void _move(PointerMoveEvent event, Size size) {
    if (_penPointer == event.pointer) {
      widget.onMove(event.pointer, _paperPoint(_viewportPoint(event, size)));
      return;
    }
    if (!_fingers.containsKey(event.pointer)) return;

    final previous = _fingers.values.take(2).toList(growable: false);
    _fingers[event.pointer] = _viewportPoint(event, size);
    final current = _fingers.values.take(2).toList(growable: false);

    if (current.length == 1) {
      _movePaper(_zoom, _pan + current.first - previous.first);
      return;
    }

    final previousSpan = _project(previous[1] - previous[0], size).distance;
    final currentSpan = _project(current[1] - current[0], size).distance;
    final zoom = previousSpan < 1
        ? _zoom
        : (_zoom * currentSpan / previousSpan).clamp(1.0, 4.0);
    final previousCenter = (previous[0] + previous[1]) / 2;
    final currentCenter = (current[0] + current[1]) / 2;
    final paperAnchor = (previousCenter - _pan) / _zoom;
    _movePaper(zoom, currentCenter - paperAnchor * zoom);
  }

  void _movePaper(double zoom, Offset pan) {
    final lower = 1 - zoom;
    final bounded = Offset(pan.dx.clamp(lower, 0.0), pan.dy.clamp(lower, 0.0));
    if (zoom == _zoom && bounded == _pan) return;

    setState(() {
      _zoom = zoom;
      _pan = bounded;
    });
  }

  void _end(int pointer, {required bool cancelled}) {
    if (_penPointer == pointer) {
      _penPointer = null;
      widget.onEnd(pointer, cancelled: cancelled);
    } else {
      _fingers.remove(pointer);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tool = widget.tool;
    final drawsInk = tool == PaperTool.pen || tool == PaperTool.highlighter;
    return AspectRatio(
      aspectRatio: 2.24,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE1E8E3), width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              return RawGestureDetector(
                gestures: {
                  EagerGestureRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                        EagerGestureRecognizer
                      >(
                        () => EagerGestureRecognizer(
                          supportedDevices: const {
                            PointerDeviceKind.touch,
                            ..._penKinds,
                          },
                        ),
                        (_) {},
                      ),
                },
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (event) => _down(event, size),
                  onPointerMove: (event) => _move(event, size),
                  onPointerUp: (event) => _end(event.pointer, cancelled: false),
                  onPointerCancel: (event) =>
                      _end(event.pointer, cancelled: true),
                  child: Transform.translate(
                    offset: _project(_pan, size),
                    child: Transform.scale(
                      scale: _zoom,
                      alignment: Alignment.topLeft,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          RepaintBoundary(
                            key: widget.captureKey,
                            child: CustomPaint(
                              painter: _InkPainter(
                                widget.visibleContent,
                                drawsInk
                                    ? PaperStroke(tool, widget.activeTrace)
                                    : null,
                              ),
                            ),
                          ),
                          IgnorePointer(
                            child: CustomPaint(
                              painter: _MarkPainter(
                                feedback: widget.feedback,
                                eraser:
                                    tool == PaperTool.eraser &&
                                        widget.activeTrace.isNotEmpty
                                    ? widget.activeTrace.last
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

const _inkColor = Color(0xFF293681);

Future<HomeworkCheckRequest> captureAnswerPaper(
  HomeworkQuestion question,
  PaperContent content,
  Size size,
) async {
  final scale = math.min(2.0, 1600 / size.longestSide);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(scale);
  _InkPainter(content, null).paint(canvas, size);
  final picture = recorder.endRecording();
  try {
    final image = await picture.toImage(
      (size.width * scale).ceil(),
      (size.height * scale).ceil(),
    );
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) {
        throw StateError('Paper snapshot could not be encoded.');
      }
      return HomeworkCheckRequest(
        assignmentId: HomeworkNotebook.assignmentId,
        question: question,
        paperPng: bytes.buffer.asUint8List(
          bytes.offsetInBytes,
          bytes.lengthInBytes,
        ),
        imageWidth: image.width,
        imageHeight: image.height,
      );
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
  }
}

Offset _project(Offset point, Size size) =>
    Offset(point.dx * size.width, point.dy * size.height);

Rect _area(PaperRegion region, Size size) => Rect.fromLTWH(
  region.x * size.width,
  region.y * size.height,
  region.width * size.width,
  region.height * size.height,
);

Path _tracePath(List<Offset> points, Size size) {
  final first = _project(points.first, size);
  final path = Path()..moveTo(first.dx, first.dy);
  for (final point in points.skip(1)) {
    final projected = _project(point, size);
    path.lineTo(projected.dx, projected.dy);
  }
  return path;
}

class _InkPainter extends CustomPainter {
  const _InkPainter(this.content, this.activeStroke);

  final PaperContent content;
  final PaperStroke? activeStroke;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFFFEFEFE), BlendMode.src);
    final dotPaint = Paint()..color = const Color(0xFFDCE6E0);
    for (var y = 16.0; y < size.height; y += 24) {
      for (var x = 16.0; x < size.width; x += 24) {
        canvas.drawCircle(Offset(x, y), 0.9, dotPaint);
      }
    }

    for (final stroke in content.strokes) {
      _drawStroke(canvas, size, stroke);
    }
    final active = activeStroke;
    if (active != null) _drawStroke(canvas, size, active);
  }

  void _drawStroke(Canvas canvas, Size size, PaperStroke stroke) {
    if (stroke.points.isEmpty) return;
    final highlighted = stroke.tool == PaperTool.highlighter;
    final paint = Paint()
      ..color = highlighted ? const Color(0x70B8E68C) : _inkColor
      ..strokeWidth = highlighted ? 12 : 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (stroke.points.length == 1) {
      canvas.drawCircle(
        _project(stroke.points.first, size),
        paint.strokeWidth / 2,
        paint,
      );
    } else {
      canvas.drawPath(
        _tracePath(stroke.points, size),
        paint..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _InkPainter old) =>
      old.content != content || old.activeStroke != activeStroke;
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({required this.feedback, required this.eraser});

  final HomeworkFeedback? feedback;
  final Offset? eraser;

  @override
  void paint(Canvas canvas, Size size) {
    final hint = feedback;
    if (hint != null) {
      final paint = Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3;
      final region = hint.region;
      if (region != null && region.isValid) {
        final area = _area(region, size);
        switch (hint.markStyle) {
          case HomeworkMarkStyle.circle:
            canvas.drawOval(area, paint);
          case HomeworkMarkStyle.underline:
            canvas.drawLine(area.bottomLeft, area.bottomRight, paint);
        }
      }
      final highlight = Paint()..color = const Color(0x59FF7373);
      for (final (index, issue) in hint.issues.indexed) {
        if (!issue.region.isValid) continue;
        final area = _area(issue.region, size);
        canvas.drawRRect(
          RRect.fromRectAndRadius(area, const Radius.circular(6)),
          highlight,
        );
        if (hint.issues.length > 1) {
          final marker = TextPainter(
            text: TextSpan(
              text: '${index + 1}',
              style: const TextStyle(
                color: Color(0xFF8B3030),
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          marker.paint(canvas, area.topLeft + const Offset(4, 1));
          marker.dispose();
        }
      }
    }

    final point = eraser;
    if (point != null) {
      final cursor = Rect.fromCenter(
        center: _project(point, size),
        width: size.width * paperEraserRadius * 2,
        height: size.height * paperEraserRadius * 2,
      );
      canvas.drawOval(
        cursor,
        Paint()..color = AppColors.accent.withValues(alpha: 0.22),
      );
      canvas.drawOval(
        cursor,
        Paint()
          ..color = AppColors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MarkPainter old) =>
      old.feedback != feedback || old.eraser != eraser;
}

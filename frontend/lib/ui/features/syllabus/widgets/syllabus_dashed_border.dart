import 'dart:math' as math;

import 'package:flutter/widgets.dart';

class SyllabusDashedBorder extends CustomPainter {
  const SyllabusDashedBorder({
    this.color = const Color(0xFFA6DCB9),
    this.radius = 20,
  });

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(1),
      Radius.circular(radius - 1),
    );
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()..addRRect(outline);
    for (final edge in path.computeMetrics()) {
      for (var start = 0.0; start < edge.length; start += 12) {
        canvas.drawPath(
          edge.extractPath(start, math.min(start + 7, edge.length)),
          stroke,
        );
      }
    }
  }

  @override
  bool shouldRepaint(SyllabusDashedBorder oldDelegate) =>
      color != oldDelegate.color || radius != oldDelegate.radius;
}

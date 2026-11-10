import 'package:flutter/material.dart';

/// Dashed rounded-rect border — the «بعدی» prayer row, the past rawatib
/// boxes. Stroke 1, dash 5 / gap 4.
class DashedRRectPainter extends CustomPainter {
  const DashedRRectPainter({required this.color, this.radius = 14});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final metric = (Path()..addRRect(rrect)).computeMetrics().first;
    const dash = 5.0;
    const gap = 4.0;
    var d = 0.0;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;
    while (d < metric.length) {
      canvas.drawPath(
          metric.extractPath(d, (d + dash).clamp(0, metric.length)), paint);
      d += dash + gap;
    }
  }

  @override
  bool shouldRepaint(DashedRRectPainter old) => old.color != color;
}

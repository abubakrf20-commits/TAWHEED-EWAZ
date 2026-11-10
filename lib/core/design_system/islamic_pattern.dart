import 'dart:math';
import 'package:flutter/material.dart';

/// نقش هندسی اسلامی ظریف: شبکهٔ تکرارشوندهٔ ستارهٔ 8پر (رب‌الحزب)
/// به‌صورت overlay طلایی با اپاسیتی بسیار کم روی سطوح قهوه‌ای.
class IslamicPatternPainter extends CustomPainter {
  final Color color;
  final double opacity;
  final double cell;

  const IslamicPatternPainter({
    required this.color,
    this.opacity = 0.06,
    this.cell = 52,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    paint.color = color.withValues(alpha: opacity);
    final r = cell * 0.46;
    for (double y = -cell; y < size.height + cell; y += cell) {
      for (double x = -cell; x < size.width + cell; x += cell) {
        _star(canvas, paint, Offset(x, y), r);
      }
    }
  }

  void _star(Canvas canvas, Paint paint, Offset c, double r) {
    canvas.drawRect(
      Rect.fromCenter(center: c, width: r * 1.35, height: r * 1.35),
      paint,
    );
    final path = Path();
    for (int i = 0; i < 4; i++) {
      final a = pi / 4 + i * (pi / 2);
      final p = Offset(
        c.dx + cos(a) * r * 0.99,
        c.dy + sin(a) * r * 0.99,
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant IslamicPatternPainter old) =>
      old.color != color || old.opacity != opacity || old.cell != cell;
}

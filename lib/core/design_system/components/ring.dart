import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tawheeed/core/theme/time_theme.dart';

/// Progress ring with round caps: a tinted track plus the colored progress
/// arc (0..1), starting at the 12 o'clock position. The caller owns whatever
/// sits in the middle — usually a number and a label. [dashedTrack] swaps the
/// solid track for dashes — the «no goal yet» ring that reads as optional
/// instead of a zeroed bar (Report fasting ring). [startDot] paints the solid
/// 12 o'clock dot the home summary rings use, so a 0 % ring still shows
/// where the sweep would begin.
class RingView extends StatelessWidget {
  const RingView({
    super.key,
    required this.progress,
    this.size = 72,
    this.strokeWidth = 7,
    this.color,
    this.trackColor,
    this.child,
    this.semanticLabel,
    this.dashedTrack = false,
    this.startDot = false,
  });

  final double progress;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? trackColor;
  final Widget? child;
  final String? semanticLabel;
  final bool dashedTrack;
  final bool startDot;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final c = color ?? t.primary;
    final ring = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: RingPainter(
          progress: progress.clamp(0.0, 1.0),
          color: c,
          trackColor: trackColor ?? c.withValues(alpha: .15),
          strokeWidth: strokeWidth,
          dashedTrack: dashedTrack,
          startDot: startDot,
        ),
        child: Center(child: child),
      ),
    );
    if (semanticLabel == null) return ring;
    return Semantics(label: semanticLabel, child: ring);
  }
}

class RingPainter extends CustomPainter {
  const RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
    this.dashedTrack = false,
    this.startDot = false,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;
  final bool dashedTrack;
  final bool startDot;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    if (dashedTrack) {
      const dashes = 22;
      const step = math.pi * 2 / dashes;
      for (var i = 0; i < dashes; i++) {
        canvas.drawArc(rect, -math.pi / 2 + i * step, step * .55, false, track);
      }
    } else {
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, track);
    }

    if (startDot) {
      // Solid dot at 12 o'clock, drawn before the early return so a 0 %
      // ring still shows where the sweep would begin. Scaled with the
      // stroke so every ring size keeps the same proportions.
      final c = Offset(size.width / 2, size.height / 2);
      final r = (size.shortestSide - strokeWidth) / 2;
      canvas.drawCircle(
        Offset(c.dx, c.dy - r),
        strokeWidth * (2.2 / 6),
        Paint()..color = color,
      );
    }

    final p = progress.clamp(0.0, 1.0);
    if (p <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * p, false, arc);
  }

  @override
  bool shouldRepaint(RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth ||
      old.dashedTrack != dashedTrack ||
      old.startDot != startDot;
}

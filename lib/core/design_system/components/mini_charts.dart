import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Tiny, dependency-free charts for the personal tool dashboards.
///
/// These intentionally use [CustomPainter] rather than a chart package: the
/// tools are local-first, ship in a ~50MB APK, and only ever draw a handful of
/// points. Everything is theme-agnostic — callers pass their own colours.

class DonutSlice {
  const DonutSlice({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;
}

/// A donut with a small gap between segments. Values <= 0 are ignored; when
/// nothing is left a neutral track is drawn instead of an empty box.
class MiniDonutChart extends StatelessWidget {
  const MiniDonutChart({
    super.key,
    required this.slices,
    this.size = 92,
    this.thickness = 12,
    this.center,
    this.trackColor,
  });

  final List<DonutSlice> slices;
  final double size;
  final double thickness;
  final Widget? center;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _DonutPainter(
              slices: slices,
              thickness: thickness,
              trackColor: trackColor ??
                  Theme.of(context).colorScheme.outline.withValues(alpha: .25),
            ),
          ),
          if (center != null) center!,
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({
    required this.slices,
    required this.thickness,
    required this.trackColor,
  });

  final List<DonutSlice> slices;
  final double thickness;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - thickness) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    final live = slices.where((s) => s.value > 0).toList();
    if (live.isEmpty) return;
    final total = live.fold<double>(0, (sum, s) => sum + s.value);
    if (total <= 0) return;

    var start = -math.pi / 2;
    for (final slice in live) {
      final sweep = (slice.value / total) * math.pi * 2;
      // A 0.035 rad gap keeps adjacent segments legible without eating a
      // small slice entirely.
      final visible = math.max(0.0, sweep - 0.035);
      canvas.drawArc(
        rect,
        start + 0.0175,
        visible,
        false,
        Paint()
          ..color = slice.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness
          ..strokeCap = StrokeCap.butt,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.slices.length != slices.length ||
      old.thickness != thickness ||
      old.trackColor != trackColor;
}

/// A sparkline with a soft area fill and a marker on the newest point.
/// At least two points are needed; a single value renders as a flat line.
class MiniLineChart extends StatelessWidget {
  const MiniLineChart({
    super.key,
    required this.values,
    required this.color,
    this.height = 60,
  });

  final List<double> values;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: height,
        child: CustomPaint(
          painter: _LinePainter(values: values, color: color),
        ),
      );
}

class _LinePainter extends CustomPainter {
  const _LinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final points = values.length == 1 ? [values.first, values.first] : values;
    var min = points.first;
    var max = points.first;
    for (final v in points) {
      if (v < min) min = v;
      if (v > max) max = v;
    }
    final span = max - min < 0.0001 ? 1.0 : max - min;
    final dx = size.width / (points.length - 1);
    Offset at(int i) => Offset(
          i * dx,
          size.height - 6 - ((points[i] - min) / span) * (size.height - 12),
        );

    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < points.length; i++) {
      line.lineTo(at(i).dx, at(i).dy);
    }
    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..color = color.withValues(alpha: .14)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final last = at(points.length - 1);
    canvas.drawCircle(last, 6, Paint()..color = color.withValues(alpha: .20));
    canvas.drawCircle(last, 3.2, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.values.length != values.length || old.color != color;
}

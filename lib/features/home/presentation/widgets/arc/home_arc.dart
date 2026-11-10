import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/home/presentation/providers/arc_style_provider.dart';
import 'package:tawheeed/features/home/presentation/widgets/arc/arc_layout.dart';
import 'package:tawheeed/features/home/presentation/widgets/arc/arc_theme.dart';
import 'package:tawheeed/features/prayer/domain/prayer_clock.dart';

/// The home hero's prayer arc, in whichever of the three styles is selected.
///
/// Static art (track, sky, segments, markers, every label) is recorded once
/// into a `ui.Picture` and cached; only the part of the day already passed and
/// the orb are painted per frame. That is why the countdown can tick every
/// second without the arc being laid out again.
class HomeArc extends StatelessWidget {
  const HomeArc({
    super.key,
    required this.arc,
    required this.style,
    required this.smallLabels,
    required this.textScale,
    this.lite = false,
  });

  final ArcState arc;
  final HomeArcStyle style;
  final bool smallLabels;
  final double textScale;

  /// The app's low-end flag: no sky fill, stars or glow.
  final bool lite;

  @override
  Widget build(BuildContext context) {
    final theme = ArcTheme.of(context);
    return AspectRatio(
      aspectRatio: ArcGeometry.designWidth / ArcGeometry.designHeight,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: ArcPainter(
            arc: arc,
            style: style,
            theme: theme,
            textScale: textScale,
            smallLabels: smallLabels,
            lite: lite,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// Paints the arc. Public so the settings preview can use the same painter at
/// a smaller size without a second implementation.
class ArcPainter extends CustomPainter {
  ArcPainter({
    required this.arc,
    required this.style,
    required this.theme,
    required this.textScale,
    required this.smallLabels,
    this.lite = false,
  });

  final ArcState arc;
  final HomeArcStyle style;
  final ArcTheme theme;
  final double textScale;
  final bool smallLabels;
  final bool lite;

  /// At most three picture pairs: one per style/size/palette combination
  /// actually on screen. Anything older is disposed when it is evicted.
  static final Map<String, _ArcStatic> _cache = {};
  static const int _cacheLimit = 3;

  static void clearCache() {
    for (final pictures in _cache.values) {
      pictures.dispose();
    }
    _cache.clear();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final geometry = ArcGeometry(size);
    final key = _cacheKey(size);
    var pictures = _cache.remove(key);
    if (pictures == null) {
      pictures = _record(geometry);
      if (_cache.length >= _cacheLimit) {
        final oldest = _cache.keys.first;
        _cache.remove(oldest)?.dispose();
      }
    }
    _cache[key] = pictures;

    // Paint order IS the fix for «خط قوس روی نقطه‌ها می‌افتد»: the sweep of
    // the day already passed used to be painted AFTER the static picture, so
    // the line covered every marker it crossed. The static art is split in
    // two: the base (track/sky/segments) under the sweep, the markers and
    // their labels back on top of it, and the orb last.
    canvas.drawPicture(pictures.base);
    _paintPassedSweep(canvas, geometry);
    canvas.drawPicture(pictures.overlay);
    _paintOrb(canvas, geometry, arc.nowFraction.clamp(0.0, 1.0));
  }

  /// The static art depends on the moment only through WHICH markers have
  /// passed and which one is next — not on the minute, so this key is stable
  /// between marker boundaries.
  String _cacheKey(Size size) {
    final states = arc.markers
        .map((m) => '${m.label}@${m.fraction.toStringAsFixed(4)}'
            '${m.state.index}')
        .join('|');
    return '${style.wire}|${size.width.round()}x${size.height.round()}'
        '|${theme.isDark}|${textScale.toStringAsFixed(2)}|$smallLabels'
        '|$lite|$states';
  }

  _ArcStatic _record(ArcGeometry g) {
    final baseRecorder = ui.PictureRecorder();
    final baseCanvas = Canvas(baseRecorder);
    switch (style) {
      case HomeArcStyle.tags:
      case HomeArcStyle.sky:
        _paintTaggedBase(baseCanvas, g);
      case HomeArcStyle.segments:
        _paintSegmentBase(baseCanvas, g);
    }

    final overlayRecorder = ui.PictureRecorder();
    final overlayCanvas = Canvas(overlayRecorder);
    _paintMarkers(overlayCanvas, g);
    _paintLabels(overlayCanvas, g);

    return _ArcStatic(
      base: baseRecorder.endRecording(),
      overlay: overlayRecorder.endRecording(),
    );
  }

  // ── static layers ────────────────────────────────────────────────────────

  void _paintTaggedBase(Canvas canvas, ArcGeometry g) {
    if (style == HomeArcStyle.sky) {
      if (!lite) {
        canvas.drawPath(
          g.domePath(),
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(0, g.center.dy - g.radius),
              Offset(0, g.baselineY),
              [theme.domeTop, theme.domeTop.withValues(alpha: 0)],
            ),
        );
        _paintStars(canvas, g);
      }
      canvas.drawLine(
        Offset(g.center.dx - g.radius, g.baselineY),
        Offset(g.center.dx + g.radius, g.baselineY),
        Paint()
          ..strokeWidth = math.max(1, g.k)
          ..color = theme.horizon,
      );
      canvas.drawPath(
        g.arcPath(),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7 * g.k
          ..strokeCap = StrokeCap.round
          ..shader = _skyShader(g, alpha: .32),
      );
      return;
    }

    // Style 1: a calm 4dp line.
    canvas.drawPath(
      g.arcPath(),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * g.k
        ..strokeCap = StrokeCap.round
        ..color = theme.track,
    );
  }

  void _paintSegmentBase(Canvas canvas, ArcGeometry g) {
    final markers = arc.markers;
    if (markers.length < 2) return;
    final paint = Paint()..style = PaintingStyle.stroke;
    const gap = 0.006;
    for (var i = 0; i < markers.length - 1; i++) {
      final from = (markers[i].fraction + gap).clamp(0.0, 1.0);
      final to = (markers[i + 1].fraction - gap).clamp(0.0, 1.0);
      if (to <= from) continue;
      final color = theme.segmentColors[i % theme.segmentColors.length];
      final done = markers[i + 1].state == ArcMarkerState.passed;
      final current = markers[i].state == ArcMarkerState.passed && !done;
      paint
        ..strokeWidth = 11 * g.k
        ..strokeCap = StrokeCap.butt
        // A finished interval keeps its colour, the one the reader is inside
        // waits dim for the dynamic layer's bright part, the rest glow at 32%.
        ..color = done
            ? color
            : color.withValues(alpha: current ? .30 : .32);
      canvas.drawPath(g.arcSlice(from, to), paint);
    }
  }

  void _paintStars(Canvas canvas, ArcGeometry g) {
    // Six fixed points above the arc, symmetric about the top.
    const points = [
      Offset(0.10, 0.30),
      Offset(0.22, 0.14),
      Offset(0.36, 0.26),
      Offset(0.64, 0.24),
      Offset(0.78, 0.12),
      Offset(0.90, 0.32),
    ];
    final paint = Paint()..color = theme.starColor;
    for (var i = 0; i < points.length; i++) {
      final p = Offset(points[i].dx * g.size.width, points[i].dy * g.size.height);
      canvas.drawCircle(p, (i.isEven ? 1.2 : 0.9) * g.k, paint);
    }
  }

  void _paintMarkers(Canvas canvas, ArcGeometry g) {
    for (var i = 0; i < arc.markers.length; i++) {
      final marker = arc.markers[i];
      final at = g.pointAt(marker.fraction);
      final passed = marker.state == ArcMarkerState.passed;
      final fill = passed
          ? theme.passed
          : (marker.kind == ArcMarkerKind.prayer
              ? theme.markerFill
              : theme.derivedFill);
      if (marker.state == ArcMarkerState.next) {
        _drawDashedRing(canvas, at, 11 * g.k, 3 * g.k, theme.nextRing, g.k);
      }
      final shape = _markerPath(marker.kind, at, g.k);
      canvas.drawPath(shape, Paint()..color = fill);
      canvas.drawPath(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (marker.kind == ArcMarkerKind.prayer ? 2 : 1.5) * g.k
          ..color = theme.markerStroke,
      );
    }
  }

  Path _markerPath(ArcMarkerKind kind, Offset at, double k) {
    if (kind == ArcMarkerKind.prayer) {
      return Path()..addOval(Rect.fromCircle(center: at, radius: 5.5 * k));
    }
    final r = 5 * k;
    return Path()
      ..moveTo(at.dx, at.dy - r)
      ..lineTo(at.dx + r, at.dy)
      ..lineTo(at.dx, at.dy + r)
      ..lineTo(at.dx - r, at.dy)
      ..close();
  }

  void _drawDashedRing(
    Canvas canvas,
    Offset center,
    double radius,
    double dash,
    Color color,
    double k,
  ) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * k
      ..strokeCap = StrokeCap.butt
      ..color = color;
    final circumference = 2 * math.pi * radius;
    final count = (circumference / (dash * 2)).floor().clamp(6, 24);
    final step = 2 * math.pi / count;
    final sweep = step * 0.5;
    for (var i = 0; i < count; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * step,
        sweep,
        false,
        paint,
      );
    }
  }

  void _paintLabels(Canvas canvas, ArcGeometry g) {
    final plan = planArcLabels(
      style: style,
      geometry: g,
      markers: arc.markers,
      textScale: textScale,
      showSmallLabels: smallLabels,
      nowT: arc.nowFraction,
    );
    for (final label in plan.labels) {
      final marker = arc.markers[label.markerIndex];
      final passed = marker.state == ArcMarkerState.passed;
      final isNext = marker.state == ArcMarkerState.next;
      final color = switch (label.role) {
        ArcLabelRole.tagName => passed || isNext ? theme.passed : theme.label,
        ArcLabelRole.innerName =>
          passed ? theme.timePassed : theme.labelDim,
      };
      final weight = isNext && label.role == ArcLabelRole.tagName
          ? FontWeight.w600
          : FontWeight.w500;
      final tp = TextPainter(
        text: TextSpan(
          text: label.text,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: label.fontSize,
            height: 1.05,
            fontWeight: weight,
            color: color,
          ),
        ),
        textDirection: TextDirection.rtl,
      )..layout();
      tp.paint(
        canvas,
        label.center - Offset(tp.width / 2, tp.height / 2),
      );
    }
  }

  // ── dynamic layer ────────────────────────────────────────────────────────

  /// The part of the day already passed, painted BETWEEN the base and the
  /// markers so the sweep never covers a dot or a name.
  void _paintPassedSweep(Canvas canvas, ArcGeometry g) {
    final t = arc.nowFraction.clamp(0.0, 1.0);
    if (t <= 0.001) return;
    if (style == HomeArcStyle.tags) {
      canvas.drawPath(
        g.arcSlice(0, t),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 * g.k
          ..strokeCap = StrokeCap.round
          ..color = theme.passed,
      );
    } else if (style == HomeArcStyle.sky) {
      canvas.drawPath(
        g.arcSlice(0, t),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7 * g.k
          ..strokeCap = StrokeCap.round
          ..shader = _skyShader(g),
      );
    } else {
      _paintCurrentSegment(canvas, g, t);
    }
  }

  void _paintCurrentSegment(Canvas canvas, ArcGeometry g, double t) {
    final markers = arc.markers;
    if (markers.length < 2) return;
    for (var i = 0; i < markers.length - 1; i++) {
      final from = markers[i].fraction;
      final to = markers[i + 1].fraction;
      if (t < from || t > to) continue;
      final color = theme.segmentColors[i % theme.segmentColors.length];
      final start = (from + 0.006).clamp(0.0, 1.0);
      final end = (t - 0.006).clamp(0.0, 1.0);
      if (end > start) {
        canvas.drawPath(
          g.arcSlice(start, end),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 11 * g.k
            ..strokeCap = StrokeCap.butt
            ..color = color,
        );
      }
      return;
    }
  }

  void _paintOrb(Canvas canvas, ArcGeometry g, double t) {
    final at = g.pointAt(t);
    final isSegments = style == HomeArcStyle.segments;
    final radius = isSegments ? 13 * g.k : 12 * g.k;
    if (style == HomeArcStyle.sky && !lite) {
      canvas.drawCircle(
        at,
        22 * g.k,
        Paint()..color = theme.orbRing.withValues(alpha: .14),
      );
      canvas.drawCircle(
        at,
        15 * g.k,
        Paint()..color = theme.orbRing.withValues(alpha: .26),
      );
    } else if (!isSegments) {
      canvas.drawCircle(
        at,
        radius + 4 * g.k,
        Paint()..color = theme.orbRing.withValues(alpha: .18),
      );
    }
    canvas.drawCircle(at, radius, Paint()..color = theme.orbFill);
    canvas.drawCircle(
      at,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (isSegments ? 2.2 : 2) * g.k
        ..color = isSegments ? Colors.white : theme.orbRing,
    );
    _paintGlyph(canvas, at, g, isSegments);
  }

  void _paintGlyph(Canvas canvas, Offset at, ArcGeometry g, bool white) {
    final color = white ? Colors.white : theme.orbRing;
    final r = 5.5 * g.k;
    if (arc.moon) {
      final disc = Path()..addOval(Rect.fromCircle(center: at, radius: r));
      final bite = Path()
        ..addOval(Rect.fromCircle(
          center: at + Offset(2.6 * g.k, -1.8 * g.k),
          radius: r * 0.86,
        ));
      canvas.drawPath(
        Path.combine(PathOperation.difference, disc, bite),
        Paint()..color = color,
      );
      return;
    }
    canvas.drawCircle(at, r * 0.72, Paint()..color = color);
    final ray = Paint()
      ..strokeWidth = 1.2 * g.k
      ..strokeCap = StrokeCap.round
      ..color = color;
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final inner = at + Offset(math.cos(angle), math.sin(angle)) * (r * 0.95);
      final outer = at + Offset(math.cos(angle), math.sin(angle)) * (r * 1.5);
      canvas.drawLine(inner, outer, ray);
    }
  }

  Shader _skyShader(ArcGeometry g, {double alpha = 1}) {
    final colors = [
      for (final color in theme.skyStops)
        alpha >= 1 ? color : color.withValues(alpha: alpha),
    ];
    return ui.Gradient.linear(
      Offset(g.center.dx - g.radius, g.baselineY),
      Offset(g.center.dx + g.radius, g.baselineY),
      colors,
      const [0, .2, .5, .72, .86, 1],
    );
  }

  @override
  bool shouldRepaint(ArcPainter old) {
    // The orb and the passed sweep move once a minute; the static picture only
    // changes at a marker boundary or when a setting changes.
    final before = (old.arc.nowFraction * 1440).round();
    final now = (arc.nowFraction * 1440).round();
    return old.arc != arc ||
        before != now ||
        old.style != style ||
        old.theme != theme ||
        old.textScale != textScale ||
        old.smallLabels != smallLabels ||
        old.lite != lite;
  }
}

/// The two halves of the static art: what the moving sweep may cover (base)
/// and what must sit on top of it (markers and their labels).
class _ArcStatic {
  const _ArcStatic({required this.base, required this.overlay});

  final ui.Picture base;
  final ui.Picture overlay;

  void dispose() {
    base.dispose();
    overlay.dispose();
  }
}

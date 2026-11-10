import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:tawheeed/core/design_system/components/tokens.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

/// ═══════════════════════════════════════════════════════════════
/// Mini charts for the personal tools — ring, horizontal bars, a 7-bar column
/// chart and a segmented day strip.
///
/// Painter-only on purpose. The app already depends on `fl_chart`, but the
/// brief rules out a chart package for these tools and every shape here is a
/// few lines of `Canvas` work. Two performance rules are load-bearing:
///  • no `saveLayer`, no `BackdropFilter`, no `Opacity` widget — alpha lives in
///    the colours themselves;
///  • the painted artwork is wrapped in a `Picture` cache keyed on the data,
///    so a repaint that changes nothing (a parent scrolling a list) does not
///    re-run the geometry.
///
/// All painters are RTL aware: the day strip and the column chart order their
/// categories right-to-left, because Persian reads that way and the app forces
/// RTL inside every one of these screens.
/// ═══════════════════════════════════════════════════════════════

/// A cached painter base: subclasses describe their geometry in
/// [paintPicture]; the picture is rebuilt only when [cacheKey] changes.
abstract class _CachedPainter extends CustomPainter {
  _CachedPainter(this.cacheKey);

  final Object cacheKey;
  ui.Picture? _picture;

  /// Draw into [canvas] with the given size.
  void paintPicture(Canvas canvas, Size size);

  @override
  void paint(Canvas canvas, Size size) {
    final cached = _picture;
    if (cached == null) {
      final recorder = ui.PictureRecorder();
      final c = Canvas(recorder);
      paintPicture(c, size);
      final picture = recorder.endRecording();
      _picture = picture;
      canvas.drawPicture(picture);
      return;
    }
    canvas.drawPicture(cached);
  }

  @override
  bool shouldRepaint(covariant _CachedPainter oldDelegate) =>
      oldDelegate.cacheKey != cacheKey;
}

/// Circular progress ring (parent home child cards, attendance ring).
///
/// [progress] is clamped to 0..1. The track is a flat alpha tint — no opacity
/// widget, so the layer tree stays shallow.
class MiniRing extends StatelessWidget {
  const MiniRing({
    super.key,
    required this.progress,
    required this.color,
    this.size = 54,
    this.stroke = 5,
    this.semanticLabel,
  });

  final double progress;
  final Color color;
  final double size;
  final double stroke;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final p = progress.clamp(0.0, 1.0);
    final widget = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          key: (p, color, stroke, t.outline),
          progress: p,
          color: color,
          outline: t.outline,
          stroke: stroke,
        ),
      ),
    );
    if (semanticLabel == null) return widget;
    return Semantics(
      label: semanticLabel,
      value: '${(p * 100).round()}%',
      child: widget,
    );
  }
}

class _RingPainter extends _CachedPainter {
  _RingPainter({
    required Object key,
    required this.progress,
    required this.color,
    required this.outline,
    required this.stroke,
  }) : super(key);

  final double progress;
  final Color color;
  final Color outline;
  final double stroke;

  @override
  void paintPicture(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - stroke) / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = outline.withValues(alpha: .35)
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = color
      ..strokeCap = StrokeCap.round;
    // Start at 12 o'clock and sweep clockwise; RTL does not mirror a ring
    // (there is no reading direction in a circle), so this stays fixed.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      arc,
    );
  }
}

/// One row of a horizontal bar chart.
class MiniBarItem {
  const MiniBarItem({
    required this.label,
    required this.value,
    required this.max,
    this.color,
  });

  final String label;
  final double value;

  /// Denominator for this row. Each row has its own so a 2-of-5 habit and a
  /// 28-of-35 prayer count can share one chart honestly.
  final double max;
  final Color? color;
}

/// Horizontal progress bars (per-habit completion, mistake tags).
class MiniBars extends StatelessWidget {
  const MiniBars({
    super.key,
    required this.items,
    required this.color,
    this.barHeight = 8,
    this.trailingLabels = true,
  });

  final List<MiniBarItem> items;
  final Color color;
  final double barHeight;

  /// Draw the `value/max` figure at the end of each row.
  final bool trailingLabels;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: DsSpacing.rowGap),
            child: _BarRow(
              item: item,
              color: item.color ?? color,
              track: t.outline,
              textColor: t.textSecondary,
              barHeight: barHeight,
              trailingLabels: trailingLabels,
            ),
          ),
      ],
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.item,
    required this.color,
    required this.track,
    required this.textColor,
    required this.barHeight,
    required this.trailingLabels,
  });

  final MiniBarItem item;
  final Color color;
  final Color track;
  final Color textColor;
  final double barHeight;
  final bool trailingLabels;

  @override
  Widget build(BuildContext context) {
    final ratio = item.max <= 0 ? 0.0 : (item.value / item.max).clamp(0.0, 1.0);
    return Semantics(
      label: item.label,
      value: '${item.value.round()} / ${item.max.round()}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    color: textColor,
                  ),
                ),
              ),
              if (trailingLabels)
                Text(
                  '${item.value.round()}/${item.max.round()}',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    color: textColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // A plain Container pair rather than a painter: two rounded rects are
          // cheaper to lay out than a CustomPaint + Picture here, and this row
          // repeats many times inside one list.
          ClipRRect(
            borderRadius: BorderRadius.circular(barHeight / 2),
            child: Stack(
              children: [
                Container(
                  height: barHeight,
                  color: track.withValues(alpha: .30),
                ),
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(barHeight / 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A 7-column chart (the weekly report). Column index 0 is the FIRST day of
/// the period as the caller ordered it; the painter maps index 0 to the
/// right-most column so the chart reads RTL.
class MiniColumnChart extends StatelessWidget {
  const MiniColumnChart({
    super.key,
    required this.values,
    required this.labels,
    required this.color,
    this.height = 110,
    this.maxValue,
    this.semanticSummary,
  });

  final List<int> values;
  final List<String> labels;
  final Color color;
  final double height;

  /// Fixed ceiling; when null the chart scales to the largest value.
  final int? maxValue;
  final String? semanticSummary;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final chart = SizedBox(
      height: height,
      child: CustomPaint(
        painter: _ColumnPainter(
          key: (values.join(','), labels.join(','), color, t.outline,
              t.textMuted, maxValue),
          values: values,
          labels: labels,
          color: color,
          track: t.outline,
          labelColor: t.textMuted,
          maxValue: maxValue,
        ),
      ),
    );
    if (semanticSummary == null) return chart;
    return Semantics(label: semanticSummary, child: chart);
  }
}

class _ColumnPainter extends _CachedPainter {
  _ColumnPainter({
    required Object key,
    required this.values,
    required this.labels,
    required this.color,
    required this.track,
    required this.labelColor,
    required this.maxValue,
  }) : super(key);

  final List<int> values;
  final List<String> labels;
  final Color color;
  final Color track;
  final Color labelColor;
  final int? maxValue;

  @override
  void paintPicture(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const labelBand = 16.0;
    final plotHeight = math.max(0.0, size.height - labelBand);

    final peak = maxValue ?? values.reduce(math.max);
    final ceiling = peak <= 0 ? 1 : peak;

    final slot = size.width / values.length;
    final barWidth = math.min(slot * .58, 22.0);

    final trackPaint = Paint()..color = track.withValues(alpha: .22);
    final barPaint = Paint()..color = color;

    for (var i = 0; i < values.length; i++) {
      // RTL: index 0 lands at the right edge.
      final slotLeft = size.width - slot * (i + 1);
      final cx = slotLeft + slot / 2;
      final left = cx - barWidth / 2;

      // The faint full-height track makes a zero day read as "nothing done"
      // rather than "chart broke".
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, 0, barWidth, plotHeight),
          const Radius.circular(4),
        ),
        trackPaint,
      );

      final ratio = (values[i] / ceiling).clamp(0.0, 1.0);
      if (ratio <= 0) continue;
      final h = plotHeight * ratio;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, plotHeight - h, barWidth, h),
          const Radius.circular(4),
        ),
        barPaint,
      );
    }

    // Day letters under the columns.
    if (labels.isNotEmpty) {
      for (var i = 0; i < values.length && i < labels.length; i++) {
        final slotLeft = size.width - slot * (i + 1);
        final tp = TextPainter(
          text: TextSpan(
            text: labels[i],
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 10,
              color: labelColor,
            ),
          ),
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.center,
        )..layout(maxWidth: slot);
        tp.paint(
          canvas,
          Offset(slotLeft + (slot - tp.width) / 2, plotHeight + 2),
        );
      }
    }
  }
}

/// One segment of the day strip (attendance or habit history).
class DayStripSegment {
  const DayStripSegment({
    required this.letter,
    required this.state,
  });

  final String letter;
  final DayStripState state;
}

enum DayStripState {
  /// Nothing scheduled / not applicable.
  none,

  /// Scheduled but not done.
  missed,

  /// Done.
  done,

  /// Partially done (some habits of the day).
  partial,

  /// Explicitly excused (attendance).
  excused,
}

/// A compact RTL strip of day cells (the 7-day history, the attendance tail).
class DayStrip extends StatelessWidget {
  const DayStrip({
    super.key,
    required this.segments,
    required this.color,
    this.cell = 22,
    this.semanticSummary,
  });

  final List<DayStripSegment> segments;
  final Color color;
  final double cell;
  final String? semanticSummary;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final success = DsStatus.success(context);
    final warning = DsStatus.warning(context);
    final danger = DsStatus.danger(context);
    final strip = SizedBox(
      height: cell + 14,
      child: CustomPaint(
        painter: _StripPainter(
          key: (
            segments.map((s) => '${s.letter}${s.state.index}').join('|'),
            color,
            t.outline,
            t.textMuted,
            success,
            warning,
            danger,
            cell,
          ),
          segments: segments,
          color: color,
          outline: t.outline,
          labelColor: t.textMuted,
          success: success,
          warning: warning,
          danger: danger,
          cell: cell,
        ),
      ),
    );
    if (semanticSummary == null) return strip;
    return Semantics(label: semanticSummary, child: strip);
  }
}

class _StripPainter extends _CachedPainter {
  _StripPainter({
    required Object key,
    required this.segments,
    required this.color,
    required this.outline,
    required this.labelColor,
    required this.success,
    required this.warning,
    required this.danger,
    required this.cell,
  }) : super(key);

  final List<DayStripSegment> segments;
  final Color color;
  final Color outline;
  final Color labelColor;
  final Color success;
  final Color warning;
  final Color danger;
  final double cell;

  @override
  void paintPicture(Canvas canvas, Size size) {
    if (segments.isEmpty) return;
    const gap = 4.0;
    final available = size.width - gap * (segments.length - 1);
    final w = math.min(cell, available / segments.length);

    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      // RTL: index 0 at the right.
      final left = size.width - w * (i + 1) - gap * i;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, 0, w, w),
        Radius.circular(w * .3),
      );
      canvas.drawRRect(rect, Paint()..color = _fill(seg.state));

      if (seg.state != DayStripState.none) {
        final tp = TextPainter(
          text: TextSpan(
            text: seg.letter,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _ink(seg.state),
            ),
          ),
          textDirection: TextDirection.rtl,
        )..layout();
        tp.paint(canvas, Offset(left + (w - tp.width) / 2, (w - tp.height) / 2));
      }
    }
  }

  Color _fill(DayStripState state) => switch (state) {
        DayStripState.none => outline.withValues(alpha: .18),
        DayStripState.missed => danger.withValues(alpha: .14),
        DayStripState.done => success.withValues(alpha: .20),
        DayStripState.partial => warning.withValues(alpha: .20),
        DayStripState.excused => color.withValues(alpha: .12),
      };

  Color _ink(DayStripState state) => switch (state) {
        DayStripState.none => labelColor,
        DayStripState.missed => danger,
        DayStripState.done => success,
        DayStripState.partial => warning,
        DayStripState.excused => color,
      };
}

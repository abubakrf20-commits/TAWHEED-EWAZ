import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/settings/presentation/widgets/widget_design_tokens.dart';

/// Settings-page mirror of the native `TasbihGlanceWidget` composition: the
/// same scaled sizes, the same palette roles (accent on the arc and the number,
/// green for the whole completed state) and the same beaded ring. Keep the two
/// in step — a preview that drifts teaches the user a widget they are not about
/// to get.
class TasbihWidgetPreview extends StatelessWidget {
  final String dhikr;
  final int count;
  final int target;

  /// The zikr's position in the list — «2/5 ·» leads the caption only when
  /// there is a choice.
  final int zikrIndex;
  final int zikrCount;

  /// The day's total across every zikr (the native widget sums its per-zikr
  /// counters, which all reset at midnight), rendered «امروز N» after the
  /// position. Always present, so the line never pops in and out.
  final int todayCount;
  final Color bgColor;
  final Color bgEndColor;
  final Color textColor;
  final Color accentColor;

  /// The palette's light flag — the success green darkens on cream so it stays
  /// legible, exactly as `TasbihGlanceWidget.countColor` does.
  final bool light;
  final double opacity;
  final double cornerRadius;

  const TasbihWidgetPreview({
    super.key,
    this.dhikr = 'الله أكبر',
    this.count = 0,
    this.target = 100,
    this.zikrIndex = 0,
    this.zikrCount = 1,
    this.todayCount = 0,
    this.bgColor = const Color(0xFF3B2316),
    this.bgEndColor = const Color(0xFF2A1A10),
    this.textColor = const Color(0xFFF5EDE3),
    this.accentColor = const Color(0xFFC9A94E),
    this.light = false,
    this.opacity = 1.0,
    this.cornerRadius = WidgetTokens.widgetRadius,
  });

  // Both track the app's done/completed green so the preview never drifts
  // from the real widget (which reads AppPalette.emerald for the completed
  // state).
  static const Color _successGreen = AppPalette.emerald;
  static const Color _successGreenLight = AppPalette.emerald;

  @override
  Widget build(BuildContext context) {
    // The native scale rule: 1.0 at the 200 dp default, clamped both ways.
    final scale = (math.min(WidgetTokens.widgetMediumWidth,
            WidgetTokens.widgetMediumHeight) /
            200.0)
        .clamp(0.7, 1.5);

    final isComplete = target > 0 && count >= target;
    final success = light ? _successGreenLight : _successGreen;
    // One colour for the whole completed state: arc, number and badge.
    final accent = isComplete ? success : accentColor;
    final progress = target > 0 ? (count / target).clamp(0.0, 1.0) : 0.0;

    final effectiveBg = bgColor.withValues(alpha: opacity);
    final effectiveBgEnd = bgEndColor.withValues(alpha: opacity);
    final dimText = textColor.withValues(alpha: 0.5);

    final dhikrSize = (10.5 * scale).clamp(9.0, 14.0);
    final countSize = (33 * scale).clamp(22.0, 46.0);
    final targetSize = (8.2 * scale).clamp(8.0, 12.0);
    final buttonHeight = (28 * scale).clamp(28.0, 36.0);
    // The pills keep their airy height; each sits inside the 44 dp touch
    // wrapper the native `_hit` frames use.
    final touchHeight = buttonHeight + 16.0;
    final chevronSize = (15.5 * scale).clamp(14.0, 22.0);
    final resetSize = (15.5 * scale).clamp(13.0, 21.0);
    // «حلقهٔ نزدیک»: the same height-budget clamp the native render applies
    // at this card's nominal 320×220 — the fixed type stack and the badge
    // block come out of the height first, the ring box takes the rest
    // (102 dp × scale is the ideal).
    final captionSize = (9 * scale).clamp(7.0, 11.0).toDouble();
    final fixedStack = 16.0 +
        3.0 +
        dhikrSize * 1.35 +
        1.0 +
        captionSize * 1.35 +
        6.0 +
        touchHeight +
        2.0;
    final budget = WidgetTokens.widgetMediumHeight - fixedStack;
    final badgeBlock = 9.0 + (targetSize * 1.35 + 6.0);
    final boxWithBadge = budget - badgeBlock;
    final ringBox = (boxWithBadge < 64.0
            ? math.min(102.0 * scale, math.max(36.0, budget))
            : math.min(102.0 * scale, boxWithBadge))
        .toDouble();

    return Container(
      width: WidgetTokens.widgetMediumWidth,
      height: WidgetTokens.widgetMediumHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [effectiveBg, effectiveBgEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(cornerRadius),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(WidgetTokens.sm),
      child: Column(
        children: [
          Text(
            dhikr,
            style: TextStyle(
              fontSize: dhikrSize,
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            // «2/5 · امروز 123» — the same template the native render
            // builds; with a single zikr only the day total remains.
            '${zikrCount > 1 ? '${zikrIndex + 1}/$zikrCount · ' : ''}'
            'امروز $todayCount',
            style: TextStyle(
              fontSize: captionSize,
              color: dimText,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: ringBox,
                    height: ringBox,
                    child: CustomPaint(
                      painter: _RingPainter(
                        progressColor: accent,
                        progress: progress,
                        light: light,
                      ),
                      child: Center(
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: countSize,
                            fontWeight: FontWeight.bold,
                            color: accent,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  _targetBadge(
                    isComplete: isComplete,
                    accent: accent,
                    // 0.62 mirrors the native badge (0.5 read disabled).
                    idleText: textColor.withValues(alpha: 0.62),
                    targetSize: targetSize,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _button('‹', accent, accent.withValues(alpha: 0.16),
                  buttonHeight, touchHeight, chevronSize),
              const SizedBox(width: 3),
              _button(
                  '↻',
                  accent.withValues(alpha: 0.92),
                  accent.withValues(alpha: 0.11),
                  buttonHeight,
                  touchHeight,
                  resetSize),
              const SizedBox(width: 3),
              _button('›', accent, accent.withValues(alpha: 0.16),
                  buttonHeight, touchHeight, chevronSize),
            ],
          ),
        ],
      ),
    );
  }

  Widget _targetBadge({
    required bool isComplete,
    required Color accent,
    required Color idleText,
    required double targetSize,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isComplete ? 0.16 : 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isComplete ? '✓ کامل شد' : 'از $target',
        style: TextStyle(
          fontSize: targetSize,
          // Completed reads in the success colour; the plain target sits back
          // so the number stays the loudest thing inside the arc.
          color: isComplete ? accent : idleText,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// The pill keeps its airy height, and a 44 dp wrapper around it carries
  /// the touch target — the same split as the native `_hit` frames.
  Widget _button(String glyph, Color color, Color fill, double pillHeight,
      double touchHeight, double fontSize) {
    return Expanded(
      child: SizedBox(
        height: touchHeight,
        child: Center(
          child: Container(
            width: double.infinity,
            height: pillHeight,
            decoration: BoxDecoration(
              color: fill,
              // 12 — mirrors the native applyRoundedTint radius (12 dp).
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                glyph,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-circle ring, mirroring the native `createTasbihRingBitmap`: the
/// accent track sits under a rest ring of beads and the progress arc, which
/// ends on a leading bead — the complete, beaded circle is the approved
/// redesign (2026-10-17) and the same composition as the app dial's
/// `_BeadRingPainter`.
class _RingPainter extends CustomPainter {
  final Color progressColor;
  final double progress;
  final bool light;

  _RingPainter({
    required this.progressColor,
    required this.progress,
    required this.light,
  });

  static const _beadCount = 40;

  @override
  void paint(Canvas canvas, Size size) {
    // Native rule: stroke = 5.65 % of the ring, never under ~6 dp.
    final strokeWidth =
        (size.shortestSide * 0.0565).clamp(6.0, size.shortestSide / 3);
    final half = size.shortestSide / 2;
    // The leading bead bulges past the arc's round cap, so it sets the
    // outermost edge; the margin keeps it inside the box.
    final leadRadius = strokeWidth * 0.66;
    final radius = half - math.max(strokeWidth / 2, leadRadius) - 1.25;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    // The whole circle first — the arc is ink on top of the ring. Same
    // 0.22 alpha as the native track paint.
    final trackPaint = Paint()
      ..color = progressColor.withValues(alpha: 0.22)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, trackPaint);

    // The rest ring is beads, lit up to the count — the native bitmap's
    // 40-bead ring, same 90 % lit alpha and same rest tones.
    final beadRadius = size.shortestSide * 0.011;
    final litCount = (progress * _beadCount).round();
    final litPaint = Paint()..color = progressColor.withValues(alpha: 0.90);
    final restPaint = Paint()
      ..color = progressColor.withValues(alpha: light ? 0.28 : 0.32);
    for (var i = 0; i < _beadCount; i++) {
      final a = -math.pi / 2 + 2 * math.pi * i / _beadCount;
      canvas.drawCircle(
        center + Offset(math.cos(a), math.sin(a)) * radius,
        beadRadius,
        i < litCount ? litPaint : restPaint,
      );
    }

    if (progress > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
          rect, -math.pi / 2, 2 * math.pi * progress, false, progressPaint);

      // Leading bead riding the arc's tip, full accent like the arc.
      final end = -math.pi / 2 + 2 * math.pi * progress;
      canvas.drawCircle(
        center + Offset(math.cos(end), math.sin(end)) * radius,
        leadRadius,
        Paint()..color = progressColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress ||
      old.progressColor != progressColor ||
      old.light != light;
}

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/app/state/clock_providers.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/app_colors.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/home/presentation/providers/arc_style_provider.dart';
import 'package:tawheeed/features/home/presentation/widgets/arc/arc_theme.dart';
import 'package:tawheeed/features/home/presentation/widgets/arc/home_arc.dart';
import 'package:tawheeed/features/prayer/domain/prayer_clock.dart';

/// «نمای قوس صفحه اصلی» — pick one of the three arc styles for the home hero.
///
/// The preview under the cards is the real arc with the real snapshot, drawn by
/// the same painter the hero uses, so what the reader picks is what they get.
/// Selection applies immediately (the hero watches the same provider).
class ArcStyleScreen extends ConsumerWidget {
  const ArcStyleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(homeArcPrefsProvider);
    final clock = ref.watch(prayerClockProvider);
    final lite = ref.watch(liteModeProvider).value ?? false;
    final textScale =
        (MediaQuery.maybeOf(context)?.textScaler.scale(1) ?? 1.0).clamp(1.0, 1.3);
    final gold = AppColors.strongAccent(context, AppTheme.lightTertiary);

    return Scaffold(
      appBar: const SectionAppBar(title: 'نمای قوس صفحه اصلی'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(
            'قوس اوقات شرعی در بالای صفحهٔ خانه به سه شکل نمایش داده می‌شود. '
            'انتخاب شما برای همهٔ روزها ذخیره می‌شود.',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 12),
              height: 1.9,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final style in HomeArcStyle.values) ...[
                Expanded(
                  child: _StyleCard(
                    style: style,
                    selected: prefs.style == style,
                    onTap: () => prefs.setStyle(style),
                    gold: gold,
                  ),
                ),
                if (style != HomeArcStyle.values.last) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _Preview(
            style: prefs.style,
            clock: clock,
            smallLabels: prefs.smallLabels,
            textScale: textScale,
            lite: lite,
          ),
          const SizedBox(height: 16),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'نمایش نام نشانگرهای کوچک',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 13),
                ),
              ),
              subtitle: Text(
                'طلوع، ضحی، نیمه‌شب و ثلث آخر (در نمای برچسب‌دار و آسمان)',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  color: AppColors.textMuted(context),
                ),
              ),
              value: prefs.smallLabels,
              onChanged: prefs.setSmallLabels,
            ),
          ),
        ],
      ),
    );
  }
}

class _StyleCard extends StatelessWidget {
  const _StyleCard({
    required this.style,
    required this.selected,
    required this.onTap,
    required this.gold,
  });

  final HomeArcStyle style;
  final bool selected;
  final VoidCallback onTap;
  final Color gold;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppTheme.darkOutline : const Color(0xFFEADFCC);
    return Semantics(
      button: true,
      selected: selected,
      label: style.label,
      child: Material(
        color: selected
            ? const Color(0xFF243056)
            : (isDark ? Colors.white.withValues(alpha: .04) : Colors.white),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? const Color(0xFF243056) : border,
                width: 0.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 34,
                  child: CustomPaint(
                    painter: _ArcThumbPainter(style: style),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (selected) ...[
                      Icon(Icons.check_circle_rounded, size: 13, color: gold),
                      const SizedBox(width: 3),
                    ],
                    Flexible(
                      child: Text(
                        style.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 11.5),
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? const Color(0xFFFCF8EF)
                              : AppColors.textPrimary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A markers-only miniature of one style: no text, so it reads at 34dp.
class _ArcThumbPainter extends CustomPainter {
  const _ArcThumbPainter({required this.style});

  final HomeArcStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final theme = ArcTheme.resolve(true);
    // A frame-local semicircle: radius fits both the width and the thumb's
    // height, so the miniature never needs the hero's design space.
    final radius = math.min(size.width / 2, size.height) - 2;
    if (radius <= 1) return;
    final center = Offset(size.width / 2, size.height - 1);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final stroke = (style == HomeArcStyle.segments ? 5.0 : 2.6) *
        (radius / 40).clamp(0.6, 1.6);

    Path slice(double from, double to) => Path()
      ..addArc(rect, math.pi * (1 - from), -math.pi * (to - from));

    if (style == HomeArcStyle.segments) {
      const count = 9;
      for (var i = 0; i < count; i++) {
        final color = theme.segmentColors[i % theme.segmentColors.length];
        canvas.drawPath(
          slice(i / count + 0.006, (i + 1) / count - 0.006),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.butt
            ..color = color.withValues(alpha: .75),
        );
      }
    } else if (style == HomeArcStyle.sky) {
      canvas.drawPath(
        slice(0, 1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke * 1.6
          ..strokeCap = StrokeCap.round
          ..shader = ui.Gradient.linear(
            Offset(center.dx - radius, center.dy),
            Offset(center.dx + radius, center.dy),
            theme.skyStops,
            const [0, .2, .5, .72, .86, 1],
          ),
      );
    } else {
      canvas.drawPath(
        slice(0, 1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = theme.track,
      );
    }

    final dot = Paint()..color = theme.passed;
    for (var i = 0; i <= 9; i++) {
      final angle = math.pi * (1 - i / 9);
      canvas.drawCircle(
        center + Offset(math.cos(angle), -math.sin(angle)) * radius,
        style == HomeArcStyle.segments ? 1.6 : 1.9,
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcThumbPainter old) => old.style != style;
}

/// The hero-like card under the cards: the real arc, current data.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.style,
    required this.clock,
    required this.smallLabels,
    required this.textScale,
    required this.lite,
  });

  final HomeArcStyle style;
  final PrayerClock? clock;
  final bool smallLabels;
  final double textScale;
  final bool lite;

  @override
  Widget build(BuildContext context) {
    final arc = clock?.value.arc;
    final palette = TimeThemeKit.of(context).palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            palette.heroTop,
            palette.heroMid,
            palette.heroBottom,
          ],
        ),
      ),
      child: Column(
        children: [
          Text(
            'پیش‌نمایش',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 11),
              color: AppPalette.cream.withValues(alpha: .8),
            ),
          ),
          const SizedBox(height: 8),
          if (arc == null)
            SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  'در حال محاسبهٔ اوقات شرعی…',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    color: AppPalette.cream.withValues(alpha: .85),
                  ),
                ),
              ),
            )
          else
            HomeArc(
              arc: arc,
              style: style,
              smallLabels: smallLabels,
              textScale: textScale,
              lite: lite,
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/worship/presentation/utils/report_tier_colors.dart';

/// A single row of the monthly evaluation report (label + done/total).
class ReportProgressRow {
  final String label;

  /// Null when the reading is unknown (query failed) — rendered as «—» so a
  /// shared report never claims a zero the user did not actually score.
  final int? done;
  final int total;

  const ReportProgressRow(this.label, this.done, this.total);
}

/// Share-friendly monthly evaluation report card. Rendered offscreen at a
/// fixed width by [shareWidgetAsImage], so it stays self-contained (no
/// scrolling, no state) and reproduces the monthly tab's key numbers.
class EvaluationReportCard extends StatelessWidget {
  final String monthLabel;
  final int score;
  final int maxScore;
  final String rating;
  final int activeDays;
  final int totalDays;
  final int streak;
  final List<ReportProgressRow> rows;

  const EvaluationReportCard({
    super.key,
    required this.monthLabel,
    required this.score,
    required this.maxScore,
    required this.rating,
    required this.activeDays,
    required this.totalDays,
    required this.streak,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final percent = maxScore > 0 ? (score / maxScore * 100).clamp(0, 100) : 0.0;
    final goldInk = dsContentColor(context, AppPalette.goldDark);
    final ratingInk = ReportTierColors.ink(context, rating);

    return AppCard(
      radius: 20,
      padding: const EdgeInsets.all(22),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header band — the phase hero gradient, matching the redesigned
            // screens' language.
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CustomPaint(
                painter: HeroGradientPainter(t, false),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.self_improvement,
                            color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'گزارش عملکرد ماهانه',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: AppTheme.scaledFontSize(context, 17),
                                fontWeight: FontWeight.w800,
                                color: AppPalette.cream,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              monthLabel,
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: AppTheme.scaledFontSize(context, 13),
                                color: AppPalette.cream.withValues(alpha: .9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Score + rating
            Row(
              children: [
                Expanded(
                  child: _statBox(
                      context, 'امتیاز ماه', '$score/$maxScore', goldInk),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statBox(context, 'ارزیابی', rating, ratingInk),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statBox(context, 'روزهای فعال',
                      '$activeDays/$totalDays', goldInk),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child:
                      _statBox(context, 'رکورد زنجیره', '$streak روز', goldInk),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: t.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'پیشرفت',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 11),
                            color: t.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percent / 100,
                            minHeight: 8,
                            backgroundColor: t.tertiary.withValues(alpha: .15),
                            valueColor: AlwaysStoppedAnimation(t.tertiary),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${percent.toStringAsFixed(1)}٪',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 11),
                            fontWeight: FontWeight.w700,
                            color: goldInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Detail rows
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Text(
                      r.label,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 12.5),
                        color: t.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      r.done == null ? '—' : '${r.done}/${r.total}',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 12.5),
                        fontWeight: FontWeight.w700,
                        color: goldInk,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),
            Divider(color: t.outline.withValues(alpha: .5)),
            const SizedBox(height: 8),
            Text(
              'برنامهٔ جامع توحید — ارزیابی عبادات',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 11),
                color: t.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBox(BuildContext context, String label, String value, Color ink) {
    final t = TimeThemeKit.of(context).palette;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 10.5),
              color: t.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 13),
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
        ],
      ),
    );
  }
}

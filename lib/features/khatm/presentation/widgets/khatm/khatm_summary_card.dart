import 'package:flutter/material.dart';
import 'package:tawheeed/features/khatm/data/models/khatm_model.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

class KhatmSummaryCard extends StatelessWidget {
  final KhatmModel khatm;
  final int daysElapsed;
  final double avgPerDay;
  const KhatmSummaryCard({
    super.key,
    required this.khatm,
    required this.daysElapsed,
    required this.avgPerDay,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pct = (khatm.progress * 100).round();
    const accent = TopicHues.khatm;
    final remaining = khatm.remainingPages;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    final warning = isDark ? AppTheme.darkWarning : AppTheme.lightWarning;
    final error = isDark ? AppTheme.darkError : AppTheme.lightError;

    final today = KhatmModel.dateKeyOf(DateTime.now());
    final pagesToday = khatm.pagesOn(today);
    final target = khatm.dailyTarget;
    final todayPct = target > 0 ? (pagesToday / target).clamp(0.0, 1.0) : 0.0;
    final doneToday = todayPct >= 1.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accent.withValues(alpha: 0.28)),
                ),
                child: const Icon(Icons.menu_book, size: 15, color: accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'پیشرفت ختم',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12.5),
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accent.withValues(alpha: 0.28)),
                ),
                child: Text(
                  '$pct%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    color: dsContentColor(context, accent),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: khatm.progress,
              minHeight: 5,
              backgroundColor: t.divider,
              valueColor: AlwaysStoppedAnimation<Color>(
                  khatm.isCompleted ? success : accent),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${khatm.readPages} از ${khatm.totalPages} صفحه خوانده شده',
                      style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 13),
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      khatm.isCompleted
                          ? 'ختم قرآن به پایان رسید 🎉'
                          : doneToday
                              ? 'هدف امروز تکمیل شد 🎉'
                              : 'امروز $pagesToday از $target صفحه خوانده‌اید',
                      style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 10.5),
                        fontWeight: FontWeight.w600,
                        color: doneToday ? success : t.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              KhatmInlineStat(
                icon: Icons.flag_outlined,
                label: 'هدف روز',
                value: '$target',
                color: warning,
              ),
              KhatmInlineStat(
                icon: Icons.trending_up,
                label: 'میانگین',
                value: avgPerDay.toStringAsFixed(1),
                color: dsContentColor(context, accent),
              ),
              KhatmInlineStat(
                icon: Icons.menu_book_outlined,
                label: 'باقی‌مانده',
                value: '$remaining',
                color: error,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class KhatmInlineStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const KhatmInlineStat({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 9.5),
                color: t.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 12.5),
              fontWeight: FontWeight.w800,
              color: dsContentColor(context, color),
            ),
          ),
        ],
      ),
    );
  }
}

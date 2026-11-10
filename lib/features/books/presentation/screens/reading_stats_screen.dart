import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:tawheeed/core/error/error_boundary.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/books/presentation/providers/reading_stats_provider.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

class ReadingStatsScreen extends ConsumerWidget {
  const ReadingStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(readingStatsProvider);
    final totalAsync = ref.watch(readingTotalProvider);
    final streakAsync = ref.watch(readingStreakProvider);
    final minutesAsync = ref.watch(readingMinutesTotalProvider);

    void retryAll() {
      ref.invalidate(readingStatsProvider);
      ref.invalidate(readingTotalProvider);
      ref.invalidate(readingStreakProvider);
      ref.invalidate(readingMinutesTotalProvider);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const SectionAppBar(title: 'آمار مطالعه'),
      body: statsAsync.when(
        data: (stats) {
          // Unknown is not zero: an int that never loaded must not read as
          // «no pages / no streak» when the totals may be non-empty.
          final total = totalAsync.asData?.value;
          final streak = streakAsync.asData?.value;
          final minutes = minutesAsync.asData?.value;
          // A rate only means something once both halves are known and the
          // denominator is not zero.
          final rate = (total != null && minutes != null && minutes > 0)
              ? (total / minutes).toStringAsFixed(1)
              : '—';
          final days = stats.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _StatCard(
                        icon: Icons.menu_book,
                        label: 'کل صفحات',
                        value: total == null ? '—' : '$total',
                        color: TimeThemeKit.of(context).palette.primary),
                    const SizedBox(width: 12),
                    _StatCard(
                        icon: Icons.local_fire_department,
                        label: 'روزهای پیاپی',
                        value: streak == null ? '—' : '$streak',
                        color: danger),
                    const SizedBox(width: 12),
                    _StatCard(
                        icon: Icons.today,
                        label: 'روزهای فعال',
                        value: '${days.length}',
                        color: success),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _StatCard(
                        icon: Icons.schedule,
                        label: 'زمان مطالعه (دقیقه)',
                        value: minutes == null
                            ? '—'
                            : NumberFormat.formatPlain(minutes.toDouble()),
                        color: TopicHues.ketabkhaneh),
                    const SizedBox(width: 12),
                    _StatCard(
                        icon: Icons.speed,
                        label: 'صفحه در دقیقه',
                        value: rate,
                        color: TimeThemeKit.of(context).palette.primary),
                  ],
                ),
                if (totalAsync.hasError ||
                    streakAsync.hasError ||
                    minutesAsync.hasError) ...[
                  const SizedBox(height: 8),
                  // Inline: the stat cards above it are still real, so this
                  // must say *which* claim is missing rather than replacing the
                  // page. «بخشی از آمار» is the honest word for it.
                  FailureView(
                    id: 'reading_stats_partial',
                    title: 'بخشی از آمار بارگذاری نشد',
                    detail: 'کارت‌هایی که می‌بینید از آخرین خواندن موفق‌اند.',
                    onRetry: retryAll,
                    layout: FailureLayout.inline,
                  ),
                ],
                const SizedBox(height: 24),
                Text('آخرین 30 روز',
                    style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w700,
                        fontFamily: AppTheme.fontFamily)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 220,
                  child: days.isEmpty
                      ? Center(
                          child: Text('هنوز آماری ثبت نشده',
                              style: TextStyle(
                                  color: TimeThemeKit.of(context).palette.textMuted,
                                  fontFamily: AppTheme.fontFamily)))
                      : BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: (days
                                        .map((e) => e.value)
                                        .reduce((a, b) => a > b ? a : b) *
                                    1.3)
                                .ceilToDouble(),
                            barTouchData: BarTouchData(
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipColor: (_) => TimeThemeKit.of(context).palette.card,
                                getTooltipItem:
                                    (group, groupIndex, rod, rodIndex) =>
                                        BarTooltipItem(
                                  '${days[groupIndex].key}\n${rod.toY.toInt()} صفحه',
                                  TextStyle(
                                      color: TimeThemeKit.of(context).palette.textPrimary,
                                      fontSize: AppTheme.scaledFontSize(context, 11),
                                      fontFamily: AppTheme.fontFamily),
                                ),
                              ),
                            ),
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        final idx = value.toInt();
                                        if (idx < 0 || idx >= days.length) {
                                          return const SizedBox();
                                        }
                                        final date = days[idx].key;
                                        final parts = date.split('-');
                                        final day =
                                            parts.length == 3 ? parts[2] : date;
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Text(day,
                                              style: TextStyle(
                                                  fontSize: AppTheme.scaledFontSize(context, 9),
                                                  color: TimeThemeKit.of(context).palette.textMuted,
                                                  fontFamily:
                                                      AppTheme.fontFamily)),
                                        );
                                      })),
                              leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 30,
                                      getTitlesWidget: (value, meta) {
                                        if (value == 0) return const SizedBox();
                                        return Text('${value.toInt()}',
                                            style: TextStyle(
                                                fontSize: AppTheme.scaledFontSize(context, 10),
                                                color: TimeThemeKit.of(context).palette.textMuted,
                                                fontFamily:
                                                    AppTheme.fontFamily));
                                      })),
                              topTitles: const AxisTitles(),
                              rightTitles: const AxisTitles(),
                            ),
                            borderData: FlBorderData(show: false),
                            barGroups: days
                                .asMap()
                                .entries
                                .map((e) => BarChartGroupData(
                                      x: e.key,
                                      barRods: [
                                        BarChartRodData(
                                          toY: e.value.value.toDouble(),
                                          color: TimeThemeKit.of(context).palette.primary,
                                          width: days.length > 20 ? 6 : 12,
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                  top: Radius.circular(4)),
                                        )
                                      ],
                                    ))
                                .toList(),
                            gridData: FlGridData(
                              drawVerticalLine: false,
                              horizontalInterval: 1,
                              getDrawingHorizontalLine: (value) => FlLine(
                                  color: TimeThemeKit.of(context).palette.divider,
                                  strokeWidth: 0.5),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, stack) => AppErrorDisplay(
            error: e,
            stackTrace: stack,
            message: 'خطا در بارگذاری آمار مطالعه',
            onRetry: retryAll),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 18),
                    fontWeight: FontWeight.w800,
                    color: color,
                    fontFamily: AppTheme.fontFamily)),
            Text(label,
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 10),
                    color: TimeThemeKit.of(context).palette.textMuted,
                    fontFamily: AppTheme.fontFamily)),
          ],
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/tools/pomodoro/presentation/pomodoro_constants.dart';

const _modeClassicColor = pomodoroAccent;
const _modeCountdownColor = countdownAccent;

/// The «تاریخچهٔ جلسات» block: summary of today, per-focus-type totals for
/// the shown history window, a 7-day bar chart and the recent session rows.
class SessionHistorySection extends StatelessWidget {
  const SessionHistorySection({
    super.key,
    required this.todayMinutes,
    required this.history,
    required this.weekTotals,
    required this.loading,
    required this.onClearHistory,
    this.error,
    this.onRetry,
  });

  final int todayMinutes;
  final List<PomodoroSessionTableData> history;
  final List<int> weekTotals;
  final bool loading;
  final VoidCallback onClearHistory;

  /// Failure of the last history read. While it is set the summary cards are
  /// suppressed — they would otherwise print a zero the read never proved.
  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = t.textPrimary;
    final mutedColor = t.textMuted;
    final loadError = error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history, size: 18, color: pomodoroAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'تاریخچهٔ جلسات',
                style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 15),
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ),
            if (history.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: 'پاک کردن تاریخچه',
                color: mutedColor,
                visualDensity: VisualDensity.compact,
                onPressed: onClearHistory,
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (loadError != null)
          _HistoryError(
            hasRows: history.isNotEmpty,
            retrying: loading,
            onRetry: onRetry,
          )
        else ...[
          _TodayCard(
            todayMinutes: todayMinutes,
            historyCount: history.length,
            isDark: isDark,
          ),
          if (history.isNotEmpty) ...[
            _FocusBreakdown(history: history),
            if (weekTotals.any((v) => v > 0)) ...[
              _WeekChart(weekTotals: weekTotals),
            ],
          ],
        ],
        const SizedBox(height: 10),
        if (loading && loadError == null)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          )
        else
          for (final s in history) _SessionRow(session: s),
        const SizedBox(height: 4),
      ],
    );
  }
}

/// Compact inline failure for the history block.
///
/// Inline rather than `page`: the rows from the last good read are still on
/// screen below it, so this must not take the whole block. It also has to say
/// *which* read failed — «به‌روزرسانی» when stale rows are showing, «بارگذاری»
/// when there are none — because the two mean different things about how much
/// the reader can trust what they see.
class _HistoryError extends StatelessWidget {
  const _HistoryError({
    required this.hasRows,
    required this.retrying,
    required this.onRetry,
  });

  final bool hasRows;
  final bool retrying;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return FailureView(
      id: 'pomodoro_history',
      title: hasRows
          ? 'به‌روزرسانی تاریخچه ممکن نشد'
          : 'بارگذاری تاریخچهٔ جلسات ممکن نشد',
      detail: hasRows
          ? 'جلسه‌های نمایش‌داده‌شده از آخرین بارگذاری‌اند.'
          : null,
      onRetry: onRetry,
      retrying: retrying,
      layout: FailureLayout.inline,
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.todayMinutes,
    required this.historyCount,
    required this.isDark,
  });

  final int todayMinutes;
  final int historyCount;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    const accent = pomodoroAccent;
    final t = TimeThemeKit.of(context).palette;
    final mutedColor = t.textMuted;
    final textColor = t.textPrimary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(14),
            ),
            child:
                const Icon(Icons.timer_outlined, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${faDigits(todayMinutes)} دقیقه',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                    fontSize: AppTheme.scaledFontSize(context, 19),
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  historyCount == 0
                      ? 'هنوز جلسه‌ای ثبت نشده — اولین جلسهٔ تمرکز شما اینجا می‌آید.'
                      : 'تمرکز امروز · هر جلسهٔ کامل به‌صورت خودکار ثبت می‌شود.',
                  style:
                      TextStyle(color: mutedColor, fontSize: AppTheme.scaledFontSize(context, 12), height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Miniature per-type totals for the sessions currently shown in the log.
class _FocusBreakdown extends StatelessWidget {
  const _FocusBreakdown({required this.history});

  final List<PomodoroSessionTableData> history;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = TimeThemeKit.of(context).palette.textMuted;
    final totals = <String, int>{};
    for (final s in history) {
      totals[s.focusType] = (totals[s.focusType] ?? 0) + s.durationMinutes;
    }
    final present =
        focusTypes.where((t) => (totals[t] ?? 0) > 0).toList(growable: false);
    if (present.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final type in present)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: focusTypeColor(type)
                    .withValues(alpha: isDark ? 0.22 : 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 8, color: focusTypeColor(type)),
                  const SizedBox(width: 6),
                  Text(
                    '$type ${faDigits(totals[type])}′',
                    style: TextStyle(
                      color: mutedColor,
                      fontSize: AppTheme.scaledFontSize(context, 12),
                      fontWeight: FontWeight.w600,
                      fontFamily: AppTheme.fontFamily,
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

class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.weekTotals});

  final List<int> weekTotals;

  @override
  Widget build(BuildContext context) {
    final mutedColor = TimeThemeKit.of(context).palette.textMuted;
    const accent = pomodoroAccent;
    final maxVal = weekTotals.fold<int>(0, math.max);
    const barMaxHeight = 52.0;
    final today = DateTime.now();
    const weekLetters = {
      1: 'د',
      2: 'س',
      3: 'چ',
      4: 'پ',
      5: 'ج',
      6: 'ش',
      7: 'ی',
    };

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart_rounded,
                    size: 15, color: accent.withValues(alpha: 0.85)),
                const SizedBox(width: 6),
                Text(
                  '7 روز اخیر',
                  style: TextStyle(
                    color: mutedColor,
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (weekTotals[i] > 0)
                          Text(
                            faDigits(weekTotals[i]),
                            style: TextStyle(
                              fontSize: AppTheme.scaledFontSize(context, 10),
                              color: i == 6 ? accent : mutedColor,
                              fontFamily: AppTheme.fontFamily,
                            ),
                          ),
                        const SizedBox(height: 3),
                        Container(
                          width: 14,
                          height: maxVal > 0
                              ? math.max(
                                  4.0, barMaxHeight * weekTotals[i] / maxVal)
                              : 4.0,
                          decoration: BoxDecoration(
                            color: i == 6
                                ? accent
                                : mutedColor.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          weekLetters[today
                                  .subtract(Duration(days: 6 - i))
                                  .weekday] ??
                              '',
                          style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 10),
                            color: i == 6 ? accent : mutedColor,
                            fontWeight: i == 6 ? FontWeight.bold : null,
                            fontFamily: AppTheme.fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});

  final PomodoroSessionTableData session;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = t.textPrimary;
    final mutedColor = t.textMuted;
    final typeColor =
        focusTypeColor(session.focusType.isEmpty ? 'عمومی' : session.focusType);
    final modeColor =
        session.mode == 'countdown' ? _modeCountdownColor : _modeClassicColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: isDark ? 0.25 : 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                session.mode == 'countdown'
                    ? Icons.hourglass_bottom
                    : Icons.timer_outlined,
                size: 20,
                color: typeColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: typeColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          session.focusType.isEmpty
                              ? 'عمومی'
                              : session.focusType,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w700,
                            fontSize: AppTheme.scaledFontSize(context, 13),
                            fontFamily: AppTheme.fontFamily,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${faDigits(session.durationMinutes)} دقیقه · ${_historyDateLabel(session.startedAt)}',
                    style: TextStyle(color: mutedColor, fontSize: AppTheme.scaledFontSize(context, 11)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: modeColor.withValues(alpha: isDark ? 0.22 : 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                session.mode == 'countdown' ? 'شمارش معکوس' : 'پومودور',
                style: TextStyle(
                  color: modeColor,
                  fontSize: AppTheme.scaledFontSize(context, 10),
                  fontWeight: FontWeight.w600,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _historyDateLabel(DateTime dt) {
    final now = DateTime.now();
    final day = DateTime(dt.year, dt.month, dt.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    final time =
        '${faDigits(dt.hour.toString().padLeft(2, '0'))}:${faDigits(dt.minute.toString().padLeft(2, '0'))}';
    if (diff == 0) return 'امروز $time';
    if (diff == 1) return 'دیروز $time';
    final j = Jalali.fromDateTime(dt);
    return '${j.formatter.mN} ${faDigits(j.formatter.d)}، ${faDigits(j.year)} · $time';
  }
}

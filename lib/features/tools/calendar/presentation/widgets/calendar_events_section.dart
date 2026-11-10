import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/core/constants/date_constants.dart';
import 'package:tawheeed/core/design_system/components/components.dart';

import 'package:tawheeed/features/tools/calendar/presentation/widgets/calendar_models.dart';
import 'package:tawheeed/features/tools/calendar/presentation/widgets/calendar_style.dart';

// ══════════════════════════════════════════════════════════════
//  MONTHLY EVENTS SECTION
// ══════════════════════════════════════════════════════════════

class MonthlyEventsSection extends StatelessWidget {
  final List<CalendarMonthEvent> events;

  /// «Today» for the past/today/next split. The screen owns the clock and
  /// passes its own value, so a test run cannot drift against the wall clock.
  final DateTime? now;

  const MonthlyEventsSection({super.key, required this.events, this.now});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();
    final t = TimeThemeKit.of(context).palette;
    final reference = now ?? DateTime.now();
    final today = _dateOnly(reference);

    // Weekly recommended fasts (Mon/Thu) repeat ~8–10× per month and crowd the
    // list. Collapse them into a single summary row; only meaningful occasions
    // (Eids, Laylat al-Qadr, Ayyam al-Beed, Tasu'a/Ashura, etc.) are listed.
    bool isWeeklyFast(String label) =>
        label == 'روزه دوشنبه (مستحب)' || label == 'روزه پنجشنبه (مستحب)';
    final weeklyFastCount = events.where((e) => isWeeklyFast(e.label)).length;
    final notable = events.where((e) => !isWeeklyFast(e.label)).toList();

    final days = notable.map((e) => _dateOnly(e.gregorianDate)).toList();
    // -1 when every occasion of the month has passed — then no row is «بعدی».
    final nextIndex = days.indexWhere((d) => !d.isBefore(today));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'مناسبات این ماه',
            count: '${notable.length + (weeklyFastCount > 0 ? 1 : 0)}',
          ),
          if (weeklyFastCount > 0) ...[
            _WeeklyFastRow(count: weeklyFastCount),
            const SizedBox(height: 6),
          ],
          for (var i = 0; i < notable.length; i++) ...[
            _OccasionRow(
              event: notable[i],
              isPast: days[i].isBefore(today),
              isToday: days[i] == today,
              // «بعدی» is the first day that has not passed yet — never today,
              // which already carries its own badge.
              isNext: i == nextIndex && days[i] != today,
              mutedInk: t.textMuted,
            ),
            if (i != notable.length - 1) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// One occasion: the Hijri day it falls on, its name, and the Shamsi date
/// under it. Today / next get a flat tinted row instead of the old full-bleed
/// right border, so the highlight stays inside the card's own geometry.
class _OccasionRow extends StatelessWidget {
  final CalendarMonthEvent event;
  final bool isPast;
  final bool isToday;
  final bool isNext;
  final Color mutedInk;

  const _OccasionRow({
    required this.event,
    required this.isPast,
    required this.isToday,
    required this.isNext,
    required this.mutedInk,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = CalendarOccasionStyle.of(event.label);
    final hue = dsContentColor(context, style.hue);
    final ink = isPast ? mutedInk : hue;
    final marked = isToday || isNext;
    // Shamsi (Jalali) date reads as a date, not as a YYYY/M/D dump.
    final jDate = Jalali.fromDateTime(event.gregorianDate);
    final shamsi =
        '${jDate.day} ${DateConstants.persianMonths[jDate.month - 1]} ${jDate.year}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        // Every row sits in its family hue at a pale fill; today/next get a
        // stronger fill plus a hairline border, past rows go neutral.
        color: isPast
            ? TimeThemeKit.of(context).palette.surfaceAlt
            : hue.withValues(
                alpha: marked
                    ? (isDark ? 0.16 : 0.10)
                    : (isDark ? 0.10 : 0.06)),
        borderRadius: BorderRadius.circular(12),
        border: marked && !isPast
            ? Border.all(color: hue.withValues(alpha: isDark ? 0.45 : 0.30))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color:
                  hue.withValues(alpha: isPast ? 0.05 : (isDark ? 0.16 : 0.10)),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Center(
              child: Text(
                '${event.hijriDay}',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 13),
                  fontWeight: FontWeight.w700,
                  color: ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(style.icon, size: 14, color: ink),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        event.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          fontWeight: FontWeight.w600,
                          color: ink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${weekdayName(event.gregorianDate)} · $shamsi',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    color: mutedInk,
                  ),
                ),
              ],
            ),
          ),
          if (isToday) ...[
            const SizedBox(width: 8),
            const BadgeChip(text: 'امروز'),
          ] else if (isNext) ...[
            const SizedBox(width: 8),
            const BadgeChip(text: 'بعدی'),
          ],
        ],
      ),
    );
  }
}

/// The collapsed weekly-fasts summary, in the same geometry as an occasion row.
class _WeeklyFastRow extends StatelessWidget {
  final int count;

  const _WeeklyFastRow({required this.count});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hue = dsContentColor(context, CalendarHues.fasting);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: hue.withValues(alpha: isDark ? 0.10 : 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: hue.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Center(
                child: Icon(Icons.restaurant_rounded, size: 17, color: hue)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'روزه‌های هفتگی مستحب',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    fontWeight: FontWeight.w600,
                    color: hue,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'این ماه $count روز (دوشنبه‌ها و پنجشنبه‌ها)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    color: t.textMuted,
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

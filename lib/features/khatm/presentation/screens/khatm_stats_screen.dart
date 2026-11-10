import 'package:tawheeed/shared/utils/date_key.dart';
import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/core/constants/date_constants.dart';
import 'package:tawheeed/core/design_system/ambient_background.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/khatm/data/models/khatm_model.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/shared/utils/date_range.dart';
import 'package:tawheeed/shared/services/share_service.dart';

Color get _accentOf => TopicHues.khatm;

/// نام روز هفتهٔ ایرانی بر اساس `DateTime.weekday` (1=دوشنبه ... 7=یکشنبه).
String _weekdayName(int weekday) {
  return switch (weekday) {
    6 => 'شنبه',
    7 => 'یکشنبه',
    1 => 'دوشنبه',
    2 => 'سه‌شنبه',
    3 => 'چهارشنبه',
    4 => 'پنجشنبه',
    5 => 'جمعه',
    _ => '',
  };
}

class KhatmStatsScreen extends StatefulWidget {
  final KhatmModel khatm;
  const KhatmStatsScreen({super.key, required this.khatm});

  @override
  State<KhatmStatsScreen> createState() => _KhatmStatsScreenState();
}

class _KhatmStatsScreenState extends State<KhatmStatsScreen> {
  bool _monthly = false;
  int _monthOffset = 0;

  DateTime get _targetMonth =>
      DateTime(DateTime.now().year, DateTime.now().month + _monthOffset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    final warning = isDark ? AppTheme.darkWarning : AppTheme.lightWarning;
    final khatm = widget.khatm;
    final now = DateTime.now();

    // ── Period bounds ──
    final DateTime start;
    final DateTime end;
    final int days;
    if (_monthly) {
      final target = _targetMonth;
      start = DateTime(target.year, target.month);
      end = DateTime(target.year, target.month + 1, 0);
      days = end.day;
    } else {
      end = now;
      start = now.subtract(const Duration(days: 6));
      days = 7;
    }

    final series = <(DateTime, int)>[];
    var total = 0;
    var bestCount = 0;
    DateTime? bestDay;
    for (var d = start; !d.isAfter(end); d = d.addCalendarDaysFromMidnight(1)) {
      final c = khatm.pagesOn(dateKeyOf(d));
      series.add((d, c));
      total += c;
      if (c > bestCount) {
        bestCount = c;
        bestDay = d;
      }
    }
    final active = series.where((e) => e.$2 > 0).length;
    final avg = days > 0 ? total / days : 0.0;
    final target = khatm.dailyTarget;
    final targetTotal = target * days;
    final fraction = targetTotal > 0 ? total / targetTotal : 0.0;
    final streak = _currentStreak(khatm);

    return AmbientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: SectionAppBar(
          title: 'گزارش پیشرفت ختم',
          actions: [
            IconButton(
              icon: Icon(Icons.share_outlined,
                  color: dsContentColor(context, _accentOf)),
              tooltip: 'کپی گزارش',
              onPressed: () => _copyReport(
                khatm: khatm,
                start: start,
                end: end,
                days: days,
                total: total,
                avg: avg,
                active: active,
                bestDay: bestDay,
                streak: streak,
                fraction: fraction,
              ),
            ),
          ],
        ),
        body: ListView(
          padding:
              const EdgeInsets.fromLTRB(DsSpacing.page, 4, DsSpacing.page, 24),
          children: [
            SegmentedTabs(
              tabs: const [
                SegmentedTab(label: 'هفتگی', icon: Icons.view_week),
                SegmentedTab(label: 'ماهانه', icon: Icons.calendar_month),
              ],
              index: _monthly ? 1 : 0,
              onChanged: (i) => setState(() => _monthly = i == 1),
            ),
            const SizedBox(height: 14),
            _ScoreCard(
              total: total,
              fraction: fraction,
              label: _monthly ? 'مجموع صفحات ماه' : 'مجموع صفحات هفته',
            ),
            const SizedBox(height: 12),
            _SummaryRow(
              items: [
                _SummaryItem(
                  icon: Icons.menu_book,
                  label: 'مجموع صفحات',
                  value: NumberFormat.formatPlain(total.toDouble()),
                  color: dsContentColor(context, _accentOf),
                ),
                _SummaryItem(
                  icon: Icons.av_timer,
                  label: 'میانگین روزانه',
                  value: NumberFormat.formatPlain(avg),
                  color: dsContentColor(context, _accentOf),
                ),
                _SummaryItem(
                  icon: Icons.local_fire_department,
                  label: 'روزهای فعال',
                  value: '$active از $days',
                  color: success,
                ),
                _SummaryItem(
                  icon: Icons.whatshot,
                  label: 'زنجیره',
                  value: '$streak روز',
                  color: warning,
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_monthly) ...[
              _MonthNavigator(
                  monthOffset: _monthOffset,
                  onChanged: (v) {
                    setState(() => _monthOffset = v);
                  }),
              const SizedBox(height: 14),
              _HeatmapCard(
                khatm: khatm,
                month: _targetMonth,
                daysInMonth: days,
              ),
              const SizedBox(height: 14),
            ] else ...[
              _BarChartCard(
                series: series,
                title: 'صفحات خوانده‌شده',
                subtitle: '7 روز اخیر',
              ),
              const SizedBox(height: 14),
            ],
            _PastDaysCard(
              series: series,
              target: target,
              monthly: _monthly,
            ),
            const SizedBox(height: 14),
            _ReportCard(
              khatm: khatm,
              total: total,
              avg: avg,
              active: active,
              bestDay: bestDay,
              streak: streak,
              onCopy: () => _copyReport(
                khatm: khatm,
                start: start,
                end: end,
                days: days,
                total: total,
                avg: avg,
                active: active,
                bestDay: bestDay,
                streak: streak,
                fraction: fraction,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// روزهای پیاپی با حداقل یک صفحه خوانده‌شده، تا امروز (یا دیروز اگر امروز خالی است).
  int _currentStreak(KhatmModel khatm) {
    var streak = 0;
    final now = DateTime.now();
    var cursor = khatm.pagesOn(dateKeyOf(now)) > 0
        ? now
        : now.subtract(const Duration(days: 1));
    for (var i = 0; i < 365; i++) {
      if (khatm.pagesOn(dateKeyOf(cursor)) <= 0) break;
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  void _copyReport({
    required KhatmModel khatm,
    required DateTime start,
    required DateTime end,
    required int days,
    required int total,
    required double avg,
    required int active,
    required DateTime? bestDay,
    required int streak,
    required double fraction,
  }) {
    final buf = StringBuffer();
    if (start.month == end.month) {
      final j = Jalali.fromDateTime(end);
      buf.writeln(
          '📊 گزارش ${_monthly ? 'ماهانه' : 'هفتگی'} ختم قرآن — ${DateConstants.persianMonths[j.month - 1]} ${j.year}');
    } else {
      buf.writeln('📊 گزارش هفتگی ختم قرآن');
    }
    buf.writeln('═' * 28);
    buf.writeln('عنوان: ${khatm.title.isNotEmpty ? khatm.title : 'ختم قرآن'}');
    buf.writeln('مجموع صفحات: ${NumberFormat.formatPlain(total.toDouble())}');
    buf.writeln('میانگین روزانه: ${NumberFormat.formatPlain(avg)}');
    if (bestDay != null) {
      buf.writeln(
          'بهترین روز: ${_weekdayName(bestDay.weekday)} (${NumberFormat.formatPlain(khatm.pagesOn(dateKeyOf(bestDay)).toDouble())} صفحه)');
    }
    buf.writeln('روزهای فعال: $active از $days');
    buf.writeln('زنجیره: $streak روز');
    buf.writeln('هدف روزانه: ${khatm.dailyTarget} صفحه');
    buf.writeln();
    buf.writeln(
        'پیشرفت کلی: ${khatm.readPages} از ${khatm.totalPages} صفحه (${(khatm.progress * 100).toStringAsFixed(1)}%)');
    buf.writeln();
    buf.writeln('📅 جزئیات روزها');
    for (var d = start; !d.isAfter(end); d = d.addCalendarDaysFromMidnight(1)) {
      final c = khatm.pagesOn(dateKeyOf(d));
      if (c > 0) {
        final j = Jalali.fromDateTime(d);
        buf.writeln('${_weekdayName(d.weekday)} ${j.day}/${j.month}: $c صفحه');
      }
    }

    ShareService.copyText(context, buf.toString(),
        doneMessage: 'گزارش در کلیپ‌بورد کپی شد');
  }
}

// ══════════════════════════════════════════════════════════════
// Score card
// ══════════════════════════════════════════════════════════════
class _ScoreCard extends StatelessWidget {
  final int total;
  final double fraction;
  final String label;
  const _ScoreCard(
      {required this.total, required this.fraction, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rating = _ratingFor(fraction);
    final ratingColor = fraction >= 0.875
        ? (isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess)
        : fraction >= 0.625
            ? (isDark ? AppTheme.darkTertiary : AppTheme.lightTertiary)
            : fraction >= 0.375
                ? (isDark ? AppTheme.darkWarning : AppTheme.lightWarning)
                : (isDark ? AppTheme.darkError : AppTheme.lightError);

    return Container(
      decoration: BoxDecoration(
        color: TopicHues.khatm,
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: AppTheme.scaledFontSize(context, 13),
              )),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.menu_book, size: 26, color: Colors.white),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    NumberFormat.formatPlain(total.toDouble()),
                    style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 40),
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                ' صفحه',
                style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 14),
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: ratingColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ratingColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              rating,
              style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 12),
                fontWeight: FontWeight.w600,
                color: dsContentColor(context, ratingColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _ratingFor(double fraction) {
    if (fraction >= 0.875) return 'عالی';
    if (fraction >= 0.625) return 'خوب';
    if (fraction >= 0.375) return 'قابل قبول';
    return 'نیاز به تلاش بیشتر';
  }
}

// ══════════════════════════════════════════════════════════════
// Summary row
// ══════════════════════════════════════════════════════════════
class _SummaryItem {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _SummaryItem(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});
}

class _SummaryRow extends StatelessWidget {
  final List<_SummaryItem> items;
  const _SummaryRow({required this.items});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: items
            .map((item) => Expanded(
                  child: Column(
                    children: [
                      Icon(item.icon, size: 20, color: item.color),
                      const SizedBox(height: 4),
                      Text(item.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: AppTheme.scaledFontSize(context, 13),
                              fontWeight: FontWeight.w800,
                              color: t.textPrimary)),
                      Text(item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: AppTheme.scaledFontSize(context, 9),
                              color: t.textMuted)),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Month navigator
// ══════════════════════════════════════════════════════════════
class _MonthNavigator extends StatelessWidget {
  final int monthOffset;
  final ValueChanged<int> onChanged;
  const _MonthNavigator({required this.monthOffset, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final target =
        DateTime(DateTime.now().year, DateTime.now().month + monthOffset);
    final j = Jalali.fromDateTime(target);
    final label = '${DateConstants.persianMonths[j.month - 1]} ${j.year}';
    final t = TimeThemeKit.of(context).palette;
    final accent = dsContentColor(context, _accentOf);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.chevron_right, color: accent),
            tooltip: 'ماه بعد',
            onPressed: () => onChanged(monthOffset + 1),
          ),
          Expanded(
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 15),
                  fontWeight: FontWeight.bold,
                  color: t.textPrimary,
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_left, color: accent),
            tooltip: 'ماه قبل',
            onPressed: () => onChanged(monthOffset - 1),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Weekly bar chart
// ══════════════════════════════════════════════════════════════
class _BarChartCard extends StatelessWidget {
  final List<(DateTime, int)> series;
  final String title;
  final String subtitle;
  const _BarChartCard(
      {required this.series, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final accent = _accentOf;
    final accentInk = dsContentColor(context, _accentOf);
    final maxCount = series.fold<int>(0, (m, e) => e.$2 > m ? e.$2 : m);
    final now = DateTime.now();
    final todayKey = dateKeyOf(now);

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: title,
            margin: EdgeInsets.zero,
            trailing: Text(subtitle,
                style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 10),
                  color: t.textMuted,
                )),
          ),
          const SizedBox(height: 16),
          Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              height: 130,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: series.map((e) {
                  final (date, count) = e;
                  final isToday = dateKeyOf(date) == todayKey;
                  final h = maxCount > 0
                      ? (count / maxCount * 90.0).clamp(3.0, 90.0)
                      : 3.0;
                  return Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          count > 0
                              ? NumberFormat.formatPlain(count.toDouble())
                              : '',
                          style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 8),
                            color: isToday ? accentInk : t.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          height: h,
                          decoration: BoxDecoration(
                            color: count > 0
                                ? (isToday
                                    ? accent
                                    : accent.withValues(alpha: 0.55))
                                : t.outline.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _weekdayName(date.weekday).substring(0, 2),
                          style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 8),
                            fontWeight:
                                isToday ? FontWeight.w800 : FontWeight.w500,
                            color: isToday ? accentInk : t.textMuted,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Monthly heatmap
// ══════════════════════════════════════════════════════════════
class _HeatmapCard extends StatelessWidget {
  final KhatmModel khatm;
  final DateTime month;
  final int daysInMonth;
  const _HeatmapCard(
      {required this.khatm, required this.month, required this.daysInMonth});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final accent = _accentOf;
    final success = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.darkSuccess
        : AppTheme.lightSuccess;
    final values = <int>[];
    var maxValue = 0;
    for (var day = 1; day <= daysInMonth; day++) {
      final d = DateTime(month.year, month.month, day);
      final v = khatm.pagesOn(dateKeyOf(d));
      values.add(v);
      if (v > maxValue) maxValue = v;
    }

    final first = DateTime(month.year, month.month);
    final daysSinceSat = (first.weekday + 1) % 7;
    final lead = List.filled(daysSinceSat, 0);
    final cells = [...lead, ...values];

    final now = DateTime.now();
    final todayKey = dateKeyOf(now);
    final weekHeaders = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'نقشه حرارتی ماه',
            margin: EdgeInsets.zero,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LegendDot(color: accent.withValues(alpha: 0.25), label: 'کم'),
                const SizedBox(width: 6),
                _LegendDot(color: accent, label: 'زیاد'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: weekHeaders
                .map((h) => Expanded(
                      child: Text(
                        h,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 9),
                          fontWeight: FontWeight.w700,
                          color: t.textMuted,
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 6),
          Column(
            children: List.generate((cells.length / 7).ceil(), (week) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: List.generate(7, (col) {
                    final idx = week * 7 + col;
                    final empty = idx >= cells.length;
                    final v = empty ? 0 : cells[idx];
                    final isToday = !empty &&
                        dateKeyOf(DateTime(month.year, month.month,
                                idx - daysSinceSat + 1)) ==
                            todayKey;
                    final intensity = maxValue > 0 ? v / maxValue : 0.0;
                    final color = v == 0
                        ? t.outline.withValues(alpha: 0.35)
                        : Color.lerp(
                              accent.withValues(alpha: 0.25),
                              accent,
                              intensity,
                            ) ??
                            accent;
                    final day = idx - daysSinceSat + 1;
                    return Expanded(
                      child: Container(
                        height: 30,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                          color: empty ? Colors.transparent : color,
                          borderRadius: BorderRadius.circular(5),
                          border: isToday
                              ? Border.all(color: success, width: 1.6)
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: empty
                            ? null
                            : Text(
                                _jalaliDayLabel(
                                    DateTime(month.year, month.month, day)),
                                style: TextStyle(
                                  fontSize: AppTheme.scaledFontSize(context, 9),
                                  fontWeight: isToday
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: v == 0
                                      ? t.textMuted
                                      : (intensity > 0.55
                                          ? Colors.white
                                          : t.textPrimary),
                                ),
                              ),
                      ),
                    );
                  }),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  String _jalaliDayLabel(DateTime d) {
    final j = Jalali.fromDateTime(d);
    return '${j.day}';
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
              fontSize: AppTheme.scaledFontSize(context, 9),
              color: t.textMuted,
            )),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Past days report
// ══════════════════════════════════════════════════════════════
class _PastDaysCard extends StatelessWidget {
  final List<(DateTime, int)> series;
  final int target;
  final bool monthly;
  const _PastDaysCard(
      {required this.series, required this.target, required this.monthly});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    final warning = isDark ? AppTheme.darkWarning : AppTheme.lightWarning;
    final accent = _accentOf;
    final accentInk = dsContentColor(context, _accentOf);
    final now = DateTime.now();
    final todayKey = dateKeyOf(now);
    final rows = series.reversed.toList(); // امروز اول

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'آمار روزهای گذشته',
            margin: EdgeInsets.zero,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${series.length} روز',
                  style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 10),
                    fontWeight: FontWeight.w700,
                    color: accentInk,
                  )),
            ),
          ),
          const SizedBox(height: 8),
          ...rows.map((e) {
            final (date, count) = e;
            final isToday = dateKeyOf(date) == todayKey;
            final j = Jalali.fromDateTime(date);
            final done = count >= target && target > 0;
            final anyRead = count > 0;
            final chipColor = done
                ? success
                : anyRead
                    ? warning
                    : t.textMuted;
            final chipLabel = done
                ? 'کامل'
                : anyRead
                    ? 'ناقص'
                    : 'نخوانده';
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: t.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.outline.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (anyRead ? accent : t.textMuted)
                          .withValues(alpha: anyRead ? 0.14 : 0.08),
                      border: Border.all(
                        color: (anyRead ? accent : t.textMuted)
                            .withValues(alpha: anyRead ? 0.35 : 0.2),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${j.day}',
                      style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 11),
                        fontWeight: FontWeight.w800,
                        color: anyRead ? accentInk : t.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_weekdayName(date.weekday)}${isToday ? ' (امروز)' : ''}',
                          style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 12.5),
                            fontWeight: FontWeight.w700,
                            color: t.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 10),
                            color: t.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${NumberFormat.formatPlain(count.toDouble())} صفحه',
                    style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 13),
                      fontWeight: FontWeight.w800,
                      color: anyRead ? accentInk : t.textMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: chipColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: chipColor.withValues(alpha: 0.30)),
                    ),
                    child: Text(
                      chipLabel,
                      style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 9.5),
                        fontWeight: FontWeight.w700,
                        color: dsContentColor(context, chipColor),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Report card
// ══════════════════════════════════════════════════════════════
class _ReportCard extends StatelessWidget {
  final KhatmModel khatm;
  final int total;
  final double avg;
  final int active;
  final DateTime? bestDay;
  final int streak;
  final VoidCallback onCopy;
  const _ReportCard(
      {required this.khatm,
      required this.total,
      required this.avg,
      required this.active,
      required this.bestDay,
      required this.streak,
      required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final accent = _accentOf;
    final accentInk = dsContentColor(context, _accentOf);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'گزارش متنی', margin: EdgeInsets.zero),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: t.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'خلاصه:\n'
              '• ${NumberFormat.formatPlain(total.toDouble())} صفحه خوانده شده\n'
              '• میانگین روزانه ${NumberFormat.formatPlain(avg)}\n'
              '• $active روز فعال\n'
              '• زنجیره $streak روز\n'
              '${bestDay != null ? '• بهترین روز: ${_weekdayName(bestDay!.weekday)} (${NumberFormat.formatPlain(khatm.pagesOn(dateKeyOf(bestDay!)).toDouble())} صفحه)' : ''}',
              style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 12),
                height: 1.7,
                color: t.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onCopy,
              icon: Icon(Icons.copy, size: 18, color: accentInk),
              label: Text('کپی گزارش کامل',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily, color: accentInk)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: accent.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

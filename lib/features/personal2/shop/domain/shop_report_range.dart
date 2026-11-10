import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/core/utils/calendar_days.dart';
import 'package:tawheeed/core/utils/jalali_format.dart';

/// A shop-report window: midnight of [from] through the last instant of [to].
///
/// Every shop aggregate is stored as an integer millisecond stamp, and the
/// stage-2 provider built its bounds inline — `date >= from`, no upper bound.
/// That worked for «today» and «N days back» because the window always ended
/// at `DateTime.now()`, but a *report* has to answer «۱۵ مهر تا ۳۰ مهر» too,
/// and there the upper bound is not now. One value object carries both bounds
/// so a range can never be half-open by accident.
///
/// `to` is a *day* (midnight); [toMsExclusive] is the next midnight, which is
/// what the SQL comparisons use — `date >= fromMs AND date < toMsExclusive`
/// includes the whole last day at any time of day, without `+ 1` off-by-ones
/// or DST arithmetic (see [addCalendarDaysFromMidnight]).
class ShopReportRange {
  /// Normalises both endpoints to midnight.
  ///
  /// A picker hands back a `DateTime` that may carry a time of day, and a
  /// `from` of 18:00 would silently exclude everything that happened that
  /// morning from `contains()` and from every `date >= fromMs` query — a range
  /// that looks right and quietly loses half a day. Normalising here means the
  /// rest of the class can assume day-aligned bounds.
  ShopReportRange({required DateTime from, required DateTime to})
      : from = DateTime(from.year, from.month, from.day),
        to = DateTime(to.year, to.month, to.day);

  /// The single day containing [day].
  factory ShopReportRange.day(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    return ShopReportRange(from: start, to: start);
  }

  /// The [days] calendar days ending today (inclusive), e.g. 7 = today + 6.
  ///
  /// Days, not 24-hour blocks: a shop's «۷ روز» is seven till-dates, so the
  /// window starts at the midnight six days ago, never at `now - 168h`.
  factory ShopReportRange.lastDays(int days, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final end = DateTime(today.year, today.month, today.day);
    final span = days < 1 ? 1 : days;
    return ShopReportRange(
      from: addCalendarDaysFromMidnight(end, -(span - 1)),
      to: end,
    );
  }

  /// The current Jalali month, from its first day through [now]'s day.
  ///
  /// «این ماه» in a Persian app means the Shamsi month (۱ تا ۳۰ مهر), not the
  /// last thirty days: on ۲ مهر the shopkeeper expects two days of numbers,
  /// and a 30-day window silently mixed in the previous month.
  factory ShopReportRange.thisJalaliMonth({DateTime? now}) {
    final today = now ?? DateTime.now();
    final jalali = Jalali.fromDateTime(today);
    final first = Jalali(jalali.year, jalali.month).toDateTime();
    return ShopReportRange(
      from: DateTime(first.year, first.month, first.day),
      to: DateTime(today.year, today.month, today.day),
    );
  }

  /// Day-aligned endpoints (see the constructor).
  final DateTime from;
  final DateTime to;

  int get fromMs => from.millisecondsSinceEpoch;

  /// First millisecond *after* the window — the half-open upper bound.
  int get toMsExclusive =>
      addCalendarDaysFromMidnight(to, 1).millisecondsSinceEpoch;

  /// Last millisecond inside the window (for APIs that take an inclusive end).
  int get toMsInclusive => toMsExclusive - 1;

  /// Number of calendar days the window covers, at least 1.
  int get dayCount {
    final span = calendarDaysBetween(from, to) + 1;
    return span < 1 ? 1 : span;
  }

  bool get isSingleDay => dayCount == 1;

  /// The equally long window immediately before this one.
  ///
  /// The comparison figure («۲۳٪ بیشتر از دورهٔ پیش») must compare like with
  /// like, so the previous window has exactly [dayCount] days and ends the day
  /// before [from] starts — never a fixed 30 days against a 7-day window.
  ShopReportRange get previous => ShopReportRange(
        from: addCalendarDaysFromMidnight(from, -dayCount),
        to: addCalendarDaysFromMidnight(from, -1),
      );

  /// Whether [moment] falls inside the window (inclusive of the last day).
  bool contains(DateTime moment) {
    final ms = moment.millisecondsSinceEpoch;
    return ms >= fromMs && ms < toMsExclusive;
  }

  /// `۱۴۰۴/۷/۳` for one day, `۱۴۰۴/۷/۱ تا ۱۴۰۴/۷/۳` for a span.
  String get label => isSingleDay
      ? jalaliLabelFa(from)
      : '${jalaliLabelFa(from)} تا ${jalaliLabelFa(to)}';

  @override
  bool operator ==(Object other) =>
      other is ShopReportRange &&
      other.fromMs == fromMs &&
      other.toMsExclusive == toMsExclusive;

  @override
  int get hashCode => Object.hash(fromMs, toMsExclusive);

  @override
  String toString() => 'ShopReportRange($label)';
}

/// The report tab's period selector.
enum ShopReportPreset {
  today('امروز'),
  last7('۷ روز'),
  last30('۳۰ روز'),
  month('این ماه'),
  custom('بازهٔ دلخواه');

  const ShopReportPreset(this.label);

  final String label;

  /// The window this preset means at [now], or null for [custom] — the caller
  /// owns the picked endpoints there.
  ShopReportRange? rangeAt(DateTime now) => switch (this) {
        ShopReportPreset.today => ShopReportRange.day(now),
        ShopReportPreset.last7 => ShopReportRange.lastDays(7, now: now),
        ShopReportPreset.last30 => ShopReportRange.lastDays(30, now: now),
        ShopReportPreset.month => ShopReportRange.thisJalaliMonth(now: now),
        ShopReportPreset.custom => null,
      };
}

/// Calendar-day arithmetic that is correct across daylight-saving changes.
///
/// `DateTime.add(const Duration(days: 1))` adds exactly 24 hours. In a
/// timezone where the clocks go back one hour, midnight + 24h lands at 23:00
/// **on the same day**, so a "next day" button silently does nothing and a
/// generated 30-day list repeats a date. Constructing the date from its
/// calendar parts normalises instead, which is what a date picker means.
library;

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day, value.hour, value.minute);

/// [date] shifted by [days] calendar days, keeping the time of day.
///
/// Works for any [days], positive or negative, and rolls over months/years.
DateTime addCalendarDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days, date.hour, date.minute);

/// Midnight of the day [days] after [date] (negative for earlier days).
DateTime addCalendarDaysFromMidnight(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

/// Member-syntax sugar over the calendar-day helpers, so call sites read
/// `now.addCalendarDaysFromMidnight(1)` — with an optional time-of-day for
/// the «next fajr / previous isha» style bounds.
extension CalendarDayArithmetic on DateTime {
  /// The day [days] after this date (negative for earlier days) at the given
  /// time of day. Defaults to midnight — mirrors [addCalendarDaysFromMidnight]
  /// (same-library call would shadow).
  DateTime addCalendarDaysFromMidnight(int days,
          [int hour = 0, int minute = 0]) =>
      DateTime(year, month, day + days, hour, minute);
}

/// The [count] consecutive calendar days starting at [start].
List<DateTime> calendarDayRange(DateTime start, int count) => [
      for (var i = 0; i < count; i++) addCalendarDaysFromMidnight(start, i),
    ];

/// Number of calendar days from [from] to [to] (negative when [to] is earlier).
///
/// Counting through UTC dates keeps daylight-saving out of the result:
/// `localA.difference(localB)` measures elapsed time, so a 30-day Hijri month
/// spanning a "clocks back" night measures 29.96 days and truncates to 29.
int calendarDaysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

import 'package:tawheeed/core/utils/calendar_days.dart';

export 'package:tawheeed/core/utils/calendar_days.dart'
    show
        addCalendarDaysFromMidnight,
        calendarDayRange,
        calendarDaysBetween,
        CalendarDayArithmetic;

/// Inclusive midnight-to-midnight date range, the shape every «از تاریخ X تا
/// تاریخ Y» loop in the app walks. Building the bounds through
/// [addCalendarDaysFromMidnight] keeps DST-affected midnights normalised.
extension DateRangeX on DateTime {
  /// Midnight of the day [days] **before** this date (positive [days] looks
  /// back). `now.calendarDaysAgo(6)` is the start of a 7-day window ending
  /// today.
  DateTime calendarDaysAgo(int days) =>
      addCalendarDaysFromMidnight(this, -days);
}

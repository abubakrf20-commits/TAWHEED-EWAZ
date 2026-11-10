// ══════════════════════════════════════════════════════════════
//  OCCASIONS — single source of truth for calendar events
// ══════════════════════════════════════════════════════════════

enum CalendarKind { hijri }

class CalendarOccasion {
  final CalendarKind kind;
  final int month;
  final int day;
  final String label;

  const CalendarOccasion(this.kind, this.month, this.day, this.label);
}

/// Sunni religious (Hijri) occasions and sunnah fasts only. Hijri days follow
/// the tabular calendar used across the app and honor the user's [hijriOffset].
const List<CalendarOccasion> kCalendarOccasions = [
  CalendarOccasion(CalendarKind.hijri, 1, 1, 'رأس السنة الهجرية'),
  CalendarOccasion(CalendarKind.hijri, 1, 9, 'روزه تاسوعا (سنت)'),
  CalendarOccasion(CalendarKind.hijri, 1, 10, 'روزه عاشورا (سنت)'),
  CalendarOccasion(CalendarKind.hijri, 3, 12, 'ولادت پیامبر اکرم (ص)'),
  CalendarOccasion(CalendarKind.hijri, 7, 1, 'اول رجب (مستحب)'),
  CalendarOccasion(CalendarKind.hijri, 7, 27, 'شب اسراء و معراج'),
  CalendarOccasion(CalendarKind.hijri, 8, 1, 'اول شعبان (مستحب)'),
  CalendarOccasion(CalendarKind.hijri, 8, 15, 'لیلة البراءة (نیمه شعبان)'),
  CalendarOccasion(CalendarKind.hijri, 9, 1, 'اول رمضان'),
  CalendarOccasion(CalendarKind.hijri, 9, 20, 'فتح مکه'),
  CalendarOccasion(CalendarKind.hijri, 9, 21, 'لیلة القدر'),
  CalendarOccasion(CalendarKind.hijri, 9, 23, 'لیلة القدر'),
  CalendarOccasion(CalendarKind.hijri, 9, 25, 'لیلة القدر'),
  CalendarOccasion(CalendarKind.hijri, 9, 27, 'لیلة القدر (أرجح)'),
  CalendarOccasion(CalendarKind.hijri, 9, 29, 'لیلة القدر'),
  CalendarOccasion(CalendarKind.hijri, 10, 1, 'عید فطر'),
  CalendarOccasion(CalendarKind.hijri, 10, 2, 'عید فطر (تعطیل)'),
  CalendarOccasion(CalendarKind.hijri, 12, 9, 'روز عرفه'),
  CalendarOccasion(CalendarKind.hijri, 12, 10, 'عید قربان'),
  CalendarOccasion(CalendarKind.hijri, 12, 11, 'ایام تشریق'),
  CalendarOccasion(CalendarKind.hijri, 12, 12, 'ایام تشریق'),
  CalendarOccasion(CalendarKind.hijri, 12, 13, 'ایام تشریق'),
];

List<CalendarOccasion> occasionsForDay(CalendarKind kind, int month, int day) =>
    kCalendarOccasions
        .where((e) => e.kind == kind && e.month == month && e.day == day)
        .toList();

// ══════════════════════════════════════════════════════════════
//  DATA MODELS
// ══════════════════════════════════════════════════════════════

class CalendarCellData {
  final int day; // Jalali day
  final int hijriDay;
  final int gregorianDay;
  final bool isToday, hasEvent, hasWorship;
  final bool hasJournal;
  final DateTime? gregorianDate;

  const CalendarCellData({
    required this.day,
    required this.hijriDay,
    required this.gregorianDay,
    required this.isToday,
    required this.hasEvent,
    required this.hasWorship,
    this.hasJournal = false,
    this.gregorianDate,
  });

  const CalendarCellData.empty()
      : day = 0,
        hijriDay = 0,
        gregorianDay = 0,
        isToday = false,
        hasEvent = false,
        hasWorship = false,
        hasJournal = false,
        gregorianDate = null;
}

/// The page's selection, published as one immutable value.
///
/// The selected day is not part of [CalendarCellData] because a tap changes
/// it: baking it into the 30 cell models forced the page to rebuild the whole
/// grid (563 element rebuilds for one tap). The header, the summary, the
/// journal and each cell's ring listen to this value instead, so a tap
/// rebuilds only what shows the selected day.
class CalendarSelection {
  final int jYear, jMonth, jDay;
  final int hYear, hMonth, hDay;
  final int gYear, gMonth, gDay;

  /// The selected day's occasions and sunnah fasts, already resolved.
  final List<String> events;

  const CalendarSelection({
    required this.jYear,
    required this.jMonth,
    required this.jDay,
    required this.hYear,
    required this.hMonth,
    required this.hDay,
    required this.gYear,
    required this.gMonth,
    required this.gDay,
    required this.events,
  });

  DateTime get date => DateTime(gYear, gMonth, gDay);

  bool isDay(DateTime d) =>
      gYear == d.year && gMonth == d.month && gDay == d.day;

  bool sameMonth(int year, int month) => jYear == year && jMonth == month;
}

class CalendarMonthEvent {
  final int hijriDay;
  final DateTime gregorianDate;
  final String label;
  const CalendarMonthEvent(
      {required this.hijriDay,
      required this.gregorianDate,
      required this.label});
}

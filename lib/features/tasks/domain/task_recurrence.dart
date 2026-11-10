/// Recurrence rules for tasks («کارهای تکراری»).
///
/// The DB stores the pattern in [TaskModel.recurringType] as one of the
/// [daily]/[weekly] constants (kept as plain strings for legacy-drift
/// compatibility). Completion of a recurring task rolls it forward to its
/// next occurrence instead of leaving it finished, so a daily/weekly duty
/// (e.g. an adhkar routine) is always waiting in the pending list.
class TaskRecurrence {
  TaskRecurrence._();

  static const String daily = 'daily';
  static const String weekly = 'weekly';
  static const String monthly = 'monthly';
  static const String everyNDays = 'every_n_days';

  static const int defaultIntervalDays = 3;

  /// The stored [recurringType] for an «هر N روز» task encodes N as
  /// `every_n_days:N` — no schema change needed; every other consumer only
  /// pattern-matches the base type through [baseOf].
  static String encodeEveryN(int days) => '$everyNDays:$days';

  /// Base pattern of a stored type ('every_n_days:5' → 'every_n_days').
  static String? baseOf(String? type) {
    if (type == null) return null;
    if (type.startsWith('$everyNDays:')) return everyNDays;
    return type;
  }

  /// Extracted N of an every-N-days type (default when absent/unparseable).
  static int intervalOf(String? type) {
    if (type == null || !type.startsWith('$everyNDays:')) {
      return defaultIntervalDays;
    }
    return int.tryParse(type.substring(everyNDays.length + 1)) ??
        defaultIntervalDays;
  }

  /// Patterns the UI can create. Anything else is treated as one-off.
  static bool isSupported(String? type) {
    final base = baseOf(type);
    return base == daily ||
        base == weekly ||
        base == monthly ||
        base == everyNDays;
  }

  /// Persian weekday names indexed 0=Saturday..6=Friday, matching
  /// `(date.weekday + 1) % 7` (Dart weekday is 1=Monday..7=Sunday).
  static const List<String> weekdayNamesFa = <String>[
    'شنبه',
    'یکشنبه',
    'دوشنبه',
    'سه‌شنبه',
    'چهارشنبه',
    'پنجشنبه',
    'جمعه',
  ];

  /// Persian name of the weekday of [date] («چهارشنبه» …).
  static String weekdayNameFa(DateTime date) =>
      weekdayNamesFa[(date.weekday + 1) % 7];

  /// Next date on Dart [weekday] (1=Monday..7=Sunday), on or after [from]'s
  /// day. Used to anchor a weekly task like «every Wednesday» on its first
  /// occurrence.
  static DateTime nextWeekday(DateTime from, int weekday) {
    final base = DateTime(from.year, from.month, from.day);
    final delta = (weekday - base.weekday) % 7;
    return base.add(Duration(days: delta));
  }

  /// Persian label shown on the tile / in the dialog.
  static String? label(String? type) {
    switch (baseOf(type)) {
      case daily:
        return 'روزانه';
      case weekly:
        return 'هفتگی';
      case monthly:
        return 'ماهانه';
      case everyNDays:
        return 'هر ${intervalOf(type)} روز';
      default:
        return null;
    }
  }

  /// Current streak: consecutive filled periods ending at [now], tolerating
  /// one missing current period (checked this morning but not yet today still
  /// counts). Pure — unit tested.
  ///
  /// The period is the task's own cadence: a day for [daily], an Iranian
  /// Saturday-week for [weekly], a calendar month for [monthly], and a window
  /// of N days for [everyNDays].
  ///
  /// WHY the extra cases: this used to treat everything except [weekly] as
  /// daily, so a monthly task — completed every thirty days, exactly as asked —
  /// could never count past one. The badge that shows a streak from two upward
  /// therefore never appeared for monthly or «هر N روز» tasks at all.
  static int currentStreak(
      List<DateTime> completions, String? type, DateTime now) {
    if (completions.isEmpty) return 0;
    final base = baseOf(type);
    DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
    final filled = {for (final c in completions) dayOnly(c)};

    // Whole days between two dates without the DST trap (`inDays` on a local
    // span truncates a 23-hour day to 0).
    int daysBetween(DateTime a, DateTime b) => DateTime.utc(b.year, b.month, b.day)
        .difference(DateTime.utc(a.year, a.month, a.day))
        .inDays;

    /// The period containing [day], as its first day and its length.
    ({DateTime start, int days}) windowOf(DateTime day) {
      final d = dayOnly(day);
      switch (base) {
        case weekly:
          final daysSinceSat = (d.weekday + 1) % 7;
          return (start: d.subtract(Duration(days: daysSinceSat)), days: 7);
        case monthly:
          final start = DateTime(d.year, d.month);
          final next = DateTime(d.year, d.month + 1);
          return (start: start, days: daysBetween(start, next));
        case everyNDays:
          final n = intervalOf(type).clamp(1, 3650);
          final epoch =
              DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(1970)).inDays;
          final offset = epoch % n;
          return (start: d.subtract(Duration(days: offset)), days: n);
        default:
          return (start: d, days: 1);
      }
    }

    bool hasPeriod(DateTime day) {
      final w = windowOf(day);
      if (w.days == 1) return filled.contains(w.start);
      for (var i = 0; i < w.days; i++) {
        if (filled.contains(w.start.add(Duration(days: i)))) return true;
      }
      return false;
    }

    DateTime stepBack(DateTime day) =>
        windowOf(day).start.subtract(const Duration(days: 1));

    var cursor = dayOnly(now);
    // Tolerate one missing current period, but not two in a row.
    if (!hasPeriod(cursor)) {
      cursor = stepBack(cursor);
      if (!hasPeriod(cursor)) return 0;
    }
    var streak = 0;
    while (hasPeriod(cursor)) {
      streak++;
      cursor = stepBack(cursor);
    }
    return streak;
  }

  /// The next due date after the instance was completed on [completedAt].
  ///
  /// The cadence anchors on the instance's own [dueDate] when it has one
  /// (a weekly task due Monday rolls to next Monday even if the user checks
  /// it on Tuesday), otherwise on the completion day. Whole missed periods
  /// (overdue gaps) are skipped: the result is always strictly after the day
  /// the task was completed.
  static DateTime? nextDue({
    required String type,
    required DateTime? dueDate,
    required DateTime completedAt,
  }) {
    if (!isSupported(type)) return null;
    final base = baseOf(type)!;
    final anchor = dueDate ?? completedAt;
    final start = DateTime(anchor.year, anchor.month, anchor.day);
    final after =
        DateTime(completedAt.year, completedAt.month, completedAt.day);

    // Monthly anchors on the day-of-month (clamped to the target month's
    // length — 31st → Feb 28/29), same rule as ExpenseRecurrence.next.
    if (base == monthly) {
      var y = start.year;
      var m = start.month;
      final day = start.day;
      var next = _monthDay(y, m, day);
      while (!next.isAfter(after)) {
        m++;
        if (m > 12) {
          m = 1;
          y++;
        }
        next = _monthDay(y, m, day);
      }
      return next;
    }

    if (base == everyNDays) {
      final step = intervalOf(type).clamp(2, 30);
      var next = start.add(Duration(days: step));
      while (!next.isAfter(after)) {
        next = next.add(Duration(days: step));
      }
      return next;
    }

    final stepDays = base == weekly ? 7 : 1;

    var next = start.add(Duration(days: stepDays));
    while (!next.isAfter(after)) {
      next = next.add(Duration(days: stepDays));
    }
    return next;
  }

  /// [day] clamped to the last day of year [y] / month [m].
  static DateTime _monthDay(int y, int m, int day) {
    final last = DateTime(y, m + 1, 0).day;
    return DateTime(y, m, day.clamp(1, last));
  }
}

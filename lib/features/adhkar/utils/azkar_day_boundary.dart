import 'package:shared_preferences/shared_preferences.dart';

/// Logical "dhikr day" boundary shared by the azkar status repository and the
/// azkar provider.
///
/// Adhkar progress rows are keyed by a date string. When the user sets a
/// reset time other than 00:00 (`azkar_resetHour` / `azkar_resetMinute`), the
/// day that owns "today's" rows must shift accordingly — between midnight
/// and the reset deadline yesterday's day is still current, matching the
/// tasbih auto-reset behaviour.
class AzkarDayBoundary {
  AzkarDayBoundary._();

  static int resetHour = 0;
  static int resetMinute = 0;

  /// Reads the persisted reset time; safe to call before any provider builds.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      resetHour = prefs.getInt('azkar_resetHour') ?? 0;
      resetMinute = prefs.getInt('azkar_resetMinute') ?? 0;
    } catch (_) {
      // Prefs unavailable (e.g. tests) — keep the midnight default.
    }
  }

  static void set(int hour, int minute) {
    resetHour = hour;
    resetMinute = minute;
  }

  /// The calendar date whose progress rows are current at [now].
  static String dayKey(DateTime now) {
    if (resetHour == 0 && resetMinute == 0) return _date(now);
    final deadline =
        DateTime(now.year, now.month, now.day, resetHour, resetMinute);
    final effective =
        now.isBefore(deadline) ? now.subtract(const Duration(days: 1)) : now;
    return _date(effective);
  }

  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

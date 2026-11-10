import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/date_key.dart';

/// SharedPreferences key holding the last calendar day (YYYY-MM-DD) on which
/// the tasbih daily reset already ran. Shared by the reset logic, the boot
/// maintenance timer and the azkar/tasbih tab's midnight timer.
const tasbihLastActiveDateKey = 'tasbih_last_active_date';

/// The daily-reset boundary for [now], or null when the counters must be left
/// alone for this moment.
///
/// Carries both values the reset needs so no caller can re-derive them and
/// drift: [today] is the key to stamp once the reset has run, [deadline] is the
/// boundary that invalidates earlier counts (the app-change marker uses it, not
/// the execution time).
///
/// The reset settings (`azkar_autoReset` / `azkar_resetHour` /
/// `azkar_resetMinute`) are read straight from SharedPreferences because they
/// are authoritative: the `azkarSettingsProvider` notifier loads them
/// asynchronously, so a fresh `ref.read` returns defaults and would make every
/// decision wrong (e.g. resetting when the user disabled auto-reset, or
/// ignoring a custom reset time).
///
/// Returns null when auto-reset is off, the daily key is already stamped for
/// today, the reset deadline is still in the future, or prefs could not be read
/// — a failed read must not silently zero the user's counters.
Future<({String today, DateTime deadline})?> tasbihResetDecision(
    DateTime now) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('azkar_autoReset') ?? true)) return null;
    final today = dateKeyOf(now);
    final lastDate = prefs.getString(tasbihLastActiveDateKey);
    if (lastDate == today) return null;
    final hour = prefs.getInt('azkar_resetHour') ?? 0;
    final minute = prefs.getInt('azkar_resetMinute') ?? 0;
    final deadline = DateTime(now.year, now.month, now.day, hour, minute);
    if (now.isBefore(deadline)) return null;
    return (today: today, deadline: deadline);
  } catch (e) {
    AppLogger.warning('tasbih_daily_reset', 'reset check failed: $e');
    return null;
  }
}

/// Whether the configured tasbih daily-reset boundary for [now] has already
/// passed while the counters were NOT reset yet today.
Future<bool> isTasbihDailyResetOverdue(DateTime now) async =>
    await tasbihResetDecision(now) != null;

/// The next instant at which [tasbihResetDecision] could possibly return
/// non-null, or null when auto-reset is off and no boundary matters.
///
/// WHY this exists: the azkar/tasbih tab used to answer the same question with
/// `Timer.periodic(Duration(minutes: 1))` — a prefs read every sixty seconds,
/// 1,440 a day, to catch one nightly event. A timer aimed at the boundary does
/// the same work once. This is the arithmetic it needs, kept next to the
/// decision it predicts so the two cannot drift: both read the same three
/// prefs keys and both treat a failed read the same way.
///
/// The default reset is 00:00, so today's boundary is already past for most of
/// the day and the answer is tomorrow's midnight — which also happens to be the
/// calendar-day rollover the old date-key check watched for, so one timer
/// covers both cases.
///
/// Returns null on a prefs read failure: the caller then schedules nothing and
/// the reset is retried on the next app resume, rather than being guessed at.
Future<DateTime?> tasbihNextResetBoundary(DateTime now) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('azkar_autoReset') ?? true)) return null;
    final hour = prefs.getInt('azkar_resetHour') ?? 0;
    final minute = prefs.getInt('azkar_resetMinute') ?? 0;
    final todayBoundary =
        DateTime(now.year, now.month, now.day, hour, minute);
    if (now.isBefore(todayBoundary)) return todayBoundary;
    // Tomorrow's boundary. `DateTime(y, m, d + 1, …)` rolls the month and year
    // correctly, which is why this is not a `Duration(days: 1)` add: a DST
    // transition makes one day 23 or 25 hours long.
    return DateTime(now.year, now.month, now.day + 1, hour, minute);
  } catch (e) {
    AppLogger.warning('tasbih_daily_reset', 'boundary read failed: $e');
    return null;
  }
}

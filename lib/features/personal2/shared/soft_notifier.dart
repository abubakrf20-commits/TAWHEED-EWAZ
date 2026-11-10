import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:tawheeed/shared/utils/app_logger.dart';

/// ═══════════════════════════════════════════════════════════════
/// SoftNotifier — the wrapper every personal-tool reminder goes through.
///
/// [NotificationService] already schedules exact alarms per feature. What it
/// does NOT have (grep finds nothing) is the policy layer these tools need:
/// quiet hours, a daily cap, and collapsing a day's nudges into one summary.
/// Those are the whole point of "soft": a children's habits app must not
/// buzz a phone nine times about the same evening.
///
/// Policy, in the order it is applied:
///  1. **Quiet hours** — a reminder inside the window is not dropped, it is
///     moved to the window's end (a nudge at 02:00 arrives at the morning
///     boundary), because silently losing it means the parent never hears it.
///  2. **Daily cap** — at most [dailyCap] nudges per tool per day; the overflow
///     is folded into the single summary id, not queued.
///  3. **Grouping** — a summary is one notification with a count, on its own
///     reserved id, so a burst collapses in the shade.
///
/// ID ranges (documented here because the brief requires it):
///   kids    : 14000 + stableSlot(key, 1000) → 14000..14999
///   teacher : 15000 + stableSlot(key, 1000) → 15000..15999
///   kids summary    : 14999
///   teacher summary : 15999
/// [NotificationIds.stableSlot] is read via its public API, and these bases are
/// clear of every range in use (highest existing base is 13000).
/// ═══════════════════════════════════════════════════════════════
class SoftNotifier {
  SoftNotifier({NotificationPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationPluginAdapter();

  final NotificationPlugin _plugin;

  // ── Reserved id ranges ───────────────────────────────────────────────

  static const int kidsBase = 14000;
  static const int kidsSpace = 1000;
  static const int kidsSummaryId = 14999;

  static const int teacherBase = 15000;
  static const int teacherSpace = 1000;
  static const int teacherSummaryId = 15999;

  /// One channel for both tools, versioned in its name as the brief requires.
  static const String channelId = 'personal2_tools_v1';
  static const String channelName = 'یادآوری ابزارهای شخصی';
  static const String channelDescription =
      'یادآوری‌های دفتر عادت کودک و دفتر مربی قرآن (همه اختیاری)';

  /// Max nudges per tool per local day, before the summary takes over.
  static const int dailyCap = 3;

  /// Which tool a notification belongs to; decides range and channel copy.
  static int idFor({
    required String tool,
    required String key,
  }) {
    // The slot space is one short of the range: a slot of 999 would land
    // exactly on the summary id, so a reminder could silently replace the
    // day's summary. Reserving that one id makes the collision impossible by
    // construction instead of by luck.
    // The 1.9.0 move renamed the teacher tool key to 'quran_teacher'; accept
    // both spellings so nudges keep landing in the teacher range (15000+) and
    // never collide with the kids block — the rename alone silently sent every
    // teacher nudge into the kids range (unit 7 audit, caught by the
    // teacher_reminders test).
    final isTeacher = tool == 'teacher' || tool == 'quran_teacher';
    final base = isTeacher ? teacherBase : kidsBase;
    final space = (isTeacher ? teacherSpace : kidsSpace) - 1;
    return base + _slot(key, space);
  }

  /// FNV-1a slot, matching `NotificationIds.stableSlot`. Duplicated here
  /// rather than imported so the two ranges stay independently auditable; the
  /// unit test pins both implementations to the same output.
  static int _slot(String key, int space) {
    assert(space > 0, 'space must be positive');
    var hash = 0x811c9dc5;
    for (final unit in key.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash % space;
  }

  // ── Scheduling ───────────────────────────────────────────────────────

  /// Schedules one nudge, applying quiet hours and the daily cap.
  ///
  /// Returns true when something was actually scheduled. An unhealthy phone
  /// (channel creation refused, exact-alarm permission missing) returns false
  /// with a log line — never an exception into the caller's build method.
  Future<bool> schedule({
    required String tool,
    required String key,
    required String title,
    required String body,
    required DateTime when,
    required int quietStartMinutes,
    required int quietEndMinutes,
    String? payload,
    int alreadyScheduledToday = 0,
    DateTime? now,
  }) async {
    try {
      await _ensureChannel();

      // The caller's clock, not the wall clock: a service that already resolved
      // "today" from an injected `now` must not have its target dropped (or
      // pushed a day later) by a wall clock on the other side of midnight.
      final current = _asLocal(now ?? tz.TZDateTime.now(tz.local));
      var target = _asLocal(when);
      if (!target.isAfter(current)) return false; // already past: nothing to say

      // 1. Quiet hours.
      target = _moveOutOfQuietHours(target, quietStartMinutes, quietEndMinutes);
      if (!target.isAfter(current)) return false;
      // 2. Daily cap — overflow belongs to the summary, not to a 4th buzz.
      if (alreadyScheduledToday >= dailyCap) {
        await _scheduleSummaryIfPossible(
          tool: tool,
          when: target,
          quietStartMinutes: quietStartMinutes,
          quietEndMinutes: quietEndMinutes,
        );
        return false;
      }

      await _plugin.schedule(
        id: idFor(tool: tool, key: key),
        title: title,
        body: body,
        scheduledDate: target,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            icon: '@drawable/ic_notification',
            color: tool == 'teacher' ? _teacherAccent : _kidsAccent,
            // These are educational nudges, not alarms: «reminder» keeps them
            // out of the alarm stream so they never compete with a prayer
            // adhan for the same minute.
            category: AndroidNotificationCategory.reminder,
          ),
        ),
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      return true;
    } catch (e) {
      AppLogger.warning('SoftNotifier', 'schedule failed: $e');
      return false;
    }
  }

  /// Cancels one scheduled nudge by its stable key.
  Future<void> cancel({required String tool, required String key}) async {
    try {
      await _plugin.cancel(id: idFor(tool: tool, key: key));
    } catch (e) {
      AppLogger.warning('SoftNotifier', 'cancel failed: $e');
    }
  }

  /// Cancels everything this feature ever scheduled (both ranges). Used when a
  /// tool's reminders are switched off, so a stale alarm cannot survive.
  Future<void> cancelAll() async {
    try {
      for (var i = 0; i < kidsSpace; i++) {
        await _plugin.cancel(id: kidsBase + i);
      }
      await _plugin.cancel(id: kidsSummaryId);
      for (var i = 0; i < teacherSpace; i++) {
        await _plugin.cancel(id: teacherBase + i);
      }
      await _plugin.cancel(id: teacherSummaryId);
    } catch (e) {
      AppLogger.warning('SoftNotifier', 'cancelAll failed: $e');
    }
  }

  // ── Policy helpers (pure, unit-tested) ───────────────────────────────

  /// Moves [when] to the end of the quiet window when it falls inside it.
  ///
  /// The window may cross midnight (`start 22:00, end 07:00`). A target inside
  /// it is pushed to the end boundary on the NEXT day when the window wraps and
  /// the target is before the end boundary, and on the same day otherwise.
  static tz.TZDateTime moveOutOfQuietHours(
    tz.TZDateTime when,
    int quietStartMinutes,
    int quietEndMinutes,
  ) =>
      _moveOutOfQuietHours(when, quietStartMinutes, quietEndMinutes);

  static tz.TZDateTime _moveOutOfQuietHours(
    tz.TZDateTime when,
    int startMinutes,
    int endMinutes,
  ) {
    if (startMinutes == endMinutes) return when; // window disabled
    final minutesOfDay = when.hour * 60 + when.minute;

    final wraps = startMinutes > endMinutes;
    final inside = wraps
        ? (minutesOfDay >= startMinutes || minutesOfDay < endMinutes)
        : (minutesOfDay >= startMinutes && minutesOfDay < endMinutes);
    if (!inside) return when;

    if (wraps && minutesOfDay >= startMinutes) {
      // Late evening: the window ends tomorrow morning.
      final nextDay = tz.TZDateTime(
        tz.local,
        when.year,
        when.month,
        when.day,
      ).add(const Duration(days: 1));
      return _atMinutes(nextDay, endMinutes);
    }
    return _atMinutes(
      tz.TZDateTime(tz.local, when.year, when.month, when.day),
      endMinutes,
    );
  }

  /// Builds a wall-clock time on [day] at [minutesOfDay], resolving both the
  /// hour/minute and any DST shift through the timezone database (`tz.TZDateTime`
  /// normalises a spring-forward gap instead of producing 02:30 that never
  /// happens).
  static tz.TZDateTime _atMinutes(tz.TZDateTime day, int minutesOfDay) {
    final h = minutesOfDay ~/ 60;
    final m = minutesOfDay % 60;
    return tz.TZDateTime(tz.local, day.year, day.month, day.day, h, m);
  }

  static tz.TZDateTime _asLocal(DateTime when) {
    if (when is tz.TZDateTime) return when;
    return tz.TZDateTime(
      tz.local,
      when.year,
      when.month,
      when.day,
      when.hour,
      when.minute,
    );
  }

  /// Pure predicate: is [minutesOfDay] inside a (possibly wrapping) window?
  static bool isQuiet(
    int minutesOfDay,
    int startMinutes,
    int endMinutes,
  ) {
    if (startMinutes == endMinutes) return false;
    if (startMinutes > endMinutes) {
      return minutesOfDay >= startMinutes || minutesOfDay < endMinutes;
    }
    return minutesOfDay >= startMinutes && minutesOfDay < endMinutes;
  }

  // ── Summary grouping ─────────────────────────────────────────────────

  /// Schedules (or replaces) the one summary notification for [tool].
  Future<bool> _scheduleSummaryIfPossible({
    required String tool,
    required tz.TZDateTime when,
    required int quietStartMinutes,
    required int quietEndMinutes,
  }) async {
    final target =
        _moveOutOfQuietHours(when, quietStartMinutes, quietEndMinutes);
    try {
      await _plugin.schedule(
        id: tool == 'teacher' ? teacherSummaryId : kidsSummaryId,
        title: tool == 'teacher' ? 'دفتر مربی قرآن' : 'دفتر عادت کودک',
        body: tool == 'teacher'
            ? 'چند یادآوری مربی در انتظار است؛ دفتر را باز کنید.'
            : 'چند کار امروز مانده است؛ یک نگاه به دفتر بیندازید.',
        scheduledDate: target,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            importance: Importance.low,
            priority: Priority.low,
            icon: '@drawable/ic_notification',
            color: tool == 'teacher' ? _teacherAccent : _kidsAccent,
            category: AndroidNotificationCategory.reminder,
            // One row in the shade, however many nudges it stands for.
            groupKey: 'personal2_$tool',
            setAsGroupSummary: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      return true;
    } catch (e) {
      AppLogger.warning('SoftNotifier', 'summary failed: $e');
      return false;
    }
  }

  Future<void> _ensureChannel() async {
    try {
      await _plugin.channelRequester?.createNotificationChannel(
        const AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
        ),
      );
    } catch (e) {
      // A refused channel is a device-policy problem; the scheduler keeps
      // working and the notification simply arrives on the fallback channel.
      AppLogger.warning('SoftNotifier', 'create channel failed: $e');
    }
  }

  static const Color _kidsAccent = Color(0xFFE58A2B);
  static const Color _teacherAccent = Color(0xFF1F7A63);
}

/// The three plugin calls [SoftNotifier] needs, extracted so tests can stand
/// in a fake without a platform channel.
abstract class NotificationPlugin {
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    String? payload,
    AndroidScheduleMode? androidScheduleMode,
  });

  Future<void> cancel({required int id});

  /// Returns the Android plugin surface, or null on another platform.
  /// Typed as `Object?`-free: callers only need `createNotificationChannel`,
  /// so the adapter narrows it for them.
  RequestChannel? get channelRequester;
}

/// The one capability [SoftNotifier] needs from the platform object.
abstract class RequestChannel {
  Future<void> createNotificationChannel(AndroidNotificationChannel channel);
}

/// The real implementation, delegating to flutter_local_notifications.
class FlutterLocalNotificationPluginAdapter implements NotificationPlugin {
  FlutterLocalNotificationPluginAdapter([FlutterLocalNotificationsPlugin? p])
      : _plugin = p ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    String? payload,
    AndroidScheduleMode? androidScheduleMode,
  }) =>
      _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode:
            androidScheduleMode ?? AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );

  @override
  Future<void> cancel({required int id}) => _plugin.cancel(id: id);

  @override
  RequestChannel? get channelRequester {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return android == null ? null : _AndroidChannelRequester(android);
  }
}

class _AndroidChannelRequester implements RequestChannel {
  const _AndroidChannelRequester(this._android);

  final AndroidFlutterLocalNotificationsPlugin _android;

  @override
  Future<void> createNotificationChannel(AndroidNotificationChannel channel) =>
      _android.createNotificationChannel(channel);
}

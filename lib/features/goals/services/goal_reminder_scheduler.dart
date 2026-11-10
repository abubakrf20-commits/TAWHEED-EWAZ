import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/goals/domain/goal_query.dart';
import 'package:tawheeed/shared/services/notification_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Daily OS notifications for goals that carry a «یادآوری روزانه».
///
/// Isolation rules (see `notification_ids.dart` and the task scheduler):
///  * every notification this service owns has a payload starting with
///    `goal_`, so cleanup is payload-scoped and never touches prayer azan
///    (100–524), custom reminders (1000–1999), the daily content windows
///    (7000–8266), task reminders (10000–10949) or personal-info expiry
///    (11000–11949);
///  * ids live in 12000–12949, a range nothing else claims.
///
/// The notification is DAILY, not one-shot. That is the whole difference from
/// the task scheduler: a task has one due date, a goal like «مطالعه روزانه»
/// needs showing up every day until the user turns it off.
///
/// Relies on `NotificationService().init()` having aligned `tz.local` with the
/// device timezone (called once at app startup).
class GoalReminderScheduler {
  GoalReminderScheduler._();

  static const String _payloadPrefix = 'goal_';
  static const int _idBase = 12000;
  static const int _idSpace = 950;

  static const String _channelId = 'goal_daily_reminders';

  static FlutterLocalNotificationsPlugin get _plugin =>
      NotificationService().plugin;

  /// Whether [goal] deserves a daily notification: enabled, a time set, not
  /// archived, and still reachable.
  ///
  /// A completed goal is skipped deliberately. Once the target is met, a daily
  /// "keep going" prompt is noise, and it is the most likely reason a user
  /// would turn reminders off entirely — losing the ones that still matter.
  static bool shouldSchedule(GoalTableData goal, {required bool isComplete}) =>
      goal.remindEnabled &&
      !goal.isArchived &&
      !isComplete &&
      _parseHm(goal.remindAt) != null;

  /// Re-syncs one goal: cancels whatever was scheduled, then schedules the
  /// daily reminder when applicable. Never throws.
  static Future<void> syncFor(GoalTableData goal,
      {required bool isComplete}) async {
    try {
      await cancelByPayload(goal.id);
      if (!shouldSchedule(goal, isComplete: isComplete)) return;
      await _schedule(goal);
    } catch (e) {
      AppLogger.warning('GoalReminder', 'syncFor ${goal.id} failed: $e');
    }
  }

  /// Cancels + reschedules every goal reminder, so they survive app restarts
  /// and reboots. Never throws.
  static Future<void> syncAll(
    Iterable<GoalTableData> goals,
    Map<String, int> totals,
  ) async {
    try {
      await cancelAll();
      for (final g in goals) {
        if (shouldSchedule(g, isComplete: _isComplete(g, totals[g.id] ?? 0))) {
          await _schedule(g);
        }
      }
    } catch (e) {
      AppLogger.warning('GoalReminder', 'syncAll failed: $e');
    }
  }

  /// Drops every pending goal notification. Never throws.
  static Future<void> cancelAll() async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final p in pending) {
        if (p.payload != null && p.payload!.startsWith(_payloadPrefix)) {
          await _plugin.cancel(id: p.id);
        }
      }
    } catch (e) {
      AppLogger.warning('GoalReminder', 'cancelAll failed: $e');
    }
  }

  static Future<void> cancelByPayload(String goalId) async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final p in pending) {
        if (p.payload == '$_payloadPrefix$goalId') {
          await _plugin.cancel(id: p.id);
        }
      }
    } catch (e) {
      AppLogger.warning('GoalReminder', 'cancel $goalId failed: $e');
    }
  }

  /// Mirror of [GoalListEntry.isComplete], for callers holding a raw row.
  static bool _isComplete(GoalTableData goal, int total) {
    if (goal.targetType == 'boolean') return total > 0;
    if (goal.targetNumber <= 0) return false;
    return total >= goal.targetNumber;
  }

  static ({int hour, int minute})? _parseHm(String hm) {
    if (hm.isEmpty) return null;
    final parts = hm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    return (hour: h, minute: m);
  }

  static Future<void> _schedule(GoalTableData goal) async {
    final hm = _parseHm(goal.remindAt);
    if (hm == null) {
      // A malformed time used to fail silently, and the user believed the
      // reminder was saved. Logged so diagnostics can surface the cause.
      AppLogger.warning('GoalReminder',
          'goal ${goal.id} has malformed remindAt "${goal.remindAt}" — not scheduled');
      return;
    }

    final now = tz.TZDateTime.now(tz.local);
    // Tomorrow's occurrence: today's has usually passed by the time the user
    // creates the goal, and scheduling a time already in the past either
    // throws or fires immediately.
    var when = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hm.hour, hm.minute);
    if (!when.isAfter(now)) {
      when = when.add(const Duration(days: 1));
    }

    await _ensureChannel();
    await NotificationService().refreshScheduleMode();

    await NotificationService().scheduleExactReminder(
      id: _idFor(goal.id),
      title: 'یادآوری: ${goal.title}',
      body: _bodyFor(goal),
      scheduledTime: when,
      // The difference from the task scheduler: this repeats every day. The
      // platform handles the recurrence, so a single request is scheduled and
      // `cancelByPayload` still drops it by payload.
      matchDateTimeComponents: DateTimeComponents.time,
      details: const AndroidNotificationDetails(
        _channelId,
        'یادآوری روزانه اهداف',
        channelDescription: 'یادآوری روزانه برای اهداف در جریان',
        icon: '@drawable/ic_notification',
        color: TopicHues.goals,
      ),
      payload: '$_payloadPrefix${goal.id}',
    );
  }

  static String _bodyFor(GoalTableData goal) {
    if (goal.dailyTarget > 0) {
      return 'امروز ${goal.dailyTarget} واحد از «${goal.title}» را ثبت کنید.';
    }
    if (goal.deadline.isNotEmpty) {
      return 'یادآوری روزانهٔ «${goal.title}» — تا مهلت باقی مانده است.';
    }
    return 'یادآوری روزانهٔ «${goal.title}»';
  }

  /// Stable id per goal, so re-syncing replaces rather than accumulates.
  static int _idFor(String goalId) =>
      _idBase + NotificationIds.stableSlot(goalId, _idSpace);

  /// Creates the goals channel on Android (no-op when it already exists, and
  /// on other platforms). Never throws.
  static Future<void> _ensureChannel() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          'یادآوری روزانه اهداف',
          description: 'یادآوری روزانه برای اهداف در جریان',
        ),
      );
    } catch (e) {
      AppLogger.warning('GoalReminder', 'channel creation failed: $e');
    }
  }
}

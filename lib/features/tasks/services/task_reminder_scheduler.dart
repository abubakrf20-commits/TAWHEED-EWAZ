import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/tasks/domain/entities/task_model.dart';
import 'package:tawheeed/shared/services/notification_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// One-shot OS notifications for tasks that carry a due date + an enabled
/// «یادآوری روز سررسید».
///
/// Isolation rules (see also `notification_ids.dart`):
///  * every notification this service owns has a payload starting with
///    `task_`, so cleanup is payload-scoped and never touches prayer azan
///    (100–524), custom reminders (1000–1999) or the daily content windows
///    (7000–8266);
///  * ids are derived from the task id and live in 10000–10949.
///
/// Relies on `NotificationService().init()` having aligned `tz.local` with the
/// device timezone (it is called once at app startup).
class TaskReminderScheduler {
  TaskReminderScheduler._();

  static const String _payloadPrefix = 'task_';
  static const int _idBase = 10000;
  static const int _idSpace = 950;

  static const String _channelId = 'task_due_reminders';

  static FlutterLocalNotificationsPlugin get _plugin =>
      NotificationService().plugin;

  /// Whether [task] currently deserves a scheduled notification: pending,
  /// reminder enabled, and a due date + time configured.
  static bool shouldSchedule(TaskModel task) =>
      !task.isCompleted &&
      task.remindEnabled &&
      task.dueDate != null &&
      task.remindAt != null;

  /// Re-syncs a single task: cancels whatever was scheduled for it, then
  /// schedules the one-shot reminder when applicable. Never throws.
  static Future<void> syncFor(TaskModel task) async {
    try {
      await cancelFor(task);
      if (!shouldSchedule(task)) return;
      await _schedule(task);
    } catch (e) {
      AppLogger.warning('TaskReminder', 'syncFor ${task.id} failed: $e');
    }
  }

  /// Cancels + reschedules every task notification (used after the initial
  /// load so reminders survive app restarts / reboots). Never throws.
  static Future<void> syncAll(Iterable<TaskModel> tasks) async {
    try {
      await cancelAll();
      for (final t in tasks) {
        if (shouldSchedule(t)) await _schedule(t);
      }
    } catch (e) {
      AppLogger.warning('TaskReminder', 'syncAll failed: $e');
    }
  }

  /// Drops the scheduled notification for [task] (payload-scoped). Never
  /// throws.
  static Future<void> cancelFor(TaskModel task) => cancelByPayload(task.id);

  static Future<void> cancelByPayload(String taskId) async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final p in pending) {
        if (p.payload == '$_payloadPrefix$taskId') {
          await _plugin.cancel(id: p.id);
        }
      }
    } catch (e) {
      AppLogger.warning('TaskReminder', 'cancel $taskId failed: $e');
    }
  }

  /// Drops every pending task notification. Never throws.
  static Future<void> cancelAll() async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final p in pending) {
        if (p.payload != null && p.payload!.startsWith(_payloadPrefix)) {
          await _plugin.cancel(id: p.id);
        }
      }
    } catch (e) {
      AppLogger.warning('TaskReminder', 'cancelAll failed: $e');
    }
  }

  static Future<void> _schedule(TaskModel task) async {
    final hm = _parseHm(task.remindAt);
    final due = task.dueDate;
    if (hm == null || due == null) {
      // Malformed time used to fail silently (user believed the reminder was
      // saved). Log it so diagnostics can surface the cause.
      if (due != null && hm == null) {
        AppLogger.warning('TaskReminder',
            'task ${task.id} has malformed remindAt "${task.remindAt}" — not scheduled');
      }
      return;
    }

    final now = tz.TZDateTime.now(tz.local);
    final when =
        tz.TZDateTime(tz.local, due.year, due.month, due.day, hm.$1, hm.$2);

    // The channel is created here (idempotent) so this scheduler never
    // depends on another file's channel manifest; without it Android 8+
    // silently falls back to default importance.
    await _ensureChannel();
    // Honor the exact-alarm grant like the reminder scheduler does: exact
    // when granted, idle-safe inexact otherwise (never throws).
    await NotificationService().refreshScheduleMode();

    // Due-day reminder.
    if (when.isAfter(now)) {
      await _scheduleAt(
        task,
        when,
        title: 'یادآوری: ${task.title}',
        body: 'سررسید امروز این کار فرا رسیده است',
      );
    }
    // Day-before heads-up at the same time, so the user can prepare.
    final eve = when.subtract(const Duration(days: 1));
    if (eve.isAfter(now)) {
      await _scheduleAt(
        task,
        eve,
        title: 'یادآوری: ${task.title}',
        body: 'فردا موعد این کار است',
      );
    }
  }

  /// Schedules one notification; a second [_scheduleAt] call for the same
  /// task gets a bumped id via [_allocId] while sharing the payload, so
  /// [cancelFor] still drops both at once.
  static Future<void> _scheduleAt(
    TaskModel task,
    tz.TZDateTime when, {
    required String title,
    required String body,
  }) async {
    await NotificationService().scheduleExactReminder(
      id: await _allocId(task.id),
      title: title,
      body: body,
      scheduledTime: when,
      details: const AndroidNotificationDetails(
        _channelId,
        'یادآوری سررسید کارها',
        channelDescription: 'یادآوری کارهایی که امروز سررسید دارند',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@drawable/ic_notification',
        color: TopicHues.tasks,
        visibility: NotificationVisibility.public,
      ),
      payload: '$_payloadPrefix${task.id}',
    );
  }

  /// Creates the task channel on Android (no-op when it already exists, and
  /// a no-op on other platforms). Never throws.
  static Future<void> _ensureChannel() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        _channelId,
        'یادآوری سررسید کارها',
        description: 'یادآوری کارهایی که امروز سررسید دارند',
        importance: Importance.high,
      ));
    } catch (e) {
      AppLogger.warning('TaskReminder', 'create channel failed: $e');
    }
  }

  /// Allocates a collision-free id in [_idBase, _idBase + _idSpace): starts
  /// from the task's stable hash slot and bumps past ids already pending.
  /// Cancel stays payload-scoped, so the bump only affects scheduling —
  /// two tasks can never silently overwrite each other's notification.
  static Future<int> _allocId(String taskId) async {
    var id = _idFor(taskId);
    try {
      final pending = await _plugin.pendingNotificationRequests();
      final used = {for (final p in pending) p.id};
      var guard = 0;
      while (used.contains(id) && guard++ < _idSpace) {
        id++;
        if (id >= _idBase + _idSpace) id = _idBase;
      }
    } catch (_) {
      // Best-effort; fall back to the raw hash slot.
    }
    return id;
  }

  /// Parses "HH:mm" into (hour, minute), or null when malformed.
  static (int, int)? _parseHm(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return (h, m);
  }

  /// Stable (cross-isolate) 32-bit FNV-1a hash of the task id → id space.
  /// Shared with the goal scheduler so both stay on one implementation; see
  /// [NotificationIds.stableSlot] for why `hashCode` is not usable here.
  static int _idFor(String taskId) =>
      _idBase + NotificationIds.stableSlot(taskId, _idSpace);
}

import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:tawheeed/features/personal/finance/finance_models.dart';
import 'package:tawheeed/features/personal/finance/finance_reminder_planner.dart';
import 'package:tawheeed/features/personal/finance/finance_settings.dart';
import 'package:tawheeed/shared/services/notification_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// The seam the finance store calls after every write. Widget tests override
/// the provider with a no-op so they never touch the notification plugin.
abstract class FinanceReminders {
  Future<void> sync(
    FinanceSnapshot snapshot, {
    FinanceReminderSettings? settings,
    String currencyUnit,
  });
}

/// Applies [FinanceReminderPlanner]'s events through the app's ONE
/// notification service (the same `scheduleExactReminder` the prayer and care
/// reminders use, so the alarm mode / exact-alarm permission handling is
/// shared).
///
/// ID range **17000–17399**, documented in `notification_ids.dart`: id =
/// `17000 + day-of-year`, one notification per day by construction, so the
/// range cannot grow with the number of obligations. Payloads start with
/// `finance_`, which is what cancellation keys on — never an id sweep — so
/// every other range is untouchable from here.
///
/// It was 14000–14999 until 2026-11-05, which is the block the kids tool's
/// `SoftNotifier` owns (14000 + slot): a finance reminder could land on a
/// child's habit nudge and replace it. The personal-tools map is now one
/// disjoint table — see `NotificationIds` for the current layout.
class FinanceReminderScheduler implements FinanceReminders {
  const FinanceReminderScheduler();

  static const String payloadPrefix = 'finance_';
  static const int idBase = 17000;
  static const String channelId = 'finance_reminders_v1';
  static const String channelName = 'یادآوری مالی';
  static const String channelDescription =
      'یادآوری چک، قسط، وام و دَین‌های دفتر مالی';

  static FlutterLocalNotificationsPlugin get _plugin =>
      NotificationService().plugin;

  @override
  Future<void> sync(
    FinanceSnapshot snapshot, {
    FinanceReminderSettings? settings,
    String currencyUnit = 'تومان',
  }) async {
    try {
      final resolved = settings ?? await FinanceSettingsStore.load();
      await _ensureChannel();
      await _cancelAll();
      if (!resolved.enabled) return;

      final now = DateTime.now();
      final events = const FinanceReminderPlanner().plan(
        snapshot: snapshot,
        settings: resolved,
        now: now,
        currencyUnit: currencyUnit,
      );
      if (events.isEmpty) return;

      await NotificationService().refreshScheduleMode();
      for (final event in events) {
        await NotificationService().scheduleExactReminder(
          id: idBase + _dayOfYear(event.at),
          title: event.title,
          body: event.body,
          scheduledTime: event.at,
          details: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@drawable/ic_notification',
            color: const Color(0xFFC9922F),
            visibility: NotificationVisibility.public,
            styleInformation: event.isGroup
                ? BigTextStyleInformation(event.body,
                    contentTitle: event.title)
                : null,
          ),
          payload: event.payload,
        );
      }
      AppLogger.info('FinanceReminder',
          'scheduled ${events.length} reminders for ${snapshot.obligations.length} rows');
    } catch (e) {
      // A reminder is a convenience; saving a cheque must never fail because
      // the OS refused a notification.
      AppLogger.warning('FinanceReminder', 'sync failed: $e');
    }
  }

  static Future<void> _cancelAll() async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final p in pending) {
        final payload = p.payload;
        if (payload != null && payload.startsWith(payloadPrefix)) {
          await _plugin.cancel(id: p.id);
        }
      }
    } catch (e) {
      AppLogger.warning('FinanceReminder', 'cancel failed: $e');
    }
  }

  static Future<void> _ensureChannel() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.high,
      ));
    } catch (e) {
      AppLogger.warning('FinanceReminder', 'channel creation failed: $e');
    }
  }

  /// 1–366; keeps every id inside the reserved 14000–14999 block.
  static int _dayOfYear(DateTime date) {
    final start = DateTime(date.year);
    return date.difference(start).inDays + 1;
  }
}

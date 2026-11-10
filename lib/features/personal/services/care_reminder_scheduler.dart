import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:tawheeed/features/personal/care_engine/care_engine.dart';
import 'package:tawheeed/features/personal/care_engine/care_models.dart';
import 'package:tawheeed/features/personal/services/care_reminder_planner.dart';
import 'package:tawheeed/features/personal/services/care_settings.dart';
import 'package:tawheeed/shared/services/notification_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// The seam the store calls after every edit. Tests override the provider with
/// a no-op so widget tests never touch the notification plugin.
abstract class CareReminders {
  Future<void> sync(CareSnapshot snapshot, {CareReminderSettings? settings});

  /// Immediate one-shot when a new odometer reading crosses a task's
  /// `remindBeforeKm` for the first time.
  Future<void> notifyThresholdCrossed({
    required String title,
    required String body,
    required String payload,
  });
}

/// Applies [CareReminderPlanner]'s events through the app's ONE notification
/// service.
///
/// ID range: **13000–13999**, documented in `notification_ids.dart`. Ids are
/// `13000 + day-of-year` (grouped events are one per day), so the range cannot
/// grow with the number of tasks. Every payload starts with `care_`, which is
/// what cancellation keys on — never an id sweep, so prayer azan (100–524),
/// reminders (1000–1999) and tasks (10000–10999) are untouchable from here.
class CareReminderScheduler implements CareReminders {
  const CareReminderScheduler();

  static const String payloadPrefix = 'care_';
  static const int idBase = 13000;
  static const String channelId = 'care_reminders_v1';
  static const String channelName = 'یادآوری ابزارهای شخصی';
  static const String channelDescription =
      'یادآوری سرویس خودرو و خانه، قبض‌ها، گارانتی و اشتراک‌ها';

  static FlutterLocalNotificationsPlugin get _plugin =>
      NotificationService().plugin;

  @override
  Future<void> sync(
    CareSnapshot snapshot, {
    CareReminderSettings? settings,
  }) async {
    try {
      final resolved = settings ?? await CareSettingsStore.load();
      await _ensureChannel();
      await _cancelAll();
      if (!resolved.enabled) return;

      final now = DateTime.now();
      final items = const CareDueItemsProvider()
          .upcoming(snapshot: snapshot, now: now);
      final events = const CareReminderPlanner()
          .plan(items: items, settings: resolved, now: now);
      if (events.isEmpty) return;

      await NotificationService().refreshScheduleMode();
      for (final event in events) {
        final id = idBase + _dayOfYear(event.at);
        await NotificationService().scheduleExactReminder(
          id: id,
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
            color: const Color(0xFF5C6BC0),
            visibility: NotificationVisibility.public,
            styleInformation: event.isGroup
                ? BigTextStyleInformation(event.body, contentTitle: event.title)
                : null,
          ),
          payload: event.payload,
        );
      }
      AppLogger.info('CareReminder',
          'scheduled ${events.length} reminders for ${items.length} items');
    } catch (e) {
      // Reminders are a convenience; an edit must never fail because the OS
      // refused a notification.
      AppLogger.warning('CareReminder', 'sync failed: $e');
    }
  }

  @override
  Future<void> notifyThresholdCrossed({
    required String title,
    required String body,
    required String payload,
  }) async {
    try {
      await _ensureChannel();
      await _plugin.show(
        id: idBase + 998,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@drawable/ic_notification',
            color: Color(0xFF5C6BC0),
            visibility: NotificationVisibility.public,
          ),
        ),
        payload: payload,
      );
    } catch (e) {
      AppLogger.warning('CareReminder', 'threshold notice failed: $e');
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
      AppLogger.warning('CareReminder', 'cancel failed: $e');
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
      AppLogger.warning('CareReminder', 'channel creation failed: $e');
    }
  }

  /// 1–366; keeps every id inside the reserved 13000–13999 block.
  static int _dayOfYear(DateTime date) {
    final start = DateTime(date.year);
    return date.difference(start).inDays + 1;
  }

  /// Kept for the doc-comment contract above; a reminder's local-time day is
  /// what the id encodes.
  static tz.TZDateTime localNow() => tz.TZDateTime.now(tz.local);
}

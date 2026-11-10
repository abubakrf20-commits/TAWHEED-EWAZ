import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/shared/services/notification_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// One-shot OS notifications for «اطلاعات من» expiry items (اقساط، گواهی‌نامه،
/// ویزا، مرور بیمه، چک و...) that carry a due date + an enabled reminder.
///
/// Isolation rules (mirrors `TaskReminderScheduler`, see also
/// `notification_ids.dart`):
///  * every notification this service owns has a payload starting with
///    `expiry_`, so cleanup is payload-scoped and never touches prayer azan
///    (100–524), custom reminders (1000–1999), tasks (10000–10949) or the
///    daily content windows (7000–8266);
///  * ids are derived from the item id and live in 11000–11949.
///
/// Reminders fire once, at 09:00 local on the day the item becomes due
/// (`dueDate - remindDaysBefore`), matching the one-shot semantics the user
/// asked for instead of a daily nag.
///
/// Relies on `NotificationService().init()` having aligned `tz.local` with the
/// device timezone (it is called once at app startup).
class ExpiryReminderScheduler {
  ExpiryReminderScheduler._();

  static const String _payloadPrefix = 'expiry_';
  static const int _idBase = 11000;
  static const int _idSpace = 950;

  /// Reminders land mid-morning so a 0-day-before reminder still reaches the
  /// user on the due date itself.
  static const int _hour = 9;

  static const String _channelId = 'expiry_reminders';

  static FlutterLocalNotificationsPlugin get _plugin =>
      NotificationService().plugin;

  /// Whether [item] currently deserves a scheduled notification: not archived,
  /// reminder enabled, a parsable due date, and a non-negative lead time.
  static bool shouldSchedule(ExpiryItemTableData item) {
    if (item.isArchived || !item.remindEnabled) return false;
    if (item.remindDaysBefore < 0) return false;
    return _parseDate(item.dueDate) != null;
  }

  /// Re-syncs a single item: cancels whatever was scheduled for it, then
  /// schedules the one-shot reminder when applicable. Never throws.
  static Future<void> syncFor(ExpiryItemTableData item) async {
    try {
      await cancelFor(item.id);
      if (!shouldSchedule(item)) return;
      await _schedule(item);
    } catch (e) {
      AppLogger.warning('ExpiryReminder', 'syncFor ${item.id} failed: $e');
    }
  }

  /// Cancels + reschedules every expiry notification (used after the initial
  /// load so reminders survive app restarts / reboots). Never throws.
  static Future<void> syncAll(Iterable<ExpiryItemTableData> items) async {
    try {
      await cancelAll();
      for (final item in items) {
        if (shouldSchedule(item)) await _schedule(item);
      }
    } catch (e) {
      AppLogger.warning('ExpiryReminder', 'syncAll failed: $e');
    }
  }

  /// Drops the scheduled notification for [itemId] (payload-scoped). Never
  /// throws.
  static Future<void> cancelFor(String itemId) async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final p in pending) {
        if (p.payload == '$_payloadPrefix$itemId') {
          await _plugin.cancel(id: p.id);
        }
      }
    } catch (e) {
      AppLogger.warning('ExpiryReminder', 'cancel $itemId failed: $e');
    }
  }

  /// Drops every pending expiry notification. Never throws.
  static Future<void> cancelAll() async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final p in pending) {
        if (p.payload != null && p.payload!.startsWith(_payloadPrefix)) {
          await _plugin.cancel(id: p.id);
        }
      }
    } catch (e) {
      AppLogger.warning('ExpiryReminder', 'cancelAll failed: $e');
    }
  }

  static Future<void> _schedule(ExpiryItemTableData item) async {
    final due = _parseDate(item.dueDate);
    if (due == null) {
      // Malformed date used to fail silently (the user believed the reminder
      // was saved). Log it so diagnostics can surface the cause.
      AppLogger.warning('ExpiryReminder',
          'item ${item.id} has malformed dueDate "${item.dueDate}" — not scheduled');
      return;
    }

    final now = tz.TZDateTime.now(tz.local);
    // `remindDaysBefore` is the user-facing lead time; 0 means "on the day".
    final when = tz.TZDateTime(
      tz.local,
      due.year,
      due.month,
      due.day - item.remindDaysBefore,
      _hour,
    );
    // A reminder whose moment already passed (or sits at the very start of
    // today) has nothing left to announce.
    if (!when.isAfter(now)) return;

    // The channel is created here (idempotent) so this scheduler never depends
    // on another file's channel manifest; without it Android 8+ silently falls
    // back to default importance.
    await _ensureChannel();
    // Honor the exact-alarm grant like the other schedulers do: exact when
    // granted, idle-safe inexact otherwise (never throws).
    await NotificationService().refreshScheduleMode();

    final title = _itemTitle(item);
    final lead = item.remindDaysBefore == 0
        ? 'امروز سررسید «$title» است.'
        : '${item.remindDaysBefore} روز تا سررسید «$title» باقی مانده است.';
    await NotificationService().scheduleExactReminder(
      id: await _allocId(item.id),
      title: 'یادآوری: $title',
      body: lead,
      scheduledTime: when,
      details: const AndroidNotificationDetails(
        _channelId,
        'یادآوری سررسید اطلاعات من',
        channelDescription: 'یادآوری سررسید اقساط، گواهی‌نامه‌ها و اسناد',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@drawable/ic_notification',
        color: Color(0xFF00897B),
        visibility: NotificationVisibility.public,
      ),
      payload: '$_payloadPrefix${item.id}',
    );
  }

  /// Item title, trimmed so a very long entry cannot blow up the notification
  /// body; falls back to a generic label when blank.
  static String _itemTitle(ExpiryItemTableData item) {
    final t = item.title.trim();
    if (t.isEmpty) return 'مورد بدون عنوان';
    return t.length <= 60 ? t : '${t.substring(0, 60)}…';
  }

  /// Creates the expiry channel on Android (no-op when it already exists, and
  /// a no-op on other platforms). Never throws.
  static Future<void> _ensureChannel() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        _channelId,
        'یادآوری سررسید اطلاعات من',
        description: 'یادآوری سررسید اقساط، گواهی‌نامه‌ها و اسناد',
        importance: Importance.high,
      ));
    } catch (e) {
      AppLogger.warning('ExpiryReminder', 'create channel failed: $e');
    }
  }

  /// Allocates a collision-free id in [_idBase, _idBase + _idSpace): starts from
  /// the item's stable hash slot and bumps past ids already pending. Cancel
  /// stays payload-scoped, so the bump only affects scheduling — two items can
  /// never silently overwrite each other's notification.
  static Future<int> _allocId(String itemId) async {
    var id = _idFor(itemId);
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

  /// Parses the stored ISO date, or null when malformed.
  static DateTime? _parseDate(String value) {
    final parsed = DateTime.tryParse(value.trim());
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  /// Stable (cross-isolate) 32-bit FNV-1a hash of the item id → id space.
  static int _idFor(String itemId) {
    var hash = 0x811c9dc5;
    for (final unit in itemId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return _idBase + (hash % _idSpace);
  }
}

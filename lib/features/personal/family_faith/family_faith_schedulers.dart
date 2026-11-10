/// Reminder schedulers for the stage-3 tools.
///
/// All three go through the app's ONE [NotificationService] and own disjoint id
/// ranges, documented in `notification_ids.dart`:
///
///  * 17400–17799 صله رحم — `17400 + day-of-year`, payload `family_relative_*`
///  * 17900–17999 قلک — `17900 + stableSlot(goalId, 99)`, payload `family_saving_*`
///
/// These three started at 15000/16000/16500 and collided with the teacher
/// ledger (15000+), the shop (16000+) and, for the savings slot, the shop again
/// — the same ids, so one tool overwrote another's notification and the
/// vanished one never came back. They now sit above every other tool block.
///
/// The interfaces exist so widget tests can override the provider with a no-op
/// and never touch the plugin.
library;

import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'package:tawheeed/features/personal/family_faith/data/family_faith_repository.dart';
import 'package:tawheeed/features/personal/family_faith/family_faith_settings.dart';
import 'package:tawheeed/features/worship/silat_al_rahim/domain/silat_al_rahim_planner.dart';
import 'package:tawheeed/features/personal/family_faith/savings/savings_models.dart';
import 'package:tawheeed/shared/services/notification_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

const String _channelId = 'family_reminders_v1';
const String _channelName = 'یادآوری صلهٔ رحم و قلک';
const String _channelDescription =
    'یادآوری تماس با اقوام و اقساط قلک';

Future<void> _ensureChannel() async {
  try {
    final android = NotificationService()
        .plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.defaultImportance,
    ));
  } catch (e) {
    AppLogger.warning('FamilyReminder', 'channel creation failed: $e');
  }
}

Future<void> _cancelPayloadPrefix(String prefix) async {
  try {
    final pending = await NotificationService().plugin.pendingNotificationRequests();
    for (final request in pending) {
      final payload = request.payload;
      if (payload != null && payload.startsWith(prefix)) {
        await NotificationService().plugin.cancel(id: request.id);
      }
    }
  } catch (e) {
    AppLogger.warning('FamilyReminder', 'cancel failed: $e');
  }
}

int _dayOfYear(DateTime date) =>
    date.difference(DateTime(date.year)).inDays + 1;

// ── صله رحم ────────────────────────────────────────────────────────────────

abstract class FamilyReminders {
  Future<void> sync(RelativesSnapshot snapshot, {FamilyReminderSettings? settings});
}

class FamilyReminderScheduler implements FamilyReminders {
  const FamilyReminderScheduler();

  static const int idBase = 17400;

  @override
  Future<void> sync(
    RelativesSnapshot snapshot, {
    FamilyReminderSettings? settings,
  }) async {
    try {
      final resolved = settings ?? await FamilySettingsStore.load();
      await _ensureChannel();
      await _cancelPayloadPrefix('family_relative_');
      if (!resolved.enabled) return;

      final events = const RelativeReminderPlanner()
          .plan(relatives: snapshot.relatives, settings: resolved, now: DateTime.now());
      if (events.isEmpty) return;

      await NotificationService().refreshScheduleMode();
      for (final event in events) {
        await NotificationService().scheduleExactReminder(
          id: idBase + _dayOfYear(event.at),
          title: event.title,
          body: event.body,
          scheduledTime: event.at,
          details: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            icon: '@drawable/ic_notification',
            color: const Color(0xFFC0507A),
            visibility: NotificationVisibility.public,
            styleInformation: event.isGroup
                ? BigTextStyleInformation(event.body, contentTitle: event.title)
                : null,
          ),
          payload: event.payload,
        );
      }
      AppLogger.info('FamilyReminder',
          'scheduled ${events.length} relative reminders');
    } catch (e) {
      // A reminder is a convenience; saving a contact must never fail because
      // the OS refused a notification.
      AppLogger.warning('FamilyReminder', 'sync failed: $e');
    }
  }
}

// ── قلک ────────────────────────────────────────────────────────────────────

abstract class SavingsReminders {
  Future<void> sync(SavingsSnapshot snapshot);
}

class SavingsReminderScheduler implements SavingsReminders {
  const SavingsReminderScheduler();

  static const int idBase = 17900;
  static const int slotSpace = 99;

  @override
  Future<void> sync(SavingsSnapshot snapshot) async {
    try {
      final settings = await SavingsReminderStore.load();
      await _ensureChannel();
      await _cancelPayloadPrefix('family_saving_');
      if (!settings.enabled) return;

      final now = DateTime.now();
      final goals = [
        for (final goal in snapshot.goals)
          if (goal.isActive && goal.remindWeekly) goal,
      ];
      if (goals.isEmpty) return;

      await NotificationService().refreshScheduleMode();
      for (final goal in goals) {
        final weeklyAt = _nextWeeklySlot(now, settings.hour);
        final progress = savingsProgress(
          goal: goal,
          deposits: snapshot.depositsFor(goal.id),
          now: now,
        );
        await NotificationService().scheduleExactReminder(
          id: idBase + NotificationIds.stableSlot(goal.id, slotSpace),
          title: 'یک قدم به «${goal.title}» نزدیک‌تر شوید',
          body: progress.remaining <= 0
              ? 'هدف تکمیل شده است؛ اگر بخواهید می‌توانید هدف تازه‌ای بسازید.'
              : 'هر مبلغی که امروز کنار بگذارید، به هدف نزدیک‌ترتان می‌کند.',
          scheduledTime: weeklyAt,
          details: const AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            icon: '@drawable/ic_notification',
            color: Color(0xFF2E8B3D),
            visibility: NotificationVisibility.public,
          ),
          payload: 'family_saving_${goal.id}',
        );

        if (settings.remindMonthly) {
          final monthlyAt = _nextMonthlySlot(now, settings.hour);
          if (monthlyAt.isAfter(now)) {
            await NotificationService().scheduleExactReminder(
              id: idBase + NotificationIds.stableSlot(goal.id, slotSpace) + 1,
              title: 'یادآوری ماهانهٔ «${goal.title}»',
              body: progress.remaining <= 0
                  ? 'هدف تکمیل شد؛ هدف تازه‌ای بسازید.'
                  : 'این ماه چقدر برای «${goal.title}» کنار گذاشتید؟',
              scheduledTime: monthlyAt,
              details: const AndroidNotificationDetails(
                _channelId,
                _channelName,
                channelDescription: _channelDescription,
                importance: Importance.defaultImportance,
                priority: Priority.defaultPriority,
                icon: '@drawable/ic_notification',
                color: Color(0xFF2E8B3D),
                visibility: NotificationVisibility.public,
              ),
              payload: 'family_saving_${goal.id}',
            );
          }
        }
      }
    } catch (e) {
      AppLogger.warning('SavingsReminder', 'sync failed: $e');
    }
  }

  /// Next Saturday at [hour] — the start of the Persian week, so the nudge
  /// lands before the week's spending rather than in the middle of it.
  static DateTime _nextWeeklySlot(DateTime now, int hour) {
    var at = DateTime(now.year, now.month, now.day, hour);
    while (at.weekday != DateTime.saturday || !at.isAfter(now)) {
      at = at.add(const Duration(days: 1));
    }
    return at;
  }

  /// First day of the next Persian month at [hour].
  static DateTime _nextMonthlySlot(DateTime now, int hour) {
    final jNow = Jalali.fromDateTime(now);
    final next = jNow.month == 12
        ? Jalali(jNow.year + 1, 1, 1)
        : Jalali(jNow.year, jNow.month + 1, 1);
    final g = next.toDateTime();
    return DateTime(g.year, g.month, g.day, hour);
  }
}


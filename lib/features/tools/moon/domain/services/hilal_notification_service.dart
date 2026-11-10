import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:tawheeed/features/tools/moon/domain/services/astronomy/hilal_visibility.dart';
import 'package:tawheeed/features/tools/moon/domain/services/astronomy/rise_set.dart';
import 'package:tawheeed/features/tools/moon/domain/services/lunar_calculator.dart';
import 'package:tawheeed/shared/services/notification_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/date_range.dart';

/// یادآوری روزانهٔ رویت هلال — اگر هلالِ فردا با چشم قابل رویت باشد، اعلان
/// می‌فرستد. بدون ویجت، فقط اعلان.
///
/// The reminder is *scheduled* as a one-shot OS alarm rather than being decided
/// only when the Moon screen happens to be opened: a user who enables the alert
/// and never visits the tab again still receives it.
class HilalNotificationService {
  HilalNotificationService._();
  static final instance = HilalNotificationService._();

  static const _enabledKey = 'hilal_notification_enabled';
  static const _latKey = 'hilal_lat';
  static const _lngKey = 'hilal_lng';

  static const int _notifId = 9001;
  static const String _channelId = 'hilal_channel';

  /// یادآوری نزدیک غروب واقعیِ همان شب انجام میشود — لحظهای که کاربر میتواند
  /// عملاً به رصد برود. ۱۸:۰۰ فقط fallback مناطق قطبی/بدون غروب است.
  static const int _fallbackReminderHour = 18;
  static const int _minutesBeforeSunset = 10;

  /// The shared, app-wide plugin instance. A private
  /// [FlutterLocalNotificationsPlugin] is NOT created: the plugin is a
  /// process-wide singleton, so calling initialize() here would replace the
  /// global `onDidReceiveNotificationResponse` and silently break tap routing
  /// for prayer times, azkar and khatm reminders.
  ///
  /// Public rather than `@visibleForTesting`: a domain-layer file may not
  /// import `package:flutter`, and the tests assert this is the shared
  /// instance.
  FlutterLocalNotificationsPlugin get plugin => NotificationService().plugin;
  FlutterLocalNotificationsPlugin get _plugin => plugin;

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<void> setEnabled(bool v, {double? lat, double? lng}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, v);
    if (lat != null && lng != null) {
      await prefs.setDouble(_latKey, lat);
      await prefs.setDouble(_lngKey, lng);
    }
    if (!v) {
      // The flag is already persisted, so a platform hiccup while cancelling
      // must not turn "disable" into a thrown error for the toggle.
      try {
        await NotificationService().cancel(_notifId);
      } catch (e) {
        AppLogger.warning(
            'HilalNotificationService', 'cancel during disable failed: $e');
      }
      return;
    }
    // Book it right away: the user must not have to open the Moon screen again
    // for the alert they just enabled to ever fire.
    final savedLat = lat ?? prefs.getDouble(_latKey);
    final savedLng = lng ?? prefs.getDouble(_lngKey);
    if (savedLat != null && savedLng != null) {
      await reschedule(savedLat, savedLng);
    }
  }

  /// Ensures the Hilal channel exists. Deliberately does **not** re-initialize
  /// the plugin: [NotificationService.init] already owns that, and the Moon
  /// screen may be opened long after startup. The channel is created lazily
  /// here, so enabling the alert needs no extra initialization step.
  Future<void> init() async {
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            'hilal_channel',
            'هلال ماه',
            description: 'یادآوری رویت هلال',
            importance: Importance.high,
          ));
    } catch (e) {
      // A missing channel only costs the notification, never a crash.
      AppLogger.debug('HilalNotificationService', 'channel create failed: $e');
    }
  }

  /// Pure "which evening, if any" decision, extracted from [reschedule] so the
  /// rule is testable without the platform plugin.
  ///
  /// Returns `null` when the target evening needs no alert — no astronomy data
  /// for that date, or the hilal is not visible to the naked eye.
  ///
  /// [dayOffset] counts evenings ahead of [reference] (1 = tomorrow). The
  /// scheduler scans forward so enabling the alert after an evening's window
  /// has passed still books the next visible one instead of nothing.
  ///
  /// Public rather than `@visibleForTesting`: a domain-layer file may not
  /// import `package:flutter`, and the tests drive this decision directly.
  static HilalReminderPlan? planReminder({
    required DateTime reference,
    required double lat,
    required double lng,
    int dayOffset = 1,
  }) {
    final target = reference.addCalendarDaysFromMidnight(dayOffset);
    final data = LunarCalculator.sunsetHilal(target, lat, lng);
    if (data == null) return null;
    final v = data.verdict;
    final nakedEye = v == HilalSightingVerdict.nakedEyePossible ||
        v == HilalSightingVerdict.easilyVisible;
    if (!nakedEye) return null;
    return HilalReminderPlan(day: target, verdict: v);
  }

  /// Books (or drops) the reminder for the next evening, using the given
  /// coordinates.
  ///
  /// Cancels whatever was pending first, so repeated calls — from the Moon
  /// screen, from boot, from resume — can never stack duplicates. A missed
  /// schedule (reboot, cleared alarm queue, app never opened) is repaired the
  /// next time this runs. Never throws.
  Future<void> reschedule(double lat, double lng, {DateTime? now}) async {
    if (!await isEnabled()) return;
    final reference = now ?? DateTime.now();
    try {
      // Whatever the previous day booked is stale now.
      await NotificationService().cancel(_notifId);

      // Scan the next three evenings for the first naked-eye hilal whose
      // window is still ahead: enabling the alert in the evening (or on a
      // night with no visible hilal tomorrow) must book the upcoming one,
      // not silently schedule nothing. Re-runs (boot, resume, screen open)
      // keep re-booking, so a nearer evening always replaces a farther one.
      HilalReminderPlan? plan;
      tz.TZDateTime? when;
      final nowTz = tz.TZDateTime.from(reference, tz.local);
      for (var offset = 1; offset <= 3 && when == null; offset++) {
        final candidate = planReminder(
            reference: reference, lat: lat, lng: lng, dayOffset: offset);
        if (candidate == null) continue;
        final day = candidate.day;
        // زمان اعلان = غروب واقعیِ همان شب منهای چند دقیقه (آماده‌سازی برای
        // رصد)؛ در نقاطی که غروب محاسبه نمیشود ساعت ثابت fallback.
        final sunset = RiseSet.sunset(day, lat, lng);
        final candidateWhen = sunset == null
            ? tz.TZDateTime(tz.local, day.year, day.month, day.day,
                _fallbackReminderHour)
            : tz.TZDateTime.from(
                sunset.subtract(const Duration(minutes: _minutesBeforeSunset)),
                tz.local);
        if (candidateWhen.isAfter(nowTz)) {
          plan = candidate;
          when = candidateWhen;
        }
      }
      if (plan == null || when == null) return;
      final tomorrow = plan.day;

      await init();
      // Honor the exact-alarm grant like every other scheduler (never throws).
      await NotificationService().refreshScheduleMode();
      // The alarm fires on the evening of the target day, so the wording is
      // about *that* evening — announcing "tomorrow" on tomorrow evening would
      // be off by a day.
      await NotificationService().scheduleExactReminder(
        id: _notifId,
        title: 'امشب هلال قابل رویت است',
        body:
            '${tomorrow.month}/${tomorrow.day} — هلال ${plan.verdict.persian} — آماده رویت باشید',
        scheduledTime: when,
        details: const AndroidNotificationDetails(
          _channelId,
          'هلال ماه',
          channelDescription: 'یادآوری رویت هلال',
          importance: Importance.high,
          priority: Priority.high,
        ),
      );
    } catch (e) {
      // Astronomy/scheduling failure must never surface as an error dialog —
      // but it must leave a trace for debugging.
      AppLogger.warning('HilalNotificationService', 'reschedule failed: $e');
    }
  }

  /// Re-books from the persisted coordinates — called on app boot so a reboot
  /// or a cleared alarm queue never silences the alert permanently.
  Future<void> rescheduleFromPrefs() async {
    if (!await isEnabled()) return;
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_latKey);
    final lng = prefs.getDouble(_lngKey);
    if (lat == null || lng == null) return;
    await reschedule(lat, lng);
  }

  /// Called on app open (boot coordinator / Moon screen) to keep the booking
  /// current with the user's real coordinates.
  Future<void> checkAndNotify(DateTime now, double lat, double lng) async {
    if (!await isEnabled()) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_latKey, lat);
    await prefs.setDouble(_lngKey, lng);
    await reschedule(lat, lng, now: now);
  }
}

/// What [HilalNotificationService.planReminder] decided: the evening the alert
/// belongs to, and the visibility verdict that justified it.
class HilalReminderPlan {
  final DateTime day;
  final HilalSightingVerdict verdict;

  const HilalReminderPlan({required this.day, required this.verdict});
}

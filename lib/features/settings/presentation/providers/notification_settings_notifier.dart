import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tawheeed/shared/models/day_time.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_time_provider.dart';
import 'package:tawheeed/features/prayer/services/islamic_events_service.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/domain/repositories/settings_writer.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_infra_providers.dart';
import 'package:tawheeed/shared/providers/shared_prefs_provider.dart';
import 'package:tawheeed/shared/services/daily_notification_scheduler.dart';
import 'package:tawheeed/shared/services/native_prayer_alarm_service.dart';
import 'package:tawheeed/shared/services/notification_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

// The infrastructure providers live in their own library so the canonical
// [Settings] notifier can reach the scheduler too; re-exported here so existing
// imports of this file keep seeing them.
export 'package:tawheeed/features/settings/presentation/providers/settings_infra_providers.dart';

part 'notification_settings_notifier.g.dart';

// `islamicEventsEnabledKey` lives in [settings_infra_providers] (re-exported
// above) so the canonical [Settings] notifier can clear it on reset without a
// notifier-to-notifier import.

/// Whether Islamic-occasion reminders are enabled (defaults to true).
@Riverpod(keepAlive: true)
Future<bool> islamicEventsEnabled(Ref ref) async {
  final prefs = await ref.watch(sharedPrefsProvider.future);
  return prefs.getBool(islamicEventsEnabledKey) ?? true;
}

/// Bumped after «لغو همه» so cards that keep a local copy of pref-backed
/// toggles (Friday reminder, post-prayer adhkar) reload them — their
/// `initState` read would otherwise stay stale for the rest of the session.
class _CancelAllTick extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final cancelAllTickProvider =
    NotifierProvider<_CancelAllTick, int>(_CancelAllTick.new);

/// Coordinator [AsyncNotifier] that bridges [AppSettings] and the notification
/// scheduling infrastructure.
///
/// It keeps [NotificationService] (a low-level singleton wrapping
/// `flutter_local_notifications`) and [DailyNotificationScheduler] in sync with
/// the user's settings. Persistence still flows through the canonical
/// [Settings] notifier so there is a single source of truth for [AppSettings].
@Riverpod(keepAlive: true)
class NotificationSettings extends _$NotificationSettings
    implements SettingsWriter {
  @override
  Future<AppSettings> build() async {
    // Mirror the canonical settings so the UI can consume a single value.
    return ref.watch(settingsProvider.future);
  }

  Settings get _settings => ref.read(settingsProvider.notifier);
  NotificationService get _notifications =>
      ref.read(notificationServiceProvider);
  DailyNotificationScheduler get _scheduler =>
      ref.read(dailyNotificationSchedulerProvider);

  /// Key holding the per-window adhkar choice (morning,evening) captured when
  /// the master switch is turned off, so turning it back on restores the
  /// user's previous selection instead of force-enabling both.
  static const String adhkarRecallKey = 'notif_azkar_master_recall';

  /// Toggle both morning and evening adhkar reminders.
  ///
  /// Off: the individual choices are remembered first. On: they are restored,
  /// falling back to both-enabled when there is no remembered choice (or when
  /// both were off, which would otherwise make this switch a no-op).
  Future<void> toggleAdhkarNotifications(bool enabled) async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    if (enabled) {
      final recall = prefs.getString(adhkarRecallKey);
      await prefs.remove(adhkarRecallKey);
      final parts = recall?.split(',');
      var morning = true, evening = true;
      if (parts != null && parts.length == 2) {
        morning = parts[0] == 'true';
        evening = parts[1] == 'true';
        if (!morning && !evening) morning = evening = true;
      }
      await _settings.setMorningAzkarNotification(morning);
      await _settings.setEveningAzkarNotification(evening);
    } else {
      final current = await ref.read(settingsProvider.future);
      await prefs.setString(
          adhkarRecallKey,
          '${current.morningAzkarNotification},'
          '${current.eveningAzkarNotification}');
      await _settings.setMorningAzkarNotification(false);
      await _settings.setEveningAzkarNotification(false);
    }
    await rescheduleAll();
  }

  /// Toggle reminders for upcoming Islamic occasions.
  Future<void> toggleIslamicEventNotifications(bool enabled) async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    await prefs.setBool(islamicEventsEnabledKey, enabled);
    ref.invalidate(islamicEventsEnabledProvider);
    if (enabled) {
      final settings = await ref.read(settingsProvider.future);
      await _notifications.scheduleMonthlyIslamicEvents(
        IslamicEventsService.upcomingWithDates(offset: settings.hijriOffset),
      );
    } else {
      await _notifications.cancelIslamicEventNotifications();
    }
  }

  /// Configure the snooze duration used by notification action buttons and
  /// persist it so it survives app restarts.
  Future<void> setSnooze(Duration duration) async {
    await _notifications.persistSnoozeMinutes(duration.inMinutes);
  }

  /// Set how many minutes after each prayer's iqamah the «اذکار بعد از نماز»
  /// reminder fires, then re-schedule the whole notification set.
  Future<void> setPostPrayerDelay(int minutes) async {
    await _notifications.persistPostPrayerDelay(minutes);
    await rescheduleAll();
  }

  /// Master toggle for the «اذکار بعد از نماز» reminders, independent of the
  /// prayer-reminder toggle. Turning it off cancels the post-prayer queue on
  /// every window; turning it on rebuilds it via [rescheduleAll].
  Future<void> setPostPrayerEnabled(bool enabled) async {
    final wasEnabled = await _notifications.postPrayerEnabled();
    await _notifications.setPostPrayerEnabled(enabled);
    if (enabled && !wasEnabled) {
      await rescheduleAll();
    } else if (!enabled && wasEnabled) {
      await _notifications.cancelPostPrayerNotifications();
    }
  }

  /// Toggle just the morning adhkar reminder and reschedule immediately.
  Future<void> setMorningAzkar(bool enabled) async {
    await _settings.setMorningAzkarNotification(enabled);
    await rescheduleAll();
  }

  /// Toggle just the evening adhkar reminder and reschedule immediately.
  Future<void> setEveningAzkar(bool enabled) async {
    await _settings.setEveningAzkarNotification(enabled);
    await rescheduleAll();
  }

  /// Set the fixed wall-clock time for the morning/evening adhkar reminder.
  /// Records that the time is now manual (overriding the prayer-anchored
  /// default of Fajr + 45 / Asr + 60) and reschedules immediately. The manual
  /// flag is written straight to prefs (not via [NotificationService]) so the
  /// generated test mocks don't need regeneration.
  Future<void> setAzkarTime(DayTime time, {required bool morning}) async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    await prefs.setBool(
        morning
            ? NotificationService.azkarMorningManualKey
            : NotificationService.azkarEveningManualKey,
        true);
    if (morning) {
      await _settings.setMorningAzkarTime(time);
    } else {
      await _settings.setEveningAzkarTime(time);
    }
    await rescheduleAll();
  }

  /// Clear the fixed wall-clock time for the morning/evening adhkar reminder
  /// so it goes back to being anchored to the prayer schedule. Without this
  /// the manual flag could only ever be turned on — a one-way switch.
  Future<void> setAzkarPrayerAnchored({required bool morning}) async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    await prefs.setBool(
        morning
            ? NotificationService.azkarMorningManualKey
            : NotificationService.azkarEveningManualKey,
        false);
    await rescheduleAll();
  }

  // --- Weekly Friday reminders: prefs-backed, re-armed through the service ---

  /// Save the Friday reminder toggle + time and re-arm (or cancel) the weekly
  /// alarm immediately.
  Future<void> setFridayReminder(
      {required bool enabled, required int hour, required int minute}) async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    await prefs.setBool(NotificationService.fridayEnabledKey, enabled);
    await prefs.setInt(NotificationService.fridayHourKey, hour);
    await prefs.setInt(NotificationService.fridayMinuteKey, minute);
    await _notifications.syncFridayReminder();
  }

  /// Save the Kahf-sura reminder toggle + time and re-arm (or cancel) it.
  Future<void> setFridayKahfReminder(
      {required bool enabled, required int hour, required int minute}) async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    await prefs.setBool(NotificationService.fridayKahfEnabledKey, enabled);
    await prefs.setInt(NotificationService.fridayKahfHourKey, hour);
    await prefs.setInt(NotificationService.fridayKahfMinuteKey, minute);
    await _notifications.syncFridayKahfReminder();
  }

  // --- Voluntary-fasting reminders: prefs-backed like the Friday pair. ---

  /// Save the Monday/Thursday fasting toggle + time and re-arm (or cancel) it.
  Future<void> setFastingMonThu(
      {required bool enabled, required int hour, required int minute}) async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    await prefs.setBool(NotificationService.fastingMonThuEnabledKey, enabled);
    await prefs.setInt(NotificationService.fastingMonThuHourKey, hour);
    await prefs.setInt(NotificationService.fastingMonThuMinuteKey, minute);
    await _syncFasting();
  }

  /// Save the ایام بیض (Hijri 13-15) fasting toggle + time and re-arm it.
  Future<void> setFastingBidh(
      {required bool enabled, required int hour, required int minute}) async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    await prefs.setBool(NotificationService.fastingBidhEnabledKey, enabled);
    await prefs.setInt(NotificationService.fastingBidhHourKey, hour);
    await prefs.setInt(NotificationService.fastingBidhMinuteKey, minute);
    await _syncFasting();
  }

  /// The ایام بیض window is computed against the user's Hijri sighting offset,
  /// which only [AppSettings] carries — so both fasting setters go through it.
  Future<void> _syncFasting() async {
    final settings = await ref.read(settingsProvider.future);
    await _notifications
        .syncFastingReminders(hijriOffset: settings.hijriOffset);
  }

  // --- Daily reminder setters: delegate persistence to the canonical Settings
  // notifier (single source of truth), the caller reschedules explicitly. ---

  Future<void> setDailyVerse(bool v) => _settings.setDailyVerse(v);

  Future<void> setDailyVerseTime(DayTime v) => _settings.setDailyVerseTime(v);

  Future<void> setDailyHadith(bool v) => _settings.setDailyHadith(v);

  Future<void> setDailyHadithTime(DayTime v) => _settings.setDailyHadithTime(v);

  Future<void> setDailyDua(bool v) => _settings.setDailyDua(v);

  Future<void> setDailyDuaTime(DayTime v) => _settings.setDailyDuaTime(v);

  Future<void> setQuranReminder(bool v) => _settings.setQuranReminder(v);

  Future<void> setQuranReminderTime(DayTime v) =>
      _settings.setQuranReminderTime(v);

  /// Turn off every reminder category and cancel everything that is scheduled
  /// (Flutter notifications, native setAlarmClock alarms, Islamic events).
  Future<void> disableAllReminders() async {
    await _settings.setMorningAzkarNotification(false);
    await _settings.setEveningAzkarNotification(false);
    await _settings.setDailyVerse(false);
    await _settings.setDailyHadith(false);
    await _settings.setDailyDua(false);
    await _settings.setQuranReminder(false);
    await _settings.setPrayerNotifications(false);
    // The five per-prayer adhan switches are independent of the master flag;
    // leaving them on let the next reschedule re-arm what «لغو همه» cancelled.
    await _settings.disableAllAzan();
    final prefs = await ref.read(sharedPrefsProvider.future);
    await prefs.setBool(islamicEventsEnabledKey, false);
    // Pref-backed toggles outside [AppSettings] — without these the next
    // forceReschedule (fingerprint, boot, …) silently re-enables them.
    // Written straight to prefs (not via NotificationService) so the keys
    // flip even when the service is mocked in tests — same pattern as the
    // Friday reminder card.
    await prefs.setBool(NotificationService.fridayEnabledKey, false);
    await prefs.setBool(NotificationService.fridayKahfEnabledKey, false);
    await prefs.setBool(NotificationService.fastingMonThuEnabledKey, false);
    await prefs.setBool(NotificationService.fastingBidhEnabledKey, false);
    await prefs.setBool(NotificationService.postPrayerEnabledKey, false);
    // The daily-khatm reminder lives on the same prefs-backed pattern; missing
    // it here let the next forceReschedule re-arm it right after "cancel all".
    await prefs.setBool(NotificationService.khatmEnabledKey, false);
    ref.invalidate(islamicEventsEnabledProvider);
    await _notifications.cancelAll();
    try {
      await NativePrayerAlarmService().cancelAll();
    } catch (e) {
      // Channel missing in tests / host — prefs are already flipped, so the
      // alarms re-arm only until the next reschedule. Logged rather than
      // dropped: a real platform failure here leaves OS alarms alive silently.
      AppLogger.warning('NotificationSettingsNotifier',
          'native prayer alarms not cancelled by cancelAll: $e');
    }
  }

  /// Re-schedule every notification category from the current settings. Safe to
  /// call from native Android background work as well as the settings UI.
  ///
  /// [forceReschedule] already rebuilds the daily verse/hadith/dua/Quran
  /// window, so they are not scheduled twice here.
  Future<void> rescheduleAll() async {
    final settings = await ref.read(settingsProvider.future);
    final prayerService = ref.read(prayerTimeServiceProvider);

    await _scheduler.forceReschedule(
      prayerService: prayerService,
      settings: settings,
      writer: this,
    );

    // Schedule monthly Islamic events — only when the events toggle is on;
    // otherwise any unrelated reschedule would silently re-enable them.
    if (ref.read(islamicEventsEnabledProvider).value ?? true) {
      await _notifications.scheduleMonthlyIslamicEvents(
        IslamicEventsService.upcomingWithDates(offset: settings.hijriOffset),
      );
    } else {
      await _notifications.cancelIslamicEventNotifications();
    }
  }

  // --- SettingsWriter: delegate persistence to the canonical Settings notifier
  // so prayer-time recalculation can update the stored city/coordinates. ---

  @override
  Future<void> setCity(String city) => _settings.setCity(city);

  @override
  Future<void> setManualCoords(double lat, double lng) =>
      _settings.setManualCoords(lat, lng);

  @override
  Future<void> setHasLocation(bool value) => _settings.setHasLocation(value);
}

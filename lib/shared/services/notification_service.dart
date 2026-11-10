import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_time_helpers.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/features/prayer/services/islamic_events_service.dart';
import 'package:tawheeed/shared/services/friday_content.dart';
import 'package:tawheeed/core/services/permission_service.dart';
import 'package:tawheeed/shared/services/daily_content_format.dart';
import 'package:tawheeed/shared/services/daily_hadith_source.dart';
import 'package:tawheeed/shared/services/daily_verse_source.dart';
import 'package:tawheeed/shared/services/native_prayer_alarm_service.dart';
import 'package:tawheeed/shared/services/notification_ids.dart';
import 'package:tawheeed/shared/services/sound_choice.dart';
import 'package:tawheeed/shared/utils/hijri_utils.dart';
import 'package:tawheeed/core/constants/date_constants.dart';
export 'package:tawheeed/shared/services/notification_ids.dart';
part 'notification_daily_reminders.dart';
part 'notification_period_reminders.dart';
part 'notification_day_scheduling.dart';
part 'notification_models.dart';

class NotificationService
    with _NotificationDailyReminders, _NotificationPeriodReminders {
  @override
  NotificationService get service => this;
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static Function(String prayerName)? onPrayerTapped;

  /// Called when a post-prayer azkar notification is tapped.
  static Function()? onPostPrayerAzkarTapped;

  /// Called when the khatm (ختم قرآن) reminder notification is tapped.
  ///
  /// Kept as a getter/setter pair so a tap that cold-starts the app (arriving
  /// before the shell registers the handler) is buffered and dispatched as
  /// soon as the handler is wired up, after the first frame.
  static Function()? _onKhatmTapped;
  static bool _pendingKhatmTap = false;

  static Function()? get onKhatmTapped => _onKhatmTapped;
  static set onKhatmTapped(Function()? callback) {
    _onKhatmTapped = callback;
    if (callback == null) {
      _pendingKhatmTap = false;
      return;
    }
    if (_pendingKhatmTap) {
      _pendingKhatmTap = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => callback());
    }
  }

  /// Tap on the weekly Surah-Kahf alert → open the Quran tab. A tap that
  /// arrives before the shell registers the handler (cold start) is buffered
  /// and dispatched as soon as the handler is wired up, after the first frame
  /// — same contract as [onKhatmTapped].
  static Function()? _onQuranTapped;
  static bool _pendingQuranTap = false;

  static Function()? get onQuranTapped => _onQuranTapped;
  static set onQuranTapped(Function()? callback) {
    _onQuranTapped = callback;
    if (callback == null) {
      _pendingQuranTap = false;
      return;
    }
    if (_pendingQuranTap) {
      _pendingQuranTap = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => callback());
    }
  }

  /// Called when a personal-tools («خودرو» / «خانه») reminder is tapped.
  /// The payload carries the tool and the exact row
  /// (`care_car_task_<id>`, `care_home_bill_<id>`, `care_day_<date>` for a
  /// grouped summary). A cold-start tap that arrives before the shell
  /// registers the handler is buffered, exactly like [onKhatmTapped].
  static Function(String payload)? _onCareTapped;
  static String? _pendingCarePayload;

  static Function(String payload)? get onCareTapped => _onCareTapped;
  static set onCareTapped(Function(String payload)? callback) {
    _onCareTapped = callback;
    if (callback == null) {
      _pendingCarePayload = null;
      return;
    }
    final pending = _pendingCarePayload;
    if (pending != null) {
      _pendingCarePayload = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => callback(pending));
    }
  }

  /// Called when a stage-3 personal-tools reminder is tapped.
  ///
  /// Payload shapes: `family_relative_<id>`, `family_relative_day_<date>`,
  /// `family_saving_<goalId>`. A cold-start tap is
  /// buffered exactly like [onCareTapped], so no tap is lost while the shell
  /// is still building.
  static Function(String payload)? _onFamilyTapped;
  static String? _pendingFamilyPayload;

  static Function(String payload)? get onFamilyTapped => _onFamilyTapped;
  static set onFamilyTapped(Function(String payload)? callback) {
    _onFamilyTapped = callback;
    if (callback == null) {
      _pendingFamilyPayload = null;
      return;
    }
    final pending = _pendingFamilyPayload;
    if (pending != null) {
      _pendingFamilyPayload = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => callback(pending));
    }
  }

  /// Test seam — routes a [NotificationResponse] through the same logic the
  /// plugin callback uses, so the tap handling can be unit tested.
  @visibleForTesting
  void handleNotificationTap(NotificationResponse response) {
    _onNotificationTap(response);
  }

  /// Called when a rich-notification action button is tapped.
  /// Receives the action id (e.g. [actionSnooze]) and the notification payload.
  static Function(String actionId, String? payload)? onNotificationAction;

  /// Action ids for rich (interactive) notifications.
  static const String actionConfirm = 'action_confirm';
  static const String actionSnooze = 'action_snooze';

  /// Minutes used when a notification is snoozed via its action button.
  static const String snoozeMinutesKey = 'notif_snooze_minutes';
  static const int defaultSnoozeMinutes = 10;
  int snoozeMinutes = defaultSnoozeMinutes;

  /// Loads the persisted snooze duration (called once during [init] so the
  /// value survives app restarts).
  Future<void> loadSnoozeMinutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      snoozeMinutes = prefs.getInt(snoozeMinutesKey) ?? defaultSnoozeMinutes;
    } catch (e) {
      // SharedPreferences unavailable — keep the default.
      AppLogger.warning('NotificationService', 'prefs init read failed: $e');
    }
  }

  /// Persists the snooze duration and applies it immediately.
  Future<void> persistSnoozeMinutes(int minutes) async {
    snoozeMinutes = minutes;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(snoozeMinutesKey, minutes);
    } catch (e) {
      // Best-effort persistence.
      AppLogger.warning('NotificationService', 'prefs write failed: $e');
    }
  }

  /// Minutes after each prayer's iqamah when the «اذکار بعد از نماز» reminder
  /// fires (auto-scheduled daily for all five prayers). Stored in
  /// SharedPreferences (not [AppSettings]) so no Drift schema migration is
  /// needed — same pattern as the snooze / Friday / khatm prefs.
  static const String postPrayerDelayKey = 'notif_post_prayer_delay_minutes';
  static const int defaultPostPrayerDelay = 10;

  /// Returns the configured post-prayer azkar delay (default 10 minutes).
  Future<int> postPrayerDelayMinutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getInt(postPrayerDelayKey) ?? defaultPostPrayerDelay)
          .clamp(0, 120);
    } catch (e) {
      AppLogger.warning('NotificationService',
          'post-prayer delay read failed, using default: $e');
      return defaultPostPrayerDelay;
    }
  }

  /// Whether the «اذکار بعد از نماز» reminders are enabled at all.
  /// Independent of the «یادآوری اوقات نماز» toggle: post-prayer adhkar used
  /// to die silently whenever prayer reminders were off. Stored in
  /// SharedPreferences (not [AppSettings]) so no Drift schema migration is
  /// needed — same pattern as the snooze / Friday / khatm prefs.
  static const String postPrayerEnabledKey = 'notif_post_prayer_enabled';

  /// Returns the post-prayer azkar master toggle (defaults to true so
  /// existing users keep today's behavior).
  Future<bool> postPrayerEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(postPrayerEnabledKey) ?? true;
    } catch (e) {
      AppLogger.warning('NotificationService', 'flag read failed: $e');
      return true;
    }
  }

  /// Persists the post-prayer azkar master toggle.
  Future<void> setPostPrayerEnabled(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(postPrayerEnabledKey, value);
    } catch (e) {
      // Best-effort persistence.
      AppLogger.warning('NotificationService', 'prefs write failed: $e');
    }
  }

  /// Persists the post-prayer azkar delay in minutes.
  Future<void> persistPostPrayerDelay(int minutes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(postPrayerDelayKey, minutes.clamp(0, 120));
    } catch (e) {
      // Best-effort persistence.
      AppLogger.warning('NotificationService', 'prefs write failed: $e');
    }
  }

  /// Epoch millis of the last missed-reminder catch-up pass.
  ///
  /// A fixed-time reminder is armed only by a run that happens inside the 24 h
  /// before its fire time — `_scheduleNotification` drops a past time, so no
  /// later run can arm it. Keeping the previous run's stamp is therefore the
  /// only way to tell "armed, nothing to report" from "the app never ran in
  /// that window". Stored in SharedPreferences so no Drift schema migration is
  /// needed — same pattern as the post-prayer delay / snooze / Friday prefs.
  static const String catchUpLastRunKey = 'notif_catchup_last_run';

  // ── Morning/evening azkar manual-time override ────────────────────────────
  //
  // By default the reminders are anchored to the prayer schedule (morning =
  // Fajr + 45 min, evening = Asr + 60 min). The user can pick a fixed
  // wall-clock time instead; these flags record that choice. Stored in
  // SharedPreferences so no Drift schema migration is needed — same pattern as
  // the post-prayer delay / snooze / Friday prefs.
  static const String azkarMorningManualKey = 'notif_azkar_morning_manual';
  static const String azkarEveningManualKey = 'notif_azkar_evening_manual';

  /// Whether the user set a fixed manual time for the morning/evening azkar
  /// reminder (vs. the prayer-anchored default).
  Future<bool> isAzkarManual({required bool morning}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(
              morning ? azkarMorningManualKey : azkarEveningManualKey) ??
          false;
    } catch (e) {
      AppLogger.warning('NotificationService', 'flag read failed: $e');
      return false;
    }
  }

  /// Records whether the morning/evening azkar uses a fixed manual time.
  Future<void> setAzkarManual(
      {required bool morning, required bool value}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
          morning ? azkarMorningManualKey : azkarEveningManualKey, value);
    } catch (e) {
      // Best-effort persistence.
      AppLogger.warning('NotificationService', 'prefs write failed: $e');
    }
  }

  bool _initialized = false;

  /// Memoized in-flight [init] run — see [init]. The singleton is per-isolate,
  /// so the memo never crosses the foreground/background boundary.
  Future<void>? _initFuture;
  AndroidScheduleMode _scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Native exact-reminder bridge (setExactAndAllowWhileIdle / setAlarmClock
  /// watchdog) — guaranteed on-time delivery when SCHEDULE_EXACT_ALARM is not
  /// granted.
  static const MethodChannel _exactReminders =
      MethodChannel('com.tawheeed/exact_reminders');

  /// Ops collected while a scheduling pass runs inside [batchNativeReminders],
  /// in the wire format Kotlin `ExactReminderScheduler.decodeOps` reads. A
  /// launch reschedule touches hundreds of ids; sending them one round trip at
  /// a time was the single biggest source of the post-launch UI stall.
  final List<Map<String, Object?>> _nativeOps = [];

  /// Open [batchNativeReminders] nesting. Only the outermost exit flushes.
  int _nativeOpBatchDepth = 0;

  /// True while a batch already paid for the exact-alarm grant query, so the
  /// remaining ids in the same pass skip it (it cannot change mid-pass).
  bool _modeQueriedInBatch = false;

  /// Delivers warm-start tap payloads from native-posted notifications (the
  /// Flutter plugin only reports responses for notifications it posted itself).
  static const MethodChannel _nativeTapChannel =
      MethodChannel('com.tawheeed/notification_tap');

  FlutterLocalNotificationsPlugin get plugin => _notifications;

  /// App brand color (gold) used to tint the notification icon.
  static const Color _brandColor = Color(0xFFC48A27);

  /// Notifications stay visible (with content) on the lock screen.
  static const NotificationVisibility _visible = NotificationVisibility.public;

  bool get isInitialized => _initialized;

  /// Uses exact alarms whenever Android grants the permission. When it is not
  /// granted, the plugin's inexact idle-safe mode is used instead of allowing
  /// the whole scheduling batch to fail with ExactAlarmPermissionException.
  ///
  /// The grant can change anytime in system settings, so every entry point
  /// re-queries it — but a batching pass queries it ONCE (the first id of the
  /// batch), because each query is another awaited platform-thread round trip
  /// and the answer cannot change while the pass runs.
  AndroidScheduleMode get scheduleMode => _scheduleMode;

  /// The mode last written to the on-device log, so a repeated refresh of the
  /// SAME mode does not append another line. Flipping a reminder used to write
  /// «Notification schedule mode: …» into `tawheed_log.txt` every single time —
  /// the one log line a user could see appear just by enabling an option —
  /// while the interesting event is the mode *changing*.
  static AndroidScheduleMode? _loggedScheduleMode;
  static bool _exactAlarmQueryWarned = false;

  /// @visibleForTesting: how many «schedule mode» lines reached the log, and how
  /// many failed-query warnings were emitted. Read by the guard test only.
  @visibleForTesting
  static int scheduleModeLogs = 0;

  @visibleForTesting
  static int exactAlarmQueryWarnings = 0;

  /// @visibleForTesting: forget the remembered mode and warning streak, so one
  /// test cannot inherit another's quiet state.
  @visibleForTesting
  static void resetScheduleModeLogging() {
    _loggedScheduleMode = null;
    _exactAlarmQueryWarned = false;
    scheduleModeLogs = 0;
    exactAlarmQueryWarnings = 0;
  }

  Future<void> refreshScheduleMode() async {
    final batching = _nativeOpBatchDepth > 0;
    if (batching && _modeQueriedInBatch) return;
    _modeQueriedInBatch = batching;
    try {
      final android = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final canSchedule = await android?.canScheduleExactNotifications();
      _scheduleMode = canSchedule == false
          ? AndroidScheduleMode.inexactAllowWhileIdle
          : AndroidScheduleMode.exactAllowWhileIdle;
      _exactAlarmQueryWarned = false;
      if (_loggedScheduleMode == _scheduleMode) {
        // Same answer as last time: console trace only, no disk write.
        AppLogger.debug('NotificationService',
            'Notification schedule mode: ${_scheduleMode.name}');
      } else {
        _loggedScheduleMode = _scheduleMode;
        scheduleModeLogs++;
        AppLogger.info('NotificationService',
            'Notification schedule mode: ${_scheduleMode.name}');
      }
    } catch (e) {
      // Keep exact mode as the optimistic default; the native plugin will
      // report a clear failure if the platform denies it. Warned once per
      // failure streak: a broken channel fails on every notification of every
      // reschedule, and that flood buried the rest of the log.
      if (!_exactAlarmQueryWarned) {
        _exactAlarmQueryWarned = true;
        exactAlarmQueryWarnings++;
        AppLogger.warning('NotificationService',
            'Could not query exact-alarm capability: $e');
      }
    }
  }

  /// تضمین اعلان دقیق برای اذکار — اگر مجوز اذان دقیق داده نشده، درخواست می‌کند
  /// تا اذکار مانند اذان سر وقت با setExactAndAllowWhileIdle بیاید نه با تأخیر Doze.
  Future<bool> _ensureExactForPostPrayer() async {
    // Non-interactive on purpose: this runs inside the scheduling path, which
    // also executes in the closed-app WorkManager isolate — where launching the
    // system "Alarms & reminders" screen is impossible and a thrown exception
    // would abort the whole scheduling batch. Permission *requests* belong to
    // the user-facing paths (onboarding, diagnostics, settings) and to
    // PermissionService.ensureExactAlarmPermission(), which enforces a 24h
    // cooldown; this helper used to bypass that cooldown and could open the
    // system settings screen at any moment (e.g. mid-reschedule while reading
    // the Quran). Delivery without the grant is now covered by the plugin
    // fallback in [_scheduleNotification].
    await refreshScheduleMode();
    return _scheduleMode == AndroidScheduleMode.exactAllowWhileIdle;
  }

  /// Idempotent (Audit): the foreground boot path (main →
  /// initNotificationsGuarded) and the background isolate's dispatch
  /// (BackgroundScheduler → NotificationService().init()) can both reach this;
  /// a second caller now awaits the same run instead of re-creating every
  /// notification channel and re-registering the native tap handler while the
  /// first run is still in flight. A failed run stays memoized — the caller
  /// side startup guard absorbs the error, and a fresh isolate / cold start
  /// gets a fresh service instance that retries.
  Future<void> init() => _initFuture ??= _initUnguarded();

  Future<void> _initUnguarded() async {
    tzdata.initializeTimeZones();
    // Align tz.local with the device's real system timezone (via the native
    // settings channel, Tehran fallback). tzdata initializes tz.local to UTC;
    // without setLocalLocation every wall-clock notification scheduled via
    // tz.TZDateTime(tz.local, ...) fires at UTC time instead of local time —
    // and with a hardcoded zone it fires at the wrong zone's wall clock.
    await _resolveLocalLocation();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // NOTE: the POST_NOTIFICATIONS prompt is deliberately NOT issued here.
    // init() runs from main() while the native launch screen is still visible,
    // so the system dialog used to appear before the user saw any rationale —
    // the onboarding notification step (and PermissionService) own the request
    // now, with an explanation in context.
    await _createNotificationChannels();
    await refreshScheduleMode();

    // Restore the persisted snooze duration (falls back to the default).
    await loadSnoozeMinutes();

    // Native-posted notifications (every reminder on Android) deliver their tap
    // payload through this channel — the plugin only reports responses for
    // notifications it posted itself.
    _nativeTapChannel.setMethodCallHandler((call) async {
      if (call.method == 'deliver') {
        final payload = call.arguments as String?;
        if (payload != null && payload.isNotEmpty) {
          handleNotificationTap(NotificationResponse(
            payload: payload,
            notificationResponseType:
                NotificationResponseType.selectedNotification,
          ));
        }
      }
    });

    _initialized = true;
  }

  /// True once [handleColdStartTap] consumed a non-empty native payload in
  /// this process. Used to skip the GPS prompt so it does not steal focus
  /// from a cold-start notification destination (P1-7 polish).
  static bool consumedColdStartTap = false;

  /// Handles a notification tap payload that arrived before the engine was
  /// ready (cold start from a native-posted notification). Called by the
  /// foreground boot path right after [init]; harmless when empty.
  Future<void> handleColdStartTap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = prefs.getString('notification_payload');
      if (payload == null || payload.isEmpty) return;
      await prefs.remove('notification_payload');
      consumedColdStartTap = true;
      handleNotificationTap(NotificationResponse(
        payload: payload,
        notificationResponseType: NotificationResponseType.selectedNotification,
      ));
    } catch (e) {
      // Best effort.
      AppLogger.warning('NotificationService', 'best-effort step failed: $e');
    }
  }

  /// Sets [tz.local] to a named timezone matching the device's current UTC
  /// offset so scheduled notifications fire at the correct local time.
  /// Result is cached; a re-scan only runs when the device timezone offset
  /// actually changes (avoids a heavy scan of the whole timezone database).
  static String? _cachedLocalTzName;

  /// Olson name of the zone [tz.local] currently points at ('' when unknown).
  /// Included in the daily schedule fingerprint so travel or a timezone change
  /// forces a full rebuild on the next launch instead of firing at the old
  /// zone's wall-clock hours.
  static String get localTzName => _cachedLocalTzName ?? '';

  /// Resolves the real device zone natively; Tehran when the channel is
  /// unavailable or the name is unknown; offset scan as a last resort.
  Future<void> _resolveLocalLocation() async {
    try {
      final name = await PermissionService().deviceTimezoneName();
      if (name != null) {
        try {
          tz.setLocalLocation(tz.getLocation(name));
          _cachedLocalTzName = name;
          return;
        } catch (e) {
          AppLogger.warning('NotificationService',
              'Unknown device timezone "$name", falling back: $e');
        }
      }
    } catch (_) {
      // No native channel (tests, background isolate) — fall through.
    }
    _setLocalLocation();
  }

  void _setLocalLocation() {
    try {
      // Re-verify the cached zone still matches the device offset on every
      // call: travel or a clock change flips the offset, and the old code
      // returned early for Tehran forever, freezing every reminder at the
      // previous zone's wall-clock time.
      final offset = DateTime.now().timeZoneOffset;
      final cached = _cachedLocalTzName;
      if (cached != null) {
        try {
          final loc = tz.getLocation(cached);
          if (tz.TZDateTime.now(loc).timeZoneOffset == offset) {
            tz.setLocalLocation(loc);
            return;
          }
        } catch (e) {
          AppLogger.warning(
              'NotificationService', 'device timezone lookup failed: $e');
        }
      }
      const tehran = 'Asia/Tehran';
      try {
        final loc = tz.getLocation(tehran);
        if (tz.TZDateTime.now(loc).timeZoneOffset == offset) {
          tz.setLocalLocation(loc);
          _cachedLocalTzName = tehran;
          return;
        }
      } catch (e) {
        AppLogger.warning(
            'NotificationService', 'setLocalLocation Tehran failed: $e');
      }
    } catch (e) {
      AppLogger.warning(
          'NotificationService', 'setLocalLocation verify failed: $e');
    }
    // Fallback: legacy offset scan for non-Iran locales (should not happen)
    try {
      final offset = DateTime.now().timeZoneOffset;
      if (_cachedLocalTzName != null &&
          tz.TZDateTime.now(tz.getLocation(_cachedLocalTzName!))
                  .timeZoneOffset ==
              offset) {
        return;
      }
      for (final loc in tz.timeZoneDatabase.locations.values) {
        if (tz.TZDateTime.now(loc).timeZoneOffset == offset) {
          tz.setLocalLocation(loc);
          _cachedLocalTzName = loc.name;
          return;
        }
      }
    } catch (e) {
      _cachedLocalTzName = null;
      AppLogger.warning(
          'NotificationService', 'setLocalLocation fallback failed: $e');
    }
  }

  Future<void> _createNotificationChannels() async {
    final plugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (plugin == null) return;

    const channels = [
      AndroidNotificationChannel(
        'custom_reminders_v2',
        'یادآورها',
        description: 'یادآوری‌های شخصی',
        importance: Importance.high,
        sound: RawResourceAndroidNotificationSound('ios17'),
      ),
      AndroidNotificationChannel(
        _prayerChannelId,
        'اوقات نماز',
        description:
            'یادآوری اوقات نماز (بدون صدا؛ اذان از سرویس پیش‌زمینه پخش می‌شود)',
        importance: Importance.high,
        playSound: false,
      ),
      AndroidNotificationChannel(
        'azkar_reminder_v3',
        'یادآوری اذکار',
        description: 'یادآوری اذکار صبح و شب',
        importance: Importance.high,
        sound: RawResourceAndroidNotificationSound('notif'),
      ),
      AndroidNotificationChannel(
        'islamic_events_v3',
        'مناسبت‌های اسلامی',
        description: 'یادآوری مناسبت‌های اسلامی پیش از فرارسیدن',
        importance: Importance.high,
        sound: RawResourceAndroidNotificationSound('notif'),
      ),
      AndroidNotificationChannel(
        'daily_reminders_v3',
        'یادآوری روزانه',
        description: 'یادآوری‌های روزانه شامل آیه و حدیث',
        importance: Importance.high,
        sound: RawResourceAndroidNotificationSound('notif'),
      ),
      AndroidNotificationChannel(
        'quran_reminder_v3',
        'یادآوری قرآن',
        description: 'یادآوری تلاوت قرآن',
        importance: Importance.high,
        sound: RawResourceAndroidNotificationSound('notif'),
      ),
      AndroidNotificationChannel(
        'khatm_reminder_v3',
        'یادآوری ختم قرآن',
        description: 'یادآوری روزانه خواندن صفحات ختم قرآن',
        importance: Importance.high,
        sound: RawResourceAndroidNotificationSound('notif'),
      ),
      AndroidNotificationChannel(
        'friday_reminder_v3',
        'یادآوری روز جمعه',
        description: 'یادآوری هفتگی آداب و اذکار روز جمعه',
        importance: Importance.high,
        sound: RawResourceAndroidNotificationSound('notif'),
      ),
      AndroidNotificationChannel(
        'friday_kahf_v1',
        'یادآوری سوره کهف',
        description: 'یادآوری هفتگی تلاوت سوره کهف در روز جمعه',
        importance: Importance.high,
        sound: RawResourceAndroidNotificationSound('notif'),
      ),
      AndroidNotificationChannel(
        'fasting_reminder_v1',
        'یادآوری روزه مستحب',
        description: 'یادآوری روزه‌های مستحب دوشنبه و پنجشنبه و ایام بیض',
        importance: Importance.high,
        sound: RawResourceAndroidNotificationSound('notif'),
      ),
    ];
    for (final channel in channels) {
      await plugin.createNotificationChannel(channel);
    }

    // Remove channels from older app versions so Android settings don't
    // accumulate dead entries after an upgrade.
    const legacy = <String>[
      // Channels the native NotificationChannelManager used to create.
      'prayer_reminders',
      'daily_azkar',
      'silent_mode',
      'custom_reminders',
      'azkar_reminder',
      'azkar_reminder_v2',
      'islamic_events',
      'islamic_events_v2',
      'daily_reminders',
      'daily_reminders_v2',
      'quran_reminder',
      'quran_reminder_v2',
      'khatm_reminder',
      'khatm_reminder_v2',
      'friday_reminder',
      'friday_reminder_v2',
      'prayer_times',
    ];
    for (final id in legacy) {
      try {
        await plugin.deleteNotificationChannel(channelId: id);
      } catch (_) {
        AppLogger.warning('notification_service', 'operation failed');
      }
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;

    // Handle interactive action buttons (snooze / confirm) first.
    final actionId = response.actionId;
    if (actionId != null && actionId.isNotEmpty) {
      onNotificationAction?.call(actionId, payload);
      if (actionId == actionSnooze) {
        _snoozeFromPayload(payload);
      }
      return;
    }

    if (payload == null) return;

    // Handle prayer notifications: payload format is "prayer_<name>" (e.g. "prayer_fajr")
    if (payload.startsWith('prayer_')) {
      final name = payload.replaceFirst('prayer_', '');
      // Skip if it's a numeric ID from old-format payloads (e.g. "prayer_notification_100")
      if (name.startsWith('notification_')) return;
      onPrayerTapped?.call(name);
      return;
    }

    // Khatm reminder → open the khatm screen directly. If the app was cold
    // started by this tap the handler isn't registered yet — buffer it.
    if (payload == 'khatm_reminder') {
      final handler = onKhatmTapped;
      if (handler != null) {
        handler();
      } else {
        _pendingKhatmTap = true;
      }
      return;
    }

    // Surah Kahf reminder → open the Quran tab so the ayah can be recited.
    if (payload == 'friday_kahf') {
      final handler = onQuranTapped;
      if (handler != null) {
        handler();
      } else {
        _pendingQuranTap = true;
      }
      return;
    }

    // Personal tools (خودرو / خانه) — payload carries the exact row.
    if (payload.startsWith('care_')) {
      final handler = onCareTapped;
      if (handler != null) {
        handler(payload);
      } else {
        _pendingCarePayload = payload;
      }
      return;
    }

    // Stage-3 personal tools (صله رحم / قلک / قضایار) — payload carries the
    // exact row so the tap lands on the tool that sent it.
    if (payload.startsWith('family_')) {
      final handler = onFamilyTapped;
      if (handler != null) {
        handler(payload);
      } else {
        _pendingFamilyPayload = payload;
      }
      return;
    }
  }

  /// Re-shows a lightweight reminder [snoozeMinutes] later when the user taps
  /// the snooze action on a prayer/adhkar notification.
  Future<void> _snoozeFromPayload(String? payload) async {
    final fireAt = DateTime.now().add(Duration(minutes: snoozeMinutes));
    const title = 'یادآوری مجدد';
    final body = (payload != null && payload.startsWith('prayer_'))
        ? 'یادآوری نماز به تعویق افتاد'
        : 'یادآوری به تعویق افتاد';
    await _scheduleNotification(
      NotificationIds.snooze,
      title,
      body,
      fireAt,
      _azkarChannel,
      payload: payload,
    );
  }

  // --- کانال‌ها ---

  // v5: prayer reminders must be silent — the azan is played by the native
  // foreground service (setAlarmClock → AdhanReceiver). v4 was created with the
  // azan sound, which produced a second sound on top of the real azan; Android
  // never mutates an existing channel, so the id is bumped to drop the sound.
  static const String _prayerChannelId = 'prayer_times_v5';

  /// Interactive action buttons attached to prayer/adhkar notifications.
  static const List<AndroidNotificationAction> _richActions = [
    AndroidNotificationAction(actionConfirm, 'تأیید'),
    AndroidNotificationAction(actionSnooze, 'به تعویق'),
  ];

  /// نقطة تشغيل الأذان الموحّدة: الصوت يعتمد على إعداد المستخدم.
  /// [bigText] يفعّل الإشعار الغني القابل للتوسيع؛ [rich] يضيف أزراراً تفاعلية.
  AndroidNotificationDetails prayerChannel({
    String soundName = 'azan_takbir',
    String? bigText,
    bool rich = true,
  }) =>
      AndroidNotificationDetails(
        _prayerChannelId,
        'اوقات نماز',
        channelDescription: 'یادآوری اوقات نماز با صدای اذان',
        importance: Importance.high,
        icon: '@drawable/ic_notification',
        largeIcon: const DrawableResourceAndroidBitmap('ic_notification_logo'),
        sound: RawResourceAndroidNotificationSound(soundName),
        category: AndroidNotificationCategory.alarm,
        color: _brandColor,
        visibility: _visible,
        styleInformation:
            bigText != null ? BigTextStyleInformation(bigText) : null,
        actions: rich ? _richActions : null,
      );

  /// قناة تذكير الأذان بدون صوت الأذان (عندما يُعطّل الأذان لصلاة معيّنة).
  /// Silent so the azan plays only through the native setAlarmClock →
  /// foreground-service path (single authoritative azan, no double audio).
  AndroidNotificationDetails _prayerChannelNoSound(
          {String? bigText, bool rich = true}) =>
      AndroidNotificationDetails(
        _prayerChannelId,
        'اوقات نماز',
        channelDescription: 'یادآوری اوقات نماز',
        importance: Importance.high,
        icon: '@drawable/ic_notification',
        largeIcon: const DrawableResourceAndroidBitmap('ic_notification_logo'),
        category: AndroidNotificationCategory.alarm,
        playSound: false,
        silent: true,
        color: _brandColor,
        visibility: _visible,
        styleInformation:
            bigText != null ? BigTextStyleInformation(bigText) : null,
        actions: rich ? _richActions : null,
      );

  /// يحوّل اسم صوت الأذان من الإعدادات إلى ملف المورد المناسب.
  String _azanSoundResource(String azanSound) {
    switch (azanSound) {
      case 'kamel':
        return 'azan_kamel';
      case 'takbirShort':
        return 'azan_takbir_short';
      default:
        return 'azan_takbir';
    }
  }

  AndroidNotificationDetails get _azkarChannel =>
      const AndroidNotificationDetails(
        'azkar_reminder_v3',
        'یادآوری اذکار',
        channelDescription: 'یادآوری اذکار صبح و شب',
        importance: Importance.high,
        icon: '@drawable/ic_notification',
        largeIcon: DrawableResourceAndroidBitmap('ic_notification_logo'),
        sound: RawResourceAndroidNotificationSound('notif'),
        color: _brandColor,
        visibility: _visible,
        actions: _richActions,
      );

  /// قناة مناسبات إسلامية غنية (نص موسّع + أزرار تفاعلية).
  AndroidNotificationDetails _islamicEventChannel(String bigText) =>
      AndroidNotificationDetails(
        'islamic_events_v3',
        'مناسبت‌های اسلامی',
        channelDescription: 'یادآوری مناسبت‌های اسلامی پیش از فرارسیدن',
        importance: Importance.high,
        icon: '@drawable/ic_notification',
        largeIcon: const DrawableResourceAndroidBitmap('ic_notification_logo'),
        sound: const RawResourceAndroidNotificationSound('notif'),
        color: _brandColor,
        visibility: _visible,
        styleInformation: BigTextStyleInformation(bigText),
        actions: _richActions,
      );

  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    bool sound = false,
    String soundName = 'ios17',
    String? bigText,
  }) async {
    AndroidNotificationSound? soundRes;
    if (soundName == 'silent') {
      soundRes = null;
    } else if (soundName == 'default') {
      soundRes = null;
    } else if (soundName.startsWith('custom:')) {
      soundRes = UriAndroidNotificationSound(
          Uri.file(soundName.substring(7)).toString());
    } else if (SoundChoice.isSystem(soundName)) {
      final uri = SoundChoice.systemUri(soundName);
      soundRes = uri == null
          ? null
          : UriAndroidNotificationSound(uri);
    } else {
      soundRes = RawResourceAndroidNotificationSound(soundName);
    }
    final channel = AndroidNotificationDetails(
      'custom_reminders_v2',
      'یادآورها',
      channelDescription: 'یادآوری‌های شخصی',
      importance: Importance.high,
      icon: '@drawable/ic_notification',
      largeIcon: const DrawableResourceAndroidBitmap('ic_notification_logo'),
      category: AndroidNotificationCategory.alarm,
      sound: soundRes,
      silent: soundName == 'silent',
      color: _brandColor,
      visibility: _visible,
      styleInformation: bigText != null
          ? BigTextStyleInformation(bigText,
              contentTitle: title,
              summaryText: body != bigText ? body : null,
              htmlFormatTitle: true,
              htmlFormatBigText: true,
              htmlFormatSummaryText: true)
          : null,
    );
    await _notifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(android: channel));
  }

  // --- اوقات نماز ---

  /// عبارات کوتاه و دلنشین برای هر نماز: (عربی، فارسی).
  static const Map<String, (String, String)> _prayerContent = {
    'fajr': (
      'الصَّلَاةُ خَيْرٌ مِّنَ النَّوْمِ',
      'روزت را با یاد حق روشن کن...'
    ),
    'dhuhr': ('أَقِيمُوا الصَّلَاةَ', 'هیاهوی روز را به آرامش نماز بسپار'),
    'asr': ('وَالْعَصْرِ...', 'لحظه‌ای سکوت؛ زمان گفتگو با خدا'),
    'maghrib': ('فَاذْكُرُوا اللَّهَ', 'خورشید غروب کرد، وقتِ دلدادگی'),
    'isha': ('أَقِمِ الصَّلَاةَ', 'پایان روز با آرامشِ یادِ او...'),
  };

  /// ساخت متن بدنهٔ جذاب و مختصر برای هر نماز.
  String _prayerBody(String key) {
    final c = _prayerContent[key];
    if (c == null) return 'وقت نماز فرا رسید';
    return '${c.$2}\n${c.$1}';
  }

  /// کانال مناسب برای یک نماز — از نسخه بی‌صدا استفاده می‌شود تا اذان فقط از
  /// مسیر native (setAlarmClock → foreground service) پخش شود و صدای تکراری نباشد.
  AndroidNotificationDetails _channelForPrayer(
          bool azanEnabled, String soundName,
          {String? bigText}) =>
      _prayerChannelNoSound(bigText: bigText);

  Future<void> schedulePrayerNotifications(PrayerTimes times,
      {AppSettings? settings}) async {
    // PrayerTimes contains wall-clock fields for the app's selected location.
    // Use that same zone for conversion and comparisons; tagging them with the
    // device zone made alarms drift (or look already passed) when the two zones
    // differed, especially after travel or a restored timezone setting.
    final scheduleTimezone = settings?.timezone;
    // A notification that missed its wall-clock time is stale, not pending.
    // Keeping it in Android's queue makes it appear when the user next opens
    // the app (often many minutes after the prayer). Always remove it while
    // rebuilding today's schedule.
    final pendingNow = await _notifications.pendingNotificationRequests();
    final pendingIds = pendingNow.map((p) => p.id).toSet();

    await _cancelBoth(id: 107);
    // Post-prayer azkar (120-124) is managed independently by
    // [schedulePostPrayerNotifications] / [cancelPostPrayerNotifications] —
    // it intentionally survives the prayer queue rebuild so toggling prayer
    // reminders never wipes it without rebuilding it.
    // Cancel today's pre-adhan reminders too — rescheduled below with the
    // current prayerNotifMinutes (0 disables them entirely).
    for (int i = NotificationIds.preAdhanFajr;
        i <= NotificationIds.preAdhanIsha;
        i++) {
      await _cancelBoth(id: i);
    }
    // The auto-scheduler now covers ALL five prayers today, so drop any
    // tracker-triggered (manual) post-prayer reminders still pending from an
    // earlier toggle — otherwise the same prayer gets two identical
    // «اذکار بعد از نماز» notifications (manual 300-304 + auto 120-124).
    for (int i = NotificationIds.manualPostFajr;
        i <= NotificationIds.manualPostIsha;
        i++) {
      await _cancelBoth(id: i);
    }

    // Request/refresh exact-alarm mode before scheduling either pre-adhan or
    // post-prayer reminders. Previously this ran only after the pre-adhan loop,
    // so the first schedule after granting permission left those reminders in
    // inexact mode and Doze could deliver them hours late.
    await _ensureExactForPostPrayer();

    final now = wallClockTime(DateTime.now());

    // تشغيل الأذان يعتمد على إعداد المستخدم لكل صلاة.
    // إن كان الأذان معطّلاً نستخدم قناة بلا صوت؛ وإلا نستخدم القناة بصوت الأذان المختار.
    final azanSound = settings != null
        ? _azanSoundResource(settings.azanSound)
        : 'azan_takbir';

    final prayers = <int, (String, String, DateTime, bool)>{
      100: (
        'اذان فجر',
        _prayerBody('fajr'),
        times.fajr,
        settings?.azanEnabledForFajr ?? false
      ),
      101: (
        'اذان ظهر',
        _prayerBody('dhuhr'),
        times.dhuhr,
        settings?.azanEnabledForDhuhr ?? false
      ),
      102: (
        'اذان عصر',
        _prayerBody('asr'),
        times.asr,
        settings?.azanEnabledForAsr ?? false
      ),
      103: (
        'اذان مغرب',
        _prayerBody('maghrib'),
        times.maghrib,
        settings?.azanEnabledForMaghrib ?? false
      ),
      104: (
        'اذان عشاء',
        _prayerBody('isha'),
        times.isha,
        settings?.azanEnabledForIsha ?? false
      ),
    };

    for (final entry in prayers.entries) {
      final id = entry.key;
      final (title, body, rawTime, azanEnabled) = entry.value;
      final time = wallClockTime(rawTime);
      if (pendingIds.contains(id) && !time.isAfter(now)) {
        // Do not preserve stale notifications: a late prayer reminder is
        // misleading and was the reason an old prayer appeared on app resume.
        await _cancelBoth(id: id);
        continue;
      }
      await _cancelBoth(id: id);
      if (time.isAfter(now)) {
        await _scheduleNotification(id, title, body, time,
            _channelForPrayer(azanEnabled, azanSound, bigText: body),
            timezone: scheduleTimezone);
      }
      // Silent «N minutes to prayer» reminder ahead of the adhan when the
      // user enabled it (prayerNotifMinutes > 0). Fires minutesBefore the
      // adhan; the adhan itself still fires at the exact time above.
      final reminderId = _preAdhanIdFor(id);
      if (reminderId != null &&
          settings?.prayerNotifMinutes != null &&
          settings!.prayerNotifMinutes > 0) {
        await _schedulePreAdhanReminder(
          id: reminderId,
          prayerName: _prayerShortName(title),
          prayerTime: time,
          minutesBefore: settings.prayerNotifMinutes,
          timezone: scheduleTimezone,
        );
      }
    }

    // صلاة الضحى: بعد 15 دقيقة من طلوع الشمس — تذكير مستحب (بلا صوت أذان)
    final dhuhaTime =
        wallClockTime(times.sunrise).add(const Duration(minutes: 15));
    if (dhuhaTime.isAfter(now)) {
      await _scheduleNotification(
        107,
        'نماز ضحی',
        'خورشید برآمد؛ فرصتِ دو رکعت بندگی',
        dhuhaTime,
        _azkarChannel,
      );
    }
  }

  /// «اذکار بعد از نماز» for TODAY (ids 120–124): each prayer's iqamah
  /// offset plus the user-configured post-prayer delay. Independent of the
  /// prayer-reminder toggle — the caller gates on [postPrayerEnabled].
  Future<void> schedulePostPrayerNotifications(PrayerTimes times,
      {AppSettings? settings}) async {
    for (int i = 120; i <= 124; i++) {
      await _cancelBoth(id: i);
    }
    await _ensureExactForPostPrayer();

    final now = wallClockTime(DateTime.now());
    final postPrayerDelay = await postPrayerDelayMinutes();
    final postPrayerTimes = <int, (String, String, DateTime)>{
      120: (
        'اذکار بعد از نماز صبح',
        'نمازت قبول؛ کام جان را با اذکار شیرین کن.',
        wallClockTime(times.fajr).add(Duration(
            minutes: (settings?.iqamahOffsetFajr ?? 30) + postPrayerDelay))
      ),
      121: (
        'اذکار بعد از نماز ظهر',
        'لحظات پس از نماز، فرصتی برای پرواز.',
        wallClockTime(times.dhuhr).add(Duration(
            minutes: (settings?.iqamahOffsetDhuhr ?? 25) + postPrayerDelay))
      ),
      122: (
        'اذکار بعد از نماز عصر',
        'ذکر بعد از نماز؛ همراهِ آرامشِ عصر.',
        wallClockTime(times.asr).add(Duration(
            minutes: (settings?.iqamahOffsetAsr ?? 25) + postPrayerDelay))
      ),
      123: (
        'اذکار بعد از نماز مغرب',
        'در این ساعتِ نورانی، ذکر حق را فراموش نکن.',
        wallClockTime(times.maghrib).add(Duration(
            minutes: (settings?.iqamahOffsetMaghrib ?? 7) + postPrayerDelay))
      ),
      124: (
        'اذکار بعد از نماز عشاء',
        'خاتمه‌بخشِ نمازت، با زمزمهٔ اذکار شبانه.',
        wallClockTime(times.isha).add(Duration(
            minutes: (settings?.iqamahOffsetIsha ?? 25) + postPrayerDelay))
      ),
    };
    for (final entry in postPrayerTimes.entries) {
      final (title, body, rawTime) = entry.value;
      final time = wallClockTime(rawTime);
      if (time.isAfter(now)) {
        await _scheduleNotification(
            entry.key, title, body, time, _azkarChannel);
      }
    }
  }

  /// Cancels every post-prayer azkar notification (today 120–124, tomorrow
  /// 125–129, day-after 216–220, extended 3066–3070 … 3166–3170) plus the
  /// legacy tracker-triggered manual ones (300–304).
  Future<void> cancelPostPrayerNotifications() async {
    for (int i = 120; i <= 124; i++) {
      await _cancelBoth(id: i);
    }
    for (int i = 125; i <= 129; i++) {
      await _cancelBoth(id: i);
    }
    for (int i = 216; i <= 220; i++) {
      await _cancelBoth(id: i);
    }
    for (var offset = 3; offset <= 7; offset++) {
      final base = 3000 + offset * 20 + 6;
      for (var id = base; id <= base + 4; id++) {
        await _cancelBoth(id: id);
      }
    }
    for (int i = NotificationIds.manualPostFajr;
        i <= NotificationIds.manualPostIsha;
        i++) {
      await _cancelBoth(id: i);
    }
  }

  Future<void> scheduleTomorrowNotifications(PrayerTimes times,
      {AppSettings? settings, bool includePrayer = true}) async {
    await _scheduleDayNotifications(
      prayerBase: 110,
      duhaId: 117,
      postBase: 125,
      times: times,
      settings: settings,
      includePrayer: includePrayer,
    );
  }

  /// Schedules the day-after-tomorrow window (IDs 210–222) so notifications
  /// keep firing for up to two days even if the app is never opened and
  /// native background scheduling is deferred by aggressive battery managers.
  Future<void> scheduleDayAfterTomorrowNotifications(PrayerTimes times,
      {AppSettings? settings, bool includePrayer = true}) async {
    await _scheduleDayNotifications(
      prayerBase: 210,
      duhaId: 215,
      postBase: 216,
      times: times,
      settings: settings,
      includePrayer: includePrayer,
    );
  }

  Future<void> schedulePrayerNotification({
    required int id,
    required String prayerName,
    required DateTime prayerTime,
    int minutesBefore = 5,
  }) async {
    final notifyTime =
        wallClockTime(prayerTime).subtract(Duration(minutes: minutesBefore));
    if (notifyTime.isBefore(wallClockTime(DateTime.now()))) return;

    try {
      await _scheduleNotification(
        id,
        minutesBefore > 0 ? 'یادآوری نماز $prayerName' : 'وقت نماز $prayerName',
        minutesBefore > 0
            ? '$minutesBefore دقیقه دیگر وقت نماز $prayerName فرا می‌رسد'
            : 'وقت نماز $prayerName فرا رسید',
        notifyTime,
        _prayerChannelNoSound(),
        payload: 'prayer_$prayerName',
      );
    } catch (e, st) {
      AppLogger.error('NotificationService',
          'Failed to schedule prayer reminder $id: $e', st);
    }
  }

  /// Diagnostic: schedules a real adhan notification (flutter channel with azan
  /// sound + native setAlarmClock) ~1 minute from now so the full prayer path
  /// can be verified without waiting for an actual prayer time. The caller's
  /// current azan settings are exercised (custom file included on the native
  /// alarm path).
  Future<void> scheduleTestAdhan({
    String azanSound = 'kamel',
    String? customAzanPath,
  }) async {
    final fireAt = DateTime.now().add(const Duration(minutes: 1));
    const body = 'این یک اعلان آزمایشی اذان است';
    await _scheduleNotification(
      NotificationIds.testAdhan,
      'اذان تستی',
      body,
      fireAt,
      prayerChannel(soundName: _azanSoundResource(azanSound), bigText: body),
    );
    await NativePrayerAlarmService().scheduleTestAlarm(
      fireAt: fireAt,
      azanSound: azanSound,
      customAzanPath: customAzanPath,
    );
  }

  Future<void> cancelPrayerNotifications() async {
    // Cancel today's prayer and post-prayer notifications (100-104, 107, 120-124)
    for (int i = 100; i <= 104; i++) {
      await _cancelBoth(id: i);
    }
    await _cancelBoth(id: 107); // Duha today
    for (int i = 120; i <= 124; i++) {
      await _cancelBoth(id: i);
    }
    // Cancel tomorrow's prayer and post-prayer notifications (110-114, 117, 125-129)
    for (int i = 110; i <= 114; i++) {
      await _cancelBoth(id: i);
    }
    await _cancelBoth(id: 117); // Duha tomorrow
    for (int i = 125; i <= 129; i++) {
      await _cancelBoth(id: i);
    }
    // Cancel all pre-adhan reminders (today 500-504, tomorrow 510-514,
    // day-after 520-524) — they follow the prayerNotifications toggle.
    for (int i = 500; i <= 524; i++) {
      await _cancelBoth(id: i);
    }
    // Cancel day-after-tomorrow's prayer and post-prayer notifications (210-220)
    await cancelDayAfterTomorrowNotifications();
    // NOTE: morning/evening azkar are NOT cancelled here — they have their own
    // toggles and are managed by [scheduleAzkarReminders] independently of the
    // prayer-reminder toggle.
  }

  /// Schedules a prayer/post-prayer window for a future day beyond the legacy
  /// today/tomorrow ranges. The IDs are deterministic, so rerunning this method
  /// replaces the previous entry instead of creating duplicates.
  Future<void> scheduleExtendedDayNotifications({
    required int dayOffset,
    required PrayerTimes times,
    AppSettings? settings,
    bool includePrayer = true,
  }) async {
    if (dayOffset < 3 || dayOffset > 7) return;
    final base = 3000 + dayOffset * 20;
    await _scheduleDayNotifications(
      prayerBase: base,
      duhaId: base + 5,
      postBase: base + 6,
      times: times,
      settings: settings,
      includePrayer: includePrayer,
    );
  }

  /// Cancels the extended prayer notification window (days 3–7), including
  /// pre-adhan reminders. Pass [dayOffset] to reconcile only one future day.
  /// Morning/evening azkar (4000-ids) have their own toggles: they are only
  /// included when [includeAzkar] is true (full rebuilds); the prayer-off
  /// path must leave them alone.
  Future<void> cancelExtendedDayNotifications(
      {int? dayOffset, bool includeAzkar = true}) async {
    final firstDay = dayOffset ?? 3;
    final lastDay = dayOffset ?? 7;
    for (var offset = firstDay; offset <= lastDay; offset++) {
      if (offset < 3 || offset > 7) continue;
      final prayerBase = 3000 + offset * 20;
      for (var id = prayerBase; id <= prayerBase + 10; id++) {
        await _cancelBoth(id: id);
      }
      final preBase = 6000 + offset * 20;
      for (var id = preBase; id <= preBase + 4; id++) {
        await _cancelBoth(id: id);
      }
      if (!includeAzkar) continue;
      final azkarBase = 4000 + offset * 20;
      for (var id = azkarBase; id <= azkarBase + 1; id++) {
        await _cancelBoth(id: id);
      }
    }
  }

  /// Drops the ENTIRE prayer-reminder queue in one call: today, tomorrow,
  /// day-after-tomorrow, extended days 3–7 (prayer windows only, never the
  /// independently-toggled morning/evening azkar), plus the native
  /// setAlarmClock alarms. Post-prayer azkar has its own toggle and is
  /// deliberately preserved here — it is rebuilt or cancelled through
  /// [schedulePostPrayerNotifications] / [cancelPostPrayerNotifications].
  /// Use this wherever prayer reminders are turned off so no stale future
  /// alarm can survive.
  Future<void> cancelAllPrayerRelated() async {
    await cancelPrayerNotifications();
    await cancelExtendedDayNotifications(includeAzkar: false);
    try {
      await NativePrayerAlarmService().cancelAll();
    } catch (e) {
      AppLogger.warning(
          'NotificationService', 'Native alarm cancel failed: $e');
    }
  }

  /// Cancels only tomorrow's Flutter notification window when its prayer times
  /// are unavailable during a refresh.
  Future<void> cancelTomorrowNotifications() async {
    await _cancelDayNotificationWindow(
      prayerBase: 110,
      duhaId: 117,
      postBase: 125,
    );
  }

  /// Cancels only the day-after-tomorrow Flutter notification window when its
  /// prayer times are unavailable during a refresh.
  Future<void> cancelDayAfterTomorrowNotifications() async {
    await _cancelDayNotificationWindow(
      prayerBase: 210,
      duhaId: 215,
      postBase: 216,
    );
  }

  /// Schedules one morning/evening adhkar pair for an extended future day.
  /// Morning/evening azkar (اذکار صبح/شب).
  ///
  /// Each slot is a **self-healing repeating daily reminder** armed natively
  /// with `setAlarmClock` + repeat (the same machinery as the azan): fixed ids
  /// [NotificationIds.morningAzkar] and [NotificationIds.eveningAzkar].
  /// [ReminderReceiver] re-arms the next day's occurrence after every fire and
  /// `rescheduleAllAfterBoot` rolls the repeat forward after a reboot, so the
  /// azkar can never silently expire the way the old per-day one-shot window
  /// did (the cause of the azkar stopping on the user's device).
  ///
  /// Morning azkar fire **45 minutes after Fajr**, evening azkar **1 hour after
  /// Asr** (azan times) when prayer times are available for today. If prayer
  /// times are unavailable (e.g. no location set) the user's fixed wall-clock
  /// times ([morningAzkarTime]/[eveningAzkarTime]) are used. Independent of the
  /// prayer-reminder toggle: each fires when its own toggle is on and is
  /// cancelled only when toggled off. The old per-day one-shot series
  /// (tomorrow/day-after ids and the day 3-7 range) is cancelled once here so
  /// nothing double-fires next to the new repeating slots.
  Future<void> scheduleAzkarReminders({
    AppSettings? settings,
    PrayerTimes? todayTimes,
    PrayerTimes? tomorrowTimes,
    PrayerTimes? dayAfterTimes,
  }) async {
    // Clean up the per-day one-shot series armed by previous builds.
    await _cancelBoth(id: NotificationIds.tomorrowMorningAzkar);
    await _cancelBoth(id: NotificationIds.tomorrowEveningAzkar);
    await _cancelBoth(id: NotificationIds.dayAfterTomorrowMorningAzkar);
    await _cancelBoth(id: NotificationIds.dayAfterTomorrowEveningAzkar);
    await cancelNativeReminderRange(4000, 4300);

    // Sweep the Flutter-plugin pending list for any «اذکار صبح/شب» left behind
    // by older plugin-based builds (repeating daily, tomorrow/day-after ids, or
    // the 4000-4300 per-day one-shot range). cancelNativeReminderRange above
    // only clears native storage, so without this a stale copy — armed at an old
    // day's time and delivered hours off — keeps firing next to the native
    // chain. Ids 105/106 are the active slots and are re-armed right below.
    try {
      final pending = await _notifications.pendingNotificationRequests();
      for (final req in pending) {
        if (req.id == NotificationIds.morningAzkar ||
            req.id == NotificationIds.eveningAzkar) {
          continue;
        }
        final isAzkar = req.title == 'اذکار صبح' ||
            req.title == 'اذکار شب' ||
            req.payload == 'adhkar_morning' ||
            req.payload == 'adhkar_evening';
        final legacyRange = req.id >= 4000 && req.id <= 4300;
        if (isAzkar || legacyRange) {
          await _notifications.cancel(id: req.id);
        }
      }
    } catch (e, st) {
      AppLogger.warning(
          'NotificationService', 'Azkar plugin-pending sweep failed: $e');
      AppLogger.error(
          'NotificationService', 'Azkar plugin-pending sweep stack', st);
    }

    final morningManual = await isAzkarManual(morning: true);
    final eveningManual = await isAzkarManual(morning: false);

    if (settings?.morningAzkarNotification ?? true) {
      final morningToD = (todayTimes != null && !morningManual)
          ? TimeOfDay.fromDateTime(
              wallClockTime(todayTimes.fajr).add(const Duration(minutes: 45)))
          : TimeOfDay(
              hour: settings?.morningAzkarTime.hour ?? 6,
              minute: settings?.morningAzkarTime.minute ?? 0);
      await _scheduleNotification(
        NotificationIds.morningAzkar,
        'اذکار صبح',
        'وقت اذکار صبح فرا رسید؛ با یاد خدا روزت را پربرکت کن',
        _nextInstanceOfTime(morningToD),
        _azkarChannel,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'adhkar_morning',
      );
    } else {
      await _cancelBoth(id: NotificationIds.morningAzkar);
    }

    if (settings?.eveningAzkarNotification ?? true) {
      final eveningToD = (todayTimes != null && !eveningManual)
          ? TimeOfDay.fromDateTime(
              wallClockTime(todayTimes.asr).add(const Duration(hours: 1)))
          : TimeOfDay(
              hour: settings?.eveningAzkarTime.hour ?? 20,
              minute: settings?.eveningAzkarTime.minute ?? 0);
      await _scheduleNotification(
        NotificationIds.eveningAzkar,
        'اذکار شب',
        'وقت اذکار شب فرا رسید؛ شب را با یاد خدا آرامش بخش',
        _nextInstanceOfTime(eveningToD),
        _azkarChannel,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'adhkar_evening',
      );
    } else {
      await _cancelBoth(id: NotificationIds.eveningAzkar);
    }
  }

  // --- اذکار صبح/شب بناءً على أوقات إقامة النماز ---

  /// Legacy: now handled inside [schedulePrayerNotifications] / [scheduleTomorrowNotifications].
  /// Kept as a no-op for callers that have not been migrated yet.
  Future<void> scheduleDailyAdhkarNotifications(AppSettings? settings) async {
    await _cancelBoth(id: NotificationIds.morningAzkar);
    await _cancelBoth(id: NotificationIds.eveningAzkar);
  }

  /// Schedule a post-prayer azkar reminder after the user marks a prayer as
  /// done in the tracker. Uses its own ID range (300-304) so it never collides
  /// with the daily auto-scheduled azkar (120-129).
  Future<void> schedulePostPrayerAzkar({
    required String prayerName,
    required DateTime scheduledTime,
  }) async {
    final time = wallClockTime(scheduledTime);
    if (time.isBefore(wallClockTime(DateTime.now()))) return;

    final id = _manualPostPrayerIdByName(prayerName);
    await _cancelBoth(id: id); // cancel any existing

    final (title, body) = _postPrayerContent(prayerName);
    await _scheduleNotification(
      id,
      title,
      body,
      time,
      _azkarChannel,
      payload: 'azkar_postprayer',
    );
  }

  /// Maps prayer name to post-prayer notification title and body.
  (String, String) _postPrayerContent(String name) {
    switch (name) {
      case 'fajr':
        return (
          'اذکار بعد از نماز صبح',
          'نمازت قبول؛ کام جان را با اذکار شیرین کن.'
        );
      case 'dhuhr':
        return ('اذکار بعد از نماز ظهر', 'لحظات پس از نماز، فرصتی برای پرواز.');
      case 'asr':
        return ('اذکار بعد از نماز عصر', 'ذکر بعد از نماز؛ همراهِ آرامشِ عصر.');
      case 'maghrib':
        return (
          'اذکار بعد از نماز مغرب',
          'در این ساعتِ نورانی، ذکر حق را فراموش نکن.'
        );
      case 'isha':
        return (
          'اذکار بعد از نماز عشاء',
          'خاتمه‌بخشِ نمازت، با زمزمهٔ اذکار شبانه.'
        );
      default:
        return ('اذکار بعد از نماز', 'اذکار بعد از نماز را بخوانید');
    }
  }

  /// Map prayer name to the manual (tracker-triggered) post-prayer ID.
  int _manualPostPrayerIdByName(String name) {
    switch (name) {
      case 'fajr':
        return NotificationIds.manualPostFajr;
      case 'dhuhr':
        return NotificationIds.manualPostDhuhr;
      case 'asr':
        return NotificationIds.manualPostAsr;
      case 'maghrib':
        return NotificationIds.manualPostMaghrib;
      case 'isha':
        return NotificationIds.manualPostIsha;
      default:
        return 300;
    }
  }

  String prayerNameFa(String name) {
    switch (name) {
      case 'fajr':
        return 'فجر';
      case 'dhuhr':
        return 'ظهر';
      case 'asr':
        return 'عصر';
      case 'maghrib':
        return 'مغرب';
      case 'isha':
        return 'عشاء';
      default:
        return name;
    }
  }

  // --- مناسبات إسلامية شهرية ---

  /// يجدول إشعاراً غنياً قبل [daysBefore] أيام من كل مناسبة إسلامية قادمة.
  Future<void> scheduleMonthlyIslamicEvents(
    List<IslamicEventOccurrence> events, {
    int daysBefore = 3,
    int hour = 9,
  }) async {
    await cancelIslamicEventNotifications();
    final now = DateTime.now();
    var id = NotificationIds.islamicEventBase;

    for (final event in events) {
      if (id > NotificationIds.islamicEventMax) break;
      final eventDay =
          DateTime(event.date.year, event.date.month, event.date.day, hour);
      final notifyAt = eventDay.subtract(Duration(days: daysBefore));
      if (notifyAt.isAfter(now)) {
        final body = '$daysBefore روز دیگر: ${event.title}';
        await _scheduleNotification(
          id,
          'مناسبت اسلامی',
          body,
          notifyAt,
          _islamicEventChannel(body),
          payload: 'islamic_event',
        );
        id++;
      }
    }
  }

  Future<void> cancelIslamicEventNotifications() async {
    for (int i = NotificationIds.islamicEventBase;
        i <= NotificationIds.islamicEventMax;
        i++) {
      await _cancelBoth(id: i);
    }
  }

  // --- قرآن ---

  // --- یادآوری هوشمند روزانه: آیه قرآن ---
  // The verse list and the day index live in [DailyVerseSource] so the Quran
  // tab («آیه روز» card) and this notification always show the same verse on
  // the same day.

  @visibleForTesting
  static List<Map<String, String>> get dailyVerses =>
      DailyVerseSource.dailyVerses;

  /// How many days ahead the daily آیه/حدیث/دعا window is scheduled. Each day
  /// gets its own one-shot notification (content computed per fire date), so a
  /// 7-day window guarantees rotation for a week even if the app is never opened
  /// and native background scheduling is deferred by battery managers.
  static const int dailyContentWindowDays = 7;

  // --- یادآوری هوشمند: حدیث روز ---
  // The hadith list and the day index live in [DailyHadithSource] so the
  // Hadith screen («چهل حدیث») and this notification always show the same
  // hadith on the same day.

  @visibleForTesting
  static List<Map<String, String>> get dailyHadiths =>
      DailyHadithSource.dailyHadiths;

  // --- یادآوری هوشمند: دعای روز ---

  // --- یادآوری هفتگی روز جمعه ---

  static const String fridayEnabledKey = 'friday_reminder_enabled';
  static const String fridayHourKey = 'friday_reminder_hour';
  static const String fridayMinuteKey = 'friday_reminder_minute';
  static const int defaultFridayHour = 7;
  static const int defaultFridayMinute = 0;

  /// یادآوری مستقل «سوره کهف» — جمعه ۶ صبح.
  static const String fridayKahfEnabledKey = 'friday_kahf_reminder_enabled';
  static const String fridayKahfHourKey = 'friday_kahf_reminder_hour';
  static const String fridayKahfMinuteKey = 'friday_kahf_reminder_minute';
  static const int defaultFridayKahfHour = 6;
  static const int defaultFridayKahfMinute = 0;

  // --- یادآوری روزانه ختم قرآن ---

  static const String khatmEnabledKey = 'khatm_reminder_enabled';
  static const String khatmHourKey = 'khatm_reminder_hour';
  static const String khatmMinuteKey = 'khatm_reminder_minute';
  static const int defaultKhatmHour = 8;
  static const int defaultKhatmMinute = 0;

  // --- یادآوری روزه مستحب (دوشنبه/پنجشنبه + ایام بیض) ---
  // Pref-backed (not [AppSettings]) so the toggles need no Drift migration —
  // the same pattern as the Friday reminders above.

  static const String fastingMonThuEnabledKey =
      'fasting_monday_thursday_enabled';
  static const String fastingMonThuHourKey = 'fasting_monday_thursday_hour';
  static const String fastingMonThuMinuteKey = 'fasting_monday_thursday_minute';

  static const String fastingBidhEnabledKey = 'fasting_ayam_al_bidh_enabled';
  static const String fastingBidhHourKey = 'fasting_ayam_al_bidh_hour';
  static const String fastingBidhMinuteKey = 'fasting_ayam_al_bidh_minute';

  static const int defaultFastingHour = 7;
  static const int defaultFastingMinute = 0;

  /// How far ahead the ایام بیض per-day window is armed. The three white days
  /// move ~11 days earlier each Gregorian month, so a 45-day window always
  /// covers at least one complete 13-15 block (and never more than two).
  static const int ayamAlBidhWindowDays = 45;

  // --- یادآوری هوشمند همه روزانه ---

  // --- ابزارها ---

  /// Runs [body] with native reminder ops collected into a single
  /// `applyReminderOps` call instead of one awaited round trip per id.
  ///
  /// A full reschedule pass touches hundreds of alarms; each previous call
  /// stalled the Android main thread (the method-channel handler answered
  /// inline) and the replies serialised, which is what made the app scroll like
  /// sludge for ~20 s after launch. Kotlin now runs the batch on its own worker
  /// thread, and the ids it skipped (already armed, unchanged) never touch
  /// AlarmManager at all.
  ///
  /// Nestable: only the outermost exit flushes. Callers that await this get the
  /// real end state — the flush is awaited before the future completes.
  Future<T> batchNativeReminders<T>(Future<T> Function() body) async {
    _nativeOpBatchDepth++;
    try {
      return await body();
    } finally {
      if (--_nativeOpBatchDepth == 0) {
        await _flushNativeOps();
        _modeQueriedInBatch = false;
      }
    }
  }

  /// Queues [op] inside a batch, or runs it on its own when none is open.
  /// Non-Android returns immediately: there is no native alarm there and the
  /// channel has no handler, so a call would only throw MissingPluginException
  /// (the old code swallowed exactly that on every iOS reminder).
  Future<void> _enqueueNativeOp(Map<String, Object?> op) async {
    if (!Platform.isAndroid) return;
    if (_nativeOpBatchDepth > 0) {
      _nativeOps.add(op);
      return;
    }
    await _invokeNativeOp(op);
  }

  Future<void> _flushNativeOps() async {
    if (_nativeOps.isEmpty) return;
    final ops = List<Map<String, Object?>>.of(_nativeOps);
    _nativeOps.clear();
    try {
      final counts = await _exactReminders.invokeMethod<dynamic>(
        'applyReminderOps',
        {'opsJson': jsonEncode(ops)},
      );
      AppLogger.info(
          'NotificationService', 'native reminder batch: ${ops.length} ops -> $counts');
    } catch (e, st) {
      // The whole batch is lost if the call fails — worse than the old per-id
      // failure, so fall back to one call per op to keep the guarantee every
      // individual reminder made before. Cancels especially must not be lost:
      // a disabled reminder that still rings is a correctness bug.
      AppLogger.error('NotificationService',
          'native reminder batch failed (${ops.length} ops): $e — retrying one by one',
          st);
      for (final op in ops) {
        await _invokeNativeOp(op);
      }
    }
  }

  /// One op on its own, in the legacy single-call method names. Errors are
  /// logged, never rethrown: a single failed reminder must not abort a batch.
  Future<void> _invokeNativeOp(Map<String, Object?> op) async {
    final type = op['type'];
    try {
      switch (type) {
        case 'arm':
          await _exactReminders.invokeMethod('scheduleReminder', {
            'id': op['id'],
            'triggerTimeMillis': op['timeMillis'],
            'title': op['title'],
            'body': op['body'],
            'channelId': op['channelId'],
            'sound': op['sound'],
            'payload': op['payload'],
            'repeatDailyMillis': op['repeatDailyMillis'],
          });
        case 'cancel':
          await _exactReminders.invokeMethod('cancelReminder', {'id': op['id']});
        case 'cancelRange':
          await _exactReminders.invokeMethod('cancelRangeReminders', {
            'startId': op['startId'],
            'endId': op['endId'],
          });
        default:
          AppLogger.warning(
              'NotificationService', 'unknown native reminder op: $type');
      }
    } catch (e, st) {
      AppLogger.error('NotificationService', 'native reminder op $type failed: $e', st);
    }
  }

  Future<void> _scheduleNotification(
    int id,
    String title,
    String body,
    DateTime scheduledTime,
    AndroidNotificationDetails androidDetails, {
    DateTimeComponents? matchDateTimeComponents,
    String? payload,
    String? timezone,
    String? nativeSound,
  }) async {
    // The exact-alarm grant can change anytime in system settings; re-query it
    // so we never route a reminder to a stale delivery mode. Cheap, and correct
    // for every caller (scheduler, reminders, tasks, pomodoro).
    await refreshScheduleMode();

    // Cancel-then-(re)schedule: every id is unique, so re-scheduling a reminder
    // always means "replace". Only the PLUGIN side needs an explicit cancel
    // here — the native path arms with a PendingIntent keyed by the same id, so
    // setAlarmClock replaces whatever that id held (an extra native cancel per
    // id was hundreds of binder calls per pass, and the batching pass would
    // then re-arm them all in one go anyway). Without the plugin purge a
    // leftover Flutter-plugin repeat scheduled by an older build (morning/
    // evening azkar, quran, friday, khatm, …) would keep firing next to the
    // native alarm — the same reminder delivered twice.
    await _notifications.cancel(id: id);

    final fireAt = _epochMillis(scheduledTime, timezone: timezone);
    if (fireAt <= DateTime.now().millisecondsSinceEpoch) {
      // Nothing will be armed for this id, so the native alarm has to be
      // removed explicitly — this is the one path where no replacement follows.
      await cancelNativeExactReminder(id);
      AppLogger.warning('NotificationService',
          'Skipped notification $id ($title): time already passed');
      return;
    }

    // Android: EVERY notification is armed natively with setAlarmClock — the
    // same Doze-immune, always-exact path the azan uses. The Flutter plugin is
    // no longer trusted for delivery timing, because OEM battery managers
    // (MIUI/HyperOS in particular) defer even setExactAndAllowWhileIdle from a
    // backgrounded or force-stopped app, which delayed reminders by hours.
    // ReminderReceiver posts each notification with the same id + channel the
    // plugin would have used. (Non-Android platforms keep the plugin path —
    // the only local-notification mechanism they have.)
    if (Platform.isAndroid) {
      await _scheduleNativeExactReminder(
        id: id,
        title: title,
        body: body,
        scheduledTime: scheduledTime,
        channelId: androidDetails.channelId,
        payload: payload,
        timezone: timezone,
        matchDateTimeComponents: matchDateTimeComponents,
        soundOverride: nativeSound,
      );
      // The native setAlarmClock arm above stays the PRIMARY delivery path: it
      // is exact and Doze-immune whenever SCHEDULE_EXACT_ALARM is granted. That
      // grant, however, is denied by default from Android 14 for newly installed
      // apps, and the native arm fails silently without it — while this early
      // return meant nothing was ever scheduled, so the reminder never arrived
      // at all (not even late). Only in that degraded state, also arm the plugin
      // with its inexact idle-safe mode: a late reminder beats a missing one.
      if (_scheduleMode != AndroidScheduleMode.exactAllowWhileIdle) {
        await _scheduleWithPlugin(
          id: id,
          title: title,
          body: body,
          scheduledTime: scheduledTime,
          androidDetails: androidDetails,
          matchDateTimeComponents: matchDateTimeComponents,
          payload: payload,
          timezone: timezone,
        );
      }
      return;
    }

    await _scheduleWithPlugin(
      id: id,
      title: title,
      body: body,
      scheduledTime: scheduledTime,
      androidDetails: androidDetails,
      matchDateTimeComponents: matchDateTimeComponents,
      payload: payload,
      timezone: timezone,
    );
  }

  /// Plugin (`zonedSchedule`) delivery path. Used on non-Android platforms and
  /// as the degraded Android fallback when SCHEDULE_EXACT_ALARM is not granted
  /// (see [_scheduleNotification]).
  Future<void> _scheduleWithPlugin({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required AndroidNotificationDetails androidDetails,
    DateTimeComponents? matchDateTimeComponents,
    String? payload,
    String? timezone,
  }) async {
    try {
      await _notifications.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: _asLocalTzDateTime(scheduledTime, timezone: timezone),
        notificationDetails: NotificationDetails(android: androidDetails),
        androidScheduleMode: _scheduleMode,
        matchDateTimeComponents: matchDateTimeComponents,
        payload: payload ?? 'prayer_id_$id',
      );
    } catch (e, st) {
      // One failed schedule must never abort the rest of a scheduling batch.
      AppLogger.error(
          'NotificationService', 'Failed to schedule $id ($title): $e', st);
    }
  }

  /// Doze-immune native exact alarm for EVERY reminder on Android. Arms a
  /// setAlarmClock (falling back to setExactAndAllowWhileIdle only if that
  /// throws) via [ReminderReceiver], which posts the notification on the same
  /// channel the Flutter plugin would have used. This is the exact same
  /// mechanism the azan audio uses, so reminders can never be Doze-deferred.
  ///
  /// Inside a [batchNativeReminders] pass this only queues the op; Kotlin
  /// decides whether the alarm actually needs arming at all.
  Future<void> _scheduleNativeExactReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required String channelId,
    String? payload,
    String? timezone,
    DateTimeComponents? matchDateTimeComponents,
    // The reminder's own sound when it differs from the channel default
    // (today: only `custom:…` file sounds). Without this the native alarm
    // always played the channel's fixed sound and a picked file never
    // sounded — the reported "custom file ignored" bug.
    String? soundOverride,
  }) async {
    try {
      await _enqueueNativeOp({
        'type': 'arm',
        'id': id,
        'timeMillis': _epochMillis(scheduledTime, timezone: timezone),
        'title': title,
        'body': body,
        'channelId': channelId,
        'sound': soundOverride ?? _nativeSoundForChannel(channelId),
        'payload': payload ?? '',
        'repeatDailyMillis': _nativeRepeatMillis(matchDateTimeComponents),
      });
    } catch (e, st) {
      AppLogger.error('NotificationService',
          'Failed to arm native exact reminder $id ($title): $e', st);
    }
  }

  /// Absolute fire time (ms since epoch). When no schedule timezone is given
  /// the fire instant is built from the DEVICE wall clock and its fields are
  /// interpreted in the device's own zone — so timing never depends on tz.local
  /// being aligned (the root cause of reminders landing hours off, e.g. 07:00
  /// firing at 10:30 when tz.local pointed at UTC). For the prayer-location
  /// case [timezone] overrides the wall-clock interpretation instead.
  int _epochMillis(DateTime time, {String? timezone}) {
    if (timezone == null || timezone.isEmpty) {
      return wallClockTime(time).millisecondsSinceEpoch;
    }
    return _asLocalTzDateTime(time, timezone: timezone).millisecondsSinceEpoch;
  }

  /// Maps a Flutter match component to a native repeat interval in ms. Only
  /// time-of-day (daily) and day-of-week (weekly) repeats are re-armed natively;
  /// date-specific one-off reminders are not repeated.
  int? _nativeRepeatMillis(DateTimeComponents? components) {
    switch (components) {
      case DateTimeComponents.time:
        return const Duration(days: 1).inMilliseconds;
      case DateTimeComponents.dayOfWeekAndTime:
        return const Duration(days: 7).inMilliseconds;
      default:
        return null;
    }
  }

  /// Best-effort cancel of a native exact-reminder watchdog (if any was armed).
  /// Queued when a [batchNativeReminders] pass is open, and ordered there
  /// against the arms of the same pass — Kotlin runs the batch FIFO on one
  /// worker thread, so a cancel can never overtake the arm before it.
  Future<void> cancelNativeExactReminder(int id) async {
    try {
      await _enqueueNativeOp({'type': 'cancel', 'id': id});
    } catch (e) {
      // Best effort — the Flutter-side cancel already ran.
      AppLogger.warning('NotificationService', 'native cancel failed: $e');
    }
  }

  /// Public entry point for scheduling a time-sensitive reminder with guaranteed
  /// on-time delivery. External callers (personal reminders, tasks, pomodoro)
  /// use this instead of calling the plugin directly, so every reminder gets the
  /// exact-alarm treatment instead of silently degrading to an inexact,
  /// Doze-delayed alarm when SCHEDULE_EXACT_ALARM is not granted.
  Future<void> scheduleExactReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required AndroidNotificationDetails details,
    DateTimeComponents? matchDateTimeComponents,
    String? payload,
    String? timezone,
    // The reminder's own sound name (e.g. `custom:/…`), forwarded to the
    // native exact alarm. The channel id alone cannot carry it: channels map
    // to one fixed raw sound, and a file path is not a channel sound at all.
    String? nativeSound,
  }) {
    return _scheduleNotification(
      id,
      title,
      body,
      scheduledTime,
      details,
      matchDateTimeComponents: matchDateTimeComponents,
      payload: payload,
      timezone: timezone,
      nativeSound: nativeSound,
    );
  }

  /// Maps a Flutter notification-channel id to the raw sound resource used on
  /// the native path, mirroring the Dart channel definitions.
  String? _nativeSoundForChannel(String channelId) {
    switch (channelId) {
      case 'custom_reminders_v2':
        return 'ios17';
      case 'prayer_times_v5':
        return 'silent';
      case 'azkar_reminder_v3':
      case 'islamic_events_v3':
      case 'daily_reminders_v3':
      case 'quran_reminder_v3':
      case 'khatm_reminder_v3':
      case 'friday_reminder_v3':
      case 'friday_kahf_v1':
      case 'fasting_reminder_v1':
        return 'notif';
      default:
        return null;
    }
  }

  tz.TZDateTime _asLocalTzDateTime(DateTime time, {String? timezone}) {
    final wallTime = wallClockTime(time);
    final location = _locationForScheduling(timezone);
    return tz.TZDateTime(
      location,
      wallTime.year,
      wallTime.month,
      wallTime.day,
      wallTime.hour,
      wallTime.minute,
      wallTime.second,
      wallTime.millisecond,
    );
  }

  tz.Location _locationForScheduling(String? timezone) {
    if (timezone == null || timezone.isEmpty) return tz.local;
    try {
      tzdata.initializeTimeZones();
      return tz.getLocation(timezone);
    } catch (_) {
      AppLogger.warning('NotificationService',
          'Unknown schedule timezone "$timezone"; using device timezone.');
      return tz.local;
    }
  }

  DateTime _wallNow(String? timezone) {
    final now = tz.TZDateTime.now(_locationForScheduling(timezone));
    return DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
      now.second,
      now.millisecond,
      now.microsecond,
    );
  }

  Future<void> cancelAll() async {
    await _notifications.cancelAll();
    try {
      await _exactReminders.invokeMethod('cancelAllReminders');
    } catch (e) {
      // Best effort — always succeeds on real devices where channels exist.
      AppLogger.warning('NotificationService', 'channel setup failed: $e');
    }
  }

  /// Cancels both the plugin notification and any armed native setAlarmClock
  /// watchdog for [id], so disabling a reminder really disables it.
  Future<void> _cancelBoth({required int id}) async {
    final plugin = _notifications;
    await plugin.cancel(id: id);
    await cancelNativeExactReminder(id);
  }

  /// Cancel a single notification by its [id], including any armed native
  /// exact-reminder watchdog for the same id.
  Future<void> cancel(int id) {
    return _cancelBoth(id: id);
  }

  /// Cancels every armed native reminder whose id falls in [startId, endId]
  /// (used to clear the whole daily-content window, whose per-day ids are not
  /// visible in the plugin's pending list once scheduling is native-only).
  Future<void> cancelNativeReminderRange(int startId, int endId) async {
    try {
      await _enqueueNativeOp({
        'type': 'cancelRange',
        'startId': startId,
        'endId': endId,
      });
    } catch (e) {
      // Best effort.
      AppLogger.warning('NotificationService', 'best-effort step failed: $e');
    }
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  /// Every native reminder currently armed on Android (from
  /// [ExactReminderScheduler.listReminders]), as displayed by the diagnostics
  /// page. Returns an empty list when the native channel is unavailable.
  /// Availability: Android-only; safe to call on all platforms.
  Future<List<NativeReminderInfo>> armedReminders() async {
    if (Platform.isAndroid) {
      try {
        final raw = await _exactReminders.invokeMethod<String>('listReminders');
        if (raw == null || raw.isEmpty) return const [];
        final decoded = jsonDecode(raw) as List<dynamic>;
        return decoded
            .map((e) => NativeReminderInfo.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));
      } catch (e) {
        AppLogger.warning('NotificationService', 'listReminders failed: $e');
        return const [];
      }
    }
    return const [];
  }

  /// Builds a clean notification body for daily content (آیه/حدیث) — the
  /// exact same format used in-app via [dailyContentBody].
  /// Test-visible alias for the shared formatter.
  @visibleForTesting
  static String debugDailyContentBody({
    required String text,
    required String ref,
    required String trans,
  }) =>
      dailyContentBody(text: text, ref: ref, trans: trans);
}

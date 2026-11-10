import 'dart:async';

import 'package:adhan/adhan.dart'
    show PrayerTimes, DateComponents, CalculationParameters, PrayerAdjustments;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/services/notification_service.dart';
import 'package:tawheeed/shared/services/native_prayer_alarm_service.dart';
import 'package:tawheeed/features/prayer/services/prayer_time_service.dart';
import 'package:tawheeed/features/prayer/services/prayer_azan_sound_store.dart';
import 'package:tawheeed/features/prayer/services/silent_mode_service.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/shared/models/day_time.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:tawheeed/features/prayer/presentation/providers/prayer_time_helpers.dart';
import 'package:tawheeed/features/settings/domain/repositories/settings_writer.dart';

class DailyNotificationScheduler {
  static final _instance = DailyNotificationScheduler._();
  factory DailyNotificationScheduler() => _instance;
  DailyNotificationScheduler._();

  SharedPreferences? _prefs;
  bool _ready = false;
  Future<void> _scheduleQueue = Future<void>.value();

  /// How long a request waits before the pass runs, so every emitter that fires
  /// around launch (main.dart, BootCoordinator, BackgroundScheduler, both
  /// settings notifiers) collapses into ONE rebuild instead of eight.
  ///
  /// A trailing window is deliberate: a leading-edge pass would run with the
  /// FIRST caller's settings, and a boot path that reads settings a moment
  /// later (an iqamah offset written by a restore, a city picked on the prayer
  /// page) would then be dropped — the queue would keep the stale times until
  /// the next date rollover. Waiting and keeping only the newest request is
  /// what makes the merge safe for prayer accuracy.
  static const Duration coalesceWindow = Duration(milliseconds: 1200);

  /// How often the "nothing changed" branch re-arms today's queue. See
  /// [_reconcileIsDue].
  static const Duration reconcileInterval = Duration(minutes: 2);
  static const String _reconciledAtKey = 'lastReconciledAtMillis';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _ready = true;
  }

  String get _storedFingerprint =>
      _prefs?.getString('lastScheduledFingerprint') ?? '';

  Future<void> _setStoredFingerprint(String value) async {
    await _prefs?.setString('lastScheduledFingerprint', value);
  }

  String _todayKey(String timezone) {
    final now = _nowIn(timezone);
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Every input that can change the scheduled notification set. Includes the
  /// calendar date so a full re-schedule happens at most once per day, plus all
  /// notification-affecting settings so any settings change is detected even by
  /// callers that use [scheduleIfNeeded] instead of [forceReschedule].
  String _scheduleFingerprint(AppSettings s) {
    final postDelay = _prefs?.getInt('notif_post_prayer_delay_minutes') ?? 10;
    // Prefs-backed inputs (kept out of AppSettings to avoid Drift schema
    // migrations). Missing any of these means a toggle/time change never
    // flips the fingerprint, so the queue silently keeps the old value until
    // an unrelated change forces a rebuild.
    final postPrayerOn =
        _prefs?.getBool(NotificationService.postPrayerEnabledKey) ?? true;
    final fridayOn =
        _prefs?.getBool(NotificationService.fridayEnabledKey) ?? true;
    final fridayHour = _prefs?.getInt(NotificationService.fridayHourKey) ??
        NotificationService.defaultFridayHour;
    final fridayMinute = _prefs?.getInt(NotificationService.fridayMinuteKey) ??
        NotificationService.defaultFridayMinute;
    final khatmOn =
        _prefs?.getBool(NotificationService.khatmEnabledKey) ?? false;
    final khatmHour = _prefs?.getInt(NotificationService.khatmHourKey) ??
        NotificationService.defaultKhatmHour;
    final khatmMinute = _prefs?.getInt(NotificationService.khatmMinuteKey) ??
        NotificationService.defaultKhatmMinute;
    final azkarMorningManual =
        _prefs?.getBool(NotificationService.azkarMorningManualKey) ?? false;
    final azkarEveningManual =
        _prefs?.getBool(NotificationService.azkarEveningManualKey) ?? false;
    final islamicEventsOn =
        // Literal (not the notifier's const) to avoid an import cycle with
        // notification_settings_notifier.dart. Must match its value.
        _prefs?.getBool('notif_islamic_events_enabled') ?? true;
    return [
      _todayKey(s.timezone),
      s.timezone,
      // Device zone: travel or a clock change must rebuild the whole queue,
      // otherwise wall-clock alarms keep firing at the old zone's hours.
      NotificationService.localTzName,
      s.calculationMethod.index,
      s.asrMethod.index,
      // Both change the computed prayer times, so a change must rebuild the
      // whole 8-day queue and the native alarms — otherwise days 2-7 keep the
      // pre-change times until the midnight rollover. (Phase-6 audit fix.)
      s.highLatitudeRule.index,
      s.elevationCorrection,
      s.useLocation,
      s.city,
      s.manualLat,
      s.manualLng,
      s.customFajrAngle,
      s.customIshaAngle,
      s.fajrOffset,
      s.sunriseOffset,
      s.dhuhrOffset,
      s.asrOffset,
      s.maghribOffset,
      s.ishaOffset,
      s.globalPrayerOffset,
      s.iqamahOffsetFajr,
      s.iqamahOffsetDhuhr,
      s.iqamahOffsetAsr,
      s.iqamahOffsetMaghrib,
      s.iqamahOffsetIsha,
      postDelay,
      s.prayerNotifications,
      s.prayerNotifMinutes,
      s.morningAzkarNotification,
      s.morningAzkarTime.hour,
      s.morningAzkarTime.minute,
      s.eveningAzkarNotification,
      s.eveningAzkarTime.hour,
      s.eveningAzkarTime.minute,
      s.quranReminder,
      s.quranReminderTime.hour,
      s.quranReminderTime.minute,
      s.silentDuringPrayer,
      s.silentDuration,
      s.silentBeforeIqamah,
      s.silentBeforeIqamahMinutes,
      s.dailyVerse,
      s.dailyVerseTime.hour,
      s.dailyVerseTime.minute,
      s.dailyHadith,
      s.dailyHadithTime.hour,
      s.dailyHadithTime.minute,
      s.dailyDua,
      s.dailyDuaTime.hour,
      s.dailyDuaTime.minute,
      s.dailyWordEnabled,
      s.dailyWordHour,
      s.dailyWordMinute,
      s.azanSound,
      s.customAzanPath,
      s.azanVolume,
      // Per-prayer voice overrides (prefs-backed, see PrayerAzanSoundStore):
      // an absent key inherits the shared azanSound above, and the literal ''
      // keeps that distinct from an explicit pick in the fingerprint.
      _prefs?.getString(PrayerAzanSoundStore.keyFor(PrayerSlot.fajr)) ?? '',
      _prefs?.getString(PrayerAzanSoundStore.keyFor(PrayerSlot.dhuhr)) ?? '',
      _prefs?.getString(PrayerAzanSoundStore.keyFor(PrayerSlot.asr)) ?? '',
      _prefs?.getString(PrayerAzanSoundStore.keyFor(PrayerSlot.maghrib)) ?? '',
      _prefs?.getString(PrayerAzanSoundStore.keyFor(PrayerSlot.isha)) ?? '',
      s.azanEnabledForFajr,
      s.azanEnabledForDhuhr,
      s.azanEnabledForAsr,
      s.azanEnabledForMaghrib,
      s.azanEnabledForIsha,
      s.hijriOffset,
      // Friday-only Dhuhr override: `null` (auto) and an explicit time must
      // produce different fingerprints, otherwise changing it leaves the
      // already-enqueued alarm holding the old value.
      s.fridayPrayerTime?.hour ?? -1,
      s.fridayPrayerTime?.minute ?? -1,
      postPrayerOn,
      fridayOn,
      fridayHour,
      fridayMinute,
      khatmOn,
      khatmHour,
      khatmMinute,
      azkarMorningManual,
      azkarEveningManual,
      islamicEventsOn,
    ].join('|');
  }

  bool needsRescheduling(AppSettings settings) {
    if (!_ready || _prefs == null) return true;
    return _storedFingerprint != _scheduleFingerprint(settings);
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _scheduleQueue.then<void>(
      (_) => action(),
      onError: (Object _, StackTrace __) => action(),
    );
    _scheduleQueue = next.catchError((_) {});
    return next;
  }

  /// The newest request waiting for its coalesced pass, and the callers whose
  /// futures complete when that single pass runs.
  PrayerTimeService? _pendingService;
  AppSettings? _pendingSettings;
  bool _pendingForce = false;
  final List<Completer<void>> _pendingWaiters = [];
  Timer? _coalesceTimer;

  Future<void> scheduleIfNeeded({
    required PrayerTimeService prayerService,
    required AppSettings settings,
  }) =>
      _request(
        prayerService: prayerService,
        settings: settings,
        force: false,
      );

  /// Collects requests for [coalesceWindow] and runs one pass for all of them.
  ///
  /// Every caller keeps its own future, and an error in the shared pass reaches
  /// all of them — the same contract the old per-call [_enqueue] had, so the
  /// call sites' existing `catchError`/try-catch still describe what happens.
  Future<void> _request({
    required PrayerTimeService prayerService,
    required AppSettings settings,
    required bool force,
  }) {
    _pendingService = prayerService;
    _pendingSettings = settings;
    _pendingForce = _pendingForce || force;
    final waiter = Completer<void>();
    _pendingWaiters.add(waiter);
    _coalesceTimer?.cancel();
    if (force) {
      // An explicit reschedule (a settings write, a restore, «بازنشانی») must
      // not wait behind the window — the user is looking at the change.
      _coalesceTimer = null;
      unawaited(_runPendingPass());
    } else {
      _coalesceTimer = Timer(coalesceWindow, () {
        _coalesceTimer = null;
        unawaited(_runPendingPass());
      });
    }
    return waiter.future;
  }

  Future<void> _runPendingPass() async {
    final prayerService = _pendingService;
    final settings = _pendingSettings;
    final force = _pendingForce;
    _pendingService = null;
    _pendingSettings = null;
    _pendingForce = false;
    final waiters = List<Completer<void>>.of(_pendingWaiters);
    _pendingWaiters.clear();
    if (prayerService == null || settings == null) return;
    final pass = _enqueue(
        () => _pass(prayerService: prayerService, settings: settings, force: force));
    for (final w in waiters) {
      pass.then(
        (_) {
          if (!w.isCompleted) w.complete();
        },
        onError: (Object e, StackTrace st) {
          if (!w.isCompleted) w.completeError(e, st);
        },
      );
    }
  }

  Future<void> _pass({
    required PrayerTimeService prayerService,
    required AppSettings settings,
    required bool force,
  }) async {
    final testPass = passOverride;
    if (testPass != null) {
      await testPass(prayerService, settings, force);
      return;
    }
    if (!_ready) await init();
    if (force) await _setStoredFingerprint('');
    // One round trip for the whole queue instead of one per reminder: the
    // native ops are collected here and applied by Kotlin on a worker thread.
    await NotificationService().batchNativeReminders(
      () => _scheduleIfNeeded(prayerService: prayerService, settings: settings),
    );
  }

  /// Test seam for the coalescing behaviour — the real pass body needs
  /// AlarmManager and SharedPreferences, so only this indirection can be
  /// observed on the fake clock. Production never sets it.
  @visibleForTesting
  Future<void> Function(PrayerTimeService, AppSettings, bool)? passOverride;

  /// Test seam: forget anything queued, so one test cannot leak a pending
  /// coalesce timer — or a half-driven serialiser — into the next one.
  ///
  /// The queue itself must be re-seeded too: its tail future was registered in
  /// the PREVIOUS test's fake-async zone, so a pass chained onto it there is
  /// never flushed by this test's `pump`, and the request silently stalls.
  /// For the same reason this must be called from INSIDE a test body — a
  /// `setUp` runs outside the binding's zone and seeds a tail that zone never
  /// flushes.
  @visibleForTesting
  void resetCoalescingForTest() {
    _coalesceTimer?.cancel();
    _coalesceTimer = null;
    for (final w in _pendingWaiters) {
      if (!w.isCompleted) w.complete();
    }
    _pendingWaiters.clear();
    _pendingService = null;
    _pendingSettings = null;
    _pendingForce = false;
    _scheduleQueue = Future<void>.value();
    passOverride = null;
  }

  Future<void> _scheduleIfNeeded({
    required PrayerTimeService prayerService,
    required AppSettings settings,
  }) async {
    if (!_ready) await init();

    // The exact-alarm grant can be revoked at any time in system settings.
    // Re-query before every batch: scheduling exact while revoked throws on
    // Android 12+, and scheduling inexact while granted invites Doze delays.
    await NotificationService().refreshScheduleMode();

    // Avoid battery/CPU churn: the expensive full re-schedule (5 prayers +
    // post-prayer azkar, morning/evening azkar, native setAlarmClock alarms,
    // tomorrow/day-after windows, silent-mode) only runs when the calendar
    // date, timezone or any notification-affecting setting actually changed.
    // But several time-sensitive reminders — daily آیه/حدیث/دعا/قرآن window,
    // adhkar, and today's prayer/post-prayer/pre-adhan queue — must be
    // reconciled on every boot/resume/hourly/background call so a settings
    // change takes effect immediately and the 7-day daily-content window never
    // silently expires. Android may also remove scheduled notifications, and an
    // app-open previously appeared to "repair" the missing reminder.
    final scheduleChanged = needsRescheduling(settings);

    // The daily آیه/حدیث/دعا/قرآن window only slides forward when it is
    // re-scheduled, and an iqamah / pre-prayer-minutes / azan change must take
    // effect immediately — not just when the daily fingerprint next changes.
    // On the short-circuit path we therefore reconcile these time-sensitive
    // reminders on every boot/resume/hourly check too, instead of leaving them
    // untouched and letting the 7-day window silently expire.
    if (!scheduleChanged) {
      // What this branch really repairs is a queue Android dropped, because a
      // settings change can never reach it — every notification-affecting
      // input is inside the fingerprint, so any change falls through to the
      // full rebuild below instead. That repair does not need one pass per boot emitter: the same
      // ids re-armed seconds apart is only UI-thread work. Skipping it is safe
      // for accuracy too — the calendar date is inside the fingerprint, so the
      // first pass of every day always rebuilds the 7-day window and today's
      // prayer queue no matter what this stamp says.
      final fp = _scheduleFingerprint(settings);
      if (!_reconcileIsDue(fp)) {
        AppLogger.debug('DailyScheduler',
            'reconcile skipped: the queue was re-armed less than '
            '${reconcileInterval.inSeconds}s ago for the same settings');
        return;
      }
      await NotificationService().scheduleDailyRemindersFromSettings(settings);
      await NotificationService().scheduleAzkarReminders(
        settings: settings,
        todayTimes: prayerService.prayerTimes,
        tomorrowTimes: _getTimesForDay(prayerService,
            _nowIn(settings.timezone).add(const Duration(days: 1)),
            timezone: settings.timezone,
            fridayPrayerTime: settings.fridayPrayerTime),
        dayAfterTimes: _getTimesForDay(prayerService,
            _nowIn(settings.timezone).add(const Duration(days: 2)),
            timezone: settings.timezone,
            fridayPrayerTime: settings.fridayPrayerTime),
      );
      // Rebuild today's prayer + post-prayer + pre-adhan reminders: Android can
      // drop a scheduled notification, and this is what puts it back. (A real
      // iqamah/pre-prayer-minutes/azan change never lands here — it flips the
      // fingerprint and is rebuilt by the full path.)
      final today = prayerService.prayerTimes;
      if (today != null) {
        if (settings.prayerNotifications) {
          await NotificationService()
              .schedulePrayerNotifications(today, settings: settings);
        } else {
          await NotificationService().cancelAllPrayerRelated();
        }
        // Post-prayer adhkar has its own toggle — rebuild it here too so a
        // delay/iqamah change applies without waiting for a fingerprint flip.
        if (await NotificationService().postPrayerEnabled()) {
          await NotificationService()
              .schedulePostPrayerNotifications(today, settings: settings);
        }
      }
      await _markReconciled(fp);
      return;
    }

    // Daily آیه/حدیث/دعای روز + یادآوری قرآن are fixed-time reminders that
    // repeat daily via matchDateTimeComponents.time. They fire even when prayer
    // notifications are disabled or prayer times fail to load (they don't
    // depend on coordinates).
    await NotificationService().scheduleDailyRemindersFromSettings(settings);

    if (prayerService.prayerTimes == null) {
      await prayerService.loadPrayerTimes(settings: settings);
    }

    final todayTimes = prayerService.prayerTimes;
    final tomorrowTimes = _getTimesForDay(
      prayerService,
      _nowIn(settings.timezone).add(const Duration(days: 1)),
      timezone: settings.timezone,
      fridayPrayerTime: settings.fridayPrayerTime,
    );
    final dayAfterTimes = _getTimesForDay(
      prayerService,
      _nowIn(settings.timezone).add(const Duration(days: 2)),
      timezone: settings.timezone,
      fridayPrayerTime: settings.fridayPrayerTime,
    );

    // Morning/evening azkar have their own toggles and are independent of the
    // prayer-reminder toggle. Times follow the prayer schedule when available:
    // morning azkar = Fajr + 45 min, evening azkar = Asr + 60 min; falls back
    // to the user's fixed wall-clock times when prayer times are unavailable.
    await NotificationService().scheduleAzkarReminders(
      settings: settings,
      todayTimes: todayTimes,
      tomorrowTimes: tomorrowTimes,
      dayAfterTimes: dayAfterTimes,
    );

    if (todayTimes == null) {
      // Prayer times may be unavailable while location is being resolved. The
      // repeating daily azkar (armed with fixed wall-clock times by
      // scheduleAzkarReminders) keep covering the offline window. Never leave
      // an old prayer/adhan queue behind when reminders were disabled or
      // native alarms are no longer enabled.
      // Without fresh prayer times the existing prayer queue cannot be
      // trusted. Remove it rather than letting stale times fire later; the
      // next successful refresh will rebuild it.
      await NotificationService().cancelPrayerNotifications();
      await NotificationService().cancelExtendedDayNotifications();
      await NativePrayerAlarmService().cancelAll();
      // Do not record a successful fingerprint: a later prayer-times refresh
      // must retry the prayer queue without waiting for a settings/date change.
      return;
    }

    // Always cancel & reschedule TODAY's prayer notifications to ensure:
    // 1. No stale notifications for past prayers (Android Doze delay can fire
    //    azan long after the actual prayer time when the user next opens the app).
    // 2. Current azan on/off settings are always reflected (toggling azan for
    //    a specific prayer used to require a day change to take effect).
    // 3. The user's prayerNotifications toggle is respected.
    if (settings.prayerNotifications) {
      await NotificationService()
          .schedulePrayerNotifications(todayTimes, settings: settings);
    } else {
      // If prayer notifications are disabled, cancel any existing scheduled
      // prayers — the whole queue including extended days and native alarms,
      // so nothing stale can survive. Post-prayer adhkar is preserved here
      // and rebuilt below under its own toggle.
      await NotificationService().cancelAllPrayerRelated();
    }

    // Post-prayer adhkar is independent of the prayer-reminder toggle.
    if (await NotificationService().postPrayerEnabled()) {
      await NotificationService()
          .schedulePostPrayerNotifications(todayTimes, settings: settings);
    } else {
      await NotificationService().cancelPostPrayerNotifications();
    }

    // Native setAlarmClock() alarms carry the actual azan sound and are gated
    // ONLY by the per-prayer azan toggles — independent of the reminder toggle.
    // The audible azan must sound when the user enables it even if prayer
    // reminder notifications are off (previously azan silently depended on
    // prayerNotifications, so flipping an azan switch appeared to do nothing).
    // On Samsung devices, setAlarmClock() bypasses all Doze/battery
    // restrictions and is guaranteed to fire in the background.
    if (settings.anyAzanEnabled) {
      try {
        await NativePrayerAlarmService()
            .scheduleAll(_nowIn(settings.timezone), todayTimes, settings);
      } catch (e) {
        AppLogger.warning(
            'DailyNotificationScheduler', 'Native alarm scheduling failed: $e');
      }
    } else {
      try {
        await NativePrayerAlarmService().cancelAll();
      } catch (e) {
        AppLogger.warning(
            'DailyNotificationScheduler', 'Native alarm cancel failed: $e');
      }
    }

    // Tomorrow's notifications and silent mode: we only reach this point when
    // the daily fingerprint changed (date rollover, timezone, or settings), so
    // tomorrow and day-after windows always get refreshed here. The prayer
    // queue is gated by the reminder toggle, but post-prayer adhkar has its
    // own toggle and must be rebuilt even when prayer reminders are off.
    final postPrayerOn = await NotificationService().postPrayerEnabled();
    if (settings.prayerNotifications || postPrayerOn) {
      if (tomorrowTimes != null) {
        await NotificationService().scheduleTomorrowNotifications(
          tomorrowTimes,
          settings: settings,
          includePrayer: settings.prayerNotifications,
        );
      } else {
        await NotificationService().cancelTomorrowNotifications();
      }

      // Extend the window one more day so notifications keep firing even if the
      // app is not opened for two days and native background scheduling is deferred.
      if (dayAfterTimes != null) {
        await NotificationService().scheduleDayAfterTomorrowNotifications(
          dayAfterTimes,
          settings: settings,
          includePrayer: settings.prayerNotifications,
        );
      } else {
        await NotificationService().cancelDayAfterTomorrowNotifications();
      }
    }

    // Always reconcile the extended window too; otherwise turning prayer
    // reminders off leaves days 3–7 queued in Android. Post-prayer adhkar has
    // its own toggle and is rebuilt here even when prayer reminders are off.
    // Morning/evening azkar need no extended windows: they are repeating
    // daily alarms that cover every day on their own.
    if (settings.prayerNotifications || postPrayerOn) {
      // Extend coverage to a full week. This is important when the app is not
      // opened for several days: the three-day window alone expires silently.
      for (var dayOffset = 3; dayOffset <= 7; dayOffset++) {
        final day = _nowIn(settings.timezone).add(Duration(days: dayOffset));
        final times = _getTimesForDay(
          prayerService,
          day,
          timezone: settings.timezone,
          fridayPrayerTime: settings.fridayPrayerTime,
        );
        if (times == null) {
          await NotificationService()
              .cancelExtendedDayNotifications(dayOffset: dayOffset);
          continue;
        }
        await NotificationService().scheduleExtendedDayNotifications(
          dayOffset: dayOffset,
          times: times,
          settings: settings,
          includePrayer: settings.prayerNotifications,
        );
      }
    } else {
      // A single call covers every extended day; computing the day's prayer
      // times here (as an earlier draft did) only fed a branch that could
      // never schedule anything — the toggle is already off.
      await NotificationService().cancelExtendedDayNotifications();
    }

    // کتم صوت: فقط در صورت منح إذن "عدم الإزعاج" (DND)؛ وإلا فلن يعمل الكتم
    // والاعتماد عليه صامتاً يُضعف الثقة. نتخطّاه مع تسجيل تحذير.
    final silentService = SilentModeService.instance;
    // Always clear previously scheduled silent timers/native alarms first, so
    // toggling «بی‌صدا» off or changing its minutes truly cancels stale windows
    // instead of leaving the device muted at an old time.
    silentService.cancelScheduled();
    final dndGranted = await silentService.isDndAccessGranted();
    if (dndGranted) {
      if (settings.silentBeforeIqamah) {
        await _scheduleSilentForPrayers(todayTimes, settings);
      }
      if (settings.silentDuringPrayer) {
        _scheduleSilentDuringPrayer(todayTimes, settings.silentDuration);
      }
    } else {
      AppLogger.warning('DailyNotificationScheduler',
          'Silent mode skipped: DND access not granted.');
    }

    final fp = _scheduleFingerprint(settings);
    await _setStoredFingerprint(fp);
    // A full rebuild re-arms everything the short-circuit branch would, so it
    // owns the reconcile stamp too — otherwise the passes that follow a date
    // rollover or a settings write would each redo the whole queue.
    await _markReconciled(fp);
  }

  /// True when the short-circuit branch may re-arm the queue again: never for a
  /// different fingerprint, and at most once per [reconcileInterval]. A stamp in
  /// the future (the clock moved, a restored backup) counts as due, so a bad
  /// stamp can never lock the repair path out.
  bool _reconcileIsDue(String fingerprint) => reconcileDueFromStamp(
        _prefs?.getString(_reconciledAtKey) ?? '',
        fingerprint,
        DateTime.now().millisecondsSinceEpoch,
      );

  /// Pure half of [_reconcileIsDue]: the same stamp may be re-armed at most once
  /// per [reconcileInterval]. Split out (and public only for tests) because the
  /// rule is what protects the repair path, and it must be checkable without
  /// SharedPreferences.
  @visibleForTesting
  static bool reconcileDueFromStamp(
    String stamp,
    String fingerprint,
    int nowMillis,
  ) {
    final sep = stamp.indexOf('|');
    if (sep <= 0) return true;
    if (stamp.substring(sep + 1) != fingerprint) return true;
    final last = int.tryParse(stamp.substring(0, sep)) ?? 0;
    if (last <= 0) return true;
    final age = nowMillis - last;
    return age < 0 || age >= reconcileInterval.inMilliseconds;
  }

  Future<void> _markReconciled(String fingerprint) async {
    await _prefs?.setString(_reconciledAtKey,
        '${DateTime.now().millisecondsSinceEpoch}|$fingerprint');
  }

  PrayerTimes? _getTimesForDay(
    PrayerTimeService service,
    DateTime day, {
    required String timezone,
    DayTime? fridayPrayerTime,
  }) {
    if (service.prayerTimes == null) return null;
    final coords = service.coordinates;
    if (coords == null) return null;
    // effectiveParams, not calculationParams: when the horizon-dip correction
    // is on, the raw method parameters do not contain it, and the azan would
    // ring at the uncorrected sunrise/maghrib while the screen shows the
    // corrected one.
    final params = service.effectiveParams;
    if (params == null) return null;

    // [day] is wall time in [timezone]. Resolve the offset for that specific
    // calendar date rather than using today's offset; otherwise a DST change
    // shifts future prayer and reminder notifications by one hour.
    final components = DateComponents(day.year, day.month, day.day);
    final offset = _zoneOffset(timezone, day);
    final base = PrayerTimes(coords, components, params, utcOffset: offset);

    if (fridayPrayerTime == null || day.weekday != DateTime.friday) {
      return base;
    }

    // وقت نماز جمعه در روزهای جمعه از تنظیمات جایگزین وقت محاسبه‌شدهٔ ظهر
    // می‌شود — همان منطقی که در `PrayerRepository._toDomain` اعمال می‌شود،
    // تا اعلان آذان جمعه هم با ساعت انتخابی کاربر هماهنگ باشد.
    //
    // adhan با `utcOffset` لحظه‌های مطلق برمی‌گرداند، پس ساعتِ دیواریِ
    // دلخواه در همان منطقهٔ زمانی ابتدا به لحظهٔ مطلق تبدیل می‌شود و
    // اختلافش با ظهرِ محاسبه‌شده به‌صورت offset اعمال می‌گردد.
    final desired = DateTime.utc(day.year, day.month, day.day,
            fridayPrayerTime.hour, fridayPrayerTime.minute)
        .subtract(offset);
    final deltaMinutes = desired.difference(base.dhuhr).inMinutes;
    if (deltaMinutes == 0) return base;

    return PrayerTimes(coords, components, _withDhuhrShift(params, deltaMinutes),
        utcOffset: offset);
  }

  /// نسخهٔ تازهٔ [src] با [minutes] دقیقه جابه‌جایی برای ظهر.
  ///
  /// [src] عمداً تغییر نمی‌کود (همان قاعده‌ای که `PrayerRepository` هم برای
  /// تصحیح ارتفاع رعایت می‌کند) تا پارامترهای مشترکِ نشست خراب نشوند.
  static CalculationParameters _withDhuhrShift(
    CalculationParameters src,
    int minutes,
  ) {
    final a = src.adjustments;
    return CalculationParameters(
      method: src.method,
      fajrAngle: src.fajrAngle,
      maghribAngle: src.maghribAngle,
      ishaAngle: src.ishaAngle,
      ishaInterval: src.ishaInterval,
      madhab: src.madhab,
      highLatitudeRule: src.highLatitudeRule,
      adjustments: PrayerAdjustments(
        fajr: a.fajr,
        sunrise: a.sunrise,
        dhuhr: a.dhuhr + minutes,
        asr: a.asr,
        maghrib: a.maghrib,
        isha: a.isha,
      ),
      methodAdjustments: src.methodAdjustments,
    );
  }

  /// UTC offset of [timezone] for [day]'s calendar date (DST-aware via the tz
  /// database, matching `PrayerRepository._resolveZone`). Noon-anchored: local
  /// midnight sits on the wrong side of a 02:00/03:00 DST transition, noon
  /// does not. Falls back to the device's numeric offset when the zone name is
  /// unknown — it is correct for today, unlike a hard-coded +3:30.
  Duration _zoneOffset(String timezone, DateTime day) {
    try {
      tzdata.initializeTimeZones();
      final loc = tz.getLocation(timezone);
      return tz.TZDateTime(loc, day.year, day.month, day.day, 12)
          .timeZoneOffset;
    } catch (e) {
      AppLogger.warning('DailyScheduler',
          'zone "$timezone" unknown, using the device offset: $e');
      return DateTime.now().timeZoneOffset;
    }
  }

  /// Current wall time in [timezone].
  DateTime _nowIn(String timezone) {
    try {
      tzdata.initializeTimeZones();
      final loc = tz.getLocation(timezone);
      return tz.TZDateTime.now(loc);
    } catch (e) {
      AppLogger.warning('DailyScheduler',
          'zone "$timezone" unknown, using device wall time: $e');
      return DateTime.now();
    }
  }

  Future<void> forceReschedule({
    required PrayerTimeService prayerService,
    required AppSettings settings,
    SettingsWriter? writer,
  }) =>
      _request(
        prayerService: prayerService,
        settings: settings,
        force: true,
      );

  /// Native silent-window slot per prayer. Each prayer gets its own request-code
  /// pair in PrayerAlarmScheduler so one prayer's window can never overwrite
  /// another's (which made only the last prayer silent)
  /// while the app was closed.
  static const Map<String, int> silentSlots = {
    'fajr': 0,
    'dhuhr': 1,
    'asr': 2,
    'maghrib': 3,
    'isha': 4,
  };

  int _silentSlotFor(String prayer) => silentSlots[prayer] ?? 0;

  Future<void> _scheduleSilentForPrayers(
      PrayerTimes times, AppSettings settings) async {
    final now = _nowIn(settings.timezone);
    final silentService = SilentModeService.instance;
    final afterMinutes = await silentService.afterIqamahMinutes();

    final prayers = {
      'fajr': (times.fajr, settings.iqamahOffsetFajr),
      'dhuhr': (times.dhuhr, settings.iqamahOffsetDhuhr),
      'asr': (times.asr, settings.iqamahOffsetAsr),
      'maghrib': (times.maghrib, settings.iqamahOffsetMaghrib),
      'isha': (times.isha, settings.iqamahOffsetIsha),
    };

    for (final entry in prayers.entries) {
      final (rawTime, offset) = entry.value;
      final time = wallClockTime(rawTime);
      if (time.isAfter(now)) {
        silentService.scheduleSilent(
          iqamahTime: time.add(Duration(minutes: offset)),
          minutesBefore: settings.silentBeforeIqamahMinutes,
          afterMinutes: afterMinutes,
          utcOffset: times.utcOffset,
          // Distinct native slot per prayer: a single shared request-code pair
          // made every prayer overwrite the previous window, so only the last
          // scheduled prayer was muted while the app stayed closed.
          slot: _silentSlotFor(entry.key),
        );
      }
    }
  }

  void _scheduleSilentDuringPrayer(PrayerTimes times, int durationMinutes) {
    final now = DateTime.now();
    final silentService = SilentModeService.instance;

    final prayers = [
      ('fajr', times.fajr),
      ('dhuhr', times.dhuhr),
      ('asr', times.asr),
      ('maghrib', times.maghrib),
      ('isha', times.isha),
    ];

    for (final (name, rawTime) in prayers) {
      final time = wallClockTime(rawTime);
      if (time.isAfter(now)) {
        silentService.scheduleSilentDuringPrayer(
          prayerTime: time,
          durationMinutes: durationMinutes,
          utcOffset: times.utcOffset,
          slot: _silentSlotFor(name),
        );
      }
    }
  }
}

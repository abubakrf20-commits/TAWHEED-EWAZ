import 'package:tawheeed/shared/utils/date_key.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/features/settings/settings.dart';
import 'package:tawheeed/features/prayer/prayer.dart';
import 'package:tawheeed/features/worship/worship.dart';
// NOTE: reminderProvider (personal reminders) is re-exported through the
// worship barrel — no separate reminders import needed.
import 'package:tawheeed/features/adhkar/adhkar.dart';
import 'package:tawheeed/features/worship/presentation/providers/reading_streak_provider.dart';
import 'package:tawheeed/shared/services/daily_notification_scheduler.dart';
import 'package:tawheeed/shared/services/notification_service.dart';
import 'package:tawheeed/app/state/shell_nav.dart';
import 'package:tawheeed/app/state/pending_prayer.dart';
import 'package:tawheeed/shared/services/azan_service.dart';
import 'package:tawheeed/shared/services/widget_sync_service.dart';
import 'package:tawheeed/features/quran/services/mp3quran_service.dart';
import 'package:tawheeed/features/tools/moon/domain/services/hilal_notification_service.dart';
import 'package:tawheeed/shared/providers/service_providers.dart';
import 'package:tawheeed/features/settings/presentation/widgets/widget_design_tokens.dart';
import 'package:tawheeed/features/adhkar/tasbih/presentation/providers/tasbih_daily_reset.dart';
import 'package:tawheeed/app/router/app_router.dart';
import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/features/personal/presentation/providers/care_providers.dart';

class BootCoordinator {
  final WidgetRef ref;
  final AzanService azanService;
  final WidgetSyncService widgetSyncService;
  Timer? _maintenanceTimer;
  String? _lastMaintenanceDateKey;
  String _lastResumeDateKey;

  /// Device UTC offset (in minutes) at the last resume — detecting a change
  /// means the user travelled across timezone boundaries.
  int? _lastDeviceOffsetMinutes;

  BootCoordinator({
    required this.ref,
    AzanService? azanService,
    WidgetSyncService? widgetSyncService,
  })  : _lastResumeDateKey = dateKeyOf(DateTime.now()),
        azanService = azanService ?? AzanService(),
        widgetSyncService = widgetSyncService ?? WidgetSyncService();

  Future<void> run() async {
    // PHASE-1 FIX: consume a cold-start notification tap HERE instead of in
    // main() — by the time this post-frame callback runs, MainShell.initState
    // has already registered the static tap handlers (onPrayerTapped etc.),
    // so a prayer tap that cold-started the app actually navigates instead of
    // being dropped on a null handler (the khatm payload had a buffer; the
    // prayer one did not).
    await NotificationService().handleColdStartTap();

    // #152: these steps touch independent stores (asset cache, quick-action
    // prefs, widget-shortcut prefs, widget counters, azan prefs) — they used
    // to run as five serial round-trips after the first frame. The permission
    // prompt still waits for them, so the notification reconcile below sees
    // the final grant state.
    widgetSyncService.startAutoSync(ref);
    await Future.wait<void>([
      WidgetTokens.init(),
      migrateQuickActionsFromPrefs(ref),
      _consumeWidgetShortcut(),
      _reconcileTasbih(),
      azanService.loadAzanPlayedToday(),
    ]);
    await _requestPermissions();
    startMaintenanceTimer();
    // PHASE-1 FIX (boot tracks): disk/network-heavy upkeep is deferred off
    // the post-first-frame path so weak phones don't jank right after the
    // shell appears. Daily cadence is preserved (the maintenance timer re-runs
    // the same work), and each task is individually guarded.
    unawaited(Future<void>.delayed(const Duration(seconds: 10)).then((_) async {
      try {
        ref.read(backupServiceProvider).runDailyAutoBackup();
        // Deliberately NO Google session restore here: the plugin's
        // "lightweight" restore falls back to the interactive account sheet
        // (google_sign_in_android), so it popped on every cold start. The
        // Drive/cloud session is restored only from the explicit sign-in
        // button in the account hub.
      } catch (e) {
        AppLogger.warning(
            'BootCoordinator', 'Deferred backup stage failed: $e');
      }
    }));
    // Rebuild a possibly-cleared alarm queue (reboot/app-update/clock change)
    // and personal reminders — kept on the immediate track because a missed
    // reschedule here means missed notifications all day.
    _checkNotifications();
    // Personal tools («خودرو» / «خانه»): rebuild the 30-day reminder window on
    // every start, exactly like the other schedulers. Guarded so a broken row
    // can never block boot.
    _syncCareReminders();
    // Hilal alert re-booking: it is a one-shot alarm, so after a reboot /
    // cleared alarm queue it would silently die unless the user happened to
    // reopen the Moon screen. Re-arm it from persisted coords on every boot.
    unawaited(HilalNotificationService.instance
        .rescheduleFromPrefs()
        .catchError((Object e) {
      AppLogger.warning('BootCoordinator', 'hilal reschedule failed: $e');
    }));
    // Audit 9-E: the 7-day audio-cache sweep used to run only when talaawah
    // playback started, so users who never opened the reader kept every
    // ephemeral prefetch forever. Sweep once per boot (best-effort).
    unawaited(Mp3QuranService.cleanupExpiredCache().catchError((Object e) {
      AppLogger.warning('BootCoordinator', 'audio cache sweep failed: $e');
    }));
    // ختم قرآن/یادآورها: force the provider load so a reboot rebuilds them
    // even if the user never opens the reminders screen this session.
    try {
      await ref.read(reminderProvider.future);
    } catch (e) {
      AppLogger.warning('BootCoordinator', 'Reminder reschedule failed: $e');
    }
  }

  void onResume() {
    final now = DateTime.now();
    final currentDateKey = dateKeyOf(now);
    // Phase-6 audit fix: a device timezone change (travel) must invalidate the
    // prayer times so the repository recalculates with the new zone. Without
    // this the stale zone (and its wall-clock offset) persisted until some
    // other event refreshed the provider.
    final deviceOffset = now.timeZoneOffset.inMinutes;
    if (_lastDeviceOffsetMinutes != null &&
        _lastDeviceOffsetMinutes != deviceOffset) {
      ref.invalidate(prayerTimesProvider);
      // Audit 5.4: a timezone change also changes the widget's prayer
      // times — push a fresh snapshot immediately instead of waiting up
      // to 30 minutes for the periodic sync timer.
      unawaited(widgetSyncService.syncWidgetsNow(ref));
    }
    _lastDeviceOffsetMinutes = deviceOffset;
    if (currentDateKey != _lastResumeDateKey) {
      _lastResumeDateKey = currentDateKey;
      // keepAlive prayer times are only rebuilt on invalidate; without this the
      // app shows yesterday's adhan times after a resume that crosses midnight.
      ref.invalidate(prayerTimesProvider);
      ref.invalidate(evaluationProvider);
      ref.invalidate(notesProvider);
      ref.invalidate(prayerTrackerProvider);
      ref.invalidate(readingStreakProvider);
      // Reset the tasbih session counters (فرض روزانه) on a new day; the
      // evaluation tab watches tasbihProvider so this also refreshes it.
      ref.invalidate(tasbihProvider);
      ref.invalidate(azkarProvider);
      ref.invalidate(azkarVersionProvider);
    } else {
      // حتی در همان روز، برای جلوگیری از گیر کردن کش اذکار پس از بازگشت از بک‌گراند،
      // یک بار همگام‌سازی سبک انجام بده (بدون پاک کردن تیک‌های امروز)
      // این مشکل «بعد از مدتی تیک‌ها پرید» را که به‌دلیل invalidate نشدن بود حل می‌کند
      ref.invalidate(azkarVersionProvider);
    }
    azanService.checkAndPlayAzan(ref);
    // Fingerprint-guarded (NOT forced): the daily fingerprint already rebuilds
    // the queue once per calendar day, and BootReceiver/RolloverReceiver set the
    // native `needs_reschedule` flag (consumed inside _checkNotifications) for
    // boot / app-update / clock / timezone changes. Forcing here rebuilt the
    // whole 8-day queue (~100+ notifications, each with a cancel + arm +
    // capability round-trip) on EVERY app resume.
    _checkNotifications();
    _reconcileTasbih();
    widgetSyncService.syncWidgetsNow(ref);
    // Capture the grant state BEFORE the (possibly interactive) request so a
    // forced rebuild only happens on a real denied -> granted transition. When
    // the permission was already granted — the normal case — the guarded pass
    // above has just reconciled the queue, and forcing again rebuilt every
    // notification a second time on each resume.
    ref
        .read(permissionServiceProvider)
        .isExactAlarmGranted()
        .then((wasGranted) async {
      final granted = await ref
          .read(permissionServiceProvider)
          .ensureExactAlarmPermission();
      await NotificationService().refreshScheduleMode();
      if (granted && !wasGranted) {
        // The user just returned from the exact-alarm settings page; rebuild the
        // queue now that alarm delivery can be exact.
        _checkNotifications(force: true);
      }
    }).catchError((e) {
      AppLogger.warning('BootCoordinator', 'Exact-alarm refresh failed: $e');
    });
    ref.read(backupServiceProvider).runDailyAutoBackup();
    _consumeWidgetShortcut();
    // Restart the upkeep cycles that [onPause] stopped. `startAutoSync` runs a
    // sync immediately (its catch-up for the background gap), and
    // `startMaintenanceTimer` reopens the 15-minute window — so nothing that
    // used to happen every 15 min while backgrounded is missed, it just happens
    // on the way back instead of in the background.
    startMaintenanceTimer();
    widgetSyncService.startAutoSync(ref);
  }

  void onPrayerTapped(String prayerName) {
    // Publish through the provider so HomeTab picks it up even when it is
    // already built (IndexedStack does not rebuild on re-select).
    ref.read(pendingPrayerProvider).value = prayerName;
    ref.read(shellTabIndexProvider.notifier).setIndex(0);
  }

  /// Rebuilds the care reminder window from the stored rows.
  void _syncCareReminders() {
    unawaited(ref
        .read(careStoreProvider.future)
        .then((snapshot) =>
            ref.read(careRemindersProvider).sync(snapshot))
        .catchError((Object e) {
      AppLogger.warning('BootCoordinator', 'care reminder sync failed: $e');
    }));
  }

  /// Opens the exact personal tool when one of its reminders is tapped.
  /// Payload shapes: `care_car_task_<id>`, `care_home_bill_<id>`,
  /// `care_day_<date>` for a grouped summary.
  void onCareTapped(String payload) {
    try {
      final isHome = payload.startsWith('care_home_') ||
          payload.startsWith('care_day_');
      final taskId = RegExp(r'^care_car_task_(.+)$')
          .firstMatch(payload)
          ?.group(1);
      final base = isHome
          ? RouteNames.personalHomeCare
          : RouteNames.personalCar;
      final uri = taskId == null
          ? base
          : Uri(path: base, queryParameters: {'task': taskId}).toString();
      buildAppRouter().push(uri);
    } catch (e) {
      AppLogger.warning('BootCoordinator', 'care navigation failed: $e');
    }
  }

  void onPostPrayerAzkarTapped() {
    ref.read(shellTabIndexProvider.notifier).setIndex(2);
    ref.read(shellSubTabProvider.notifier).setIndex(1);
  }

  /// Opens the stage-3 tool a reminder came from.
  ///
  /// Payload shapes: `family_relative_<id>`, `family_relative_day_<date>`,
  /// `family_saving_<goalId>`. Every branch goes through
  /// the router so the vault route (and its PIN gate) is entered properly.
  void onFamilyTapped(String payload) {
    try {
      final uri = _familyUri(payload);
      if (uri == null) return;
      buildAppRouter().push(uri);
    } catch (e) {
      AppLogger.warning('BootCoordinator', 'family navigation failed: $e');
    }
  }

  String? _familyUri(String payload) {
    if (payload.startsWith('family_saving_')) {
      final id = payload.replaceFirst('family_saving_', '').trim();
      if (id.isEmpty) return RouteNames.personalSavings;
      return RouteNames.personalSavingsGoal(id);
    }
    if (payload.startsWith('family_relative_day_')) {
      return RouteNames.silatAlRahim;
    }
    if (payload.startsWith('family_relative_')) {
      final id = payload.replaceFirst('family_relative_', '').trim();
      return id.isEmpty
          ? RouteNames.silatAlRahim
          : Uri(
              path: RouteNames.silatAlRahim,
              queryParameters: {'relative': id},
            ).toString();
    }
    return null;
  }

  /// Opens the khatm (ختم قرآن) screen when the daily khatm reminder
  /// notification is tapped — through the router (not a raw Navigator push
  /// that escapes GoRouter's history accounting).
  void onKhatmTapped() {
    try {
      buildAppRouter().push(RouteNames.khatm);
    } catch (e) {
      AppLogger.warning('BootCoordinator', 'Khatm navigation failed: $e');
    }
  }

  /// Opens the Quran tab when the weekly Surah-Kahf reminder is tapped.
  /// Tab 1 is the mushaf reader (see `MainShell._buildTab`).
  void onQuranTapped() {
    ref.read(shellTabIndexProvider.notifier).setIndex(1);
  }

  /// Must be called from a context that supports showDialog.
  Future<void> showGpsPromptIfNeeded(BuildContext context) async {
    try {
      final useLocation = ref.read(settingsProvider).value?.useLocation ?? true;
      if (!useLocation) return;

      final prefs = await SharedPreferences.getInstance();
      final gpsEnabled =
          await ref.read(permissionServiceProvider).isGpsEnabled();
      // PHASE-1 FIX: also detect a denied location *permission* — GPS can be
      // on while the app is still blocked, which used to fall back silently
      // to default coordinates with no way for the user to notice.
      final locGranted =
          await ref.read(permissionServiceProvider).isLocationGranted();
      if (gpsEnabled && locGranted) return;

      // Two independent once-per-install prompts (kept separate so a granted
      // GPS doesn't swallow the permission prompt and vice versa).
      if (!gpsEnabled) {
        final shown = prefs.getBool('gps_prompt_shown') ?? false;
        if (shown) return;
        await prefs.setBool('gps_prompt_shown', true);
        if (!context.mounted) return;
        await _showLocationDialog(
          context,
          title: 'فعال کردن موقعیت مکانی',
          message:
              'برای محاسبه دقیق اوقات شرعی، لطفاً موقعیت مکانی (GPS) را در تنظیمات گوشی فعال کنید.',
          buttonLabel: 'فعال کردن',
          action: ref.read(permissionServiceProvider).openLocationSettings,
        );
      } else if (!locGranted) {
        final shown = prefs.getBool('loc_perm_prompt_shown') ?? false;
        if (shown) return;
        await prefs.setBool('loc_perm_prompt_shown', true);
        if (!context.mounted) return;
        await _showLocationDialog(
          context,
          title: 'دسترسی موقعیت مکانی',
          message:
              '«توحید» به دسترسی موقعیت نیاز دارد تا اوقات شرعی را دقیق محاسبه کند. از تنظیمات برنامه آن را مجاز کنید.',
          buttonLabel: 'تنظیمات برنامه',
          // Native side opens ACTION_APPLICATION_DETAILS_SETTINGS.
          action: ref.read(permissionServiceProvider).requestLocationPermission,
        );
      }
    } catch (e) {
      AppLogger.warning('BootCoordinator', 'GPS check failed: $e');
    }
  }

  Future<void> _showLocationDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String buttonLabel,
    required Future<void> Function() action,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.location_on_outlined,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(
          message,
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('بعداً'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await action();
            },
            icon: const Icon(Icons.settings, size: 16),
            label: Text(buttonLabel),
          ),
        ],
      ),
    );
  }

  Future<void> runDelayedResync() async {
    await Future.delayed(const Duration(seconds: 5));
    widgetSyncService.syncWidgetsNow(ref);
  }

  /// The 15-minute upkeep tick.
  ///
  /// Lifecycle-aware since the battery audit: it used to run for the whole
  /// lifetime of the process, which on Android is long past the moment the
  /// user leaves the app — ~96 wakeups a day doing daily-rollover work that
  /// `onResume()` already performs on the way back. `onPause()` cancels it and
  /// `onResume()` restarts it, exactly like `ClockTicker`, whose
  /// lifecycle-aware behaviour this file now shares.
  void startMaintenanceTimer() {
    _maintenanceTimer?.cancel();
    _maintenanceTimer = Timer.periodic(const Duration(minutes: 15), (_) async {
      try {
        final now = DateTime.now();
        final dateKey = dateKeyOf(now);
        if (_lastMaintenanceDateKey != dateKey) {
          _lastMaintenanceDateKey = dateKey;
          // An app left open across midnight never resumes, so refresh the
          // keepAlive prayer times here too — otherwise the countdown and
          // tracker keep using the previous day's adhan times.
          ref.invalidate(prayerTimesProvider);
          azanService.maybeResetDay();
          ref.invalidate(tasbihProvider);
          ref.invalidate(azkarProvider);
          ref.invalidate(azkarVersionProvider);
        } else if (await isTasbihDailyResetOverdue(now)) {
          // A custom (non-midnight) reset time has passed but the provider was
          // never re-run after it (the date-rollover triggers fired too early
          // and returned before the deadline) — re-run the daily reset now.
          ref.invalidate(tasbihProvider);
        }
        azanService.checkAndPlayAzan(ref);
        if (now.minute == 0) _checkNotifications();
      } catch (e) {
        AppLogger.warning('BootCoordinator', 'Maintenance tick error: $e');
      }
    });
  }

  /// Stops the periodic upkeep while the app is not in the foreground.
  /// Nothing is lost: [onResume] performs the same date-rollover checks the
  /// tick would have, and [startMaintenanceTimer] restarts it on the way back.
  void onPause() {
    _maintenanceTimer?.cancel();
    _maintenanceTimer = null;
    widgetSyncService.pauseAutoSync();
  }

  void dispose() {
    widgetSyncService.dispose();
    azanService.dispose();
    _maintenanceTimer?.cancel();
  }

  // ── Private ──

  Future<void> _consumeWidgetShortcut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final route = prefs.getString('widget_shortcut');
      if (route == null || route.isEmpty) return;
      await prefs.remove('widget_shortcut');

      switch (route) {
        case 'quran':
          ref.read(shellTabIndexProvider.notifier).setIndex(1);
        case 'tasbih':
        case 'azkar':
          ref.read(shellTabIndexProvider.notifier).setIndex(2);
        case 'prayer':
        default:
          ref.read(shellTabIndexProvider.notifier).setIndex(0);
      }
    } catch (e) {
      AppLogger.warning('BootCoordinator', 'Shortcut routing failed: $e');
    }
  }

  Future<void> _reconcileTasbih() async {
    // Shared with the widget-sync service so the same «last interaction
    // wins» reconciliation also runs on every snapshot sync (30-min timer,
    // state changes), not only at boot/resume.
    await widgetSyncService.reconcileTasbihFromWidget(ref);
  }

  Future<void> _requestPermissions() async {
    try {
      await ref.read(permissionServiceProvider).requestRuntimePermissions();
    } catch (e) {
      AppLogger.warning('BootCoordinator', 'Permission request failed: $e');
    }
  }

  Future<void> _checkNotifications({bool force = false}) async {
    final settings = ref.read(settingsProvider).value ?? const AppSettings();
    final prayerService = ref.read(prayerTimeServiceProvider);
    var reschedule = force;
    if (!reschedule) {
      // Native BootReceiver sets this after boot/update/clock/timezone
      // changes — honor it with a full rebuild even when the daily
      // fingerprint looks unchanged (e.g. same calendar date).
      // consumeNeedsReschedule handles its own errors and returns false —
      // this used to sit behind a dead try/catch that could never fire.
      reschedule =
          await ref.read(permissionServiceProvider).consumeNeedsReschedule();
    }
    final scheduling = reschedule
        ? DailyNotificationScheduler().forceReschedule(
            prayerService: prayerService,
            settings: settings,
          )
        : DailyNotificationScheduler().scheduleIfNeeded(
            prayerService: prayerService,
            settings: settings,
          );
    scheduling.catchError((e) {
      AppLogger.warning('BootCoordinator', 'Notification scheduling error: $e');
    });
    // ختم قرآن یادآوری مستقل از تنظیمات اوقات نماز است و از صفحه ختم مدیریت
    // می‌شود؛ در هر بوت همگام می‌شود تا بعد از نصب/بازنصب یا پاک شدن اعلان‌ها
    // زمان‌بندی آن از دست نرود.
    NotificationService().syncKhatmReminder().catchError((e) {
      AppLogger.warning('BootCoordinator', 'Khatm reminder sync error: $e');
    });
  }
}

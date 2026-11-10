import 'dart:async';

import 'dart:ui' show PlatformDispatcher;

import 'package:dorar_hadith_flutter/dorar_hadith_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kReleaseMode, visibleForTesting;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:tawheeed/features/prayer/prayer.dart';
import 'package:tawheeed/shared/services/firebase_core_init.dart';
import 'package:tawheeed/features/quran/data/quran_data.dart';
import 'package:tawheeed/features/settings/settings.dart';
import 'package:tawheeed/shared/services/daily_notification_scheduler.dart';
import 'package:tawheeed/shared/services/firebase_push_service.dart';
import 'package:tawheeed/shared/services/notification_service.dart';
import 'package:tawheeed/shared/services/background_scheduler.dart';
import 'package:tawheeed/app/router/app_router.dart';
import 'package:tawheeed/app/state/app_bootstrap.dart';
import 'package:tawheeed/app/state/clock_providers.dart';
import 'package:tawheeed/core/design_system/ambient_background.dart';
import 'package:tawheeed/core/error/error_boundary.dart';
import 'package:tawheeed/core/theme/app_text_scale.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/core/utils/startup_guard.dart';
import 'package:tawheeed/features/dorar_hadith/data/datasources/dorar_remote_datasource.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Sentry DSN is injected at build time via `--dart-define=SENTRY_DSN=...`
/// so it never lives in source control. When absent (local dev, tests), error
/// reporting is a no-op and the app still runs normally.
const String _sentryDsn = String.fromEnvironment('SENTRY_DSN');

bool get _sentryEnabled => _sentryDsn.isNotEmpty;

/// Cold-start stopwatch: every init phase logs its elapsed time so TTI
/// regressions are measurable from the on-device log (Phase-1 audit fix).
final Stopwatch _startup = Stopwatch();
bool _bootstrapped = false;

void _startupMark(String phase) =>
    AppLogger.info('Startup', '$phase: ${_startup.elapsedMilliseconds}ms');

/// Real app version for crash grouping (never a hardcoded string — releases
/// must map to the exact Play Store version+build). Read lazily by the
/// deferred Sentry pass, so the default is what a crash report carries if the
/// package-info channel never answered.
String _release = 'tawheeed@unknown';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _startup
    ..reset()
    ..start();

  // PHASE-1 FIX: global error handlers are installed FIRST — before any
  // awaited init. They used to be installed after Firebase/NotificationService
  // awaits, so any error thrown during those inits bypassed both handlers
  // (no Sentry capture, no AppLogger line, no crash report).

  // Platform-dispatched errors (platform channels, plugins) bypass
  // FlutterError.onError; mark them handled so a plugin hiccup (e.g. audio)
  // never tears the process down.
  PlatformDispatcher.instance.onError = (e, st) {
    if (_sentryEnabled) {
      Sentry.captureException(e, stackTrace: st);
    }
    AppLogger.error('PlatformDispatcherError', e, st);
    return true;
  };

  // Global error boundary — catch unhandled errors and log them.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (_sentryEnabled) {
      Sentry.captureException(details.exception, stackTrace: details.stack);
    }
    AppLogger.error('FlutterError', details.exception, details.stack);
  };

  // SPLASH REDESIGN: Sentry — and the PackageInfo channel call it needs for
  // its release tag — used to be awaited *before* runApp, which put a crash
  // reporter ahead of the first frame. Both now run with the rest of the
  // deferred work. Until Sentry is up the handlers above still log every
  // error to AppLogger, and when no DSN was injected at build time Sentry
  // never runs at all, so a misconfigured or slow Sentry can no longer
  // decide when the user sees the app.
  //
  // STARTUP LAG FIX (2026-10-15): Firebase core init used to be a splash-gate
  // phase, holding the gate for seconds on slow/sanctioned networks. It now
  // starts here, unawaited, at the earliest channel-ready moment; the push
  // chain and the Firestore streams await the same memoized future, so the
  // launch path never waits for the network.
  unawaited(ensureFirebaseInitialized());
  await _bootstrapOnce();
}

/// Guards against a double runApp (e.g. Sentry init failing *after* it
/// already invoked appRunner).
Future<void> _bootstrapOnce() async {
  if (_bootstrapped) return;
  _bootstrapped = true;
  await _bootstrap();
}

/// The cold-start stages the splash waits on before Home may appear. Each is
/// individually guarded by [runStartupPhase], so one failure degrades its own
/// feature and the app still launches.
///
/// Firebase core is deliberately NOT here anymore (2026-10-15): it is the
/// only network-bound phase and held the gate for seconds on slow networks.
/// It starts unawaited in `main()` and the push/Firestore consumers await the
/// same memoized future. The remaining three stages are all local, so the
/// gate stays fast; dropping a local stage would let Home build over a
/// half-loaded app (a first-build provider then caches the empty Quran
/// corpus, so search silently returns nothing all session).
List<Future<void> Function()> _startupPhases() => [
      initNotificationsGuarded,
      _initQuranData,
      _initDorarHadith,
    ];

Future<void> _bootstrap() async {
  final bootstrap = AppBootstrap(phases: _startupPhases());
  await runZonedGuarded(() async {
    runApp(
      ProviderScope(
        overrides: [appBootstrapProvider.overrideWithValue(bootstrap)],
        child: const TawheedApp(),
      ),
    );
    _startupMark('runApp');

    // The frame is scheduled; the moment it is on screen the init stages run
    // in parallel behind the splash, together with the work Home never waits
    // for. `addPostFrameCallback` rather than `endOfFrame` so the kickoff is
    // not itself an await on the frame's completion.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startupMark('first-frame');
      bootstrap.start();
      _startDeferredWork();
    });
  }, (error, stack) {
    if (_sentryEnabled) {
      Sentry.captureException(error, stackTrace: stack);
    }
    AppLogger.error('UnhandledZoneError', error, stack);
  });
}

/// Work the first frame does not need and Home does not wait for. Started on
/// the first frame so it never competes with it.
void _startDeferredWork() {
  // PHASE-1 FIX: FCM (token fetch + topic subscribe) is a NETWORK call and
  // used to be awaited before runApp. Phase-1 audit refinement: the delay is
  // anchored to the FIRST FRAME instead of a fixed 2s timer — on a slow
  // device the old timer could fire before the first frame and compete with
  // it; on a fast device it wasted 2s of push readiness.
  unawaited(WidgetsBinding.instance.endOfFrame.then((_) async {
    try {
      // Core first: push init skips itself when no Firebase app exists, so
      // without this await a fast first frame could leave push disabled for
      // the whole session whenever the lazy core init was still in flight.
      await ensureFirebaseInitialized();
      await FirebasePushService().init();
    } catch (e, st) {
      AppLogger.error('Push', 'deferred init failed: $e', st);
    }
  }));

  // Native AndroidX WorkManager runs the Dart background callback for prayer
  // sync, daily content refresh and azan checks when the app is closed.
  // Scheduled OFF the startup critical path: this is closed-app upkeep and
  // must never delay the first frame (BootCoordinator re-syncs after it).
  unawaited(BackgroundScheduler.initialize().then((_) async {
    await BackgroundScheduler().scheduleDailyRefresh(
      initialDelay: const Duration(hours: 1),
    );
    await BackgroundScheduler().enqueueAzanCheck();
    await BackgroundScheduler().enqueueHourlyNotifCheck();
  }).catchError((e, st) {
    AppLogger.error('BackgroundScheduler', e, st);
  }));

  // Real app version for crash grouping, then Sentry itself — both after the
  // frame, and both guarded, so neither can hold the launch hostage.
  unawaited(() async {
    try {
      _release = await _releaseName();
      await _initSentry();
    } catch (e, st) {
      AppLogger.error('Startup', 'deferred Sentry init failed: $e', st);
    }
  }());
}

/// PHASE-1 FIX: Sentry must never be able to prevent the app from
/// launching — a misconfigured DSN or an init failure is logged and the app
/// carries on without crash reporting (the AppLogger handlers stay in place).
Future<void> _initSentry() async {
  if (!_sentryEnabled) return;
  try {
    await SentryFlutter.init((options) {
      options.dsn = _sentryDsn;
      // Sample 10% of traces to keep the free tier quota in check.
      options.tracesSampleRate = 0.1;
      options.environment = kReleaseMode ? 'production' : 'development';
      options.release = _release;
    });
    _startupMark('sentry-init');
  } catch (e, st) {
    AppLogger.error(
        'Startup', 'Sentry init failed — continuing without it: $e', st);
  }
}

Future<String> _releaseName() async {
  try {
    final pkg = await PackageInfo.fromPlatform();
    _startupMark('package-info');
    return 'tawheeed@${pkg.version}+${pkg.buildNumber}';
  } catch (e, st) {
    // Phase-1/2 audit fix: the message used to be a bare 'operation failed'
    // with the error dropped — useless in the on-device log.
    AppLogger.error('main', 'PackageInfo failed: $e', st);
    return 'tawheeed@unknown';
  }
}

/// PHASE-1 FIX (critical): init() used to run unguarded *outside*
/// runZonedGuarded — an exception from the plugin/tz/channel stack escaped
/// before runApp, producing a permanent black screen (the exact failure mode
/// already documented for loadQuranData, but never applied here). A failure
/// now degrades notifications only; the app still launches and the next cold
/// start retries. Public + @visibleForTesting so the regression test can lock
/// the "never throws" contract end-to-end (test/main_startup_guard_test.dart).
@visibleForTesting
Future<void> initNotificationsGuarded() => runStartupPhase(
      'NotificationService.init failed — launching without notifications',
      () async {
        await NotificationService().init();
        _startupMark('notifications-init');
      },
    );

/// متون کامل قرآن از asset بارگذاری می‌شود (2.5 مگابایت، decode در isolate
/// جداگانه) — پیش از Home تا تمام مصرف‌کننده‌های همگامِ `quran` (جستجو،
/// اشتراک، fallback آیه در مصحف) همیشه دادهٔ کامل ببینند؛ در غیر این صورت
/// جستجو بی‌صدا خالی می‌ماند. (loadQuranData خودش هم guard داخلی دارد؛
/// این‌جا belt-and-suspenders است.)
Future<void> _initQuranData() => runStartupPhase(
      'Quran data load failed — launching empty',
      () async {
        // FATAL-STARTUP GUARD: a corrupted asset (or a failed update) used to
        // leave the app as a permanent black screen — launch anyway with an
        // empty dataset; every consumer already has an empty-data fallback and
        // quran features degrade gracefully, while a full app remains usable.
        await loadQuranData();
        _startupMark('quran-data');
      },
    );

/// جستجوی احادیث درر — rawi.db به پوشه پشتیبان کپی می‌شود و cache.db هم
/// همان‌جا ساخته می‌شود (مسیر پیش‌فرض پکیج روی Android قابل نوشتن نیست).
/// اگر ناموفق باشد فقط جستجوی احادیث در صفحهٔ خطا می‌ماند و برنامه بالا
/// می‌آید.
Future<void> _initDorarHadith() => runStartupPhase(
      'Dorar hadith init failed — hadith search degraded',
      () async {
        await DorarHadithFlutter.ensureInitialized();
        await configureDorarCache();
        _startupMark('dorar-init');
      },
    );

class TawheedApp extends ConsumerWidget {
  const TawheedApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Phase-1 audit fix: the identical scheduleIfNeeded trigger was pasted
    // into both listeners; extracted so a future change cannot diverge, and
    // the fire-and-forget future now carries its own catchError (it used to
    // escape to the zone with no context).
    void rescheduleDailyNotifications() {
      final s = ref.read(settingsProvider).value ?? const AppSettings();
      final prayerService = ref.read(prayerTimeServiceProvider);
      DailyNotificationScheduler()
          .scheduleIfNeeded(
        prayerService: prayerService,
        settings: s,
      )
          .catchError((Object e) {
        AppLogger.warning(
            'TawheedApp', 'daily notification reschedule failed: $e');
      });
    }

    ref.listen(settingsProvider, (_, next) {
      if (next is AsyncData && next.value != null) {
        rescheduleDailyNotifications();
      }
    });

    ref.listen(prayerTimesProvider, (_, next) {
      if (next is AsyncData && next.value != null) {
        rescheduleDailyNotifications();
      }
    });

    final s = ref.watch(settingsProvider).value ?? const AppSettings();

    final font = s.fontFamily.name;
    // Keep the whole app (including hardcoded TextStyles) on the active font.
    // Default remains Calibri — the app's identity font.
    AppTheme.fontFamily = font;

    ThemeMode themeMode;
    switch (s.themeMode) {
      case ThemeModeOption.dark:
        themeMode = ThemeMode.dark;
      case ThemeModeOption.light:
        themeMode = ThemeMode.light;
      default:
        themeMode = ThemeMode.system;
    }

    // Live theme: the palette follows the time-of-day phase derived from the
    // shar'i schedule. Watching the phase here rebuilds MaterialApp only when
    // the phase actually changes (a few times per day), and ThemeData carries
    // the TimeThemeKit extension so the switch animates smoothly.
    final kind = themeKindFromStored(s.accentPreset);
    final phase = ref.watch(timePhaseProvider);
    AppTheme.applyTheme(kind: kind, phase: phase);

    return MaterialApp.router(
      title: 'توحید',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fa'),
      supportedLocales: const [Locale('fa'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: themeMode,
      // The phase→palette hand-off (live theme) animates softly instead of
      // snapping — the design's 800ms eased transition. Users with the OS
      // «remove animations» accessibility setting get an instant switch.
      themeAnimationDuration: WidgetsBinding.instance.platformDispatcher
              .accessibilityFeatures.disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 800),
      themeAnimationCurve: Curves.easeInOut,
      // Base type sizes stay at 1.0 here: the reader's size is applied ONCE,
      // centrally, by the root TextScaler in `builder` below. Multiplying the
      // theme sizes as well would scale every themed text twice.
      theme: AppTheme.lightTheme(fontFamily: font),
      darkTheme: AppTheme.darkTheme(fontFamily: font),
      // ONE TextScaler for the whole app — and the only one. [AppTextScale]
      // replaces the device's own font-size preference with the in-app
      // «اندازه فونت» setting, so the reader looks the same on every phone
      // while still being resizable from inside the app. Unlike theme-only
      // scaling, a root TextScaler also reaches the ~1000 hardcoded
      // `fontSize:` styles (mushaf glyphs, clock digits, sciences text) that
      // never followed the setting before.
      // Also the global error boundary: wrapping the Navigator here covers
      // EVERY route, so a build error shows the friendly retry UI instead of a
      // grey/red screen.
      // The ambient backdrop is applied at the ROOT, not only per route. The
      // router wraps each GoRoute in `_ambient` (app_router.dart), but a raw
      // `Navigator.push` pushes its own opaque page on top of that branch, so
      // the ambient route below is never painted — and a screen whose Scaffold
      // is `Colors.transparent` then shows the platform window: the reported
      // black background (ریاض الصالحین chapters, the inner hadith pages, یقین,
      // reading stats, the fatwa detail). Wrapping here covers every route,
      // pushed or routed, present and future.
      //
      // Safe by SDK contract: `MaterialApp.builder` is invoked below
      // `AnimatedTheme`, so `Theme.of` inside `AmbientBackground` resolves to
      // the app's own theme (app.dart's own note on the extra `Builder`).
      // Routes that paint their own backdrop (the shell, the mushaf, splash)
      // cover this one, so nothing changes visually where it already worked.
      builder: (context, child) => AmbientBackground(
        child: AppTextScale(
          fontScale: s.fontScale,
          child: AppErrorBoundary(
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
      routerConfig: buildAppRouter(),
    );
  }
}

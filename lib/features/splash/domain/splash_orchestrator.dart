import 'dart:async';

import 'package:tawheeed/features/splash/presentation/splash_style.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Where the splash hands off to.
enum SplashDestination { shell, onboarding }

/// The cold-start gate: how long the splash stays up and where it goes.
///
/// Kept out of the widget so the rules are testable without pumping a tree:
/// leave when BOTH the minimum show and initialization have finished, never
/// later than the hang guard, and always to somewhere — an init that throws
/// or wedges still reaches Home, because a splash you cannot leave is worse
/// than a Home with one degraded feature.
class SplashOrchestrator {
  SplashOrchestrator({
    this.minShow = SplashTiming.minimumShow,
    this.loaderDelay = SplashTiming.loaderDelay,
    this.hangGuard = SplashTiming.hangGuard,
  });

  final Duration minShow;
  final Duration loaderDelay;
  final Duration hangGuard;

  /// Leaves no sooner than [minShow]; there is deliberately no maximum, so a
  /// genuinely slow device waits on its init rather than on a timer.
  Future<SplashDestination> run({
    required Future<void> Function() init,
    required Future<bool?> Function() onboardingDone,
    void Function()? onLoaderDue,
  }) async {
    // The dots are a promise about a wait that has not landed yet; the moment
    // the gate resolves they are cancelled, so a 2.01s cold start never shows
    // a loader for one frame.
    Timer? loaderTimer;
    if (onLoaderDue != null && loaderDelay > Duration.zero) {
      loaderTimer = Timer(loaderDelay, onLoaderDue);
    }

    final startedAt = DateTime.now();
    bool initFailed = false;
    try {
      // Init and the routing decision are independent — the flag read is
      // usually long done while the Quran decode is still running, and
      // awaiting them in series would add the faster one to the wait.
      final initTask = () async {
        try {
          await init().timeout(hangGuard);
        } on TimeoutException {
          initFailed = true;
          AppLogger.error('SplashOrchestrator',
              'init wedged for ${hangGuard.inMilliseconds}ms — opening Home anyway');
        } catch (e, st) {
          initFailed = true;
          AppLogger.error(
              'SplashOrchestrator', 'a startup phase escaped its guard: $e', st);
        }
      }();

      final decisionTask = () async {
        try {
          return await onboardingDone().timeout(hangGuard);
        } on TimeoutException {
          AppLogger.error('SplashOrchestrator',
              'the onboarding read wedged — assuming an existing user');
        } catch (e, st) {
          AppLogger.error('SplashOrchestrator',
              'the onboarding read failed — assuming an existing user', st);
        }
        // Unknown: assume an existing user. Showing onboarding to a returning
        // user would overwrite a real profile; Home with defaults degrades
        // far more softly, and the still-pending read lands as soon as it can.
        return null;
      }();

      await Future.wait<void>([
        Future<void>.delayed(minShow),
        initTask,
        // `then((_))` only to give the three futures one type — the decision
        // itself is read off `decisionTask` below, whose value is cached.
        decisionTask.then((_) {}),
      ]);

      final took = DateTime.now().difference(startedAt);
      AppLogger.info('SplashOrchestrator',
          'gate released after ${took.inMilliseconds}ms (init: '
          '${initFailed ? 'degraded' : 'ok'})');
      return await decisionTask == false
          ? SplashDestination.onboarding
          : SplashDestination.shell;
    } finally {
      loaderTimer?.cancel();
    }
  }
}

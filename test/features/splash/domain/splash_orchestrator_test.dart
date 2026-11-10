import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/splash/domain/splash_orchestrator.dart';
import 'package:tawheeed/features/splash/presentation/splash_style.dart';

/// The splash's only job is to decide WHEN to leave and WHERE to go, and both
/// are timing rules rather than widget rules. Real timers are used here (never
/// a fake clock this file has to keep in sync): every assertion is of the form
/// "not before X" or "fired exactly once", which real timers can only
/// overshoot, never undershoot.
void main() {
  const fast = Duration(milliseconds: 30);
  const slowish = Duration(milliseconds: 160);

  SplashOrchestrator tuned({
    Duration minShow = fast,
    Duration loaderDelay = Duration.zero,
    Duration hangGuard = const Duration(seconds: 2),
  }) =>
      SplashOrchestrator(
        minShow: minShow,
        loaderDelay: loaderDelay,
        hangGuard: hangGuard,
      );

  Future<void> after(Duration d) => Future<void>.delayed(d);

  group('the shipped timings', () {
    test('the minimum show is 800ms and there is no maximum', () {
      expect(SplashTiming.minimumShow, const Duration(milliseconds: 800));
      expect(SplashTiming.crossFade, const Duration(milliseconds: 250));
      expect(SplashTiming.loaderDelay, const Duration(seconds: 2));
      expect(SplashTiming.hangGuard, const Duration(seconds: 12));
    });
  });

  group('when it leaves', () {
    test('never before the minimum show, even with init already done',
        () async {
      final started = DateTime.now();
      final destination = await tuned(minShow: slowish).run(
        init: () async {},
        onboardingDone: () async => true,
      );
      final elapsed = DateTime.now().difference(started);

      expect(destination, SplashDestination.shell);
      expect(elapsed, greaterThanOrEqualTo(slowish));
    });

    test('waits for init when init is the slower half', () async {
      final started = DateTime.now();
      await tuned().run(
        init: () => after(slowish),
        onboardingDone: () async => true,
      );

      expect(DateTime.now().difference(started), greaterThanOrEqualTo(slowish));
    });

    test('does not add the two waits: they run together', () async {
      const both = Duration(milliseconds: 120);
      final started = DateTime.now();
      await tuned(minShow: both).run(
        init: () => after(both),
        onboardingDone: () async => true,
      );

      // Series would cost 240ms; parallel costs one 120ms wait plus a tick.
      expect(DateTime.now().difference(started),
          lessThan(const Duration(milliseconds: 220)));
    });
  });

  group('never hangs', () {
    test('an init that throws still reaches Home', () async {
      final destination = await tuned().run(
        init: () async => throw StateError('a phase fell over'),
        onboardingDone: () async => true,
      );

      expect(destination, SplashDestination.shell);
    });

    test('a wedged init is cut off by the hang guard', () async {
      final started = DateTime.now();
      final destination = await tuned(
        hangGuard: slowish,
      ).run(
        init: () => Completer<void>().future,
        onboardingDone: () async => true,
      );

      expect(destination, SplashDestination.shell);
      expect(DateTime.now().difference(started), greaterThanOrEqualTo(slowish));
    });

    test('a wedged onboarding read still opens Home', () async {
      final destination = await tuned(hangGuard: slowish).run(
        init: () async {},
        onboardingDone: () => Completer<bool?>().future,
      );

      expect(destination, SplashDestination.shell);
    });

    test('an onboarding read that throws still opens Home', () async {
      final destination = await tuned().run(
        init: () async {},
        onboardingDone: () async => throw StateError('db wedged'),
      );

      expect(destination, SplashDestination.shell);
    });
  });

  group('where it goes', () {
    test('true — an existing user, so Home', () async {
      expect(
          await tuned().run(
            init: () async {},
            onboardingDone: () async => true,
          ),
          SplashDestination.shell);
    });

    test('false — a fresh install, so onboarding', () async {
      expect(
          await tuned().run(
            init: () async {},
            onboardingDone: () async => false,
          ),
          SplashDestination.onboarding);
    });

    test('null — unknown, and Home degrades more softly than onboarding',
        () async {
      expect(
          await tuned().run(
            init: () async {},
            onboardingDone: () async => null,
          ),
          SplashDestination.shell);
    });

    test('a degraded init does not override a real onboarding answer',
        () async {
      // The two decisions are independent: a failed Quran load must not turn
      // a first launch into the shell.
      final destination = await tuned().run(
        init: () async => throw StateError('quran asset corrupt'),
        onboardingDone: () async => false,
      );

      expect(destination, SplashDestination.onboarding);
    });
  });

  group('the slow-start dots', () {
    test('stay hidden when the gate beats the delay', () async {
      var shown = 0;
      await tuned(loaderDelay: slowish).run(
        init: () => after(fast),
        onboardingDone: () async => true,
        onLoaderDue: () => shown++,
      );

      expect(shown, 0, reason: 'a 30ms cold start must never show a loader');
    });

    test('appear once the wait crosses the delay', () async {
      var shown = 0;
      final started = DateTime.now();
      await tuned(loaderDelay: fast, hangGuard: slowish).run(
        init: () => Completer<void>().future,
        onboardingDone: () async => true,
        onLoaderDue: () => shown++,
      );

      expect(shown, 1);
      expect(DateTime.now().difference(started), greaterThanOrEqualTo(fast));
    });

    test('fire once, not on every tick', () async {
      var shown = 0;
      await tuned(
        minShow: slowish,
        loaderDelay: fast,
      ).run(
        init: () => after(slowish),
        onboardingDone: () async => true,
        onLoaderDue: () => shown++,
      );

      expect(shown, 1);
    });
  });
}

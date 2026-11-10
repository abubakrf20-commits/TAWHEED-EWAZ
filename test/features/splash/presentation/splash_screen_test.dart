import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/app/state/app_bootstrap.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/features/splash/presentation/screens/splash_screen.dart';
import 'package:tawheeed/features/splash/presentation/splash_style.dart';

class _MockSettings extends Settings {
  AppSettings settings;
  _MockSettings({this.settings = const AppSettings()});

  @override
  Future<AppSettings> build() async => settings;

  @override
  Future<void> patch(AppSettings Function(AppSettings) updater) async {
    settings = updater(settings);
  }
}

/// What the splash handed to the destination route as `extra` (the cross-fade
/// length), or null when it navigated without one.
Object? _handedExtra;

Widget _harness({
  AppSettings settings = const AppSettings(),
  AppBootstrap? bootstrap,
}) {
  final router = GoRouter(
    initialLocation: RouteNames.splash,
    routes: [
      GoRoute(
        path: RouteNames.shell,
        builder: (_, state) {
          _handedExtra = state.extra;
          return const Scaffold(body: Center(child: Text('SHELL_PLACEHOLDER')));
        },
      ),
      GoRoute(
        path: RouteNames.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: RouteNames.onboarding,
        builder: (_, state) {
          _handedExtra = state.extra;
          return const Scaffold(
              body: Center(child: Text('ONBOARDING_PLACEHOLDER')));
        },
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith(() => _MockSettings(settings: settings)),
      // A cold start in the app always has the real batch; a test that does
      // not care about init timing gets one that is already finished.
      if (bootstrap != null)
        appBootstrapProvider.overrideWithValue(bootstrap)
      else
        appBootstrapProvider.overrideWithValue(AppBootstrap.immediate()),
    ],
    // Exactly the locale wiring TawheedApp ships with: the field is composed
    // RTL, and without the delegates `fa` resolves back to en.
    child: MaterialApp.router(
      locale: const Locale('fa'),
      supportedLocales: const [Locale('fa'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    ),
  );
}

/// Sizes the test window and returns once the splash has painted.
Future<void> _pumpSplashAt(
  WidgetTester tester,
  Size size, {
  AppSettings settings = const AppSettings(onboardingCompleted: true),
  AppBootstrap? bootstrap,
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_harness(settings: settings, bootstrap: bootstrap));
  await tester.pump();
}

/// Moves the fake clock on by [d] and then builds one more frame: the gate's
/// `context.go` runs in the microtasks the timer releases, so the destination
/// route is only in the tree after the frame that follows.
Future<void> _advance(WidgetTester tester, Duration d) async {
  await tester.pump(d);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _handedExtra = null;
    SharedPreferences.setMockInitialValues({'onboarding_done_v1': true});
  });

  group('what it shows', () {
    testWidgets('the branding and the four tiles', (tester) async {
      await _pumpSplashAt(tester, const Size(360, 800));

      expect(find.text('همراه شما در مسیر بندگی'), findsOneWidget);
      expect(find.text('قرآن'), findsOneWidget);
      expect(find.text('اذکار'), findsOneWidget);
      expect(find.text('نماز'), findsOneWidget);
      expect(find.text('قبله'), findsOneWidget);
      // The composition is RTL-specific: the crescent goes to the top-END
      // corner, so a harness that resolved to LTR would record a mirror image.
      expect(Directionality.of(tester.element(find.byType(SplashScreen))),
          TextDirection.rtl);

      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
    });

    testWidgets('the coin is a plain Image with nothing drawn around it',
        (tester) async {
      await _pumpSplashAt(tester, const Size(360, 800));

      final logo = find.byKey(const ValueKey('splash-logo'));
      expect(logo, findsOneWidget);
      expect(tester.widget<Image>(logo).image, same(SplashAssets.logo),
          reason: 'the real logo asset, one shared provider');

      // Sacred: no frame, no glow, no clip, no shadow. Walk the coin's own
      // ancestor chain and reject any box, clip or elevation widget on the way.
      const forbidden = {
        DecoratedBox,
        ClipRRect,
        ClipPath,
        ClipOval,
        Card,
        Container,
        PhysicalModel,
        Shadow,
        InkWell,
        FittedBox,
      };
      final chain = <Type>[];
      tester.element(logo).visitAncestorElements((ancestor) {
        chain.add(ancestor.widget.runtimeType);
        // Stop at the painter: above it is the Scaffold's own surface, which is
        // the page rather than a frame around the coin.
        return ancestor.widget is! CustomPaint;
      });
      expect(chain, contains(CustomPaint),
          reason: 'the field is paint only — nothing is drawn between the '
              'gradient and the logo pixels');
      expect(chain, contains(Stack),
          reason: 'the coin is laid out in the field Stack, not in a box');
      expect(chain.where(forbidden.contains), isEmpty,
          reason: 'anything box-like around the coin is a frame');

      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
    });

    testWidgets('the coin is centred horizontally and 1 cm above centre',
        (tester) async {
      await _pumpSplashAt(tester, const Size(360, 800));

      final screen = tester.getRect(find.byType(SplashScreen));
      final box = tester.getRect(find.byKey(const ValueKey('splash-logo')));
      expect(box.center.dx, closeTo(screen.center.dx, 0.01));
      expect(
          box.center.dy, closeTo(screen.center.dy - SplashSizes.logoLift, 0.01),
          reason:
              'the mark sits above the dead centre so the tagline has room');
      // clamp(0.7056 * 360, 201.6, 288) = 253.968 — the 0.9 box the user asked
      // for («لوگو 10% کوچکتر»).
      expect(box.width, closeTo(SplashSizes.logoSize(360), 0.01));
      expect(box.width, closeTo(254.016, 0.01));
      expect(box.height, closeTo(box.width, 0.01));
      expect(box.top, closeTo((800 - 254.016) / 2 - SplashSizes.logoLift, 0.01));

      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
    });

    test('the logo never drops below the floor and never exceeds 288dp', () {
      expect(SplashSizes.logoSize(200), SplashSizes.logoMin);
      expect(SplashSizes.logoSize(320), closeTo(225.792, 0.01));
      expect(SplashSizes.logoSize(360), closeTo(254.016, 0.01));
      expect(SplashSizes.logoSize(393), closeTo(277.3, 0.01));
      expect(SplashSizes.logoSize(412), SplashSizes.logoMax);
      expect(SplashSizes.logoSize(800), SplashSizes.logoMax);
    });

    test('the lift is one centimetre, in the unit dp is defined by', () {
      // 1 cm = 10/2.54 inch, and 1 inch = 160 dp.
      expect(SplashSizes.logoLift, closeTo(160 / 2.54, 0.01));
    });

    testWidgets('the tiles are decoration only — one semantics label total',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpSplashAt(tester, const Size(360, 800));

      expect(find.bySemanticsLabel('توحید — همراه شما در مسیر بندگی'),
          findsOneWidget);
      for (final label in ['قرآن', 'اذکار', 'نماز', 'قبله']) {
        expect(find.text(label), findsOneWidget);
        expect(find.bySemanticsLabel(label), findsNothing,
            reason: 'the tile labels must not be announced — they are '
                'decoration, and there is nothing to tap');
      }

      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      handle.dispose();
    });

    testWidgets('a short screen hides the tiles, never the coin',
        (tester) async {
      // 470, not the old 500: a 10 % smaller coin buys ~28 dp of vertical
      // room, so 500 dp is no longer short enough to drop the tiles. The
      // contract being guarded is unchanged — under a window this tight the
      // tiles go and the mark stays whole.
      await _pumpSplashAt(tester, const Size(360, 470));

      final box = tester.getRect(find.byKey(const ValueKey('splash-logo')));
      expect(box.top, greaterThanOrEqualTo(0),
          reason: 'the lift is floored so a short window never cuts the mark');
      expect(box.bottom, lessThanOrEqualTo(470));
      expect(find.text('قرآن'), findsNothing);
      expect(find.text('همراه شما در مسیر بندگی'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
    });

    testWidgets('the font scale is capped at 1.3 for this screen only',
        (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await _pumpSplashAt(tester, const Size(360, 800));

      // Read it from INSIDE the splash: the widget's own element sits above
      // the MediaQuery it publishes.
      final scaler =
          MediaQuery.of(tester.element(find.text('همراه شما در مسیر بندگی')))
              .textScaler;
      expect(scaler.scale(10), closeTo(13, 0.01));

      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
    });

    testWidgets('the slow-start dots appear only after two seconds',
        (tester) async {
      // An init that never lands, so the dots are the only thing that moves.
      final stuck = AppBootstrap(phases: [
        () => Completer<void>().future,
      ]);
      stuck.start();
      await _pumpSplashAt(tester, const Size(360, 800), bootstrap: stuck);

      final dots = find.descendant(
        of: find.byType(SplashScreen),
        matching: find.byWidgetPredicate((w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle),
      );
      await tester.pump(const Duration(milliseconds: 1900));
      expect(dots, findsNothing,
          reason: 'a wait the user cannot feel needs no spinner');

      await tester.pump(const Duration(milliseconds: 200));
      expect(dots, findsNWidgets(3));
      expect(find.text('همراه شما در مسیر بندگی'), findsOneWidget);

      // Then the hang guard lets go and the dots leave with the route.
      await tester.pump(const Duration(seconds: 13));
      await tester.pump();
      expect(find.text('SHELL_PLACEHOLDER'), findsOneWidget);
    });
  });

  group('when it leaves', () {
    testWidgets('not before the 800ms floor', (tester) async {
      await _pumpSplashAt(tester, const Size(360, 800));

      await _advance(tester, const Duration(milliseconds: 700));
      expect(find.text('SHELL_PLACEHOLDER'), findsNothing);
      expect(find.text('همراه شما در مسیر بندگی'), findsOneWidget);

      await _advance(tester, const Duration(milliseconds: 200));
      expect(find.text('SHELL_PLACEHOLDER'), findsOneWidget);
    });

    testWidgets('as soon as init lands, with no maximum cap', (tester) async {
      final quick = AppBootstrap(phases: [
        () => Future<void>.delayed(const Duration(milliseconds: 2000))
      ]);
      quick.start();
      await _pumpSplashAt(tester, const Size(360, 800), bootstrap: quick);

      // Past the 800ms floor, but init is still running — the gate waits.
      await _advance(tester, const Duration(milliseconds: 1600));
      expect(find.text('SHELL_PLACEHOLDER'), findsNothing,
          reason: 'the floor alone is not enough — init is still running');

      await _advance(tester, const Duration(milliseconds: 600));
      expect(find.text('SHELL_PLACEHOLDER'), findsOneWidget);
    });

    testWidgets('a deep-link cold start still routes to Home', (tester) async {
      SharedPreferences.setMockInitialValues({
        'notification_payload': 'prayer_fajr',
        'onboarding_done_v1': true,
      });
      await _pumpSplashAt(tester, const Size(360, 800));

      await _advance(tester, const Duration(milliseconds: 1600));
      expect(find.text('SHELL_PLACEHOLDER'), findsOneWidget);
    });
  });

  group('where it goes', () {
    testWidgets('onboarding on a fresh install', (tester) async {
      SharedPreferences.setMockInitialValues({'onboarding_done_v1': false});
      await _pumpSplashAt(tester, const Size(360, 800));

      await _advance(tester, const Duration(milliseconds: 1600));
      expect(find.text('ONBOARDING_PLACEHOLDER'), findsOneWidget);
      expect(find.text('SHELL_PLACEHOLDER'), findsNothing);
    });

    testWidgets('the stashed flag wins over a stale settings row',
        (tester) async {
      SharedPreferences.setMockInitialValues({'onboarding_done_v1': false});
      await _pumpSplashAt(tester, const Size(360, 800));

      await _advance(tester, const Duration(milliseconds: 1600));
      expect(find.text('ONBOARDING_PLACEHOLDER'), findsOneWidget);
    });

    testWidgets('a missing flag falls back to settings and is written back',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _pumpSplashAt(tester, const Size(360, 800));

      await _advance(tester, const Duration(milliseconds: 1600));
      expect(find.text('SHELL_PLACEHOLDER'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboarding_done_v1'), isTrue,
          reason: 'the routing decision is cached for the next cold start');
    });

    testWidgets('an init that fails still reaches Home', (tester) async {
      final broken = AppBootstrap(phases: [
        () async => throw StateError('a phase fell over'),
      ]);
      broken.start();
      await _pumpSplashAt(tester, const Size(360, 800), bootstrap: broken);

      await _advance(tester, const Duration(milliseconds: 1600));
      expect(find.text('SHELL_PLACEHOLDER'), findsOneWidget);
    });
  });

  group('the hand-off', () {
    testWidgets('fades over 250ms by default', (tester) async {
      await _pumpSplashAt(tester, const Size(360, 800));
      await _advance(tester, const Duration(milliseconds: 1600));

      expect(_handedExtra, SplashTiming.crossFade);
    });

    testWidgets('is instant in lite mode', (tester) async {
      SharedPreferences.setMockInitialValues({
        'onboarding_done_v1': true,
        'lite_mode': true,
      });
      await _pumpSplashAt(tester, const Size(360, 800));
      await _advance(tester, const Duration(milliseconds: 1600));

      expect(_handedExtra, Duration.zero);
    });

    testWidgets('is instant under reduce-motion', (tester) async {
      const features = FakeAccessibilityFeatures(disableAnimations: true);
      tester.platformDispatcher.accessibilityFeaturesTestValue = features;
      addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

      await _pumpSplashAt(tester, const Size(360, 800));
      await _advance(tester, const Duration(milliseconds: 1600));

      expect(_handedExtra, Duration.zero);
    });
  });
}

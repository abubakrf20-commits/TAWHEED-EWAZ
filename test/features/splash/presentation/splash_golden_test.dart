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

class _MockSettings extends Settings {
  @override
  Future<AppSettings> build() async =>
      const AppSettings(onboardingCompleted: true);

  @override
  Future<void> patch(AppSettings Function(AppSettings) updater) async {}
}

/// Visual baselines for the launch field: the three shipped widths, the 1.3
/// cap the screen publishes for itself, the slow-start dots, and a short screen
/// that gives up the tiles but never the coin.
///
/// The splash leaves after the 800ms floor, so every case here is pumped
/// against an init that never lands — that is the only way the same frame can
/// be captured twice on two machines. Nothing else about the screen changes with time: the field
/// painter has `shouldRepaint => false`, and the dots sit at a fixed phase of
/// the repeating controller the pumps below dictate.
///
/// Like the More/Home/Calendar sets these render **tofu glyphs** — no app font
/// is loaded in the test binding — so they guard palette, geometry and the
/// coin's own pixels, not Persian shaping. There is no Android device attached,
/// so this is the strongest visual proof available, not a substitute for a
/// device pass.
Future<void> _pumpField(
  WidgetTester tester, {
  required Size size,
  double textScale = 1.0,
  bool loader = false,
}) async {
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  // An init that never finishes keeps the route on screen for the capture.
  final stuck = AppBootstrap(phases: [() => Completer<void>().future]);
  stuck.start();

  final router = GoRouter(
    initialLocation: RouteNames.splash,
    routes: [
      GoRoute(
        path: RouteNames.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: RouteNames.shell,
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('SHELL_PLACEHOLDER'))),
      ),
    ],
  );

  await tester.pumpWidget(ProviderScope(
    overrides: [
      settingsProvider.overrideWith(_MockSettings.new),
      appBootstrapProvider.overrideWithValue(stuck),
    ],
    // Exactly the locale wiring TawheedApp ships with: without the delegates a
    // `fa` locale resolves back to en and the baseline records the mirror
    // image of the real launch (the crescent belongs to the top-END corner).
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
  ));

  // The coin is a real asset: decoding it needs the IO pool, which the fake
  // clock cannot drive.
  await tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
  await tester.pump();

  if (loader) {
    // 2s to reach the dots, then half of the 1100ms cycle so their alphas sit
    // at a fixed, repeatable phase.
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pump(const Duration(milliseconds: 550));
  } else {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Lets the gate go: the route, its hang-guard timer and the dots controller
/// must all be disposed before the binding checks the test for leaks.
Future<void> _leaveTheField(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 13));
  await tester.pump();
  expect(find.text('SHELL_PLACEHOLDER'), findsOneWidget);
}

/// Captures the field and then lets the gate go, so the route, its
/// hang-guard timer and the dots controller are all disposed before the
/// binding checks the test for leaks.
Future<void> _expectFieldGolden(WidgetTester tester, String name) async {
  await expectLater(
    find.byType(SplashScreen),
    matchesGoldenFile('goldens/$name.png'),
  );
  await _leaveTheField(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'onboarding_done_v1': true});
  });

  for (final width in [320.0, 360.0, 412.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('the field at ${width}dp, scale $scale', (tester) async {
        await _pumpField(
          tester,
          size: Size(width, width == 412.0 ? 915.0 : 800.0),
          textScale: scale,
        );
        await _expectFieldGolden(
            tester, 'splash_${width.toInt()}_scale${(scale * 10).round()}');
      });
    }
  }

  testWidgets('the slow-start dots after a wait the user can feel',
      (tester) async {
    await _pumpField(tester, size: const Size(360, 800), loader: true);
    await _expectFieldGolden(tester, 'splash_360_loader');
  });

  testWidgets('a short screen drops the tiles, never the coin', (tester) async {
    // 470 dp is the window that is short for the 0.9 coin — see
    // `splash_screen_test.dart`: at 500 the tiles now fit and stay.
    await _pumpField(tester, size: const Size(360, 470));
    await _expectFieldGolden(tester, 'splash_360_short');
  });
}

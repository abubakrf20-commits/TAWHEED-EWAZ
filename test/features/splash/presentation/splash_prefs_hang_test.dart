import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/features/splash/presentation/screens/splash_screen.dart';

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

/// Phase-1 regression: SplashScreen awaits `SharedPreferences.getInstance()`
/// before deciding where to navigate. The Phase-1 fix added a 400ms timeout —
/// without it a platform channel that never answers (as mocked here) would
/// wedge the splash forever. This file must be the FIRST prefs consumer in
/// its isolate so the default MethodChannel store (not a seeded in-memory
/// store) is the one that hangs.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('splash still routes when the prefs channel hangs',
      (tester) async {
    const channel = MethodChannel('plugins.flutter.io/shared_preferences');
    final never = Completer<Object?>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) => never.future);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final router = GoRouter(
      initialLocation: RouteNames.splash,
      routes: [
        GoRoute(
          path: RouteNames.shell,
          builder: (_, __) => const Scaffold(
            body: Center(child: Text('SHELL_PLACEHOLDER')),
          ),
        ),
        GoRoute(
          path: RouteNames.splash,
          builder: (_, __) => const SplashScreen(),
        ),
        GoRoute(
          path: RouteNames.onboarding,
          builder: (_, __) => const Scaffold(
            body: Center(child: Text('ONBOARDING_PLACEHOLDER')),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            () => _MockSettings(
              settings: const AppSettings(onboardingCompleted: true),
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    // 400ms prefs timeout + 800ms minimum show — navigation lands
    // around t≈1200ms; pump well past it.
    await tester.pump(const Duration(milliseconds: 2400));
    await tester.pump();

    expect(find.text('SHELL_PLACEHOLDER'), findsOneWidget,
        reason: 'a hung prefs channel must never wedge the splash');
  });
}

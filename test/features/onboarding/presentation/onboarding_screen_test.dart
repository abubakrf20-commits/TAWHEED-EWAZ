import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding_platform_interface/geocoding_platform_interface.dart'
    as pi;
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';

class _MockSettings extends Settings {
  AppSettings settings = const AppSettings();

  @override
  // SynchronousFuture resolves at element creation, so a later patch() can
  // never be overwritten by a still-pending build() future (the async
  // variant raced OnboardingScreen._saveCity and failed its verify read).
  Future<AppSettings> build() => SynchronousFuture(settings);

  @override
  Future<void> patch(AppSettings Function(AppSettings) updater) async {
    settings = updater(settings);
    // Mirror the real notifier: OnboardingScreen._finish verifies the write
    // through ref.read(settingsProvider).value before persisting the flag.
    state = AsyncData(settings);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildApp({_MockSettings? settingsOverride}) {
    final router = GoRouter(
      initialLocation: RouteNames.onboarding,
      routes: [
        GoRoute(
          path: RouteNames.shell,
          builder: (_, __) => const Scaffold(
            body: Center(child: Text('SHELL_PLACEHOLDER')),
          ),
        ),
        GoRoute(
          path: RouteNames.onboarding,
          builder: (_, __) => const OnboardingScreen(),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        settingsProvider
            .overrideWith(() => settingsOverride ?? _MockSettings()),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('the welcome step comes first and leads to location',
      (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('شروع کار با توحید'), findsOneWidget);
    expect(find.text('به توحید خوش آمدید'), findsOneWidget);
    // The four capability lines: the wizard must say what it is setting up
    // before the two permission asks.
    expect(find.text('اوقات شرعی و اذان'), findsOneWidget);
    expect(find.text('یادآوری‌ها'), findsOneWidget);
    // Nothing is written before the user taps «شروع».
    expect(find.text('نام شهر'), findsNothing);

    await tester.tap(find.text('شروع'));
    await tester.pumpAndSettle();

    expect(find.text('اوقات شرعی دقیق‌تر'), findsOneWidget);
    expect(find.text('نام شهر'), findsOneWidget);
    expect(find.text('استفاده از موقعیت فعلی'), findsOneWidget);
    expect(find.text('ادامه'), findsOneWidget);
  });

  testWidgets('the welcome step writes nothing on its own', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final mock = _MockSettings();
    await tester.pumpWidget(buildApp(settingsOverride: mock));
    await tester.pumpAndSettle();

    expect(mock.settings.onboardingCompleted, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_done_v1'), isNull);
  });

  testWidgets('empty city shows a validation error', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('شروع'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ادامه'));
    await tester.pumpAndSettle();

    expect(find.text('شهر را وارد کنید یا از موقعیت فعلی استفاده کنید.'),
        findsOneWidget);
  });

  testWidgets('unresolvable city (offline) shows a coordinates error',
      (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('شروع'));
    await tester.pumpAndSettle();

    // Must be a name the bundled Iran table does NOT carry — تهران resolves
    // from it without any geocoder, so the offline-failure branch was never
    // reached. With no geocoding platform registered in tests, an unknown
    // name is what actually simulates «offline».
    await tester.enterText(find.byType(TextField), 'شهر ناشناخته');
    await tester.tap(find.text('ادامه'));
    await tester.pumpAndSettle();

    // The wording grew when an unresolvable city stopped trapping the first
    // launch; the prefix is the contract, the rest is guidance.
    expect(find.textContaining('مختصات این شهر پیدا نشد'), findsOneWidget);
    // No navigation into the app happened.
    expect(find.text('SHELL_PLACEHOLDER'), findsNothing);
  });

  testWidgets('finishing onboarding writes onboarding_done_v1 (Phase-1 flag)',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    pi.GeocodingPlatformFactory.instance = _FakeGeocodingFactory();

    final mock = _MockSettings();
    await tester.pumpWidget(buildApp(settingsOverride: mock));
    await tester.pumpAndSettle();

    // Step 0 — welcome: nothing to fill in, just «شروع».
    await tester.tap(find.text('شروع'));
    await tester.pumpAndSettle();
    expect(find.text('اوقات شرعی دقیق‌تر'), findsOneWidget);

    // Step 1 — location: a typed city resolves through the fake geocoder.
    await tester.enterText(find.byType(TextField), 'تهران');
    await tester.tap(find.text('ادامه'));
    await tester.pumpAndSettle();
    expect(find.text('یادآوری‌های به‌موقع'), findsOneWidget);

    // Step 2 — notifications: skip via «بعداً» (no native permission channels).
    await tester.tap(find.text('بعداً'));
    await tester.pumpAndSettle();
    expect(find.text('ظاهر مورد علاقه شما'), findsOneWidget);

    // Step 3 — finish: persists settings + the routing flag, then navigates.
    await tester.tap(find.text('شروع استفاده از برنامه'));
    await tester.pumpAndSettle();

    expect(find.text('SHELL_PLACEHOLDER'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_done_v1'), isTrue,
        reason: '_finish must persist the flag SplashScreen routes on');
  });
}

/// Fake geocoder so the city step resolves offline in tests — the platform
/// factory is null in the test environment ([Geocoding()] would throw and
/// the step could never complete).
class _FakeGeocodingFactory extends pi.GeocodingPlatformFactory {
  @override
  pi.Geocoding createGeocoding(pi.GeocodingCreationParams params) =>
      _FakeGeocoding(params);
}

class _FakeGeocoding extends pi.Geocoding {
  // Super-parameters can't target the named `implementation` constructor
  // (the unnamed one is a factory), so the lint suggestion doesn't compile.
  // ignore: use_super_parameters
  _FakeGeocoding(pi.GeocodingCreationParams params)
      : super.implementation(params);

  @override
  Future<List<pi.Location>> locationFromAddress(String address,
      {Locale? locale}) async {
    // Any typed city resolves to Tehran — enough for the routing contract.
    return [const pi.Location(latitude: 35.6892, longitude: 51.3890)];
  }
}

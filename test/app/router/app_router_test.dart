import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/app/router/app_router.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import '../../core/database/mock_daos.dart';

/// Pumps the real app router, waits out the splash forwarding, then runs
/// [body] with the router ready.
Future<GoRouter> pumpRouter(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final mockRepo = MockSettingsRepository();
  mockRepo.setMockSettings(const AppSettings(onboardingCompleted: true));
  final router = buildAppRouter();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWith((ref) async => mockRepo),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  // The splash's 800ms floor + settings load + shell build.
  await tester.pump(const Duration(seconds: 4));
  await tester.pump();
  return router;
}

void main() {
  /// Unmounts the app and lets background timers (BootCoordinator upkeep)
  /// fire so the test binding's no-pending-timers invariant holds.
  Future<void> settleTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 11));
  }

  testWidgets('unknown path shows the Persian 404 screen', (tester) async {
    final router = await pumpRouter(tester);
    router.go('/definitely-not-a-route');
    await tester.pump();
    await tester.pump();
    expect(find.text('صفحه پیدا نشد'), findsOneWidget);
    await settleTree(tester);
  });

  testWidgets('404 home button returns to the shell', (tester) async {
    final router = await pumpRouter(tester);
    router.go('/definitely-not-a-route');
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('بازگشت به خانه'));
    // Shell build is heavy (boot coordinator async work) — give it frames.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('صفحه پیدا نشد'), findsNothing);
    expect(router.state.uri.toString(), '/');
    await settleTree(tester);
  });
}

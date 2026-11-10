import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/features/personal_info/presentation/providers/vault_session.dart';

class _UnlockedSession extends VaultSessionNotifier {
  @override
  bool build() => true;
}

Future<void> _pumpGuardedRoute(
  WidgetTester tester, {
  required bool pinSet,
  bool unlocked = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        vaultPinSetProvider.overrideWith((ref) => Future.value(pinSet)),
        if (unlocked) vaultSessionProvider.overrideWith(_UnlockedSession.new),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: RouteNames.personalCredentials,
          routes: [
            GoRoute(
              path: RouteNames.personalInfo,
              builder: (context, state) =>
                  const Scaffold(body: Center(child: Text('صفحهٔ رمز صندوق'))),
            ),
            GoRoute(
              path: RouteNames.personalCredentials,
              builder: (context, state) => const VaultGuard(
                child: Scaffold(body: Center(child: Text('رمزها و حساب‌ها'))),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('بدون تعیین رمز، صفحهٔ صندوق بی‌درنگ باز می‌شود', (tester) async {
    await _pumpGuardedRoute(tester, pinSet: false);
    expect(find.text('رمزها و حساب‌ها'), findsOneWidget);
    expect(find.text('ورود رمز'), findsNothing);
  });

  testWidgets('با رمز و صندوق قفل، اعلان قفل نمایش داده می‌شود',
      (tester) async {
    await _pumpGuardedRoute(tester, pinSet: true);
    expect(find.text('رمزها و حساب‌ها'), findsNothing);
    expect(find.text('صندوق قفل است'), findsOneWidget);
    expect(find.text('ورود رمز'), findsOneWidget);
  });

  testWidgets('پس از باز شدن قفل در همین نشست، صفحهٔ هدف نمایش داده می‌شود',
      (tester) async {
    await _pumpGuardedRoute(tester, pinSet: true, unlocked: true);
    expect(find.text('رمزها و حساب‌ها'), findsOneWidget);
  });

  testWidgets('دکمهٔ «ورود رمز» به صفحهٔ اصلی صندوق می‌رود', (tester) async {
    await _pumpGuardedRoute(tester, pinSet: true);
    await tester.tap(find.text('ورود رمز'));
    await tester.pumpAndSettle();
    expect(find.text('صفحهٔ رمز صندوق'), findsOneWidget);
  });
}

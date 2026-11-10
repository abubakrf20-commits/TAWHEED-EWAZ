import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal_info/presentation/providers/personal_info_provider.dart';
import 'package:tawheeed/features/personal_info/presentation/providers/vault_session.dart';
import 'package:tawheeed/features/personal_info/presentation/screens/personal_info_screen.dart';

class _UnlockedSession extends VaultSessionNotifier {
  @override
  bool build() => true;
}

const _emptyStats = (
  profiles: 0,
  credentials: 0,
  assets: 0,
  insurances: 0,
  emergencyContacts: 0,
  expiring: 0,
);

/// Device-proven 2026-10-13: leaving «اطلاعات من» threw
/// (`ref.read` on the unmounting element) — and the throw skipped `lock()`,
/// silently leaving the vault open. The screen now captures the notifier in
/// `initState`, so dispose re-arms the gate without touching `ref`.
void main() {
  setUpAll(
      () => AppTheme.applyTheme(kind: ThemeKind.day, phase: TimePhase.day));

  Future<ProviderContainer> pumpScreen(WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    final container = ProviderContainer(overrides: [
      vaultSessionProvider.overrideWith(_UnlockedSession.new),
      personalInfoStatsProvider
          .overrideWith((ref) => Future.value(_emptyStats)),
      expiringItemsProvider.overrideWith((ref) => Future.value([])),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const PersonalInfoScreen(),
        ),
      ),
    );
    // No pumpAndSettle: the dashboard runs a live ticker, so settle never
    // comes. Bounded pumps are enough — dispose is what this guards.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    return container;
  }

  testWidgets('leaving the vault re-locks it with no dispose throw',
      (tester) async {
    final container = await pumpScreen(tester);
    expect(container.read(vaultSessionProvider), isTrue);

    await tester.pumpWidget(Container());
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(container.read(vaultSessionProvider), isFalse);
  });
}

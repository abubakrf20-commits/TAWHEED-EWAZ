import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/app/state/clock_providers.dart';
import 'package:tawheeed/core/services/clock_ticker.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/features/settings/presentation/screens/more_screen.dart';

import '../../../../core/database/mock_daos.dart';

/// The user-facing contract behind `b6ad0b7` and the 2026-10-08 removal:
/// «آمارهٔ پیشرفت» and the recitation tools are gone from the app, so they
/// must not reappear in «بیشتر» either — not through the redesign's registry
/// and not through a re-added tile.
///
/// The redesign's MoreScreen carries a riverpod hero strip, so the pump needs
/// the same scoped wrap as `more_screen_test.dart`.
final _idleTicker = clockTickerProvider.overrideWith((ref) {
  final ticker = ClockTicker.idle();
  ref.onDispose(ticker.dispose);
  return ticker;
});

ProviderScope _wrap(Widget child) {
  SharedPreferences.setMockInitialValues({});
  final mockRepo = MockSettingsRepository();
  mockRepo.setMockSettings(const AppSettings());
  return ProviderScope(
    overrides: [
      settingsRepositoryProvider.overrideWith((ref) async => mockRepo),
      _idleTicker,
    ],
    child: child,
  );
}

void main() {
  testWidgets('More lists the reading tools but none of the removed ones',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 3600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(const MaterialApp(home: MoreScreen())));
    await tester.pumpAndSettle();

    // Removed with the sections they belonged to.
    for (final gone in [
      'مصحف توحید',
      'تلاوت‌یار',
      'ملقّن',
      'آمارهٔ پیشرفت',
    ]) {
      expect(find.text(gone), findsNothing, reason: '«$gone» came back');
    }

    // Still reachable: the external practice mushaf and the dua sections.
    expect(find.text('مصحف حافظ'), findsOneWidget);
    expect(find.text('دعا'), findsOneWidget);
    expect(find.text('حصن المسلم'), findsOneWidget);
  });
}

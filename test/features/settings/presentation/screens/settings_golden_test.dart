import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/prayer/presentation/screens/prayer_settings_screen.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/pages/settings_screen.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_infra_providers.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';

import '../../../../core/database/mock_daos.dart';
import '../fake_notification_infra.dart';
import 'golden_page_fit.dart';

/// Visual baselines for the two redesigned settings pages (Design 1 / A):
/// the main page at 412/320dp under the day palette, the main page dark, and
/// the prayer & adhan page under day and dark. Each is captured at its own
/// measured height so a shorter viewport cannot hide a clipped sliver. Like the
/// More set, these pin layout and palette drift; no font is loaded in the test
/// binding, so glyph shaping is not covered.
Widget _wrap(
  Widget home,
  ThemeData theme, {
  required ProviderContainer container,
  double textScale = 1,
}) {
  final base = theme.textTheme;
  final scaled = textScale == 1
      ? theme
      : theme.copyWith(
          textTheme: base.copyWith(
            bodyMedium: base.bodyMedium
                ?.copyWith(fontSize: base.bodyMedium!.fontSize! * textScale),
          ),
        );
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: scaled,
      home: Directionality(textDirection: TextDirection.rtl, child: home),
    ),
  );
}

Future<void> _open(
  WidgetTester tester, {
  required Widget home,
  required ThemeKind kind,
  required bool dark,
  required double width,
  double textScale = 1,
}) async {
  SharedPreferences.setMockInitialValues({});
  AppTheme.applyTheme(kind: kind, phase: TimePhase.day);
  // Build the ThemeData AFTER applyTheme: passing `AppTheme.light` as a call
  // argument would evaluate it against the PREVIOUS test's palette statics
  // (Dart evaluates arguments before the call), so a day golden following a
  // night one baked the night palette in — order-dependent red.
  final theme = dark ? AppTheme.dark : AppTheme.light;
  await tester.binding.setSurfaceSize(Size(width, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final repo = MockSettingsRepository()..setMockSettings(const AppSettings());
  final container = ProviderContainer(overrides: [
    settingsRepositoryProvider.overrideWith((ref) async => repo),
    dailyNotificationSchedulerProvider
        .overrideWithValue(FakeDailyNotificationScheduler()),
  ]);
  addTearDown(container.dispose);

  await tester.pumpWidget(
    _wrap(home, theme, container: container, textScale: textScale),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));

  // Size the surface to the page's real height: a wrapping row makes the list's
  // own extent estimate unreliable (see `golden_page_fit.dart`).
  await fitPageHeight(tester, width);
}

void main() {
  testWidgets('Settings golden — day 412dp', (tester) async {
    await _open(tester,
        home: const SettingsScreen(),
        kind: ThemeKind.day,
        dark: false,
        width: 412);
    await expectLater(find.byType(SettingsScreen),
        matchesGoldenFile('goldens/settings_day.png'));
  });

  testWidgets('Settings golden — day 320dp', (tester) async {
    await _open(tester,
        home: const SettingsScreen(),
        kind: ThemeKind.day,
        dark: false,
        width: 320);
    await expectLater(find.byType(SettingsScreen),
        matchesGoldenFile('goldens/settings_day_320.png'));
  });

  testWidgets('Settings golden — night 412dp', (tester) async {
    await _open(tester,
        home: const SettingsScreen(),
        kind: ThemeKind.night,
        dark: true,
        width: 412);
    await expectLater(find.byType(SettingsScreen),
        matchesGoldenFile('goldens/settings_night.png'));
  });

  testWidgets('Prayer settings golden — day 412dp', (tester) async {
    await _open(tester,
        home: const PrayerSettingsScreen(),
        kind: ThemeKind.day,
        dark: false,
        width: 412);
    await expectLater(find.byType(PrayerSettingsScreen),
        matchesGoldenFile('goldens/prayer_settings_day.png'));
  });

  testWidgets('Prayer settings golden — night 412dp', (tester) async {
    await _open(tester,
        home: const PrayerSettingsScreen(),
        kind: ThemeKind.night,
        dark: true,
        width: 412);
    await expectLater(find.byType(PrayerSettingsScreen),
        matchesGoldenFile('goldens/prayer_settings_night.png'));
  });
}

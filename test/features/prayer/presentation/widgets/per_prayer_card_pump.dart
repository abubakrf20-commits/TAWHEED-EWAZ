import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/prayer/presentation/widgets/per_prayer_adhan_card.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_infra_providers.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';

import '../../../../core/database/mock_daos.dart';
import '../../../settings/presentation/fake_notification_infra.dart';

/// The one widget-tree the card pumps into everywhere: RTL page context, the
/// day palette (or the scaled one), a RepaintBoundary the card-only goldens
/// capture, and a host that watches [settingsProvider] exactly like the
/// settings page does — so a write is visible in `widget.settings` even
/// without the whole screen around the card.
class _CardHost extends ConsumerWidget {
  const _CardHost({required this.anchors, required this.flashKey});

  final Map<String, GlobalKey> anchors;
  final String? flashKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    return PerPrayerAdhanCard(
      settings: settings,
      anchors: anchors,
      flashKey: flashKey,
    );
  }
}

/// The `(container, repo)` pair the card tests carry together.
typedef CardHarness = ({
  ProviderContainer container,
  MockSettingsRepository repo
});

/// Pumps the card standalone.
Future<CardHarness> pumpCard(
  WidgetTester tester, {
  required AppSettings settings,
  Map<String, Object> prefs = const {},
  double width = 412,
  double textScale = 1.0,
  bool dark = false,
}) async {
  tester.view.physicalSize = Size(width, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // Per-prayer voice overrides live in SharedPreferences.
  SharedPreferences.setMockInitialValues(prefs.cast<String, String>());

  // Build the theme AFTER applyTheme so the palette statics are current (the
  // settings-goldens order lesson), and scale bodyMedium for the 1.3 rows —
  // the driver `AppTheme.scaledFontSize` actually reads.
  AppTheme.applyTheme(
      kind: dark ? ThemeKind.night : ThemeKind.day, phase: TimePhase.day);
  final base = dark ? AppTheme.dark : AppTheme.light;
  final theme = textScale == 1.0
      ? base
      : base.copyWith(
          textTheme: base.textTheme.copyWith(
            bodyMedium: base.textTheme.bodyMedium?.copyWith(
                fontSize: base.textTheme.bodyMedium!.fontSize! * textScale),
          ),
        );

  final repo = MockSettingsRepository()..setMockSettings(settings);
  final container = ProviderContainer(overrides: [
    settingsRepositoryProvider.overrideWith((ref) async => repo),
    dailyNotificationSchedulerProvider
        .overrideWithValue(FakeDailyNotificationScheduler()),
  ]);
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: theme,
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                // The card is taller than short viewports at wide widths;
                // inside the real page the ListView scrolls. Vertical
                // scrolling keeps the width constraints tight, so every
                // layout mode resolves exactly as on the page.
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: RepaintBoundary(
                    key: ValueKey('golden-card'),
                    child: _CardHost(anchors: {}, flashKey: null),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  // One pump resolves the settings load; the second lets the card's async
  // voice-override read land.
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
  return (container: container, repo: repo);
}

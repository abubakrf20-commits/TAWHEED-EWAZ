import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/app/state/shell_nav.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/features/settings/presentation/screens/worship_scoring_screen.dart';

import '../../../../core/database/mock_daos.dart';

/// «امتیازدهی عبادات» — the six point values, now behind three tabs instead of
/// six inline rows on the settings page (user request, 2026-11-09).
///
/// The two concerns are kept apart on purpose: each tab must show only its own
/// rows, and every stepper must still write the field it names. A value that
/// moved to a tab but kept the old write path is exactly the regression the
/// inline tests could not catch.
void main() {
  late MockSettingsRepository repo;

  Future<void> pump(WidgetTester tester, {int tab = 0}) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    AppTheme.applyTheme(kind: ThemeKind.day, phase: TimePhase.day);
    SharedPreferences.setMockInitialValues({});
    repo = MockSettingsRepository()..setMockSettings(const AppSettings());
    final container = ProviderContainer(overrides: [
      settingsRepositoryProvider.overrideWith((ref) async => repo),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: WorshipScoringScreen(initialTab: tab),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
  }

  Future<void> tapPlus(WidgetTester tester, int index) async {
    final stepper = find.byType(SettingsStepper).at(index);
    await tester.tap(
      find.descendant(of: stepper, matching: find.byIcon(Icons.add_rounded)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pump(const Duration(milliseconds: 250));
  }

  testWidgets('opens on «نماز» with its three rows', (tester) async {
    await pump(tester);

    expect(find.text('هر نماز واجب (فرض)'), findsOneWidget);
    expect(find.text('هر سنت و وتر'), findsOneWidget);
    expect(find.text('نماز ضحی'), findsOneWidget);
    expect(find.byType(SettingsStepper), findsNWidgets(3));
  });

  testWidgets('each prayer stepper writes its own field', (tester) async {
    await pump(tester);
    final before = repo.getMockSettings();

    await tapPlus(tester, 0);
    expect(repo.getMockSettings().fardhPoint, before.fardhPoint + 1);

    await tapPlus(tester, 1);
    expect(repo.getMockSettings().sunnahPoint, before.sunnahPoint + 1);

    await tapPlus(tester, 2);
    expect(repo.getMockSettings().duhaPoint, before.duhaPoint + 1);
  });

  testWidgets('«اذکار» holds only adhkar + tasbih, and both still write',
      (tester) async {
    await pump(tester);
    await openTab(tester, 'اذکار');

    expect(find.text('اذکار صبح و شام'), findsOneWidget);
    expect(find.text('تسبیح'), findsOneWidget);
    expect(find.text('هر نماز واجب (فرض)'), findsNothing);
    expect(find.byType(SettingsStepper), findsNWidgets(2));

    final before = repo.getMockSettings();
    await tapPlus(tester, 0);
    expect(repo.getMockSettings().adhkarPoint, before.adhkarPoint + 1);

    await tapPlus(tester, 1);
    expect(repo.getMockSettings().tasbihPoint, before.tasbihPoint + 1);
  });

  testWidgets('«طاعات» carries the multiplier only, stepping by 25%',
      (tester) async {
    await pump(tester);
    await openTab(tester, 'طاعات');

    expect(find.text('طاعات (قرآن، صدقه و…)'), findsOneWidget);
    expect(find.byType(SettingsStepper), findsOneWidget);
    expect(repo.getMockSettings().worshipMultiplier, 1.0);

    await tapPlus(tester, 0);
    expect(repo.getMockSettings().worshipMultiplier, 1.25);
  });

  testWidgets('initialTab deep-links into a tab', (tester) async {
    await pump(tester, tab: 2);

    expect(find.text('طاعات (قرآن، صدقه و…)'), findsOneWidget);
    expect(find.text('هر نماز واجب (فرض)'), findsNothing);
  });

  testWidgets('an out-of-range initialTab falls back to «نماز»',
      (tester) async {
    await pump(tester, tab: 9);

    expect(find.text('هر نماز واجب (فرض)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the report link selects the evaluation tab, not a route',
      (tester) async {
    // The page is opened as a PUSHED route, the way «بیشتر ← تنظیمات» opens
    // it: the door must set the shell tab and pop back to the shell.
    // «ارزیابی و گزارش» is a shell tab (route_names.dart explains why a path
    // for it 404s), so pushing anything here would stack a dead page.
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    AppTheme.applyTheme(kind: ThemeKind.day, phase: TimePhase.day);
    SharedPreferences.setMockInitialValues({});
    repo = MockSettingsRepository()..setMockSettings(const AppSettings());
    final container = ProviderContainer(overrides: [
      settingsRepositoryProvider.overrideWith((ref) async => repo),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const WorshipScoringScreen()),
                  ),
                  child: const Text('open scoring'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open scoring'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(WorshipScoringScreen), findsOneWidget);
    expect(container.read(shellTabIndexProvider), 0);

    final link = find.text('دیدن گزارش با این امتیازها');
    await tester.ensureVisible(link);
    await tester.pumpAndSettle();
    await tester.tap(link);
    await tester.pumpAndSettle();

    expect(container.read(shellTabIndexProvider), 4);
    expect(find.byType(WorshipScoringScreen), findsNothing);
    expect(find.text('open scoring'), findsOneWidget,
        reason: 'the settings stack is closed and the shell is visible');
    expect(tester.takeException(), isNull);
  });
}

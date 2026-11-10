import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/pages/settings_screen.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_infra_providers.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/features/adhkar/presentation/providers/azkar_settings_provider.dart';

import '../../../../core/database/mock_daos.dart';
import '../fake_notification_infra.dart';

/// Functional audit of the redesigned main settings page: every control the
/// page offers must actually change the thing it claims to (and the change
/// must persist into the repository), and every navigation row must be wired.
///
/// The user's report — "before these changes everything was locked" — is
/// guarded here by tapping each control and asserting the persisted value, not
/// by reading the widget tree.
void main() {
  late MockSettingsRepository repo;

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    AppSettings settings = const AppSettings(),
    double width = 412,
    double height = 6000,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    AppTheme.applyTheme(kind: ThemeKind.day, phase: TimePhase.day);
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    repo = MockSettingsRepository()..setMockSettings(settings);
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
          theme: AppTheme.light,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    return container;
  }

  /// The + zone of the [index]th [SettingsStepper] in document order. This page
  /// owns exactly one (the Hijri offset): the six worship-point steppers moved
  /// to «امتیازدهی عبادات» (three tabs) on 2026-11-09 and are covered by
  /// worship_scoring_screen_test.dart.
  Future<void> tapPlus(WidgetTester tester, int index) async {
    final stepper = find.byType(SettingsStepper).at(index);
    await tester.tap(
      find.descendant(of: stepper, matching: find.byIcon(Icons.add_rounded)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('the page exposes only the Hijri stepper it owns',
      (tester) async {
    await pump(tester);
    expect(find.byType(SettingsStepper), findsOneWidget);
    // The scoring rows left for their own tabbed page; the settings page keeps
    // one door to them and no numbers.
    expect(find.text('تنظیم امتیازها'), findsOneWidget);
    expect(find.text('هر نماز واجب (فرض)'), findsNothing);
  });

  testWidgets('a theme-kind chip writes accentPreset and persists',
      (tester) async {
    await pump(tester);
    expect(repo.getMockSettings().accentPreset, isNot('gold'));

    // The page auto-reveals the selected chip (now the default «شب»), which
    // can leave «طلایی» scrolled out of the viewport — bring it in first.
    await tester.ensureVisible(find.text('طلایی'));
    await tester.pump();
    await tester.tap(find.text('طلایی'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(repo.getMockSettings().accentPreset, 'gold');
  });

  testWidgets('the {سیستم/روشن/تاریک} segment writes themeMode',
      (tester) async {
    await pump(tester);
    expect(repo.getMockSettings().themeMode, isNot(ThemeModeOption.dark));

    await tester.tap(find.text('تاریک'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(repo.getMockSettings().themeMode, ThemeModeOption.dark);
  });

  testWidgets('the hijri-offset stepper writes hijriOffset (+1 up, −1 down)',
      (tester) async {
    await pump(tester);
    final before = repo.getMockSettings().hijriOffset;

    await tapPlus(tester, 0);
    expect(repo.getMockSettings().hijriOffset, before + 1);

    final stepper = find.byType(SettingsStepper).at(0);
    await tester.tap(
      find.descendant(of: stepper, matching: find.byIcon(Icons.remove_rounded)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(repo.getMockSettings().hijriOffset, before);
  });

  // The five worship-point steppers and the multiplier moved to
  // «امتیازدهی عبادات» (three tabs). Their write path is pinned there, in
  // worship_scoring_screen_test.dart — same fields, same ranges.

  testWidgets('the tasbih volume slider writes azkar_sound_volume',
      (tester) async {
    final container = await pump(tester);

    final sliderRect = tester.getRect(find.byType(Slider).first);
    await tester.tapAt(Offset(
      sliderRect.left + sliderRect.width * 0.2,
      sliderRect.center.dy,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getDouble('azkar_sound_volume');
    expect(stored, isNotNull);
    expect(stored!, lessThan(1.0));
    expect(container.read(azkarSettingsProvider).tasbihVolume, stored);
  });

  testWidgets('the adhan volume slider writes azanVolume', (tester) async {
    await pump(tester);
    expect(repo.getMockSettings().azanVolume, 1.0);

    final row = find.ancestor(
      of: find.text('صدای اذان'),
      matching: find.byType(SettingsSliderRow),
    );
    expect(row, findsOneWidget);

    final slider = find.descendant(of: row, matching: find.byType(Slider));
    final rect = tester.getRect(slider);
    await tester.tapAt(Offset(
      rect.left + rect.width * 0.2,
      rect.center.dy,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(repo.getMockSettings().azanVolume, lessThan(1.0));

    // setAzanVolume debounces an alarm reschedule (350 ms); let it fire so the
    // test does not end with a pending timer.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  });

  testWidgets('an adhan-volume DRAG writes the store once with the last value',
      (tester) async {
    await pump(tester);

    final row = find.ancestor(
      of: find.text('صدای اذان'),
      matching: find.byType(SettingsSliderRow),
    );
    final slider = find.descendant(of: row, matching: find.byType(Slider));
    final rect = tester.getRect(slider);

    // A drag, not a tap: several onChanged ticks. Each used to cost one full
    // read-modify-write on Drift; the trailing writer must land exactly ONE
    // write carrying the value the finger released on.
    final gesture =
        await tester.startGesture(Offset(rect.left + 8, rect.center.dy));
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      await gesture.moveBy(const Offset(24, 0));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();

    expect(repo.updateCount, 1);
    expect(repo.getMockSettings().azanVolume, lessThan(1.0));

    // setAzanVolume debounces an alarm reschedule (350 ms); let it fire.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  });

  testWidgets('every navigation row is wired (no dead tiles)', (tester) async {
    await pump(tester);

    // The account hub, «پیام‌های مدیریت»، «ارسال پیشنهاد» and «درباره برنامه»
    // left this page for «بیشتر» (user decision, 2026-10-17); their door is
    // the More registry, asserted in more_registry_test.dart.
    const navTitles = <String>[
      'فونت و نمایش',
      'تنظیم امتیازها',
      'تنظیمات اذان و اقامه',
      'تنظیمات اعلان‌ها و اذکار',
      'تشخیص تنظیمات گوشی',
      'پیوست‌های اطلاعات من',
      'تنظیم ویجت‌های صفحه اصلی',
      'بهینه‌سازی باتری',
    ];
    for (final title in navTitles) {
      final rows = tester.widgetList<SettingRow>(find.ancestor(
          of: find.text(title), matching: find.byType(SettingRow)));
      expect(rows, isNotEmpty, reason: '«$title» has no SettingRow');
      expect(rows.every((r) => r.onTap != null), isTrue,
          reason: '«$title» is wired but its row has no onTap');
    }
  });

  testWidgets('a representative nav row pushes the route it names',
      (tester) async {
    tester.view.physicalSize = const Size(412, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    AppTheme.applyTheme(kind: ThemeKind.day, phase: TimePhase.day);
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(overrides: [
      settingsRepositoryProvider
          .overrideWith((ref) async => MockSettingsRepository()),
      dailyNotificationSchedulerProvider
          .overrideWithValue(FakeDailyNotificationScheduler()),
    ]);
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: RouteNames.settings,
      routes: [
        GoRoute(
          path: RouteNames.settings,
          builder: (_, __) => const SettingsScreen(),
          routes: [
            GoRoute(
              path: 'font',
              builder: (_, __) => Scaffold(
                appBar: AppBar(title: const Text('FONT')),
                body: const Center(child: Text('PAGE-FONT')),
              ),
            ),
            GoRoute(
              path: 'widget',
              builder: (_, __) => Scaffold(
                appBar: AppBar(title: const Text('WIDGET')),
                body: const Center(child: Text('PAGE-WIDGET')),
              ),
            ),
            GoRoute(
              path: 'notifications',
              builder: (_, __) => Scaffold(
                appBar: AppBar(title: const Text('NOTIF')),
                body: const Center(child: Text('PAGE-NOTIF')),
              ),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.text('فونت و نمایش'));
    await tester.pumpAndSettle();
    expect(find.text('PAGE-FONT'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('تنظیم ویجت‌های صفحه اصلی'));
    await tester.pumpAndSettle();
    expect(find.text('PAGE-WIDGET'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('تنظیمات اعلان‌ها و اذکار'));
    await tester.pumpAndSettle();
    expect(find.text('PAGE-NOTIF'), findsOneWidget);
  });
}

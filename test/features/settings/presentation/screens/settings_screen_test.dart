import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/settings/presentation/pages/settings_screen.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_infra_providers.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import '../../../../core/database/mock_daos.dart';
import '../fake_notification_infra.dart';

/// The main settings page after the Design-1 redesign: one search field on top,
/// seven grouped sections in a fixed reading order, «بهینه‌سازی باتری» last.
/// The account hub, «پیام‌های مدیریت»، «ارسال پیشنهاد» and «درباره برنامه»
/// live on «بیشتر» now (user decision, 2026-10-17) — the settings page keeps
/// no duplicate door.
///
/// These tests render under the REAL app theme on purpose: its button themes
/// carry full-width minimum sizes, so a button placed as a bare Row child only
/// breaks here, not under the test binding's default theme.
void main() {
  final sectionTitles = <String>[
    'ظاهر برنامه',
    'نماز و اذان',
    'صداهای برنامه',
    'امتیازدهی عبادات',
    'اعلان‌ها و اذکار',
    'ویجت‌ها',
    'سایر',
  ];

  late MockSettingsRepository repo;

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    AppSettings settings = const AppSettings(),
    double width = 412,
    double height = 6000,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    AppTheme.applyTheme(kind: ThemeKind.day, phase: TimePhase.day);
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    return container;
  }

  testWidgets('SettingsScreen renders with default settings', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pump(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('SettingsScreen renders with custom settings', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pump(
      tester,
      settings: const AppSettings(themeMode: ThemeModeOption.dark),
    );
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('the search field sits above every section', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pump(tester);

    expect(find.byType(SettingsSearchField), findsOneWidget);
    final fieldY =
        tester.getTopLeft(find.byType(SettingsSearchField)).dy;
    final firstSectionY = tester
        .getTopLeft(find.widgetWithText(SectionHeader, sectionTitles.first))
        .dy;
    expect(fieldY, lessThan(firstSectionY));

    // The old app-bar search icon is gone — the field is the only entry point.
    expect(find.byIcon(Icons.search), findsNothing);
  });

  testWidgets('the groups appear in the approved order', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pump(tester);

    for (final title in sectionTitles) {
      expect(find.widgetWithText(SectionHeader, title), findsOneWidget,
          reason: 'missing «$title»');
    }

    final ys = sectionTitles
        .map((t) => tester.getTopLeft(find.widgetWithText(SectionHeader, t)).dy)
        .toList(growable: false);
    for (var i = 1; i < ys.length; i++) {
      expect(ys[i], greaterThan(ys[i - 1]), reason: '«${sectionTitles[i]}»');
    }

    // …and «بهینه‌سازی باتری» is the last row on the page, inside «سایر»,
    // under the «مدیریت فضا» row.
    final storageY = tester.getTopLeft(find.text('مدیریت فضا')).dy;
    expect(storageY, greaterThan(ys.last));
    expect(
      tester.getTopLeft(find.text('بهینه‌سازی باتری')).dy,
      greaterThan(storageY),
    );
  });

  testWidgets('the More-owned rows stay off this page (no duplicates)',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pump(tester);

    // User decision (2026-10-17): these four doors are reachable from
    // «بیشتر» — «پیام‌های مدیریت»، «ارسال پیشنهاد»، «درباره برنامه» and the
    // account hub must not come back here as a second entry.
    for (final gone in [
      'حساب ابری و نسخه پشتیبان',
      'ارسال پیشنهاد',
      'پیام‌های مدیریت',
      'درباره برنامه',
    ]) {
      expect(find.text(gone), findsNothing, reason: '«$gone» is duplicated');
    }
    // …while the page keeps its own rows.
    expect(find.text('بهینه‌سازی باتری'), findsOneWidget);
    expect(find.text('تنظیم ویجت‌های صفحه اصلی'), findsOneWidget);
  });

  testWidgets('search results group under their page titles', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pump(tester);

    await tester.enterText(find.byType(SettingsSearchField), 'پشتیبان');
    // The field debounces 150 ms before it queries the registry.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // Hits are grouped under the page that owns each row…
    expect(find.widgetWithText(SectionHeader, 'حساب و پشتیبان'),
        findsOneWidget);
    // …and the plain sections step aside while a query is active.
    expect(
        find.widgetWithText(SectionHeader, 'ظاهر برنامه'), findsNothing);
    expect(find.text('بازگردانی پشتیبان'), findsOneWidget);

    // Clearing the field brings the sections back.
    await tester.enterText(find.byType(SettingsSearchField), '');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(
        find.widgetWithText(SectionHeader, 'ظاهر برنامه'), findsOneWidget);
  });

  testWidgets('a question typed into the field reaches the row', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pump(tester);

    // Filler words and the question mark are dropped instead of being required
    // to appear in a label — the row is found by «اذان» + «خاموش».
    await tester.enterText(
        find.byType(SettingsSearchField), 'چطور اذان را خاموش کنم؟');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('اذان فجر'), findsOneWidget);
  });

  testWidgets('the keyboard search key applies the query at once',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pump(tester);

    await tester.enterText(find.byType(SettingsSearchField), 'پشتیبان');
    // Submit BEFORE the 150 ms debounce could have fired: only onSubmitted can
    // make the results appear in this frame.
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();

    expect(find.text('بازگردانی پشتیبان'), findsOneWidget);
    // …and the keyboard is dismissed so the results are visible.
    expect(tester.testTextInput.isVisible, isFalse);
  });

  for (final width in [320.0, 360.0, 412.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('lays out at ${width.toInt()}dp x$scale with no overflow',
          (tester) async {
        SharedPreferences.setMockInitialValues({});
        // A tall viewport lays out every section in one pass, so an invalid
        // constraint anywhere on the page (not only what a drag happens to
        // reveal) fails the test.
        await pump(tester, width: width, textScale: scale);
        expect(tester.takeException(), isNull);

        await tester.scrollUntilVisible(find.text('بهینه‌سازی باتری'), 400,
            scrollable: find.byType(Scrollable).first, maxScrolls: 60);
        expect(tester.takeException(), isNull);

        // Let the notifier's 350 ms reschedule debounce fire.
        await tester.pump(const Duration(milliseconds: 500));
      });
    }
  }
}

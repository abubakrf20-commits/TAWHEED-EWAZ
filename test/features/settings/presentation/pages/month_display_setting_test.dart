import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/core/constants/date_constants.dart';
import 'package:tawheeed/core/constants/month_display.dart';
import 'package:tawheeed/core/theme/month_display_scope.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/pages/settings_screen.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_infra_providers.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';

import '../../../../core/database/mock_daos.dart';
import '../fake_notification_infra.dart';

/// «روش عرضه ماه» — Iranians name the solar months فروردین…اسفند, Afghans
/// name the SAME months حمل…حوت. The setting must:
///
/// * never touch the Shamsi arithmetic (names only — the calendar is identical),
/// * reach every surface app-wide through the single table in
///   [DateConstants] (no screen keeps its own copy),
/// * persist in the `month_display` pref and survive a cold start,
/// * repaint the surfaces that are already on screen when it flips, and
/// * follow the choice into the home-screen widget's snapshot, which is built
///   from a background service that must read the pref itself.
void main() {
  const afghanJoined =
      'حمل، ثور، جوزا، سرطان، اسد، سنبله، میزان، عقرب، قوس، جدی، دلو، حوت';
  const iranianJoined =
      'فروردین، اردیبهشت، خرداد، تیر، مرداد، شهریور، مهر، آبان، آذر، دی، بهمن، اسفند';

  setUp(() {
    monthDisplayNotifier.value = MonthDisplay.iranian;
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  tearDown(() {
    monthDisplayNotifier.value = MonthDisplay.iranian;
  });

  group('month tables', () {
    test('the two tables name the same twelve months', () {
      expect(DateConstants.iranianMonths, hasLength(12));
      expect(DateConstants.afghanMonths, hasLength(12));
      expect(DateConstants.iranianMonths.first, 'فروردین');
      expect(DateConstants.iranianMonths.last, 'اسفند');
      expect(DateConstants.afghanMonths, const [
        'حمل',
        'ثور',
        'جوزا',
        'سرطان',
        'اسد',
        'سنبله',
        'میزان',
        'عقرب',
        'قوس',
        'جدی',
        'دلو',
        'حوت',
      ]);
      for (final name in DateConstants.afghanMonths) {
        expect(DateConstants.iranianMonths, isNot(contains(name)));
      }
    });

    test('monthsFor picks the table and persianMonths follows the notifier',
        () {
      expect(DateConstants.monthsFor(MonthDisplay.iranian),
          same(DateConstants.iranianMonths));
      expect(DateConstants.monthsFor(MonthDisplay.afghan),
          same(DateConstants.afghanMonths));
      expect(DateConstants.persianMonths, same(DateConstants.iranianMonths));

      monthDisplayNotifier.value = MonthDisplay.afghan;
      expect(DateConstants.persianMonths, same(DateConstants.afghanMonths));
    });

    test('only the exact stored name «afghan» selects Afghan', () {
      expect(monthDisplayFromStored('afghan'), MonthDisplay.afghan);
      expect(monthDisplayFromStored('iranian'), MonthDisplay.iranian);
      expect(monthDisplayFromStored(null), MonthDisplay.iranian);
      expect(monthDisplayFromStored(''), MonthDisplay.iranian);
      expect(monthDisplayFromStored('AFGHAN'), MonthDisplay.iranian);
      expect(monthDisplayFromStored('persian'), MonthDisplay.iranian);
    });
  });

  group('persistence', () {
    test('setMonthDisplay stores the choice and load restores it', () async {
      await setMonthDisplay(MonthDisplay.afghan);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kMonthDisplayPrefKey), 'afghan');
      expect(await readStoredMonthDisplay(), MonthDisplay.afghan);

      // A cold start: the notifier holds its construction default until the
      // root wrapper loads the stored value.
      monthDisplayNotifier.value = MonthDisplay.iranian;
      expect(await loadMonthDisplay(), MonthDisplay.afghan);
      expect(monthDisplayNotifier.value, MonthDisplay.afghan);
    });

    test('an unset pref keeps the Iranian default, and iranian is stored', () async {
      expect(await readStoredMonthDisplay(), MonthDisplay.iranian);

      await setMonthDisplay(MonthDisplay.iranian);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kMonthDisplayPrefKey), 'iranian');
    });
  });

  group('repaint', () {
    testWidgets('a dependent under MonthDisplayScope rebuilds when it flips',
        (tester) async {
      await tester.pumpWidget(
        MonthDisplayScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                // Reading the month table inside build is the dependency.
                MonthDisplayScope.of(context);
                return Text(DateConstants.persianMonths.first);
              },
            ),
          ),
        ),
      );
      expect(find.text('فروردین'), findsOneWidget);

      monthDisplayNotifier.value = MonthDisplay.afghan;
      await tester.pump();

      expect(find.text('حمل'), findsOneWidget);
      expect(find.text('فروردین'), findsNothing);
    });
  });

  group('the settings row', () {
    late MockSettingsRepository repo;

    Future<void> pumpPage(WidgetTester tester, Widget page) async {
      tester.view.physicalSize = const Size(412, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      AppTheme.applyTheme(kind: ThemeKind.day, phase: TimePhase.day);
      repo = MockSettingsRepository()..setMockSettings(const AppSettings());
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
            home: page,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
    }

    testWidgets('lives in «فونت و نمایش» and lists the active names',
        (tester) async {
      await pumpPage(tester, const FontDisplayPage());

      expect(find.text('روش عرضه ماه'), findsOneWidget);
      expect(find.text('نام ماه‌های شمسی: ایرانی یا افغانی'), findsOneWidget);
      expect(find.text(iranianJoined), findsOneWidget);
      expect(find.text(afghanJoined), findsNothing);

      // Inside the one font/display card, after the font controls and the
      // clock toggle, before the Arabic-text switches.
      final rowY = tester.getTopLeft(find.text('روش عرضه ماه')).dy;
      for (final above in const [
        'فونت برنامه',
        'اندازه فونت',
        'ساعت 12 ساعته',
      ]) {
        expect(rowY, greaterThan(tester.getTopLeft(find.text(above)).dy),
            reason: '«$above» must stay above «روش عرضه ماه»');
      }
      expect(
          rowY,
          lessThan(tester.getTopLeft(find.text('نمایش متن عربی')).dy),
          reason: 'the month row sits before the Arabic-text switches');
      expect(tester.takeException(), isNull);
    });

    testWidgets('the main page no longer carries it; its tile says why',
        (tester) async {
      await pumpPage(tester, const SettingsScreen());

      expect(find.text('روش عرضه ماه'), findsNothing);
      expect(find.text('افغانی'), findsNothing);
      // The nav tile is the door, and its subtitle names the month choice.
      expect(find.text('انتخاب فونت، اندازه، نام ماه و متن عربی'),
          findsOneWidget);
    });

    testWidgets('«افغانی» stores the pref and the preview repaints',
        (tester) async {
      await pumpPage(tester, const FontDisplayPage());
      expect(monthDisplayNotifier.value, MonthDisplay.iranian);

      await tester.tap(find.text('افغانی'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(monthDisplayNotifier.value, MonthDisplay.afghan);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kMonthDisplayPrefKey), 'afghan');
      expect(find.text(afghanJoined), findsOneWidget);
      expect(find.text(iranianJoined), findsNothing);

      // …and back, so the choice is not one-way.
      await tester.tap(find.text('ایرانی'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(monthDisplayNotifier.value, MonthDisplay.iranian);
      expect(prefs.getString(kMonthDisplayPrefKey), 'iranian');
      expect(find.text(iranianJoined), findsOneWidget);
    });
  });

  group('wiring guards', () {
    test('no lib file keeps its own Iranian month table', () {
      // The single source is date_constants.dart; a local copy would silently
      // ignore the setting (that is how a screen keeps printing فروردین).
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll('\\', '/');
        if (path.endsWith('core/constants/date_constants.dart')) continue;
        final source = entity.readAsStringSync();
        if (source.contains("'فروردین'") || source.contains('"فروردین"')) {
          offenders.add(path);
        }
      }
      expect(offenders, isEmpty,
          reason: 'local month table(s) outside date_constants.dart: $offenders');
    });

    test('on-screen surfaces depend on the scope, the widget snapshot reads it',
        () {
      String read(String path) =>
          File(path).readAsStringSync().replaceAll('\r\n', '\n');

      // Both are already painted when the choice flips, so both must subscribe.
      for (final path in [
        'lib/features/home/presentation/widgets/hero_card.dart',
        'lib/features/prayer/presentation/widgets/prayer_widget_preview.dart',
      ]) {
        expect(read(path), contains('MonthDisplayScope.of(context)'),
            reason: '$path must repaint when the month names change');
      }

      // The native home-screen widget is rendered by a background sync that
      // cannot see the notifier — it must read the stored pref itself.
      final sync = read('lib/shared/services/widget_sync_service.dart');
      expect(sync, contains('readStoredMonthDisplay'));
      expect(sync, isNot(contains('DateConstants.persianMonths')));
    });
  });
}

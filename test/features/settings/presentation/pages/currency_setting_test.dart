import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/pages/settings_screen.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_infra_providers.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/shared/models/app_currency.dart';
import 'package:tawheeed/shared/services/currency_store.dart';

import '../../../../core/database/mock_daos.dart';
import '../fake_notification_infra.dart';

/// «واحد پول» — the one place that shows BOTH currency stores.
///
/// The two are deliberately separate (see [CurrencyStore]): the calculators'
/// unit is the scale of a calculation, the ledger's unit is a label on money
/// that is already stored and never converted. The row must therefore:
///
/// * reveal both current units (and read them, so a cold start into settings
///   does not show «تومان» to a user who picked dollars),
/// * write each store's key and nothing else,
/// * warn, in the ledger dialog, that stored amounts are not converted, and
/// * keep the in-memory notifiers in step, because the zakat and expenses
///   screens stay alive in other tabs and listen to them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    CurrencyStore.calculators.notifier.value = AppCurrency.toman;
    CurrencyStore.ledger.notifier.value = AppCurrency.toman;
  });

  tearDown(() {
    CurrencyStore.calculators.notifier.value = AppCurrency.toman;
    CurrencyStore.ledger.notifier.value = AppCurrency.toman;
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    AppTheme.applyTheme(kind: ThemeKind.day, phase: TimePhase.day);
    final repo = MockSettingsRepository()..setMockSettings(const AppSettings());
    final container = ProviderContainer(overrides: [
      settingsRepositoryProvider.overrideWith((ref) async => repo),
      dailyNotificationSchedulerProvider
          .overrideWithValue(FakeDailyNotificationScheduler()),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.light, home: const SettingsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
  }

  group('the section', () {
    testWidgets('shows both stores, each with its current unit',
        (tester) async {
      await pumpSettings(tester);

      expect(find.text('واحد پول'), findsOneWidget);
      expect(find.text('واحد حساب‌گرها'), findsOneWidget);
      expect(find.text('واحد دفتر هزینه‌ها'), findsOneWidget);
      expect(find.text('زکات، فطر، میراث، کفاره، قلک، بدهی و مغازه — تومان'),
          findsOneWidget);
      expect(find.text('برچسب مبالغ ثبت‌شده — تومان'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reads the stored units on open (cold start into settings)',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'app_currency_code': 'EUR',
        'expenses_currency_code': 'AED',
      });
      await pumpSettings(tester);

      expect(find.text('زکات، فطر، میراث، کفاره، قلک، بدهی و مغازه — یورو'),
          findsOneWidget);
      expect(find.text('برچسب مبالغ ثبت‌شده — درهم امارات'), findsOneWidget);
    });
  });

  group('the calculators dialog', () {
    testWidgets('«دلخواه» saves the unit the user writes', (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.text('واحد حساب‌گرها'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('دلخواه…'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'سکه');
      await tester.tap(find.text('تأیید'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ذخیره'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_currency_code'), AppCurrency.customCode);
      expect(prefs.getString('app_currency_code_custom_name'), 'سکه');
      expect(CurrencyStore.calculators.notifier.value.isCustom, isTrue);
      expect(find.text('زکات، فطر، میراث، کفاره، قلک، بدهی و مغازه — سکه'),
          findsOneWidget);
    });

    testWidgets('writes app_currency_code and leaves the ledger alone',
        (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.text('واحد حساب‌گرها'));
      await tester.pumpAndSettle();
      expect(find.text('دلار آمریکا'), findsOneWidget);

      await tester.tap(find.text('دلار آمریکا'));
      await tester.pump();
      await tester.tap(find.text('ذخیره'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_currency_code'), 'USD');
      expect(prefs.getString('expenses_currency_code'), isNull);
      // The notifier is the only channel the live zakat/inheritance screens
      // listen on, so it must carry the new value.
      expect(CurrencyStore.calculators.notifier.value, AppCurrency.dollar);
      expect(CurrencyStore.ledger.notifier.value, AppCurrency.toman);
      expect(
          find.text('زکات، فطر، میراث، کفاره، قلک، بدهی و مغازه — دلار آمریکا'),
          findsOneWidget);
    });

    testWidgets('«انصراف» writes nothing', (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.text('واحد حساب‌گرها'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('یورو'));
      await tester.pump();
      await tester.tap(find.text('انصراف'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_currency_code'), isNull);
      expect(CurrencyStore.calculators.notifier.value, AppCurrency.toman);
    });
  });

  group('the ledger dialog', () {
    testWidgets(
        'warns that amounts are not converted, then writes only its key',
        (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.text('واحد دفتر هزینه‌ها'));
      await tester.pumpAndSettle();
      expect(
          find.textContaining('مبالغ ثبت‌شده تبدیل نمی‌شوند'), findsOneWidget);

      await tester.tap(find.text('افغانی افغانستان'));
      await tester.pump();
      await tester.tap(find.text('ذخیره'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('expenses_currency_code'), 'AFN');
      expect(prefs.getString('app_currency_code'), isNull);
      expect(CurrencyStore.ledger.notifier.value, AppCurrency.afghani);
      expect(CurrencyStore.calculators.notifier.value, AppCurrency.toman);
    });
  });

  group('search', () {
    testWidgets('«دلار» finds the currency row', (tester) async {
      await pumpSettings(tester);

      await tester.enterText(find.byType(TextField).first, 'دلار');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      // The result card prints the row's own title + subtitle, so the hit is
      // the currency section and not some other money-ish row.
      expect(find.text('واحد پول'), findsOneWidget);
      expect(
          find.text('واحد همهٔ بخش‌های مالی: زکات، فطر، میراث، کفاره، قلک، '
              'بدهی، مغازه و هزینه‌ها'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

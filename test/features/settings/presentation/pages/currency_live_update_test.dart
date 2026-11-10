import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/expenses/data/repositories/expense_repository.dart';
import 'package:tawheeed/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:tawheeed/features/expenses/domain/entities/expense_model.dart';
import 'package:tawheeed/features/expenses/presentation/screens/expenses_screen.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/pages/settings_screen.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_infra_providers.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/features/tools/zakat/presentation/screens/zakat_screen.dart';
import 'package:tawheeed/shared/models/app_currency.dart';
import 'package:tawheeed/shared/services/currency_store.dart';

import '../../../../core/database/mock_daos.dart';
import '../fake_notification_infra.dart';

/// The settings page is the ONLY writer of both currency stores, and the zakat
/// and expenses screens stay alive in other tabs while the reader is in it.
///
/// So the interesting question is not "does the dialog write prefs" — that is
/// [currency_setting_test] — but "do the screens that are already open follow
/// the write". Both listen on their own store's `notifier`; if that wiring ever
/// breaks, the labels stay on the old unit until the tab is rebuilt, and the
/// reader believes their nisab is in a currency it is not.
///
/// The harness keeps both screens mounted at once (the app's tab shell does the
/// same with an `IndexedStack`) and pushes the real settings page on top, so
/// each change travels the production path: row → dialog → `save()` → notifier
/// → live `setState`. Nothing is reopened between the write and the assert.
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

  Future<void> pumpApp(WidgetTester tester, {int index = 0}) async {
    tester.view.physicalSize = const Size(900, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    AppTheme.applyTheme(kind: ThemeKind.day, phase: TimePhase.day);
    final settings = MockSettingsRepository()
      ..setMockSettings(const AppSettings());
    final ledger = _MockExpenseRepository()
      ..items = [
        ExpenseModel(
          id: '1',
          title: 'حقوق',
          amount: 500000,
          isIncome: true,
          category: 'عمومی',
          date: DateTime.now(),
        ),
      ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          expenseRepositoryProvider.overrideWithValue(ledger),
          settingsRepositoryProvider.overrideWith((ref) async => settings),
          dailyNotificationSchedulerProvider
              .overrideWithValue(FakeDailyNotificationScheduler()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: _Shell(index: index),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Pushes the real settings page over the open screens and returns the
  /// navigator, so a test can go back the way the reader does.
  Future<NavigatorState> openSettings(WidgetTester tester) async {
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(navigator.push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('واحد پول'), findsOneWidget);
    return navigator;
  }

  Future<void> pickCurrency(
    WidgetTester tester, {
    required String row,
    required String currency,
  }) async {
    await tester.tap(find.text(row));
    await tester.pumpAndSettle();
    await tester.tap(find.text(currency));
    await tester.pump();
    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();
  }

  /// Every money field and the unit it is labelled with, read off the
  /// `suffixText` the calculator actually paints — plus every non-money field
  /// (`گرم`, `رأس`, `‰`) left out, so the assertion is about currency only.
  Map<String, String> moneyFieldUnits(WidgetTester tester) {
    final units = {for (final c in AppCurrency.values) c.unit};
    final out = <String, String>{};
    for (final field in tester.widgetList<TextField>(
      find.byType(TextField, skipOffstage: false),
    )) {
      final suffix = field.decoration?.suffixText;
      if (suffix != null && units.contains(suffix)) {
        out[field.decoration?.labelText ?? '(unnamed)'] = suffix;
      }
    }
    return out;
  }

  void expectZakatUnit(WidgetTester tester, String unit, {String? reason}) {
    // «دارایی دلاری» asks *how many dollars* are held, so its label is always
    // «دلار» whatever unit the nisab is counted in; every other money field
    // speaks the calculator's unit.
    final fields = moneyFieldUnits(tester)..remove('دارایی دلاری');
    expect(fields, isNotEmpty, reason: 'صفحهٔ زکات هیچ فیلد پولی نشان نداد');
    expect(
      fields.values.toSet(),
      {unit},
      reason: [if (reason != null) reason, 'فیلدها: $fields'].join(' — '),
    );
  }

  group('the calculators unit', () {
    testWidgets('reaches the open zakat screen without reopening it',
        (tester) async {
      await pumpApp(tester);
      expectZakatUnit(tester, 'تومان');

      await openSettings(tester);
      await pickCurrency(
        tester,
        row: 'واحد حساب‌گرها',
        currency: 'دلار آمریکا',
      );

      // Still under the settings route, never rebuilt from prefs: the live
      // listener is what moved the labels.
      expectZakatUnit(
        tester,
        'دلار',
        reason: 'صفحهٔ باز زکات باید از همان کانال باخبر شود',
      );
      // …and it must not have dragged the ledger's label with it.
      expect(find.text('500,000 تومان', skipOffstage: false), findsOneWidget);
    });

    testWidgets('is still there after coming back from settings',
        (tester) async {
      await pumpApp(tester);
      final navigator = await openSettings(tester);
      await pickCurrency(
        tester,
        row: 'واحد حساب‌گرها',
        currency: 'یورو',
      );

      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('واحد پول'), findsNothing);
      expectZakatUnit(tester, 'یورو');
      expect(CurrencyStore.calculators.current, AppCurrency.euro);
    });
  });

  group('the ledger unit', () {
    testWidgets('relabels the amounts already in the open expenses screen',
        (tester) async {
      await pumpApp(tester, index: 1);
      expect(find.text('500,000 تومان'), findsOneWidget);

      await openSettings(tester);
      await pickCurrency(
        tester,
        row: 'واحد دفتر هزینه‌ها',
        currency: 'افغانی افغانستان',
      );

      expect(find.text('500,000 افغانی', skipOffstage: false), findsOneWidget);
      expect(find.text('500,000 تومان', skipOffstage: false), findsNothing);
      // The stored number is untouched — only its unit changed.
      expect(CurrencyStore.ledger.current, AppCurrency.afghani);
      expectZakatUnit(tester, 'تومان',
          reason: 'واحد دفتر نباید واحد حساب‌گرها را عوض کند');
    });

    testWidgets('is visible on the page once settings closes', (tester) async {
      await pumpApp(tester, index: 1);
      final navigator = await openSettings(tester);
      await pickCurrency(
        tester,
        row: 'واحد دفتر هزینه‌ها',
        currency: 'دینار عراق',
      );

      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('500,000 دینار'), findsOneWidget);
      expect(find.text('500,000 تومان', skipOffstage: false), findsNothing);
    });
  });

  group('one visit, both stores', () {
    testWidgets('each screen follows its own unit, not the other one',
        (tester) async {
      await pumpApp(tester);
      final navigator = await openSettings(tester);
      await pickCurrency(tester, row: 'واحد حساب‌گرها', currency: 'یورو');
      await pickCurrency(
        tester,
        row: 'واحد دفتر هزینه‌ها',
        currency: 'دینار عراق',
      );

      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expectZakatUnit(tester, 'یورو');
      expect(find.text('500,000 دینار', skipOffstage: false), findsOneWidget);
      expect(CurrencyStore.calculators.current, AppCurrency.euro);
      expect(CurrencyStore.ledger.current, AppCurrency.iraqiDinar);
    });

    testWidgets('«انصراف» leaves the open screens on the old unit',
        (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      await tester.tap(find.text('واحد حساب‌گرها'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('دلار آمریکا'));
      await tester.pump();
      await tester.tap(find.text('انصراف'));
      await tester.pumpAndSettle();

      expect(CurrencyStore.calculators.current, AppCurrency.toman);
      expectZakatUnit(tester, 'تومان');
      expect(tester.takeException(), isNull);
    });
  });
}

/// Both live tabs, like the app's shell: the unselected one stays mounted and
/// listening, which is exactly the case this guard is about.
class _Shell extends StatelessWidget {
  const _Shell({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: const [
          ZakatScreen(),
          ExpensesScreen(),
        ],
      ),
    );
  }
}

class _MockExpenseRepository implements ExpenseRepository {
  List<ExpenseModel> items = [];
  Map<String, double> budgets = {};

  @override
  Future<List<ExpenseModel>> load() async => List.of(items);

  @override
  Future<void> save(List<ExpenseModel> expenses) async {
    items = List.of(expenses);
  }

  @override
  Future<void> migrateFromLegacyIfNeeded() async {}

  @override
  Future<Map<String, double>> loadBudgets() async => budgets;

  @override
  Future<void> saveBudget(String category, double monthlyLimit) async {}

  @override
  Future<void> deleteBudget(String category) async {}
}

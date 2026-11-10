import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/features/expenses/data/repositories/expense_repository.dart';
import 'package:tawheeed/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:tawheeed/features/expenses/domain/entities/expense_model.dart';
import 'package:tawheeed/features/expenses/presentation/screens/expense_report_screen.dart';
import 'package:tawheeed/features/tools/zakat/presentation/screens/zakat_screen.dart';
import 'package:tawheeed/shared/models/app_currency.dart';
import 'package:tawheeed/shared/services/currency_store.dart';

class _Repo implements ExpenseRepository {
  _Repo(this.items);

  List<ExpenseModel> items;

  @override
  Future<List<ExpenseModel>> load() async => List.of(items);

  @override
  Future<void> save(List<ExpenseModel> expenses) async {
    items = List.of(expenses);
  }

  @override
  Future<void> migrateFromLegacyIfNeeded() async {}

  @override
  Future<Map<String, double>> loadBudgets() async => {};

  @override
  Future<void> saveBudget(String category, double monthlyLimit) async {}

  @override
  Future<void> deleteBudget(String category) async {}
}

void main() {
  final now = DateTime(2026, 10, 21); // Jalali 1405

  ExpenseModel row(double amount, DateTime date, {bool income = false}) =>
      ExpenseModel(
        id: '${date.millisecondsSinceEpoch}-$amount-$income',
        title: income ? 'income' : 'expense',
        amount: amount,
        isIncome: income,
        date: date,
      );

  group('zakatPrefillAmount', () {
    test('uses only the current Jalali year, not the lifetime net', () {
      final expenses = [
        // 1403/1404 rows must not leak into this year's balance.
        row(900000, DateTime(2024, 5, 2), income: true),
        row(400000, DateTime(2025, 5, 2)),
        row(300000, DateTime(2026, 5, 2), income: true),
        row(120000, DateTime(2026, 8, 2)),
      ];

      expect(
        ExpenseReportScreen.zakatPrefillAmount(expenses, now),
        closeTo(180000, 0.001),
      );
    });

    test('a negative year balance pre-fills nothing', () {
      final expenses = [
        row(100000, DateTime(2026, 5, 2), income: true),
        row(250000, DateTime(2026, 8, 2)),
      ];

      expect(ExpenseReportScreen.zakatPrefillAmount(expenses, now), 0);
    });

    test('an empty list pre-fills nothing', () {
      expect(ExpenseReportScreen.zakatPrefillAmount(const [], now), 0);
    });
  });

  /// The balance is counted in the LEDGER's unit and the calculator opens in
  /// the CALCULATORS' unit. Handing the number across without reconciling the
  /// two would compare a foreign-currency amount against a nisab expressed in
  /// the calculator's unit — a wrong zakat answer, not a cosmetic slip. The
  /// report therefore never converts and never switches a unit: «واحد پول» is
  /// changed in the settings only, so the calculator drops the figure itself.
  group('the zakat handoff across two units', () {
    Future<void> pumpReport(
      WidgetTester tester, {
      required AppCurrency ledger,
      required AppCurrency calculators,
    }) async {
      SharedPreferences.setMockInitialValues({
        'expenses_currency_code': ledger.code,
        'app_currency_code': calculators.code,
      });
      CurrencyStore.ledger.notifier.value = AppCurrency.toman;
      CurrencyStore.calculators.notifier.value = AppCurrency.toman;
      tester.view.physicalSize = const Size(420, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = _Repo([row(500000, DateTime.now(), income: true)]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [expenseRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: ExpenseReportScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    String cashText(WidgetTester tester) => tester
        .widget<TextField>(find.widgetWithText(TextField, 'پول نقد'))
        .controller!
        .text;

    testWidgets('same unit: the balance is carried straight through',
        (tester) async {
      await pumpReport(tester,
          ledger: AppCurrency.afghani, calculators: AppCurrency.afghani);

      await tester.tap(find.textContaining('محاسبه زکات مانده امسال'));
      await tester.pumpAndSettle();

      expect(find.byType(ZakatScreen), findsOneWidget);
      expect(cashText(tester), '500000');
      expect(find.text('واحد پول یکی نیست'), findsNothing);
    });

    testWidgets('different unit: opens at once, never asks, never switches',
        (tester) async {
      await pumpReport(tester,
          ledger: AppCurrency.afghani, calculators: AppCurrency.toman);
      final prefs = await SharedPreferences.getInstance();
      final calculatorsKeyBefore = prefs.getString('app_currency_code');
      final ledgerKeyBefore = prefs.getString('expenses_currency_code');

      await tester.tap(find.textContaining('محاسبه زکات مانده امسال'));
      await tester.pumpAndSettle();

      // No prompt stands between the report and the calculator.
      expect(find.text('واحد پول یکی نیست'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(ZakatScreen), findsOneWidget);

      // The ledger says «افغانی» and the calculator counts in «تومان», so the
      // calculator keeps the figure out of its field and says why — the report
      // no longer decides this for it.
      expect(cashText(tester), isEmpty);
      expect(find.textContaining('به واحد دیگری بود و وارد نشد'), findsOneWidget);

      // Neither store is rewritten by opening the calculator.
      expect(CurrencyStore.calculators.current, AppCurrency.toman);
      expect(CurrencyStore.ledger.current, AppCurrency.afghani);
      expect(prefs.getString('app_currency_code'), calculatorsKeyBefore);
      expect(prefs.getString('expenses_currency_code'), ledgerKeyBefore);
    });
  });
}

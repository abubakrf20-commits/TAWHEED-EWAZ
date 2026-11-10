import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/features/expenses/data/repositories/expense_repository.dart';
import 'package:tawheeed/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:tawheeed/features/expenses/domain/entities/expense_model.dart';
import 'package:tawheeed/features/expenses/presentation/screens/expenses_screen.dart';
import 'package:tawheeed/shared/models/app_currency.dart';
import 'package:tawheeed/shared/services/currency_store.dart';

class MockExpenseRepository implements ExpenseRepository {
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/shared_preferences'),
    (methodCall) async {
      if (methodCall.method == 'getAll') {
        return <String, dynamic>{};
      }
      if (methodCall.method == 'setValue') {
        return true;
      }
      return null;
    },
  );

  testWidgets('added expense appears in the list', (tester) async {
    final repo = MockExpenseRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [expenseRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: ExpensesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('هنوز تراکنشی ثبت نشده'), findsOneWidget);

    await tester.tap(find.widgetWithText(FloatingActionButton, 'تراکنش جدید'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'خرید نان');
    await tester.enterText(find.byType(TextField).at(1), '15000');
    // The dialog grew (recurrence row); scroll the save button into view.
    await tester.ensureVisible(find.text('ذخیره'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();

    expect(find.text('خرید نان'), findsOneWidget);
    expect(find.text('هنوز تراکنشی ثبت نشده'), findsNothing);

    await tester.pump(const Duration(milliseconds: 400));
    expect(repo.items.length, 1);
    expect(repo.items.first.title, 'خرید نان');
    expect(repo.items.first.amount, 15000);
  });

  testWidgets('persisted expense loads back on rebuild', (tester) async {
    final repo = MockExpenseRepository()
      ..items = [
        ExpenseModel(
          id: '1',
          title: 'قبض برق',
          amount: 200000,
          date: DateTime.now(),
        ),
      ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [expenseRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: ExpensesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('قبض برق'), findsOneWidget);
  });

  testWidgets(
      'empty state shows the financial virtues and CTA opens the '
      'dialog', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = MockExpenseRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [expenseRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: ExpensesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ساماندهی مالی'), findsOneWidget);
    expect(find.text('افزودن اولین تراکنش'), findsOneWidget);
    expect(find.text('قناعت، ثروتی است که هیچ‌کس نمی‌تواند از تو بگیرد'),
        findsOneWidget);

    await tester.tap(find.text('افزودن اولین تراکنش'));
    await tester.pumpAndSettle();
    // Dialog title (the FAB behind the sheet shares the same label).
    expect(find.text('تراکنش جدید'), findsWidgets);
    expect(find.text('تاریخ تراکنش'), findsOneWidget);
  });

  testWidgets(
      'hero, this-month card and time sections render from persisted '
      'data', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final now = DateTime.now();
    final repo = MockExpenseRepository()
      ..items = [
        ExpenseModel(
          id: '1',
          title: 'حقوق',
          amount: 500000,
          isIncome: true,
          category: 'عمومی',
          date: now,
        ),
        ExpenseModel(
          id: '2',
          title: 'قبض برق',
          amount: 200000,
          category: 'قبض',
          date: now,
        ),
        ExpenseModel(
          id: '3',
          title: 'بیمه',
          amount: 100000,
          category: 'عمومی',
          date: now.subtract(const Duration(days: 40)),
        ),
      ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [expenseRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: ExpensesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Hero: total balance = 500k income − 300k expense = 200k.
    expect(find.text('مانده کل'), findsOneWidget);
    expect(find.text('200,000 تومان'), findsOneWidget);

    // This-month card + its section label.
    expect(find.text('این ماه'), findsWidgets);
    expect(find.text('بیشترین هزینه ماه: قبض'), findsOneWidget);

    // Time-bucket sections.
    expect(find.text('امروز'), findsOneWidget);
    expect(find.text('گذشته'), findsOneWidget);
    expect(find.text('حقوق'), findsOneWidget);
    expect(find.text('قبض برق'), findsOneWidget);
    expect(find.text('بیمه'), findsOneWidget);

    // The weekly income/expense row was removed per product decision —
    // month stats only.
    expect(find.text('درآمد هفته'), findsNothing);
    expect(find.text('هزینه هفته'), findsNothing);
  });

  testWidgets('the «این ماه» filter keeps only this month transactions',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final now = DateTime.now();
    final repo = MockExpenseRepository()
      ..items = [
        ExpenseModel(
          id: '1',
          title: 'قبض برق',
          amount: 200000,
          category: 'قبض',
          date: now,
        ),
        ExpenseModel(
          id: '2',
          title: 'بیمه',
          amount: 100000,
          category: 'عمومی',
          date: now.subtract(const Duration(days: 40)),
        ),
      ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [expenseRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: ExpensesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('بیمه'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('expense_filter_month')));
    await tester.pumpAndSettle();

    expect(find.text('قبض برق'), findsOneWidget);
    expect(find.text('بیمه'), findsNothing);
  });

  testWidgets('search narrows the list and shows the not-found message',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final now = DateTime.now();
    final repo = MockExpenseRepository()
      ..items = [
        ExpenseModel(
            id: '1',
            title: 'قبض برق',
            amount: 200000,
            category: 'قبض',
            date: now),
        ExpenseModel(
            id: '2',
            title: 'بیمه',
            amount: 100000,
            category: 'عمومی',
            date: now),
      ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [expenseRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: ExpensesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('expense_search_btn')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'برق');
    await tester.pumpAndSettle();

    expect(find.text('قبض برق'), findsOneWidget);
    expect(find.text('بیمه'), findsNothing);

    // Nothing matches → «موردی یافت نشد», not the empty-ledger message.
    await tester.enterText(find.byType(TextField), 'چیزی نیست');
    await tester.pumpAndSettle();
    expect(find.text('موردی یافت نشد'), findsOneWidget);
    expect(find.text('هنوز تراکنشی ثبت نشده'), findsNothing);
  });

  testWidgets('the duplicate category chip row is gone', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final now = DateTime.now();
    final repo = MockExpenseRepository()
      ..items = [
        ExpenseModel(
            id: '1',
            title: 'قبض برق',
            amount: 200000,
            category: 'قبض',
            date: now),
        ExpenseModel(
            id: '2',
            title: 'بیمه',
            amount: 100000,
            category: 'عمومی',
            date: now),
      ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [expenseRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: ExpensesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Removed per product decision: the second chip row («همه دسته‌ها» +
    // per-category chips) duplicated the search/category narrowing.
    expect(find.byKey(const ValueKey('expense_category_قبض')), findsNothing);
    expect(find.byKey(const ValueKey('expense_category_all')), findsNothing);
  });

  testWidgets('the category menu narrows the list in two taps', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final now = DateTime.now();
    final repo = MockExpenseRepository()
      ..items = [
        ExpenseModel(
            id: '1',
            title: 'قبض برق',
            amount: 200000,
            category: 'قبض',
            date: now),
        ExpenseModel(
            id: '2',
            title: 'بیمه',
            amount: 100000,
            category: 'عمومی',
            date: now),
      ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [expenseRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: ExpensesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('expense_category_filter')));
    await tester.pumpAndSettle();
    // The menu entry — the tile behind the overlay shares the label, and the
    // overlay is later in the tree.
    await tester.tap(find.text('عمومی').last);
    await tester.pumpAndSettle();

    expect(find.text('بیمه'), findsOneWidget);
    expect(find.text('قبض برق'), findsNothing);

    // «همه دسته‌ها» clears it again.
    await tester.tap(find.byKey(const ValueKey('expense_category_filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('همه دسته‌ها'));
    await tester.pumpAndSettle();

    expect(find.text('قبض برق'), findsOneWidget);
    expect(find.text('بیمه'), findsOneWidget);
  });

  testWidgets('an over-budget transaction warns in the dialog and again after',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = MockExpenseRepository()
      ..items = [
        ExpenseModel(
            id: '1',
            title: 'بیمه',
            amount: 100000,
            category: 'عمومی',
            date: DateTime.now()),
      ]
      ..budgets = {'عمومی': 100000};

    await tester.pumpWidget(
      ProviderScope(
        overrides: [expenseRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: ExpensesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FloatingActionButton, 'تراکنش جدید'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'خرید');
    await tester.enterText(find.byType(TextField).at(1), '50000');
    await tester.pumpAndSettle();

    // Category defaults to «عمومی» and the date to today, so the 100,000
    // ceiling is already spent and this 50,000 crosses it — warned live,
    // before any save.
    expect(find.textContaining('رد می‌شود'), findsOneWidget);

    await tester.ensureVisible(find.text('ذخیره'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();

    expect(find.textContaining('رد شد'), findsOneWidget);
  });

  testWidgets('واحد پول دفتر هزینه‌ها جداست و برچسب مبالغ را عوض می‌کند',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = MockExpenseRepository()
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

    // واحد حسابگرها روی دلار است تا نشان دهد دفتر هزینه‌ها به آن نگاه نمی‌کند.
    await CurrencyStore.calculators.save(AppCurrency.dollar);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [expenseRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: ExpensesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('500,000 تومان'), findsOneWidget,
        reason: 'دفتر پیش‌فرض تومانی است، نه دلارِ حسابگرها');

    // No currency picker lives on this page any more: the unit is chosen in
    // Settings only, so the AppBar carries no unit action.
    expect(find.byKey(const ValueKey('expense_currency_btn')), findsNothing);
    expect(find.byIcon(Icons.payments_outlined), findsNothing);

    await CurrencyStore.ledger.save(AppCurrency.afghani);
    await tester.pumpAndSettle();

    expect(find.text('500,000 افغانی'), findsOneWidget);
    expect(CurrencyStore.ledger.current, AppCurrency.afghani);
    expect(CurrencyStore.calculators.current, AppCurrency.dollar,
        reason: 'تغییر واحد دفتر نباید واحد حسابگرها را عوض کند');
  });

  testWidgets('تغییر واحد دفتر از صفحهٔ تنظیمات، برچسب این صفحه را هم عوض می‌کند',
      (tester) async {
    tester.view.physicalSize = const Size(420, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await CurrencyStore.ledger.save(AppCurrency.toman);
    final repo = MockExpenseRepository()
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
        overrides: [expenseRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: ExpensesScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('500,000 تومان'), findsOneWidget);

    // همان نوشتنی که ردیف «واحد دفتر هزینه‌ها» در تنظیمات انجام می‌دهد؛ این
    // صفحه در تب دیگری زنده است و باید از همین کانال باخبر شود.
    await CurrencyStore.ledger.save(AppCurrency.afghani);
    await tester.pumpAndSettle();

    expect(find.text('500,000 افغانی'), findsOneWidget);
    expect(find.text('500,000 تومان'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

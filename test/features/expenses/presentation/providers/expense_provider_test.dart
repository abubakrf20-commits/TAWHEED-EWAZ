import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/expenses/data/repositories/expense_repository.dart';
import 'package:tawheeed/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:tawheeed/features/expenses/domain/entities/expense_model.dart';
import 'package:tawheeed/features/expenses/presentation/providers/expense_provider.dart';

class MockExpenseRepository implements ExpenseRepository {
  List<ExpenseModel> items = [];
  final Map<String, double> budgets = {};
  int saveCalls = 0;

  @override
  Future<List<ExpenseModel>> load() async => List.of(items);

  @override
  Future<void> save(List<ExpenseModel> expenses) async {
    saveCalls++;
    items = List.of(expenses);
  }

  @override
  Future<void> migrateFromLegacyIfNeeded() async {}

  @override
  Future<Map<String, double>> loadBudgets() async => Map.of(budgets);

  @override
  Future<void> saveBudget(String category, double monthlyLimit) async {
    budgets[category] = monthlyLimit;
  }

  @override
  Future<void> deleteBudget(String category) async {
    budgets.remove(category);
  }
}

/// Repository whose initial-load step blocks until [gate] completes, so the
/// provider can be disposed while `_load()` is still awaiting inside it.
class _BlockingRepo extends MockExpenseRepository {
  final gate = Completer<void>();

  @override
  Future<void> migrateFromLegacyIfNeeded() => gate.future;
}

/// Repository that refuses the first read and works afterwards, so a retry
/// can be observed succeeding.
class _FlakyRepo extends MockExpenseRepository {
  bool failNextLoad = true;

  @override
  Future<List<ExpenseModel>> load() async {
    if (failNextLoad) {
      failNextLoad = false;
      throw StateError('database is locked');
    }
    return List.of(items);
  }
}

/// Repository whose writes can be made to fail on demand.
class _SaveFailingRepo extends MockExpenseRepository {
  bool failSave = true;

  @override
  Future<void> save(List<ExpenseModel> expenses) async {
    if (failSave) throw StateError('disk full');
    await super.save(expenses);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a finished load marks expensesLoadedProvider ready', () async {
    final repo = MockExpenseRepository();
    final container = ProviderContainer(
      overrides: [expenseRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    expect(container.read(expensesLoadedProvider), ExpensesLoadStatus.loading);
    container.read(expenseListProvider);
    await container.pump();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(container.read(expensesLoadedProvider), ExpensesLoadStatus.ready);
  });

  test('a failed load marks expensesLoadedProvider failed, not ready',
      () async {
    // The defect this guards: `loaded` used to mean "the read finished",
    // success or not, so a broken query showed the «no transactions yet»
    // onboarding to a reader whose ledger was simply unreadable.
    final repo = _FlakyRepo()..failNextLoad = true;
    final container = ProviderContainer(
      overrides: [expenseRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    container.read(expenseListProvider);
    await container.pump();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(container.read(expensesLoadedProvider), ExpensesLoadStatus.failed);
  });

  test('reload after a failure reads the ledger and turns the panel off',
      () async {
    final repo = _FlakyRepo()
      ..failNextLoad = true
      ..items = [
        ExpenseModel(
          id: 'e1',
          title: 'نان',
          amount: 50000,
          category: 'خوراک',
          date: DateTime(2026, 3, 20),
        ),
      ];
    final container = ProviderContainer(
      overrides: [expenseRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    container.read(expenseListProvider);
    await container.pump();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(container.read(expensesLoadedProvider), ExpensesLoadStatus.failed);
    expect(container.read(expenseListProvider), isEmpty);

    // The retry has to clear the `_loaded` guard, otherwise it is a no-op that
    // leaves the error panel on screen forever.
    await container.read(expenseListProvider.notifier).reload();
    await container.pump();

    expect(container.read(expensesLoadedProvider), ExpensesLoadStatus.ready);
    expect(container.read(expenseListProvider).single.title, 'نان');
  });

  test('a failed save raises expenseSaveFailedProvider and a good one clears it',
      () async {
    final repo = _SaveFailingRepo();
    final container = ProviderContainer(
      overrides: [expenseRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    container.read(expenseListProvider);
    await container.pump();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    await container.read(expenseListProvider.notifier).addExpense(
          title: 'اجاره',
          amount: 1000000,
          date: DateTime(2026, 3, 15),
        );
    // The entry stays in memory — the reader must see what they typed — but
    // the banner has to say it has not reached disk.
    expect(container.read(expenseListProvider).single.title, 'اجاره');
    // Writes are debounced by 300 ms.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(container.read(expenseSaveFailedProvider), isTrue);

    repo.failSave = false;
    await container.read(expenseListProvider.notifier).addExpense(
          title: 'نان',
          amount: 50000,
          date: DateTime(2026, 3, 16),
        );
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(container.read(expenseSaveFailedProvider), isFalse);
  });

  test('completing the initial load after dispose does not throw', () async {
    // Regression for the dispose-time crash: `_load()` reads another provider
    // in its `finally` after awaiting DB work. If the container is disposed in
    // that gap, an unguarded `ref.read` throws a StateError that surfaces as an
    // unhandled async error. The `ref.mounted` guard must prevent it.
    Object? zoneError;
    final repo = _BlockingRepo();
    await runZonedGuarded(() async {
      final container = ProviderContainer(
        overrides: [expenseRepositoryProvider.overrideWithValue(repo)],
      );
      container.read(expenseListProvider); // fires _load, blocks on the gate
      await Future<void>.delayed(Duration.zero);
      container.dispose(); // provider gone while _load is mid-await
      repo.gate.complete(); // _load resumes into its finally
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }, (e, _) => zoneError ??= e);

    expect(zoneError, isNull, reason: 'disposed ref read threw: $zoneError');
  });

  test('due recurring expenses are materialized as plain copies and advanced',
      () async {
    // Anchor the fixture to the clock the notifier reads: a monthly source
    // due on the 1st of last month always yields exactly two copies (last
    // month + this month) and an anchor at the 1st of next month, on any
    // day the suite runs.
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1);
    final thisMonth = DateTime(now.year, now.month);
    final nextMonth = DateTime(now.year, now.month + 1);
    final repo = MockExpenseRepository()
      ..items = [
        ExpenseModel(
          id: 'rent',
          title: 'اجاره',
          amount: 1000000,
          category: 'قبض',
          date: lastMonth,
          isRecurring: true,
          recurringType: 'monthly',
          nextDueDate: lastMonth,
        ),
      ];
    final container = ProviderContainer(
      overrides: [expenseRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    // Kick the async load and let it settle (the notifier fires _load()
    // without awaiting it, so poll until the state moves).
    container.read(expenseListProvider);
    for (var i = 0; i < 20; i++) {
      await container.pump();
      if (container.read(expenseListProvider).isNotEmpty) break;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    final state = container.read(expenseListProvider);
    expect(state.length, 3); // copies for last month + this month + anchor

    final copies = state.where((e) => !e.isRecurring).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    expect(copies.length, 2);
    expect(copies[0].date, lastMonth);
    expect(copies[0].title, 'اجاره');
    expect(copies[0].amount, 1000000);
    expect(copies[1].date, thisMonth);

    final anchor = state.singleWhere((e) => e.isRecurring);
    expect(anchor.nextDueDate, nextMonth);
    expect(anchor.nextDueDate!.isAfter(DateTime.now()), isTrue);
  });

  test('budget notifier persists set/remove through the repository', () async {
    final repo = MockExpenseRepository();
    final container = ProviderContainer(
      overrides: [expenseRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    container.read(expenseBudgetProvider);
    await container.pump();

    await container
        .read(expenseBudgetProvider.notifier)
        .setBudget('خوراک', 1500000);
    expect(container.read(expenseBudgetProvider)['خوراک'], 1500000);
    expect(repo.budgets['خوراک'], 1500000);

    await container.read(expenseBudgetProvider.notifier).removeBudget('خوراک');
    expect(container.read(expenseBudgetProvider), isEmpty);
    expect(repo.budgets, isEmpty);
  });

  test('addExpense seeds nextDueDate with the next cycle, not the start date',
      () async {
    final repo = MockExpenseRepository();
    final container = ProviderContainer(
      overrides: [expenseRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    await container.read(expenseListProvider.notifier).addExpense(
          title: 'اجاره',
          amount: 1000000,
          date: DateTime(2026, 3, 15),
          isRecurring: true,
          recurringType: 'monthly',
        );

    final state = container.read(expenseListProvider);
    // Exactly one row: the source itself. (Pre-fix, nextDueDate == date made
    // materialization instantly duplicate the entry at creation date.)
    expect(state.length, 1);
    expect(state.single.date, DateTime(2026, 3, 15));
    expect(state.single.isRecurring, isTrue);
    expect(state.single.nextDueDate, DateTime(2026, 4, 15));
  });

  test('expensesInJalaliMonth groups by Jalali month across Nowruz', () async {
    final repo = MockExpenseRepository();
    final container = ProviderContainer(
      overrides: [expenseRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    // 2026-03-20 = Esfand 1404, 2026-03-25 = Farvardin 1405.
    container.read(expenseListProvider.notifier).state = [
      ExpenseModel(
          id: 'e1',
          title: 'a',
          amount: 1,
          createdAt: DateTime(2026),
          date: DateTime(2026, 3, 20)),
      ExpenseModel(
          id: 'e2',
          title: 'b',
          amount: 2,
          createdAt: DateTime(2026),
          date: DateTime(2026, 3, 25)),
    ];

    final esfand =
        container.read(expensesInJalaliMonthProvider((year: 1404, month: 12)));
    expect(esfand.map((e) => e.id), contains('e1'));
    expect(esfand.map((e) => e.id), isNot(contains('e2')));

    final farvardin =
        container.read(expensesInJalaliMonthProvider((year: 1405, month: 1)));
    expect(farvardin.map((e) => e.id), contains('e2'));
    expect(farvardin.map((e) => e.id), isNot(contains('e1')));
  });
}

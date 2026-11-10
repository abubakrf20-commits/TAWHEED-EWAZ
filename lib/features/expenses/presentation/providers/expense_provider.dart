import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/features/expenses/data/repositories/expense_repository.dart';
import 'package:tawheeed/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:tawheeed/features/expenses/domain/entities/expense_model.dart';
import 'package:tawheeed/features/expenses/domain/expense_recurrence.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/entity_ids.dart';

part 'expense_provider.g.dart';

/// Whether the very first DB load has finished (successfully or not). Lets the
/// screen show a spinner during load instead of mistaking "still loading" (or
/// a failed load) for "no transactions yet" and flashing the empty-state.
/// Where the initial read got to.
///
/// WHY three states and not a bool: `loaded` used to mean "the read finished",
/// whether it succeeded or not — so a failed query marked the list loaded and
/// the screen showed the «هنوز تراکنشی ثبت نشده» onboarding to a user whose
/// three hundred transactions had simply not been read. A failure is a state
/// the reader can see and retry, not a finished load.
enum ExpensesLoadStatus { loading, ready, failed }

/// True while the last write to the ledger failed.
///
/// Kept apart from the list itself: the row the reader just added is real in
/// memory and must stay visible, but they have to know it has not reached disk.
final expenseSaveFailedProvider =
    NotifierProvider<ExpenseSaveFailedNotifier, bool>(
        ExpenseSaveFailedNotifier.new);

class ExpenseSaveFailedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) {
    if (state != value) state = value;
  }
}

final expensesLoadedProvider =
    NotifierProvider<ExpensesLoadedNotifier, ExpensesLoadStatus>(
        ExpensesLoadedNotifier.new);

class ExpensesLoadedNotifier extends Notifier<ExpensesLoadStatus> {
  @override
  ExpensesLoadStatus build() => ExpensesLoadStatus.loading;

  void markLoaded() => state = ExpensesLoadStatus.ready;

  void markFailed() => state = ExpensesLoadStatus.failed;

  void markLoading() => state = ExpensesLoadStatus.loading;
}

@Riverpod(keepAlive: true)
double totalBalance(Ref ref) {
  final expenses = ref.watch(expenseListProvider);
  double balance = 0;
  for (final e in expenses) {
    balance += e.isIncome ? e.amount : -e.amount;
  }
  return balance;
}

/// Expenses of one Jalali month. (The old Gregorian `month` filter compared
/// `date.month` against a Jalali month number, silently dropping
/// Esfand/Farvardin cross-year rows — the report screen groups by
/// [Jalali.fromDateTime], so this provider does the same.)
@riverpod
List<ExpenseModel> expensesInJalaliMonth(Ref ref, ({int year, int month}) ym) {
  final expenses = ref.watch(expenseListProvider);
  return expenses.where((e) {
    final j = Jalali.fromDateTime(e.date);
    return j.year == ym.year && j.month == ym.month;
  }).toList();
}

@Riverpod(keepAlive: true)
class ExpenseList extends _$ExpenseList {
  bool _loaded = false;
  Timer? _saveTimer;
  ExpenseRepository? _repo;
  // Plain snapshot of the list: the dispose-time flush must not touch `ref`
  // NOR `state` (both throw once the provider is being disposed).
  List<ExpenseModel> _latest = const [];

  /// Resolved when the initial DB load finishes. Mutations await it: the
  /// load assigns `state` wholesale, so an add made while the load was still
  /// in flight was silently clobbered (and the next debounce flushed the
  /// clobbered list over it — the entry was gone from memory AND disk).
  Completer<void> _ready = Completer<void>();

  @override
  List<ExpenseModel> build() {
    _ready = Completer<void>();
    ref.onDispose(() {
      _saveTimer?.cancel();
      unawaited(_save());
    });
    _load();
    return [];
  }

  Future<void> _awaitReady() async {
    if (!_ready.isCompleted) await _ready.future;
  }

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    final repo = ref.read(expenseRepositoryProvider);
    _repo = repo;
    var ok = false;
    try {
      await repo.migrateFromLegacyIfNeeded();
      final expenses = await repo.load();
      final materialized = _materializeRecurring(expenses);
      if (materialized != null) {
        _setState(materialized);
        await _save();
      } else if (expenses.isNotEmpty) {
        _setState(expenses);
      }
      ok = true;
    } catch (e) {
      AppLogger.warning('ExpenseList', 'initial load failed: $e');
    } finally {
      _ready.complete();
      // `ref` may be gone by now: the load awaits DB work and the container can
      // dispose this provider in the gap. Reading another provider after an
      // await unconditionally would throw once disposed.
      if (ref.mounted) {
        final notifier = ref.read(expensesLoadedProvider.notifier);
        if (ok) {
          notifier.markLoaded();
        } else {
          notifier.markFailed();
        }
      }
    }
  }

  /// Re-runs the initial read after a failure.
  ///
  /// The load is guarded by `_loaded`, so without clearing it the retry button
  /// would be a no-op that leaves the error panel on screen.
  Future<void> reload() async {
    _loaded = false;
    _ready = Completer<void>();
    if (ref.mounted) {
      ref.read(expensesLoadedProvider.notifier).markLoading();
    }
    await _load();
  }

  /// Turns due recurring sources into real entries.
  ///
  /// For every recurring expense whose [ExpenseModel.nextDueDate] has arrived
  /// (or passed), inserts a plain copy dated that day and advances the source
  /// to the next cycle — repeatedly until the next date is in the future
  /// (capped so a long absence cannot flood the list). Returns the updated
  /// list, or null when nothing was due.
  static List<ExpenseModel>? _materializeRecurring(List<ExpenseModel> all) {
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    final changed = <ExpenseModel>[];
    final source = <ExpenseModel>[];
    final nowMicros = DateTime.now().microsecondsSinceEpoch;
    var guard = 0;
    var copyIndex = 0;

    for (final e in all) {
      if (e.isRecurring &&
          e.recurringType != null &&
          ExpenseRecurrence.isSupported(e.recurringType) &&
          e.nextDueDate != null) {
        var next = e.nextDueDate!;
        var anchor = e;
        var made = false;
        while (!next.isAfter(todayDay) && guard < 500) {
          changed.add(anchor.copyWith(
            id: '${e.id}_${nowMicros}_${copyIndex++}',
            date: next,
            isRecurring: false,
            recurringType: null,
            nextDueDate: null,
          ));
          next = ExpenseRecurrence.next(next, e.recurringType!);
          made = true;
          guard++;
        }
        if (made) {
          anchor = anchor.copyWith(nextDueDate: next);
          source.add(anchor);
        } else {
          source.add(e);
        }
      } else {
        source.add(e);
      }
    }

    if (changed.isEmpty) return null;
    return [...changed, ...source];
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), () {
      unawaited(_save());
    });
  }

  /// Writes the current list, and says so when it cannot.
  ///
  /// WHY the catch and the flag: this is fired by `unawaited` from the debounce
  /// timer and from `onDispose`, so a failure used to surface only as an
  /// unhandled async error — the row stayed on screen and was gone after the
  /// next launch, with nothing to tell the reader their entry had not been
  /// written.
  Future<void> _save() async {
    final repo = _repo;
    if (repo == null) return;
    try {
      await repo.save(_latest);
      if (ref.mounted && ref.read(expenseSaveFailedProvider)) {
        ref.read(expenseSaveFailedProvider.notifier).set(false);
      }
    } catch (e) {
      AppLogger.error('ExpenseList', 'save failed: $e');
      if (ref.mounted) {
        ref.read(expenseSaveFailedProvider.notifier).set(true);
      }
    }
  }

  void _setState(List<ExpenseModel> next) {
    _latest = next;
    state = next;
  }

  Future<void> addExpense({
    required String title,
    required double amount,
    bool isIncome = false,
    String category = 'عام',
    DateTime? date,
    String? note,
    bool isRecurring = false,
    String? recurringType,
  }) async {
    await _awaitReady();
    final at = date ?? DateTime.now();
    // The source row itself represents the first occurrence (dated [at]);
    // the NEXT cycle is due one recurrence later. Seeding nextDueDate with
    // [at] made _materializeRecurring duplicate the entry at creation date.
    final nextDue =
        (isRecurring && ExpenseRecurrence.isSupported(recurringType))
            ? ExpenseRecurrence.next(at, recurringType!)
            : null;
    final expense = ExpenseModel(
      id: newEntityId(),
      title: title,
      amount: amount,
      isIncome: isIncome,
      category: category,
      date: at,
      note: note,
      isRecurring: isRecurring,
      recurringType: recurringType,
      nextDueDate: nextDue,
    );
    _setState([expense, ...state]);
    _scheduleSave();
  }

  /// Removed by the last [deleteExpense], kept in memory so the snackbar can
  /// restore it. The whole list is re-persisted on save, so restoring the
  /// in-memory row is enough to bring it back on disk too.
  ExpenseModel? _lastDeleted;

  Future<void> deleteExpense(String id) async {
    await _awaitReady();
    final idx = state.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    _lastDeleted = state[idx];
    _setState(state.where((e) => e.id != id).toList());
    _scheduleSave();
  }

  /// Restores the transaction removed by the last [deleteExpense] (undo
  /// snackbar). Re-inserts it with its original id so nothing is duplicated.
  Future<void> undoLastDelete() async {
    final expense = _lastDeleted;
    if (expense == null) return;
    _lastDeleted = null;
    if (state.any((e) => e.id == expense.id)) return;
    _setState([expense, ...state]);
    _scheduleSave();
  }

  Future<void> updateExpense(ExpenseModel updated) async {
    await _awaitReady();
    final list = state;
    final idx = list.indexWhere((e) => e.id == updated.id);
    if (idx < 0) return;
    _setState([...list]..[idx] = updated);
    _scheduleSave();
  }
}

/// Per-category budget status for the current Jalali month, combining the
/// configured budgets with this month's actual spending (expenses only —
/// income is excluded).
///
/// Keyed by category. Categories that have spending but no configured budget
/// are also present, with an infinite limit, so the UI can show them as
/// "unlimited" instead of dropping them.
@Riverpod(keepAlive: true)
Map<String, ({double spent, double limit, bool over})> budgetStatus(Ref ref) {
  final budgets = ref.watch(expenseBudgetProvider);
  final now = Jalali.now();
  final monthExpenses = ref
      .watch(expensesInJalaliMonthProvider((year: now.year, month: now.month)));
  final spent = <String, double>{};
  for (final e in monthExpenses) {
    if (e.isIncome) continue;
    spent[e.category] = (spent[e.category] ?? 0) + e.amount;
  }
  final out = <String, ({double spent, double limit, bool over})>{};
  for (final entry in budgets.entries) {
    final s = spent[entry.key] ?? 0;
    out[entry.key] = (spent: s, limit: entry.value, over: s > entry.value);
  }
  for (final entry in spent.entries) {
    out.putIfAbsent(entry.key,
        () => (spent: entry.value, limit: double.infinity, over: false));
  }
  return out;
}

/// Monthly budget per category («محدودیت بودجه برای هر دسته»).
@Riverpod(keepAlive: true)
class ExpenseBudget extends _$ExpenseBudget {
  bool _loaded = false;

  @override
  Map<String, double> build() {
    _load();
    return {};
  }

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      state = await ref.read(expenseRepositoryProvider).loadBudgets();
    } catch (e) {
      AppLogger.warning('ExpenseBudget', 'load failed: $e');
    }
  }

  Future<void> setBudget(String category, double monthlyLimit) async {
    state = {...state, category: monthlyLimit};
    try {
      await ref
          .read(expenseRepositoryProvider)
          .saveBudget(category, monthlyLimit);
    } catch (e) {
      AppLogger.warning('ExpenseBudget', 'save failed: $e');
    }
  }

  Future<void> removeBudget(String category) async {
    if (!state.containsKey(category)) return;
    state = {...state}..remove(category);
    try {
      await ref.read(expenseRepositoryProvider).deleteBudget(category);
    } catch (e) {
      AppLogger.warning('ExpenseBudget', 'delete failed: $e');
    }
  }
}

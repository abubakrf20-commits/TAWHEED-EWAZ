import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/expenses/domain/entities/expense_model.dart';
import 'package:tawheeed/features/expenses/domain/expense_categories.dart';
import 'package:tawheeed/features/expenses/presentation/providers/expense_provider.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Where the user's own categories are kept.
///
/// Deliberately NOT prefixed `flutter.`: `BackupService.isRestorablePreferenceKey`
/// rejects that prefix on both export and restore, so a prefixed key would be
/// written into every backup and then refused on the way back in — the
/// categories would survive in the file and vanish on restore.
const String kCustomExpenseCategoriesPref = 'expenses_custom_categories';

/// Where the names the user removed are kept.
///
/// WHY a second list rather than just deleting the first: a removed category can
/// still be on rows (removing a category is not removing data), and
/// [mergeExpenseCategories] re-adds any name the ledger mentions so those rows
/// stay reachable. Without a record of the removal, the chip would reappear on
/// the very next rebuild and the remove button would look broken. Hiding is what
/// makes the removal stick; the rows are untouched.
const String kHiddenExpenseCategoriesPref = 'expenses_hidden_categories';

/// The user's edits to the vocabulary.
class ExpenseCategoryStore {
  const ExpenseCategoryStore({
    this.custom = const [],
    this.hidden = const {},
  });

  /// Added by the user, in the order they were added.
  final List<String> custom;

  /// Removed by the user, lowercased. Kept out of the picker even when rows or a
  /// budget still mention the name.
  final Set<String> hidden;

  ExpenseCategoryStore copyWith({List<String>? custom, Set<String>? hidden}) =>
      ExpenseCategoryStore(
        custom: custom ?? this.custom,
        hidden: hidden ?? this.hidden,
      );
}

/// The user's category edits, persisted.
///
/// WHY prefs and not a Drift table: budgets have a table because they are keyed
/// rows the report joins against; this is a short ordered list of labels, and
/// the prefs store is exported and restored by `BackupService` verbatim. A new
/// table would also mean a schema version bump, which this change has no other
/// reason to ask for.
final expenseCategoryStoreProvider =
    NotifierProvider<ExpenseCategoryStoreNotifier, ExpenseCategoryStore>(
        ExpenseCategoryStoreNotifier.new);

class ExpenseCategoryStoreNotifier extends Notifier<ExpenseCategoryStore> {
  bool _loaded = false;

  @override
  ExpenseCategoryStore build() {
    _load();
    return const ExpenseCategoryStore();
  }

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawCustom =
          prefs.getStringList(kCustomExpenseCategoriesPref) ?? const <String>[];
      final rawHidden =
          prefs.getStringList(kHiddenExpenseCategoriesPref) ?? const <String>[];

      // Clean what is on disk before trusting it: an older build, a hand-edited
      // pref or a restore from another install can each carry a name this build
      // would refuse on input (surrounding spaces, a duplicate, a built-in).
      final custom = <String>[];
      final seen = <String>{};
      for (final entry in rawCustom) {
        final value = normalizeExpenseCategory(entry);
        if (value.isEmpty) continue;
        if (value.runes.length > kMaxExpenseCategoryLength) continue;
        if (isBuiltInExpenseCategory(value)) continue;
        if (!seen.add(value.toLowerCase())) continue;
        custom.add(value);
      }
      final hidden = <String>{
        for (final entry in rawHidden)
          if (normalizeExpenseCategory(entry).isNotEmpty)
            normalizeExpenseCategory(entry).toLowerCase(),
      };
      if (ref.mounted) {
        state = ExpenseCategoryStore(
          custom: List.unmodifiable(custom),
          hidden: Set.unmodifiable(hidden),
        );
      }
    } catch (e) {
      AppLogger.warning('ExpenseCategories', 'load failed: $e');
    }
  }

  /// Adds [value] to the vocabulary. Returns whether it reached the disk.
  ///
  /// Validation is not done here — `validateNewExpenseCategory` owns the rules
  /// and the caller runs it first. A value that duplicates an existing entry is a
  /// no-op rather than an error: the user's intent (have this category) is
  /// already satisfied.
  ///
  /// On a failed write the in-memory store is put back. A chip that survives on
  /// screen and is gone after the next launch is worse than a chip that never
  /// appeared: the reader believes they added it.
  Future<bool> addCategory(String value) async {
    final normalized = normalizeExpenseCategory(value);
    if (normalized.isEmpty) return true;
    final lower = normalized.toLowerCase();
    if (state.custom.any((c) => c.toLowerCase() == lower)) return true;
    final previous = state;
    state = ExpenseCategoryStore(
      custom: List.unmodifiable([...state.custom, normalized]),
      // Re-adding a name the user once removed must bring it back, otherwise the
      // hidden list would keep it out of the picker forever.
      hidden: Set.unmodifiable({...state.hidden}..remove(lower)),
    );
    try {
      await persist(state);
      return true;
    } catch (e) {
      AppLogger.warning('ExpenseCategories', 'add failed: $e');
      if (ref.mounted) state = previous;
      return false;
    }
  }

  /// Removes a user-added category from the picker. Returns whether the write
  /// landed.
  ///
  /// Only the vocabulary entry goes: rows keep the label they were saved with,
  /// which is why the name is also recorded as hidden — otherwise the in-use pass
  /// in [mergeExpenseCategories] would put the chip straight back. Deleting a
  /// category is not deleting data, and the confirmation dialog says so.
  Future<bool> removeCategory(String value) async {
    final normalized = normalizeExpenseCategory(value);
    final lower = normalized.toLowerCase();
    final index =
        state.custom.indexWhere((c) => c.toLowerCase() == lower);
    if (index < 0) return true;
    final previous = state;
    state = ExpenseCategoryStore(
      custom: List.unmodifiable([...state.custom]..removeAt(index)),
      hidden: Set.unmodifiable({...state.hidden, lower}),
    );
    try {
      await persist(state);
      return true;
    } catch (e) {
      AppLogger.warning('ExpenseCategories', 'remove failed: $e');
      if (ref.mounted) state = previous;
      return false;
    }
  }

  /// `setStringList` answers false when the write did not land and the plugin
  /// does not throw in that case — an unchecked call would report success for a
  /// failed write.
  ///
  /// Hidden is written first: if the second write fails, the category is merely
  /// marked hidden while still present, and the custom pass still shows it — so a
  /// half-applied removal leaves the chip where it was rather than silently
  /// dropping it from a list the user did not touch.
  ///
  /// Visible for testing only: the rollback path is the one thing here a mock
  /// preference store cannot produce (its `setStringList` always answers true),
  /// so a test subclasses this to throw and watches the state come back.
  @visibleForTesting
  Future<void> persist(ExpenseCategoryStore store) async {
    final prefs = await SharedPreferences.getInstance();
    final hiddenOk = await prefs.setStringList(
        kHiddenExpenseCategoriesPref, store.hidden.toList());
    if (!hiddenOk) throw StateError('hidden write returned false');
    final customOk = await prefs.setStringList(
        kCustomExpenseCategoriesPref, store.custom);
    if (!customOk) throw StateError('custom write returned false');
  }
}

/// Every category the UI may offer, in picker order.
///
/// The single source the expense dialog, the budget dialog and the report all
/// read, so a category added in one place exists in all of them.
final expenseCategoryChoicesProvider = Provider<List<String>>((ref) {
  final store = ref.watch(expenseCategoryStoreProvider);
  final rows = ref.watch(expenseListProvider);
  final budgets = ref.watch(expenseBudgetProvider);
  return mergeExpenseCategories(
    custom: store.custom,
    hidden: store.hidden,
    inUse: rows.map((e) => e.category),
    budgeted: budgets.keys,
  );
});

/// How many transactions carry each category.
///
/// Read by the delete confirmation, which has to say whether removing a category
/// touches anything. Counted off the canonical name, so a legacy «عام» row is
/// reported under «عمومی» — the chip the reader is looking at.
final expenseCategoryUsageProvider = Provider<Map<String, int>>((ref) {
  final rows = ref.watch(expenseListProvider);
  final counts = <String, int>{};
  for (final e in rows) {
    final key = canonicalExpenseCategory(e.category);
    counts[key] = (counts[key] ?? 0) + 1;
  }
  return counts;
});

/// The user's own categories as a lowercased set, for "is this removable?".
///
/// Separate from the choices list because the choices also carry built-ins and
/// in-use names, and only the user's own may be deleted.
final customExpenseCategoryKeysProvider = Provider<Set<String>>((ref) {
  final store = ref.watch(expenseCategoryStoreProvider);
  return {for (final c in store.custom) c.toLowerCase()};
});

/// Whether the picker should draw a remove affordance on [value].
bool isRemovableExpenseCategory(String value, Set<String> customKeys) =>
    customKeys.contains(normalizeExpenseCategory(value).toLowerCase());

/// The category a dialog should open with for [expense].
///
/// A row whose category is missing from the vocabulary still opens with that
/// category selected — the choices list already contains it via the in-use pass,
/// and this keeps the caller from falling back to the default and silently
/// re-categorising the row on save.
String categoryForExpense(ExpenseModel? expense) => expense == null
    ? kDefaultExpenseCategory
    : canonicalExpenseCategory(expense.category);

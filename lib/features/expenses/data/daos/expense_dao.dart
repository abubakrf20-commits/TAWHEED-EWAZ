import 'dart:convert';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';
import 'package:tawheeed/features/expenses/domain/entities/expense_model.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

final expenseDaoProvider = Provider<ExpenseDao>((ref) {
  return ExpenseDao(ref.read(appDatabaseProvider));
});

class ExpenseDao {
  final AppDatabase db;
  ExpenseDao(this.db);

  Future<List<ExpenseModel>> getAll() async {
    final rows = await db.select(db.expenseTable).get();
    return rows.map(_toModel).toList();
  }

  /// Indexed range query (Audit 3.1-3): monthly reports / budget checks
  /// should filter in SQL instead of scanning the whole table into memory.
  /// [start] inclusive, [end] exclusive.
  Future<List<ExpenseModel>> getBetween(DateTime start, DateTime end) async {
    final query = db.select(db.expenseTable)
      ..where((t) => t.date.isBiggerOrEqualValue(start))
      ..where((t) => t.date.isSmallerThanValue(end));
    final rows = await query.get();
    return rows.map(_toModel).toList();
  }

  Future<void> upsert(ExpenseModel expense) async {
    await db.into(db.expenseTable).insertOnConflictUpdate(
          ExpenseTableData(
            id: expense.id,
            title: expense.title,
            amount: expense.amount,
            isIncome: expense.isIncome,
            category: expense.category,
            date: expense.date,
            note: expense.note,
            isRecurring: expense.isRecurring,
            recurringType: expense.recurringType,
            nextDueDate: expense.nextDueDate,
            createdAt: expense.createdAt,
          ),
        );
  }

  // ── Category budgets ────────────────────────────────────────────────────

  Future<Map<String, double>> getBudgets() async {
    final rows = await db.select(db.expenseBudgetTable).get();
    return {for (final r in rows) r.category: r.monthlyLimit};
  }

  Future<void> setBudget(String category, double monthlyLimit) async {
    await db.into(db.expenseBudgetTable).insertOnConflictUpdate(
          ExpenseBudgetTableData(
            category: category,
            monthlyLimit: monthlyLimit,
          ),
        );
  }

  Future<void> deleteBudget(String category) async {
    await (db.delete(db.expenseBudgetTable)
          ..where((t) => t.category.equals(category)))
        .go();
  }

  Future<void> delete(String id) async {
    await (db.delete(db.expenseTable)..where((t) => t.id.equals(id))).go();
  }

  Future<void> replaceAll(List<ExpenseModel> expenses) async {
    await db.transaction(() async {
      await db.delete(db.expenseTable).go();
      for (final e in expenses) {
        await upsert(e);
      }
    });
  }

  Future<void> migrateFromLegacyIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migratedFlag) == true) return;

    const legacyKey = 'expenses_data';
    final str = prefs.getString(legacyKey);
    if (str == null) {
      await prefs.setBool(_migratedFlag, true);
      return;
    }

    try {
      final legacy = (jsonDecode(str) as List)
          .map((e) => ExpenseModel.fromJson(e as Map<String, dynamic>))
          .toList();
      if (legacy.isNotEmpty) {
        await replaceAll(legacy);
      }
    } catch (e) {
      AppLogger.warning('ExpenseDao', 'Legacy migration failed: $e');
    }

    await prefs.setBool(_migratedFlag, true);
    await prefs.remove(legacyKey);
  }

  static const String _migratedFlag = 'expenses_migrated_v1';

  ExpenseModel _toModel(ExpenseTableData r) {
    return ExpenseModel(
      id: r.id,
      title: r.title,
      amount: r.amount,
      isIncome: r.isIncome,
      category: r.category,
      date: r.date,
      note: r.note,
      isRecurring: r.isRecurring,
      recurringType: r.recurringType,
      nextDueDate: r.nextDueDate,
      createdAt: r.createdAt,
    );
  }
}

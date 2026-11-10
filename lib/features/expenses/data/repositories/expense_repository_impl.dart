import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/features/expenses/data/daos/expense_dao.dart';
import 'package:tawheeed/features/expenses/data/repositories/expense_repository.dart';
import 'package:tawheeed/features/expenses/domain/entities/expense_model.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepositoryImpl(ref.read(expenseDaoProvider));
});

class ExpenseRepositoryImpl implements ExpenseRepository {
  final ExpenseDao _dao;
  ExpenseRepositoryImpl(this._dao);

  @override
  Future<List<ExpenseModel>> load() => _dao.getAll();

  @override
  Future<void> save(List<ExpenseModel> expenses) => _dao.replaceAll(expenses);

  @override
  Future<void> migrateFromLegacyIfNeeded() => _dao.migrateFromLegacyIfNeeded();

  @override
  Future<Map<String, double>> loadBudgets() => _dao.getBudgets();

  @override
  Future<void> saveBudget(String category, double monthlyLimit) =>
      _dao.setBudget(category, monthlyLimit);

  @override
  Future<void> deleteBudget(String category) => _dao.deleteBudget(category);
}

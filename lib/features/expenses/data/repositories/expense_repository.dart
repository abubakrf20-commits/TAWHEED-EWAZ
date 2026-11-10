import 'package:tawheeed/features/expenses/domain/entities/expense_model.dart';

abstract class ExpenseRepository {
  Future<List<ExpenseModel>> load();
  Future<void> save(List<ExpenseModel> expenses);
  Future<void> migrateFromLegacyIfNeeded();

  Future<Map<String, double>> loadBudgets();
  Future<void> saveBudget(String category, double monthlyLimit);
  Future<void> deleteBudget(String category);
}

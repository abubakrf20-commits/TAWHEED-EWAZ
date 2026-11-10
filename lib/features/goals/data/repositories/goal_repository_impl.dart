import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/goals/data/daos/goal_dao.dart';
import 'package:tawheeed/features/goals/domain/repositories/goal_repository.dart';

/// Uses the [goalDaoProvider] declared in `goal_dao.dart`.
///
/// This file used to declare a second provider with the same name, which
/// shadowed the imported one — so the DAO provider in its natural home was
/// dead code that a maintainer would have edited without effect.
final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  return GoalRepositoryImpl(ref.read(goalDaoProvider));
});

class GoalRepositoryImpl implements GoalRepository {
  final GoalDao _dao;
  GoalRepositoryImpl(this._dao);

  @override
  Future<List<GoalTableData>> getGoals({bool includeArchived = false}) =>
      _dao.getGoals(includeArchived: includeArchived);

  @override
  Future<GoalTableData?> getGoal(String id) => _dao.getGoal(id);

  @override
  Future<void> upsertGoal(GoalTableCompanion entry) => _dao.upsertGoal(entry);

  @override
  Future<void> deleteGoal(String id) => _dao.deleteGoal(id);

  @override
  Future<void> setArchived(String id, bool archived) =>
      _dao.setArchived(id, archived);

  @override
  Future<void> clearSourceLink(String id) => _dao.clearSourceLink(id);

  @override
  Future<int> goalTotal(String goalId) => _dao.goalTotal(goalId);

  @override
  Future<Map<String, int>> totalsByGoal(List<String> goalIds) =>
      _dao.totalsByGoal(goalIds);

  @override
  Future<int> progressOn(String goalId, String date) =>
      _dao.progressOn(goalId, date);

  @override
  Future<Map<String, int>> progressByDay(String goalId,
          {String? from, String? to}) =>
      _dao.progressByDay(goalId, from: from, to: to);

  @override
  Future<Map<String, List<String>>> positiveDaysByGoal(List<String> goalIds) =>
      _dao.positiveDaysByGoal(goalIds);

  @override
  Future<List<GoalProgressTableData>> progressEntries(String goalId,
          {int limit = 200}) =>
      _dao.progressEntries(goalId, limit: limit);

  @override
  Future<void> addProgress(GoalProgressTableCompanion entry) =>
      _dao.addProgress(entry);

  @override
  Future<void> updateProgress(String id, int amount) =>
      _dao.updateProgress(id, amount);

  @override
  Future<void> deleteProgressEntry(String id) => _dao.deleteProgressEntry(id);
}

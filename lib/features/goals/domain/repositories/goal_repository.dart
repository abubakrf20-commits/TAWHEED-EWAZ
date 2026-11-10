import 'package:tawheeed/core/database/app_database.dart';

/// Abstraction over «هدف‌گذاری» persistence (goals + progress entries).
abstract class GoalRepository {
  Future<List<GoalTableData>> getGoals({bool includeArchived = false});
  Future<GoalTableData?> getGoal(String id);
  Future<void> upsertGoal(GoalTableCompanion entry);

  /// Removes the goal and, by way of the foreign key's ON DELETE CASCADE,
  /// every progress row that belongs to it. There is deliberately no
  /// `deleteProgress: false` escape hatch: it was a public way to orphan
  /// rows that nothing in the app would ever clean up, and it now means the
  /// database has no way to produce orphans in the first place.
  Future<void> deleteGoal(String id);

  /// Flip the archive flag without touching any other column.
  Future<void> setArchived(String id, bool archived);

  /// Detach a goal from a linked source whose row no longer exists, without
  /// touching any other column.
  Future<void> clearSourceLink(String id);

  Future<int> goalTotal(String goalId);

  /// Totals for many goals at once, so a list can render from one query.
  Future<Map<String, int>> totalsByGoal(List<String> goalIds);

  Future<int> progressOn(String goalId, String date);

  /// Per-day sums, oldest first.
  Future<Map<String, int>> progressByDay(String goalId,
      {String? from, String? to});

  /// Days carrying a positive entry, per goal, for streak arithmetic.
  Future<Map<String, List<String>>> positiveDaysByGoal(List<String> goalIds);

  /// The individual entries, newest first — what edit and delete need.
  Future<List<GoalProgressTableData>> progressEntries(String goalId,
      {int limit});

  Future<void> addProgress(GoalProgressTableCompanion entry);
  Future<void> updateProgress(String id, int amount);
  Future<void> deleteProgressEntry(String id);
}

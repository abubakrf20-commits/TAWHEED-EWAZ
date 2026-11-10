import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';

final goalDaoProvider = Provider<GoalDao>((ref) {
  return GoalDao(ref.read(appDatabaseProvider));
});

class GoalDao {
  final AppDatabase db;
  GoalDao(this.db);

  Future<List<GoalTableData>> getGoals({bool includeArchived = false}) {
    final q = db.select(db.goalTable)
      ..orderBy([
        (t) => OrderingTerm.desc(t.isActive),
        (t) => OrderingTerm.desc(t.updatedAt),
      ]);
    if (!includeArchived) q.where((t) => t.isArchived.equals(false));
    return q.get();
  }

  Future<GoalTableData?> getGoal(String id) =>
      (db.select(db.goalTable)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<void> upsertGoal(GoalTableCompanion entry) =>
      db.into(db.goalTable).insertOnConflictUpdate(entry);

  /// Deleting the parent row is enough: `goal_progress_table.goal_id` is a
  /// real foreign key with ON DELETE CASCADE, so the progress rows go with
  /// it inside the database. There is no longer a two-statement sequence
  /// that could be interrupted halfway and leave orphans behind.
  Future<void> deleteGoal(String id) =>
      (db.delete(db.goalTable)..where((t) => t.id.equals(id))).go();

  /// Flip the archive flag and nothing else.
  ///
  /// The restore path used to rewrite all twelve columns read from a goal
  /// that was loaded when the sheet opened, which silently reverted any
  /// edit made while the sheet was up. A targeted UPDATE cannot clobber
  /// fields it does not mention.
  ///
  /// [updatedAt] is bumped on purpose: the list orders by `updated_at DESC`,
  /// so a goal you just archived or restored surfaces at the top instead of
  /// vanishing into a list sorted by an edit date from months ago.
  Future<void> setArchived(String id, bool archived) async {
    await (db.update(db.goalTable)..where((t) => t.id.equals(id))).write(
      GoalTableCompanion(
        isArchived: Value(archived),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Detaches a goal from its linked source, leaving every other column alone.
  ///
  /// A targeted UPDATE rather than a full `upsertGoal` from the row the screen
  /// already had in hand: the goal may have been edited on another screen
  /// since, and writing the stale copy back would silently revert those
  /// edits along with the link.
  Future<void> clearSourceLink(String id) async {
    await (db.update(db.goalTable)..where((t) => t.id.equals(id))).write(
      GoalTableCompanion(
        linkedType: const Value(''),
        linkedId: const Value(''),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Lifetime total for one goal, summed by SQLite.
  ///
  /// Was a Dart loop over every progress row of the goal. That made the
  /// query O(rows) per call, and the list screen called it once per goal —
  /// see [totalsByGoal] for the fix that removed the N+1.
  Future<int> goalTotal(String goalId) async {
    final total = db.goalProgressTable.amount.sum();
    final row = await (db.selectOnly(db.goalProgressTable)
          ..addColumns([total])
          ..where(db.goalProgressTable.goalId.equals(goalId)))
        .getSingle();
    return row.read(total) ?? 0;
  }

  /// Totals for a whole set of goals in ONE query.
  ///
  /// The list screen watched a per-goal `goalTotalProvider`, so rendering N
  /// goals issued N separate SUM queries and N full scans of
  /// `goal_progress_table` before the composite (goal_id, date) index
  /// existed. This is the same totals, grouped once.
  Future<Map<String, int>> totalsByGoal(List<String> goalIds) async {
    if (goalIds.isEmpty) return const {};
    final placeholders = List.filled(goalIds.length, '?').join(', ');
    final rows = await db.customSelect(
      'SELECT goal_id AS g, COALESCE(SUM(amount), 0) AS t '
      'FROM goal_progress_table WHERE goal_id IN ($placeholders) '
      'GROUP BY goal_id',
      variables: [for (final id in goalIds) Variable<String>(id)],
      readsFrom: {db.goalProgressTable},
    ).get();
    return {
      for (final row in rows) row.read<String>('g'): row.read<int>('t'),
    };
  }

  /// Sum for a single day, summed by SQLite. Exact string match on a
  /// zero-padded `yyyy-MM-dd` key.
  Future<int> progressOn(String goalId, String date) async {
    final total = db.goalProgressTable.amount.sum();
    final row = await (db.selectOnly(db.goalProgressTable)
          ..addColumns([total])
          ..where(db.goalProgressTable.goalId.equals(goalId) &
              db.goalProgressTable.date.equals(date)))
        .getSingle();
    return row.read(total) ?? 0;
  }

  /// Per-day sums, oldest first — one query for the chart, the 7-day pace
  /// average and the history list.
  ///
  /// Those three panels each re-derived the same day→amount map by looping
  /// over the raw progress rows in the widget. Aggregating here keeps the
  /// result in one place and leaves the index doing the grouping.
  Future<Map<String, int>> progressByDay(
    String goalId, {
    String? from,
    String? to,
  }) async {
    final day = db.goalProgressTable.date;
    final total = db.goalProgressTable.amount.sum();
    final query = db.selectOnly(db.goalProgressTable)
      ..addColumns([day, total])
      ..where(db.goalProgressTable.goalId.equals(goalId))
      ..groupBy([day])
      ..orderBy([OrderingTerm.asc(day)]);
    if (from != null) {
      query.where(db.goalProgressTable.date.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      query.where(db.goalProgressTable.date.isSmallerOrEqualValue(to));
    }
    final rows = await query.get();
    // `read` is typed nullable for every column, even a NOT NULL one, so both
    // the key and the value need a guard — the value cannot actually be null
    // here, because a group only exists if it matched at least one row.
    return <String, int>{
      for (final row in rows)
        if (row.read<String>(day) case final dayKey?)
          dayKey: row.read<int>(total) ?? 0,
    };
  }

  /// Active days per goal, for the streak column — one query for the whole
  /// list.
  ///
  /// Distinct `goal_id, date` pairs, not the amounts: a streak asks "was
  /// anything logged on this day", and the answer is a boolean. Summing here
  /// would tell us how much, which the total column already has, and would
  /// make the result depend on how many entries a day happened to be split
  /// into.
  ///
  /// Only rows with `amount > 0` qualify. A recorded zero is an honest
  /// "nothing today", not activity, and must not fake a streak.
  Future<Map<String, List<String>>> positiveDaysByGoal(
      List<String> goalIds) async {
    if (goalIds.isEmpty) return const {};
    final placeholders = List.filled(goalIds.length, '?').join(', ');
    final rows = await db.customSelect(
      'SELECT goal_id AS g, date AS d FROM goal_progress_table '
      'WHERE goal_id IN ($placeholders) AND amount > 0 '
      'GROUP BY goal_id, date ORDER BY goal_id, date',
      variables: [for (final id in goalIds) Variable<String>(id)],
      readsFrom: {db.goalProgressTable},
    ).get();
    final out = <String, List<String>>{};
    for (final row in rows) {
      (out[row.read<String>('g')] ??= <String>[]).add(row.read<String>('d'));
    }
    return out;
  }

  /// The individual progress rows for one goal, newest day first.
  ///
  /// `progressByDay` returns per-day sums, which is what the chart wants but
  /// cannot identify a row — so correcting a mistyped entry was impossible
  /// without deleting it and retyping it. The history needs the rows
  /// themselves to offer edit and delete per entry.
  Future<List<GoalProgressTableData>> progressEntries(String goalId,
      {int limit = 200}) {
    return (db.select(db.goalProgressTable)
          ..where((t) => t.goalId.equals(goalId))
          ..orderBy([
            (t) => OrderingTerm.desc(t.date),
            (t) => OrderingTerm.desc(t.createdAt)
          ])
          ..limit(limit))
        .get();
  }

  /// Insert, or replace if the id already exists.
  ///
  /// Was a bare `insert`, so a repeated id threw a `SqliteException` that no
  /// layer caught. The boolean-today toggle relies on this: it derives a
  /// deterministic id from (goal, day), so tapping twice updates the single
  /// row instead of failing or double-counting.
  Future<void> addProgress(GoalProgressTableCompanion entry) =>
      db.into(db.goalProgressTable).insertOnConflictUpdate(entry);

  /// Correct a mistyped amount. The only other mutations were "add a row"
  /// and "delete a row", so fixing a wrong number meant deleting it and
  /// typing it again — which also lost the original timestamp.
  Future<void> updateProgress(String id, int amount) async {
    await (db.update(db.goalProgressTable)..where((t) => t.id.equals(id)))
        .write(GoalProgressTableCompanion(amount: Value(amount)));
  }

  Future<void> deleteProgressEntry(String id) =>
      (db.delete(db.goalProgressTable)..where((t) => t.id.equals(id))).go();
}

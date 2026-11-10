import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';

final dailyStatusDaoProvider = Provider<DailyStatusDao>((ref) {
  return DailyStatusDao(ref.read(appDatabaseProvider));
});

class DailyStatusDao {
  final AppDatabase db;
  DailyStatusDao(this.db);

  Future<DailyStatusTableData?> get(
      String category, String date, String key) async {
    return (db.select(db.dailyStatusTable)
          ..where((t) => t.category.equals(category))
          ..where((t) => t.date.equals(date))
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
  }

  Future<int?> getValue(String category, String date, String key) async {
    final record = await get(category, date, key);
    return record?.value;
  }

  Future<void> set(String category, String date, String key, int value) async {
    await db.into(db.dailyStatusTable).insertOnConflictUpdate(
          DailyStatusTableData(
              category: category, date: date, key: key, value: value),
        );
  }

  /// Atomically increments [value] by [amount] in a single UPSERT statement.
  /// Avoids the read-modify-write race that `getValue` + `set` would introduce
  /// when the same counter is tapped in quick succession.
  Future<void> increment(
      String category, String date, String key, int amount) async {
    if (amount == 0) return;
    await db.customStatement(
      'INSERT INTO daily_status_table (category, date, key, value) '
      'VALUES (?, ?, ?, ?) '
      'ON CONFLICT(category, date, key) DO UPDATE SET value = value + ?',
      [category, date, key, amount, amount],
    );
  }

  Future<void> setBool(
      String category, String date, String key, bool value) async {
    await set(category, date, key, value ? 1 : 0);
  }

  Future<bool> getBool(String category, String date, String key) async {
    final val = await getValue(category, date, key);
    return val == 1;
  }

  Future<List<DailyStatusTableData>> getAllForCategory(String category) async {
    return (db.select(db.dailyStatusTable)
          ..where((t) => t.category.equals(category)))
        .get();
  }

  Future<List<DailyStatusTableData>> getAllForDate(
      String category, String date) async {
    return (db.select(db.dailyStatusTable)
          ..where((t) => t.category.equals(category))
          ..where((t) => t.date.equals(date)))
        .get();
  }

  Future<List<DailyStatusTableData>> getAllInDateRange(
      String category, String startDate, String endDate) async {
    final stmt = db.customSelect(
      'SELECT * FROM daily_status_table WHERE category = ? AND date >= ? AND date <= ?',
      variables: [
        Variable.withString(category),
        Variable.withString(startDate),
        Variable.withString(endDate)
      ],
    );
    final rows = await stmt.get();
    return rows.map((row) {
      return DailyStatusTableData(
        category: row.read<String>('category'),
        date: row.read<String>('date'),
        key: row.read<String>('key'),
        value: row.read<int>('value'),
      );
    }).toList();
  }

  Future<Map<String, int>> getAllAsMap(String category) async {
    final records = await getAllForCategory(category);
    final map = <String, int>{};
    for (final r in records) {
      map[r.date] = r.value;
    }
    return map;
  }

  /// Per-zikr tasbih counts for one date in a single query (`tasbih_daily_<id>`
  /// categories → zikr id). Replaces the N+1 `getValue` loop in the
  /// evaluation build; the plain `tasbih_daily` aggregate row is excluded.
  Future<Map<String, int>> getTasbihDailyForDate(String date) async {
    const prefix = 'tasbih_daily_';
    final stmt = db.customSelect(
      'SELECT category, value FROM daily_status_table '
      "WHERE date = ? AND category LIKE '$prefix%' AND category <> 'tasbih_daily'",
      variables: [Variable.withString(date)],
    );
    final rows = await stmt.get();
    final map = <String, int>{};
    for (final row in rows) {
      final category = row.read<String>('category');
      map[category.substring(prefix.length)] = row.read<int>('value');
    }
    return map;
  }

  Future<Map<String, Map<String, int>>> getAllGroupedByDate(
      String category) async {
    final records = await getAllForCategory(category);
    final map = <String, Map<String, int>>{};
    for (final r in records) {
      map.putIfAbsent(r.date, () => {})[r.key] = r.value;
    }
    return map;
  }

  Future<int> sumForDateRange(
      String category, String startDate, String endDate) async {
    final records = await getAllInDateRange(category, startDate, endDate);
    return records.fold<int>(0, (sum, r) => sum + r.value);
  }

  Future<void> deleteForCategory(String category) async {
    await (db.delete(db.dailyStatusTable)
          ..where((t) => t.category.equals(category)))
        .go();
  }

  /// Deletes every row in [categories] in one transaction. Returns the number of
  /// rows removed.
  ///
  /// WHY a list and not one [deleteForCategory] per category: the evaluation
  /// reset clears four categories that only make sense together — the ticks and
  /// the scores derived from them. Applying half of them would leave a checklist
  /// with no history, or a history whose checklist is gone; a transaction means
  /// the reset either happened or did not.
  Future<int> deleteCategories(List<String> categories) async {
    if (categories.isEmpty) return 0;
    return db.transaction(() async {
      var removed = 0;
      for (final category in categories) {
        removed += await (db.delete(db.dailyStatusTable)
              ..where((t) => t.category.equals(category)))
            .go();
      }
      return removed;
    });
  }

  Future<void> deleteForDate(String category, String date) async {
    await (db.delete(db.dailyStatusTable)
          ..where((t) => t.category.equals(category))
          ..where((t) => t.date.equals(date)))
        .go();
  }

  /// Deletes every row of [categories] whose date is within
  /// [startDate..endDate] (inclusive). Returns the number of rows removed.
  ///
  /// The evaluation's range reset clears a day, a week or a month instead of
  /// the whole history, so the whole-category deletes above are too wide —
  /// a date-scoped sibling keeps the same all-or-nothing transaction rule:
  /// the range either went entirely or the caller reports failure.
  Future<int> deleteCategoriesInDateRange(
      List<String> categories, String startDate, String endDate) async {
    if (categories.isEmpty) return 0;
    return db.transaction(() async {
      var removed = 0;
      for (final category in categories) {
        removed += await (db.delete(db.dailyStatusTable)
              ..where((t) => t.category.equals(category))
              ..where((t) => t.date.isBiggerOrEqualValue(startDate))
              ..where((t) => t.date.isSmallerOrEqualValue(endDate)))
            .go();
      }
      return removed;
    });
  }

  /// Deletes rows whose category starts with [prefix] within
  /// [startDate..endDate] (inclusive). Covers the per-zikr `tasbih_daily_<id>`
  /// categories, whose ids are open-ended.
  Future<void> deleteCategoryPrefixInDateRange(
      String prefix, String startDate, String endDate) async {
    await db.customStatement(
      'DELETE FROM daily_status_table '
      'WHERE category LIKE ? || \'%\' AND date >= ? AND date <= ?',
      [prefix, startDate, endDate],
    );
  }

  /// Reads every row a range reset would delete — the reset backup's raw
  /// material. Same predicate as [deleteCategoriesInDateRange] plus the
  /// per-zikr prefix, so the backup and the delete can never disagree about
  /// what a range contains.
  Future<List<DailyStatusTableData>> getRowsForRangeBackup(
      List<String> categories, String prefix, String startDate,
      String endDate) async {
    final placeholders = List.filled(categories.length, '?').join(', ');
    final stmt = db.customSelect(
      'SELECT * FROM daily_status_table '
      "WHERE (category IN ($placeholders) OR category LIKE ? || '%') "
      'AND date >= ? AND date <= ?',
      variables: [
        for (final c in categories) Variable.withString(c),
        Variable.withString(prefix),
        Variable.withString(startDate),
        Variable.withString(endDate),
      ],
    );
    final rows = await stmt.get();
    return rows.map((row) {
      return DailyStatusTableData(
        category: row.read<String>('category'),
        date: row.read<String>('date'),
        key: row.read<String>('key'),
        value: row.read<int>('value'),
      );
    }).toList();
  }

  /// Puts backed-up rows back after a reset undo. Conflict-safe upserts: a
  /// restore over rows written after the reset simply wins — the reader asked
  /// for their history back.
  Future<void> restoreRows(List<DailyStatusTableData> rows) async {
    if (rows.isEmpty) return;
    await db.batch((batch) {
      batch.insertAllOnConflictUpdate(db.dailyStatusTable, rows);
    });
  }

  Future<void> deleteAll() async {
    await db.delete(db.dailyStatusTable).go();
  }
}

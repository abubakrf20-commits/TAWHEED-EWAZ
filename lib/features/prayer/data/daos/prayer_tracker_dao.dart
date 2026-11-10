import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';

final prayerTrackerDaoProvider = Provider<PrayerTrackerDao>((ref) {
  return PrayerTrackerDao(ref.read(appDatabaseProvider));
});

class PrayerTrackerDao {
  final AppDatabase db;
  PrayerTrackerDao(this.db);

  Future<List<PrayerTrackerTableData>> getAllForDate(String date) async {
    return (db.select(db.prayerTrackerTable)..where((t) => t.date.equals(date)))
        .get();
  }

  Future<PrayerTrackerTableData?> getForDateAndKey(
      String date, String prayerKey) async {
    return (db.select(db.prayerTrackerTable)
          ..where((t) => t.date.equals(date))
          ..where((t) => t.prayerKey.equals(prayerKey)))
        .getSingleOrNull();
  }

  Future<void> upsert(PrayerTrackerTableData record) async {
    await db.into(db.prayerTrackerTable).insertOnConflictUpdate(record);
  }

  Future<List<PrayerTrackerTableData>> getAllInDateRange(
      String startDate, String endDate) async {
    final stmt = db.customSelect(
      'SELECT * FROM prayer_tracker_table WHERE date >= ? AND date <= ?',
      variables: [Variable.withString(startDate), Variable.withString(endDate)],
    );
    final rows = await stmt.get();
    return rows.map((row) {
      return PrayerTrackerTableData(
        date: row.read<String>('date'),
        prayerKey: row.read<String>('prayer_key'),
        value: row.read<int?>('value'),
      );
    }).toList();
  }

  Future<Map<String, int>> getAllAsMap() async {
    final records = await db.select(db.prayerTrackerTable).get();
    return {
      for (final r in records) 'pt_${r.date}_${r.prayerKey}': r.value ?? 0
    };
  }

  Future<void> deleteForDate(String date) async {
    await (db.delete(db.prayerTrackerTable)..where((t) => t.date.equals(date)))
        .go();
  }

  /// Deletes every recorded prayer status within [startDate..endDate]
  /// (inclusive). The evaluation's range reset uses this to un-tick a day, a
  /// week or a month in one statement instead of looping [deleteForDate].
  Future<int> deleteDateRange(String startDate, String endDate) async {
    return (db.delete(db.prayerTrackerTable)
          ..where((t) => t.date.isBiggerOrEqualValue(startDate))
          ..where((t) => t.date.isSmallerOrEqualValue(endDate)))
        .go();
  }

  /// Puts backed-up prayer rows back after a reset undo.
  Future<void> restoreRows(List<PrayerTrackerTableData> rows) async {
    if (rows.isEmpty) return;
    await db.batch((batch) {
      batch.insertAllOnConflictUpdate(db.prayerTrackerTable, rows);
    });
  }

  Future<void> deleteForDateAndKey(String date, String prayerKey) async {
    await (db.delete(db.prayerTrackerTable)
          ..where((t) => t.date.equals(date))
          ..where((t) => t.prayerKey.equals(prayerKey)))
        .go();
  }

  Future<void> deleteAll() async {
    await db.delete(db.prayerTrackerTable).go();
  }
}

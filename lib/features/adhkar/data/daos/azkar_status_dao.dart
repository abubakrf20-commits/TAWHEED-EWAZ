import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';

final azkarStatusDaoProvider = Provider<AzkarStatusDao>((ref) {
  return AzkarStatusDao(ref.read(appDatabaseProvider));
});

class AzkarStatusDao {
  final AppDatabase db;
  AzkarStatusDao(this.db);

  Future<ZikrStatusRecordTableData?> getStatus(String id, String date) async {
    final query = db.select(db.zikrStatusRecordTable)
      ..where((t) => t.id.equals(id))
      ..where((t) => t.date.equals(date));
    return query.getSingleOrNull();
  }

  Future<void> setStatus(ZikrStatusRecordTableData status) async {
    await db.into(db.zikrStatusRecordTable).insertOnConflictUpdate(status);
  }

  Future<void> setStatusesBatch(
      List<ZikrStatusRecordTableData> statuses) async {
    if (statuses.isEmpty) return;
    await db.batch((batch) {
      batch.insertAllOnConflictUpdate(db.zikrStatusRecordTable, statuses);
    });
  }

  Future<List<ZikrStatusRecordTableData>> getStatusesForDate(
      String date) async {
    final query = db.select(db.zikrStatusRecordTable)
      ..where((t) => t.date.equals(date));
    return query.get();
  }

  /// Loads every status record (used by the azkar statistics screen).
  Future<List<ZikrStatusRecordTableData>> getAll() async {
    return db.select(db.zikrStatusRecordTable).get();
  }

  /// Batch-load all records where date is between [startDate] and [endDate] (inclusive).
  Future<List<ZikrStatusRecordTableData>> getStatusesForDateRange(
      String startDate, String endDate) async {
    final stmt = db.customSelect(
      'SELECT * FROM zikr_status_record_table WHERE date >= ? AND date <= ?',
      variables: [Variable.withString(startDate), Variable.withString(endDate)],
    );
    final rows = await stmt.get();
    return rows.map((row) {
      return ZikrStatusRecordTableData(
        id: row.read<String>('id'),
        statusIndex: row.read<int>('status_index'),
        date: row.read<String>('date'),
      );
    }).toList();
  }

  Future<void> deleteStatus(String id, String date) async {
    await (db.delete(db.zikrStatusRecordTable)
          ..where((t) => t.id.equals(id))
          ..where((t) => t.date.equals(date)))
        .go();
  }

  /// Deletes every zikr status within [startDate..endDate] (inclusive).
  /// The evaluation's range reset uses this to clear a day, a week or a month
  /// of azkar records in one statement.
  Future<int> deleteDateRange(String startDate, String endDate) async {
    return (db.delete(db.zikrStatusRecordTable)
          ..where((t) => t.date.isBiggerOrEqualValue(startDate))
          ..where((t) => t.date.isSmallerOrEqualValue(endDate)))
        .go();
  }

  /// Puts backed-up zikr rows back after a reset undo.
  Future<void> restoreRows(List<ZikrStatusRecordTableData> rows) async {
    if (rows.isEmpty) return;
    await db.batch((batch) {
      batch.insertAllOnConflictUpdate(db.zikrStatusRecordTable, rows);
    });
  }

  /// Count all records with a given status.
  Future<int> countByStatus(int statusIndex) async {
    final rows = await (db.select(db.zikrStatusRecordTable)
          ..where((t) => t.statusIndex.equals(statusIndex)))
        .get();
    return rows.length;
  }
}

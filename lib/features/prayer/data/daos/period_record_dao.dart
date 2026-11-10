import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';

final periodRecordDaoProvider = Provider<PeriodRecordDao>((ref) {
  return PeriodRecordDao(ref.read(appDatabaseProvider));
});

class PeriodRecordDao {
  final AppDatabase db;
  PeriodRecordDao(this.db);

  Future<List<PeriodRecordTableData>> getAllRecords() async {
    return db.select(db.periodRecordTable).get();
  }

  Future<void> upsertRecord(PeriodRecordTableData record) async {
    await db.into(db.periodRecordTable).insertOnConflictUpdate(record);
  }

  Future<void> insertRecord(PeriodRecordTableCompanion record) async {
    await db.into(db.periodRecordTable).insert(record);
  }

  Future<void> deleteRecord(int id) async {
    await (db.delete(db.periodRecordTable)..where((t) => t.id.equals(id))).go();
  }
}

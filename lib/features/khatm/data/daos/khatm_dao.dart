import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';

final khatmDaoProvider = Provider<KhatmDao>((ref) {
  return KhatmDao(ref.read(appDatabaseProvider));
});

class KhatmDao {
  final AppDatabase db;
  KhatmDao(this.db);

  Future<List<KhatmTableData>> getAllKhatms() async {
    return db.select(db.khatmTable).get();
  }

  Future<KhatmTableData?> getKhatm(String id) async {
    final query = db.select(db.khatmTable)..where((t) => t.id.equals(id));
    return query.getSingleOrNull();
  }

  Future<void> upsertKhatm(KhatmTableData khatm) async {
    await db.into(db.khatmTable).insertOnConflictUpdate(khatm);
  }

  Future<void> deleteKhatm(String id) async {
    await (db.delete(db.khatmTable)..where((t) => t.id.equals(id))).go();
  }
}

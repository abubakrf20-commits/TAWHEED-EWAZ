import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';

final duaDaoProvider = Provider<DuaDao>((ref) {
  return DuaDao(ref.read(appDatabaseProvider));
});

class DuaDao {
  final AppDatabase db;
  DuaDao(this.db);

  Future<List<DuaTableData>> getAllDuas() async {
    return db.select(db.duaTable).get();
  }

  Future<DuaTableData?> getDua(String id) async {
    final query = db.select(db.duaTable)..where((t) => t.id.equals(id));
    return query.getSingleOrNull();
  }

  Future<void> upsertDua(DuaTableData dua) async {
    await db.into(db.duaTable).insertOnConflictUpdate(dua);
  }

  Future<void> clearAll() async {
    await db.delete(db.duaTable).go();
  }

  Future<void> deleteDua(String id) async {
    await (db.delete(db.duaTable)..where((t) => t.id.equals(id))).go();
  }

  Future<void> upsertBatch(List<DuaTableData> duads) async {
    await db.batch((batch) {
      for (final dua in duads) {
        batch.insert(db.duaTable, dua, mode: InsertMode.insertOrReplace);
      }
    });
  }

  Future<void> setFavorite(String id, bool favorite) async {
    final existing = await getDua(id);
    if (existing != null) {
      final updated = existing.copyWith(isFavorite: favorite);
      await db.into(db.duaTable).insertOnConflictUpdate(updated);
    }
  }
}

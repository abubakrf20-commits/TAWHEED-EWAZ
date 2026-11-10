import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';

final noteDaoProvider = Provider<NoteDao>((ref) {
  return NoteDao(ref.read(appDatabaseProvider));
});

class NoteDao {
  final AppDatabase db;
  NoteDao(this.db);

  Future<List<NoteTableData>> getAllNotes() async {
    return db.select(db.noteTable).get();
  }

  Future<NoteTableData?> getNote(String id) async {
    final query = db.select(db.noteTable)..where((t) => t.id.equals(id));
    return query.getSingleOrNull();
  }

  Future<void> upsertNote(NoteTableData note) async {
    await db.into(db.noteTable).insertOnConflictUpdate(note);
  }

  Future<void> deleteNote(String id) async {
    await (db.delete(db.noteTable)..where((t) => t.id.equals(id))).go();
  }

  Future<void> clearAll() async {
    await db.delete(db.noteTable).go();
  }
}

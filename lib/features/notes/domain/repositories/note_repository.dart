import 'package:tawheeed/core/database/app_database.dart';

abstract class NoteRepository {
  Future<List<NoteTableData>> getAllNotes();
  Future<NoteTableData?> getNote(String id);
  Future<void> upsertNote(NoteTableData note);
  Future<void> deleteNote(String id);
}

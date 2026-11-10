import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/notes/data/daos/note_dao.dart';
import 'package:tawheeed/features/notes/domain/repositories/note_repository.dart';

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  return NoteRepositoryImpl(ref.read(noteDaoProvider));
});

class NoteRepositoryImpl implements NoteRepository {
  final NoteDao _dao;
  NoteRepositoryImpl(this._dao);

  @override
  Future<List<NoteTableData>> getAllNotes() => _dao.getAllNotes();

  @override
  Future<NoteTableData?> getNote(String id) => _dao.getNote(id);

  @override
  Future<void> upsertNote(NoteTableData note) => _dao.upsertNote(note);

  @override
  Future<void> deleteNote(String id) => _dao.deleteNote(id);
}

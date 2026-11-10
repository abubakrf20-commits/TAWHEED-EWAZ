import 'package:drift/drift.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/quran/data/tables/quran_bookmark_table.dart';

part 'quran_bookmark_dao.g.dart';

@DriftAccessor(tables: [QuranBookmarkTable])
class QuranBookmarkDao extends DatabaseAccessor<AppDatabase>
    with _$QuranBookmarkDaoMixin {
  QuranBookmarkDao(super.db);

  Future<List<QuranBookmarkTableData>> getAll() =>
      select(quranBookmarkTable).get();

  Stream<List<QuranBookmarkTableData>> watchAll() =>
      select(quranBookmarkTable).watch();

  Future<QuranBookmarkTableData?> getByAyah(int surah, int ayah) =>
      (select(quranBookmarkTable)
            ..where((t) => t.surah.equals(surah) & t.ayah.equals(ayah)))
          .getSingleOrNull();

  Future<int> add(int surah, int ayah, {String? note}) =>
      into(quranBookmarkTable).insert(QuranBookmarkTableCompanion(
          surah: Value(surah),
          ayah: Value(ayah),
          note: Value(note),
          createdAt: Value(DateTime.now())));

  Future<bool> removeByAyah(int surah, int ayah) async {
    final count = await (delete(quranBookmarkTable)
          ..where((t) => t.surah.equals(surah) & t.ayah.equals(ayah)))
        .go();
    return count > 0;
  }

  Future<bool> toggle(int surah, int ayah, {String? note}) async {
    final existing = await getByAyah(surah, ayah);
    if (existing != null) {
      await removeByAyah(surah, ayah);
      return false;
    } else {
      await add(surah, ayah, note: note);
      return true;
    }
  }

  /// Attaches (or replaces) the reader's note on a bookmark, creating the
  /// bookmark when the ayah is not marked yet — writing a note implies marking
  /// the ayah (report §7.4).
  ///
  /// A blank or whitespace-only [note] clears the column but KEEPS the
  /// bookmark: the mark and the note are independent, and a reader who erases a
  /// note should not silently lose their position. Returns the note as stored
  /// (`null` when cleared) so the caller can say what happened.
  Future<String?> setNote(int surah, int ayah, String? note) async {
    final trimmed = note?.trim();
    final stored = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    final existing = await getByAyah(surah, ayah);
    if (existing == null) {
      await add(surah, ayah, note: stored);
      return stored;
    }
    await (update(quranBookmarkTable)
          ..where((t) => t.surah.equals(surah) & t.ayah.equals(ayah)))
        .write(QuranBookmarkTableCompanion(note: Value(stored)));
    return stored;
  }
}

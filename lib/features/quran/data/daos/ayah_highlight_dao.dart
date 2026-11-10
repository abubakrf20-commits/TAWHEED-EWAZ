import 'package:drift/drift.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/quran/data/tables/ayah_highlight_table.dart';

part 'ayah_highlight_dao.g.dart';

@DriftAccessor(tables: [AyahHighlightTable])
class AyahHighlightDao extends DatabaseAccessor<AppDatabase>
    with _$AyahHighlightDaoMixin {
  AyahHighlightDao(super.db);

  /// Every highlight, newest first — the small per-page lookups below are
  /// what the reader hot path uses; this is for future management UI.
  Future<List<AyahHighlightTableData>> getAll() => (select(ayahHighlightTable)
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .get();

  /// All highlight colors for one Mushaf page's worth of lookups: the caller
  /// passes the (surah, ayah) pairs present on the page and gets back only
  /// the rows that matter. Keeps the reader render path O(highlights-on-page)
  /// instead of loading the whole table.
  Future<List<AyahHighlightTableData>> getForVerses(
      List<(int, int)> verses) async {
    if (verses.isEmpty) return const [];
    final query = select(ayahHighlightTable)..where((t) => _orOf(verses, t));
    return query.get();
  }

  Expression<bool> _orOf(List<(int, int)> verses, AyahHighlightTable t) {
    Expression<bool>? acc;
    for (final (s, a) in verses) {
      final clause = t.surah.equals(s) & t.ayah.equals(a);
      acc = acc == null ? clause : (acc | clause);
    }
    return acc ?? const Constant(false);
  }

  /// Watch everything — powers a future highlights list and lets the mushaf
  /// invalidate itself when a highlight is added/removed from the sheet.
  Stream<List<AyahHighlightTableData>> watchAll() =>
      select(ayahHighlightTable).watch();

  /// Inserts or replaces the color for one ayah (id-stable: the unique index
  /// on (surah, ayah) makes the conflict path an update, so lifetime history
  /// in createdAt is preserved via [keepCreatedAt]).
  /// Insert or re-color. The unique (surah, ayah) index is the real
  /// identity — [insertOnConflictUpdate] only targets the PK (id),
  /// which is NOT the conflicting key here, so read-then-write inside
  /// a transaction keeps this portable without hand-written SQL.
  Future<void> setColor(int surah, int ayah, String colorHex) async {
    await transaction(() async {
      final existing = await (select(ayahHighlightTable)
            ..where((t) => t.surah.equals(surah) & t.ayah.equals(ayah)))
          .getSingleOrNull();
      if (existing == null) {
        await into(ayahHighlightTable).insert(
          AyahHighlightTableCompanion.insert(
            surah: surah,
            ayah: ayah,
            colorHex: colorHex,
            createdAt: Value(DateTime.now()),
          ),
        );
      } else {
        await (update(ayahHighlightTable)
              ..where((t) => t.surah.equals(surah) & t.ayah.equals(ayah)))
            .write(AyahHighlightTableCompanion(colorHex: Value(colorHex)));
      }
    });
  }

  Future<bool> remove(int surah, int ayah) async {
    final count = await (delete(ayahHighlightTable)
          ..where((t) => t.surah.equals(surah) & t.ayah.equals(ayah)))
        .go();
    return count > 0;
  }
}

import 'dart:math';
import 'package:meta/meta.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:tawheeed/features/hadith/domain/entities/hadith.dart';
import 'package:tawheeed/shared/services/content_download_service.dart'
    show DownloadProgress;
import 'package:tawheeed/shared/services/downloaded_sqlite_db.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/text_highlight.dart';

/// Thrown when the hadith database has not been downloaded yet (the UI shows
/// a download prompt instead of a crash).
typedef HadithDatabaseMissingException = ContentDatabaseMissingException;

/// One-shot schema migration for a hadith database, run on a **worker
/// isolate** (see [DownloadedSqliteDbService.schemaWork]).
///
/// Adding `grade`/`arabic_normalized` is instant, but backfilling the
/// normalized copy touches every row (80k+ in کتب حدیث) and building the FTS
/// index then re-reads them all: several seconds that used to freeze the
/// screen on a section's first open. The v2 pass additionally rewrites the
/// rows carrying the publisher's legacy symbol glyphs (see
/// [repairLegacyHonorifics]) before the normalized copy is computed, so
/// search sees the repaired text as well. v3 then rebuilds the trigram FTS
/// index over that final text. Ends with `PRAGMA user_version`
/// so later opens skip the isolate spawn entirely.
///
/// Must stay top-level and capture nothing: only the path crosses over, and the
/// handle it opens is closed here before returning.
void migrateHadithSchema(String path) {
  final db = sqlite3.open(path, mode: OpenMode.readWrite);
  try {
    try {
      db.execute('ALTER TABLE hadiths ADD COLUMN grade TEXT');
      AppLogger.warning(
          'hadith_db_service', 'added grade column via migration');
    } catch (_) {
      // Column already exists.
    }
    _repairLegacyHonorificSymbols(db);
    _backfillNormalizedArabic(db);
    _ensureHadithsFts(db);
    db.execute('PRAGMA user_version = $hadithSchemaVersion');
  } finally {
    db.close();
  }
}

/// The [DownloadedSqliteDbService.schemaWorkVersion] [migrateHadithSchema]
/// writes. Bump both together when the migration grows a new step: installs on
/// the old revision then re-run it once.
///
/// v2 repairs the legacy «islam» symbol-font glyphs the published taraghib /
/// riyad text carries (they render as tofu boxes) — see
/// [repairLegacyHonorifics].
///
/// v3 retokenizes the full-text index with the **trigram** tokenizer and
/// rebuilds it over the current content: the external-content table then
/// serves `arabic_normalized LIKE '%…%'` — the same predicate the plain scan
/// already ran, so the result rows cannot differ — from the index instead of
/// an 80k-row scan. A trigram table whose index sits empty answers those
/// like-queries with nothing, so the rebuild runs at the end of every
/// migration pass and a failing rebuild drops the table wholesale (search
/// downgrades to the plain LIKE path — complete but slow — never partial).
const int hadithSchemaVersion = 3;

/// The legacy private-use-area honorific glyphs of the «islam» symbol font
/// (MAK Alagha / Applied Graphic Arts, 1994–2008) that the published source
/// files of صحیح الترغیب و الترهیب and ریاض الصالحین baked into their text.
/// Android's text stack has no glyph for any of them, so every one of them
/// renders as an empty box. The identities were read off the embedded font
/// itself:
///
/// * `F0C9`/`F072` — the «صلى الله عليه وسلم» calligraphy (identical
///   outlines); every position is a mention of the Prophet.
/// * `F092` — the same صلوات phrase; the shipped font left this outline
///   empty, and its one position follows «رسول الله».
/// * `F0B8` — «رضي الله عنهما», the DUAL: all its positions are the classic
///   father–son pairs (ابن عمر، ابن عباس، حسن بن علی، اسماء بنت ابی بکر…)
///   and one «حذيفة … و معاذ بن جبل».
/// * `F0C3` — «رضي الله عنه»; its outline is also empty in the shipped font,
///   and its three positions are male companions (ابوهریره و پدرش).
/// * `F0CF` — «رضي الله عنها» (feminine; every position a female narrator).
const Map<String, String> legacyHonorificSymbols = {
  '\uF072': 'صلى الله عليه وسلم',
  '\uF0C9': 'صلى الله عليه وسلم',
  '\uF092': 'صلى الله عليه وسلم',
  '\uF0B8': 'رضي الله عنهما',
  '\uF0C3': 'رضي الله عنه',
  '\uF0CF': 'رضي الله عنها',
};

/// The crescent-and-star ORNAMENT (`F05D`) that sits between a quote and its
/// verse: pure decoration, not an honorific — deleted, never replaced with
/// text the book did not print.
const String legacySymbolOrnament = '\uF05D';

/// Replaces the legacy symbol glyphs with their honorific phrases, padding
/// any side glued to a neighbour («ابوهریره» + `F0C3` + «به» becomes
/// «ابوهریره رضي الله عنه به»), and returns [text] untouched when it carries
/// no legacy glyph. Idempotent: repaired text contains no codes at all.
@visibleForTesting
String repairLegacyHonorifics(String text) {
  final codes = [...legacyHonorificSymbols.keys, legacySymbolOrnament];
  if (!codes.any((c) => text.contains(c))) return text;

  // The ornament is deleted first: padding around it would leave a stray
  // double space inside the quote it decorates.
  var out = text.replaceAll(legacySymbolOrnament, '');

  for (final code in legacyHonorificSymbols.keys) {
    final escaped = RegExp.escape(code);
    out = out.replaceAllMapped(
        RegExp('([^\\s])$escaped'), (m) => '${m[1]} $code');
    out = out.replaceAllMapped(
        RegExp('$escaped([^\\s])'), (m) => '$code ${m[1]}');
  }
  for (final e in legacyHonorificSymbols.entries) {
    out = out.replaceAll(e.key, e.value);
  }

  // One row prints the صلوات glyph twice in a row — collapse the duplicate
  // the replacement just created.
  out = out.replaceAll(
      'صلى الله عليه وسلم صلى الله عليه وسلم', 'صلى الله عليه وسلم');
  // A single source typo carries the feminine glyph after ابن عمر; the
  // book's own 75 ابن عمر positions all print the dual form.
  out = out.replaceAll('ابن عمر رضي الله عنها', 'ابن عمر رضي الله عنهما');
  return out;
}

/// Applies [repairLegacyHonorifics] to every stored row that still carries a
/// legacy glyph. Runs before [_backfillNormalizedArabic]: a database whose
/// `arabic_normalized` is not computed yet then gets the repaired text as its
/// normalized copy, while an already-migrated one is rebuilt here — which the
/// column-scoped FTS trigger mirrors into a partial index that is cleared
/// again right after (see the comment at the end).
void _repairLegacyHonorificSymbols(Database db) {
  try {
    final codes = [...legacyHonorificSymbols.keys, legacySymbolOrnament];
    final hadithWhere = codes.map((_) => 'instr(arabic, ?) > 0').join(' OR ');
    final rows =
        db.select('SELECT id, arabic FROM hadiths WHERE $hadithWhere', codes);

    final hasNameArabic = db
        .select('PRAGMA table_info(chapters)')
        .any((c) => c['name'] == 'name_arabic');
    final chapterRows = hasNameArabic
        ? db.select(
            'SELECT id, name_arabic FROM chapters WHERE '
            '${codes.map((_) => 'instr(name_arabic, ?) > 0').join(' OR ')}',
            codes)
        : const <Row>[];

    if (rows.isEmpty && chapterRows.isEmpty) return;

    final hasNormalized = db
        .select('PRAGMA table_info(hadiths)')
        .any((c) => c['name'] == 'arabic_normalized');
    AppLogger.warning(
        'hadith_db_service',
        'repairing legacy symbol glyphs: ${rows.length} hadith(s), '
            '${chapterRows.length} chapter(s)');

    db.execute('BEGIN');
    if (rows.isNotEmpty) {
      final update = hasNormalized
          ? db.prepare('UPDATE hadiths SET arabic = ?, arabic_normalized = ? '
              'WHERE id = ?')
          : db.prepare('UPDATE hadiths SET arabic = ? WHERE id = ?');
      for (final row in rows) {
        final id = row['id'] as int;
        final arabic = (row['arabic'] ?? '').toString();
        final fixed = repairLegacyHonorifics(arabic);
        if (fixed == arabic) continue;
        if (hasNormalized) {
          update.execute([fixed, TextHighlight.normalize(fixed), id]);
        } else {
          update.execute([fixed, id]);
        }
      }
      update.close();
    }
    for (final row in chapterRows) {
      final name = (row['name_arabic'] ?? '').toString();
      final fixed = repairLegacyHonorifics(name);
      if (fixed == name) continue;
      db.execute('UPDATE chapters SET name_arabic = ? WHERE id = ?',
          [fixed, row['id']]);
    }
    db.execute('COMMIT');

    // The repair only rewrites `arabic` (+ `arabic_normalized`) — it never
    // consults or "fixes" the index. Historically v2 ended it with a
    // `delete-all` because the partial trigger-written index could hide the
    // complete LIKE result set (the v1 backfill never populated anything:
    // a scan of an external-content FTS table reads the content table, so
    // its `id NOT IN (SELECT rowid …)` matched nothing and search always
    // ran on the plain LIKE path). v3 reconciles differently: the migration
    // closes with a full trigram rebuild over the final content
    // ([_ensureHadithsFts]), and a rebuild that cannot complete drops the
    // table — so no half-built index ever outlives the pass.
  } catch (e) {
    AppLogger.warning('hadith_db_service', 'legacy symbol repair failed: $e');
  }
}

/// Adds an [arabic_normalized] column (tashkeel/alif/ta-marbuta normalized
/// copy of the arabic text) so that un-diacritized Arabic queries match the
/// diacritized stored text, then backfills any rows still missing it.
void _backfillNormalizedArabic(Database db) {
  try {
    final cols = db.select('PRAGMA table_info(hadiths)');
    final hasCol = cols.any((c) => c['name'] == 'arabic_normalized');
    if (!hasCol) {
      db.execute('ALTER TABLE hadiths ADD COLUMN arabic_normalized TEXT');
    }

    final nullCount = db
        .select(
            'SELECT COUNT(*) as c FROM hadiths WHERE arabic_normalized IS NULL')
        .first['c'] as int;
    if (nullCount == 0) return;

    AppLogger.warning(
        'hadith_db_service', 'normalizing $nullCount hadiths for search');
    db.execute('BEGIN');
    final select = db.prepare(
        'SELECT id, arabic FROM hadiths WHERE arabic_normalized IS NULL');
    final update =
        db.prepare('UPDATE hadiths SET arabic_normalized = ? WHERE id = ?');
    for (final row in select.select()) {
      final id = row['id'] as int;
      final arabic = (row['arabic'] ?? '').toString();
      update.execute([TextHighlight.normalize(arabic), id]);
    }
    update.close();
    select.close();
    db.execute('COMMIT');
  } catch (e) {
    AppLogger.warning('hadith_db_service', 'normalization failed: $e');
  }
}

/// Full-text index over the normalized Arabic text, retokenized with the
/// **trigram** tokenizer (v3): the external-content table then answers
/// `arabic_normalized LIKE '%…%'` — the exact predicate search already ran —
/// from the index instead of a full-table scan. Verified on the bundled
/// engine: candidates through the index are re-checked against the stored
/// value, so the result set equals the plain scan's; a pattern with no run
/// of ≥3 characters degrades to that same scan.
///
/// The index is rebuilt here at the end of every migration pass that seeds
/// it. A trigram table whose index sits EMPTY answers like-queries with
/// nothing (content rows are invisible to the accelerated path), so a failed
/// rebuild drops the table wholesale: search then falls back to the plain
/// LIKE scan ([HadithDbService._ftsHadithsByLike]), which is complete.
void _ensureHadithsFts(Database db) {
  try {
    // The tokenizer is baked into an FTS5 table forever: upgrade the legacy
    // unicode61 one by dropping and recreating it. Content lives in
    // `hadiths` and is never touched by either.
    final tables = db.select(
        "SELECT sql FROM sqlite_master WHERE type = 'table' "
        "AND name = 'hadiths_fts'");
    final existing =
        tables.isEmpty ? null : tables.first['sql'] as String?;
    if (existing != null && !existing.contains('trigram')) {
      db.execute('DROP TRIGGER IF EXISTS hadiths_fts_au');
      db.execute('DROP TRIGGER IF EXISTS hadiths_fts_ad');
      db.execute('DROP TRIGGER IF EXISTS hadiths_fts_ai');
      db.execute('DROP TABLE hadiths_fts');
    }
    db.execute('CREATE VIRTUAL TABLE IF NOT EXISTS hadiths_fts USING fts5('
        "arabic_normalized, content='hadiths', content_rowid='id', "
        "tokenize='trigram')");
    db.execute('''CREATE TRIGGER IF NOT EXISTS hadiths_fts_ai
        AFTER INSERT ON hadiths BEGIN
          INSERT INTO hadiths_fts(rowid, arabic_normalized)
          VALUES (new.id, new.arabic_normalized);
        END''');
    db.execute('''CREATE TRIGGER IF NOT EXISTS hadiths_fts_ad
        AFTER DELETE ON hadiths BEGIN
          INSERT INTO hadiths_fts(hadiths_fts, rowid, arabic_normalized)
          VALUES ('delete', old.id, old.arabic_normalized);
        END''');
    // NOTE: column-scoped (`OF arabic_normalized`), not plain AFTER UPDATE:
    // a whole-row trigger fires delete+reinsert even when only an
    // unrelated column (e.g. `grade`) changes, which corrupts this
    // external-content index (SQLITE_CORRUPT_VTAB on the next write).
    // Always recreate: databases migrated before v3 may still carry a
    // legacy whole-row trigger of this name.
    db.execute('DROP TRIGGER IF EXISTS hadiths_fts_au');
    db.execute('''CREATE TRIGGER hadiths_fts_au
        AFTER UPDATE OF arabic_normalized ON hadiths BEGIN
          INSERT INTO hadiths_fts(hadiths_fts, rowid, arabic_normalized)
          VALUES ('delete', old.id, old.arabic_normalized);
          INSERT INTO hadiths_fts(rowid, arabic_normalized)
          VALUES (new.id, new.arabic_normalized);
        END''');
    // Populate-once through the canonical external-content command: the
    // v1-era `INSERT … WHERE id NOT IN (SELECT rowid …)` backfill could
    // never insert anything (that scan reads the content table), and a
    // trigram table left empty answers every accelerated like-query with
    // nothing — see the doc on [_ensureHadithsFts].
    db.execute("INSERT INTO hadiths_fts(hadiths_fts) VALUES('rebuild')");
  } catch (e) {
    // FTS unavailable (or a locked DB): searches transparently fall back
    // to the LIKE path in [HadithDbService._ftsHadithsByLike]. Drop the
    // table too when the rebuild failed half-way — a table with an empty
    // token index hides every accelerated match, while no table at all
    // degrades search gracefully to the complete plain scan.
    try {
      db.execute('DROP TABLE IF EXISTS hadiths_fts');
    } catch (_) {
      // Nothing more can be done; the like-path search still stands.
    }
    AppLogger.warning('hadith_db_service', 'FTS setup failed: $e');
  }
}

/// Offline hadith database service.
///
/// The database is NOT bundled anymore to keep the app small — it is
/// downloaded once (as `hadith.db.gz`, ~17 MB) from the hosted content catalog
/// into `Documents/hadith.db` and kept forever. The UI checks
/// [HadithDbService.isDownloaded] before opening the books screen and offers a
/// download button with progress. [init] throws
/// [HadithDatabaseMissingException] when the file is absent so callers can
/// surface the download prompt. The schema is migrated automatically when
/// needed (adds the `grade`/`arabic_normalized` columns and repairs the
/// publisher's legacy symbol glyphs) on a worker isolate — see
/// [migrateHadithSchema].
class HadithDbService extends DownloadedSqliteDbService {
  static HadithDbService? _instance;
  factory HadithDbService() => _instance ??= HadithDbService._();
  HadithDbService._({
    super.dbFileName = 'hadith.db',
    super.remoteKey = 'hadith/hadith.db',
    super.contentRevision = 1,
    super.minChapters = 0,
  }) : super(readOnly: false, schemaWork: migrateHadithSchema);

  /// Standalone ریاض الصالحین database — a separate download
  /// (`riyad/ryadalsalihin.db.gz`) so readers of this section never need the
  /// full کتب حدیث payload (and vice versa).
  ///
  /// Revision 2 is the first build taken straight from the six Word volumes
  /// instead of being cut out of `hadith.db`: 372 باب (the edition's own
  /// count — the cut-out copy carried 366 and missed the five ببs whose
  /// heading lost the word «باب»), 1,897 narrations, the 19 «کتاب» chain in
  /// `chapters.part`, every پانوشت anchored to its own line, the verses each
  /// باب opens with (`preambles`) and the first volume's مقدمه‌ها
  /// (`matter_sections`). The old copy carried no footnotes and no chain, and
  /// its numbering lived in a bundled label table.
  ///
  /// Revision 3 is the same six-volume build with two columns repaired: every
  /// باب's printed heading is now written into `name_arabic` as well, which is
  /// the column the readers ask, and the 83 ببs that a volume prints before its
  /// first «کتاب» heading take the label of the next labelled chapter instead of
  /// an empty chain, so they group under their کتاب like the rest. No text and
  /// no count moved — 372 باب / 1,897 narrations / 3,288 پانوشت either way.
  ///
  /// Revision 4 republishes that same six-volume payload beside معالم's
  /// footnote repair: the build was produced again from the Word volumes and
  /// came out byte-identical, so this number moves only to keep the two study
  /// books on one publication. Unlike معالم, no reader's copy is wrong — an
  /// install that does not fetch this revision still holds the same bytes.
  static final HadithDbService riyad = HadithDbService._(
      dbFileName: 'ryadalsalihin.db',
      remoteKey: 'riyad/ryadalsalihin.db',
      contentRevision: 4,
      // The six-volume build carries 372 باب. A copy cut out of the old
      // `hadith.db` (366) is stale whatever number its install recorded.
      minChapters: 370);

  /// صحیح الترغیب و الترهیب — the full 29-book edition (428 chapters, 3,775
  /// numbered hadiths plus the مقدمه and خاتمه sections).
  ///
  /// Revision 3 stores every پانوشت with the text it belongs to (the `footnotes`
  /// table) instead of a collected list at the end of the book, and keeps the
  /// publisher's notices between a heading and its first entry (the `preambles`
  /// table). `contentRevision` is what lets an install that already holds an
  /// older copy replace it (`ensureDownloaded` returns early for any valid file
  /// on disk, so a republished payload is invisible without it).
  ///
  /// Revision 4 adds `footnotes.anchor_line` — the 0-based index of the line of
  /// `hadiths.arabic` a پانوشت is printed against, so the reader can mark its
  /// number inside the text instead of only listing it below. Rows that belong
  /// to a heading, a notice or the مقدمه/خاتمه keep it NULL. Nothing else in the
  /// payload changed; the bump only exists to hand the column to installs that
  /// still hold a revision-3 copy.
  ///
  /// Revision 5 drops the two «پایان جلد» sections the edition printed as
  /// volume furniture (their nine paragraphs and their notes). The book now
  /// ends at its own خاتمه, exactly as a reader expects.
  static final HadithDbService taraghib = HadithDbService._(
      dbFileName: 'taraghib.db',
      remoteKey: 'taraghib/taraghib.db',
      contentRevision: 5,
      minChapters: 426);

  /// Standalone معالم السنه النبویه database — the whole four-volume work in
  /// one small, self-contained download (`maalim/maalim.db.gz`) so its readers
  /// never need the full کتب حدیث payload either.
  ///
  /// Revision 2 replaced the first hosted parse (276 rows without the book's
  /// TOC discipline) with the corrected single volume. Revision 3 is the full
  /// edition: 49 کتاب, 1,929 باب, 3,823 حدیث, 3,831 پانوشت, 119 notice
  /// paragraphs and the مقدمه/خاتمه sections — the first two revisions only
  /// ever carried one volume (274 باب / 474 حدیث). Bump again whenever
  /// maalim.db is republished so installed copies pick the correction up.
  ///
  /// Revision 4 is a repair of revision 3's *payload*, not of its number: the
  /// build that shipped it was still the one-volume parse, so an install that
  /// pressed «دانلود» between the bump and the republish recorded revision 3
  /// over the old bytes and would never fetch again — `needsUpdate` compares
  /// the stored number with this one, and they matched. The same full edition
  /// now additionally carries `chapters.part` (the مقصد › کتاب › فصل chain the
  /// فهرست groups by) and `chapters.is_bab`, so the number had to move for both
  /// reasons to reach that copy.
  ///
  /// Revision 5 gives the edition ONE `books` row: the 49 «کتاب»s of its own
  /// chain are labels in `chapters.part`, and every باب takes the next
  /// `chapter_index` of the whole book (1..1929). Revision 4 wrote the kits as
  /// `books` rows, so the section — which lists one book's chapters — showed
  /// 55 of 1,929 ببs.
  ///
  /// Revision 6 writes each باب's printed heading into `name_arabic` too, the
  /// column the readers actually ask, so a fresh download carries its title
  /// there instead of relying on the query-layer borrow. The chain, the counts
  /// and every text are the revision-5 edition's: 1,929 باب / 3,823 حدیث /
  /// 3,831 پانوشت.
  ///
  /// Revision 7 anchors the introduction's notes to the introduction: the
  /// converter read volume 1 twice, and the second pass had no chapter to hang
  /// the front matter's thirteen پانوشت‌ها on, so the first باب («ارکان اسلام و
  /// ایمان») adopted them and printed them above its narrations. The باب and
  /// narration counts are untouched (1,929 / 3,823); the notes now total 3,819
  /// because twelve of the thirty-one were the same thirteen written twice.
  ///
  /// Revision 8 numbers the narrations the way the page does: `hadith_number`
  /// is the printed number (1..3921), not a running counter, so «حدیث ۱۰۶۸»
  /// is the same narration the printed book numbers 1068 and the jump box
  /// reaches the same place the reader would flip to. The printed edition
  /// skips 244 numbers it never used and prints 144 of them twice (its own
  /// errata, reproduced here instead of silently renumbered); a number the
  /// book does not carry answers with the section's «در این نسخه نیست» notice.
  /// Four source typos past the ceiling (3963/4225/4329/7334) take their
  /// running position, or the book's last number would read 7334.
  static final HadithDbService maalim = HadithDbService._(
      dbFileName: 'maalim.db',
      remoteKey: 'maalim/maalim.db',
      contentRevision: 8,
      // 1,929 rows. The one-volume parse this section shipped first carried
      // 276, and that is the copy that outlived its revision number.
      minChapters: 1900);

  /// Local path of the default (کتب حدیث) database.
  static Future<String> dbPath() => HadithDbService().localPath();

  /// Whether a valid copy of the default database is already on disk.
  static Future<bool> isDownloaded() => HadithDbService().isDownloadedFile();

  /// Downloads the default database (decompressing `hadith.db.gz`).
  static Future<void> download({DownloadProgress? onProgress}) =>
      HadithDbService().downloadFile(onProgress: onProgress);

  static Future<void> deleteDownloaded() async =>
      HadithDbService().deleteDownloadedFile();

  /// Alias of [ensureReady] under the historical name; runs the schema
  /// migrations (grade / arabic_normalized) on first open.
  Future<void> init() => ensureReady();

  @override
  int get schemaWorkVersion => hadithSchemaVersion;

  /// The LIKE predicate answered through the trigram table. Returns null
  /// when the FTS table is unavailable (caller falls back to the plain scan);
  /// otherwise the matches, possibly empty.
  ///
  /// The rows are the plain scan's rows: SQLite serves the pattern from the
  /// trigram index and re-checks each candidate against the stored value
  /// (verified on the bundled 3.53 — a row whose trigrams appear scattered
  /// is NOT returned), so infix/completeness semantics are unchanged.
  /// Book/grade predicates resolve against the joined content table exactly
  /// as the fallback query binds them.
  Future<List<Map<String, dynamic>>?> _ftsHadithsByLike(
    String q, {
    int? bookId,
    List<String> gradeAliases = const [],
    required int limit,
  }) async {
    try {
      final where = StringBuffer('hadiths_fts.arabic_normalized LIKE ?');
      final args = <Object?>['%$q%'];
      if (bookId != null) {
        where.write(' AND book_id = ?');
        args.add(bookId);
      }
      if (gradeAliases.isNotEmpty) {
        where.write(
            ' AND lower(trim(grade)) IN (${List.filled(gradeAliases.length, '?').join(',')})');
        args.addAll(gradeAliases);
      }
      args.add(limit);
      final rows = db.select(
        'SELECT h.* FROM hadiths_fts JOIN hadiths h '
        'ON h.id = hadiths_fts.rowid WHERE $where '
        'ORDER BY h.book_id, h.hadith_number LIMIT ?',
        args,
      );
      return [for (final r in rows) Map<String, dynamic>.from(r)];
    } catch (e) {
      AppLogger.warning('hadith_db_service', 'indexed like lookup failed: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getAllBooks() async {
    return [
      for (final r in db.select('SELECT * FROM books ORDER BY id'))
        Map<String, dynamic>.from(r)
    ];
  }

  Future<Map<String, dynamic>?> getBook(int id) async {
    final rows = db.select('SELECT * FROM books WHERE id = ?', [id]);
    return rows.isNotEmpty ? Map<String, dynamic>.from(rows.first) : null;
  }

  // ─── Chapter queries ────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getChaptersForBook(int bookId) async {
    final rows = db.select(
        'SELECT * FROM chapters WHERE book_id = ? ORDER BY chapter_index',
        [bookId]);
    return rows.map(_withPrintedName).toList(growable: false);
  }

  /// A chapter row whose heading is readable, whichever column carries it.
  ///
  /// The Word-built books (معالم, ریاض) print one heading per division, and the
  /// builder wrote it to `name_persian` while leaving `name_arabic` empty — the
  /// reader reads `name_arabic`, so every باب listed a blank title. Both columns
  /// name the same printed line, so an empty one borrows the other.
  Map<String, dynamic> _withPrintedName(Row row) {
    final map = Map<String, dynamic>.from(row);
    final arabic = (map['name_arabic'] ?? '').toString().trim();
    if (arabic.isNotEmpty) return map;
    final persian = (map['name_persian'] ?? '').toString().trim();
    if (persian.isNotEmpty) map['name_arabic'] = persian;
    return map;
  }

  /// Every chapter of the database, ordered by book then chapter — one query
  /// for a section whose search results must resolve a hit's book and chapter.
  Future<List<Map<String, dynamic>>> getAllChapters() async {
    final rows = db.select(
        'SELECT * FROM chapters ORDER BY book_id, chapter_index');
    return rows.map(_withPrintedName).toList(growable: false);
  }

  /// Chapters for a set of `chapters.id` values — one query for the chapters
  /// the rows of a search hit belong to. Empty input returns an empty list.
  Future<List<Map<String, dynamic>>> getChaptersByIds(List<int> ids) async {
    if (ids.isEmpty) return const [];
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows =
        db.select('SELECT * FROM chapters WHERE id IN ($placeholders)', ids);
    return rows.map(_withPrintedName).toList(growable: false);
  }

  // ─── Hadith queries ─────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getHadithsForBook(int bookId,
      {int? limit, int offset = 0}) async {
    if (limit != null) {
      return [
        for (final r in db.select(
            'SELECT * FROM hadiths WHERE book_id = ? ORDER BY hadith_number LIMIT ? OFFSET ?',
            [bookId, limit, offset]))
          Map<String, dynamic>.from(r)
      ];
    }
    return [
      for (final r in db.select(
          'SELECT * FROM hadiths WHERE book_id = ? ORDER BY hadith_number',
          [bookId]))
        Map<String, dynamic>.from(r)
    ];
  }

  Future<List<Map<String, dynamic>>> getHadithsForChapter(int chapterId,
      {int limit = 50}) async {
    return [
      for (final r in db.select(
          'SELECT * FROM hadiths WHERE chapter_id = ? ORDER BY hadith_number LIMIT ?',
          [chapterId, limit]))
        Map<String, dynamic>.from(r)
    ];
  }

  /// Hadiths of a chapter identified by its `chapter_index` (which is what the
  /// UI shows; fractional ids like `35.2` work too).
  Future<List<Map<String, dynamic>>> getHadithsForChapterIndex(
      int bookId, num chapterIndex) async {
    return [
      for (final r in db.select(
          'SELECT h.* FROM hadiths h JOIN chapters c ON h.chapter_id = c.id '
          'WHERE c.book_id = ? AND c.chapter_index = ? ORDER BY h.hadith_number',
          [bookId, chapterIndex.toDouble()]))
        Map<String, dynamic>.from(r)
    ];
  }

  /// Every hadith carrying [number] in whatever database is open. Whether a
  /// number is unique depends on the edition (the general کتب حدیث database
  /// restarts numbering per book; the taraghib edition numbers 1..N globally),
  /// so callers must not assume either way.
  ///
  /// `hadith_number` carries no index (the generator creates only the chapter
  /// and book indexes), so this is a filtered scan — the same cost class as
  /// the whole-book reads this service already serves.
  Future<List<Map<String, dynamic>>> getHadithsByNumber(int number,
      {int limit = 20}) async {
    if (number <= 0 || limit <= 0) return const [];
    return [
      for (final r in db.select(
          'SELECT * FROM hadiths WHERE hadith_number = ? '
          'ORDER BY book_id, chapter_id, id LIMIT ?',
          [number, limit]))
        Map<String, dynamic>.from(r)
    ];
  }

  /// Chapter hadith counts for a whole book in a single query.
  Future<Map<num, int>> getHadithCountsPerChapter(int bookId) async {
    final rows = db.select(
        'SELECT c.chapter_index AS idx, COUNT(h.id) AS c FROM chapters c '
        'LEFT JOIN hadiths h ON h.chapter_id = c.id '
        'WHERE c.book_id = ? GROUP BY c.chapter_index',
        [bookId]);
    return {
      for (final r in rows) ((r['idx'] as num).toDouble()): (r['c'] as int),
    };
  }

  /// (chapter_index, hadith_number) pairs of a whole book, ordered —
  /// used by the riyad section for exact per-chapter hadith counts.
  Future<List<Map<String, dynamic>>> getChapterEntryNumbers(int bookId) async {
    final rows = db.select(
        'SELECT c.chapter_index AS idx, h.hadith_number AS no '
        'FROM chapters c JOIN hadiths h ON h.chapter_id = c.id '
        'WHERE c.book_id = ? ORDER BY c.chapter_index, h.hadith_number',
        [bookId]);
    return [for (final r in rows) Map<String, dynamic>.from(r)];
  }

  /// Optional label columns (`is_matn`, `print_no`) baked into the standalone
  /// riyad database v2. Throws when the on-disk database predates them.
  Future<List<Map<String, dynamic>>> getEntryLabelRows(int bookId) async {
    final rows = db.select(
        'SELECT hadith_number AS no, is_matn AS m, print_no AS p '
        'FROM hadiths WHERE book_id = ? ORDER BY hadith_number',
        [bookId]);
    return [for (final r in rows) Map<String, dynamic>.from(r)];
  }

  Future<Map<String, dynamic>?> getHadith(int id) async {
    final rows = db.select('SELECT * FROM hadiths WHERE id = ?', [id]);
    return rows.isNotEmpty ? Map<String, dynamic>.from(rows.first) : null;
  }

  Future<int> getHadithCountForBook(int bookId) async {
    final result = db.select(
        'SELECT COUNT(*) as c FROM hadiths WHERE book_id = ?', [bookId]).first;
    return result['c'] as int;
  }

  /// Total hadith rows of the whole database — the count a section header
  /// reports, never a hand-written constant.
  Future<int> getHadithCount() async {
    final result = db.select('SELECT COUNT(*) as c FROM hadiths').first;
    return result['c'] as int;
  }

  /// Hadith totals keyed by `books.id` — one query for a book list.
  Future<Map<int, int>> getHadithCountsPerBook() async {
    final rows = db.select(
        'SELECT book_id AS b, COUNT(*) AS c FROM hadiths GROUP BY book_id');
    return {for (final r in rows) (r['b'] as int): (r['c'] as int)};
  }

  /// Chapter totals keyed by `books.id` — one query for a book list.
  Future<Map<int, int>> getChapterCountsPerBook() async {
    final rows = db.select(
        'SELECT book_id AS b, COUNT(*) AS c FROM chapters GROUP BY book_id');
    return {for (final r in rows) (r['b'] as int): (r['c'] as int)};
  }

  /// Every numbered hadith in print order (`hadith_number`), each row carrying
  /// the `book_id` and its chapter's `chapter_index` — what a jump-by-number
  /// needs to resolve a number to a location.
  Future<List<Map<String, dynamic>>> getNumberedEntries() async {
    final rows = db.select(
        'SELECT h.hadith_number AS no, h.book_id AS book, c.chapter_index AS idx '
        'FROM hadiths h JOIN chapters c ON c.id = h.chapter_id '
        'ORDER BY h.hadith_number');
    return [for (final r in rows) Map<String, dynamic>.from(r)];
  }

  // ─── Matter sections (مقدمه / خاتمه) ───────────────────────
  //
  // These tables only exist in databases built with them (the taraghib edition
  // from revision 2 on). Callers treat a missing table as "this database has no
  // matter sections", never as an error.

  /// All matter sections in reading order.
  Future<List<Map<String, dynamic>>> getMatterSections() async {
    final rows = db.select(
        'SELECT * FROM matter_sections ORDER BY sort_order, id');
    return [for (final r in rows) Map<String, dynamic>.from(r)];
  }

  /// Paragraphs of one matter section in order.
  Future<List<Map<String, dynamic>>> getMatterParagraphs(int sectionId) async {
    final rows = db.select(
        'SELECT * FROM matter_paragraphs WHERE section_id = ? '
        'ORDER BY para_order, id',
        [sectionId]);
    return [for (final r in rows) Map<String, dynamic>.from(r)];
  }

  /// Paragraph totals keyed by `matter_sections.id` — one query for the list.
  Future<Map<int, int>> getMatterParagraphCounts() async {
    final rows = db.select('SELECT section_id AS s, COUNT(*) AS c '
        'FROM matter_paragraphs GROUP BY section_id');
    return {for (final r in rows) (r['s'] as int): (r['c'] as int)};
  }

  // ─── Footnotes and publisher notices ────────────────────────
  //
  // Revision 3 keeps every پانوشت with the text it annotates, so a reader can
  // print it where the book prints it. The tables follow the same contract as
  // the matter tables: a database built without them answers with nothing.

  /// Every footnote of one chapter: the ones on its hadiths (grouped in Dart by
  /// `hadith_id`), the chapter-heading footnote (no hadith and no preamble), and
  /// the ones on a preamble paragraph of the chapter.
  Future<List<Map<String, dynamic>>> getFootnotesForChapter(
      int chapterId) async {
    final rows = db.select(
        'SELECT f.* FROM footnotes f '
        'LEFT JOIN hadiths h ON h.id = f.hadith_id '
        'WHERE (f.chapter_id = ? AND f.hadith_id IS NULL) OR h.chapter_id = ? '
        'ORDER BY f.sort_order, f.id',
        [chapterId, chapterId]);
    return [for (final r in rows) Map<String, dynamic>.from(r)];
  }

  /// Footnotes that belong to the book itself — its heading and a book preamble
  /// paragraph — never to one of its chapters or hadiths.
  Future<List<Map<String, dynamic>>> getFootnotesForBook(int bookId) async {
    final rows = db.select(
        'SELECT * FROM footnotes WHERE book_id = ? AND chapter_id IS NULL '
        'AND hadith_id IS NULL ORDER BY sort_order, id',
        [bookId]);
    return [for (final r in rows) Map<String, dynamic>.from(r)];
  }

  /// Footnotes of one مقدمه/خاتمه section. Each row carries `source_para`, which
  /// is how a screen prints it under the paragraph it belongs to.
  Future<List<Map<String, dynamic>>> getFootnotesForSection(
      int sectionId) async {
    final rows = db.select(
        'SELECT * FROM footnotes WHERE section_id = ? ORDER BY sort_order, id',
        [sectionId]);
    return [for (final r in rows) Map<String, dynamic>.from(r)];
  }

  /// The publisher's notices printed between one chapter heading and its first
  /// entry, in the order the book prints them.
  Future<List<Map<String, dynamic>>> getChapterPreambles(int chapterId) async {
    final rows = db.select(
        'SELECT * FROM preambles WHERE chapter_id = ? ORDER BY id', [chapterId]);
    return [for (final r in rows) Map<String, dynamic>.from(r)];
  }

  /// Notices printed between a book heading and its first chapter.
  Future<List<Map<String, dynamic>>> getBookPreambles(int bookId) async {
    final rows = db.select(
        'SELECT * FROM preambles WHERE book_id = ? AND chapter_id IS NULL '
        'ORDER BY id',
        [bookId]);
    return [for (final r in rows) Map<String, dynamic>.from(r)];
  }

  // ─── Search ─────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> searchArabic(String query,
      {int limit = 50}) async {
    final q = TextHighlight.arabicSearchKey(query);
    // The LIKE predicate itself is served by the trigram index (same exact
    // rows as the scan; a pattern with no ≥3-char run degrades to the scan).
    // Any index trouble falls back to the plain LIKE path — identical rows,
    // slower.
    final fast = await _ftsHadithsByLike(q, limit: limit);
    if (fast != null && fast.isNotEmpty) return fast;
    return [
      for (final r in db.select(
          'SELECT * FROM hadiths WHERE arabic_normalized LIKE ? '
          'ORDER BY book_id, hadith_number LIMIT ?',
          ['%$q%', limit]))
        Map<String, dynamic>.from(r)
    ];
  }

  Future<List<Map<String, dynamic>>> searchHadiths({
    required String qArabic,
    int limit = 50,
    int? bookId,
    HadithGrade? grade,
  }) async {
    final q = TextHighlight.arabicSearchKey(qArabic);
    final gradeAliases = grade == null ? const <String>[] : grade.dbAliases;
    // Indexed by the trigram table (exact LIKE rows); the plain scan below
    // is the identical-predicate fallback for any FTS trouble.
    final fast = await _ftsHadithsByLike(q,
        bookId: bookId, gradeAliases: gradeAliases, limit: limit);
    if (fast != null && fast.isNotEmpty) return fast;

    // LIKE fallback — same predicates, everything bound.
    final where = StringBuffer('arabic_normalized LIKE ?');
    final args = <Object?>['%$q%'];
    if (bookId != null) {
      where.write(' AND book_id = ?');
      args.add(bookId);
    }
    if (gradeAliases.isNotEmpty) {
      where.write(
          ' AND lower(trim(grade)) IN (${List.filled(gradeAliases.length, '?').join(',')})');
      args.addAll(gradeAliases);
    }
    args.add(limit);
    return [
      for (final r in db.select(
          'SELECT * FROM hadiths WHERE $where '
          'ORDER BY book_id, hadith_number LIMIT ?',
          args))
        Map<String, dynamic>.from(r)
    ];
  }

  Future<List<Map<String, dynamic>>> searchBooks(String query) async {
    return [
      for (final r in db.select(
          'SELECT * FROM books WHERE title_arabic LIKE ?', ['%$query%']))
        Map<String, dynamic>.from(r)
    ];
  }

  // ─── Grade-filtered search ──────────────────────────────────

  Future<List<Map<String, dynamic>>> searchByGrade(HadithGrade grade,
      {int limit = 100}) async {
    if (grade == HadithGrade.unknown) return [];
    return [
      for (final r in db.select(
          'SELECT * FROM hadiths WHERE grade = ? '
          'ORDER BY book_id, hadith_number LIMIT ?',
          [grade.name, limit]))
        Map<String, dynamic>.from(r)
    ];
  }

  // ─── Random hadith ──────────────────────────────────────────

  /// Random pick via a random offset instead of `ORDER BY RANDOM()` (which
  /// sorts the whole table on every call).
  Future<Map<String, dynamic>?> getRandomHadith() async {
    final count =
        db.select('SELECT COUNT(*) as c FROM hadiths').first['c'] as int;
    if (count == 0) return null;
    final offset = Random().nextInt(count);
    final rows = db.select('SELECT * FROM hadiths LIMIT 1 OFFSET ?', [offset]);
    return rows.isNotEmpty ? Map<String, dynamic>.from(rows.first) : null;
  }

  Future<Map<String, dynamic>?> getRandomHadithFromBook(int bookId) async {
    final count = db.select(
        'SELECT COUNT(*) as c FROM hadiths WHERE book_id = ?',
        [bookId]).first['c'] as int;
    if (count == 0) return null;
    final offset = Random().nextInt(count);
    final rows = db.select(
        'SELECT * FROM hadiths WHERE book_id = ? LIMIT 1 OFFSET ?',
        [bookId, offset]);
    return rows.isNotEmpty ? Map<String, dynamic>.from(rows.first) : null;
  }

  // ─── Cleanup ──────────────────────────────────────────────────
}

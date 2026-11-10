import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import 'package:tawheeed/features/hadeeth_enc/domain/entities/hadeeth_enc_hadith.dart';
import 'package:tawheeed/shared/services/downloaded_sqlite_db.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// Offline database service for موسوعه احادیث (HadeethEnc.com Persian dump).
///
/// The categorized database (~2.1 MB gzipped) is downloaded on demand from the
/// content repo — same pattern as ریاض الصالحین and فتاوای شرعی — keeping the
/// APK slim and allowing content refreshes without an app release.
class HadeethEncDbService extends DownloadedSqliteDbService {
  static HadeethEncDbService? _instance;
  factory HadeethEncDbService() => _instance ??= HadeethEncDbService._();
  HadeethEncDbService._()
      : super(
            dbFileName: 'hadeeth_enc.db',
            remoteKey: 'hadeeth_enc/hadeeth_enc.db',
            readOnly: false);

  /// Global 1-based encyclopedia number of each row (source order by id),
  /// built once per open.
  ///
  /// This used to be `ROW_NUMBER() OVER (ORDER BY id)` inside every query. A
  /// window is the last step of a select, so no predicate can push below it:
  /// each list page, each tap on a hadith and each keystroke of a search
  /// materialized and sorted the WHOLE table — every text column of all ~30k
  /// rows — on the UI isolate. The rank is a plain function of the id order, so
  /// one id-only scan at open time replaces it and the queries go back to using
  /// the primary key.
  ///
  /// Filtered results still get the encyclopedia number (never the list
  /// position), which is what «شمارهٔ حدیث» shows in the list badge, the detail
  /// title and shared text/image.
  Map<int, int> _sequenceById = const {};

  /// Ids in encyclopedia order — the inverse of [_sequenceById], position 0
  /// being hadith number ۱.
  List<int> _idsBySequence = const [];

  /// Loads [_sequenceById] and [_idsBySequence] unless already loaded. Ids
  /// only: the scan covers the table once per open, instead of once per query.
  Future<void> _ensureSequenceTable() async {
    if (_sequenceById.isNotEmpty) return;
    // An id-only covering scan: no text column is read, so this stays a
    // one-off millisecond cost on the UI isolate rather than an isolate spawn.
    final ids = [
      for (final r in db.select('SELECT id FROM hadiths ORDER BY id'))
        (r['id'] as num).toInt()
    ];
    _idsBySequence = ids;
    _sequenceById = {
      for (final e in ids.asMap().entries) e.value: e.key + 1,
    };
  }

  /// Main thematic categories (دسته‌های اصلی HadeethEnc.com).
  static const List<(int, String)> mainCategories = [
    (1, 'قرآن و علوم قرآنی'),
    (2, 'حدیث و علوم حدیث'),
    (3, 'عقیده'),
    (4, 'فقه و اصول'),
    (5, 'فضائل و آداب'),
    (6, 'دعوت و احتساب'),
    (7, 'سیرت و تاریخ'),
  ];

  /// Whether a current (categorized) database is already on disk. A legacy
  /// pre-category copy is treated as missing so the UI offers re-download.
  Future<bool> isAvailable() async {
    try {
      final file = File(await localPath());
      if (!await file.exists()) return false;
      final probe = sqlite3.open(file.path);
      final cols = probe
          .select('PRAGMA table_info(hadiths)')
          .map((r) => r['name'])
          .toSet();
      probe.close();
      return cols.contains('category');
    } catch (_) {
      AppLogger.warning('hadeeth_enc_db_service', 'operation failed');
      return false;
    }
  }

  Future<void> download({ContentDownloadProgress? onProgress}) =>
      downloadFile(onProgress: onProgress);

  /// Removes the downloaded database; [close] resets the memo tables.
  Future<void> deleteDownloaded() => deleteDownloadedFile();

  Future<void> init() async {
    await ensureReady();
    await _ensureSequenceTable();
  }

  @override
  void onReady(Database db) {
    try {
      final count = db.select('SELECT COUNT(*) as c FROM hadiths').first['c'];
      AppLogger.warning('hadeeth_enc_db_service', "'ready, $count hadiths'");
    } catch (e) {
      AppLogger.warning(
          'hadeeth_enc_db_service', "'ready but query failed: $e'");
    }
  }

  int _total = 0;

  /// Total number of hadiths (cached after the first call).
  Future<int> getCount({String? category}) async {
    await init();
    if (category == null || category.isEmpty) {
      if (_total == 0) {
        _total =
            db.select('SELECT COUNT(*) as c FROM hadiths').first['c'] as int;
      }
      return _total;
    }
    return db.select('SELECT COUNT(*) as c FROM hadiths WHERE category = ?',
        [category]).first['c'] as int;
  }

  /// Subcategory names of one main category (موضوع‌ها), alphabetical.
  Future<List<String>> subCategories(int mainId) async {
    await init();
    return [
      for (final r in db.select(
          'SELECT DISTINCT category FROM hadiths '
          'WHERE cat_main = ? AND category IS NOT NULL ORDER BY category',
          [mainId]))
        r['category'] as String,
    ];
  }

  /// Paginated list (id + titles only, cheap) ordered by source order.
  /// Every row carries its global `sequence` so a topic-filtered page keeps
  /// the real hadith number instead of renumbering from 1.
  Future<List<HadeethEncHadith>> getPage({
    int offset = 0,
    int limit = 50,
    String? category,
  }) async {
    await init();
    if (category != null && category.isNotEmpty) {
      return _rowsToHadiths(db.select(
        'SELECT id, title_ar, title FROM hadiths '
        'WHERE category = ? ORDER BY id LIMIT ? OFFSET ?',
        [category, limit, offset],
      ));
    }
    return _rowsToHadiths(db.select(
      'SELECT id, title_ar, title FROM hadiths ORDER BY id LIMIT ? OFFSET ?',
      [limit, offset],
    ));
  }

  Future<HadeethEncHadith?> getHadith(int id) async {
    await init();
    final rows = db.select('SELECT * FROM hadiths WHERE id = ?', [id]);
    if (rows.isEmpty) return null;
    return _rowsToHadiths(rows).single;
  }

  /// One pass for a whole favorites list, instead of one query per hadith.
  Future<List<HadeethEncHadith>> getByIds(List<int> ids) async {
    if (ids.isEmpty) return const [];
    await init();
    final marks = List<String>.filled(ids.length, '?').join(',');
    return _rowsToHadiths(db.select(
      'SELECT * FROM hadiths WHERE id IN ($marks) ORDER BY id',
      ids,
    ));
  }

  /// Returns the id of the hadith shown at the given list position (0-based)
  /// when the list is ordered by id — backs the «پرش به شماره حدیث» jump.
  ///
  /// Reads the same scan as [_sequenceById] rather than querying: `id` is an
  /// ordinary column here, so `ORDER BY id LIMIT 1 OFFSET n` would sort the
  /// whole table for one row.
  Future<int?> getHadithIdAt(int index) async {
    await init();
    if (index < 0 || index >= _idsBySequence.length) return null;
    return _idsBySequence[index];
  }

  /// All hadiths with every field.
  Future<List<HadeethEncHadith>> getAllHadiths() async {
    await init();
    return _rowsToHadiths(db.select('SELECT * FROM hadiths ORDER BY id'));
  }

  /// Advanced search across every content field of the encyclopedia: Arabic
  /// and Persian titles, Arabic and Persian texts, explanation (شرح),
  /// benefits (نکات حدیث), grade (صحت) and takhrij (منبع). An optional
  /// [category] narrows results to one thematic subcategory.
  Future<List<HadeethEncHadith>> search(
    String query, {
    int limit = 50,
    String? category,
  }) async {
    await init();
    final q = query.trim();

    // Empty query with no topic filter matches nothing by design.
    if (q.isEmpty) {
      if (category == null || category.isEmpty) return const [];
      final rows = db.select(
        'SELECT id, title_ar, title FROM hadiths '
        'WHERE category = ? ORDER BY id LIMIT ?',
        [category, limit],
      );
      return _rowsToHadiths(rows);
    }

    final patterns = _likePatterns(q);
    final textClause = '(${_searchClause(patterns)})';
    final hasCat = category != null && category.isNotEmpty;
    final where =
        hasCat ? 'WHERE category = ? AND $textClause' : 'WHERE $textClause';

    final params = <Object?>[
      if (hasCat) category,
      for (final p in patterns)
        for (var i = 0; i < _searchColumns.length; i++) p,
      limit,
    ];

    final rows = db.select(
      'SELECT id, title_ar, title FROM hadiths $where ORDER BY id LIMIT ?',
      params,
    );
    return _rowsToHadiths(rows);
  }

  /// Every column a text search reads, in the order [_searchClause] binds them.
  static const List<String> _searchColumns = [
    'title_ar',
    'title',
    'text_ar',
    'text',
    'explanation',
    'benefits',
    'grade',
    'takhrij',
  ];

  /// Literal `LIKE` patterns matching [q] — the `%` wrappers included.
  ///
  /// `%` and `_` are escaped (and matched back with `ESCAPE`) so a percent typed
  /// by the user means itself instead of silently widening the search. Digits
  /// are offered in all three scripts: a Persian keyboard types «۱۲», most of
  /// the corpus stores Latin ones and some grades/takhrijs use Arabic-Indic, so
  /// whichever script the user typed, all three still get tried. Text without
  /// digits collapses to a single pattern, keeping normal searches cheap.
  static List<String> _likePatterns(String q) {
    final latin = NumberFormat.normalizeDigits(q
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_'));
    String inScript(int digitZero) => latin.replaceAllMapped(
          RegExp('[0-9]'),
          (m) => String.fromCharCode(digitZero + int.parse(m.group(0)!)),
        );
    final forms = <String>{latin, inScript(0x0660), inScript(0x06F0)};
    return [for (final f in forms) '%$f%'];
  }

  /// OR-chain of `column LIKE ? ESCAPE '\'` terms for every [patterns] entry.
  static String _searchClause(List<String> patterns) => patterns
      .map((p) =>
          _searchColumns.map((c) => "$c LIKE ? ESCAPE '\\'").join(' OR '))
      .join(' OR ');

  List<HadeethEncHadith> _rowsToHadiths(List<Row> rows) => [
        for (final r in rows)
          HadeethEncHadith.fromRow(_withSequence(Map<String, dynamic>.from(r))),
      ];

  /// Attaches the `sequence` column [HadeethEncHadith.fromRow] reads: the
  /// encyclopedia number, not the position in this result set.
  Map<String, dynamic> _withSequence(Map<String, dynamic> row) {
    row['sequence'] = _sequenceById[(row['id'] as num).toInt()];
    return row;
  }

  @override
  void close() {
    super.close();
    _total = 0;
    _sequenceById = const {};
    _idsBySequence = const [];
  }
}

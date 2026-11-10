import 'dart:async';
import 'dart:isolate';
import 'package:meta/meta.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:path/path.dart' as p;
import 'package:tawheeed/features/quran/data/quran_data.dart';
import 'package:tawheeed/features/quran/data/quran_helpers.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

class QuranSearchResult {
  final int surah;
  final int verse;
  final String textNormalized;
  final String textOriginal;
  final int page;
  final String? translation;

  const QuranSearchResult({
    required this.surah,
    required this.verse,
    required this.textNormalized,
    required this.textOriginal,
    required this.page,
    this.translation,
  });
}

/// Local, offline Arabic search over the whole Quran.
///
/// Searching NEVER depends on the SQLite/FTS index being ready: results come
/// from three layers, merged and de-duplicated (FTS prefix matches first,
/// then DB substring (`LIKE`) matches, then an in-memory substring scan):
///  1. FTS5 prefix search  — fast exact/prefix hits (only when FTS5 exists).
///  2. DB substring search — plain `LIKE '%word%'` on a normal table, so it
///                           works even when FTS5 is unavailable or broken.
///  3. In-memory scan      — always available, even with no DB at all.
/// A broken or missing index therefore degrades search to a slow-but-working
/// path instead of showing "no results".
class QuranSearchService {
  static Database? _db;
  static bool _indexing = false;
  static bool _indexReady = false;
  static final _initCompleter = Completer<void>();
  static bool _ftsAvailable = true;

  /// Test seam: when set, the index database is created at this path instead
  /// of the app documents directory.
  @visibleForTesting
  static String? debugDatabasePathOverride;

  /// Resets all cached state (used by tests to simulate cold starts and to
  /// free the on-disk index between scenarios).
  @visibleForTesting
  static void resetForTest() {
    // `dispose()` is deprecated upstream in favour of `close()`.
    _db?.close();
    _db = null;
    _indexing = false;
    _indexReady = false;
    _ftsAvailable = true;
    _normalizedEmlaeyCache = null;
    if (!_initCompleter.isCompleted) _initCompleter.complete();
  }

  /// Precomputed `normalizeArabicSearchText` of every verse's emlaey text.
  /// Building it once (off the UI isolate) turns the in-memory scan into
  /// cheap substring matching instead of re-normalizing all 6236 verses.
  static List<String>? _normalizedEmlaeyCache;

  /// Opens (and lazily populates) the search database. Never throws — a
  /// failure just means the FTS/LIKE layers stay unused and search falls back
  /// to the in-memory scan.
  static Future<Database?> get database async {
    if (_db != null && _indexReady) return _db;
    if (!_indexing) {
      _indexing = true;
      try {
        _db = await _initDatabase();
        _indexReady = true;
        if (!_initCompleter.isCompleted) _initCompleter.complete();
      } catch (e) {
        AppLogger.warning('quran_search_service', 'error: $e');
        _ftsAvailable = false;
        if (!_initCompleter.isCompleted) _initCompleter.completeError(e);
      } finally {
        _indexing = false;
      }
    } else {
      // Concurrent caller — wait for the in-flight init. Any failure here is
      // swallowed; searching must never throw because of the DB.
      try {
        await _initCompleter.future;
      } catch (_) {
        AppLogger.warning('quran_search_service', 'operation failed');
      }
    }
    return _db;
  }

  /// Warm the search index (FTS table fetch + normalized cache) in the
  /// background. Fire-and-forget: searching works immediately even before
  /// this completes (via the in-memory scan), and quietly upgrades to the
  /// DB-backed layers once ready.
  static Future<void> prepare() => ensureInitialized();

  static Future<void> ensureInitialized() async {
    try {
      await database;
    } catch (_) {
      AppLogger.warning('quran_search_service', 'operation failed');
    }
    await _ensureNormalizedCacheBuilt();
  }

  static Future<Database> _initDatabase() async {
    final path = debugDatabasePathOverride ??
        p.join(
            (await getApplicationDocumentsDirectory()).path, 'quran_search.db');
    final db = sqlite3.open(path);

    db.execute('PRAGMA synchronous = OFF');
    db.execute('PRAGMA cache_size = -64000');

    _ensurePlainTable(db);
    _ftsAvailable = _ensureFts5(db);

    final count =
        db.select('SELECT COUNT(*) as c FROM quran_text').first['c'] as int;
    if (count == 0 && quran.isNotEmpty) {
      // Building the index inserts ~6k rows (with per-verse normalization).
      // Spawn a background isolate AND pass the verses by value — a spawned
      // isolate starts fresh, so the `quran` static is empty there.
      final verses = List<Map<String, dynamic>>.from(quran);
      await Isolate.run(() => _populateIndexInIsolate(path, verses));
    }

    // Precompute the normalized fallback cache — on the main isolate so it
    // sees the loaded verses (a spawned isolate cannot).
    _normalizedEmlaeyCache ??= _buildNormalizedCache();

    return db;
  }

  /// Plain `surah/verse/text` table backing the `LIKE` substring search.
  /// Works on every platform regardless of FTS5 support.
  static void _ensurePlainTable(Database db) {
    db.execute('''
      CREATE TABLE IF NOT EXISTS quran_text (
        surah INTEGER NOT NULL,
        verse INTEGER NOT NULL,
        text_original TEXT NOT NULL,
        text_normalized TEXT NOT NULL
      )
    ''');
  }

  /// Optional FTS5 accelerator. Returns whether the virtual table exists.
  static bool _ensureFts5(Database db) {
    try {
      db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS quran_fts USING fts5(
          surah, verse, text_original, text_normalized,
          tokenize='unicode61 remove_diacritics 2'
        )
      ''');
      return true;
    } catch (e) {
      AppLogger.warning(
          'QuranSearchService', 'FTS5 unavailable, using LIKE search only: $e');
      return false;
    }
  }

  static void _populateIndexInIsolate(
      String path, List<Map<String, dynamic>> verses) {
    final db = sqlite3.open(path);
    try {
      db.execute('PRAGMA synchronous = OFF');
      db.execute('PRAGMA cache_size = -64000');
      _ensurePlainTable(db);
      final hasFts = _ensureFts5(db);
      if (verses.isNotEmpty) _populateIndex(db, verses, hasFts: hasFts);
    } catch (e) {
      AppLogger.warning('QuranSearchService',
          'Index population failed (will use memory scan): $e');
    } finally {
      // `dispose()` is deprecated upstream in favour of `close()`.
      db.close();
    }
  }

  /// Adds every verse to the plain table (and to FTS5 when available) if the
  /// tables are empty — earlier app versions left a half-built index behind.
  static void _populateIndex(Database db, List<Map<String, dynamic>> verses,
      {required bool hasFts}) {
    const batchSize = 500;
    int i = 0;
    final List<Map<String, dynamic>> batch = [];

    for (final aya in verses) {
      final surah = aya['sora'] as int;
      final verse = aya['aya_no'] as int;
      final textOriginal = (aya['aya_text_emlaey'] as String?)?.trim() ?? '';
      final textNormalized = normalizeArabicSearchText(textOriginal);

      batch.add({
        'surah': surah,
        'verse': verse,
        'text_original': textOriginal,
        'text_normalized': textNormalized,
      });

      i++;
      if (i % batchSize == 0) {
        _insertBatch(db, batch, hasFts: hasFts);
        batch.clear();
      }
    }
    if (batch.isNotEmpty) _insertBatch(db, batch, hasFts: hasFts);
  }

  static void _insertBatch(Database db, List<Map<String, dynamic>> batch,
      {required bool hasFts}) {
    final stmt = db.prepare(
        'INSERT INTO quran_text(surah, verse, text_original, text_normalized) VALUES (?, ?, ?, ?)');
    for (final row in batch) {
      stmt.execute([
        row['surah'],
        row['verse'],
        row['text_original'],
        row['text_normalized']
      ]);
    }
    stmt.close();

    if (hasFts) {
      final fts = db.prepare(
          'INSERT INTO quran_fts(surah, verse, text_original, text_normalized) VALUES (?, ?, ?, ?)');
      for (final row in batch) {
        fts.execute([
          row['surah'],
          row['verse'],
          row['text_original'],
          row['text_normalized']
        ]);
      }
      fts.close();
    }
  }

  /// Builds/caches the normalized verse list (synchronous — must see the
  /// loaded `quran` static, so it cannot run in a spawned isolate).
  static Future<void> _ensureNormalizedCacheBuilt() async {
    _normalizedEmlaeyCache ??= _buildNormalizedCache();
  }

  static List<String> _normalizedCache() {
    _normalizedEmlaeyCache ??= _buildNormalizedCache();
    return _normalizedEmlaeyCache!;
  }

  static List<String> _buildNormalizedCache() {
    return quran
        .map((a) => normalizeArabicSearchText(
            (a['aya_text_emlaey'] as String?)?.trim() ?? ''))
        .toList();
  }

  static List<String> _searchWords(String normalized) =>
      normalized.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

  /// Search Arabic text in the Quran. Never throws, works with or without the
  /// database: FTS prefix + DB-substring + in-memory scan layers are merged.
  static List<QuranSearchResult> search(String query,
      {int limit = 100, int? surahFilter}) {
    if (query.trim().length < 2) return const [];

    final normalized = normalizeArabicSearchText(query.trim());
    if (normalized.isEmpty) return const [];

    final seen = <(int, int)>{};
    final merged = <QuranSearchResult>[];

    void absorb(List<QuranSearchResult> rs) {
      for (final r in rs) {
        if (merged.length >= limit) return;
        if (seen.add((r.surah, r.verse))) merged.add(r);
      }
    }

    if (_indexReady && _db != null) {
      if (_ftsAvailable) {
        try {
          absorb(
              _ftsSearch(normalized, limit: limit, surahFilter: surahFilter));
        } catch (e) {
          AppLogger.warning('QuranSearchService', 'FTS search failed: $e');
        }
      }
      try {
        absorb(_likeSearch(normalized, limit: limit, surahFilter: surahFilter));
      } catch (e) {
        AppLogger.warning('QuranSearchService', 'LIKE search failed: $e');
      }
    }

    if (merged.length < limit) {
      // In-memory substring scan — guarantees results even with no DB.
      absorb(
          _fallbackSearch(normalized, limit: limit, surahFilter: surahFilter));
    }

    return merged;
  }

  static QuranSearchResult _rowToResult(dynamic row) {
    final surah = row['surah'] as int;
    final verse = row['verse'] as int;
    int page;
    try {
      page = getPageNumber(surah, verse);
    } catch (_) {
      AppLogger.warning('quran_search_service', 'operation failed');
      page = 1;
    }
    return QuranSearchResult(
      surah: surah,
      verse: verse,
      textNormalized: row['text_normalized'] as String,
      textOriginal: row['text_original'] as String,
      page: page,
    );
  }

  /// FTS5 prefix match — each term gets a `*` so partial input matches full
  /// words (e.g. «مزمل» → «المزمل»). Word-boundary-only: mid-word matches
  /// are picked up by [_likeSearch]/[_fallbackSearch].
  static List<QuranSearchResult> _ftsSearch(String normalized,
      {int limit = 100, int? surahFilter}) {
    final db = _db!;
    final searchTerms =
        _searchWords(normalized).map((t) => '$t*').join(' AND ');

    String sql;
    List<dynamic> params;

    if (surahFilter != null) {
      sql = '''
        SELECT surah, verse, text_original, text_normalized
        FROM quran_fts
        WHERE quran_fts MATCH ?
          AND surah = ?
        ORDER BY surah, verse
        LIMIT ?
      ''';
      params = [searchTerms, surahFilter, limit];
    } else {
      sql = '''
        SELECT surah, verse, text_original, text_normalized
        FROM quran_fts
        WHERE quran_fts MATCH ?
        ORDER BY surah, verse
        LIMIT ?
      ''';
      params = [searchTerms, limit];
    }

    return db.select(sql, params).map(_rowToResult).toList();
  }

  /// Plain `LIKE '%word%'` substring search over the normal table — catches
  /// mid-word matches (e.g. «عرش» inside «العرش») without needing FTS5.
  static List<QuranSearchResult> _likeSearch(String normalized,
      {int limit = 100, int? surahFilter}) {
    final db = _db!;
    final words = _searchWords(normalized);
    if (words.isEmpty) return const [];

    // Escape LIKE wildcards typed by the user so they match literally.
    final escaped = words
        .map((w) => w
            .replaceAll(r'\', r'\\')
            .replaceAll('%', r'\%')
            .replaceAll('_', r'\_'))
        .toList();
    final conds =
        List.filled(words.length, "text_normalized LIKE ? ESCAPE '\\'")
            .join(' AND ');

    final sql = surahFilter != null
        ? '''
          SELECT surah, verse, text_original, text_normalized
          FROM quran_text
          WHERE $conds AND surah = ?
          ORDER BY surah, verse
          LIMIT ?
        '''
        : '''
          SELECT surah, verse, text_original, text_normalized
          FROM quran_text
          WHERE $conds
          ORDER BY surah, verse
          LIMIT ?
        ''';

    final params = <dynamic>[...escaped.map((w) => '%$w%')];
    if (surahFilter != null) params.add(surahFilter);
    params.add(limit);

    return db.select(sql, params).map(_rowToResult).toList();
  }

  /// In-memory substring scan over the precomputed normalized cache. The
  /// ultimate guarantee — runs even when there is no database at all.
  static List<QuranSearchResult> _fallbackSearch(String normalized,
      {int limit = 100, int? surahFilter}) {
    if (quran.isEmpty) return const [];

    // Substring matching — each word must appear inside the verse text.
    final words = _searchWords(normalized);
    final cache = _normalizedCache();

    final results = <QuranSearchResult>[];
    for (var i = 0; i < quran.length && results.length < limit; i++) {
      final aya = quran[i];
      if (surahFilter != null && aya['sora'] != surahFilter) continue;
      final emlaey = (aya['aya_text_emlaey'] as String?)?.trim() ?? '';
      final normalizedEmlaey = cache[i];
      if (words.every(normalizedEmlaey.contains)) {
        final surah = aya['sora'] as int;
        final verse = aya['aya_no'] as int;
        int page;
        try {
          page = getPageNumber(surah, verse);
        } catch (_) {
          AppLogger.warning('quran_search_service', 'operation failed');
          page = 1;
        }
        results.add(QuranSearchResult(
          surah: surah,
          verse: verse,
          textNormalized: normalizedEmlaey,
          textOriginal: emlaey,
          page: page,
        ));
      }
    }
    return results;
  }
}

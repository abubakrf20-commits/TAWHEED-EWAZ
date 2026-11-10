import 'dart:async';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/text_highlight.dart';
import 'package:tawheeed/features/hadith/services/hadith_db_service.dart';

// ═══════════════════════════════════════════════════════════════
// Data Models — matching hadith-json-main structure
// ═══════════════════════════════════════════════════════════════

class HadithBookMeta {
  final String key;
  final String titleArabic;
  final String authorArabic;
  final int hadithCount;
  final int chapterCount;
  final String category; // forties, other_books, the_9_books
  final String assetPath;

  const HadithBookMeta({
    required this.key,
    required this.titleArabic,
    required this.authorArabic,
    required this.hadithCount,
    required this.chapterCount,
    required this.category,
    required this.assetPath,
  });
}

class HadithChapter {
  /// Chapter id. Usually an integer, but some books (e.g. Sunan an-Nasa'i,
  /// Shama'il) use fractional sub-chapter ids like `35.2`, so this is a [num].
  final num id;
  final int bookId;
  final String arabic;

  const HadithChapter({
    required this.id,
    required this.bookId,
    required this.arabic,
  });
}

class HadithEntry {
  final int id;
  final int idInBook;

  /// Matches [HadithChapter.id]; may be fractional for sub-chapters.
  final num chapterId;
  final int bookId;
  final String arabic;

  /// Authenticity grade straight from the `grade` column — `sahih` / `hasan` /
  /// `daif` (see [parseHadithGrade]) or free text. Empty when the DB carries
  /// no grading for this hadith, in which case the UI shows no badge.
  final String grade;

  const HadithEntry({
    required this.id,
    required this.idInBook,
    required this.chapterId,
    required this.bookId,
    required this.arabic,
    this.grade = '',
  });
}

/// Full book with chapters and hadiths
class HadithFullBook {
  final int id;
  final HadithBookMeta metadata;
  final List<HadithChapter> chapters;
  final List<HadithEntry> hadiths;

  const HadithFullBook({
    required this.id,
    required this.metadata,
    required this.chapters,
    required this.hadiths,
  });
}

/// Normalize Arabic text for search: remove tashkeel, normalize alif variants.
/// Delegates to the shared [TextHighlight] normalizer so search matching and
/// result highlighting stay perfectly in sync.
String normalizeArabic(String s) => TextHighlight.normalize(s);

// ═══════════════════════════════════════════════════════════════
// Service — reads from hadith.db via HadithDbService
// ═══════════════════════════════════════════════════════════════

class HadithBooksService {
  static final HadithBooksService _instance = HadithBooksService._();
  factory HadithBooksService() => _instance;
  HadithBooksService._();

  /// Maps book key → DB book id (from tools/hadith_to_sqlite.py)
  static const Map<String, int> _keyToDbId = {
    'bukhari': 1,
    'muslim': 2,
    'nasai': 3,
    'abudawud': 4,
    'tirmidhi': 5,
    'ibnmajah': 6,
    'malik': 7,
    'ahmed': 8,
    'darimi': 9,
    'nawawi40': 10,
    'qudsi40': 11,
    'waliullah40': 12,
    'riyad_assalihin': 13,
    'mishkat_almasabih': 14,
    'aladab_almufrad': 15,
    'shamail_muhammadiyah': 16,
    'bulugh_almaram': 17,
  };

  /// Registry of all 17 books with metadata
  static const List<HadithBookMeta> bookRegistry = [
    // ─── Forties (الأربعينات) ──────────────────────────────
    HadithBookMeta(
      key: 'nawawi40',
      titleArabic: 'الأربعون النووية',
      authorArabic: 'الإمام يحيى بن شرف النووي',
      hadithCount: 42,
      chapterCount: 1,
      category: 'forties',
      assetPath: '',
    ),
    HadithBookMeta(
      key: 'qudsi40',
      titleArabic: 'الأحاديث القدسية',
      authorArabic: '',
      hadithCount: 40,
      chapterCount: 1,
      category: 'forties',
      assetPath: '',
    ),
    HadithBookMeta(
      key: 'waliullah40',
      titleArabic: 'الأربعون للشاه ولي الله',
      authorArabic: 'الشاه ولي الله الدهلوي',
      hadithCount: 40,
      chapterCount: 1,
      category: 'forties',
      assetPath: '',
    ),
    // ─── Other Books (كتب أخرى) ────────────────────────────
    HadithBookMeta(
      key: 'aladab_almufrad',
      titleArabic: 'الأدب المفرد',
      authorArabic: 'الإمام محمد بن إسماعيل البخاري',
      hadithCount: 1322,
      chapterCount: 56,
      category: 'other_books',
      assetPath: '',
    ),
    HadithBookMeta(
      key: 'bulugh_almaram',
      titleArabic: 'بلوغ المرام',
      authorArabic: 'ابن حجر العسقلاني',
      hadithCount: 1582,
      chapterCount: 16,
      category: 'other_books',
      assetPath: '',
    ),
    HadithBookMeta(
      key: 'mishkat_almasabih',
      titleArabic: 'مشكاة المصابيح',
      authorArabic: 'الخطيب التبريزي',
      hadithCount: 6294,
      chapterCount: 29,
      category: 'other_books',
      assetPath: '',
    ),
    HadithBookMeta(
      key: 'riyad_assalihin',
      titleArabic: 'رياض الصالحين',
      authorArabic: 'الإمام يحيى بن شرف النووي',
      hadithCount: 1896,
      chapterCount: 20,
      category: 'other_books',
      assetPath: '',
    ),
    HadithBookMeta(
      key: 'shamail_muhammadiyah',
      titleArabic: 'الشمائل المحمدية',
      authorArabic: 'الإمام الترمذي',
      hadithCount: 402,
      chapterCount: 57,
      category: 'other_books',
      assetPath: '',
    ),
    // ─── The 9 Books (الكتب التسعة) ───────────────────────
    HadithBookMeta(
      key: 'bukhari',
      titleArabic: 'صحيح البخاري',
      authorArabic: 'الإمام محمد بن إسماعيل البخاري',
      hadithCount: 7008,
      chapterCount: 97,
      category: 'the_9_books',
      assetPath: '',
    ),
    HadithBookMeta(
      key: 'muslim',
      titleArabic: 'صحيح مسلم',
      authorArabic: 'الإمام مسلم بن الحجاج',
      hadithCount: 5362,
      chapterCount: 56,
      category: 'the_9_books',
      assetPath: '',
    ),
    HadithBookMeta(
      key: 'tirmidhi',
      titleArabic: 'سنن الترمذي',
      authorArabic: 'الإمام الترمذي',
      hadithCount: 3956,
      chapterCount: 49,
      category: 'the_9_books',
      assetPath: '',
    ),
    HadithBookMeta(
      key: 'abudawud',
      titleArabic: 'سنن أبي داود',
      authorArabic: 'الإمام أبو داود',
      hadithCount: 5274,
      chapterCount: 43,
      category: 'the_9_books',
      assetPath: '',
    ),
    HadithBookMeta(
      key: 'nasai',
      titleArabic: 'سنن النسائي',
      authorArabic: 'الإمام النسائي',
      hadithCount: 5768,
      chapterCount: 52,
      category: 'the_9_books',
      assetPath: '',
    ),
    HadithBookMeta(
      key: 'ibnmajah',
      titleArabic: 'سنن ابن ماجه',
      authorArabic: 'الإمام ابن ماجه',
      hadithCount: 4341,
      chapterCount: 37,
      category: 'the_9_books',
      assetPath: '',
    ),
    HadithBookMeta(
      key: 'malik',
      titleArabic: 'الموطأ',
      authorArabic: 'الإمام مالك بن أنس',
      hadithCount: 1594,
      chapterCount: 61,
      category: 'the_9_books',
      assetPath: '',
    ),
    HadithBookMeta(
      key: 'ahmed',
      titleArabic: 'مسند أحمد',
      authorArabic: 'الإمام أحمد بن حنبل',
      hadithCount: 4305,
      chapterCount: 1,
      category: 'the_9_books',
      assetPath: '',
    ),
    HadithBookMeta(
      key: 'darimi',
      titleArabic: 'سنن الدارمي',
      authorArabic: 'الإمام الدارمي',
      hadithCount: 3367,
      chapterCount: 1,
      category: 'the_9_books',
      assetPath: '',
    ),
  ];

  /// Get book metadata by key
  static HadithBookMeta? getMeta(String key) {
    for (final m in bookRegistry) {
      if (m.key == key) return m;
    }
    return null;
  }

  /// DB book id for a registry [key], or null when the key is unknown.
  static int? dbIdFor(String key) => _keyToDbId[key];

  /// Registry metadata for a DB book id (the value a `hadiths` row carries in
  /// `book_id`), or null when the id is unknown.
  static HadithBookMeta? metaForDbId(int bookId) {
    for (final entry in _keyToDbId.entries) {
      if (entry.value == bookId) return getMeta(entry.key);
    }
    return null;
  }

  /// Get all book metadata, optionally filtered by category
  static List<HadithBookMeta> getAllMeta({String? category}) {
    if (category == null) return bookRegistry;
    return bookRegistry.where((m) => m.category == category).toList();
  }

  /// Get categories with labels (order: The 9 Books → Other Books → Forties)
  static List<({String key, String labelAr})> get categories => [
        (key: 'the_9_books', labelAr: 'الكتب التسعة'),
        (key: 'other_books', labelAr: 'كتب أخرى'),
        (key: 'forties', labelAr: 'الأربعينات'),
      ];

  /// Loads a book's metadata + chapter list from the DB. Hadiths are NOT
  /// eagerly loaded (Bukhari alone has ~7000) — callers use
  /// [loadChapterHadiths] / [chapterHadithCounts] on demand.
  Future<HadithFullBook> loadBook(String key) async {
    final meta = getMeta(key);
    if (meta == null) throw ArgumentError('Unknown book key: $key');
    final dbId = _keyToDbId[key];
    if (dbId == null) throw ArgumentError('Unknown book key: $key');

    final db = HadithDbService();
    await db.init();

    final dbChapters = await db.getChaptersForBook(dbId);

    final chapters = dbChapters.map((ch) {
      final ci = ch['chapter_index'];
      return HadithChapter(
        id: ci is num ? ci : (ci as int).toDouble(),
        bookId: dbId,
        arabic: (ch['name_arabic'] ?? '').toString(),
      );
    }).toList();

    AppLogger.warning('hadith_books_service',
        "'HadithBooksService: loaded $key from DB — ${chapters.length} chapters'");
    return HadithFullBook(
      id: dbId,
      metadata: meta,
      chapters: chapters,
      hadiths: const [],
    );
  }

  /// Hadiths of one chapter (by the displayed `chapter_index`), loaded on
  /// demand instead of pulling the whole book into memory.
  Future<List<HadithEntry>> loadChapterHadiths(
      String key, num chapterIndex) async {
    final dbId = _keyToDbId[key];
    if (dbId == null) return const [];
    final db = HadithDbService();
    await db.init();
    final rows = await db.getHadithsForChapterIndex(dbId, chapterIndex);
    return rows
        .map((h) => HadithEntry(
              id: h['id'] as int,
              idInBook: (h['hadith_number'] as int?) ?? 0,
              chapterId: chapterIndex,
              bookId: dbId,
              arabic: (h['arabic'] ?? '').toString(),
              grade: (h['grade'] ?? '').toString(),
            ))
        .toList();
  }

  /// One-query chapter counts for a book's chapter list.
  Future<Map<num, int>> chapterHadithCounts(String key) async {
    final dbId = _keyToDbId[key];
    if (dbId == null) return const {};
    final db = HadithDbService();
    await db.init();
    return db.getHadithCountsPerChapter(dbId);
  }

  /// Paginated hadiths of a book (for the «همه احادیث» list).
  Future<List<HadithEntry>> loadBookHadiths(String key,
      {int limit = 30, int offset = 0}) async {
    final dbId = _keyToDbId[key];
    if (dbId == null) return const [];
    final db = HadithDbService();
    await db.init();
    final rows = await db.getHadithsForBook(dbId, limit: limit, offset: offset);
    return rows
        .map((h) => HadithEntry(
              id: h['id'] as int,
              idInBook: (h['hadith_number'] as int?) ?? 0,
              chapterId: (h['chapter_id'] as int?) ?? 0,
              bookId: dbId,
              arabic: (h['arabic'] ?? '').toString(),
              grade: (h['grade'] ?? '').toString(),
            ))
        .toList();
  }

  /// Search across all books
  Future<List<({HadithBookMeta book, HadithEntry hadith})>> search(
    String query, {
    int limit = 50,
  }) async {
    final results = <({HadithBookMeta book, HadithEntry hadith})>[];
    final q = query.trim();
    if (q.isEmpty) return results;

    final db = HadithDbService();
    await db.init();
    final dbResults =
        await db.searchHadiths(qArabic: normalizeArabic(q), limit: limit);

    for (final row in dbResults) {
      final bookId = row['book_id'] as int;
      String? key;
      for (final entry in _keyToDbId.entries) {
        if (entry.value == bookId) {
          key = entry.key;
          break;
        }
      }
      if (key == null) continue;
      final meta = getMeta(key);
      if (meta == null) continue;
      results.add((
        book: meta,
        hadith: HadithEntry(
          id: row['id'] as int,
          idInBook: (row['hadith_number'] as int?) ?? 0,
          chapterId: (row['chapter_id'] as int?) ?? 0,
          bookId: bookId,
          arabic: (row['arabic'] ?? '').toString(),
          grade: (row['grade'] ?? '').toString(),
        ),
      ));
    }
    return results;
  }

  /// Search within a single book
  Future<List<HadithEntry>> searchInBook(String key, String query,
      {int limit = 50}) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final dbId = _keyToDbId[key];
    if (dbId == null) return [];

    final db = HadithDbService();
    await db.init();
    final dbResults = await db.searchHadiths(
      qArabic: normalizeArabic(q),
      limit: limit,
      bookId: dbId,
    );

    return dbResults
        .map((row) => HadithEntry(
              id: row['id'] as int,
              idInBook: (row['hadith_number'] as int?) ?? 0,
              chapterId: (row['chapter_id'] as int?) ?? 0,
              bookId: dbId,
              arabic: (row['arabic'] ?? '').toString(),
              grade: (row['grade'] ?? '').toString(),
            ))
        .toList();
  }

  /// Get a random hadith from any book
  Future<({HadithBookMeta book, HadithEntry hadith})?> getRandomHadith() async {
    final db = HadithDbService();
    await db.init();
    final dbResult = await db.getRandomHadith();
    if (dbResult == null) return null;

    final bookId = dbResult['book_id'] as int;

    // Find the book key for this DB id
    String? key;
    for (final entry in _keyToDbId.entries) {
      if (entry.value == bookId) {
        key = entry.key;
        break;
      }
    }
    if (key == null) return null;

    final meta = getMeta(key);
    if (meta == null) return null;

    return (
      book: meta,
      hadith: HadithEntry(
        id: dbResult['id'] as int,
        idInBook: (dbResult['hadith_number'] as int?) ?? 0,
        chapterId: (dbResult['chapter_id'] as int?) ?? 0,
        bookId: bookId,
        arabic: (dbResult['arabic'] ?? '').toString(),
        grade: (dbResult['grade'] ?? '').toString(),
      ),
    );
  }

  /// No-op: DB queries are fast enough without caching
  void clearCache() {}
}

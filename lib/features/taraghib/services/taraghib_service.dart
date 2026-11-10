import 'package:tawheeed/features/hadith/services/hadith_db_service.dart';
import 'package:tawheeed/shared/services/content_download_service.dart'
    show DownloadProgress;
import 'package:tawheeed/shared/utils/app_logger.dart';

/// صحیح الترغیب و الترهیب — بخش مستقل مطالعه.
///
/// محتوا در پایگاه‌دادهٔ اختصاصی و جدای کتب حدیث نگهداری می‌شود:
/// `taraghib/taraghib.db.gz` نسخهٔ کامل ۲۹ کتابی است — ۴۲۸ باب و ۳۷۷۵ حدیثِ
/// شماره‌دار (شماره‌ها همان شمارهٔ چاپیِ پیوستهٔ کتاب‌اند، ۱ تا ۳۷۷۵)، به‌همراه
/// مقدمه و خاتمه که در جدول‌های جداگانه ذخیره شده‌اند و حدیث شمرده نمی‌شوند؛
/// هر پانوشت هم با همان متن و بابی ذخیره شده که در کتاب زیرش آمده است.
class TaraghibService {
  final HadithDbService _db = HadithDbService.taraghib;

  List<Map<String, dynamic>>? _books;
  List<Map<String, dynamic>>? _allChapters;
  Map<int, int>? _hadithCounts;
  Map<int, int>? _chapterCounts;
  Map<int, ({int bookId, num chapterIndex})>? _chapterLocations;
  List<({int bookId, num chapterIndex, int number})>? _numberedIndex;

  // ─── Availability ─────────────────────────────────────────────

  /// Whether the standalone taraghib database is already on disk.
  Future<bool> isAvailable() => _db.isDownloadedFile();

  /// True when the copy on disk predates the current content revision (the
  /// 29-book edition). The download service's `ensureDownloaded` returns early
  /// for any valid file on disk, so without this check an existing install
  /// would keep reading its old 440-chapter copy forever.
  Future<bool> needsUpdate() => _db.needsUpdate();

  /// Opens the taraghib database (throws when not downloaded yet).
  Future<void> ensureReady() => _db.init();

  /// Downloads (or replaces) `taraghib/taraghib.db.gz`.
  Future<void> download({DownloadProgress? onProgress}) =>
      _db.downloadFile(onProgress: onProgress);

  /// Removes the downloaded database and drops every cache built from it, so
  /// a later download can never serve rows of the deleted copy.
  Future<void> deleteDownloaded() async {
    _books = null;
    _allChapters = null;
    _hadithCounts = null;
    _chapterCounts = null;
    _chapterLocations = null;
    _numberedIndex = null;
    await _db.deleteDownloadedFile();
  }

  // ─── Books and chapters ──────────────────────────────────────

  /// The 29 books in print order, including the unnumbered divider book
  /// «كتاب صفة الجنة والنار» that still carries real hadiths.
  Future<List<Map<String, dynamic>>> books() async {
    final cached = _books;
    if (cached != null) return cached;
    return _books = await _db.getAllBooks();
  }

  Future<Map<String, dynamic>?> book(int bookId) => _db.getBook(bookId);

  Future<List<Map<String, dynamic>>> chaptersForBook(int bookId) =>
      _db.getChaptersForBook(bookId);

  /// Hadith totals keyed by `books.id` — one query for the book list.
  Future<Map<int, int>> hadithCountsPerBook() async {
    final cached = _hadithCounts;
    if (cached != null) return cached;
    return _hadithCounts = await _db.getHadithCountsPerBook();
  }

  /// Chapter totals keyed by `books.id` — one query for the book list.
  Future<Map<int, int>> chapterCountsPerBook() async {
    final cached = _chapterCounts;
    if (cached != null) return cached;
    return _chapterCounts = await _db.getChapterCountsPerBook();
  }

  /// Exact per-chapter hadith count of one book.
  Future<Map<num, int>> hadithCountsPerChapter(int bookId) =>
      _db.getHadithCountsPerChapter(bookId);

  Future<List<Map<String, dynamic>>> entriesOfChapter(
          int bookId, num chapterIndex) =>
      _db.getHadithsForChapterIndex(bookId, chapterIndex);

  /// The chapter row itself — needed for its publisher note, which the print
  /// edition places on the chapters that carry no hadith at all.
  Future<Map<String, dynamic>?> chapterOf(int bookId, num chapterIndex) async {
    final rows = await chaptersForBook(bookId);
    for (final row in rows) {
      if ((row['chapter_index'] as num).toDouble() ==
          chapterIndex.toDouble()) {
        return row;
      }
    }
    return null;
  }

  /// Every chapter of every book, ordered by book and then by the per-book
  /// chapter index — the one call the search layer needs to label a hit.
  Future<List<Map<String, dynamic>>> allChapters() async {
    final cached = _allChapters;
    if (cached != null) return cached;
    return _allChapters = await _db.getAllChapters();
  }

  /// `chapters.id` → its book and per-book chapter index. Built once, so a
  /// search hit (which carries only `chapter_id`/`book_id`) can be labelled
  /// with the باب it belongs to.
  Future<Map<int, ({int bookId, num chapterIndex})>> chapterLocations() async {
    final cached = _chapterLocations;
    if (cached != null) return cached;
    final rows = await allChapters();
    return _chapterLocations = {
      for (final r in rows)
        (r['id'] as int): (
          bookId: (r['book_id'] as num).toInt(),
          chapterIndex: r['chapter_index'] as num,
        ),
    };
  }

  // ─── Matter sections (مقدمه / خاتمه) ────────────────────────

  /// مقدمه and خاتمه sections in reading order. A copy from before revision 2
  /// has no matter tables at all, so a failure reads as «this database has no
  /// matter sections» rather than an error screen.
  Future<List<Map<String, dynamic>>> matterSections() =>
      _guardReading('matter sections', _db.getMatterSections, const []);

  Future<List<Map<String, dynamic>>> matterParagraphs(int sectionId) =>
      _guardReading('matter sections',
          () => _db.getMatterParagraphs(sectionId), const []);

  /// Paragraph totals keyed by `matter_sections.id` — one query for the list.
  Future<Map<int, int>> matterParagraphCounts() => _guardReading(
      'matter sections', _db.getMatterParagraphCounts, const <int, int>{});

  // ─── Footnotes and publisher notices ────────────────────────
  //
  // A copy that predates revision 3 has no footnotes/preambles tables, so every
  // reader degrades to "nothing to show" instead of blocking the screen.

  /// Footnotes of one chapter, ordered; group the hadith ones by `hadith_id`
  /// and print each group under its own hadith.
  Future<List<Map<String, dynamic>>> footnotesOfChapter(int chapterId) =>
      _guardReading('footnotes',
          () => _db.getFootnotesForChapter(chapterId), const []);

  /// Footnotes that belong to the book itself (its heading and its preamble).
  Future<List<Map<String, dynamic>>> footnotesOfBook(int bookId) =>
      _guardReading('footnotes',
          () => _db.getFootnotesForBook(bookId), const []);

  /// Footnotes of one مقدمه/خاتمه section; each row carries `source_para`.
  Future<List<Map<String, dynamic>>> footnotesOfSection(int sectionId) =>
      _guardReading('footnotes',
          () => _db.getFootnotesForSection(sectionId), const []);

  /// Notices the publisher prints between a chapter heading and its first entry.
  Future<List<Map<String, dynamic>>> preamblesOfChapter(int chapterId) =>
      _guardReading('preambles',
          () => _db.getChapterPreambles(chapterId), const []);

  /// Notices printed between a book heading and its first chapter.
  Future<List<Map<String, dynamic>>> preamblesOfBook(int bookId) =>
      _guardReading('preambles',
          () => _db.getBookPreambles(bookId), const []);

  Future<T> _guardReading<T>(
      String what, Future<T> Function() read, T fallback) async {
    try {
      return await read();
    } catch (e) {
      AppLogger.warning('taraghib_service', '$what unavailable: $e');
      return fallback;
    }
  }

  // ─── Numbered hadiths ────────────────────────────────────────

  Future<List<({int bookId, num chapterIndex, int number})>>
      _numberedEntries() async {
    final cached = _numberedIndex;
    if (cached != null) return cached;
    final rows = await _db.getNumberedEntries();
    return _numberedIndex = [
      for (final row in rows)
        (
          bookId: (row['book'] as num).toInt(),
          chapterIndex: row['idx'] as num,
          number: (row['no'] as num).toInt(),
        ),
    ];
  }

  /// Highest hadith number of this edition, derived from the data (3775).
  Future<int> maxHadithNumber() async {
    var max = 0;
    for (final entry in await _numberedEntries()) {
      if (entry.number > max) max = entry.number;
    }
    return max;
  }

  /// Finds the book and chapter carrying printed number [number] — the global
  /// sequential number this edition prints in its «حدیث X» badges (1..3775).
  /// Returns null for a number the edition does not carry.
  Future<({int bookId, num chapterIndex, int number})?> locateHadithNumber(
      int number) async {
    if (number <= 0) return null;
    for (final entry in await _numberedEntries()) {
      if (entry.number == number) return entry;
    }
    return null;
  }

  /// Total numbered hadiths of the whole edition.
  Future<int> totalHadiths() => _db.getHadithCount();

  /// Rows one full-text read returns. The screen calls a full page «نتیجهٔ
  /// نخست» instead of a total, so both numbers must stay one constant.
  static const int searchLimit = 30;

  /// Full-text search (normalized Arabic matching).
  Future<List<Map<String, dynamic>>> search(String query,
          {int limit = searchLimit}) =>
      _db.searchArabic(query, limit: limit);
}

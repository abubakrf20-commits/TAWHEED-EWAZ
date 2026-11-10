import 'package:tawheeed/features/hadith/services/hadith_db_service.dart';
import 'package:tawheeed/shared/services/content_download_service.dart'
    show DownloadProgress;
import 'package:tawheeed/shared/utils/app_logger.dart';

/// ریاض الصالحین — بخش مستقل مطالعه.
///
/// محتوا در پایگاه‌دادهٔ اختصاصی و جدای کتب حدیث نگهداری می‌شود:
/// `riyad/ryadalsalihin.db.gz` — شرح کامل علامه عثیمین در شش جلد، یک‌جا:
/// ۳۷۲ باب (شمارهٔ چاپی خودِ کتاب) و ۱٬۸۹۷ حدیثِ شماره‌دار، با پانوشت‌هایی که
/// هرکدام زیر همان سطرِ خودش چاپ می‌شود، آیه‌هایی که هر باب با آن‌ها آغاز
/// می‌شود، و مقدمه‌های جلد نخست در بخش‌های جدا.
///
/// فهرستِ برنامه یک سطح دارد: هر باب یک [chapters] ردیف است و ستون `part`
/// نامِ «کتاب»ی را نگه می‌دارد که باب زیرِ آن چاپ شده، تا صفحهٔ فهرست بالای هر
/// گروه سرفصل بکشد. شمارهٔ حدیث‌ها پیوستهٔ همین نسخه است (1 تا 1897)، نه
/// شمارهٔ چاپیِ پراکنده‌ی ترجمه (که در هر باب از نو شروع می‌شود).
///
/// این سرویس لایهٔ نازک روی همان موتور [HadithDbService] است ولی فایل
/// جداگانه‌ای دارد — همان روش معالم السنه و صحیح الترغیب.
class RiyadService {
  /// `books.id` این نسخه — تک‌ردیف است (کل اثر یک کتاب در کتابخانه است).
  static const int bookId = 1;

  final HadithDbService _db = HadithDbService.riyad;

  List<({num chapterIndex, int number})>? _numberedIndex;

  // ─── Availability ─────────────────────────────────────────────

  /// Whether the standalone riyad database is already on disk.
  Future<bool> isAvailable() => _db.isDownloadedFile();

  /// True when the copy on disk predates the current content revision (the
  /// six-volume build). `ensureDownloaded` returns early for any valid file on
  /// disk, so without this check an install would keep reading its old
  /// 366-باب copy forever.
  Future<bool> needsUpdate() => _db.needsUpdate();

  /// Opens the riyad database (throws when not downloaded yet).
  Future<void> ensureReady() => _db.init();

  /// Downloads `riyad/ryadalsalihin.db.gz` if missing.
  Future<void> download({DownloadProgress? onProgress}) =>
      _db.downloadFile(onProgress: onProgress);

  /// Removes the downloaded database (closes the handle first) and drops every
  /// cache built from it, so a later download cannot serve rows of the copy
  /// that was just deleted.
  Future<void> deleteDownloaded() async {
    _numberedIndex = null;
    await _db.deleteDownloadedFile();
  }

  // ─── Chapters (کتاب › باب) ────────────────────────────────────

  Future<List<Map<String, dynamic>>> chapters() =>
      _db.getChaptersForBook(bookId);

  /// The chapter row itself — the reader needs its `id` for its notes and its
  /// `part` for the list's group header.
  Future<Map<String, dynamic>?> chapterOf(num chapterIndex) async {
    for (final row in await chapters()) {
      if ((row['chapter_index'] as num).toDouble() ==
          chapterIndex.toDouble()) {
        return row;
      }
    }
    return null;
  }

  /// Hadith totals keyed by `chapter_index` — one query for the whole list.
  Future<Map<num, int>> hadithCountsPerChapter() async {
    final counts = <num, int>{};
    for (final entry in await _numberedEntries()) {
      counts[entry.chapterIndex] = (counts[entry.chapterIndex] ?? 0) + 1;
    }
    return counts;
  }

  /// Every row of one باب in hadith-number order.
  Future<List<Map<String, dynamic>>> entriesOfChapter(num chapterIndex) =>
      _db.getHadithsForChapterIndex(bookId, chapterIndex);

  // ─── Footnotes and notices ──────────────────────────────────
  //
  // A copy that predates revision 2 has no footnotes/preambles tables, so the
  // reader degrades to «nothing to show» instead of an error screen.

  /// Footnotes of one باب, ordered; group the hadith ones by `hadith_id` and
  /// print each group under its own text. Rows anchored to the heading carry
  /// neither a hadith nor a notice id.
  Future<List<Map<String, dynamic>>> footnotesOfChapter(int chapterId) =>
      _guardReading('footnotes',
          () => _db.getFootnotesForChapter(chapterId), const []);

  /// The verses and the translator's lines printed between the باب heading and
  /// its first narration.
  Future<List<Map<String, dynamic>>> preamblesOfChapter(int chapterId) =>
      _guardReading('preambles',
          () => _db.getChapterPreambles(chapterId), const []);

  // ─── Matter sections (مقدمه‌های جلد نخست) ───────────────────

  Future<List<Map<String, dynamic>>> matterSections() =>
      _guardReading('matter sections', _db.getMatterSections, const []);

  Future<List<Map<String, dynamic>>> matterParagraphs(int sectionId) =>
      _guardReading('matter sections',
          () => _db.getMatterParagraphs(sectionId), const []);

  Future<Map<int, int>> matterParagraphCounts() => _guardReading(
      'matter sections', _db.getMatterParagraphCounts, const <int, int>{});

  Future<List<Map<String, dynamic>>> footnotesOfSection(int sectionId) =>
      _guardReading('footnotes',
          () => _db.getFootnotesForSection(sectionId), const []);

  Future<T> _guardReading<T>(
      String what, Future<T> Function() read, T fallback) async {
    try {
      return await read();
    } catch (e) {
      AppLogger.warning('riyad_service', '$what unavailable: $e');
      return fallback;
    }
  }

  // ─── Numbered hadiths ────────────────────────────────────────

  Future<List<({num chapterIndex, int number})>> _numberedEntries() async {
    final cached = _numberedIndex;
    if (cached != null) return cached;
    final rows = await _db.getChapterEntryNumbers(bookId);
    return _numberedIndex = [
      for (final row in rows)
        if (((row['no'] as num?)?.toInt() ?? 0) > 0)
          (
            chapterIndex: row['idx'] as num,
            number: (row['no'] as num).toInt(),
          ),
    ];
  }

  /// Highest hadith number of this edition, derived from the data (1897).
  Future<int> maxHadithNumber() async {
    var max = 0;
    for (final entry in await _numberedEntries()) {
      if (entry.number > max) max = entry.number;
    }
    return max;
  }

  /// Finds the chapter and entry number carrying [number] — the continuous
  /// number this edition's badges print (1..N). Returns null for a number the
  /// edition does not carry.
  Future<(num, int)?> locateHadithNumber(int number) async {
    if (number <= 0) return null;
    for (final entry in await _numberedEntries()) {
      if (entry.number == number) return (entry.chapterIndex, entry.number);
    }
    return null;
  }

  /// Narrations this edition carries (1,897 on the shipped database).
  Future<int> totalEntries() async => (await _numberedEntries()).length;

  /// Rows one search asks for. The screen labels the list from this number, so
  /// it cannot claim more hits than it actually shows.
  static const int searchLimit = 30;

  /// Full-text search (normalized Arabic matching).
  Future<List<Map<String, dynamic>>> search(String query,
          {int limit = searchLimit}) =>
      _db.searchArabic(query, limit: limit);
}

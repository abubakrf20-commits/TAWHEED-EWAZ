import 'package:tawheeed/features/hadith/services/hadith_db_service.dart';
import 'package:tawheeed/shared/services/content_download_service.dart'
    show DownloadProgress;
import 'package:tawheeed/shared/utils/app_logger.dart';

/// معالم السنه النبویه — بخش مستقل مطالعه.
///
/// خلاصه‌ای از ۱۴ کتاب اصلی حدیث (جمع وترتیب: شیخ صالح أحمد الشامي ·
/// ترجمه وتعلیق: شاکر الذهبي). محتوا در پایگاه‌دادهٔ اختصاصی و جدا از کتب
/// حدیث نگهداری می‌شود: دانلود `maalim/maalim.db.gz` — ۱٬۹۲۹ بابِ فهرستِ خودِ
/// کتاب (۲۷ بابش بدون حدیثِ تازه‌اند و شرحِ باب پیشین را دارند) و ۳٬۸۲۳
/// حدیثِ شماره‌دار، با پانوشت‌هایی که هرکدام زیر سطرِ خودش چاپ می‌شود.
///
/// ساختار فایل چهارلایه است (مقصد › کتاب › فصل › باب) ولی فهرستِ برنامه یک
/// سطح دارد: هر باب یک [chapters] ردیف است و ستون غیرمعمول `part` زنجیرهٔ
/// کاملِ مقصد/کتاب/فصلِ فعال را نگه می‌دارد تا صفحهٔ فهرست بالای هر گروه
/// سرفصل بکشد.
/// شمارهٔ حدیث‌ها همان شمارهٔ نسخهٔ چاپی است (1 تا 3921)، نه شمارندهٔ ردیف:
/// «حدیث 1068» همان روایتی است که صفحهٔ کتاب زیر شمارهٔ 1068 چاپ کرده. نسخهٔ
/// چاپی ۲۴۴ شماره را هرگز نچاپ کرده و ۱۴۴ شماره را دو بار چاپ کرده؛ همان
/// دوگانگی و همان شکاف‌ها اینجا هم هست تا شماره‌ها جابه‌جا نشوند — پرش به
/// شماره‌ای که کتاب ندارد پیام «در این نسخه نیست» می‌دهد.
///
/// نسخه یک `books` ردیف دارد: ۴۹ «کتاب»ِ خودِ اثر (و مقصد و فصلش) در `part`
/// می‌آیند، زیرا فهرستِ این بخش یک سطح دارد و هر بار که `part` عوض شود
/// سرفصلِ گروه کشیده می‌شود. نوشتنشان به‌صورت ردیف‌های `books` باعث می‌شد
/// بخش فقط یکی از ۴۹ کتاب را نشان دهد.
///
/// این سرویس لایهٔ نازک روی همان موتور [HadithDbService] است ولی فایل
/// جداگانه‌ای دارد — همان روش ریاض الصالحین و صحیح الترغیب.
class MaalimService {
  /// `books.id` این نسخه — تک‌ردیف است (کل اثر یک کتاب در کتابخانه است).
  static const int bookId = 1;

  final HadithDbService _db = HadithDbService.maalim;

  /// `(chapterIndex, number)` of every numbered narration, ordered by
  /// chapter then number. Built once per service instance from
  /// [HadithDbService.getChapterEntryNumbers] so the jump dialog's upper
  /// bound and the lookup itself always agree with the data on disk.
  List<({num chapterIndex, int number})>? _numberedIndex;

  // ─── Availability ─────────────────────────────────────────────

  /// Whether the standalone maalim database is already on disk.
  Future<bool> isAvailable() => _db.isDownloadedFile();

  /// Whether the copy on disk predates the hosted revision. The
  /// republished maalim.db (the four-volume edition, every باب carrying
  /// its مقصد › کتاب › فصل chain) must replace the stale one-volume
  /// parse — see `contentRevision` on [HadithDbService.maalim].
  Future<bool> needsUpdate() => _db.needsUpdate();

  /// Opens the maalim database (throws when not downloaded yet).
  Future<void> ensureReady() => _db.init();

  /// Downloads `maalim/maalim.db.gz` if missing.
  Future<void> download({DownloadProgress? onProgress}) =>
      _db.downloadFile(onProgress: onProgress);

  // ─── Queries ──────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> chapters() =>
      _db.getChaptersForBook(bookId);

  /// Whether [chapterIndex] carries a printed bab number.
  ///
  /// این فایل دو بخشِ فصل دارد که کتاب بدون خطِ «باب» و مستقیم زیرِ عنوانِ
  /// فصل شروعشان کرده (ستون `is_bab` صفر) — آن‌ها فصل‌اند نه باب، و شمارهٔ
  /// بابِشان باید در رابط مثل همان‌ها دیده شود. پایگاه‌دادهٔ کهنه‌ای که این
  /// ستون را ندارد همه را باب پاسخ می‌دهد (رفتار قبلی).
  Future<bool> isBab(num chapterIndex) async {
    for (final row in await chapters()) {
      if (row['chapter_index'] == chapterIndex) {
        return ((row['is_bab'] as num?)?.toInt() ?? 1) != 0;
      }
    }
    return true;
  }

  /// Per-bab counts keyed by `chapter_index`, counting **narrations** only.
  ///
  /// The raw SQL behind [HadithDbService.getHadithCountsPerChapter] counts
  /// every row, so it would report 1 for the one bab that carries the book's
  /// unnumbered cross-reference row («ببین حدیث (1068) وپس از آن را.») even
  /// though that bab holds no narration — a pointer is not a حدیث.
  Future<Map<num, int>> countsPerChapter() => hadithCountsPerChapter();

  /// Exact per-chapter count of real narrations (the single unnumbered
  /// cross-reference row is not counted).
  Future<Map<num, int>> hadithCountsPerChapter() async {
    final counts = <num, int>{};
    for (final entry in await _numberedEntries()) {
      counts[entry.chapterIndex] = (counts[entry.chapterIndex] ?? 0) + 1;
    }
    return counts;
  }

  /// Every row of one bab: the narrations in hadith-number order first, the
  /// unnumbered cross-reference note last.
  ///
  /// [HadithDbService.getHadithsForChapterIndex] orders by `hadith_number`,
  /// which puts the note (number 0) *ahead* of «حدیث ۱» — a translator's
  /// pointer must not open the list, so it is moved to the end here, inside
  /// this book only: الترغیب leans on the same engine with its unnumbered
  /// rows as real bab headings, which belong first.
  Future<List<Map<String, dynamic>>> entriesOfChapter(num chapterIndex) async {
    final rows =
        await _db.getHadithsForChapterIndex(bookId, chapterIndex);
    final narrations = <Map<String, dynamic>>[];
    final notes = <Map<String, dynamic>>[];
    for (final row in rows) {
      final no = (row['hadith_number'] as num?)?.toInt() ?? 0;
      (no > 0 ? narrations : notes).add(row);
    }
    return [...narrations, ...notes];
  }

  /// The chapter row itself — the reader needs its `id` to ask for its notes.
  Future<Map<String, dynamic>?> chapterOf(num chapterIndex) async {
    for (final row in await chapters()) {
      if ((row['chapter_index'] as num).toDouble() ==
          chapterIndex.toDouble()) {
        return row;
      }
    }
    return null;
  }

  // ─── Footnotes and notices ──────────────────────────────────
  //
  // The edition carries 3,831 پانوشت, 3,741 of them anchored to the line they
  // annotate. A copy from before those tables answers with nothing instead of
  // failing the read.

  /// Every پانوشت of one باب: on its hadiths, on its opening notices, and on
  /// its own heading.
  Future<List<Map<String, dynamic>>> footnotesOfChapter(int chapterId) =>
      _guardRead(
          'footnotes', () => _db.getFootnotesForChapter(chapterId));

  /// The verses and translator's lines printed between the باب heading and its
  /// first narration.
  Future<List<Map<String, dynamic>>> preamblesOfChapter(int chapterId) =>
      _guardRead(
          'preambles', () => _db.getChapterPreambles(chapterId));

  // ─── مقدمه and خاتمه ────────────────────────────────────────
  //
  // These are not hadiths, so they never appear in the باب list: the edition
  // prints three openings (مترجم، مؤلف، درآمد) and one خاتمه at the end of the
  // fourth volume. They live in `matter_sections` / `matter_paragraphs` and are
  // read through their own row, like ریاض and الترغیب.

  Future<List<Map<String, dynamic>>> matterSections() =>
      _guardRead('matter sections', _db.getMatterSections);

  Future<List<Map<String, dynamic>>> matterParagraphs(int sectionId) =>
      _guardRead('matter paragraphs',
          () => _db.getMatterParagraphs(sectionId));

  Future<Map<int, int>> matterParagraphCounts() async {
    try {
      return await _db.getMatterParagraphCounts();
    } catch (e) {
      AppLogger.warning('maalim_service', 'paragraph counts unavailable: $e');
      return const {};
    }
  }

  /// The printed notes on one مقدمه/خاتمه paragraph.
  Future<List<Map<String, dynamic>>> footnotesOfSection(int sectionId) =>
      _guardRead('section footnotes',
          () => _db.getFootnotesForSection(sectionId));

  Future<List<Map<String, dynamic>>> _guardRead(
      String what, Future<List<Map<String, dynamic>>> Function() read) async {
    try {
      return await read();
    } catch (e) {
      AppLogger.warning('maalim_service', '$what unavailable: $e');
      return const [];
    }
  }

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

  /// Highest printed number of this edition, derived from the data (3,921).
  Future<int> maxHadithNumber() async {
    var max = 0;
    for (final entry in await _numberedEntries()) {
      if (entry.number > max) max = entry.number;
    }
    return max;
  }

  /// Finds the chapter and entry number carrying [number] — the printed
  /// number this edition prints on its «حدیث X» badges (1..3921). Returns
  /// `(chapterIndex, hadithNumber)` or null for a number the edition does not
  /// carry (a printed gap) — and the first of a number the book prints twice,
  /// because a jump target must be one place.
  Future<(num, int)?> locateHadithNumber(int number) async {
    if (number <= 0) return null;
    for (final entry in await _numberedEntries()) {
      if (entry.number == number) return (entry.chapterIndex, entry.number);
    }
    return null;
  }

  /// Narrations this edition carries (3,823 on the shipped database), not
  /// rows: the one unnumbered cross-reference row is excluded. The section's
  /// header counts the same set from the data it loaded, so the two cannot
  /// disagree.
  Future<int> totalEntries() async => (await _numberedEntries()).length;

  /// Full-text search (normalized Arabic matching).
  Future<List<Map<String, dynamic>>> search(String query, {int limit = 30}) =>
      _db.searchArabic(query, limit: limit);
}

/// صفحه‌بندی محتوای کتاب‌ها بر اساس نشانگرهای صفحهٔ چاپی.
///
/// کتاب‌های کتابخانه فایل JSON با لیست پاراگراف‌ها هستند؛ پاراگراف‌ها در هم
/// ادغام شده‌اند اما مرز صفحهٔ نسخهٔ چاپی با نشانگرهایی مانند
/// `(3/458) ---` جدا شده‌اند. این سرویس متن را بر همین مرزها برش می‌زند تا:
///  - شماره‌های صفحه با نسخهٔ چاپی هماهنگ باشند (پرش دقیق به «صفحهٔ 59»)،
///  - فهرست (TOC) از همین برش‌ها برچسب بگیرد، و
///  - بخش‌هایی که با «باب/کتاب/فصل…» شروع می‌شوند قابل پرش باشند.
library;

/// یک «صفحه» در نسخهٔ خواننده.
class BookPage {
  /// ایندکس 0-پایه در ترتیب صفحات (مورد استفادهٔ خواننده).
  final int index;

  /// شمارهٔ صفحهٔ چاپی وقتی نشانگر `(N/M)` موجود است؛ وگرنه `null`.
  final int? printNo;

  /// شمارهٔ آخرین صفحهٔ چاپی (`M`) وقتی مشخص باشد.
  final int? printTotal;

  /// متن کامل صفحه.
  final String text;

  /// سربرگ تشخیص‌داده‌شدهٔ ابتدای صفحه (مثل «باب 12: …») یا `null`.
  final String? heading;

  /// شمارهٔ جلد (۰پایه) که این صفحه به آن تعلق دارد؛ فقط زمانی معنا دارد که
  /// [BookPagination.paginate] شمار جلدها را گرفته باشد. صفحه‌ها را جابه‌جا
  /// نمی‌کند — فقط برچسبی است برای پرش به جلد در فهرست.
  final int volume;

  /// پانوشت‌های همین صفحه، کلید‌شده با شمارهٔ منبع (`57` برای `(57)`).
  ///
  /// فایل‌های کتاب یک نگاشت پانوشت برای کل جلد دارند و شماره‌ها در هر باب از
  /// نو شروع می‌شوند، پس یک شناسه در جاهای مختلف به پانوشت‌های متفاوت
  /// پاسخ می‌دهد. هر صفحه تنها پانوشت‌های خودش را می‌گیرد تا متنِ صفحهٔ اول
  /// در پای صفحه‌های بعد تکرار نشود.
  final Map<String, String> notes;

  const BookPage({
    required this.index,
    required this.text,
    this.printNo,
    this.printTotal,
    this.heading,
    this.volume = 0,
    this.notes = const {},
  });

  /// برچسب نمایشی این صفحه در فهرست.
  String get label {
    if (heading != null && heading!.isNotEmpty) return heading!;
    return _firstLine(text);
  }

  /// شمارهٔ نمایشی کامل مثل «59 / 458».
  String get pageLabel {
    if (printNo != null) {
      final total = printTotal != null ? ' / $printTotal' : '';
      return '$printNo$total';
    }
    return '${index + 1}';
  }

  /// رونوشت با سربرگ — برای افزودن سربرگ پس از ایجاد.
  BookPage withHeading(String? header) => BookPage(
        index: index,
        text: text,
        printNo: printNo,
        printTotal: printTotal,
        heading: header ?? heading,
        volume: volume,
        notes: notes,
      );

  /// رونوشت با سربرگ و جلد تازه — گام پایانیِ صفحه‌بندی.
  BookPage withPlacement(String? header, int newVolume) => BookPage(
        index: index,
        text: text,
        printNo: printNo,
        printTotal: printTotal,
        heading: header ?? heading,
        volume: newVolume,
        notes: notes,
      );

  /// رونوشت با تنِ برش‌خورده و پانوشت‌های همین صفحه.
  BookPage withBody(String newText, Map<String, String> newNotes) => BookPage(
        index: index,
        text: newText,
        printNo: printNo,
        printTotal: printTotal,
        heading: heading,
        volume: volume,
        notes: newNotes,
      );

  /// رونوشت با ایندکس تازه — پس از کنار گذاشتن صفحه‌های تهی.
  BookPage withIndex(int newIndex) => BookPage(
        index: newIndex,
        text: text,
        printNo: printNo,
        printTotal: printTotal,
        heading: heading,
        volume: volume,
        notes: notes,
      );

  static String _firstLine(String text) {
    final first = text.trim();
    if (first.isEmpty) return '';
    final newline = first.indexOf('\n');
    if (newline > 0) return first.substring(0, newline).trim();
    return first.length > 90 ? first.substring(0, 90).trim() : first.trim();
  }
}

/// موتور صفحه‌بندی — خالص و قابل تست.
abstract final class BookPagination {
  /// نشانگر مرز صفحهٔ چاپی: `(3/458)`.
  static final RegExp _pageMarker = RegExp(r'\((\d+)\s*/\s*(\d+)\)');

  /// جداکننده‌های خط بلند (`---`) که گاهی بدون شماره دیده می‌شوند.
  static final RegExp _dashSeparator =
      RegExp(r'(?:\r?\n|^)\s*[-–—]{3,}\s*(?=\S)');

  /// جداکنندهٔ صفحه که بی‌درنگ پس از نشانگر `(N/M)` می‌آید.
  ///
  /// عمداً از [_dashSeparator] جدا است: اینجا فقط فاصله/یک شکست خط و سپس
  /// دست‌کم سه خط مجاز است، چون پرسش «آیا این نشانگر مرز صفحه است؟» با
  /// «کجای متن جداکننده دارد؟» یکی نیست.
  static final RegExp _breakAfterMarker =
      RegExp(r'[ \t]*(?:\r?\n)?[ \t]*[-–—]{3,}');

  /// طول پنجرهٔ بررسیِ پس از نشانگر (کد واحد).
  static const int _breakWindow = 45;

  static bool _hasPageBreakAfter(String text, int from) {
    final end = from + _breakWindow;
    final slice = text.substring(from, end < text.length ? end : text.length);
    return _breakAfterMarker.matchAsPrefix(slice) != null;
  }

  /// الگوی سربرگ‌های فقهی رایج ابتدای بخش — بدون `\b` چون حروف عربی/فارسی
  /// در Dart word-boundary محسوب نمی‌شوند؛ به‌جایش lookahead روی کاراکتر بعد.
  static final RegExp _headingRe = RegExp(
    r'^((?:باب|بَاب|الباب|الْبَاب|كتاب|کتاب|كِتَاب|کِتَاب|الكتاب|الفصل|فصل|فَصْل|مقدمة|مقدّمة|خاتمة|الخاتمة)(?=[\s:،,؛؛‌\-–—()]|[\u064B-\u065F]|$)[^\n]{0,80})',
  );

  /// [volumes] شمار جلدهای نسخهٔ چاپی (از فایل کتاب) است. وقتی بیش از یک
  /// جلد باشد، هر صفحه شمارهٔ جلد خودش را می‌گیرد تا فهرست بتواند به
  /// ابتدای جلد بپرد — مرز جلد از بازشماری شماره‌ها در نشانگرها (یا از
  /// تقسیم متناسب، وقتی نشانگرها قابل‌اتکا نیستند) به‌دست می‌آید.
  ///
  /// [legacyNotes] نگاشتِ پانوشتِ کل جلد از فایل کتاب است؛ فقط برای کتاب‌هایی
  /// که پانوشت‌ها را درون متن ندارند و تنها در حالتِ بی‌ابهام (شناسه‌ای که
  /// در سراسر کتاب فقط یک بار در متن می‌آید) به کار می‌رود.
  static List<BookPage> paginate(
    List<String> content, {
    int fallbackChars = 800,
    int volumes = 1,
    Map<String, String> legacyNotes = const {},
  }) {
    final text =
        content.map((p) => p.trim()).where((p) => p.isNotEmpty).join('\n');
    if (text.isEmpty) return const [];

    // 1) برش بر اساس نشانگرهای صفحهٔ چاپی.
    // شماره‌های صفحه در پانوشت‌ها (و گاهی در متن) هم داخل پرانتز تکرار
    // می‌شوند؛ نشانگرِ راستین همان است که بی‌درنگ جداکنندهٔ صفحه (`---`)
    // پشتش می‌آید. اگر هیچ نشانگری این شکل را نداشت، همهٔ نشانگرها مرز
    // شمرده می‌شوند تا سبکِ بدونِ جداکننده از دست نرود.
    final allMarkerMatches = _pageMarker.allMatches(text).toList();
    final genuineMarkers =
        allMarkerMatches.where((m) => _hasPageBreakAfter(text, m.end)).toList();
    final markerMatches =
        genuineMarkers.isNotEmpty ? genuineMarkers : allMarkerMatches;
    if (markerMatches.isNotEmpty) {
      final pages = <BookPage>[];
      // نشانگری که هر صفحه را ساخت (‎-1 برای پیش‌گفتار) — نگاشتِ مرز جلد
      // به ایندکس صفحه بدون این فهرست ممکن نیست.
      final startMarker = <int>[];
      for (var i = 0; i < markerMatches.length; i++) {
        final m = markerMatches[i];
        if (i == 0) {
          final head = _cleanChunk(text.substring(0, m.start));
          if (head.isNotEmpty) {
            pages.add(BookPage(index: pages.length, text: head));
            startMarker.add(-1);
          }
        }
        final chunkText = _cleanChunk(
          text.substring(
            m.end,
            i + 1 < markerMatches.length
                ? markerMatches[i + 1].start
                : text.length,
          ),
        );
        if (chunkText.isNotEmpty) {
          pages.add(BookPage(
            index: pages.length,
            text: chunkText,
            printNo: int.tryParse(m.group(1) ?? ''),
            printTotal: int.tryParse(m.group(2)!),
          ));
          startMarker.add(i);
        }
      }
      if (pages.length >= 2) {
        final volOf = _volumeOf(
          startMarker: startMarker,
          text: text,
          marks: markerMatches,
          volumes: volumes,
        );
        return _extractNotes([
          for (var i = 0; i < pages.length; i++)
            pages[i].withPlacement(_detectHeading(pages[i].text), volOf[i]),
        ], legacyNotes);
      }
    }

    // 2) برخی کتاب‌ها شمارهٔ صفحه ندارند ولی جداکنندهٔ `---` دارند.
    final dashMatches = _dashSeparator.allMatches(text).toList();
    if (dashMatches.length >= 2) {
      final pages = <BookPage>[];
      var cursor = 0;
      for (final m in dashMatches) {
        final chunk = _cleanChunk(text.substring(cursor, m.start));
        if (chunk.isNotEmpty) {
          pages.add(BookPage(index: pages.length, text: chunk));
        }
        cursor = m.end;
      }
      final tail = _cleanChunk(text.substring(cursor));
      if (tail.isNotEmpty) pages.add(BookPage(index: pages.length, text: tail));
      if (pages.length >= 2) {
        return _extractNotes(_withPlacement(pages, volumes), legacyNotes);
      }
    }

    // 3) بدون مرز: تقسیم به قطعات کاراکتری (رفتار قبلی).
    final words = text.split(RegExp(r'\s+'));
    final pages = <BookPage>[];
    final buffer = StringBuffer();
    var chars = 0;
    for (final w in words) {
      buffer.write('$w ');
      chars += w.length + 1;
      if (chars >= fallbackChars) {
        pages
            .add(BookPage(index: pages.length, text: buffer.toString().trim()));
        buffer.clear();
        chars = 0;
      }
    }
    final tail = buffer.toString().trim();
    if (tail.isNotEmpty) pages.add(BookPage(index: pages.length, text: tail));
    return _extractNotes(_withPlacement(pages, volumes), legacyNotes);
  }

  /// شمارهٔ صفحهٔ چاپیِ هر صفحه در چیدمانِ پیش از پالایش نشانگرها.
  ///
  /// تنها برای مهاجرت ایندکس‌های ذخیره‌شده به کار می‌رود: پیش‌تر هر `(N/M)`
  /// — حتی شمارهٔ پانوشت — صفحه‌ای جدا می‌ساخت و حذفِ آن صفحه‌های ساختگی
  /// ایندکس‌ها را جابه‌جا می‌کند. با این فهرست، صفحهٔ قدیم از روی شمارهٔ
  /// چاپی‌اش در چیدمان تازه پیدا می‌شود.
  static List<int?> legacyPrintNos(List<String> content) {
    final text =
        content.map((p) => p.trim()).where((p) => p.isNotEmpty).join('\n');
    if (text.isEmpty) return const [];
    final all = _pageMarker.allMatches(text).toList();
    if (all.isEmpty) return const [];
    final out = <int?>[];
    for (var i = 0; i < all.length; i++) {
      final m = all[i];
      if (i == 0) {
        final head = _cleanChunk(text.substring(0, m.start));
        if (head.isNotEmpty) out.add(null);
      }
      final chunk = _cleanChunk(
        text.substring(
          m.end,
          i + 1 < all.length ? all[i + 1].start : text.length,
        ),
      );
      if (chunk.isNotEmpty) out.add(int.tryParse(m.group(1) ?? ''));
    }
    return out;
  }

  /// ایندکس شروع هر جلد (۰=جلد اول) از روی برچسب جلدِ خودِ صفحات.
  ///
  /// وقتی فقط یک جلد هست `[0]` برمی‌گردد — شیت فهرست در آن حالت
  /// چیپی نشان نمی‌دهد.
  static List<int> volumeStartsOf(List<BookPage> pages) {
    if (pages.isEmpty) return const [];
    final starts = <int>[0];
    for (var i = 1; i < pages.length; i++) {
      if (pages[i].volume != pages[i - 1].volume) starts.add(i);
    }
    return starts;
  }

  /// شمارهٔ جلدِ هر صفحه در چیدمانِ بدون نشانگر: تقسیم متناسب.
  static List<BookPage> _withPlacement(List<BookPage> pages, int volumes) {
    final boundaries = _proportionalStarts(pages.length, volumes);
    return [
      for (final p in pages)
        p.withPlacement(
          _detectHeading(p.text),
          _volumeAtBoundaries(boundaries, p.index),
        ),
    ];
  }

  /// شمارهٔ جلدِ هر صفحه در چیدمانِ نشانگری.
  ///
  /// دو نشانه، هر دو از دلِ نشانگرهای `(N/M)`:
  ///  * **بازشماری X**: نشانگر دوباره به `1` برمی‌گردد (جلد شمارهٔ خودش را
  ///    از نو شروع می‌کند) — در دادهٔ واقعی کتابخانه دقیقاً همان‌جایی است
  ///    که شمارهٔ صفحهٔ چاپی هم می‌پرد (۴۱۴→۳۶)؛
  ///  * **پرش شمارهٔ صفحه**: عدد چاپیِ قبلِ نشانگر بیش از ۲۰ تا کم می‌شود.
  /// فقط وقتی شمارِ هر نشانه دقیقاً `volumes-1` باشد به آن اعتماد می‌شود؛
  /// در غیر این صورت (نشانگرهای ارجاعی/پرشیِ کتاب‌هایی مثل ۵۴۹۲۹) مرز
  /// متناسب تقسیم می‌شود — بهتر از یک مرز دروغین است.
  static List<int> _volumeOf({
    required List<int> startMarker,
    required String text,
    required List<RegExpMatch> marks,
    required int volumes,
  }) {
    if (volumes < 2 || startMarker.length < 2) {
      return List<int>.filled(startMarker.length, 0);
    }

    final xResets = <int>[];
    final folioDrops = <int>[];
    int? lastFolio;
    for (var i = 0; i < marks.length; i++) {
      if (i > 0 &&
          marks[i].group(1) == '1' &&
          (int.tryParse(marks[i - 1].group(1) ?? '') ?? 1) > 1) {
        xResets.add(i);
      }
      final folio = _folioBefore(text, marks[i].start);
      if (folio != null) {
        if (lastFolio != null && lastFolio - folio > 20) folioDrops.add(i);
        lastFolio = folio;
      }
    }

    List<int>? boundaryMarkers;
    if (xResets.length == volumes - 1) {
      boundaryMarkers = xResets;
    } else if (folioDrops.length == volumes - 1) {
      boundaryMarkers = folioDrops;
    }

    final List<int> boundaries;
    if (boundaryMarkers != null) {
      // نشانگرِ بازشماری، نخستین نشانگرِ جلد تازه است؛ آن نشانگر chunkِ
      // پیش‌ از خودش را می‌بندد، پس جلد از همان chunk شروع می‌شود — یعنی
      // اولین صفحه‌ای که نشانگرش ≥ b-1 باشد.
      boundaries = [
        for (final b in boundaryMarkers)
          _firstPageAtOrAfter(startMarker, b - 1),
      ];
    } else {
      boundaries = _proportionalStarts(startMarker.length, volumes);
    }
    return [
      for (var p = 0; p < startMarker.length; p++)
        _volumeAtBoundaries(boundaries, p),
    ];
  }

  /// مرزِ متناسبِ جلدها (ایندکس صفحه)، صعودی و داخل محدوده.
  static List<int> _proportionalStarts(int pageCount, int volumes) {
    if (volumes < 2 || pageCount < 2) return const [];
    final out = <int>[];
    var prev = 0;
    for (var k = 1; k < volumes; k++) {
      final raw = ((k * pageCount) / volumes).round().clamp(1, pageCount - 1);
      if (raw > prev) {
        out.add(raw);
        prev = raw;
      }
    }
    return out;
  }

  /// شمارهٔ جلدِ صفحهٔ [page] با مرزهای صعودی (تعدادِ مرزهای پیش از آن).
  static int _volumeAtBoundaries(List<int> boundaries, int page) {
    var volume = 0;
    for (final b in boundaries) {
      if (b <= page) {
        volume++;
      } else {
        break;
      }
    }
    return volume;
  }

  /// اولین صفحه‌ای که نشانگرش ≥ [marker] است (یا آخرین صفحه).
  static int _firstPageAtOrAfter(List<int> startMarker, int marker) {
    for (var p = 0; p < startMarker.length; p++) {
      if (startMarker[p] >= marker) return p;
    }
    return startMarker.length - 1;
  }

  /// عدد چاپیِ چسبیده به پیش از نشانگر — شمارهٔ صفحهٔ نسخهٔ چاپی.
  ///
  /// یک عدد داخل پرانتز (ارجاع مثل `(2/592)`) شمارهٔ صفحه نیست و رد
  /// می‌شود، وگرنه همان ارجاعِ حاشیه‌ای «پرش صفحه» جعل می‌کرد.
  static final RegExp _folioTail = RegExp(r'(\d{1,4})\s*$');

  static int? _folioBefore(String text, int markerStart) {
    final from = markerStart > 25 ? markerStart - 25 : 0;
    final slice = text.substring(from, markerStart);
    final m = _folioTail.firstMatch(slice);
    if (m == null) return null;
    if (m.start > 0 && slice[m.start - 1] == '(') return null;
    return int.tryParse(m.group(1)!);
  }

  /// آغازِ بلوکِ پانوشت درون‌متنی: `____ (57) متن پانوشت`.
  ///
  /// بعضی فایل‌ها پیش از خطِ جداکننده یک شمارهٔ ترتیبی یا خط تیره هم
  /// می‌گذارند (`____ (57) 3- متن`) و بعضی شماره را در قلاب می‌نویسند
  /// (`____ [57] متن`)؛ هر سه همان بلوک است.
  static final RegExp _noteBlobStart =
      RegExp(r'_{1,}\s*[\(\[]\s*\d+\s*[\)\]]');

  /// سرصفحهٔ هر پانوشت با خط تیره: `(57) - ` یا `(57) 3- `.
  static final RegExp _noteEntry =
      RegExp(r'[\(\[]\s*(\d+)\s*[\)\]]\s*(?:\d+\s*)?[-–—]\s*');

  /// سرصفحهٔ هر پانوشت با خطِ جداکننده: `____ (57) `.
  static final RegExp _noteHeading =
      RegExp(r'_{2,}\s*[\(\[]\s*(\d+)\s*[\)\]]');

  /// سرصفحهٔ قلابی: `[57] ` — نسخه‌هایی که شمارهٔ پانوشت را در قلاب می‌گذارند.
  static final RegExp _noteBracket = RegExp(r'\[(\d+)\]');

  /// نشانگر ارجاعِ پانوشت در تنِ صفحه: `(57)`.
  static final RegExp _noteRef = RegExp(r'\((\d+)\)');

  /// خطِ جداکنندهٔ تهی (`__________`) چیزی برای خواندن نیست.
  static final RegExp _ruleLine =
      RegExp(r'^[ \t]*_{3,}[ \t]*$', multiLine: true);
  static final RegExp _inlineRule = RegExp(r'[ \t]*_{3,}[ \t]*');
  static final RegExp _doubleSpace = RegExp(r'[ \t]{2,}');

  /// بیرون کشیدن پانوشت‌های درون‌متنی و بریدنشان از تنِ صفحه.
  ///
  /// فایل‌های کتاب متنِ پانوشت‌ها را در همان پاراگرافِ متن گذاشته‌اند
  /// (`____ (57) - …`)؛ آن بلوک در پای صفحهٔ نخست می‌ماند و خواننده آن را در
  /// پای همهٔ صفحه‌ها تکرار می‌کرد. اینجا بلوک فقط از همان صفحه بریده و به
  /// [BookPage.notes] خودش منتقل می‌شود؛ نشانگرهای `(57)` در متن می‌مانند تا
  /// همچنان شناسایی شوند. تنِ صفحه جز این برش دست‌نخورده است (آفست‌های
  /// هایلایت جابه‌جا نمی‌شوند).
  static List<BookPage> _extractNotes(
    List<BookPage> pages,
    Map<String, String> legacyNotes,
  ) {
    final owned = <String>{};
    final stripped = <BookPage>[];
    for (final raw in pages) {
      final blob = _noteBlobStart.firstMatch(raw.text);
      if (blob == null) {
        stripped.add(_tidyPage(raw));
        continue;
      }
      final notes = _notesInTail(raw.text.substring(blob.start));
      owned.addAll(notes.keys);
      stripped.add(_tidyPage(raw.withBody(
        raw.text.substring(0, blob.start).trimRight(),
        notes,
      )));
    }
    if (legacyNotes.isEmpty) return _compact(stripped);

    // نگاشتِ کل‌جلدی فقط وقتی به کار می‌رود که شناسه در سراسر کتاب یک بار
    // آمده باشد؛ وگرنه چاپِ پانوشتِ اشتباه است و سکوت صادقانه‌تر.
    final at = <String, List<int>>{};
    for (var i = 0; i < stripped.length; i++) {
      for (final m in _noteRef.allMatches(stripped[i].text)) {
        final slots = at.putIfAbsent(m.group(1)!, () => <int>[]);
        if (!slots.contains(i)) slots.add(i);
      }
    }
    return _compact([
      for (var i = 0; i < stripped.length; i++)
        _withLegacyNotes(stripped[i], i, at, owned, legacyNotes),
    ]);
  }

  /// صفحه‌ای که تنها پانوشت داشت، پس از برش تهی می‌شود — برگِ سفید در
  /// وسط کتاب است، پس حذف و ایندکس‌ها دوباره شماره می‌شوند.
  static List<BookPage> _compact(List<BookPage> pages) {
    final kept = [
      for (final page in pages)
        if (page.text.trim().isNotEmpty) page,
    ];
    return [
      for (var i = 0; i < kept.length; i++) kept[i].withIndex(i),
    ];
  }

  /// پانوشت‌های یک بلوک، کلید‌شده با شمارهٔ ارجاع.
  ///
  /// سه شکل در داده هست: `(57) - متن`، `____ (57) متن` و `[57] متن`.
  /// شکلی که شمارش بیشتری دارد همان بلوک است؛ پیش از این، بلوکِ بی‌شکل
  /// در تنِ صفحه می‌ماند و خواننده آن را وسط متن می‌دید.
  static Map<String, String> _notesInTail(String tail) {
    final dashed = _noteEntry.allMatches(tail).toList();
    final headed = _noteHeading.allMatches(tail).toList();
    final bracket = _noteBracket.allMatches(tail).toList();
    // خط تیره گویاترین شکل است؛ وگرنه قلاب تنها وقتی برنده است که از
    // سرصفحه‌های جداکننده بیشتر باشد (چند پانوشتِ قلابی در یک بلوک).
    final entries = dashed.isNotEmpty
        ? dashed
        : (bracket.length > headed.length ? bracket : headed);
    final notes = <String, String>{};
    for (var i = 0; i < entries.length; i++) {
      final body = tail
          .substring(
            entries[i].end,
            i + 1 < entries.length ? entries[i + 1].start : tail.length,
          )
          .replaceFirst(RegExp(r'^[\s_]*[-–—]\s*'), '')
          .replaceAll(RegExp(r'[\s_]+$'), '')
          .trim();
      if (body.isNotEmpty) {
        notes.putIfAbsent(entries[i].group(1)!, () => body);
      }
    }
    return notes;
  }

  /// خطِ جداکنندهٔ تهی را از تنِ صفحه برمی‌دارد.
  static BookPage _tidyPage(BookPage page) {
    final text = page.text
        .replaceAll(_ruleLine, '')
        .replaceAll(_inlineRule, ' ')
        .replaceAll(_doubleSpace, ' ')
        .trim();
    return text == page.text ? page : page.withBody(text, page.notes);
  }

  static BookPage _withLegacyNotes(
    BookPage page,
    int index,
    Map<String, List<int>> at,
    Set<String> owned,
    Map<String, String> legacyNotes,
  ) {
    Map<String, String>? extra;
    for (final entry in at.entries) {
      final id = entry.key;
      if (entry.value.length != 1 || entry.value.single != index) continue;
      if (owned.contains(id) || page.notes.containsKey(id)) continue;
      final value = legacyNotes[id]?.trim();
      if (value == null || value.isEmpty) continue;
      if (_noteEntry.allMatches(value).length > 1) continue;
      (extra ??= <String, String>{})[id] = value;
    }
    if (extra == null) return page;
    return page.withBody(page.text, {...page.notes, ...extra});
  }

  static String _cleanChunk(String raw) {
    return raw
        .replaceAll(RegExp(r'^\s*[-–—]{3,}\s*'), '')
        .replaceAll(RegExp(r'^\s+|\s+$'), '');
  }

  /// تشخیص سربرگ «باب/کتاب/فصل…» از ابتدای متن صفحه.
  static String? _detectHeading(String text) {
    final norm = text.trimLeft();
    if (norm.isEmpty) return null;
    final m = _headingRe.firstMatch(norm);
    if (m == null) return null;
    final raw = (m.group(1) ?? '').trim();
    if (raw.isEmpty) return null;
    return raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

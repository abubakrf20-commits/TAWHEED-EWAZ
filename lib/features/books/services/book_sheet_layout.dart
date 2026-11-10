import 'package:tawheeed/features/books/services/book_pagination.dart';

/// برگِ نمایشی خواننده — یکی از سه چیزی که خواننده می‌بیند:
///
///  * [BookSheetKind.page] یک صفحهٔ واقعی کتاب،
///  * [BookSheetKind.title] صفحهٔ عنوان،
///  * [BookSheetKind.blank] یک برگ سفید، تا فصل از برگ درست آغاز شود.
///
/// این لایه عمداً **نمایشی** است: ایندکس صفحهٔ محتوا (`BookPage.index`) همان
/// چیزی است که پیشرفت، نشانک و هایلایت با آن ذخیره می‌شوند، پس افزودن برگ
/// سفید یا صفحهٔ عنوان نباید هیچ دادهٔ ذخیره‌شده‌ای را جابه‌جا کند. صفحه‌بندی
/// هم دست‌نخورده می‌ماند؛ فقط ترتیبِ نمایش عوض می‌شود.
enum BookSheetKind { page, title, blank }

/// One displayed sheet — see [BookSheetKind].
class BookSheet {
  const BookSheet.page(this.page) : kind = BookSheetKind.page;

  const BookSheet.title()
      : page = -1,
        kind = BookSheetKind.title;

  const BookSheet.blank()
      : page = -1,
        kind = BookSheetKind.blank;

  final BookSheetKind kind;

  /// Content page index, or `-1` for the title and blank sheets.
  final int page;

  bool get isPage => kind == BookSheetKind.page;
}

/// ترتیب برگ‌ها برای یک کتاب — یک برگ در هر بار، همان‌طور که کاغذ ورق می‌خورد.
///
/// Two rules do all the work:
///
///  * **A chapter opens a sheet.** In a printed book a new باب starts on a
///    right-hand (first-read) page; when it would land on the wrong side a
///    blank sheet goes in front of it. A book is read as sheets, not as a
///    continuous strip, and a chapter starting mid-left looks like a printout.
///  * **The title gets a sheet of its own**, so a book opens on its name the
///    way a printed book does.
class BookSheetLayout {
  BookSheetLayout._({
    required this.sheets,
    required this.pageSheet,
  });

  /// Nothing loaded yet — the reader is still downloading.
  BookSheetLayout.empty()
      : sheets = const [],
        pageSheet = const [];

  /// ساخت ترتیب برگ‌ها.
  ///
  /// [titlePage] adds the opening sheet; [chapterRecto] is the rule described
  /// on the class — turn it off and the layout is exactly the raw page order
  /// with nothing inserted.
  factory BookSheetLayout.build({
    required List<BookPage> pages,
    required bool titlePage,
    required bool chapterRecto,
  }) {
    // Nothing to arrange: the reader shows its empty-content view, and a
    // title sheet in front of no book at all would be a book that never ends.
    if (pages.isEmpty) return BookSheetLayout.empty();

    final sheets = <BookSheet>[];

    if (titlePage) sheets.add(const BookSheet.title());

    for (var i = 0; i < pages.length; i++) {
      // Even sheet index = the side a chapter belongs on (a title sheet at
      // 0 counts, so the book's first page lands on the recto after it).
      if (chapterRecto && isChapter(pages[i]) && sheets.length.isOdd) {
        sheets.add(const BookSheet.blank());
      }
      sheets.add(BookSheet.page(i));
    }

    final pageSheet = List<int>.filled(pages.length, -1);
    for (var i = 0; i < sheets.length; i++) {
      final page = sheets[i].page;
      if (page >= 0 && pageSheet[page] < 0) pageSheet[page] = i;
    }
    return BookSheetLayout._(sheets: sheets, pageSheet: pageSheet);
  }

  /// برگ‌ها، به‌ترتیب نمایش.
  final List<BookSheet> sheets;

  /// page index → its sheet (for [sheetForPage]).
  final List<int> pageSheet;

  bool get isEmpty => sheets.isEmpty;

  /// یک صفحهٔ فصل، یعنی صفحه‌ای که با سربرگِ «باب/کتاب/فصل…» آغاز می‌شود.
  static bool isChapter(BookPage page) =>
      (page.heading ?? '').trim().isNotEmpty;

  /// The sheet that displays [page] (never a blank or the title).
  int sheetForPage(int page) {
    if (pageSheet.isEmpty) return 0;
    final at = page.clamp(0, pageSheet.length - 1);
    final sheet = pageSheet[at];
    return sheet < 0 ? 0 : sheet;
  }

  /// The content page a sheet belongs to: a blank belongs to the page in
  /// front of it (a flyleaf does not advance your position), and the title
  /// sits before page 0.
  int pageOfSheet(int sheet) {
    // An empty layout has no lower bound to clamp against, and there is no
    // content page to point at — the reader is still downloading.
    if (sheets.isEmpty) return 0;
    for (var i = sheet.clamp(0, sheets.length - 1); i >= 0; i--) {
      final page = sheets[i].page;
      if (page >= 0) return page;
    }
    return 0;
  }

  /// Next sheet in reading order, or `null` at the end of the book.
  int? stepForward(int sheet) {
    if (sheets.isEmpty) return null;
    final next = sheet + 1;
    return next < sheets.length ? next : null;
  }

  /// Previous sheet, or `null` at the front of the book.
  int? stepBack(int sheet) {
    if (sheets.isEmpty) return null;
    final previous = sheet - 1;
    return previous >= 0 ? previous : null;
  }
}

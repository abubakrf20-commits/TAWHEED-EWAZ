import 'package:tawheeed/features/books/services/book_pagination.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// One entry of a book file's own `toc` list.
class BookTocItem {
  const BookTocItem({required this.title, this.printPage});

  /// The entry as the edition prints it, without the trailing page number.
  final String title;

  /// The printed page the entry points at, when the file carries one.
  final int? printPage;
}

/// The `toc` array every book file ships — the edition's real table of
/// contents.
///
/// The reader used to guess a contents list from headings found at the top of
/// pages, which on PDF-extracted text produces a handful of «باب» lines and
/// misses most of the book. Each shipped `toc` entry ends with its printed page
/// (`… پیدا و ناپیدا 12`), so parsing it gives a contents list that matches the
/// paper edition and can be jumped to.
abstract final class BookToc {
  const BookToc._();

  /// A page number at the end of the entry. Persian and Arabic-Indic digits
  /// are included because the files are not consistent about them.
  static final RegExp _trailingPage =
      RegExp(r'[\s\u00A0]+([0-9\u06F0-\u06F9\u0660-\u0669]{1,4})\s*$');

  /// A line that is nothing but a page number is leftover page furniture,
  /// not a heading.
  static final RegExp _digitsOnly =
      RegExp(r'^[0-9\u06F0-\u06F9\u0660-\u0669]+$');

  static List<BookTocItem> parse(List<String> raw) {
    final out = <BookTocItem>[];
    for (final line in raw) {
      var text = line.trim();
      if (text.isEmpty || _digitsOnly.hasMatch(text)) continue;
      int? page;
      final m = _trailingPage.firstMatch(text);
      if (m != null) {
        final digits = NumberFormat.normalizeDigits(m.group(1)!);
        page = int.tryParse(digits);
        if (page != null) {
          text = text.substring(0, m.start).trim();
        }
      }
      if (text.isEmpty) continue;
      // A file that lists the same heading twice (a volume header and its
      // first section) should not make the reader pick twice.
      if (out.isNotEmpty &&
          out.last.title == text &&
          out.last.printPage == page) {
        continue;
      }
      out.add(BookTocItem(title: text, printPage: page));
    }
    return out;
  }

  /// Index in [pages] of the page printed as [printPage].
  ///
  /// Exact when the edition carries that number in its page markers. When it
  /// does not (front matter, or a marker the extractor dropped) the nearest
  /// earlier page wins, because a contents entry always points at or before
  /// its section — jumping forward would skip the heading the reader asked
  /// for. `null` only when the pages carry no printed numbers at all.
  static int? indexForPage(List<BookPage> pages, int printPage) {
    int? previous;
    for (var i = 0; i < pages.length; i++) {
      final no = pages[i].printNo;
      if (no == null) continue;
      if (no == printPage) return i;
      if (no < printPage) {
        previous = i;
        continue;
      }
      // Past the target: the previous numbered page is the best answer, and
      // before the first marker it is the page in front of it (front matter),
      // never the page after — which would skip the heading.
      return previous ?? (i > 0 ? i - 1 : i);
    }
    return previous;
  }
}

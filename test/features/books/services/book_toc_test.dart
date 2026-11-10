import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/books/services/book_pagination.dart';
import 'package:tawheeed/features/books/services/book_toc.dart';

/// The book files ship the edition's own contents list, and the numbers at the
/// end of each line are the only thing that connects it to a page in the
/// reader. Getting that arithmetic wrong silently sends the reader to the
/// wrong chapter, so it is pinned here.
void main() {
  group('parse', () {
    test('takes the printed page off the end of the entry', () {
      final items = BookToc.parse([
        'فصل في الأمر بالإخلاص 12',
        'باب ما يقول عند دخول المسجد 48',
      ]);
      expect(items.length, 2);
      expect(items.first.title, 'فصل في الأمر بالإخلاص');
      expect(items.first.printPage, 12);
      expect(items.last.printPage, 48);
    });

    test('reads Persian and Arabic-Indic page numbers', () {
      final items = BookToc.parse(['مقدمة ۱۲', 'الباب الأول ٤٨']);
      expect(items[0].printPage, 12);
      expect(items[1].printPage, 48);
    });

    test('an entry without a number keeps its whole title', () {
      final items = BookToc.parse(['خطبة الكتاب']);
      expect(items.single.title, 'خطبة الكتاب');
      expect(items.single.printPage, isNull);
    });

    test('blank lines and empty titles are dropped', () {
      expect(BookToc.parse(const ['', '   ', '12']), isEmpty);
    });

    test('a repeated heading is kept once', () {
      final items = BookToc.parse(['باب النية 3', 'باب النية 3']);
      expect(items.length, 1);
    });
  });

  group('indexForPage', () {
    List<BookPage> pages() => [
          const BookPage(index: 0, text: 'مقدمة'),
          const BookPage(index: 1, text: 'أ', printNo: 3, printTotal: 40),
          const BookPage(index: 2, text: 'ب', printNo: 5, printTotal: 40),
          const BookPage(index: 3, text: 'ج', printNo: 9, printTotal: 40),
        ];

    test('an exact printed page lands on its own index', () {
      expect(BookToc.indexForPage(pages(), 5), 2);
    });

    test('a missing number lands on the nearest EARLIER page', () {
      // Page 7 does not exist in the extract: the section starts somewhere in
      // page 5, never after it.
      expect(BookToc.indexForPage(pages(), 7), 2);
    });

    test('a number before the first marked page lands on the first page', () {
      expect(BookToc.indexForPage(pages(), 1), 0);
    });

    test('a number past the last page lands on the last marked page', () {
      expect(BookToc.indexForPage(pages(), 999), 3);
    });

    test('a book without printed numbers resolves to nothing', () {
      expect(
        BookToc.indexForPage(
          const [BookPage(index: 0, text: 'x'), BookPage(index: 1, text: 'y')],
          5,
        ),
        isNull,
      );
    });
  });
}

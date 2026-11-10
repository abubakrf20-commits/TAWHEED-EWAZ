import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/books/services/book_page_migration.dart';
import 'package:tawheeed/features/books/services/book_pagination.dart';

/// Page indexes are what the device stores (progress, bookmarks, highlights).
/// Removing the phantom marker pages renumbers them, and the printed page
/// number is the only anchor that survives both layouts.
void main() {
  BookPage page(int index, int? printNo) =>
      BookPage(index: index, text: 'صفحهٔ $index', printNo: printNo);

  group('BookPageMigration.remap', () {
    test('finds the page carrying the same printed number', () {
      final pages = [page(0, null), page(1, 1), page(2, 2), page(3, 3)];
      // The old layout had a phantom page between 1 and 2.
      final remap = BookPageMigration.remap(
        legacyPrintNos: const [null, 1, 57, 2, 3],
        pages: pages,
      );
      expect(remap[0], 0);
      expect(remap[1], 1);
      expect(remap[3], 2);
      expect(remap[4], 3);
    });

    test('a number the new layout does not hold is left unmapped', () {
      final pages = [page(0, null), page(1, 1)];
      final remap = BookPageMigration.remap(
        legacyPrintNos: const [null, 1, 2],
        pages: pages,
      );
      expect(remap.containsKey(2), isFalse);
    });

    test('first occurrence wins when a printed number repeats', () {
      final pages = [page(0, 4), page(1, 4), page(2, 5)];
      final remap = BookPageMigration.remap(
        legacyPrintNos: const [4, 5],
        pages: pages,
      );
      expect(remap[0], 0);
      expect(remap[1], 2);
    });

    test('the flag is per book, so one book cannot mask another', () {
      expect(
        BookPageMigration.flagKey('book_54929'),
        isNot(BookPageMigration.flagKey('book_67155')),
      );
    });
  });

  group('BookPagination.legacyPrintNos', () {
    test('mirrors the pre-filter layout, phantom pages included', () {
      final content = [
        '(1/100) --- یک',
        '(5/9) ارجاع --- دو',
        '(2/100) --- سه',
      ];
      expect(BookPagination.legacyPrintNos(content), [1, 5, 2]);
      // The filtered layout drops the phantom page.
      expect(
        BookPagination.paginate(content).map((p) => p.printNo),
        [1, 2],
      );
    });
  });
}

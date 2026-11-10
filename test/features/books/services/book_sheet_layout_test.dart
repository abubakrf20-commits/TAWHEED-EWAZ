import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/books/services/book_pagination.dart';
import 'package:tawheeed/features/books/services/book_sheet_layout.dart';

/// The layout is the whole of «چه چیزی کِی نشان داده می‌شود»: the title page
/// and the blank leaf a chapter opens on. None of it may touch a page index,
/// so progress, bookmarks and highlights keep their numbers.
///
/// The reader shows ONE sheet at a time — the two-page spread was removed, so
/// these tests also pin that a step is one sheet, never a pair.
void main() {
  BookPage page(int index, {String? heading}) => BookPage(
        index: index,
        text: 'متن صفحهٔ $index',
        heading: heading,
      );

  List<BookPage> book({required int length, List<int> chapters = const []}) => [
        for (var i = 0; i < length; i++)
          page(i, heading: chapters.contains(i) ? 'باب ${i + 1}' : null),
      ];

  List<BookSheet> build({
    required int length,
    List<int> chapters = const [],
    bool titlePage = false,
    bool chapterRecto = false,
  }) =>
      BookSheetLayout.build(
        pages: book(length: length, chapters: chapters),
        titlePage: titlePage,
        chapterRecto: chapterRecto,
      ).sheets;

  test('the raw page order when nothing is switched on', () {
    expect(
        build(length: 5, chapters: const [2]).map((s) => s.page),
        [0, 1, 2, 3, 4]);
  });

  test('a chapter that already opens a right-hand sheet gets no blank', () {
    final layout = BookSheetLayout.build(
      pages: book(length: 5, chapters: const [0, 2]),
      titlePage: false,
      chapterRecto: true,
    );
    expect(layout.sheets.map((s) => s.page), [0, 1, 2, 3, 4],
        reason: 'sheets 0 and 2 are already on the recto side');
  });

  test('a chapter landing on a verso gets a blank leaf in front of it', () {
    final layout = BookSheetLayout.build(
      pages: book(length: 5, chapters: const [3]),
      titlePage: false,
      chapterRecto: true,
    );
    expect(layout.sheets.map((s) => s.kind), [
      BookSheetKind.page, // 0 (sheet 0)
      BookSheetKind.page, // 1
      BookSheetKind.page, // 2 (sheet 2)
      BookSheetKind.blank, // sheet 3 — 3 would open a verso
      BookSheetKind.page, // 3 (sheet 4)
      BookSheetKind.page, // 4
    ]);
    // The page numbers themselves are untouched.
    expect(layout.sheets.where((s) => s.isPage).map((s) => s.page),
        [0, 1, 2, 3, 4]);
    expect(layout.pageOfSheet(3), 2,
        reason: 'a flyleaf belongs to the page in front of it');
  });

  test('the title takes the first sheet, so the book starts on a recto', () {
    final layout = BookSheetLayout.build(
      pages: book(length: 3, chapters: const [0]),
      titlePage: true,
      chapterRecto: true,
    );
    expect(layout.sheets.map((s) => s.kind), [
      BookSheetKind.title,
      BookSheetKind.blank, // the verso behind the title
      BookSheetKind.page, // chapter opens the next recto
      BookSheetKind.page,
      BookSheetKind.page,
    ]);
    expect(layout.sheetForPage(0), 2);
    expect(layout.pageOfSheet(0), 0);
    expect(layout.sheetForPage(2), 4);
  });

  test('the title alone adds one sheet and no blank', () {
    expect(
        build(length: 3, titlePage: true)
            .map((s) => s.kind)
            .toList(),
        [
          BookSheetKind.title,
          BookSheetKind.page,
          BookSheetKind.page,
          BookSheetKind.page,
        ]);
  });

  test('page ↔ sheet survives a layout with nothing inserted', () {
    final layout = BookSheetLayout.build(
      pages: book(length: 6),
      titlePage: false,
      chapterRecto: false,
    );
    for (var p = 0; p < 6; p++) {
      expect(layout.sheetForPage(p), p);
      expect(layout.pageOfSheet(p), p);
    }
  });

  test('a step is one sheet, so an odd last page has no empty partner', () {
    final layout = BookSheetLayout.build(
      pages: book(length: 3),
      titlePage: false,
      chapterRecto: false,
    );
    expect(layout.sheets.map((s) => s.page), [0, 1, 2],
        reason: 'nothing is padded in — the reader never shows a blank beside '
            'a page');
    expect(layout.stepForward(0), 1);
    expect(layout.stepForward(2), isNull);
    expect(layout.stepBack(2), 1);
    expect(layout.stepBack(0), isNull);
  });

  test('turning past a flyleaf lands on the chapter, then on its next page',
      () {
    final layout = BookSheetLayout.build(
      pages: book(length: 4, chapters: const [3]),
      titlePage: false,
      chapterRecto: true,
    );
    // sheets: 0, 1, 2, blank, 3
    expect(layout.stepForward(2), 3);
    expect(layout.stepForward(3), 4);
    expect(layout.sheets[4].page, 3);
    expect(layout.sheetForPage(3), 4);
  });

  test('an empty book never steps off the end', () {
    final layout = BookSheetLayout.build(
      pages: const [],
      titlePage: true,
      chapterRecto: true,
    );
    expect(layout.sheets, isEmpty);
    expect(layout.stepForward(0), isNull);
    expect(layout.stepBack(0), isNull);
    expect(layout.pageOfSheet(0), 0);
    expect(BookSheetLayout.empty().sheets, isEmpty);
  });
}

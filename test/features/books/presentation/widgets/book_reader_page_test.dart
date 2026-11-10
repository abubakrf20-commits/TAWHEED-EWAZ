import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/books/presentation/book_page_notes.dart';
import 'package:tawheeed/features/books/presentation/widgets/book_reader_page.dart';
import 'package:tawheeed/features/books/services/book_pagination.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// The page is the reader's whole «کتاب‌بودن»: justified text, a running head,
/// a folio, and page turns in the margins only. Each of those is a promise a
/// future edit could quietly drop, so they are pinned here.
void main() {
  BookPage page({
    String text = 'بند نخست این صفحه است.\nبند دوم این صفحه است.',
    String? heading,
    int? printNo,
    int? printTotal,
    int index = 0,
  }) =>
      BookPage(
        index: index,
        text: text,
        heading: heading,
        printNo: printNo,
        printTotal: printTotal,
      );

  Future<void> pump(
    WidgetTester tester,
    BookPage p, {
    String query = '',
    VoidCallback? onNext,
    VoidCallback? onPrev,
  }) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: BookReaderPage(
            page: p,
            bookTitle: 'شرح آسان عقیده طحاوی',
            style: const BookReaderPageStyle(
              fontSize: 16,
              lineHeight: 1.8,
              fontFamily: 'Vazirmatn',
              ink: Color(0xFF2C2C2C),
              sideMargin: 26,
            ),
            highlights: const [],
            footnotes: const <BookPageNote>[],
            searchQuery: query,
            onNext: onNext,
            onPrev: onPrev,
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets('every paragraph is justified on both edges', (tester) async {
    await pump(tester, page());
    final paragraphs = tester.widgetList<SelectableText>(
        find.byType(SelectableText));
    expect(paragraphs, isNotEmpty);
    for (final p in paragraphs) {
      expect(p.textAlign, TextAlign.justify,
          reason: 'the page is set as a book, not as ragged text');
    }
  });

  testWidgets('paragraphs are separated by air, not by a blank line',
      (tester) async {
    await pump(tester, page());
    final rects = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .map((w) => tester.getRect(find.byWidget(w)))
        .toList();
    expect(rects.length, 2);
    expect(rects[1].top - rects[0].bottom, greaterThan(4),
        reason: 'a page with no paragraph gap reads as one wall of text');
  });

  testWidgets('the running head carries the chapter, else the book title',
      (tester) async {
    await pump(tester, page(heading: 'باب سوم: توحید', index: 1));
    expect(find.text('باب سوم: توحید'), findsOneWidget);

    await pump(tester, page());
    expect(find.text('شرح آسان عقیده طحاوی'), findsOneWidget);
  });

  testWidgets('a printed book alternates title and chapter page to page',
      (tester) async {
    // Odd index (a verso in this page order) carries the chapter, even the
    // book's own name, the way a running head moves in a real book.
    await pump(tester, page(heading: 'باب سوم: توحید', index: 3));
    expect(find.text('باب سوم: توحید'), findsOneWidget);
    expect(find.text('شرح آسان عقیده طحاوی'), findsNothing);

    await pump(tester, page(heading: 'باب سوم: توحید', index: 4));
    expect(find.text('شرح آسان عقیده طحاوی'), findsOneWidget);
    expect(find.text('باب سوم: توحید'), findsNothing);
  });

  testWidgets('the footnote mode rules the marker and the note',
      (tester) async {
    Future<void> pumpWith(BookFootnoteMode mode) async {
      await tester.binding.setSurfaceSize(const Size(360, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: BookReaderPage(
              page: page(text: 'قال الله تعالى (37) ثم'),
              bookTitle: 'كتاب',
              style: BookReaderPageStyle(
                fontSize: 16,
                lineHeight: 1.8,
                fontFamily: 'Vazirmatn',
                ink: const Color(0xFF2C2C2C),
                sideMargin: 26,
                footnoteMode: mode,
              ),
              highlights: const [],
              footnotes: const [
                BookPageNote(
                  displayNumber: 1,
                  sourceId: '37',
                  text: 'الحاشية',
                ),
              ],
            ),
          ),
        ),
      ));
      await tester.pump();
    }

    int widgetSpans() {
      var count = 0;
      for (final text in tester
          .widgetList<SelectableText>(find.byType(SelectableText))) {
        text.textSpan?.visitChildren((child) {
          if (child is WidgetSpan) count++;
          return true;
        });
      }
      return count;
    }

    String plain(String? text) =>
        (text ?? '').replaceAll(RegExp('[\u2066\u2069]'), '');

    await pumpWith(BookFootnoteMode.markers);
    expect(widgetSpans(), 1, reason: 'the marker is a tappable widget');
    // The marker prints the page-local number, never the source number it
    // came from — that is what made one note look like it belonged to
    // several pages.
    expect(
      tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => plain(text.data))
          .where((data) => data == '1'),
      isNotEmpty,
      reason: 'the page numbers its own notes from one',
    );
    expect(
      tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => plain(text.data))
          .where((data) => data == '37'),
      isEmpty,
      reason: 'a source number is provenance, not a printed marker',
    );

    await pumpWith(BookFootnoteMode.notes);
    expect(widgetSpans(), 0,
        reason: 'plain text keeps the page uninterrupted');
    expect(find.textContaining('(37)'), findsOneWidget);

    await pumpWith(BookFootnoteMode.hidden);
    expect(widgetSpans(), 0);
    expect(find.textContaining('(37)'), findsOneWidget);
    expect(find.textContaining('الحاشية'), findsNothing,
        reason: 'hiding footnotes hides the whole apparatus');
  });

  testWidgets('the folio prints the edition page numbers', (tester) async {
    await pump(tester, page(printNo: 59, printTotal: 458));
    final folio = tester.widgetList<Text>(find.byType(Text)).where((t) {
      final data = t.data;
      if (data == null) return false;
      // The isolate marks are invisible but part of the string.
      return data.replaceAll(RegExp('[\u2066\u2069]'), '') == '59 / 458';
    });
    expect(folio, isNotEmpty,
        reason: 'a printed book numbers its pages; so does this one');
  });

  testWidgets('the gutter margin follows the sheet, and only when asked',
      (tester) async {
    Future<EdgeInsets> pumpStyle({
      required bool mirror,
      required bool gutterLeft,
    }) async {
      await tester.binding.setSurfaceSize(const Size(360, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: BookReaderPage(
              page: page(),
              bookTitle: 'كتاب',
              style: BookReaderPageStyle(
                fontSize: 16,
                lineHeight: 1.8,
                fontFamily: 'Vazirmatn',
                ink: const Color(0xFF2C2C2C),
                sideMargin: 26,
                mirrorMargin: mirror,
                gutterOnLeft: gutterLeft,
              ),
              highlights: const [],
              footnotes: const <BookPageNote>[],
            ),
          ),
        ),
      ));
      await tester.pump();
      final scroll = tester.widget<SingleChildScrollView>(
          find.byType(SingleChildScrollView));
      return scroll.padding as EdgeInsets;
    }

    final flat = await pumpStyle(mirror: false, gutterLeft: false);
    expect(flat.left, 26, reason: 'mirror off = two equal margins');
    expect(flat.right, 26);

    final gutterLeft = await pumpStyle(mirror: true, gutterLeft: true);
    expect(gutterLeft.left, 26 + BookReaderPageStyle.gutter,
        reason: 'the fold side keeps the binding room');
    expect(gutterLeft.right, 26);

    final gutterRight = await pumpStyle(mirror: true, gutterLeft: false);
    expect(gutterRight.right, 26 + BookReaderPageStyle.gutter,
        reason: 'turning the sheet moves the gutter to the other edge');
    expect(gutterRight.left, 26);
  });

  testWidgets('tapping the text selects, tapping a margin turns the page',
      (tester) async {
    var next = 0;
    var prev = 0;
    await pump(tester, page(),
        onNext: () => next++, onPrev: () => prev++);

    // The middle of the page belongs to the text.
    await tester.tap(find.byType(SelectableText).first);
    await tester.pump();
    expect(next + prev, 0,
        reason: 'a full-page tap overlay is what used to block selection');

    // Left margin in RTL advances, the right margin goes back.
    await tester.tapAt(const Offset(8, 300));
    await tester.pump();
    expect(next, 1);
    await tester.tapAt(const Offset(352, 300));
    await tester.pump();
    expect(prev, 1);
  });

  testWidgets('a search hit is painted, not just counted', (tester) async {
    await pump(tester, page(), query: 'دوم');
    final rich = tester.widgetList<SelectableText>(
        find.byType(SelectableText));
    var painted = false;
    for (final p in rich) {
      final span = p.textSpan;
      span?.visitChildren((child) {
        if (child is TextSpan &&
            child.style?.backgroundColor != null &&
            (child.text ?? '').contains('دوم')) {
          painted = true;
        }
        return true;
      });
    }
    expect(painted, isTrue);
  });

  group('the page prints its own notes at its foot, open like a book', () {
    Future<void> pumpWithNotes(
      WidgetTester tester, {
      required BookFootnoteMode mode,
      String text = 'قال رسول الله (3) وبشّر (7).\nوروى أيضاً (3) مرّتين.',
      List<BookPageNote> notes = const [
        BookPageNote(displayNumber: 1, sourceId: '3', text: 'الحاشية الأولى'),
        BookPageNote(displayNumber: 2, sourceId: '7', text: 'الحاشية الثانية'),
      ],
    }) async {
      await tester.binding.setSurfaceSize(const Size(360, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: BookReaderPage(
              page: page(text: text),
              bookTitle: 'كتاب',
              style: BookReaderPageStyle(
                fontSize: 16,
                lineHeight: 1.8,
                fontFamily: 'Vazirmatn',
                ink: const Color(0xFF2C2C2C),
                sideMargin: 26,
                footnoteMode: mode,
              ),
              highlights: const [],
              footnotes: notes,
            ),
          ),
        ),
      ));
      await tester.pump();
    }

    Finder note(String needle) => find.byWidgetPredicate(
          (w) =>
              w is Text &&
              (w.textSpan?.toPlainText() ?? '').contains(needle),
        );

    int noteRows(WidgetTester tester) => tester
        .widgetList<Text>(find.byType(Text))
        .where((t) => (t.textSpan?.toPlainText() ?? '').contains('الحاشية'))
        .length;

    testWidgets('every note is on the page, under its text', (tester) async {
      await pumpWithNotes(tester, mode: BookFootnoteMode.markers);
      expect(note('الحاشية الأولى'), findsOneWidget);
      expect(note('الحاشية الثانية'), findsOneWidget);

      final lastParagraph = tester.getRect(find.byType(SelectableText).last);
      final firstNote = tester.getRect(note('الحاشية الأولى'));
      expect(firstNote.top, greaterThanOrEqualTo(lastParagraph.bottom),
          reason: 'a printed book sets its apparatus below its text');

      // The page handed the widget one note per id, so a repeated marker
      // prints its note once, like a real page.
      expect(noteRows(tester), 2);
    });

    testWidgets('the notes stay open when the in-text markers are off',
        (tester) async {
      await pumpWithNotes(tester, mode: BookFootnoteMode.notes);
      expect(note('الحاشية الأولى'), findsOneWidget);
      expect(note('الحاشية الثانية'), findsOneWidget);
    });

    testWidgets('tapping a marker brings its printed note into view',
        (tester) async {
      // A real page: the note sits far below the fold, so nothing but the
      // marker's own tap can bring it into view.
      final body = List.generate(
        40,
        (i) => 'بندٌ من متن الكتاب رقم $i، طويلٌ حتى يملأ الصفحة كلها.',
      ).join('\n');
      await pumpWithNotes(
        tester,
        mode: BookFootnoteMode.markers,
        text: 'قال رسول الله (3).\n$body',
        notes: const [
          BookPageNote(displayNumber: 1, sourceId: '3', text: 'الحاشية'),
        ],
      );

      final start = tester.getRect(note('الحاشية'));
      expect(start.top, greaterThan(720),
          reason: 'the note starts below the visible page');

      // The marker prints the page-local number; the folio may print the same
      // digits, so the underline is what tells them apart.
      final marker = find.byWidgetPredicate((w) =>
          w is Text &&
          w.data == NumberFormat.ltrIsolated('1') &&
          w.style?.decoration == TextDecoration.underline);
      expect(marker, findsOneWidget);

      await tester.tap(marker);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.getRect(note('الحاشية')).top, lessThan(start.top),
          reason: 'the marker must lead the eye to its own note');
    });

    testWidgets('a marker whose note is missing prints no orphan',
        (tester) async {
      await pumpWithNotes(
        tester,
        mode: BookFootnoteMode.markers,
        text: 'قال (3) ثم (9) بلا حاشية.',
        notes: const [
          BookPageNote(displayNumber: 1, sourceId: '3', text: 'الحاشية الوحيدة'),
        ],
      );
      expect(note('الحاشية الوحيدة'), findsOneWidget);
      expect(noteRows(tester), 1,
          reason: 'an unanswered marker must not set a rule over an empty note');
    });
  });
}

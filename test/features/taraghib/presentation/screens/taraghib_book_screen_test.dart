import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/taraghib/presentation/screens/taraghib_book_screen.dart';
import 'package:tawheeed/features/taraghib/presentation/screens/taraghib_chapter_screen.dart';
import 'package:tawheeed/shared/widgets/inline_footnotes.dart';
import 'package:tawheeed/features/taraghib/services/taraghib_service.dart';

/// Drives the book page's chapter list without a real database.
class _FakeBookService extends TaraghibService {
  _FakeBookService({
    this.chapters = const <Map<String, dynamic>>[],
    this.counts = const <num, int>{},
    this.footnotes = const <Map<String, dynamic>>[],
    this.preambles = const <Map<String, dynamic>>[],
    this.failOpenTimes = 0,
  });

  final List<Map<String, dynamic>> chapters;
  final Map<num, int> counts;
  final List<Map<String, dynamic>> footnotes;
  final List<Map<String, dynamic>> preambles;
  final int failOpenTimes;
  int openCalls = 0;

  @override
  Future<void> ensureReady() async {
    openCalls++;
    if (openCalls <= failOpenTimes) {
      throw Exception('book locked');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> chaptersForBook(int bookId) async =>
      chapters;

  @override
  Future<Map<num, int>> hadithCountsPerChapter(int bookId) async => counts;

  @override
  Future<List<Map<String, dynamic>>> footnotesOfBook(int bookId) async =>
      footnotes;

  @override
  Future<List<Map<String, dynamic>>> preamblesOfBook(int bookId) async =>
      preambles;
}

const Map<String, dynamic> _book = {
  'id': 7,
  'book_no': 7,
  'title_arabic': 'كتاب العلم',
  'title_persian': 'کتاب العلم',
  'title_english': null,
  'hadith_count': 3,
  'chapter_count': 2,
  'volume': 1,
};

const List<Map<String, dynamic>> _chapters = [
  {
    'id': 71,
    'book_id': 7,
    'chapter_index': 1.0,
    'printed_number': 1,
    'name_arabic': 'باب فضل العلم',
    'name_persian': 'باب فضیلت علم',
    'note': null,
  },
  {
    'id': 72,
    'book_id': 7,
    'chapter_index': 2.0,
    'printed_number': null,
    'name_arabic': 'باب طلب العلم',
    'name_persian': 'باب جستن علم',
    'note': 'این باب در نسخهٔ چاپی عنوان دارد، اما حدیثی زیر آن نیامده است.',
  },
];

Future<void> pumpBook(
  WidgetTester tester,
  Map<String, dynamic> book,
  TaraghibService service,
) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
      MaterialApp(home: TaraghibBookScreen(book: book, service: service)));
  await tester.pumpAndSettle();
}

/// Footnote bodies are `SelectableText`, so a plain `find.text` is not the
/// finder to reach for; this one names the widget it expects.
Finder _note(String text) => find.byWidgetPredicate(
      (w) => w is SelectableText && (w.data ?? '').trim() == text,
      description: 'SelectableText("$text")',
    );

void main() {
  testWidgets('the book page lists its chapters with the printed numerals',
      (tester) async {
    final fake = _FakeBookService(
      chapters: _chapters,
      counts: {1.0: 3, 2.0: 0},
    );
    await pumpBook(tester, _book, fake);

    expect(find.text('کتاب 7'), findsOneWidget);
    expect(find.text('2 باب · 3 حدیث'), findsOneWidget);
    expect(find.text('کتاب العلم'), findsOneWidget);

    expect(find.text('باب فضیلت علم'), findsOneWidget);
    expect(find.text('3 حدیث'), findsOneWidget);
    // The printed numeral is the badge.
    expect(find.text('1'), findsOneWidget);

    // بابی که شمارهٔ چاپی ندارد، شمارهٔ ترتیبی خود را نشان می‌دهد.
    expect(find.text('باب جستن علم'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    // A chapter the edition prints without hadiths says so, and names the
    // publisher's note instead of inventing content.
    expect(find.text('یادداشت ناشر'), findsOneWidget);
    expect(find.text('بدون حدیث'), findsOneWidget);
  });

  testWidgets('a chapter row opens that chapter inside its own book',
      (tester) async {
    final fake = _FakeBookService(
      chapters: _chapters,
      counts: {1.0: 3, 2.0: 0},
    );
    await pumpBook(tester, _book, fake);

    await tester.tap(find.text('باب فضیلت علم'));
    // The pushed page spins on its real (downloaded-book) service, so settle
    // is unreachable here — pump the route transition instead.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final chapter = tester
        .widget<TaraghibChapterScreen>(find.byType(TaraghibChapterScreen));
    expect(chapter.bookId, 7);
    expect(chapter.bookTitle, 'کتاب العلم');
    expect(chapter.chapterIndex, 1.0);
    // The chapter is handed over by its Arabic heading, as the edition prints
    // it — that is the title every other surface already carries.
    expect(chapter.chapterTitle, 'باب فضل العلم');
  });

  testWidgets('the divider book is titled without a numeral', (tester) async {
    final fake = _FakeBookService(
      chapters: const [
        {
          'id': 91,
          'book_id': 27,
          'chapter_index': 1.0,
          'printed_number': 1,
          'name_arabic': 'باب صفة الجنة',
          'name_persian': 'باب وصف بهشت',
          'note': null,
        },
      ],
      counts: {1.0: 5},
    );
    await pumpBook(
      tester,
      const {
        'id': 27,
        'book_no': null,
        'title_arabic': 'كتاب توصيف بهشت و جهنم',
        'title_persian': 'کتاب وصف بهشت و جهنم',
        'hadith_count': 5,
        'chapter_count': 1,
      },
      fake,
    );

    // The edition prints this book without a number — the page must not
    // borrow the next book's numeral to fill the gap.
    expect(find.text('کتاب'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) =>
          w is Text &&
          w.data != null &&
          RegExp(r'^کتاب \d+$').hasMatch(w.data!)),
      findsNothing,
    );
    expect(find.text('1 باب · 5 حدیث'), findsOneWidget);
    expect(find.text('کتاب وصف بهشت و جهنم'), findsOneWidget);
  });

  testWidgets('a failed load names itself, and a retry re-reads the book',
      (tester) async {
    final fake = _FakeBookService(
      chapters: _chapters,
      counts: {1.0: 3, 2.0: 0},
      failOpenTimes: 1,
    );
    await pumpBook(tester, _book, fake);

    expect(find.byKey(const ValueKey('failure_taraghib_book_load')),
        findsOneWidget);
    expect(find.text('فهرست باب‌های این کتاب باز نشد'), findsOneWidget);
    expect(find.text('باب فضیلت علم'), findsNothing);
    expect(fake.openCalls, 1);

    await tester.tap(find.text('تلاش دوباره'));
    await tester.pumpAndSettle();

    expect(fake.openCalls, 2);
    expect(find.text('فهرست باب‌های این کتاب باز نشد.'), findsNothing);
    expect(find.text('باب فضیلت علم'), findsOneWidget);
  });

  testWidgets('a book with no chapters says so', (tester) async {
    final fake = _FakeBookService();
    await pumpBook(tester, _book, fake);

    expect(find.text('بابی برای این کتاب ثبت نشده است.'), findsOneWidget);
    // With no chapters there is nothing to count, so no subtitle is printed.
    expect(find.textContaining('باب ·'), findsNothing);
  });

  testWidgets('the book heading note and its publisher notice print above the chapters',
      (tester) async {
    final fake = _FakeBookService(
      chapters: _chapters,
      counts: {1.0: 3, 2.0: 0},
      footnotes: const [
        {'text': 'حاشیهٔ عنوان کتاب', 'preamble_id': null, 'sort_order': 1},
        {'text': 'حاشیهٔ یادداشت ناشر', 'preamble_id': 49, 'sort_order': 2},
        // A blank body is not a note; it must not take a number.
        {'text': '   ', 'preamble_id': 49, 'sort_order': 3},
        // A note whose preamble is not in this book is attached to nothing.
        {'text': 'حاشیهٔ یتیم', 'preamble_id': 999, 'sort_order': 4},
      ],
      preambles: const [
        {'id': 49, 'arabic': 'یادداشت ناشر برای این کتاب'},
      ],
    );
    await pumpBook(tester, _book, fake);

    final headingNote = tester.getTopLeft(_note('حاشیهٔ عنوان کتاب')).dy;
    final notice = tester.getTopLeft(find.text('یادداشت ناشر برای این کتاب')).dy;
    final noticeNote = tester.getTopLeft(_note('حاشیهٔ یادداشت ناشر')).dy;
    final firstChapter = tester.getTopLeft(find.text('باب فضیلت علم')).dy;

    expect(headingNote, lessThan(notice));
    expect(notice, lessThan(noticeNote));
    expect(noticeNote, lessThan(firstChapter));
    expect(_note('حاشیهٔ یتیم'), findsNothing);

    // The print edition restarts the counter on every page, so each owner
    // block numbers its own notes from 1 — the chapter badge's own «1» is
    // outside these blocks and is not counted here.
    expect(
      find.descendant(
          of: find.byType(InlineFootnotes), matching: find.text('1')),
      findsNWidgets(2),
    );
    expect(
      find.descendant(
          of: find.byType(InlineFootnotes), matching: find.text('2')),
      findsNothing,
    );
  });

  testWidgets('a book with no printed matter floats nothing above its chapters',
      (tester) async {
    final fake = _FakeBookService(
      chapters: _chapters,
      counts: {1.0: 3, 2.0: 0},
    );
    await pumpBook(tester, _book, fake);

    // The other twenty books carry no heading note and no publisher
    // preamble; they must stay pixel-identical to the pre-footnote page.
    expect(find.byType(InlineFootnotes), findsNothing);
    expect(find.byType(PublisherNotice), findsNothing);
  });
}

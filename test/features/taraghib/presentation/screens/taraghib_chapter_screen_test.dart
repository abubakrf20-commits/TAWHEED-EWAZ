import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/taraghib/presentation/screens/taraghib_chapter_screen.dart';
import 'package:tawheeed/shared/widgets/inline_footnotes.dart';
import 'package:tawheeed/features/taraghib/services/taraghib_service.dart';

class _FakeChapterService extends TaraghibService {
  _FakeChapterService({
    this.chapter,
    this.entries = const <Map<String, dynamic>>[],
    this.footnotes = const <Map<String, dynamic>>[],
    this.preambles = const <Map<String, dynamic>>[],
  });

  final Map<String, dynamic>? chapter;
  final List<Map<String, dynamic>> entries;
  final List<Map<String, dynamic>> footnotes;
  final List<Map<String, dynamic>> preambles;

  @override
  Future<void> ensureReady() async {}

  @override
  Future<Map<String, dynamic>?> chapterOf(int bookId, num chapterIndex) async =>
      chapter;

  @override
  Future<List<Map<String, dynamic>>> entriesOfChapter(
          int bookId, num chapterIndex) async =>
      entries;

  @override
  Future<List<Map<String, dynamic>>> footnotesOfChapter(int chapterId) async =>
      footnotes;

  @override
  Future<List<Map<String, dynamic>>> preamblesOfChapter(int chapterId) async =>
      preambles;
}

const _chapterTitle = 'باب فضیلت علم';

const _chapter = <String, dynamic>{'id': 501};

const _entries = <Map<String, dynamic>>[
  {
    'id': 9001,
    'hadith_number': 1,
    'arabic': 'متن حدیث نخست این باب.',
  },
  {
    'id': 9002,
    'hadith_number': 2,
    'arabic': 'متن حدیث دوم این باب.',
  },
];

const _footnotes = <Map<String, dynamic>>[
  // No hadith and no preamble: the note printed under the باب heading.
  {'text': 'حاشیهٔ عنوان باب', 'hadith_id': null, 'preamble_id': null,
    'sort_order': 1},
  {'text': 'حاشیهٔ حدیث نخست', 'hadith_id': 9001, 'preamble_id': null,
    'sort_order': 2},
  {'text': 'حاشیهٔ یادداشت ناشر', 'hadith_id': null, 'preamble_id': 77,
    'sort_order': 3},
  // A blank body is not a note; it must not take a number.
  {'text': '   ', 'hadith_id': 9001, 'preamble_id': null, 'sort_order': 4},
  // A note whose hadith is not in this chapter is attached to nothing.
  {'text': 'حاشیهٔ یتیم', 'hadith_id': 9999, 'preamble_id': null,
    'sort_order': 5},
];

const _preambles = <Map<String, dynamic>>[
  {'id': 77, 'arabic': 'یادداشت ناشر این باب'},
];

/// One hadith set on three lines, with the print edition's notes anchored to
/// the line each of them is set against.
const _anchoredEntries = <Map<String, dynamic>>[
  {
    'id': 9100,
    'hadith_number': 1,
    'arabic': 'سطر نخست این حدیث\nسطر دوم این حدیث\nسطر سوم این حدیث',
  },
];

const _anchoredFootnotes = <Map<String, dynamic>>[
  {'text': 'حاشیهٔ سطر نخست', 'hadith_id': 9100, 'preamble_id': null,
    'anchor_line': 0, 'sort_order': 1},
  {'text': 'حاشیهٔ نخست سطر سوم', 'hadith_id': 9100, 'preamble_id': null,
    'anchor_line': 2, 'sort_order': 2},
  {'text': 'حاشیهٔ دوم سطر سوم', 'hadith_id': 9100, 'preamble_id': null,
    'anchor_line': 2, 'sort_order': 3},
  // An anchor past the last line marks nothing, but the note still prints.
  {'text': 'حاشیهٔ بیرون از متن', 'hadith_id': 9100, 'preamble_id': null,
    'anchor_line': 99, 'sort_order': 4},
];

Future<void> pumpChapter(
  WidgetTester tester,
  TaraghibService service, {
  String chapterTitle = _chapterTitle,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  tester.view.physicalSize = const Size(1080, 4800);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: TaraghibChapterScreen(
      bookId: 7,
      bookTitle: 'کتاب العلم',
      chapterIndex: 1,
      chapterTitle: chapterTitle,
      initialHadithNumber: 1,
      service: service,
    ),
  ));
  await tester.pumpAndSettle();
  // Let the position listener's 700ms save debounce fire, then settle the
  // frame its setState may schedule.
  await tester.pump(const Duration(milliseconds: 800));
  await tester.pumpAndSettle();
}

/// Footnote bodies are `SelectableText`, so a plain `find.text` is not the
/// finder to reach for; this one names the widget it expects.
Finder _note(String text) => find.byWidgetPredicate(
      (w) => w is SelectableText && (w.data ?? '').trim() == text,
      description: 'SelectableText("$text")',
    );

void main() {
  testWidgets('every note prints under its own host, in reading order',
      (tester) async {
    final fake = _FakeChapterService(
      chapter: _chapter,
      entries: _entries,
      footnotes: _footnotes,
      preambles: _preambles,
    );
    await pumpChapter(tester, fake);

    expect(find.text('باب 1'), findsOneWidget);

    final headingNote = tester.getTopLeft(_note('حاشیهٔ عنوان باب')).dy;
    final notice = tester.getTopLeft(find.text('یادداشت ناشر این باب')).dy;
    final noticeNote = tester.getTopLeft(_note('حاشیهٔ یادداشت ناشر')).dy;
    final firstHadith =
        tester.getTopLeft(_note('متن حدیث نخست این باب.')).dy;
    final firstHadithNote = tester.getTopLeft(_note('حاشیهٔ حدیث نخست')).dy;
    final secondHadith =
        tester.getTopLeft(_note('متن حدیث دوم این باب.')).dy;

    // Heading note, then the publisher's notice with its own note, then each
    // hadith with its note directly beneath it — never a list at the end.
    expect(headingNote, lessThan(notice));
    expect(notice, lessThan(noticeNote));
    expect(noticeNote, lessThan(firstHadith));
    expect(firstHadith, lessThan(firstHadithNote));
    expect(firstHadithNote, lessThan(secondHadith));

    // Three owner blocks, each restarting its own counter at 1: the blank
    // note is not counted and the orphan belongs to no block.
    expect(find.byType(InlineFootnotes), findsNWidgets(3));
    expect(
      find.descendant(
          of: find.byType(InlineFootnotes), matching: find.text('1')),
      findsNWidgets(3),
    );
    expect(
      find.descendant(
          of: find.byType(InlineFootnotes), matching: find.text('2')),
      findsNothing,
    );
    expect(_note('حاشیهٔ یتیم'), findsNothing);
  });

  testWidgets('a chapter with no printed notes floats nothing', (tester) async {
    final fake = _FakeChapterService(chapter: _chapter, entries: _entries);
    await pumpChapter(tester, fake);

    // The 20 books whose chapters carry no notes must stay identical to the
    // pre-footnote page — no empty rule, no stray number.
    expect(find.byType(InlineFootnotes), findsNothing);
    expect(find.byType(PublisherNotice), findsNothing);
    expect(_note('متن حدیث نخست این باب.'), findsOneWidget);
    expect(_note('متن حدیث دوم این باب.'), findsOneWidget);
  });

  testWidgets('a hadith-less chapter keeps the publisher note in place',
      (tester) async {
    final fake = _FakeChapterService(
      chapter: const {
        'id': 502,
        'note': 'این باب در نسخهٔ چاپی حدیثی ندارد.',
        'note_arabic': 'لا حدیث فی هذا الباب.',
      },
      footnotes: const [
        {'text': 'حاشیهٔ عنوان باب', 'hadith_id': null, 'preamble_id': null,
          'sort_order': 1},
        {'text': 'حاشیهٔ یادداشت ناشر', 'hadith_id': null, 'preamble_id': 77,
          'sort_order': 2},
      ],
      preambles: _preambles,
    );
    await pumpChapter(tester, fake);

    expect(find.text('یادداشت ناشر'), findsOneWidget);
    expect(_note('لا حدیث فی هذا الباب.'), findsOneWidget);
    expect(_note('این باب در نسخهٔ چاپی حدیثی ندارد.'), findsOneWidget);
    expect(
        find.text(
            'در نسخهٔ چاپی این باب حدیثی ندارد و یادداشت بالا در همان‌جا آمده است.'),
        findsOneWidget);

    // The heading block still owns its note and the publisher's note above
    // the explanation of the printing edition.
    final headingNote = tester.getTopLeft(_note('حاشیهٔ عنوان باب')).dy;
    final notice = tester.getTopLeft(find.text('یادداشت ناشر این باب')).dy;
    final noticeNote = tester.getTopLeft(_note('حاشیهٔ یادداشت ناشر')).dy;
    final emptyNote = tester.getTopLeft(_note('این باب در نسخهٔ چاپی حدیثی ندارد.')).dy;

    expect(headingNote, lessThan(notice));
    expect(notice, lessThan(noticeNote));
    expect(noticeNote, lessThan(emptyNote));
  });

  testWidgets('a 320 dp phone at a large text scale keeps every card in bounds',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(640, 1600); // 320 dp at 2×
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.4)),
        child: child!,
      ),
      home: TaraghibChapterScreen(
        bookId: 7,
        bookTitle: 'كتاب العلم',
        chapterIndex: 1,
        chapterTitle: _chapterTitle,
        initialHadithNumber: 1,
        service: _FakeChapterService(chapter: _chapter, entries: _entries),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    // The badge and «در حال مطالعه» used to push the copy/share buttons off the
    // card here, and the jump bar's fixed 46 px clipped its chips.
    expect(tester.takeException(), isNull);
  });

  testWidgets('each printed note wears its number inside the hadith text',
      (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    final fake = _FakeChapterService(
      chapter: _chapter,
      entries: _anchoredEntries,
      footnotes: _anchoredFootnotes,
    );
    await pumpChapter(tester, fake);

    // The body is the only rich `SelectableText` on the page; the notes below
    // it are plain `data` strings.
    final body = tester.widget<SelectableText>(find.byWidgetPredicate(
        (w) => w is SelectableText && w.textSpan != null,
        description: 'the hadith body'));

    // Each number is glued to the last word of the line its note is anchored
    // to, and two notes sharing one line share that spot.
    expect(
        body.textSpan!.toPlainText(),
        'سطر نخست این حدیث1\n'
        'سطر دوم این حدیث\n'
        'سطر سوم این حدیث2,3');

    // Every note still prints below, numbering from 1 — including the one whose
    // anchor runs past the last line, which marks nothing above.
    expect(find.byType(InlineFootnotes), findsOneWidget);
    expect(_note('حاشیهٔ بیرون از متن'), findsOneWidget);
    for (final number in ['1', '2', '3', '4']) {
      expect(
          find.descendant(
              of: find.byType(InlineFootnotes), matching: find.text(number)),
          findsOneWidget);
    }

    // Copy hands over the print edition's own text: the markers live on screen
    // only and must never reach the clipboard.
    await tester.tap(find.byTooltip('کپی متن'));
    await tester.pump();
    final set = calls
        .firstWhere((c) => c.method == 'Clipboard.setData')
        .arguments as Map<Object?, Object?>;
    expect(
        set['text'], 'سطر نخست این حدیث\nسطر دوم این حدیث\nسطر سوم این حدیث');
    // Drain the copy SnackBar's timer before the test ends.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/hadith/services/part_books.dart';
import 'package:tawheeed/features/riyad/presentation/screens/riyad_book_screen.dart';
import 'package:tawheeed/features/riyad/presentation/screens/riyad_chapter_screen.dart';
import 'package:tawheeed/features/riyad/presentation/screens/riyad_intro_screen.dart';
import 'package:tawheeed/features/riyad/presentation/screens/riyad_screen.dart';
import 'package:tawheeed/features/riyad/services/riyad_service.dart';
import 'package:tawheeed/shared/services/content_download_service.dart'
    show DownloadProgress;

/// What the four Riyad screens promise beyond reading the text.
///
/// 1. **They fit.** 320 dp is the narrowest phone the app supports and 1.3× is
///    the scale its accessibility pass uses. The باب badge printed its
///    `chapter_index` as a double («84.0»), and the entry card's badge row had
///    no flexible child, so a large scale pushed copy/share off the card.
/// 2. **A query is a match set.** As soon as a text search answered, the title
///    filter was dropped and the body fell back to *every* chapter — 372 rows of
///    the book under the hits, labelled «باب‌هایی با این عنوان یافت نشد».
/// 3. **An answer belongs to the query that asked for it.** A slow read could
///    land after the field moved on and paint the previous word's rows.
/// 4. **A failed search is said out loud** — and the title matches stay.
/// 5. **A failed download is a sentence**, not a `SocketException` dump.
class _FakeRiyad extends RiyadService {
  _FakeRiyad({
    this.available = true,
    this.downloadFails = false,
    this.searchFails = false,
    this.gateQuery,
  });

  final bool available;
  final bool downloadFails;
  final bool searchFails;

  /// The query whose answer is held until [gate] completes — the race test's
  /// slow read.
  final String? gateQuery;
  final Completer<void> gate = Completer<void>();
  final List<String> queries = [];

  static Map<String, dynamic> _chapter(
          int id, double index, String name, String? part) =>
      {
        'id': id,
        'book_id': RiyadService.bookId,
        'chapter_index': index,
        'printed_number': index.toInt(),
        'name_arabic': name,
        'part': part,
      };

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> needsUpdate() async => false;

  @override
  Future<void> ensureReady() async {}

  @override
  Future<void> download({DownloadProgress? onProgress}) async {
    if (downloadFails) {
      throw const SocketException('Failed host lookup: tawheeed.test');
    }
    onProgress?.call(100, 100);
  }

  @override
  Future<List<Map<String, dynamic>>> chapters() async => [
        _chapter(1, 1, 'باب الإخلاص', null),
        _chapter(2, 84, 'باب الحياء', 'کتاب 1: ادب'),
      ];

  @override
  Future<Map<num, int>> hadithCountsPerChapter() async =>
      {1.0: 3, 84.0: 2};

  @override
  Future<int> totalEntries() async => 5;

  @override
  Future<List<Map<String, dynamic>>> matterSections() async => const [
        {'id': 1, 'title': 'درآمدی بر کتاب', 'volume': 1},
      ];

  @override
  Future<Map<String, dynamic>?> chapterOf(num chapterIndex) async =>
      _chapter(2, 84, 'باب الحياء', 'کتاب 1: ادب');

  @override
  Future<List<Map<String, dynamic>>> entriesOfChapter(num chapterIndex) async =>
      [
        {
          'id': 501,
          'book_id': RiyadService.bookId,
          'chapter_id': 2,
          'hadith_number': 1897,
          'arabic': 'الحَيَاءُ شُعْبَةٌ مِنَ الإِيمَانِ\n'
              'ترجمه: حیا شاخه‌ای از ایمان است که پیامبر صلی الله علیه وسلم '
              'در روایتی طولانی آن را برای اصحابش شرح داده است.',
        },
      ];

  @override
  Future<List<Map<String, dynamic>>> footnotesOfChapter(int chapterId) async =>
      const [
        {
          'id': 1,
          'footnote_no': '12',
          'text': 'صحیح مسلم، ش: 2560',
          'hadith_id': 501,
          'anchor_line': 0,
        },
      ];

  @override
  Future<List<Map<String, dynamic>>> preamblesOfChapter(int chapterId) async =>
      const [];

  @override
  Future<Map<int, int>> matterParagraphCounts() async => const {1: 1};

  @override
  Future<List<Map<String, dynamic>>> matterParagraphs(int sectionId) async =>
      const [
        {
          'id': 1,
          'section_id': 1,
          'para_order': 1,
          'arabic': 'کتاب «ریاض الصالحین» از امهات کتب حدیث است.',
        },
      ];

  @override
  Future<List<Map<String, dynamic>>> footnotesOfSection(int sectionId) async =>
      const [];

  @override
  Future<List<Map<String, dynamic>>> search(String query,
      {int limit = RiyadService.searchLimit}) async {
    queries.add(query);
    if (searchFails) throw StateError('database unavailable');
    if (query == gateQuery) await gate.future;
    return [
      {
        'id': query == gateQuery ? 900 : 901,
        'book_id': RiyadService.bookId,
        'chapter_id': 1,
        'hadith_number': 1,
        'arabic': 'نص ${query.trim()}',
      },
    ];
  }

  @override
  Future<int> maxHadithNumber() async => 1897;
}

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  double width = 320,
  double scale = 1.3,
}) async {
  tester.view.physicalSize = Size(width * 3, 1400 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final errors = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = errors.add;
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme(),
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(width, 1400),
        textScaler: TextScaler.linear(scale),
      ),
      child: Directionality(textDirection: TextDirection.rtl, child: screen),
    ),
  ));
  await tester.pump();
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
  FlutterError.onError = previous;
  tester.takeException();
  expect(errors, isEmpty, reason: errors.map((e) => e.toString()).join('\n---\n'));
}

/// Types into the search field and lets the 400 ms debounce and the read that
/// follows it finish.
Future<void> _search(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField), query);
  await tester.pump(const Duration(milliseconds: 450));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _openReader(WidgetTester tester, _FakeRiyad fake) async {
  await _pump(tester, RiyadScreen(service: fake));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('at 320 dp with the text at 1.3×', () {
    testWidgets('the فهرست, a کتاب, a باب and the مقدمه‌ها all fit',
        (tester) async {
      final fake = _FakeRiyad();
      await _openReader(tester, fake);
      expect(find.text('کتاب‌ها (2)'), findsOneWidget);

      final book = partBooksOf(await fake.chapters()).last;
      await _pump(
        tester,
        RiyadBookScreen(book: book, hadithCounts: {84.0: 2}),
      );
      expect(find.text('باب الحياء'), findsOneWidget);

      await _pump(
        tester,
        RiyadChapterScreen(
          chapterIndex: 84,
          chapterTitle: 'باب الحياء',
          service: fake,
        ),
      );
      expect(find.textContaining('الحَيَاءُ'), findsWidgets);

      await _pump(
        tester,
        RiyadIntroScreen(
          sections: const [
            {'id': 1, 'title': 'درآمدی بر کتاب'},
          ],
          service: fake,
        ),
      );
      expect(find.text('درآمدی بر کتاب'), findsOneWidget);
    });
  });

  testWidgets('a باب with no part prints 84, not 84.0', (tester) async {
    final fake = _FakeRiyad();
    final book = partBooksOf(await fake.chapters()).last;

    await _pump(
      tester,
      RiyadBookScreen(book: book, hadithCounts: {84.0: 2}),
    );

    expect(find.text('84'), findsOneWidget);
    expect(find.text('84.0'), findsNothing);
  });

  testWidgets('a title match survives the text search', (tester) async {
    final fake = _FakeRiyad();
    await _openReader(tester, fake);

    await _search(tester, 'الحياء');
    await tester.pump(const Duration(milliseconds: 100));

    // The text hit is listed, and the باب with the same title is still there.
    expect(find.text('نتایج متن (1)'), findsOneWidget);
    expect(find.text('باب‌های هم‌نام (1)'), findsOneWidget);
    expect(find.text('باب الحياء'), findsOneWidget);
    // A query is a match set: the book's other باب must not be listed below it
    // (the whole 372-row list used to be painted here).
    expect(find.text('باب الإخلاص'), findsNothing);
  });

  testWidgets('an answer for an older query never paints under the new one',
      (tester) async {
    final fake = _FakeRiyad(gateQuery: 'قديم');
    await _openReader(tester, fake);

    await tester.enterText(find.byType(TextField), 'قديم');
    await tester.pump(const Duration(milliseconds: 450));
    // The first read is held; type over it before it answers.
    await tester.enterText(find.byType(TextField), 'جديد');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();
    expect(find.textContaining('نص جديد'), findsOneWidget);

    fake.gate.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('نص جديد'), findsOneWidget);
    expect(find.textContaining('نص قديم'), findsNothing);
  });

  testWidgets('a failed search says so and keeps the title matches',
      (tester) async {
    final fake = _FakeRiyad(searchFails: true);
    await _openReader(tester, fake);

    await _search(tester, 'الإخلاص');
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('جست‌وجو انجام نشد'), findsOneWidget);
    expect(find.text('باب الإخلاص'), findsOneWidget);
    expect(find.textContaining('نتایج متن'), findsNothing);
  });

  testWidgets('a failed download is a sentence, not an exception',
      (tester) async {
    final fake = _FakeRiyad(available: false, downloadFails: true);
    await _openReader(tester, fake);

    await tester.tap(find.text('دانلود محتوا'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('دانلود کامل نشد'), findsOneWidget);
    expect(find.textContaining('SocketException'), findsNothing);
    expect(find.textContaining('Failed host lookup'), findsNothing);
  });
}

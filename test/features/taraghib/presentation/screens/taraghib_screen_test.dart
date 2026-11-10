import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/taraghib/presentation/screens/taraghib_book_screen.dart';
import 'package:tawheeed/features/taraghib/presentation/screens/taraghib_chapter_screen.dart';
import 'package:tawheeed/features/taraghib/presentation/screens/taraghib_screen.dart';
import 'package:tawheeed/features/taraghib/services/taraghib_service.dart';
import 'package:tawheeed/shared/services/content_download_service.dart'
    show DownloadProgress;

typedef _ChapterLocation = ({int bookId, num chapterIndex});

/// Drives every branch of the screen's update/download/open flow without a
/// real database, network or file system.
class _FakeTaraghibService extends TaraghibService {
  _FakeTaraghibService({
    required this.available,
    this.needsUpdateValue = false,
    this.failEnsureReadyTimes = 0,
    this.failDownloadTimes = 0,
    this.jumpMax = 0,
    this.jumpLocations = const <int, _ChapterLocation>{},
    this.searchRows = const <Map<String, dynamic>>[],
  });

  final bool available;
  final bool needsUpdateValue;
  final int failEnsureReadyTimes;
  final int failDownloadTimes;
  final int jumpMax;
  final Map<int, _ChapterLocation> jumpLocations;
  final List<Map<String, dynamic>> searchRows;
  int ensureReadyCalls = 0;
  int downloadCalls = 0;
  int searchCalls = 0;
  String? lastSearchQuery;
  int? lastSearchLimit;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> needsUpdate() async => needsUpdateValue;

  @override
  Future<void> ensureReady() async {
    ensureReadyCalls++;
    if (ensureReadyCalls <= failEnsureReadyTimes) {
      throw Exception('open failed');
    }
  }

  @override
  Future<void> download({DownloadProgress? onProgress}) async {
    downloadCalls++;
    if (downloadCalls <= failDownloadTimes) {
      throw Exception('network down');
    }
    onProgress?.call(100, 100);
  }

  @override
  Future<List<Map<String, dynamic>>> books() async =>
      const <Map<String, dynamic>>[
        {
          'id': 1,
          'book_no': 1,
          'title_arabic': 'كتاب الإخلاص',
          'title_persian': 'کتاب اخلاص',
          'title_english': null,
          'hadith_count': 2,
          'chapter_count': 2,
          'volume': 1,
        },
        {
          'id': 2,
          'book_no': null,
          'title_arabic': 'كتاب توصيف بهشت و جهنم',
          'title_persian': null,
          'title_english': null,
          'hadith_count': 5,
          'chapter_count': 1,
          'volume': 1,
        },
      ];

  @override
  Future<List<Map<String, dynamic>>> allChapters() async =>
      const <Map<String, dynamic>>[
        {
          'id': 11,
          'book_id': 1,
          'chapter_index': 1.0,
          'printed_number': 1,
          'name_arabic': 'باب الإخلاص',
          'name_persian': 'باب اخلاص',
          'note': null,
        },
        {
          'id': 12,
          'book_id': 1,
          'chapter_index': 2.0,
          'printed_number': null,
          'name_arabic': 'باب الصدق',
          'name_persian': 'باب راست‌گویی',
          'note': null,
        },
        {
          'id': 13,
          'book_id': 2,
          'chapter_index': 1.0,
          'printed_number': 1,
          'name_arabic': 'باب صفة الجنة',
          'name_persian': null,
          'note': null,
        },
      ];

  @override
  Future<List<Map<String, dynamic>>> chaptersForBook(int bookId) async =>
      (await allChapters())
          .where((c) => (c['book_id'] as num).toInt() == bookId)
          .toList();

  @override
  Future<Map<num, int>> hadithCountsPerChapter(int bookId) async =>
      bookId == 1 ? {1.0: 2, 2.0: 0} : {1.0: 5};

  @override
  Future<List<Map<String, dynamic>>> matterSections() async =>
      const <Map<String, dynamic>>[
        {'id': 21, 'kind': 'intro', 'title': 'مقدمهٔ کتاب', 'sort_order': 1},
        {'id': 22, 'kind': 'khatimah', 'title': 'خاتمه', 'sort_order': 2},
      ];

  @override
  Future<Map<int, int>> matterParagraphCounts() async =>
      const {21: 12, 22: 4};

  @override
  Future<int> totalHadiths() async => 3775;

  @override
  Future<int> maxHadithNumber() async => jumpMax;

  @override
  Future<({int bookId, num chapterIndex, int number})?> locateHadithNumber(
      int number) async {
    final chapter = jumpLocations[number];
    if (chapter == null) return null;
    return (
      bookId: chapter.bookId,
      chapterIndex: chapter.chapterIndex,
      number: number,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> search(String query,
      {int limit = 30}) async {
    searchCalls++;
    lastSearchQuery = query;
    lastSearchLimit = limit;
    return searchRows;
  }
}

Future<void> pumpTaraghib(WidgetTester tester, TaraghibService service) async {
  // The browse list is a builder — a real phone viewport is tall enough to
  // build every row this suite asserts on.
  tester.view.physicalSize = const Size(1080, 4800);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: TaraghibScreen(service: service)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an installed revision-1 copy is updated before it is opened',
      (tester) async {
    // The reported defect: 2,698 was the old copy's count. Opening it would
    // show the same wrong numbers, so the update gate runs first.
    final fake = _FakeTaraghibService(available: true, needsUpdateValue: true);
    await pumpTaraghib(tester, fake);

    expect(find.text('به‌روزرسانی صحیح الترغیب'), findsOneWidget);
    expect(find.text('به‌روزرسانی محتوا'), findsOneWidget);
    expect(
        find.textContaining('نسخهٔ روی این دستگاه قدیمی است'), findsOneWidget);
    expect(
        find.textContaining('29 کتاب · 428 باب · 3775 حدیث'), findsOneWidget);
    expect(fake.ensureReadyCalls, 0);
    expect(find.byTooltip('پرش به شماره حدیث'), findsNothing);
  });

  testWidgets('a download that succeeds retries the open and shows content',
      (tester) async {
    // The copy lands on disk, one transient step fails, and the screen used to
    // claim «دانلود ناموفق بود» even though re-entering opened it. The open is
    // retried once before any message appears.
    final fake =
        _FakeTaraghibService(available: false, failEnsureReadyTimes: 1);
    await pumpTaraghib(tester, fake);

    expect(find.text('دانلود محتوا'), findsOneWidget);
    await tester.tap(find.text('دانلود محتوا'));
    await tester.pumpAndSettle();

    expect(fake.downloadCalls, 1);
    expect(fake.ensureReadyCalls, 2); // first attempt failed, retry opened
    expect(find.text('کتاب‌ها (2)'), findsOneWidget);
    expect(find.textContaining('ناموفق'), findsNothing);
    expect(find.textContaining('دوباره وارد شوید'), findsNothing);
  });

  testWidgets('a downloaded copy that will not open asks the user to re-enter',
      (tester) async {
    final fake =
        _FakeTaraghibService(available: false, failEnsureReadyTimes: 99);
    await pumpTaraghib(tester, fake);

    await tester.tap(find.text('دانلود محتوا'));
    await tester.pumpAndSettle();

    expect(fake.downloadCalls, 1);
    expect(fake.ensureReadyCalls, 2); // exactly one retry, then the notice
    expect(find.textContaining('کتاب دانلود شد'), findsOneWidget);
    expect(find.textContaining('دوباره وارد شوید'), findsOneWidget);
    // The download itself succeeded — never reported as a failure.
    expect(find.textContaining('ناموفق'), findsNothing);
  });

  testWidgets('a genuine download failure is still reported, with a retry',
      (tester) async {
    final fake = _FakeTaraghibService(available: false, failDownloadTimes: 1);
    await pumpTaraghib(tester, fake);

    await tester.tap(find.text('دانلود محتوا'));
    await tester.pumpAndSettle();

    // The reader gets a sentence he can act on — never the exception's own
    // text, which used to reach the card as «Exception: network down».
    expect(find.textContaining('دانلود کامل نشد'), findsOneWidget);
    expect(find.textContaining('network down'), findsNothing);
    expect(find.textContaining('Exception'), findsNothing);
    expect(find.textContaining('دوباره وارد شوید'), findsNothing);
    expect(find.text('دانلود محتوا'), findsOneWidget); // button is back
    expect(fake.ensureReadyCalls, 0);
  });

  testWidgets(
      'the ready page carries the edition\'s own attribution and counts',
      (tester) async {
    final fake = _FakeTaraghibService(available: true);
    await pumpTaraghib(tester, fake);

    expect(find.text('صحیح الترغیب و الترهیب'), findsOneWidget);
    expect(
        find.text(
            'علامه منذری · تخریج علامه البانی · ترجمهٔ شیخ موسی بازماندگان'),
        findsOneWidget);
    expect(find.text('2 کتاب'), findsOneWidget);
    expect(find.text('3 باب'), findsOneWidget);
    expect(find.text('3775 حدیث'), findsOneWidget);
    // The old copy's numbers must never appear again.
    expect(find.textContaining('2698'), findsNothing);
    expect(find.textContaining('440 باب'), findsNothing);
    // ریاض الصالحین's شرح line must never appear here.
    expect(find.text('شرح صحیح الترغیب'), findsNothing);
    expect(find.textContaining('العثیمین'), findsNothing);
  });

  testWidgets('the browse page reads مقدمه، کتاب‌ها then خاتمه',
      (tester) async {
    final fake = _FakeTaraghibService(available: true);
    await pumpTaraghib(tester, fake);

    final intro = tester.getTopLeft(find.text('مقدمه')).dy;
    final books = tester.getTopLeft(find.text('کتاب‌ها (2)')).dy;
    final khatimah = tester.getTopLeft(find.text('خاتمه و پایان جلدها')).dy;
    expect(intro, lessThan(books));
    expect(books, lessThan(khatimah));

    // فهرست مطالب is not part of the edition any more — it repeats the book
    // and باب list this very page already prints.
    expect(find.textContaining('فهرست مطالب'), findsNothing);

    // Only the divider book is printed without a numeral, so it is the only
    // row wearing the icon badge (the header tile is a different glyph).
    expect(find.byIcon(Icons.book_outlined), findsOneWidget);

    await tester.tap(find.text('کتاب اخلاص'));
    // The pushed page spins on its real (downloaded-book) service, so settle
    // is unreachable here — pump the route transition instead.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final book =
        tester.widget<TaraghibBookScreen>(find.byType(TaraghibBookScreen));
    expect(book.book['id'], 1);
  });

  testWidgets(
      'the download prompt shows the real book, chapter and hadith counts',
      (tester) async {
    final fake = _FakeTaraghibService(available: false);
    await pumpTaraghib(tester, fake);

    expect(
        find.textContaining('29 کتاب · 428 باب · 3775 حدیث'), findsOneWidget);
    expect(
        find.textContaining('دانلود یک‌باره حدود 2 مگابایت'), findsOneWidget);
    expect(find.textContaining('2698 حدیث'), findsNothing);
    expect(find.textContaining('440 باب'), findsNothing);
    // The jump needs an open book — it must not be offered before that.
    expect(find.byTooltip('پرش به شماره حدیث'), findsNothing);
  });

  testWidgets('the jump dialog opens the chapter at the requested hadith',
      (tester) async {
    final fake = _FakeTaraghibService(
      available: true,
      jumpMax: 3775,
      jumpLocations: const {2: (bookId: 1, chapterIndex: 1.0)},
    );
    await pumpTaraghib(tester, fake);

    await tester.tap(find.byTooltip('پرش به شماره حدیث'));
    await tester.pumpAndSettle();
    expect(find.text('پرش به شماره حدیث'), findsOneWidget);
    expect(find.textContaining('از 1 تا 3775'), findsOneWidget);

    await tester.enterText(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextField)),
        '2');
    await tester.pump();
    await tester.tap(find.text('برو'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final chapter = tester
        .widget<TaraghibChapterScreen>(find.byType(TaraghibChapterScreen));
    expect(chapter.bookId, 1);
    expect(chapter.bookTitle, 'کتاب اخلاص');
    expect(chapter.chapterIndex, 1.0);
    expect(chapter.chapterTitle, 'باب الإخلاص');
    expect(chapter.initialHadithNumber, 2);
  });

  testWidgets('a number this edition does not carry is reported, not opened',
      (tester) async {
    final fake = _FakeTaraghibService(available: true, jumpMax: 3775);
    await pumpTaraghib(tester, fake);

    await tester.tap(find.byTooltip('پرش به شماره حدیث'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextField)),
        '900');
    await tester.pump();
    await tester.tap(find.text('برو'));
    await tester.pumpAndSettle();

    expect(find.byType(TaraghibChapterScreen), findsNothing);
    expect(
        find.text('حدیث شمارهٔ 900 در این نسخه موجود نیست.'), findsOneWidget);
  });

  testWidgets('a title search lists the matching باب under the empty text hits',
      (tester) async {
    final fake = _FakeTaraghibService(available: true);
    await pumpTaraghib(tester, fake);

    await tester.enterText(find.byType(TextField), 'راست‌گویی');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();

    expect(find.text('نتایج متن (0)'), findsOneWidget);
    expect(find.text('در متن احادیث نتیجه‌ای برای این عبارت یافت نشد.'),
        findsOneWidget);
    expect(find.text('کتاب‌ها، باب‌ها و بخش‌های هم‌نام'), findsOneWidget);
    expect(find.text('باب راست‌گویی'), findsOneWidget);
    expect(find.text('کتاب اخلاص'), findsOneWidget); // the chapter's book

    await tester.tap(find.text('باب راست‌گویی'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final chapter = tester
        .widget<TaraghibChapterScreen>(find.byType(TaraghibChapterScreen));
    expect(chapter.bookId, 1);
    expect(chapter.chapterIndex, 2.0);
    expect(chapter.chapterTitle, 'باب الصدق');
  });

  testWidgets('a query that matches nothing says so in both sections',
      (tester) async {
    final fake = _FakeTaraghibService(available: true);
    await pumpTaraghib(tester, fake);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();

    expect(find.text('نتایج متن (0)'), findsOneWidget);
    expect(find.text('در متن احادیث نتیجه‌ای برای این عبارت یافت نشد.'),
        findsOneWidget);
    expect(find.text('کتاب یا بابی با این عنوان یافت نشد.'), findsOneWidget);
  });

  testWidgets('one letter filters titles without reading the whole book',
      (tester) async {
    // A single letter matched almost every narration: thirty hits arrived, the
    // header said «نتایج متن (30)» and the page looked broken.
    final fake = _FakeTaraghibService(available: true);
    await pumpTaraghib(tester, fake);

    await tester.enterText(find.byType(TextField), 'ا');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();

    expect(fake.searchCalls, 0);
    // Nothing was read, so no empty «یافت نشد» line is invented for it: the
    // local title filter answers on its own.
    expect(find.textContaining('نتایج متن'), findsNothing);
    expect(find.text('کتاب‌ها، باب‌ها و بخش‌های هم‌نام'), findsOneWidget);
    expect(find.text('باب اخلاص'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a capped search says it holds only the first results',
      (tester) async {
    final capped = List<Map<String, dynamic>>.generate(
        30, (i) => {'arabic': 'حدیث شمارهٔ ${i + 1}', 'hadith_number': i + 1});
    final fake = _FakeTaraghibService(available: true, searchRows: capped);
    await pumpTaraghib(tester, fake);

    await tester.enterText(find.byType(TextField), 'فضل');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();

    expect(fake.lastSearchQuery, 'فضل');
    expect(fake.lastSearchLimit, TaraghibService.searchLimit);
    // Thirty rows is the cap, not a total — the header must not claim it is.
    expect(find.text('نتایج متن (30 نتیجهٔ نخست)'), findsOneWidget);
  });
}

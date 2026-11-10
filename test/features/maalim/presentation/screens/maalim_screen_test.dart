import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/maalim/presentation/screens/maalim_book_screen.dart';
import 'package:tawheeed/features/maalim/presentation/screens/maalim_chapter_screen.dart';
import 'package:tawheeed/features/maalim/presentation/screens/maalim_matter_screen.dart';
import 'package:tawheeed/features/maalim/presentation/screens/maalim_screen.dart';
import 'package:tawheeed/features/maalim/services/maalim_service.dart';
import 'package:tawheeed/shared/services/content_download_service.dart'
    show DownloadProgress;

/// Drives every branch of the screen's download/open flow without a real
/// database, network or file system.
class _FakeMaalimService extends MaalimService {
  _FakeMaalimService({
    required this.available,
    this.outdated = false,
    this.failEnsureReadyTimes = 0,
    this.failDownloadTimes = 0,
    this.jumpMax = 0,
    this.jumpLocations = const {},
  });

  final bool available;

  /// Whether needsUpdate() answers true — the copy on disk predates the
  /// republished database.
  final bool outdated;
  final int failEnsureReadyTimes;
  final int failDownloadTimes;
  final int jumpMax;
  final Map<int, num> jumpLocations;
  int ensureReadyCalls = 0;
  int downloadCalls = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> needsUpdate() async => outdated;

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

  /// A باب and a فصل-only section in two different مقصد/کتاب/فصل groups, so
  /// both the section headers and the «is this a باب?» badge are observable.
  @override
  Future<List<Map<String, dynamic>>> chapters() async => [
        {
          'id': 1,
          'book_id': 20,
          'chapter_index': 1.0,
          'name_arabic': '«ذکر آدم علیه السلام»',
          'name_english': null,
          'part': 'مقصد هفتم: تاریخ، سیرت ومناقب · کتاب اول: أنبیاء',
          'is_bab': 1,
        },
        {
          'id': 2,
          'book_id': 20,
          'chapter_index': 2.0,
          'name_arabic': '«نسب رسول الله صلی الله علیه وسلم»',
          'name_english': null,
          'part': 'مقصد هفتم: تاریخ، سیرت ومناقب · کتاب دوم: سیرت نبوی شریف · '
              'فصل اول: جاهلیت',
          'is_bab': 0,
        },
      ];

  @override
  Future<Map<num, int>> hadithCountsPerChapter() async => {1.0: 1, 2.0: 2};

  /// The book's front and back matter: three openings and one خاتمه in the
  /// real payload, one of each here.
  @override
  Future<List<Map<String, dynamic>>> matterSections() async => [
        {
          'id': 1,
          'key': 'intro_translator',
          'kind': 'intro',
          'title': 'مقدمه‌ی مترجم',
        },
        {
          'id': 2,
          'key': 'khatimah',
          'kind': 'khatimah',
          'title': 'خاتمه',
        },
      ];

  @override
  Future<List<Map<String, dynamic>>> matterParagraphs(int sectionId) async =>
      [
        {
          'section_id': sectionId,
          'para_order': 1,
          'arabic': 'ستایش از آنِ خداوندِ جهانیان است.',
        },
      ];

  @override
  Future<List<Map<String, dynamic>>> footnotesOfSection(int sectionId) async =>
      const [];

  @override
  Future<List<Map<String, dynamic>>> search(String query,
          {int limit = 30}) async =>
      const [];

  @override
  Future<int> maxHadithNumber() async => jumpMax;

  @override
  Future<(num, int)?> locateHadithNumber(int number) async {
    final chapter = jumpLocations[number];
    return chapter == null ? null : (chapter, number);
  }
}

Future<void> pumpMaalim(WidgetTester tester, MaalimService service) async {
  await tester.pumpWidget(MaterialApp(home: MaalimScreen(service: service)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a download that succeeds retries the open and shows content',
      (tester) async {
    final fake = _FakeMaalimService(available: false, failEnsureReadyTimes: 1);
    await pumpMaalim(tester, fake);

    expect(find.text('دانلود محتوا'), findsOneWidget);
    await tester.tap(find.text('دانلود محتوا'));
    await tester.pumpAndSettle();

    expect(fake.downloadCalls, 1);
    expect(fake.ensureReadyCalls, 2); // first attempt failed, retry opened
    expect(find.text('کتاب‌ها (2)'), findsOneWidget); // content is open
    expect(find.textContaining('ناموفق'), findsNothing);
    expect(find.textContaining('دوباره وارد شوید'), findsNothing);
  });

  testWidgets('a downloaded copy that will not open asks the user to re-enter',
      (tester) async {
    final fake = _FakeMaalimService(available: false, failEnsureReadyTimes: 99);
    await pumpMaalim(tester, fake);

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
    final fake = _FakeMaalimService(available: false, failDownloadTimes: 1);
    await pumpMaalim(tester, fake);

    await tester.tap(find.text('دانلود محتوا'));
    await tester.pumpAndSettle();

    expect(find.textContaining('network down'), findsOneWidget);
    expect(find.textContaining('دوباره وارد شوید'), findsNothing);
    expect(find.text('دانلود محتوا'), findsOneWidget); // button is back
  });

  testWidgets('the ready page carries the book\'s own attribution',
      (tester) async {
    final fake = _FakeMaalimService(available: true);
    await pumpMaalim(tester, fake);

    // The proper name paints twice on the ready page: the app bar and the
    // header card both carry it (the download prompt carries it a third time).
    expect(find.text('معالم السنه النبویه'), findsNWidgets(2));
    expect(
        find.text(
            'جمع وترتیب: شیخ صالح أحمد الشامي · ترجمه وتعلیق: شاکر الذهبي'),
        findsOneWidget);
    // The neighbouring books' lines must never appear here.
    expect(find.textContaining('العثیمین'), findsNothing); // ریاض
    expect(find.textContaining('منذری'), findsNothing); // ترغیب
  });

  testWidgets('the download prompt promises no count it cannot verify',
      (tester) async {
    final fake = _FakeMaalimService(available: false);
    await pumpMaalim(tester, fake);

    // Nothing is on disk yet, so there is nothing to count: the prompt names
    // the payload's size only. The numbers it used to print were the
    // one-volume edition's (274 باب / 474 حدیث) and stayed put after the full
    // four-volume build replaced that copy.
    expect(find.textContaining('474'), findsNothing);
    expect(find.textContaining('274'), findsNothing);
    expect(find.textContaining('۲ مگابایت'), findsOneWidget);
    // The jump needs an open book — it must not be offered before that.
    expect(find.byTooltip('پرش به شماره حدیث'), findsNothing);
  });

  testWidgets('the ready header counts the data it loaded, not a constant',
      (tester) async {
    final fake = _FakeMaalimService(available: true);
    await pumpMaalim(tester, fake);

    // The fake carries two rows — one باب and one فصل-only section — and
    // three narrations. Both chips must read that, so a republished edition
    // shows its real size without a code change.
    expect(find.text('1 باب'), findsOneWidget);
    expect(find.text('3 حدیث'), findsOneWidget);
    expect(find.text('274 باب'), findsNothing);
    expect(find.text('474 حدیث'), findsNothing);
  });

  testWidgets('the first page lists the work\'s own کتاب‌s, not its باب‌ها',
      (tester) async {
    final fake = _FakeMaalimService(available: true);
    await pumpMaalim(tester, fake);

    // The edition's chain is مقصد › کتاب › فصل › باب; the page now stops at
    // the کتاب level, the same first step صحیح الترغیب takes. Both chapters
    // sit under their own کتاب, and each tile carries the مقصد above it.
    expect(find.text('کتاب‌ها (2)'), findsOneWidget);
    expect(find.text('کتاب اول: أنبیاء'), findsOneWidget);
    expect(find.text('کتاب دوم: سیرت نبوی شریف'), findsOneWidget);
    expect(find.text('مقصد هفتم: تاریخ، سیرت ومناقب'), findsNWidgets(2));
    // The chapter titles and the فصل line belong to the book page now.
    expect(find.text('«ذکر آدم علیه السلام»'), findsNothing);
    expect(find.text('فصل اول: جاهلیت'), findsNothing);
  });

  testWidgets('tapping a کتاب opens its own باب‌ها', (tester) async {
    final fake = _FakeMaalimService(available: true);
    await pumpMaalim(tester, fake);

    await tester.tap(find.text('کتاب دوم: سیرت نبوی شریف'));
    await tester.pumpAndSettle();

    expect(find.byType(MaalimBookScreen), findsOneWidget);
    expect(find.text('«نسب رسول الله صلی الله علیه وسلم»'), findsOneWidget);
    // A فصل-only section badges itself «ف», never the next باب's number.
    expect(find.text('ف'), findsOneWidget);
    // …and only that book's rows: the other book's باب is not here.
    expect(find.text('«ذکر آدم علیه السلام»'), findsNothing);
  });

  testWidgets('an active search lists matching باب‌ها instead of کتاب‌ها',
      (tester) async {
    final fake = _FakeMaalimService(available: true);
    await pumpMaalim(tester, fake);
    expect(find.text('کتاب اول: أنبیاء'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'نسب رسول');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // A query is a match set, not the book's traversal: the chapter rows come
    // back and the book tiles go away.
    expect(find.text('کتاب اول: أنبیاء'), findsNothing);
    expect(find.text('«نسب رسول الله صلی الله علیه وسلم»'), findsOneWidget);
  });

  testWidgets('the jump dialog opens the chapter at the requested hadith',
      (tester) async {
    final fake = _FakeMaalimService(
        available: true, jumpMax: 474, jumpLocations: const {2: 1.0});
    await pumpMaalim(tester, fake);

    await tester.tap(find.byTooltip('پرش به شماره حدیث'));
    await tester.pumpAndSettle();
    expect(find.text('پرش به شماره حدیث'), findsOneWidget);
    expect(find.textContaining('از 1 تا 474'), findsOneWidget);

    await tester.enterText(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextField)),
        '2');
    await tester.pump();
    await tester.tap(find.text('برو'));
    // The pushed chapter screen spins on its real (downloaded-book) service,
    // so settle is unreachable here — pump the route transition instead.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final chapter =
        tester.widget<MaalimChapterScreen>(find.byType(MaalimChapterScreen));
    expect(chapter.chapterIndex, 1.0);
    expect(chapter.chapterTitle, '«ذکر آدم علیه السلام»');
    expect(chapter.initialHadithNumber, 2);
  });

  testWidgets('a number this edition does not carry is reported, not opened',
      (tester) async {
    final fake = _FakeMaalimService(
        available: true, jumpMax: 474, jumpLocations: const {2: 1.0});
    await pumpMaalim(tester, fake);

    await tester.tap(find.byTooltip('پرش به شماره حدیث'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextField)),
        '400');
    await tester.pump();
    await tester.tap(find.text('برو'));
    await tester.pumpAndSettle();

    expect(find.byType(MaalimChapterScreen), findsNothing);
    expect(
        find.text('حدیث شمارهٔ 400 در این نسخه موجود نیست.'), findsOneWidget);
  });

  testWidgets(
      'a republished database replaces the stale copy instead of opening it',
      (tester) async {
    final fake = _FakeMaalimService(available: true, outdated: true);
    await pumpMaalim(tester, fake);

    // The stale copy is on disk but predates the revision: the screen
    // asks for a re-download instead of opening the old parse.
    expect(find.textContaining('نسخهٔ تصحیح‌شده'), findsOneWidget);
    expect(find.text('دانلود محتوا'), findsOneWidget);
    expect(find.text('کتاب‌ها (2)'), findsNothing);

    await tester.tap(find.text('دانلود محتوا'));
    await tester.pumpAndSettle();

    expect(fake.downloadCalls, 1);
    expect(find.text('کتاب‌ها (2)'), findsOneWidget); // corrected book
  });

  testWidgets('the book lists its مقدمهها and خاتمه beside the باب chain',
      (tester) async {
    // خاتمه sits after the whole باب chain and the list is lazy, so give the
    // test a page tall enough for both rows to be built without scrolling.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final fake = _FakeMaalimService(available: true);
    await pumpMaalim(tester, fake);

    expect(find.text('مقدمه‌ها'), findsOneWidget);

    expect(find.text('خاتمه'), findsWidgets);

    await tester.tap(find.text('مقدمه‌ها'));
    await tester.pumpAndSettle();

    expect(find.byType(MaalimMatterScreen), findsOneWidget);
    expect(find.text('مقدمه‌ی مترجم'), findsOneWidget);
    expect(find.textContaining('ستایش از آنِ خداوند'), findsOneWidget);
  });

  testWidgets('a search hides the matter rows: the list is a match set',
      (tester) async {
    final fake = _FakeMaalimService(available: true);
    await pumpMaalim(tester, fake);

    await tester.enterText(find.byType(TextField).first, 'آدم');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('مقدمه‌ها'), findsNothing);
    expect(find.text('خاتمه'), findsNothing);
  });
}

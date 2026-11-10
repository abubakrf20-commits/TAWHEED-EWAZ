import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/riyad/presentation/screens/riyad_book_screen.dart';
import 'package:tawheeed/features/riyad/presentation/screens/riyad_chapter_screen.dart';
import 'package:tawheeed/features/riyad/presentation/screens/riyad_intro_screen.dart';
import 'package:tawheeed/features/riyad/presentation/screens/riyad_screen.dart';
import 'package:tawheeed/features/riyad/services/riyad_service.dart';
import 'package:tawheeed/shared/services/content_download_service.dart'
    show DownloadProgress;

/// Drives every branch of the screen's download/open flow without a real
/// database, network or file system.
class _FakeRiyadService extends RiyadService {
  _FakeRiyadService({
    required this.available,
    this.outdated = false,
    this.jumpMax = 0,
    this.jumpLocations = const {},
  });

  final bool available;

  /// Whether needsUpdate() answers true — the copy on disk predates the
  /// six-volume database.
  final bool outdated;
  final int jumpMax;
  final Map<int, num> jumpLocations;
  int downloadCalls = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> needsUpdate() async => outdated;

  @override
  Future<void> ensureReady() async {}

  @override
  Future<void> download({DownloadProgress? onProgress}) async {
    downloadCalls++;
    onProgress?.call(100, 100);
  }

  /// Three ببs: the first two printed before the edition's first «کتاب»
  /// heading (no `part`), the third under «کتاب 1: ادب» — both the section
  /// headers and their absence are observable.
  @override
  Future<List<Map<String, dynamic>>> chapters() async => [
        {
          'id': 1,
          'book_id': RiyadService.bookId,
          'chapter_index': 1.0,
          'printed_number': 1,
          'name_arabic': 'باب الإخلاص',
          'part': null,
        },
        {
          'id': 2,
          'book_id': RiyadService.bookId,
          'chapter_index': 2.0,
          'printed_number': 2,
          'name_arabic': 'باب التوبة',
          'part': null,
        },
        {
          'id': 3,
          'book_id': RiyadService.bookId,
          'chapter_index': 3.0,
          'printed_number': 84,
          'name_arabic': 'باب الحياء',
          'part': 'کتاب 1: ادب',
        },
      ];

  @override
  Future<Map<num, int>> hadithCountsPerChapter() async =>
      {1.0: 3, 2.0: 2, 3.0: 0};

  @override
  Future<int> totalEntries() async => 5;

  @override
  Future<List<Map<String, dynamic>>> matterSections() async => const [
        {'id': 1, 'title': 'درآمدی بر کتاب', 'volume': 1},
      ];

  @override
  Future<List<Map<String, dynamic>>> search(String query,
          {int limit = 30}) async =>
      query.trim() == 'ریاض' ? const [] : const [];

  @override
  Future<int> maxHadithNumber() async => jumpMax;

  @override
  Future<(num, int)?> locateHadithNumber(int number) async {
    final chapter = jumpLocations[number];
    return chapter == null ? null : (chapter, number);
  }
}

Future<void> pumpRiyad(WidgetTester tester, RiyadService service) async {
  await tester.pumpWidget(MaterialApp(
    home: RiyadScreen(service: service),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a download that succeeds opens the book', (tester) async {
    final fake = _FakeRiyadService(available: false);
    await pumpRiyad(tester, fake);

    expect(find.text('دانلود محتوا'), findsOneWidget);
    await tester.tap(find.text('دانلود محتوا'));
    await tester.pumpAndSettle();

    expect(fake.downloadCalls, 1);
    expect(find.text('کتاب‌ها (3)'), findsOneWidget); // content is open
    expect(find.text('3 باب'), findsOneWidget); // counts come from the data
    expect(find.text('5 حدیث'), findsOneWidget);
  });

  testWidgets('a copy from before revision 2 is replaced, not opened',
      (tester) async {
    final fake = _FakeRiyadService(available: true, outdated: true);
    await pumpRiyad(tester, fake);

    expect(find.textContaining('نسخهٔ تصحیح‌شده'), findsOneWidget);
    expect(find.text('دانلود نسخهٔ جدید'), findsOneWidget);
    expect(find.text('کتاب‌ها (3)'), findsNothing);
  });

  testWidgets('the first page lists the edition\'s own کتاب‌s',
      (tester) async {
    final fake = _FakeRiyadService(available: true);
    await pumpRiyad(tester, fake);

    // Three chapters make three books here: the two ببs printed before the
    // first «کتاب» heading stand on their own, and the third belongs to
    // «کتاب 1: ادب» — the same کتاب › باب › حدیث walk الترغیب has.
    expect(find.text('کتاب‌ها (3)'), findsOneWidget);
    expect(find.text('باب الإخلاص'), findsOneWidget);
    expect(find.text('کتاب 1: ادب'), findsOneWidget);
    // The باب under that کتاب belongs to its page, not to this one.
    expect(find.text('باب الحياء'), findsNothing);
  });

  testWidgets('tapping a کتاب opens its own ببs', (tester) async {
    final fake = _FakeRiyadService(available: true);
    await pumpRiyad(tester, fake);

    await tester.tap(find.text('کتاب 1: ادب'));
    await tester.pumpAndSettle();

    expect(find.byType(RiyadBookScreen), findsOneWidget);
    expect(find.text('باب الحياء'), findsOneWidget);
    // A باب the edition leaves without a new narration says so.
    expect(find.text('شرح'), findsOneWidget);
    expect(find.text('باب الإخلاص'), findsNothing);
  });

  testWidgets('the مقدمه row opens the first volume front matter',
      (tester) async {
    final fake = _FakeRiyadService(available: true);
    await pumpRiyad(tester, fake);

    expect(find.text('مقدمه‌ها'), findsOneWidget);
    await tester.tap(find.text('مقدمه‌ها'));
    await tester.pumpAndSettle();
    expect(find.byType(RiyadIntroScreen), findsOneWidget);
  });

  testWidgets('the jump dialog opens the chapter at the requested hadith',
      (tester) async {
    final fake = _FakeRiyadService(
      available: true,
      jumpMax: 5,
      jumpLocations: const {2: 2.0},
    );
    await pumpRiyad(tester, fake);

    await tester.tap(find.byTooltip('پرش به شماره حدیث'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '2');
    await tester.pumpAndSettle();
    await tester.tap(find.text('برو'));
    // The pushed reader spins while it waits for a database this test does not
    // provide, so settle by hand instead of waiting for the animation to end.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(RiyadChapterScreen), findsOneWidget);
    expect(find.text('باب 2'), findsOneWidget);
  });
}

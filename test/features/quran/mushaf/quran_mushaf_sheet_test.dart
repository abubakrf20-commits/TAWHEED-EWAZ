// Widget test: mushaf-level flows that need real page data.
//
// Seeds page 1 (QCF4 JSON + fonts) through the same path_provider mock the
// viewer tests use, pumps the full QuranMushafView, then taps a glyph to
// verify the verse-action sheet actually opens, scrolls in a short (landscape)
// viewport instead of overflowing, and exposes its key actions.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/app/state/shell_nav.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/features/quran/data/daos/quran_bookmark_dao.dart';
import 'package:tawheeed/features/quran/mushaf/qcf4/qcf4_config.dart';
import 'package:tawheeed/features/quran/mushaf/qcf4/qcf4_data_store.dart';
import 'package:tawheeed/features/quran/mushaf/qcf4/qcf4_font_loader.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_reader_prefs.dart';
import 'package:tawheeed/features/quran/mushaf/qcf4/qcf4_page_viewer.dart';
import 'package:tawheeed/features/quran/mushaf/quran_mushaf_view.dart';

const String _pageJson = '''
{
  "page": 1,
  "font": "QCF4_Hafs_01",
  "lines": [
    {"line": 1, "words": [
      {"code": 61696, "char": "\\uF100", "font": "QCF4_Hafs_01",
       "text": "بِسْمِ", "type": "word", "verse_key": "1:1", "position": 1},
      {"code": 61700, "char": "\\uF104", "font": "QCF4_Hafs_01",
       "text": "V1", "type": "end", "verse_key": "1:1", "position": 5}
    ]},
    {"line": 2, "words": [
      {"code": 61701, "char": "\\uF105", "font": "QCF4_Hafs_01",
       "text": "الْحَمْدُ", "type": "word", "verse_key": "1:2", "position": 1},
      {"code": 61702, "char": "\\uF106", "font": "QCF4_Hafs_01",
       "text": "الرَّبِّ", "type": "word", "verse_key": "1:2", "position": 2},
      {"code": 61703, "char": "\\uF107", "font": "QCF4_Hafs_01",
       "text": "الْعَالَمِينَ", "type": "word", "verse_key": "1:2", "position": 3},
      {"code": 61704, "char": "\\uF108", "font": "QCF4_Hafs_01",
       "text": "V2", "type": "end", "verse_key": "1:2", "position": 5}
    ]},
    {"line": 3, "words": [
      {"code": 61701, "char": "\\uF105", "font": "QCF4_Hafs_01",
       "text": "الْحَمْدُ", "type": "word", "verse_key": "1:3", "position": 1},
      {"code": 61705, "char": "\\uF109", "font": "QCF4_Hafs_01",
       "text": "V3", "type": "end", "verse_key": "1:3", "position": 5}
    ]},
    {"line": 4, "words": [
      {"code": 61701, "char": "\\uF105", "font": "QCF4_Hafs_01",
       "text": "الْحَمْدُ", "type": "word", "verse_key": "1:4", "position": 1},
      {"code": 61705, "char": "\\uF109", "font": "QCF4_Hafs_01",
       "text": "V4", "type": "end", "verse_key": "1:4", "position": 5}
    ]},
    {"line": 5, "words": [
      {"code": 61701, "char": "\\uF105", "font": "QCF4_Hafs_01",
       "text": "الْحَمْدُ", "type": "word", "verse_key": "1:5", "position": 1},
      {"code": 61705, "char": "\\uF109", "font": "QCF4_Hafs_01",
       "text": "V5", "type": "end", "verse_key": "1:5", "position": 5}
    ]},
    {"line": 6, "words": [
      {"code": 61701, "char": "\\uF105", "font": "QCF4_Hafs_01",
       "text": "الْحَمْدُ", "type": "word", "verse_key": "1:6", "position": 1},
      {"code": 61705, "char": "\\uF109", "font": "QCF4_Hafs_01",
       "text": "V6", "type": "end", "verse_key": "1:6", "position": 5}
    ]},
    {"line": 7, "words": [
      {"code": 61701, "char": "\\uF105", "font": "QCF4_Hafs_01",
       "text": "الْحَمْدُ", "type": "word", "verse_key": "1:7", "position": 1},
      {"code": 61705, "char": "\\uF109", "font": "QCF4_Hafs_01",
       "text": "V7", "type": "end", "verse_key": "1:7", "position": 5}
    ]}
  ]
}
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  Directory pagesDir() => Directory(
      p.join(tempDir.path, 'quran_content', Qcf4Config.cacheDirName, 'pages'));
  Directory fontsDir() => Directory(
      p.join(tempDir.path, 'quran_content', Qcf4Config.cacheDirName, 'fonts'));

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('tawheeed_mushaf_widget');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return tempDir.path;
      }
      return null;
    });
    SharedPreferences.setMockInitialValues({});
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  tearDown(() {
    Qcf4DataStore.instance.clearMemory();
    Qcf4FontLoader.instance.testRegisterHook = null;
  });

  /// Seeds page 1 + fonts on disk so the viewer's fast path renders glyphs.
  Future<void> seedPageCache() async {
    await pagesDir().create(recursive: true);
    await File(p.join(pagesDir().path, '001.json')).writeAsString(_pageJson);
    await fontsDir().create(recursive: true);
    for (final family in <String>[
      'QCF4_Hafs_01',
      Qcf4Config.qbsmlFontFamily,
    ]) {
      await File(p.join(fontsDir().path, Qcf4Config.fontTtfFileName(family)))
          .writeAsBytes([0, 0, 0, 0]);
    }
    Qcf4FontLoader.instance.testRegisterHook = (_, __) async => true;
    await Qcf4DataStore.instance.loadPage(1, allowNetwork: false);
    await Qcf4FontLoader.instance.ensure('QCF4_Hafs_01');
    await Qcf4FontLoader.instance.ensure(Qcf4Config.qbsmlFontFamily);
  }

  Future<void> pumpReader(WidgetTester tester, {AppDatabase? store}) async {
    // The band's controls are what most of this suite drives, so it starts
    // with the reader's own «نوار بالای صفحه» tick on; the bare-page default
    // is asserted in the widget suite.
    SharedPreferences.setMockInitialValues(
        {MushafReaderPrefs.headerVisibleKey: true});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          quranImmersiveProvider.overrideWith(QuranImmersive.new),
          // The tests that write bookmarks need their own in-memory store. It is
          // passed as an `AppDatabase?` rather than as a list of overrides
          // because Riverpod 3 does not export the `Override` type, so a
          // parameter of that type cannot be written.
          if (store != null) appDatabaseProvider.overrideWithValue(store),
        ],
        child: const Directionality(
          textDirection: TextDirection.rtl,
          child: MaterialApp(
            home: Scaffold(
              body: QuranMushafView(),
            ),
          ),
        ),
      ),
    );
    // Let async init (prefs + page load) settle. Fixed pumps: pumpAndSettle
    // would hang on the header's indeterminate progress bar.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// The reader watches Drift-backed stream providers (ayah highlights).
  /// Disposing them schedules a zero-duration housekeeping timer, and a timer
  /// left until binding teardown fails the "no pending timers" invariant -- so
  /// every test unmounts the tree and drains the clock while the binding is
  /// still running.
  Future<void> unmountReader(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  void readerTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      await body(tester);
      await unmountReader(tester);
    });
  }

  /// Leaves the reader in the state it puts itself in on rotation: the chrome
  /// hidden, and the shell's bottom navigation hidden with it.
  Future<void> enterFullscreen(WidgetTester tester) async {
    // Reading settings moved into the overflow menu, which is where the new
    // slim header keeps everything that is not navigation.
    await tester.tap(find.byTooltip('بیشتر'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('تنظیمات مطالعه'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 200));
    // The sheet body scrolls only when its content outgrows the window — the
    // third card starts below the fold on a short screen, so reach the row
    // before tapping it.
    final fullscreenRow = find.text('نوار بالای صفحه');
    await tester.ensureVisible(fullscreenRow);
    await tester.pump();
    await tester.tap(fullscreenRow);
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// A point on the page that cannot be a glyph and that no overlay covers:
  /// in the viewer's own left margin (it reserves 10dp before the text block
  /// starts), half-way down. The reserved top/bottom bands are *outside* the
  /// viewer — a tap there belongs to nobody — and the bottom of the page is
  /// where the reader's hint snackbar floats.
  Offset blankPagePoint(WidgetTester tester) {
    final pager = tester.getRect(find.byType(PageView));
    return Offset(pager.left + 5, pager.center.dy);
  }

  readerTest('tapping a glyph opens the verse-action sheet', (tester) async {
    await tester.runAsync(seedPageCache);
    await pumpReader(tester);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('\uF100').first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('سورهٔ الفاتحة — آیهٔ 1'), findsOneWidget);
    expect(find.text('تلاوت'), findsOneWidget);
  });

  readerTest(
      'the verse actions sit on 48dp icon tiles: six on top, share and note below',
      (tester) async {
    await tester.runAsync(seedPageCache);
    tester.view.physicalSize = const Size(400 * 2, 900 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await pumpReader(tester);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('\uF100').first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));

    // The five fixed labels. The bookmark cell's text flips between «نشان» and
    // «حذف نشان», so it is measured below rather than spelled out here.
    for (final label in ['تلاوت', 'تفسیر', 'ترجمه', 'صوتی', 'هایلایت']) {
      expect(find.text(label), findsOneWidget, reason: 'the $label cell');
    }

    // Share and note joined the six on the same 48 dp cell (user request), so
    // the sheet carries EIGHT tiles on TWO rows: the six actions on top and
    // the share/note pair directly below, arranged like the ones above.
    final actionTiles = <Rect>[];
    for (final element in find
        .descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(DuotoneIconTile),
        )
        .evaluate()) {
      final tile = element.widget as DuotoneIconTile;
      if (tile.size != 48) continue;
      actionTiles.add(tester.getRect(find.byWidget(tile)));
    }
    expect(actionTiles, hasLength(8), reason: 'six actions + share + note');
    expect(actionTiles.first.width, 48,
        reason: 'up from the old two-column grid’s 40 dp');
    final topRow = actionTiles.take(6).toList();
    final secondRow = actionTiles.skip(6).toList();
    expect(topRow.map((r) => r.top).toSet(), hasLength(1),
        reason: 'the six actions share one row');
    expect(topRow.map((r) => r.left).toSet(), hasLength(6),
        reason: 'six columns — the grid this replaced had two');
    expect(secondRow.map((r) => r.top).toSet(), hasLength(1),
        reason: 'share and note share one row');
    expect(secondRow.map((r) => r.left).toSet(), hasLength(2),
        reason: 'two cells under the six');
    expect(secondRow.first.top, greaterThan(topRow.first.bottom),
        reason: 'the pair sits BELOW the six, like the icons above');
    expect(tester.takeException(), isNull);
  });

  readerTest(
      'verse-action sheet scrolls in a short landscape viewport instead of overflowing',
      (tester) async {
    await tester.runAsync(seedPageCache);
    // 800x380 landscape-like: the two tile rows must scroll rather than
    // overflow.
    tester.view.physicalSize = const Size(800 * 2, 380 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await pumpReader(tester);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('\uF100').first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));

    // The sheet opens and its body is scrollable.
    expect(find.text('سورهٔ الفاتحة — آیهٔ 1'), findsOneWidget);
    final scrollable = find
        .descendant(
          of: find.byType(BottomSheet),
          matching: find.byWidgetPredicate(
              (w) => w is SingleChildScrollView || w is Scrollable),
        )
        .first;
    expect(scrollable, findsOneWidget);

    // Drag the sheet body up: the share tile becomes visible without any
    // RenderFlex overflow exception.
    await tester.drag(scrollable, const Offset(0, -200));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('اشتراک'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  readerTest(
      'the ayah sheet highlights the verse and has no duplicate '
      'range-share option', (tester) async {
    await tester.runAsync(seedPageCache);
    // A tall phone: the highlight tile must sit above the fold to be tappable.
    tester.view.physicalSize = const Size(400 * 2, 900 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await pumpReader(tester);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('').first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));

    // The colored highlight entry is back and wired to the persistent
    // swatch picker (Audit 8.12: markers now survive restarts in Drift).
    expect(find.text('هایلایت'), findsOneWidget);
    // Only ONE share option remains: the «اشتراک» tile on this sheet (the
    // range option used to duplicate it on the exact same screen and was
    // removed). The full wording lives in the tile's semantics label.
    expect(find.text('اشتراک'), findsOneWidget);
    expect(find.bySemanticsLabel('اشتراک‌گذاری این آیه'), findsOneWidget);
    expect(find.text('اشتراک‌گذاری محدوده‌ای از آیات'), findsNothing);

    await tester.tap(find.text('هایلایت'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('هایلایت این آیه'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('ayah_highlight_swatch_0')), findsOneWidget);
    // Nothing to remove yet: this ayah has no stored marker.
    expect(find.byKey(const ValueKey('ayah_highlight_remove')), findsNothing);
  });

  readerTest('the verse-action sheet can be swiped shut as well',
      (tester) async {
    // Same defect as the reading-settings sheet, and the same fix: its body is
    // a MushafSheetScroll now, so while the content fits the scrollable adds no
    // drag recogniser and the sheet receives the drag itself.
    await tester.runAsync(seedPageCache);
    tester.view.physicalSize = const Size(400 * 2, 900 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await pumpReader(tester);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('\uF100').first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('سورهٔ الفاتحة — آیهٔ 1'), findsOneWidget);

    await tester.drag(
        find.text('سورهٔ الفاتحة — آیهٔ 1'), const Offset(0, 500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('سورهٔ الفاتحة — آیهٔ 1'), findsNothing,
        reason: 'a downward drag must dismiss this sheet too');
    expect(tester.takeException(), isNull);
  });

  readerTest('a double tap leaves fullscreen — a single tap does not',
      (tester) async {
    // Reader request: the way out of fullscreen is a double tap on the page.
    // The chip that used to open the header is gone ("nothing may sit over the
    // page"), and the hint now names the double tap — so a stray tap on the
    // paper must stay inert and only a deliberate double tap may wake the
    // chrome.
    await tester.runAsync(seedPageCache);
    tester.view.physicalSize = const Size(400 * 2, 900 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await pumpReader(tester);
    expect(tester.takeException(), isNull);

    await enterFullscreen(tester);
    expect(find.byTooltip('بیشتر'), findsNothing,
        reason: 'fullscreen hides the header');

    final blank = blankPagePoint(tester);
    await tester.tapAt(blank);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byTooltip('بیشتر'), findsNothing,
        reason: 'one tap on blank paper must not wake the chrome');
    // The double tap is the way back: two taps inside the double-tap window,
    // far enough apart to be seen as a second tap rather than one long one.
    await tester.tapAt(blank);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(blank);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byTooltip('بیشتر'), findsOneWidget,
        reason: 'the double tap on the page must bring the chrome back');
    expect(tester.takeException(), isNull);
  });

  readerTest('a tap on the page never hides the chrome that is showing',
      (tester) async {
    // The other half of the rule: a stray tap on the paper while reading must
    // not take the header away. Hiding is deliberate — a double tap, or the
    // fullscreen switch.
    await tester.runAsync(seedPageCache);
    tester.view.physicalSize = const Size(400 * 2, 900 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await pumpReader(tester);
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('بیشتر'), findsOneWidget);

    await tester.tapAt(blankPagePoint(tester));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byTooltip('بیشتر'), findsOneWidget,
        reason: 'a stray tap must not hide the chrome');
    expect(tester.takeException(), isNull);
  });

  readerTest('the page identity is printed inside the page bands',
      (tester) async {
    // Reader request (2026-10-13): the surah name top-right and the juz
    // top-left are printed on every page, in BOTH chrome states — a
    // continuation page carries them like the page a surah opens. They sit in
    // the 28 dp band the page keeps clear of its glyphs, below the header when
    // it is up. The page number prints bottom-left in both states too (reader
    // request: normal AND fullscreen), clear of the 26 dp binding band now
    // that the page-side glyph is gone.
    await tester.runAsync(seedPageCache);
    tester.view.physicalSize = const Size(400 * 2, 900 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await pumpReader(tester);
    expect(tester.takeException(), isNull);

    final pager = tester.getRect(find.byType(PageView));
    // The text block's own top edge — it starts below the header band plus the
    // 28 dp the page reserves, so the band the labels may use is exactly
    // [page.top + 28 .. page.top] in fullscreen and [viewer.top - 28 ..
    // viewer.top] with the header up.
    final viewerTop = tester.getRect(find.byType(Qcf4PageViewer)).top;

    // Chrome up: the paper carries the two facts below the header band, and
    // the page number in the bottom band (reader request: bottom-left in the
    // normal state too, not only fullscreen).
    final surahUp =
        tester.getRect(find.byKey(const ValueKey('mushaf_corner_surah_1')));
    final juzUp =
        tester.getRect(find.byKey(const ValueKey('mushaf_corner_juz_1')));
    final numberUp =
        tester.getRect(find.byKey(const ValueKey('mushaf_corner_page_1')));
    expect(surahUp.top, greaterThanOrEqualTo(viewerTop - 28),
        reason: 'the surah label must clear the header, not hide behind it');
    expect(surahUp.bottom, lessThanOrEqualTo(viewerTop),
        reason: 'the surah label must stay in the band above the glyphs');
    expect(juzUp.bottom, lessThanOrEqualTo(viewerTop),
        reason: 'the juz label must stay in the band above the glyphs');
    expect(numberUp.top, greaterThanOrEqualTo(pager.bottom - 28),
        reason: 'the page number must stay in the band below the glyphs');
    // The folio is centred: one contract for every page, no parity jump.
    expect(numberUp.center.dx, closeTo(pager.center.dx, 1),
        reason: 'the folio sits on the page axis, not on a hard-coded edge');

    await enterFullscreen(tester);

    final surah =
        tester.getRect(find.byKey(const ValueKey('mushaf_corner_surah_1')));
    final juz =
        tester.getRect(find.byKey(const ValueKey('mushaf_corner_juz_1')));
    final number =
        tester.getRect(find.byKey(const ValueKey('mushaf_corner_page_1')));

    // Top band (28 dp): below the page's top edge, clear of the text block.
    expect(surah.top, greaterThanOrEqualTo(pager.top));
    expect(surah.bottom, lessThanOrEqualTo(pager.top + 28),
        reason: 'the surah label must stay in the band above the glyphs');
    expect(juz.bottom, lessThanOrEqualTo(pager.top + 28),
        reason: 'the juz label must stay in the band above the glyphs');
    // Corners: surah right, juz left, both on the same 12 dp edge inset and
    // the same baseline.
    expect(surah.right, closeTo(pager.right - 12, 1));
    expect(juz.left, closeTo(pager.left + 12, 1));
    expect(surah.top, closeTo(juz.top, 1),
        reason: 'the two corner labels share one baseline');
    // Bottom band: the number alone, on the page axis.
    expect(number.top, greaterThanOrEqualTo(pager.bottom - 28),
        reason: 'the page number must stay in the band below the glyphs');
    expect(number.center.dx, closeTo(pager.center.dx, 1));
    // …and it stays clear of the 18 dp binding band on the opposite side.
    expect(number.left, greaterThan(pager.left + 18));
    expect(tester.takeException(), isNull);
  });

  readerTest('the page-side right/left glyph is gone from the reader',
      (tester) async {
    // Reader request: «پایین ایکون صفحهٔ راست و چپ حذف کن». The glyph was the
    // only page furniture carrying that side wording, so its absence is the
    // proof — asserted through semantics, since the icon itself is decorative.
    await tester.runAsync(seedPageCache);
    tester.view.physicalSize = const Size(400 * 2, 900 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await pumpReader(tester);
    await enterFullscreen(tester);

    expect(find.bySemanticsLabel('صفحهٔ راست'), findsNothing);
    expect(find.bySemanticsLabel('صفحهٔ چپ'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  readerTest(
      'the mini player tucks away and comes back without stopping playback',
      (tester) async {
    // No reciter is picked in this test, so the play command lands on the
    // friendly error — which is exactly what makes the panel render here.
    await tester.runAsync(seedPageCache);
    tester.view.physicalSize = const Size(400 * 2, 900 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await pumpReader(tester);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('\uF100').first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('تلاوت'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));

    // Whatever a headless platform reports, the play command puts the mini
    // player up — and that panel is what must be dismissible.
    final hide = find.byTooltip('مخفی کردن نوار پخش');
    expect(hide, findsOneWidget, reason: 'the mini player is up');

    // Tuck the bar away: the panel is gone, the resume pill replaces it.
    await tester.tap(hide);
    await tester.pump();
    expect(find.byTooltip('مخفی کردن نوار پخش'), findsNothing,
        reason: 'the panel is hidden');
    expect(find.byTooltip('نمایش نوار پخش'), findsOneWidget);

    // And the pill brings it straight back.
    await tester.tap(find.byTooltip('نمایش نوار پخش'));
    await tester.pump();
    expect(find.byTooltip('مخفی کردن نوار پخش'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  readerTest('a note written from the ayah sheet rides the bookmark (§7.4)',
      (tester) async {
    await tester.runAsync(seedPageCache);
    tester.view.physicalSize = const Size(400 * 2, 1000 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    // Its own in-memory database, so the assertion below reads a real write
    // rather than whatever the app's own file database happens to hold.
    final db = AppDatabase.withConnection(NativeDatabase.memory());
    addTearDown(db.close);
    final dao = QuranBookmarkDao(db);

    await pumpReader(tester, store: db);
    expect(tester.takeException(), isNull);

    // The sheet offers the note on an icon tile, below sharing.
    await tester.tap(find.text('\uF100').first, warnIfMissed: false);
    // The sheet slides in from the bottom; roll several frames so the route
    // transition reaches its resting place. A single long pump starts it but
    // does not carry it, and a tap on a tile then lands below the screen.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('یادداشت'), findsOneWidget);

    await tester.tap(find.text('یادداشت'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The writer opens with its own title, and saving marks the ayah.
    expect(find.text('یادداشت آیه'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'تدبر من در این آیه');
    await tester.pump();
    await tester.tap(find.text('ذخیره'));
    // The dialog closes, the write lands, and the bookmark stream re-emits:
    // roll frames until all three have happened.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final stored = await tester.runAsync(() => dao.getByAyah(1, 1));
    expect(stored, isNotNull, reason: 'writing a note marks the ayah too');
    expect(stored!.note, 'تدبر من در این آیه');

    // Reopening the sheet now offers to edit: the tile's glyph flips to the
    // edit pen and the semantics label names the edit. The note's text itself
    // is read in the writer, not previewed on the tile (the icon tiles carry
    // no subtitle — that is the shape the user asked for).
    await tester.tap(find.text('\uF100').first, warnIfMissed: false);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byIcon(Icons.edit_note_rounded), findsOneWidget);
    expect(find.bySemanticsLabel('ویرایش یادداشت این آیه'), findsOneWidget);
  });
}

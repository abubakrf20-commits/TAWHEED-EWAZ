import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/features/quran/mushaf/qcf4/qcf4_config.dart';
import 'package:tawheeed/features/quran/mushaf/qcf4/qcf4_data_store.dart';
import 'package:tawheeed/features/quran/mushaf/qcf4/qcf4_font_loader.dart';
import 'package:tawheeed/features/quran/mushaf/qcf4/qcf4_page_viewer.dart';

/// Widget-level tests for the live-font page renderer.
///
/// The page JSON + TTF files are pre-seeded on a temp documents dir and engine
/// font registration runs through `Qcf4FontLoader.testRegisterHook` (the test
/// engine accepts any bytes as a font), so the render path — page load, the
/// fast path, per-line measurement, line layout, highlight rebuild and the
/// memoised page tree — is exercised end-to-end instead of the offline
/// fallback. The fixture uses ordinary word lines only (no surah banner) so
/// no asset image decoding is involved.
const String _pageJson = '''
{
  "page": 1,
  "font": "QCF4_Hafs_01",
  "lines": [
    {"line": 1, "words": [
      {"code": 61696, "char": "\\uF100", "font": "QCF4_Hafs_01",
       "text": "بِسْمِ", "type": "word", "verse_key": "1:1", "position": 1},
      {"code": 61699, "char": "\\uF103", "font": "QCF4_Hafs_01",
       "text": "الرَّحِيمِ", "type": "word", "verse_key": "1:1", "position": 4},
      {"code": 61700, "char": "\\uF104", "font": "QCF4_Hafs_01",
       "text": "V1", "type": "end", "verse_key": "1:1", "position": 5}
    ]},
    {"line": 2, "words": [
      {"code": 61701, "char": "\\uF105", "font": "QCF4_Hafs_01",
       "text": "الْحَمْدُ", "type": "word", "verse_key": "1:2", "position": 1},
      {"code": 61705, "char": "\\uF109", "font": "QCF4_Hafs_01",
       "text": "V2", "type": "end", "verse_key": "1:2", "position": 5}
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
    tempDir = await Directory.systemTemp.createTemp('tawheeed_qcf4_viewer');
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

  /// Seeds page 1 + its fonts on disk, decodes the page into the RAM LRU and
  /// registers both font families so the viewer's fast path triggers.
  Future<void> seedPageCache() async {
    final pages = pagesDir();
    await pages.create(recursive: true);
    await File(p.join(pages.path, '001.json')).writeAsString(_pageJson);

    final fonts = fontsDir();
    await fonts.create(recursive: true);
    for (final family in <String>[
      'QCF4_Hafs_01',
      Qcf4Config.qbsmlFontFamily,
    ]) {
      await File(p.join(fonts.path, Qcf4Config.fontTtfFileName(family)))
          .writeAsBytes([0, 0, 0, 0]);
    }

    Qcf4FontLoader.instance.testRegisterHook = (_, __) async => true;
    await Qcf4DataStore.instance.loadPage(1, allowNetwork: false);
    await Qcf4FontLoader.instance.ensure('QCF4_Hafs_01');
    await Qcf4FontLoader.instance.ensure(Qcf4Config.qbsmlFontFamily);
  }

  Future<void> pumpViewer(WidgetTester tester,
      {Qcf4Highlight highlight = const Qcf4Highlight(surah: 1, ayah: 1),
      bool fitWidth = false}) async {
    tester.view.physicalSize = const Size(1080, 2160);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Qcf4PageViewer(page: 1, highlight: highlight, fitWidth: fitWidth),
      ),
    ));
  }

  Finder viewerRows() => find.descendant(
      of: find.byType(Qcf4PageViewer), matching: find.byType(Row));

  testWidgets('page glyphs have horizontal breathing room from the screen edge',
      (tester) async {
    await tester.runAsync(seedPageCache);
    // Portrait (fitWidth=false): slimmer 10px margin; landscape: 16px.
    await pumpViewer(tester);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The viewer's own edge padding so the glyphs never touch the screen
    // edges. Find it inside the SizedBox.expand body.
    Finder padWith(double h) => find.descendant(
          of: find.byType(Qcf4PageViewer),
          matching: find.byWidgetPredicate((w) =>
              w is Padding &&
              w.padding is EdgeInsets &&
              (w.padding as EdgeInsets).left == h &&
              (w.padding as EdgeInsets).right == h),
        );
    expect(tester.widgetList<Padding>(padWith(10)), isNotEmpty);

    // Landscape keeps the wider margin.
    await pumpViewer(tester, fitWidth: true);
    await tester.pumpAndSettle();
    expect(tester.widgetList<Padding>(padWith(16)), isNotEmpty);
  });

  testWidgets('fitWidth mode scrolls vertical overflow instead of shrinking',
      (tester) async {
    await tester.runAsync(seedPageCache);
    // A short (landscape-like) viewport: contain-fit would shrink the glyphs
    // drastically; fitWidth must keep the width-bound size and scroll.
    tester.view.physicalSize = const Size(2160, 1080);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Qcf4PageViewer(
          page: 1,
          highlight: Qcf4Highlight(surah: 1, ayah: 1),
          fitWidth: true,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    // The FittedBox inside binds on width (fitWidth), not contain.
    final box = tester.widget<FittedBox>(find.byType(FittedBox).first);
    expect(box.fit, BoxFit.fitWidth);
  });

  testWidgets('contain mode (default) does not scroll the page',
      (tester) async {
    await tester.runAsync(seedPageCache);
    await pumpViewer(tester);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsNothing);
    final box = tester.widget<FittedBox>(find.byType(FittedBox).first);
    expect(box.fit, BoxFit.contain);
  });

  testWidgets('renders a fully cached page without the busy spinner',
      (tester) async {
    await tester.runAsync(seedPageCache);
    await pumpViewer(tester);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Fast path: everything is already in RAM, so no loading UI at any point.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // The two fixture word lines render as RTL rows.
    expect(viewerRows(), findsNWidgets(2));
    expect(
      find.descendant(
          of: find.byType(Qcf4PageViewer), matching: find.byType(FittedBox)),
      findsWidgets,
    );
  });

  testWidgets('rebuilds correctly when the highlighted verse changes',
      (tester) async {
    await tester.runAsync(seedPageCache);
    await pumpViewer(tester,
        highlight: const Qcf4Highlight(surah: 1, ayah: 1, activeWord: 0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await pumpViewer(tester,
        highlight: const Qcf4Highlight(surah: 1, ayah: 2, activeWord: -1));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(viewerRows(), findsNWidgets(2));
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('an off-page highlight change reuses the cached page tree',
      (tester) async {
    // Page 1 carries 1:1 and 1:2, not 1:4 — the highlight can never affect
    // its output, so the memoised tree must be reused across the update.
    await tester.runAsync(seedPageCache);
    await pumpViewer(tester, highlight: const Qcf4Highlight(surah: 1, ayah: 4));
    await tester.pumpAndSettle();
    final first = tester.widget<FittedBox>(find.byType(FittedBox).first);

    await pumpViewer(tester, highlight: const Qcf4Highlight(surah: 1, ayah: 5));
    await tester.pumpAndSettle();
    final second = tester.widget<FittedBox>(find.byType(FittedBox).first);

    expect(tester.takeException(), isNull);
    expect(identical(first, second), isTrue,
        reason: 'an off-page highlight change must reuse the cached tree');
  });
}

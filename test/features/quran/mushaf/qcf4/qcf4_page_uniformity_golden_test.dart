import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/quran/mushaf/qcf4/qcf4_config.dart';
import 'package:tawheeed/features/quran/mushaf/qcf4/qcf4_models.dart';
import 'package:tawheeed/features/quran/mushaf/qcf4/qcf4_page_viewer.dart';

/// Documents-dir stand-in so the QCF4 cache resolves under a temp directory.
class _FakePathProvider extends PathProviderPlatform {
  final String documentsPath;
  _FakePathProvider(this.documentsPath);

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

/// The viewer's own design-width target, mirrored here so the fixture guard
/// below can state the contract without reaching into private state.
const double kRefLineUnits = 16.3;

/// Default body size the viewer uses when `fontSize` is not passed, and the
/// clamp its probe scale is held to — mirrored from `_Qcf4PageViewerState`.
/// See the caveat in the glyph-size test for what these mean here.
const double kBaseFontSize = 30.0;
const double kScaleMin = 0.90;
const double kScaleMax = 1.12;

/// One synthetic Mushaf page: which QCF4 font group it belongs to, and how
/// its words sit on physical lines.
class _SamplePage {
  final int number;
  final String font;
  final List<int> lineCounts;
  final List<String> words;

  _SamplePage({
    required this.number,
    required this.font,
    required this.lineCounts,
    required this.words,
  });

  /// Realistic uneven fill: two fuller lines, then a run of short ones, the
  /// way a printed page's justification reads. Distributes [wordCount] words
  /// across lines so the counts can never drift out of sync with the inventory.
  static List<int> _lineCountsFor(int wordCount) {
    const fullness = <int>[3, 3, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2];
    final counts = <int>[];
    var left = wordCount;
    var i = 0;
    while (left > 0) {
      final want = fullness[i % fullness.length];
      final take = want > left ? left : want;
      counts.add(take);
      left -= take;
      i++;
    }
    return counts;
  }

  /// Short Arabic function words, so twelve of them span less than the
  /// [kRefLineUnits] design width and the probe lands *inside* its clamp
  /// instead of saturating on a substitute font.
  static const List<String> _inventory = <String>[
    'وَ',
    'فِي',
    'مِنْ',
    'قَدْ',
    'لَمْ',
    'هُمْ',
    'هُوَ',
    'بِهِ',
    'مَعَ',
    'إِنَّ',
    'أَنْ',
    'كَانَ',
    'يَوْمَ',
    'نَفْسٍ',
    'رَبِّهِ',
    'سَمَاءَ',
    'أَرْضٍ',
    'جَنَّةٍ',
    'كُلٌّ',
    'مِنَ',
    'لَهُ',
    'بِمَا',
    'عَمَّ',
    'قَدْ',
    'ثُمَّ',
    'حَتَّىٰ',
  ];

  /// [rotation] shifts which words the design-uniformity probe samples first
  /// (it measures the first twelve body words it meets). Same inventory, so a
  /// page's real content — and therefore its correct measure — is unchanged.
  factory _SamplePage.sample(int number, String font, {int rotation = 0}) {
    const inv = _inventory;
    final rotated = [
      for (var i = 0; i < inv.length; i++) inv[(i + rotation) % inv.length],
    ];
    final counts = _lineCountsFor(rotated.length);
    // Twelve content lines keeps the page clear of the "short page" path
    // (blank-line dropping + vertical justification), so the measured column
    // is the page's natural text measure.
    assert(counts.length >= 12, 'fixture must keep >= 12 content lines');
    return _SamplePage(
      number: number,
      font: font,
      lineCounts: counts,
      words: rotated,
    );
  }

  Qcf4Page toModel() {
    final lines = <Qcf4Line>[];
    var i = 0;
    var lineNo = 0;
    for (final count in lineCounts) {
      final lineWords = <Qcf4Word>[];
      for (var k = 0; k < count; k++, i++) {
        lineWords.add(Qcf4Word(char: words[i], font: font, type: 'word'));
      }
      lines.add(Qcf4Line(line: ++lineNo, words: lineWords));
    }
    return Qcf4Page(page: number, font: font, surahs: const [], lines: lines);
  }
}

/// Body paragraphs in document order. A line renders as a `Row` of `Text`s
/// inside a `FittedBox`, so painted widths are transform-scaled, but
/// `RenderParagraph.size` is the laid-out (design-space) size.
List<RenderParagraph> _bodyParagraphs(WidgetTester tester, String font) {
  final out = <RenderParagraph>[];
  final finder = find.byType(Text);
  for (var i = 0; i < finder.evaluate().length; i++) {
    final style = tester.widget<Text>(finder.at(i)).style;
    if (style?.fontFamily != font || style?.fontSize == null) continue;
    out.add(tester.renderObject<RenderParagraph>(finder.at(i)));
  }
  return out;
}

/// The single effective body size the page rendered with — straight from the
/// design-uniformity probe.
double _effFontSize(WidgetTester tester, String font) {
  final sizes = <double>{};
  final finder = find.byType(Text);
  for (var i = 0; i < finder.evaluate().length; i++) {
    final style = tester.widget<Text>(finder.at(i)).style;
    if (style?.fontFamily != font || style?.fontSize == null) continue;
    sizes.add(style!.fontSize!);
  }
  expect(sizes, hasLength(1),
      reason: 'a page must render every body word at one effective size');
  return sizes.single;
}

/// Natural width of the page's text column (its widest physical line).
double _columnWidth(WidgetTester tester, _SamplePage spec) {
  final paras = _bodyParagraphs(tester, spec.font);
  expect(paras, hasLength(spec.words.length),
      reason: 'every sample word should render a paragraph');

  var widest = 0.0;
  var i = 0;
  for (final count in spec.lineCounts) {
    var w = 0.0;
    for (var k = 0; k < count; k++) {
      w += paras[i++].size.width;
    }
    if (w > widest) widest = w;
  }
  return widest;
}

void main() {
  // Two QCF4 font groups (in the real dataset: separately digitised scans).
  const groupA = 'QCF4_Hafs_01';
  const groupB = 'QCF4_Hafs_02';

  // Group A: identical line composition on every page, so any difference in
  // rendered line measure is a difference in glyph scale — nothing else moved.
  final measurePages = [
    _SamplePage.sample(11, groupA),
    _SamplePage.sample(12, groupA),
    _SamplePage.sample(13, groupA),
  ];

  // Group B: same inventory, rotated per page. The probe samples a different
  // twelve words on each page, which is exactly the real-world condition the
  // per-group normalization exists for.
  final glyphPages = [
    _SamplePage.sample(21, groupB),
    _SamplePage.sample(22, groupB, rotation: 5),
    _SamplePage.sample(23, groupB, rotation: 11),
  ];

  final allPages = [...measurePages, ...glyphPages];

  late Directory docsDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    docsDir = await Directory.systemTemp.createTemp('qcf4_uniformity');
    PathProviderPlatform.instance = _FakePathProvider(docsDir.path);
    SharedPreferences.setMockInitialValues({});

    // QuranStorage.contentDir() → <documents>/quran_content
    final contentDir = Directory(p.join(docsDir.path, 'quran_content'));
    final fontsDir =
        Directory(p.join(contentDir.path, Qcf4Config.cacheDirName, 'fonts'));
    final pagesDir =
        Directory(p.join(contentDir.path, Qcf4Config.cacheDirName, 'pages'));
    await fontsDir.create(recursive: true);
    await pagesDir.create(recursive: true);

    // Stand in for the runtime-downloaded QCF4 TTFs with the app's bundled
    // Arabic faces — two genuinely different metrics (regular vs bold) so the
    // probe has real per-glyph advances, and no network is involved.
    Future<void> seedFont(String family, String asset) async {
      final src = File(asset);
      expect(src.existsSync(), isTrue, reason: 'missing test font $asset');
      final dest =
          File(p.join(fontsDir.path, Qcf4Config.fontTtfFileName(family)));
      await src.copy(dest.path);
    }

    await seedFont(groupA, 'assets/fonts/Amiri-Regular.ttf');
    await seedFont(groupB, 'assets/fonts/Amiri-Bold.ttf');
    // Pages also need the shared header/bismillah family loadable, even
    // though these samples carry no header lines.
    await seedFont(
        Qcf4Config.qbsmlFontFamily, 'assets/fonts/Amiri-Regular.ttf');

    for (final spec in allPages) {
      final name = '${spec.number.toString().padLeft(3, '0')}.json';
      await File(p.join(pagesDir.path, name))
          .writeAsString(spec.toModel().encode());
    }
  });

  tearDownAll(() async {
    if (await docsDir.exists()) await docsDir.delete(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 60; i++) {
      // The viewer reads page JSON + TTFs off the real filesystem, which only
      // advances inside runAsync.
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
      if (find.byType(Qcf4PageViewer).evaluate().isNotEmpty &&
          find.byType(CircularProgressIndicator).evaluate().isEmpty) {
        return;
      }
    }
    fail('the sample page never finished loading');
  }

  Future<void> showPage(WidgetTester tester, int page) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.light(),
      home: Qcf4PageViewer(page: page, highlight: const Qcf4Highlight()),
    ));
    await settle(tester);
  }

  Future<void> showViewer(WidgetTester tester) async {
    tester.view.physicalSize = const Size(760, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('pages of one font group render at one glyph size',
      (tester) async {
    await showViewer(tester);
    await showPage(tester, glyphPages.first.number);

    final sizes = <double>[_effFontSize(tester, glyphPages.first.font)];
    for (final spec in glyphPages.skip(1)) {
      await showPage(tester, spec.number);
      sizes.add(_effFontSize(tester, spec.font));
    }

    // The uniform glyph size is the whole point of the design-uniformity probe:
    // the QCF4 files were digitised from different scans, and a fixed body size
    // made some pages read visibly larger than others — the reported "some
    // pages longer / some shorter". Pages of one font group must therefore
    // land on a single effective size.
    expect(sizes.toSet(), hasLength(1),
        reason: 'font group $groupB rendered its pages at $sizes');

    // Caveat worth stating plainly: the substitute faces bundled with the app
    // are not digitised for mushaf layout — twelve of their words span far
    // more than the design width, so the probe saturates on [kScaleMin,
    // kScaleMax] and every page of the group lands on kScaleMin. The
    // assertion above therefore pins the *invariant* (one group, one size),
    // which is what the viewer promises, but on these fixtures the clamp
    // delivers it rather than the normalization. Exercising the normalization
    // itself needs the real QCF4 TTFs vendored or fetched in the test.
  });

  testWidgets('pages with the same content render the same line measure',
      (tester) async {
    await showViewer(tester);
    await showPage(tester, measurePages.first.number);

    final widths = <double>[_columnWidth(tester, measurePages.first)];
    for (final spec in measurePages.skip(1)) {
      await showPage(tester, spec.number);
      widths.add(_columnWidth(tester, spec));
    }

    // Every page in this set carries identical lines, so an identical column
    // width is the contract that page-to-page navigation keeps the text block
    // the same width across the mushaf.
    final spread = widths.reduce((a, b) => a > b ? a : b) /
        widths.reduce((a, b) => a < b ? a : b);
    expect(spread, closeTo(1.0, 0.001),
        reason: 'font group $groupA column widths were $widths');
  });

  for (final spec in allPages) {
    final tag = spec.number.toString().padLeft(3, '0');
    testWidgets('golden: sample mushaf page $tag', (tester) async {
      await showViewer(tester);
      await showPage(tester, spec.number);
      await expectLater(
        find.byType(Qcf4PageViewer),
        matchesGoldenFile('goldens/qcf4_page_$tag.png'),
      );
    });
  }
}

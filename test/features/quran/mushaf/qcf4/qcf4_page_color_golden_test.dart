// Golden test: the mushaf page as the palette paints it.
//
// The palette's contracts (page ink, recited-ayah ink, saved-marker band) are
// asserted as colour maths in `mushaf_palette_test.dart`, but maths alone
// cannot catch the failure this file exists for: the *rendering* quietly
// drifting from the palette — a band re-alphaed at the paint site, the recited
// ink replaced by a constant, a paper handed the wrong ink. So the page is
// rendered through the real `Qcf4PageViewer` with the reader's own colour
// decisions applied, and the pixels are pinned across three papers (pale cream,
// the tight mid-brown, a night paper) and three picks (the emerald default, the
// warm amber that has the least headroom, and a cool indigo).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_backgrounds.dart';
import 'package:tawheeed/features/quran/mushaf/qcf4/qcf4_config.dart';
import 'package:tawheeed/features/quran/mushaf/qcf4/qcf4_models.dart';
import 'package:tawheeed/features/quran/mushaf/qcf4/qcf4_page_viewer.dart';

/// Documents-dir stand-in so the QCF4 cache resolves under a temp directory.
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.documentsPath);

  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

const String _font = 'QCF4_Hafs_01';
const int _page = 41;

/// The verse the reader is "reciting" in these renders, and the ones carrying
/// saved markers.
const int _recitedAyah = 6;
const String _markedAyah = '1:2';

/// One synthetic page of real Arabic words, each carrying a `sura:ayah` key so
/// the saved-marker band has a verse to attach to.
Qcf4Page _samplePage() {
  const words = <String>[
    'وَ', 'فِي', 'مِنْ', 'قَدْ', 'لَمْ', 'هُمْ', //
    'هُوَ', 'بِهِ', 'مَعَ', 'إِنَّ', 'أَنْ', 'كَانَ',
  ];
  final lines = <Qcf4Line>[];
  var i = 0;
  for (var line = 1; line <= 3; line++) {
    final lineWords = <Qcf4Word>[];
    for (var k = 0; k < 4; k++, i++) {
      lineWords.add(Qcf4Word(
        char: words[i],
        font: _font,
        type: 'word',
        verseKey: '1:${i + 1}',
        position: k + 1,
      ));
    }
    lines.add(Qcf4Line(line: line, words: lineWords));
  }
  return Qcf4Page(page: _page, font: _font, surahs: const [], lines: lines);
}

MushafBackground _paper(String name) =>
    kMushafBackgrounds.firstWhere((b) => b.name == name);

MushafRecitationColor _pick(String name) =>
    kMushafRecitationColors.firstWhere((c) => c.name == name);

/// ASCII slugs so the golden file names stay portable.
const Map<String, String> _slug = {
  'کرم': 'cream',
  'خرمایی': 'tan',
  'شب شکلاتی': 'night',
  'سبز زمردی': 'emerald',
  'کهربایی': 'amber',
  'نیلی': 'indigo',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A pale paper, the mid-brown where the highlight has the least headroom, and
  // a night paper — the three regimes the palette rules branch on.
  final papers = ['کرم', 'خرمایی', 'شب شکلاتی'].map(_paper).toList();
  final picks = ['سبز زمردی', 'کهربایی', 'نیلی'].map(_pick).toList();

  late Directory docsDir;

  setUpAll(() async {
    docsDir = await Directory.systemTemp.createTemp('qcf4_colors');
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
    // Arabic face: real glyph advances, and no network involved.
    Future<void> seedFont(String family, String asset) async {
      final src = File(asset);
      expect(src.existsSync(), isTrue, reason: 'missing test font $asset');
      await src.copy(p.join(fontsDir.path, Qcf4Config.fontTtfFileName(family)));
    }

    await seedFont(_font, 'assets/fonts/Amiri-Regular.ttf');
    await seedFont(
        Qcf4Config.qbsmlFontFamily, 'assets/fonts/Amiri-Regular.ttf');

    await File(
            p.join(pagesDir.path, '${_page.toString().padLeft(3, '0')}.json'))
        .writeAsString(_samplePage().encode());
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

  /// Renders the page on [paper] with the reader's own colour decisions: the
  /// page ink, the saved-marker band on [_markedAyah], and the recited ayah's
  /// ink and band on [_recitedAyah].
  /// The recitation ink the reader's pick resolves to on [paper] — the colour
  /// of the recited ayah's glyphs, and the colour its wash is derived from.
  Color inkOn(MushafBackground paper, MushafRecitationColor pick) =>
      mushafRecitationInkOn(paper.color, pick.color);

  Future<void> showPage(
    WidgetTester tester,
    MushafBackground paper,
    MushafRecitationColor pick,
  ) async {
    final ink = inkOn(paper, pick);
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: RepaintBoundary(
          key: const ValueKey('paper'),
          child: Container(
            color: paper.color,
            child: Qcf4PageViewer(
              page: _page,
              highlight: const Qcf4Highlight(surah: 1, ayah: _recitedAyah),
              highlightColor: ink,
              recitationWash: mushafLiveAyahWashOn(paper.color, ink),
              verseTints: {
                _markedAyah: mushafAyahBandOn(paper.color, pick.color),
              },
              textColor: mushafPageInk(paper.color),
              fontSize: 26,
              lineHeight: 1.5,
              verseMarkerColor: mushafNeedsLightInk(paper.color)
                  ? const Color(0xFFC9965C)
                  : const Color(0xFF7A4A21),
            ),
          ),
        ),
      ),
    ));
    await settle(tester);
  }

  Future<void> useDevice(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 560);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('the painted marker band is the palette-computed band',
      (tester) async {
    // The golden would happily pin a wrong colour; this says what the pixels are
    // supposed to be, so a re-alpha at the paint site fails with a readable
    // message instead of a mysterious image diff.
    await useDevice(tester);
    final paper = _paper('خرمایی');
    final pick = _pick('کهربایی');
    await showPage(tester, paper, pick);

    final painted = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .map((decoration) => decoration.color)
        .whereType<Color>();

    expect(painted, contains(mushafAyahBandOn(paper.color, pick.color)),
        reason: 'the viewer must paint the band the palette computed, not a '
            'raw wash of the picked colour');
  });

  testWidgets('the painted recitation wash is the palette-computed wash',
      (tester) async {
    // The live tint is derived from the paper (its legibility contract depends
    // on it), so a paint site that re-derives its own alpha — or that forgets
    // the paper entirely — would go unnoticed by the goldens alone.
    await useDevice(tester);
    final paper = _paper('کرم');
    final pick = _pick('سبز زمردی');
    final ink = inkOn(paper, pick);
    await showPage(tester, paper, pick);

    final wash = mushafLiveAyahWashOn(paper.color, ink);
    final painted = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .map((decoration) => decoration.color)
        .whereType<Color>();

    expect(painted, contains(wash),
        reason: 'the viewer must paint the palette wash for this paper, not a '
            'fixed alpha of the recitation ink re-derived at the paint site');
    // They wrap the recited ayah's own glyphs, so the sweep has to hold for the
    // text on top of them — on «کرم» the tint survives untouched.
    expect(wash.toARGB32(),
        Color.lerp(paper.color, ink, kMushafLiveAyahAlpha)!.toARGB32(),
        reason: 'a paper with headroom must keep the shipped 16% tint');
    expect(
      mushafContrastRatio(ink, wash),
      greaterThanOrEqualTo(kMushafMinHighlightContrast - 0.01),
      reason: 'the recited ayah must stay legible on its own tint',
    );
  });

  testWidgets('the tint gives way where the glyphs have no contrast to spare',
      (tester) async {
    // «خرمایی» + «کهربایی» is the pair with the least headroom: its ink sits
    // exactly on the floor, so the wash cannot be painted at full strength
    // without taking the recited ayah under it. Legibility wins, and the ayah
    // is still marked by its own ink colour.
    await useDevice(tester);
    final paper = _paper('خرمایی');
    final pick = _pick('کهربایی');
    final ink = inkOn(paper, pick);
    await showPage(tester, paper, pick);

    final wash = mushafLiveAyahWashOn(paper.color, ink);
    expect(
      mushafColorDistance(wash, paper.color),
      lessThan(mushafColorDistance(
          Color.lerp(paper.color, ink, kMushafLiveAyahAlpha)!, paper.color)),
      reason: 'the full-strength tint would drop the glyphs below the floor '
          'on this paper — it must have been softened',
    );
    expect(
      mushafContrastRatio(ink, wash),
      greaterThanOrEqualTo(kMushafMinHighlightContrast - 0.01),
      reason: 'the guarantee must hold on the tightest pair in the palette',
    );
  });

  for (final paper in papers) {
    for (final pick in picks) {
      final paperSlug = _slug[paper.name]!;
      final pickSlug = _slug[pick.name]!;
      testWidgets('golden: $paperSlug paper, $pickSlug marker', (tester) async {
        await useDevice(tester);
        await showPage(tester, paper, pick);
        await expectLater(
          find.byKey(const ValueKey('paper')),
          matchesGoldenFile('goldens/qcf4_colors_${paperSlug}_$pickSlug.png'),
        );
      });
    }
  }
}

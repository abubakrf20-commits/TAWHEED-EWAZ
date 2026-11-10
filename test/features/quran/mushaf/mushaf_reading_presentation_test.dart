import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_palette.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_reading.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// The reading surface the tafsir and translation sheets share: nothing is
/// boxed — the ayah keeps the reader's own face one step larger in its own ink,
/// the translation or tafsir follows in the plain body ink, both sheets turn
/// their pages on the same hairline foot pager, and the words are selectable so
/// a passage can be copied.
void main() {
  const palette = MushafPalette.light;

  Widget host(Widget child) => MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: child),
        ),
      );

  group('quoted ayah', () {
    testWidgets('reads in the app face, not the Amiri tafsir face',
        (tester) async {
      await tester.pumpWidget(host(const MushafPassageAyah(
        text: 'بسم الله الرحمن الرحيم',
        palette: palette,
      )));

      final text = tester.widget<Text>(find.text('بسم الله الرحمن الرحيم'));
      final context = tester.element(find.byType(MushafPassageAyah));

      expect(text.style?.fontFamily, AppTheme.fontFamily);
      expect(text.style?.fontFamily, isNot('Amiri'));
      expect(text.style?.fontSize, AppTheme.scaledFontSize(context, 17));
      expect(
        text.style!.fontSize!,
        greaterThan(AppTheme.scaledFontSize(context, 14)),
      );
      expect(text.style?.fontWeight, FontWeight.w600);
      expect(text.textDirection, TextDirection.rtl);
      expect(text.textAlign, TextAlign.right);
    });

    testWidgets('wears its own ink, distinct from the body ink',
        (tester) async {
      await tester.pumpWidget(host(const MushafPassageAyah(
        text: 'الحمد لله',
        palette: palette,
      )));

      final text = tester.widget<Text>(find.text('الحمد لله'));
      expect(text.style?.color, mushafAyahInk(palette));
      expect(text.style?.color, isNot(palette.surfaceText));
      expect(text.style?.color, isNot(palette.accent));
    });

    testWidgets('stands on the page with no box around it', (tester) async {
      await tester.pumpWidget(host(const MushafPassageAyah(
        text: 'قل هو الله أحد',
        palette: palette,
      )));

      final ayah = find.byType(MushafPassageAyah);
      for (final box in <Finder>[
        find.byType(Container),
        find.byType(DecoratedBox),
        find.byType(ColoredBox),
        find.byType(Card),
        find.byType(Material),
      ]) {
        expect(
          find.descendant(of: ayah, matching: box),
          findsNothing,
          reason: 'the quoted ayah must never sit in a box',
        );
      }
      expect(
        tester.getSize(ayah).width,
        tester.getSize(find.byType(Scaffold)).width,
      );
    });

    testWidgets('a lifted base size stays on the shared type scale',
        (tester) async {
      await tester.pumpWidget(host(const MushafPassageAyah(
        text: 'قل هو الله أحد',
        palette: palette,
        baseSize: 19,
      )));

      final text = tester.widget<Text>(find.text('قل هو الله أحد'));
      final context = tester.element(find.byType(MushafPassageAyah));

      expect(text.style?.fontSize, AppTheme.scaledFontSize(context, 19));
      expect(
        text.style!.fontSize!,
        greaterThan(AppTheme.scaledFontSize(context, 17)),
      );
      expect(AppTheme.typeScale, contains(text.style!.fontSize!));
    });

    test('the ink clears the 4.5 floor on the page in both palettes', () {
      for (final p in [MushafPalette.light, MushafPalette.night]) {
        expect(
          _contrast(mushafAyahInk(p), p.surface),
          greaterThanOrEqualTo(4.5),
          reason: 'quoted ayah on the bare paper',
        );
      }
    });

    test('the mix buys depth the bare accent does not have', () {
      for (final p in [MushafPalette.light, MushafPalette.night]) {
        expect(
          _contrast(mushafAyahInk(p), p.surface),
          greaterThan(_contrast(p.accent, p.surface)),
          reason: 'the ayah must read above commentary that wears the accent',
        );
      }
    });
  });

  group('page rail', () {
    testWidgets('the folio prints the word and the number, read as one label',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(host(const MushafSheetFolio(
        palette: palette,
        page: 42,
      )));

      expect(find.text('صفحه'), findsOneWidget);
      expect(find.text(NumberFormat.en(42)), findsOneWidget);
      expect(
        tester.widget<Semantics>(find.descendant(
          of: find.byType(MushafSheetFolio),
          matching: find.byType(Semantics),
        ).first).properties.label,
        'صفحهٔ ${NumberFormat.en(42)}',
      );

      semantics.dispose();
    });

    testWidgets('previous sits right of the folio and next left of it',
        (tester) async {
      var prev = 0;
      var next = 0;
      await tester.pumpWidget(host(SizedBox(
        width: 380,
        child: MushafSheetPager(
          palette: palette,
          page: 7,
          onPrevious: () => prev++,
          onNext: () => next++,
        ),
      )));

      final previous = tester.getRect(find.byType(MushafSheetRailButton).at(0));
      final folio = tester.getRect(find.byType(MushafSheetFolio));
      final following = tester.getRect(find.byType(MushafSheetRailButton).at(1));

      expect(previous.center.dx, greaterThan(folio.center.dx));
      expect(following.center.dx, lessThan(folio.center.dx));

      await tester.tap(find.text('صفحهٔ قبلی'));
      await tester.tap(find.text('صفحهٔ بعدی'));
      expect(prev, 1);
      expect(next, 1);
    });

    testWidgets('the foot closes on a single hairline over the page',
        (tester) async {
      await tester.pumpWidget(host(MushafSheetPager(
        palette: palette,
        page: 7,
        onPrevious: () {},
        onNext: () {},
      )));

      final root = tester.widget<DecoratedBox>(find
          .descendant(
            of: find.byType(MushafSheetPager),
            matching: find.byType(DecoratedBox),
          )
          .first);
      final border = (root.decoration as BoxDecoration).border! as Border;

      expect(border.top.color, palette.border);
      expect(border.top.style, BorderStyle.solid);
      expect(border.left, BorderSide.none);
      expect(border.right, BorderSide.none);
      expect(border.bottom, BorderSide.none);
    });

    testWidgets('a step is a glyph over its word, on a 52 dp target',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(MushafSheetRailButton(
        palette: palette,
        icon: Icons.arrow_back,
        label: 'صفحهٔ قبلی',
        onTap: () => taps++,
      )));

      final button = tester.widget<TextButton>(find.byType(TextButton));
      expect(
        button.style!.minimumSize!.resolve(const <WidgetState>{}),
        const Size(52, 46),
      );
      expect(button.style!.tapTargetSize, MaterialTapTargetSize.shrinkWrap);
      expect(
        button.style!.shape!.resolve(const <WidgetState>{}),
        isA<RoundedRectangleBorder>(),
      );

      final label = tester.widget<Text>(find.text('صفحهٔ قبلی'));
      expect(label.style?.color, palette.accent);
      expect(label.maxLines, 2);
      expect(
        tester.getRect(find.byType(Icon)).bottom,
        lessThanOrEqualTo(tester.getRect(find.text('صفحهٔ قبلی')).top),
      );

      await tester.tap(find.byType(TextButton));
      expect(taps, 1);
    });

    testWidgets('a disabled step goes quiet instead of spinning',
        (tester) async {
      await tester.pumpWidget(host(const MushafSheetRailButton(
        palette: palette,
        icon: Icons.arrow_forward,
        label: 'صفحهٔ بعدی',
        onTap: null,
      )));

      expect(
        tester.widget<TextButton>(find.byType(TextButton)).onPressed,
        isNull,
      );
      expect(
        tester.widget<Text>(find.text('صفحهٔ بعدی')).style?.color,
        palette.surfaceMuted.withValues(alpha: 0.45),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('a busy page turn locks both steps and quiets the folio',
        (tester) async {
      var prev = 0;
      var next = 0;
      await tester.pumpWidget(host(MushafSheetPager(
        palette: palette,
        page: 42,
        onPrevious: () => prev++,
        onNext: () => next++,
        busy: true,
      )));

      final buttons = tester.widgetList<TextButton>(find.byType(TextButton));
      expect(buttons, hasLength(2));
      expect(buttons.every((b) => b.onPressed == null), isTrue);
      expect(
        tester.widget<MushafSheetFolio>(find.byType(MushafSheetFolio)).dimmed,
        isTrue,
      );
      expect(
        tester.widget<Text>(find.text('صفحه')).style?.color,
        palette.surfaceMuted.withValues(alpha: 0.4),
      );
      expect(
        tester.widget<Text>(find.text(NumberFormat.en(42))).style?.color,
        palette.surfaceMuted.withValues(alpha: 0.5),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.tap(find.text('صفحهٔ بعدی'), warnIfMissed: false);
      expect(prev + next, 0);
    });
  });

  group('tafsir verse turns', () {
    testWidgets('the verse steps ride the same foot pager as the translation',
        (tester) async {
      var previous = 0;
      var next = 0;
      await tester.pumpWidget(host(SizedBox(
        width: 360,
        child: MushafSheetPager(
          palette: palette,
          page: 7,
          previousLabel: 'آیهٔ قبلی',
          nextLabel: 'آیهٔ بعدی',
          onPrevious: () => previous++,
          onNext: () => next++,
        ),
      )));

      expect(find.text('آیهٔ قبلی'), findsOneWidget);
      expect(find.text('آیهٔ بعدی'), findsOneWidget);

      final previousRect =
          tester.getRect(find.byType(MushafSheetRailButton).at(0));
      final folio = tester.getRect(find.byType(MushafSheetFolio));
      final nextRect =
          tester.getRect(find.byType(MushafSheetRailButton).at(1));
      expect(previousRect.center.dx, greaterThan(folio.center.dx));
      expect(nextRect.center.dx, lessThan(folio.center.dx));

      await tester.tap(find.text('آیهٔ قبلی'));
      await tester.tap(find.text('آیهٔ بعدی'));
      expect(previous, 1);
      expect(next, 1);
    });

    testWidgets('a busy verse turn locks both steps and quiets the folio',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(MushafSheetPager(
        palette: palette,
        page: 7,
        previousLabel: 'آیهٔ قبلی',
        nextLabel: 'آیهٔ بعدی',
        onPrevious: () => taps++,
        onNext: () => taps++,
        busy: true,
      )));

      final buttons = tester.widgetList<TextButton>(find.byType(TextButton));
      expect(buttons, hasLength(2));
      expect(buttons.every((b) => b.onPressed == null), isTrue);
      expect(
        tester.widget<MushafSheetFolio>(find.byType(MushafSheetFolio)).dimmed,
        isTrue,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.tap(find.text('آیهٔ بعدی'), warnIfMissed: false);
      expect(taps, 0);
    });
  });

  group('sheet header', () {
    testWidgets('one centred two-line title over a grab handle',
        (tester) async {
      await tester.pumpWidget(host(const MushafContentSheetHeader(
        palette: palette,
        title: 'تفسیر آیه ۷',
        subtitle: 'البقرة',
      )));

      final title = tester.widget<Text>(find.text('تفسیر آیه ۷'));
      expect(title.textAlign, TextAlign.center);
      expect(title.maxLines, 2);
      expect(title.style?.fontWeight, FontWeight.w800);
      expect(title.style?.fontFamily, AppTheme.fontFamily);
      expect(find.text('البقرة'), findsOneWidget);

      final handles = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) =>
              c.decoration is BoxDecoration &&
              (c.decoration! as BoxDecoration).color ==
                  palette.accent.withValues(alpha: 0.32))
          .toList();
      expect(handles, hasLength(1));
      expect(tester.getSize(find.byWidget(handles.single)), const Size(40, 4));
    });

    testWidgets('the compact header keeps the title and its action on one line',
        (tester) async {
      await tester.pumpWidget(host(MushafContentSheetHeader.compact(
        palette: palette,
        title: 'تفسیر آیهٔ ۷ · البقرة',
        actions: [
          MushafSheetAction(
            palette: palette,
            icon: Icons.share_outlined,
            label: 'اشتراک',
            onTap: () {},
          ),
        ],
      )));

      final title = tester.widget<Text>(find.text('تفسیر آیهٔ ۷ · البقرة'));
      expect(title.maxLines, 1);
      expect(title.textAlign, TextAlign.center);
      expect(title.style?.fontWeight, FontWeight.w800);

      // Only the title and the action's own label — a second text row (the
      // retired subtitle) would make three.
      expect(find.byType(Text), findsNWidgets(2));

      final titleRect = tester.getRect(find.text('تفسیر آیهٔ ۷ · البقرة'));
      final actionRect = tester.getRect(find.byType(TextButton));
      expect(titleRect.top, lessThan(actionRect.bottom));
      expect(actionRect.top, lessThan(titleRect.bottom));
      expect(actionRect.center.dx, lessThan(titleRect.center.dx));
    });

    testWidgets('closes on a single hairline', (tester) async {
      await tester.pumpWidget(host(const MushafContentSheetHeader(
        palette: palette,
        title: 'ترجمه',
      )));

      final rules = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) => c.color == palette.border)
          .toList();
      expect(rules, hasLength(1));
      expect(tester.getSize(find.byWidget(rules.single)).height, 1);
    });

    testWidgets('an action is a quiet 44 dp target and reaches the handler',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(MushafSheetAction(
        palette: palette,
        icon: Icons.share_outlined,
        label: 'اشتراک',
        onTap: () => taps++,
      )));

      final button = tester.widget<TextButton>(find.byType(TextButton));
      expect(
        button.style!.minimumSize!.resolve(const <WidgetState>{}),
        const Size(0, 44),
      );
      expect(button.style!.tapTargetSize, MaterialTapTargetSize.shrinkWrap);
      expect(button.style!.shape!.resolve(const <WidgetState>{}),
          isA<RoundedRectangleBorder>());

      await tester.tap(find.byType(TextButton));
      expect(taps, 1);
    });

    testWidgets('a disabled action cannot be pressed', (tester) async {
      await tester.pumpWidget(host(MushafSheetAction(
        palette: palette,
        icon: Icons.share_outlined,
        label: 'اشتراک',
        onTap: () {},
        enabled: false,
      )));

      expect(
        tester.widget<TextButton>(find.byType(TextButton)).onPressed,
        isNull,
      );
    });
  });

  group('the page’s ornament', () {
    testWidgets('is a hairline broken once by a diamond, never a fill',
        (tester) async {
      await tester.pumpWidget(host(const Center(
        child: SizedBox(
          width: 220,
          child: MushafRuleOrnament(palette: palette),
        ),
      )));

      final containers = tester
          .widgetList<Container>(find.descendant(
            of: find.byType(MushafRuleOrnament),
            matching: find.byType(Container),
          ))
          .toList();
      // Two rules and the mark's own square — nothing else is drawn.
      expect(containers, hasLength(3));

      final rules = containers.where((c) => c.color == palette.border).toList();
      expect(rules, hasLength(2));
      for (final rule in rules) {
        expect(tester.getSize(find.byWidget(rule)).height, 1);
      }

      expect(find.byType(MushafDiamond), findsOneWidget);
      final ornament = tester.getCenter(find.byType(MushafRuleOrnament));
      final diamond = tester.getCenter(find.byType(MushafDiamond));
      expect(diamond.dx, closeTo(ornament.dx, 0.5));
      expect(diamond.dy, closeTo(ornament.dy, 0.5));
    });

    testWidgets('the diamond is a turned solid square, with no decoration',
        (tester) async {
      await tester.pumpWidget(host(const Center(
        child: MushafDiamond(palette: palette, size: 9, alpha: 0.4),
      )));

      final transform = tester.widget<Transform>(find.descendant(
        of: find.byType(MushafDiamond),
        matching: find.byType(Transform),
      ));
      final matrix = transform.transform;
      expect(matrix.entry(0, 0), closeTo(math.cos(math.pi / 4), 1e-9));
      expect(matrix.entry(1, 0), closeTo(math.sin(math.pi / 4), 1e-9));
      expect(matrix.entry(0, 1), closeTo(-math.sin(math.pi / 4), 1e-9));

      final square = tester.widget<Container>(find.descendant(
        of: find.byType(MushafDiamond),
        matching: find.byType(Container),
      ));
      expect(square.color, palette.accent.withValues(alpha: 0.4));
      expect(square.decoration, isNull);
      expect(square.foregroundDecoration, isNull);
      expect(tester.getSize(find.byWidget(square)), const Size(9, 9));
    });
  });

  group('sheets ride the kit', () {
    test('the tafsir keeps the ayah above its commentary and turns the verse '
        'at the foot, never in a card', () {
      final source = _sliceOf(
        'lib/features/quran/mushaf/quran_mushaf_sheets.dart',
        'class MushafTafsirSheetState',
        '/// Catalog row for a content file',
      );

      expect(source, contains('kMushafContentSheetHeightFraction'));
      expect(source, contains('MushafContentSheetHeader.compact('));
      expect(source, contains('getSurahNameArabic(_surah)'));
      expect(source, contains('MushafPassageAyah('));
      expect(source, contains('baseSize: 19'));
      expect(source, contains('TafsirText('));
      expect(source, contains('mushafAyahInk('));
      expect(source, contains('MushafRuleOrnament('));
      expect(source, contains('MushafDiamond('));
      expect(source, contains('SelectionArea('));
      expect('MushafSheetAction('.allMatches(source), hasLength(1));
      expect(source, contains('MushafSheetPager('));
      expect(source, contains("previousLabel: 'آیهٔ قبلی'"));
      expect(source, contains("nextLabel: 'آیهٔ بعدی'"));
      expect(source, contains('page: getPageNumber(_surah, _verse)'));
      expect(source, contains('busy: _loading'));
      expect(source, isNot(contains('_VerseNavButton')));
      expect(source, isNot(contains('MushafTafsirMargin(')));
      expect(source, isNot(contains('Card(')));
      expect(source, isNot(contains('Divider(')));
      expect(source, isNot(contains('alpha: 0.08')));
      expect(source, isNot(contains('alpha: 0.03')));
    });

    test('the translation turns the page on the foot pager under the verses',
        () {
      final source = _sliceOf(
        'lib/features/quran/mushaf/quran_mushaf_content_sheets.dart',
        'class _TranslationSheetState',
        '/// Bottom sheet listing every verse',
      );

      expect(source, contains('kMushafContentSheetHeightFraction'));
      expect(source, contains('MushafContentSheetHeader('));
      expect(source, contains('mushafAyahTextStyle('));
      expect(source, contains('_SheetSurahHeading('));
      expect(source, contains('MushafRuleOrnament('));
      expect(source, contains('.unicodeText'));
      expect(source, contains('ListView.builder('));
      expect(source, contains('SelectionArea('));
      expect(source, contains('MushafSheetPager('));
      expect(source, contains('onPrevious: _page > 1'));
      expect(source, contains('onNext: _page < QuranApiConfig.mushafPageCount'));
      expect(source, contains('widget.onPageChanged(target)'));
      expect(source, contains('_scroll.jumpTo(0)'));
      expect(source, contains('busy: _paging'));
      expect(source, isNot(contains('glyphV2')));
      expect(source, isNot(contains('QuranKitNumberTile(')));
      expect(source, isNot(contains('MushafTafsirMargin(')));
      expect(source, isNot(contains('Card(')));
      expect(source, isNot(contains('BoxDecoration')));
      expect(source, isNot(contains('Divider(')));
      expect(source, isNot(contains('alpha: 0.04')));
    });

    test('the scanner reads code, not prose', () {
      const prose = '// the old glyphV2 fallback and alpha: 0.04 wash\n'
          'const marker = 1; /* Divider(height: 1, color: palette.accent) */';
      final code = _withoutComments(prose);
      expect(code, isNot(contains('glyphV2')));
      expect(code, isNot(contains('alpha: 0.04')));
      expect(code, isNot(contains('Divider(')));
      expect(code, contains('const marker = 1;'));
    });
  });
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// The sheet classes share files with older surfaces (the content manager and
/// the verse-follow sheet), which still own their own chrome — only the class
/// under review is scanned.
String _sliceOf(String path, String start, String end) {
  final source = File(path).readAsStringSync();
  final from = source.indexOf(start);
  final to = source.indexOf(end);
  expect(from, isNonNegative, reason: '$path is missing $start');
  expect(to, greaterThan(from), reason: '$path is missing $end after $start');
  return _withoutComments(source.substring(from, to));
}

/// Returns [source] with comments blanked out, newlines and offsets kept.
String _withoutComments(String source) {
  final out = StringBuffer();
  var i = 0;
  while (i < source.length) {
    final ch = source[i];
    final pair = i + 1 < source.length ? source.substring(i, i + 2) : '';
    if (pair == '//') {
      while (i < source.length && source[i] != '\n') {
        out.write(' ');
        i++;
      }
      continue;
    }
    if (pair == '/*') {
      var depth = 0;
      while (i < source.length) {
        if (source.startsWith('/*', i)) {
          depth++;
          i += 2;
          out.write('  ');
        } else if (source.startsWith('*/', i)) {
          depth--;
          i += 2;
          out.write('  ');
          if (depth == 0) break;
        } else {
          out.write(source[i] == '\n' ? '\n' : ' ');
          i++;
        }
      }
      continue;
    }
    if (ch == "'" || ch == '"') {
      final close = source.startsWith('$ch$ch$ch', i) ? '$ch$ch$ch' : ch;
      out.write(close);
      i += close.length;
      while (i < source.length) {
        if (source[i] == r'\' && i + 1 < source.length) {
          out.write(source.substring(i, i + 2));
          i += 2;
          continue;
        }
        if (source.startsWith(close, i)) {
          out.write(close);
          i += close.length;
          break;
        }
        out.write(source[i]);
        i++;
      }
      continue;
    }
    out.write(ch);
    i++;
  }
  return out.toString();
}

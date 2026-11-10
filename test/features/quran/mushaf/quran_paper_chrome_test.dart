import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_palette.dart';
import 'package:tawheeed/features/quran/mushaf/quran_paper_chrome.dart';

/// A lock on the mushaf's **paper chrome**.
///
/// The reader is theme-independent: its screens paint from a [MushafPalette],
/// never from the app's time theme. The three aux screens that are not the
/// immersive reader had each grown their own [AppBar] anyway — two on `chrome`,
/// one on `surface`, three title styles, `centerTitle` on two of the three and
/// `elevation` on one — so the same paper opened three different bars.
///
/// [quranPaperAppBar] is that recipe, once. This file holds both ends of it: a
/// widget test of the recipe itself (the ink, the zero lift, the centred title
/// and its on-scale 15), and a comment-stripped source scan that keeps the
/// three screens on the recipe while the immersive reader and the two share
/// screens stay off it.
void main() {
  // ── the recipe ────────────────────────────────────────────────────────────
  for (final entry in <(String, MushafPalette)>[
    ('light', MushafPalette.light),
    ('night', MushafPalette.night),
  ]) {
    testWidgets('the recipe paints the ${entry.$1} paper', (tester) async {
      final palette = entry.$2;
      final bar = await _pumpBar(tester, palette);

      expect(bar.backgroundColor, palette.chrome,
          reason: 'the bar is the paper\'s chrome, never its sheet: the search '
              'screen used to paint `surface` and opened a different bar');
      expect(bar.foregroundColor, palette.onChrome);
      expect(bar.elevation, 0);
      expect(bar.scrolledUnderElevation, 0,
          reason: 'paper does not lift under a scroll');
      expect(bar.centerTitle, isTrue,
          reason: 'the surah index used to start-align its title');

      final title = tester.widget<Text>(find.text(_title));
      final style = title.style;
      expect(style, isNotNull);
      expect(style!.fontFamily, AppTheme.fontFamily);
      expect(style.fontSize, 15,
          reason: '15 is a step on the shared type scale, so asking through '
              '`scaledFontSize` renders exactly the raw 15 the screens used '
              'to hand-type — but it can never drift off the scale again');
      expect(style.fontWeight, FontWeight.w700);
      expect(style.color, palette.onChrome);
    });
  }

  // ── the lock ──────────────────────────────────────────────────────────────
  const paperScreens = <String>[
    'lib/features/quran/presentation/screens/quran_bookmarks_screen.dart',
    'lib/features/quran/mushaf/quran_surah_list_screen.dart',
    'lib/features/quran/mushaf/quran_search_screen.dart',
  ];

  for (final path in paperScreens) {
    test('$path wears the paper bar instead of its own', () {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path is missing');

      final code = _withoutComments(file.readAsStringSync());

      expect(code, contains('quranPaperAppBar('),
          reason: 'every paper aux screen opens through the one recipe');
      expect(
        code,
        contains(
            "import 'package:tawheeed/features/quran/mushaf/quran_paper_chrome.dart';"),
        reason: 'a local copy of the recipe is the drift this file ends',
      );

      final bars = _rawBarFindings(code);
      expect(
        bars,
        isEmpty,
        reason: 'a second bar is how the three screens drifted apart in the '
            'first place — call `quranPaperAppBar`:\n'
            '${_where(path, code, bars)}',
      );

      final sizes = _rawSizeFindings(code);
      expect(
        sizes,
        isEmpty,
        reason: 'a hand-typed 15 is the bar title this recipe owns; use the '
            'recipe rather than re-typing its size:\n'
            '${_where(path, code, sizes)}',
      );
    });
  }

  test('the recipe is the only bar recipe for the paper', () {
    final code = _withoutComments(
      File('lib/features/quran/mushaf/quran_paper_chrome.dart')
          .readAsStringSync(),
    );

    expect(code, contains('palette.chrome'));
    expect(code, contains('palette.onChrome'));
    expect(code, contains('elevation: 0'));
    expect(code, contains('scrolledUnderElevation: 0'));
    expect(code, contains('centerTitle: true'));
    expect(code, contains('AppTheme.scaledFontSize(context, 15)'));
    expect(code, contains('AppTheme.fontFamily'));
    expect(code, contains('FontWeight.w700'));
  });

  test('the immersive reader and the share screens keep their own chrome', () {
    final tab = _withoutComments(
      File('lib/features/quran/presentation/screens/quran_tab.dart')
          .readAsStringSync(),
    );
    expect(tab, contains('QuranMushafView('));
    expect(_rawBarFindings(tab), isEmpty,
        reason: 'the immersive reader paints its own chrome over the page; '
            'the paper bar belongs to the aux screens only');

    for (final path in <String>[
      'lib/features/quran/mushaf/quran_ayah_share_screen.dart',
      'lib/features/quran/mushaf/quran_tafsir_share_screen.dart',
    ]) {
      final code = _withoutComments(File(path).readAsStringSync());
      expect(code, contains('AmbientBackground('),
          reason: '$path is an ambient surface, not a paper screen');
      expect(code, isNot(contains('quranPaperAppBar(')),
          reason: '$path is an `AmbientBackground` + `ShareCardPalette` '
              'surface — a different family from the reader\'s paper');
    }
  });

  test('the search spinner uses the reader\'s ink', () {
    final code = _withoutComments(
      File('lib/features/quran/mushaf/quran_search_screen.dart')
          .readAsStringSync(),
    );
    expect(
      code,
      contains('CircularProgressIndicator(color: palette.accent)'),
      reason: 'an untinted spinner is the app theme\'s accent on a paper it '
          'does not own; the bookmark list already tints its own',
    );
  });

  // ── the scanners themselves ───────────────────────────────────────────────
  // A guard that stops biting is worse than no guard, so each scanner is
  // driven against a snippet shaped like the regression it exists to catch.
  group('the locked regressions are actually caught', () {
    test('a raw bar is a finding, and the recipe is not', () {
      expect(
        _rawBarFindings('appBar: AppBar(backgroundColor: c.chrome)'),
        hasLength(1),
      );
      expect(
        _rawBarFindings('appBar: AppBar(\n  title: t,\n)'),
        hasLength(1),
        reason: 'the bar may open on the next line',
      );
      expect(
        _rawBarFindings('appBar: quranPaperAppBar(context, palette: p)'),
        isEmpty,
        reason: 'the recipe\'s own name must not trip the raw-bar scan — '
            'there is no word boundary inside `quranPaperAppBar`',
      );
      expect(_rawBarFindings('final String appBar;'), isEmpty);
    });

    test('a hand-typed bar size is a finding, the scaled step is not', () {
      expect(_rawSizeFindings('fontSize: 15,'), hasLength(1));
      expect(_rawSizeFindings('fontSize: 15.0,'), hasLength(1));
      expect(_rawSizeFindings('fontSize: 150,'), isEmpty);
      expect(
        _rawSizeFindings('fontSize: AppTheme.scaledFontSize(context, 15),'),
        isEmpty,
      );
    });

    test('comments are not chrome', () {
      expect(
        _rawBarFindings(_withoutComments('// AppBar(backgroundColor: c)')),
        isEmpty,
      );
      expect(
        _rawSizeFindings(_withoutComments('/* fontSize: 15 */')),
        isEmpty,
      );
      expect(_lineOf('a\nb\nc', 4), 3);
    });
  });
}

const String _title = 'فهرست سوره‌ها';

Future<AppBar> _pumpBar(WidgetTester tester, MushafPalette palette) async {
  late AppBar bar;
  await tester.pumpWidget(
    MaterialApp(
      // The recipe reads `bodyMedium` through `scaledFontSize`, and the app
      // theme sets it to 15. A bare `MaterialApp` answers 14 and would make
      // this test pin the wrong number.
      theme: AppTheme.light,
      home: Builder(
        builder: (context) {
          bar = quranPaperAppBar(context, palette: palette, title: _title);
          return Scaffold(appBar: bar);
        },
      ),
    ),
  );
  return bar;
}

/// `quranPaperAppBar(` never matches: the `r` before its `AppBar` is a word
/// character, so there is no word boundary there.
final RegExp _rawAppBar = RegExp(r'\bAppBar\s*\(');

/// The bar's hand-typed title size. `fontSize: 15` is what the three screens
/// carried before the recipe; 150 (or a scaled call) must not match.
final RegExp _rawBarTitleSize = RegExp(r'fontSize:\s*15\b');

List<int> _rawBarFindings(String code) => [
      for (final match in _rawAppBar.allMatches(code)) match.start,
    ];

List<int> _rawSizeFindings(String code) => [
      for (final match in _rawBarTitleSize.allMatches(code)) match.start,
    ];

/// Blanks `//` and `/* … */` comments while keeping every newline and offset,
/// so a finding still maps to the line a reader sees. String literals are
/// stepped over whole: a `//` inside a literal is not a comment.
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
      // Block comments nest in Dart.
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

int _lineOf(String code, int offset) =>
    '\n'.allMatches(code.substring(0, offset)).length + 1;

String _where(String path, String code, Iterable<int> offsets) =>
    offsets.map((offset) => '$path:${_lineOf(code, offset)}').join('\n');

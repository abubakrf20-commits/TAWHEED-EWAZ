import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/app/router/home_bottom_nav.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

/// The dark chrome follows the selected «تم برنامه» (user report: the header /
/// clock box, the quran header, the selected bottom tab and the
/// recitation/translation player header did not change colour with the theme).
///
/// All of it used to be painted from a *fixed* brown — `HomeColors.hero*`,
/// `[AppTheme.mocha, AppTheme.darkWalnut]`, `[0xFF5A4032, 0xFF2A1A12]` — which
/// is why the app theme never reached it. The reader chrome now reads the active
/// [AppPalette] through its `heroGradient` (or its two ends); the bottom nav
/// instead wears **its own section's hue**, deepened for the light bar and
/// lifted for the dark one (`HomeBottomNav.pillTop`/`pillBottom`).
///
/// Only the bottom nav is publicly pumpable; the reader header and the two
/// player pads are private parts of the mushaf library with no widget seam, so
/// a source guard stands in for them — the same idiom as
/// `quran/mushaf/download_hero_style_test.dart`.
void main() {
  const chromeFiles = <String>[
    'lib/features/home/presentation/widgets/hero_card.dart',
    'lib/app/router/home_bottom_nav.dart',
    'lib/features/quran/mushaf/quran_reader_header.dart',
    'lib/features/quran/mushaf/quran_reader_player.dart',
  ];

  group('the dark chrome is painted from the palette, never a fixed brown', () {
    test('no chrome file keeps the retired brown literals', () {
      for (final path in chromeFiles) {
        final src = File(path).readAsStringSync();
        expect(src.contains('0xFF5A4032'), isFalse,
            reason: '$path still carries the retired reader/panel brown');
        expect(src.contains('0xFF2A1A12'), isFalse,
            reason: '$path still carries the retired panel brown end');
        expect(src.contains('HomeColors.hero'), isFalse,
            reason: '$path still reads the deleted HomeColors.hero* block');
      }
    });

    test('the home hero paints the active theme hero gradient', () {
      final src = File(
              'lib/features/home/presentation/widgets/hero_card.dart')
          .readAsStringSync();
      expect(src.contains('t.heroGradient'), isTrue,
          reason: 'the hero field must come from the palette');
      // The gradient is part of the repaint key, or a theme change never
      // repaints the already-laid-out field.
      expect(src.contains('old.hero[0] != hero[0]'), isTrue,
          reason: 'the palette colours must join shouldRepaint');
      // The orb and the bottom glow are palette tokens too, so a theme
      // switch moves the whole field and not only its gradient.
      expect(src.contains('AppPalette.heroGold'), isTrue,
          reason: 'the hero decoration must read the palette, not a '
              'fixed gold');
    });

    test('HomeColors no longer declares a hero block', () {
      final src = File(
              'lib/features/home/presentation/widgets/home_tokens.dart')
          .readAsStringSync();
      // Whole declarations, not a bare word: a *comment* may still name the
      // palette stop it happens to equal (`/// == dawn heroTop`).
      for (final name in [
        'static const Color heroTop',
        'heroUpper',
        'heroLower',
        'static const Color heroBottom',
      ]) {
        expect(src.contains(name), isFalse,
            reason: 'home_tokens.dart still declares $name');
      }
    });

    test('the reader header and both player pads share one palette gradient',
        () {
      final header = File(
              'lib/features/quran/mushaf/quran_reader_header.dart')
          .readAsStringSync();
      expect(header.contains('LinearGradient _readerChromeGradient'), isTrue,
          reason: 'the shared chrome builder must live in one place');
      expect(header.contains('.palette.heroGradient'), isTrue);

      final player = File(
              'lib/features/quran/mushaf/quran_reader_player.dart')
          .readAsStringSync();
      // Exactly two pads: the talaawah player and the translation player.
      expect(RegExp(r'_readerChromeGradient\(context\)').allMatches(player).length,
          2,
          reason: 'both player pads must use the shared chrome gradient');
    });

    test('the quran index list keeps the paper chrome, not the app theme', () {
      // The sibling lists are paper-driven by contract (see
      // `quran_bookmarks_screen_test.dart`: "chrome, paper and rows follow the
      // palette, not the app theme"). Only the reader's own header band and the
      // two player pads follow the app theme — do not "unify" the index list
      // onto the theme gradient without changing that contract first.
      //
      // Since `bc7ac89` the paper bar is the shared `quranPaperAppBar` (painted
      // from `_p.chrome`/`_p.onChrome`); the body sits on `_p.background`.
      // Naming that helper is the source proof that the list still answers to
      // the paper palette and never to the app theme.
      final src = File(
              'lib/features/quran/mushaf/quran_surah_list_screen.dart')
          .readAsStringSync();
      expect(src.contains('quranPaperAppBar('), isTrue,
          reason: 'the index list wears the shared paper bar');
      expect(src.contains('heroGradient'), isFalse);
    });
  });

  group('the bottom nav selected pill wears its own section hue', () {
    testWidgets('the pill stops are the section hue, deepened per brightness',
        (tester) async {
      final light = await _pumpNav(tester, isDark: false);
      expect(light, <Color>[
        HomeBottomNav.pillTop(SectionHues.home, false),
        HomeBottomNav.pillBottom(SectionHues.home, false),
      ]);

      final dark = await _pumpNav(tester, isDark: true);
      expect(dark, <Color>[
        HomeBottomNav.pillTop(SectionHues.home, true),
        HomeBottomNav.pillBottom(SectionHues.home, true),
      ]);

      // Guard the guard: equal stops would let both assertions above pass while
      // nothing actually changed with the brightness.
      expect(light.first == dark.first, isFalse,
          reason: 'the top stop deepens on the light bar, lifts on the dark one');
      expect(light.last == dark.last, isFalse,
          reason: 'the bottom stop follows the brightness too');
    });
  });

  group('every palette supplies its own hero gradient', () {
    test('heroGradient is exactly the three hero stops', () {
      for (final p in const <AppPalette>[
        AppPalettes.goldLight,
        AppPalettes.goldDark,
        AppPalettes.dawnLight,
        AppPalettes.dawnDark,
        AppPalettes.dayLight,
        AppPalettes.dayDark,
        AppPalettes.sunsetLight,
        AppPalettes.sunsetDark,
        AppPalettes.nightLight,
        AppPalettes.nightDark,
      ]) {
        expect(p.heroGradient, <Color>[p.heroTop, p.heroMid, p.heroBottom]);
      }
    });
  });
}

/// Pumps the nav over the app's own light or dark theme.
///
/// `AppTheme.light` is always `Brightness.light` and `AppTheme.dark` always
/// `Brightness.dark`, and the pill hue is a per-tab constant, so brightness is
/// the only axis that can move a pill stop.
Future<List<Color>> _pumpNav(
  WidgetTester tester, {
  required bool isDark,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(
        body: Column(
          children: [
            const Spacer(),
            HomeBottomNav(currentIndex: 0, onTap: (_) {}),
          ],
        ),
      ),
    ),
  );
  // MaterialApp wraps the theme in an AnimatedTheme: reading it on the frame
  // the new theme is handed over would return the *previous* palette at
  // lerp t=0 and prove nothing. Settle the 200ms theme animation first.
  await tester.pumpAndSettle();
  return _selectedGradient(tester);
}

/// The gradient of the single selected pill (the only pill that paints one).
///
/// The pill is a plain `Container`, not an `AnimatedContainer`: `105400e`
/// dropped the 180 ms tween so the fill is decided on the tap frame.
List<Color> _selectedGradient(WidgetTester tester) {
  final gradients = tester
      .widgetList<Container>(find.byType(Container))
      .map((w) => w.decoration)
      .whereType<BoxDecoration>()
      .map((d) => d.gradient)
      .whereType<LinearGradient>()
      .toList();
  expect(gradients, hasLength(1),
      reason: 'exactly one bottom-nav pill is selected');
  return gradients.single.colors;
}

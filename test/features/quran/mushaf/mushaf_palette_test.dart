// Unit test: the contract the mushaf palette holds itself to.
//
// The palette used to grow by appending whatever colour looked nice, and it
// accumulated entries the reader could not tell apart — «بژ روشن» and
// «گندمی», «آبی ملایم» and «آبی مهآلود». "No duplicates" and "readable on
// every paper" are properties of the whole set rather than of one entry, so
// they are checked here as properties, over every pair and every combination,
// instead of being asserted one colour at a time.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/quran/mushaf/mushaf_backgrounds.dart';

/// The darkest paper and the palest paper, used as the extremes a pick has to
/// survive.
const Color _palest = Color(0xFFFDFAF0);
const Color _black = Color(0xFF000000);

void main() {
  group('page backgrounds', () {
    test('there are 22 of them and no two are the same colour', () {
      // 25 minus the gold and the two orange-brown papers the reader retired.
      expect(kMushafBackgrounds.length, 22);

      final seen = <int>{};
      for (final background in kMushafBackgrounds) {
        expect(
          seen.add(background.color.toARGB32()),
          isTrue,
          reason:
              '«${background.name}» repeats a colour already in the palette',
        );
      }

      for (var i = 0; i < kMushafBackgrounds.length; i++) {
        for (var j = i + 1; j < kMushafBackgrounds.length; j++) {
          final distance = mushafColorDistance(
            kMushafBackgrounds[i].color,
            kMushafBackgrounds[j].color,
          );
          expect(
            distance,
            greaterThanOrEqualTo(kMushafBackgroundMinDeltaE),
            reason: '«${kMushafBackgrounds[i].name}» and '
                '«${kMushafBackgrounds[j].name}» are only '
                '${distance.toStringAsFixed(1)} ΔE apart — on a full page of '
                'glyphs they read as one colour with a printing wobble',
          );
        }
      }
    });

    test('the light/dark split is contiguous and matches the count', () {
      expect(kMushafDayBackgroundCount, greaterThan(0));
      expect(kMushafDayBackgroundCount, lessThan(kMushafBackgrounds.length));

      final day = kMushafBackgrounds.take(kMushafDayBackgroundCount).toList();
      final night = kMushafBackgrounds.skip(kMushafDayBackgroundCount).toList();

      // The picker draws two groups straight off this boundary, so a colour on
      // the wrong side of it would be filed under «کاغذ تیره» while the page
      // paints it with day ink.
      expect(day.where((b) => b.isNight), isEmpty,
          reason: 'a dark paper is listed in the light group');
      expect(night.where((b) => !b.isNight), isEmpty,
          reason: 'a light paper is listed in the dark group');
    });

    test('every colour is named', () {
      final names = <String>{};
      for (final background in kMushafBackgrounds) {
        expect(background.name.trim(), isNotEmpty);
        expect(names.add(background.name), isTrue,
            reason: '«${background.name}» names two different colours');
      }
    });

    test('the palette still covers all the families the reader asked for', () {
      bool has(String fragment) =>
          kMushafBackgrounds.any((b) => b.name.contains(fragment));
      for (final family in ['کرم', 'شامواه', 'قهوه', 'شب']) {
        expect(has(family), isTrue,
            reason: 'the «$family» family disappeared from the palette');
      }
    });

    test('the gold and the orange-brown papers stay retired', () {
      // The reader asked for these to go: on a full page of glyphs a saturated
      // gold or orange-brown field tires the eye. «خرمایی» stays — it is the
      // mid-tone the contrast rules are calibrated on.
      for (final name in ['طلایی کهنه', 'بژ گرم', 'خرمایی روشن']) {
        expect(kMushafBackgrounds.any((b) => b.name == name), isFalse,
            reason: '«$name» came back into the palette');
      }
      expect(kMushafDayBackgroundCount, 15,
          reason: 'the three retired papers were all light papers');
    });
  });

  group('recited-ayah colours', () {
    test('there are 18 of them and no two are the same colour', () {
      // 20 minus the two true oranges the reader retired.
      expect(kMushafRecitationColors.length, 18);

      final seen = <int>{};
      for (final entry in kMushafRecitationColors) {
        expect(
          seen.add(entry.color.toARGB32()),
          isTrue,
          reason: '«${entry.name}» repeats a colour already in the palette',
        );
        expect(entry.name.trim(), isNotEmpty);
      }

      for (var i = 0; i < kMushafRecitationColors.length; i++) {
        for (var j = i + 1; j < kMushafRecitationColors.length; j++) {
          final distance = mushafColorDistance(
            kMushafRecitationColors[i].color,
            kMushafRecitationColors[j].color,
          );
          expect(
            distance,
            greaterThanOrEqualTo(kMushafAyahMinDeltaE),
            reason: '«${kMushafRecitationColors[i].name}» and '
                '«${kMushafRecitationColors[j].name}» are only '
                '${distance.toStringAsFixed(1)} ΔE apart',
          );
        }
      }
    });

    test('the default pick is the first entry, so the historical emerald holds',
        () {
      expect(kMushafRecitationColors.first.color.toARGB32(), 0xFF0E7A5A);
    });

    test('the two true oranges stay retired', () {
      for (final name in ['نارنجی سوخته', 'نارنجی']) {
        expect(kMushafRecitationColors.any((c) => c.name == name), isFalse,
            reason: '«$name» came back into the palette');
      }
    });
  });

  group('page ink', () {
    test('is the more legible of the two inks on every paper', () {
      for (final background in kMushafBackgrounds) {
        final ink = mushafPageInk(background.color);
        final inkContrast = mushafContrastRatio(ink, background.color);
        final creamContrast =
            mushafContrastRatio(kMushafCreamInk, background.color);
        final darkContrast =
            mushafContrastRatio(kMushafDarkInk, background.color);

        expect(
            inkContrast,
            moreOrLessEquals(math.max(creamContrast, darkContrast),
                epsilon: 0.001),
            reason: '${background.name} is painted with the worse ink');
        // 3:1 is the WCAG floor for large text; glyphs are large, but not so
        // large that less would do. The mid-browns are the tight ones.
        expect(inkContrast, greaterThanOrEqualTo(3.0),
            reason: '${background.name} cannot be read at all '
                '(${inkContrast.toStringAsFixed(2)}:1)');
      }
    });

    test('the old luminance cut-off picked the wrong ink on the browns', () {
      // The concrete failure that made a contrast-driven rule necessary: the
      // palette now runs through mid-tone browns, and «خرمایی» (#A8764C) has a
      // luminance of 0.218 — under the old `luminance < 0.4` test it was handed
      // the *cream* ink at a contrast ratio of 2.96, i.e. an unreadable page.
      const tan = Color(0xFFA8764C);
      expect(tan.computeLuminance(), lessThan(0.4),
          reason: 'this colour is only interesting because the old rule '
              'classified it as a night paper');
      expect(mushafNeedsLightInk(tan), isFalse);
      expect(mushafContrastRatio(kMushafDarkInk, tan),
          greaterThan(mushafContrastRatio(kMushafCreamInk, tan)));
      expect(mushafContrastRatio(mushafPageInk(tan), tan), greaterThan(3.0));

      // And the genuinely dark brown is still a cream-ink paper.
      expect(mushafNeedsLightInk(const Color(0xFF875A32)), isTrue);
    });

    test('the rule is unchanged for every colour the reader already had', () {
      // The palette rewrite must not silently re-ink a page an existing reader
      // is used to: every legacy colour was either plainly light or plainly
      // dark, so the new rule and the old cut-off agree on all of them.
      for (final legacy in kLegacyMushafBackgrounds) {
        final oldRule = legacy.computeLuminance() < 0.4;
        expect(mushafNeedsLightInk(legacy), oldRule,
            reason:
                'the ink of ${legacy.toARGB32().toRadixString(16)} changed');
      }
    });
  });

  group('recited-ayah colour on a page', () {
    test('is legible on every paper, for every pick', () {
      for (final background in kMushafBackgrounds) {
        final inkContrast = mushafContrastRatio(
            mushafPageInk(background.color), background.color);
        // A pick can never beat the page's own ink; on the mid-tone papers the
        // ink itself is only ~4:1, so that is the ceiling to hold the pick to.
        final target = math.min(kMushafMinHighlightContrast, inkContrast);
        for (final pick in kMushafRecitationColors) {
          final painted = mushafRecitationInkOn(background.color, pick.color);
          expect(
            mushafContrastRatio(painted, background.color),
            greaterThanOrEqualTo(target - 0.01),
            reason: '«${pick.name}» is not readable on «${background.name}»',
          );
        }
      }
    });

    test('keeps the hue instead of being swapped for a fixed gold', () {
      // The old rule replaced any dark pick with one light gold on a night
      // page, so the reader's choice survived only on light paper. Mixing
      // toward the ink keeps each pick recognisably itself.
      for (final pick in kMushafRecitationColors) {
        final painted = mushafRecitationInkOn(_black, pick.color);
        expect(mushafColorDistance(painted, kMushafCreamInk), greaterThan(1.0),
            reason:
                '«${pick.name}» collapsed into the cream ink on a black page');
        expect(mushafColorDistance(painted, pick.color),
            lessThan(mushafColorDistance(kMushafCreamInk, pick.color)),
            reason: '«${pick.name}» moved further from itself than the ink is');
      }
    });

    test('never mixes past the identity floor', () {
      // The reason the cap exists: pushed all the way into the ink, every pick
      // becomes the same cream and the reader's choice is silently discarded.
      for (final paper in kMushafBackgrounds) {
        for (final pick in kMushafRecitationColors) {
          final painted = mushafRecitationInkOn(paper.color, pick.color);
          final limit = Color.lerp(
              pick.color, mushafPageInk(paper.color), kMushafMaxHighlightMix)!;
          expect(mushafColorDistance(painted, pick.color),
              lessThanOrEqualTo(mushafColorDistance(limit, pick.color) + 0.01),
              reason: '«${pick.name}» on «${paper.name}» went past the cap');
        }
      }
    });

    test('a pick that already reads is painted exactly as chosen', () {
      // The common case by far: on the palest paper all twenty are legible as
      // they come, so the reader sees precisely the colour they picked.
      for (final pick in kMushafRecitationColors) {
        expect(mushafRecitationInkOn(_palest, pick.color).toARGB32(),
            pick.color.toARGB32(),
            reason:
                '«${pick.name}» was adjusted on a paper it already reads on');
      }
    });

    test('stays a set of distinguishable colours on every paper', () {
      // Twenty picks that stay twenty picks, rather than collapsing into a few
      // creamy near-neighbours. The floor is 2 ΔE — markably different, not
      // merely non-identical — and the tight papers are the mid-tones, where
      // the highlight has the least headroom: «خرمایی» bottoms out around 2.4
      // (its two amber neighbours) and the night papers stay above 8.
      for (final paper in kMushafBackgrounds) {
        var worst = double.infinity;
        for (var i = 0; i < kMushafRecitationColors.length; i++) {
          for (var j = i + 1; j < kMushafRecitationColors.length; j++) {
            final a = mushafRecitationInkOn(
                paper.color, kMushafRecitationColors[i].color);
            final b = mushafRecitationInkOn(
                paper.color, kMushafRecitationColors[j].color);
            worst = math.min(worst, mushafColorDistance(a, b));
          }
        }
        expect(worst, greaterThanOrEqualTo(2.0),
            reason: 'the picks converge on «${paper.name}»: closest pair only '
                '${worst.toStringAsFixed(1)} ΔE apart');
      }

      // And on the paper the reader is most likely using, they are untouched:
      // the full 10 ΔE of the palette itself survives to the page.
      var worstOnPalest = double.infinity;
      for (var i = 0; i < kMushafRecitationColors.length; i++) {
        for (var j = i + 1; j < kMushafRecitationColors.length; j++) {
          worstOnPalest = math.min(
              worstOnPalest,
              mushafColorDistance(kMushafRecitationColors[i].color,
                  kMushafRecitationColors[j].color));
        }
      }
      expect(worstOnPalest, greaterThanOrEqualTo(kMushafAyahMinDeltaE));
    });
  });

  group('saved ayah highlight bands', () {
    test('keep the page ink legible under every pick on every paper', () {
      for (final paper in kMushafBackgrounds) {
        final ink = mushafPageInk(paper.color);
        for (final pick in kMushafRecitationColors) {
          final band = mushafAyahBandOn(paper.color, pick.color);
          expect(
            mushafContrastRatio(band, ink),
            greaterThanOrEqualTo(kMushafMinHighlightContrast - 0.01),
            reason: 'the «${pick.name}» marker on «${paper.name}» drops the '
                'glyphs below the palette contrast floor',
          );
        }
      }
    });

    test('stay visible on every paper, for every pick', () {
      for (final paper in kMushafBackgrounds) {
        for (final pick in kMushafRecitationColors) {
          final band = mushafAyahBandOn(paper.color, pick.color);
          expect(
            mushafColorDistance(band, paper.color),
            greaterThanOrEqualTo(kMushafAyahBandMinDeltaE - 0.01),
            reason: 'the «${pick.name}» marker on «${paper.name}» is invisible '
                '— the reader cannot find the ayah they marked',
          );
        }
      }
    });

    test('are painted as the plain wash wherever that already worked', () {
      // The guarantee is the exception, not the rule: on almost every paper and
      // pick the 25% wash already reads and is visible, and re-deriving it must
      // not change a single byte of what the reader sees today.
      var untouched = 0;
      for (final paper in kMushafBackgrounds) {
        final ink = mushafPageInk(paper.color);
        for (final pick in kMushafRecitationColors) {
          final wash =
              Color.lerp(paper.color, pick.color, kMushafAyahBandAlpha)!;
          final alreadyWorks =
              mushafContrastRatio(wash, ink) >= kMushafMinHighlightContrast &&
                  mushafColorDistance(wash, paper.color) >=
                      kMushafAyahBandMinDeltaE;
          if (!alreadyWorks) continue;
          expect(
            mushafAyahBandOn(paper.color, pick.color).toARGB32(),
            wash.toARGB32(),
            reason: 'the «${pick.name}» marker was adjusted on «${paper.name}» '
                'although its plain wash already met both rules',
          );
          untouched++;
        }
      }
      // The bar is a proportion, not a literal: the palette is 22 papers × 18
      // picks = 396 pairs now, and 98% of them (the same share the 500-pair
      // palette held at 490) must come through untouched.
      final pairs = kMushafBackgrounds.length * kMushafRecitationColors.length;
      expect(pairs, 396);
      expect(untouched, greaterThanOrEqualTo((pairs * 0.98).floor()),
          reason: 'the guarantee adjusted too many highlights: only $untouched '
              'of the $pairs washes were left alone');
    });

    test('stay a set of distinguishable markers on every paper', () {
      // Twenty picks that stay twenty picks instead of collapsing into a few
      // near-neighbours on the mid-tone papers, where the band has the least
      // headroom. «خرمایی» is the tight one, at ~2.5 ΔE.
      for (final paper in kMushafBackgrounds) {
        var worst = double.infinity;
        for (var i = 0; i < kMushafRecitationColors.length; i++) {
          for (var j = i + 1; j < kMushafRecitationColors.length; j++) {
            final a =
                mushafAyahBandOn(paper.color, kMushafRecitationColors[i].color);
            final b =
                mushafAyahBandOn(paper.color, kMushafRecitationColors[j].color);
            worst = math.min(worst, mushafColorDistance(a, b));
          }
        }
        expect(worst, greaterThanOrEqualTo(2.0),
            reason: 'the marker colours converge on «${paper.name}»: closest '
                'pair only ${worst.toStringAsFixed(1)} ΔE apart');
      }
    });
  });

  group('live recitation ayah wash', () {
    test('keeps the recited glyphs legible on every paper, for every pick', () {
      // This is the guarantee the tint used to lack. The wash is the recitation
      // ink tinted over the paper — the same colour as the glyphs it sits
      // behind — so at a fixed 16% it quietly ate into their contrast: measured
      // across the palette, 244 of the 500 paper/pick pairs landed under
      // [kMushafMinHighlightContrast], the worst at 2.46:1 on «قهوه‌ای» with
      // «نارنجی». Nothing threw and nothing changed colour; the ayah was just
      // harder to read than the palette promises.
      for (final paper in kMushafBackgrounds) {
        for (final pick in kMushafRecitationColors) {
          final ink = mushafRecitationInkOn(paper.color, pick.color);
          final wash = mushafLiveAyahWashOn(paper.color, ink);
          expect(
            mushafContrastRatio(ink, wash),
            greaterThanOrEqualTo(kMushafMinHighlightContrast - 0.01),
            reason: 'the «${pick.name}» wash on «${paper.name}» drops the '
                'recited glyphs below the palette contrast floor',
          );
        }
      }
    });

    test('never tints harder than the default, only softer', () {
      // The guarantee may give the tint up, it may not redesign it: every
      // result is one of the candidate strengths up to
      // [kMushafLiveAyahAlpha], so the shipped look is an upper bound.
      const steps = 32;
      for (final paper in kMushafBackgrounds) {
        for (final pick in kMushafRecitationColors) {
          final ink = mushafRecitationInkOn(paper.color, pick.color);
          final wash = mushafLiveAyahWashOn(paper.color, ink);
          final candidates = List<Color>.generate(
            steps + 1,
            (i) =>
                Color.lerp(paper.color, ink, kMushafLiveAyahAlpha * i / steps)!,
          );
          expect(
            candidates.map((c) => c.toARGB32()).toList(),
            contains(wash.toARGB32()),
            reason: 'the wash on «${paper.name}» for «${pick.name}» is not one '
                'of the strengths the palette allows',
          );
        }
      }
    });

    test('leaves the tint alone wherever the default already read', () {
      // Same guard rail as the saved band: re-deriving the wash must not move a
      // single byte of what the reader sees on the pairs that were already
      // fine — the guarantee is the exception, not a repaint.
      var untouched = 0;
      var softened = 0;
      for (final paper in kMushafBackgrounds) {
        for (final pick in kMushafRecitationColors) {
          final ink = mushafRecitationInkOn(paper.color, pick.color);
          final plain = Color.lerp(paper.color, ink, kMushafLiveAyahAlpha)!;
          final wash = mushafLiveAyahWashOn(paper.color, ink);
          final alreadyWorks =
              mushafContrastRatio(ink, plain) >= kMushafMinHighlightContrast;
          if (alreadyWorks) {
            expect(
              wash.toARGB32(),
              plain.toARGB32(),
              reason: 'the «${pick.name}» wash on «${paper.name}» was weakened '
                  'although its plain tint already cleared the floor',
            );
            untouched++;
          } else {
            expect(
              mushafColorDistance(wash, paper.color),
              lessThanOrEqualTo(
                  mushafColorDistance(plain, paper.color) + 0.001),
              reason: 'a tint below the floor was strengthened, which can '
                  'only cost the glyphs more contrast',
            );
            softened++;
          }
        }
      }
      expect(
        untouched,
        greaterThanOrEqualTo(200),
        reason: 'the guarantee weakened too much of the palette: only '
            '$untouched of 500 washes kept their shipped tint',
      );
      expect(
        softened,
        greaterThan(0),
        reason: 'no paper needed softening — either the shipped tint became '
            'legible on its own or the floor is no longer being applied',
      );
    });
  });

  group('migration lookups', () {
    test('every legacy colour snaps into the new palette', () {
      expect(kLegacyMushafBackgrounds.length, 25);
      expect(kLegacyMushafRecitationColors.length, 7);

      for (final legacy in kLegacyMushafBackgrounds) {
        final index = mushafNearestBackgroundIndexOf(legacy);
        expect(index, inInclusiveRange(0, kMushafBackgrounds.length - 1));
        // Nothing may snap further than the palette's own step size, or the
        // reader's page would visibly change colour on upgrade.
        expect(mushafColorDistance(legacy, kMushafBackgrounds[index].color),
            lessThanOrEqualTo(12.0),
            reason: 'legacy ${legacy.toARGB32().toRadixString(16)} lands far '
                'from «${kMushafBackgrounds[index].name}»');
      }

      for (final legacy in kLegacyMushafRecitationColors) {
        final index = mushafNearestRecitationIndexOf(legacy);
        expect(index, inInclusiveRange(0, kMushafRecitationColors.length - 1));
      }
    });

    test('the legacy default stays a light paper and the emerald stays first',
        () {
      // quran_bg_day = 0 was «کرم» and quran_recitation_color = 0 was the
      // emerald: the two defaults must not flip the reader's page or ink.
      final background = kMushafBackgrounds[
          mushafNearestBackgroundIndexOf(mushafLegacyBackgroundColor(0))];
      expect(background.isNight, isFalse);

      final pick = kMushafRecitationColors[
          mushafNearestRecitationIndexOf(mushafLegacyRecitationColor(0))];
      expect(pick.color.toARGB32(), 0xFF0E7A5A);
    });

    test('the legacy recited-ayah colours that still exist are preserved', () {
      // Four of the seven survived the rewrite verbatim. The old olive-brown
      // («خردهای») had no distinct neighbour worth keeping, and the old flat
      // grey became a tinted slate so the palette's two neutrals could be told
      // apart on a night page.
      // Legacy pick 2 — the orange — was retired at the reader's request;
      // the test below pins where an existing pick of it now lands.
      const verbatim = [0, 1, 3, 4];
      for (final index in verbatim) {
        final legacy = mushafLegacyRecitationColor(index);
        expect(
          kMushafRecitationColors[mushafNearestRecitationIndexOf(legacy)]
              .color
              .toARGB32(),
          legacy.toARGB32(),
          reason: 'legacy pick $index changed colour',
        );
      }
    });

    test('a reader who had picked the retired orange keeps a warm hue', () {
      // Removing a colour must not silently hand the reader a cold one. Legacy
      // pick 2 was the orange #B4531B; the nearest survivor has to be the warm
      // «آجری» (16.1 ΔE), not «کهربایی» (23.1) or the green «زیتونی» (39.3).
      final snapped = kMushafRecitationColors[
          mushafNearestRecitationIndexOf(mushafLegacyRecitationColor(2))];
      expect(snapped.name, 'آجری',
          reason: 'the retired orange landed on «${snapped.name}»');
    });

    test('a colour that is not in the palette reports -1 and a nearest', () {
      const orphan = Color(0xFF123456);
      expect(mushafBackgroundIndexOf(orphan), -1);
      expect(mushafRecitationIndexOf(orphan), -1);
      expect(mushafNearestBackgroundIndexOf(orphan),
          inInclusiveRange(0, kMushafBackgrounds.length - 1));
      expect(mushafNearestRecitationIndexOf(orphan),
          inInclusiveRange(0, kMushafRecitationColors.length - 1));
    });
  });
}

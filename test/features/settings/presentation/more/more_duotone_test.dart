import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/settings/presentation/more/more_duotone.dart';
import 'package:tawheeed/features/settings/presentation/more/more_registry.dart';

/// Style 2: flat duotone squircle. One accent in, five flat alpha-derived
/// colors out — no gradients, no gloss. The tests pin the spec alphas and
/// keep the glyph at ≥ 3:1 on every palette the app can render.
void main() {
  const lightPalettes = [
    AppPalettes.goldLight,
    AppPalettes.dawnLight,
    AppPalettes.dayLight,
    AppPalettes.sunsetLight,
    AppPalettes.nightLight,
  ];
  const darkPalettes = [
    AppPalettes.goldDark,
    AppPalettes.dawnDark,
    AppPalettes.dayDark,
    AppPalettes.sunsetDark,
    AppPalettes.nightDark,
  ];

  group('mix()', () {
    test('endpoints are identity and the midpoint is the average', () {
      const red = Color(0xFFFF0000);
      const blue = Color(0xFF0000FF);
      expect(mix(red, blue, 0), red);
      expect(mix(red, blue, 1), blue);
      final mid = mix(red, blue, .5);
      expect(mid.r, closeTo(.5, .002));
      expect(mid.b, closeTo(.5, .002));
      expect(mid.g, closeTo(0, .002));
    });

    test('alpha is interpolated too (no double-darkening on tinted surfaces)',
        () {
      final out = mix(const Color(0x80FF0000), const Color(0x00000000), .5);
      expect(out.a, closeTo(.25, .01));
    });
  });

  group('contrastRatio()', () {
    test('is the WCAG ratio', () {
      expect(MoreDuotone.contrastRatio(Colors.white, Colors.black),
          closeTo(21, .01));
      expect(MoreDuotone.contrastRatio(Colors.blue, Colors.blue),
          closeTo(1, .001));
    });
  });

  group('style-2 derivation', () {
    test('matches the spec alphas for one accent', () {
      const accent = Color(0xFF0F7B6C);
      final d = MoreDuotone.of(accent,
          isDark: false, cardSurface: AppPalettes.goldLight.card);
      expect(d.fill, accent.withValues(alpha: 0x24 / 255));
      expect(d.border, accent.withValues(alpha: 0x2E / 255));
      expect(d.dot, accent.withValues(alpha: 0x70 / 255));
    });

    test('glyph is the faintest ladder step that clears 3:1 on the fill', () {
      const accent = Color(0xFF0F7B6C);
      final surface = AppPalettes.goldLight.card;
      final d = MoreDuotone.of(accent, isDark: false, cardSurface: surface);
      final fillOnCard =
          Color.alphaBlend(accent.withValues(alpha: 0x24 / 255), surface);
      // A deep accent clears 3:1 at the faintest step (10% toward black).
      expect(d.glyph, mix(accent, Colors.black, .10));
      expect(MoreDuotone.contrastRatio(d.glyph, fillOnCard),
          greaterThanOrEqualTo(3));
    });

    test('every registry accent keeps its glyph at ≥ 3:1, light and dark', () {
      final accents = {for (final item in kMoreItems) item.accent};
      final failures = <String>[];
      for (final palette in [...lightPalettes, ...darkPalettes]) {
        final isDark = palette.card.computeLuminance() < .5;
        for (final accent in accents) {
          final d =
              MoreDuotone.of(accent, isDark: isDark, cardSurface: palette.card);
          final fillOnCard = Color.alphaBlend(
              accent.withValues(alpha: 0x24 / 255), palette.card);
          final ratio = MoreDuotone.contrastRatio(d.glyph, fillOnCard);
          if (ratio < 3) {
            failures.add('${accent.toARGB32()} on ${palette.card.toARGB32()} '
                '→ $ratio');
          }
        }
      }
      expect(failures, isEmpty);
    });

    test('the amber and sky-blue mockup accents are the hard cases, and pass',
        () {
      for (final isDark in [false, true]) {
        final surface =
            isDark ? AppPalettes.goldDark.card : AppPalettes.goldLight.card;
        for (final accent in const [Color(0xFFD9922B), Color(0xFF2B7FD6)]) {
          final d =
              MoreDuotone.of(accent, isDark: isDark, cardSurface: surface);
          final fillOnCard =
              Color.alphaBlend(accent.withValues(alpha: 0x24 / 255), surface);
          expect(MoreDuotone.contrastRatio(d.glyph, fillOnCard),
              greaterThanOrEqualTo(3),
              reason: 'accent ${accent.toARGB32()} on $surface');
        }
      }
    });

    test('derived colors are computed once per (accent, brightness, surface)',
        () {
      MoreDuotone.clearCacheForTests();
      const accent = Color(0xFF1E6B34);
      final first = MoreDuotone.of(accent,
          isDark: false, cardSurface: AppPalettes.goldLight.card);
      final again = MoreDuotone.of(accent,
          isDark: false, cardSurface: AppPalettes.goldLight.card);
      expect(identical(first, again), isTrue);
      final otherSurface = MoreDuotone.of(accent,
          isDark: true, cardSurface: AppPalettes.goldDark.card);
      expect(identical(first, otherSurface), isFalse);
      // Same VALUE, different argument object: memoized by color equality.
      final sameCall = MoreDuotone.of(const Color(0xFF1E6B34),
          isDark: false, cardSurface: AppPalettes.goldLight.card);
      expect(identical(first, sameCall), isTrue);
      MoreDuotone.clearCacheForTests();
    });
  });

  group('moreTileSize()', () {
    test('clamps to [52, 72]', () {
      expect(moreTileSize(20), 52); // raw 8 → min
      expect(moreTileSize(58), 52); // raw 38.4 → min
      expect(moreTileSize(75), 52); // raw 52 → min boundary
      expect(moreTileSize(100), 72); // raw 72 → max boundary
      expect(moreTileSize(106.25), 72); // raw 77 → capped
      expect(moreTileSize(600), 72); // far over the cap
    });

    test('inside the clamp the edge is 80 % of a four-column cell', () {
      expect(moreTileSize(90), closeTo(64, .001)); // 0.8 * 80
      expect(moreTileSize(81.75), closeTo(57.4, .001));
    });

    test('the widths the page produces land where the spec expects', () {
      // Page padding 10 per side, group-card padding 6 per side, plus the
      // card's two 0.5px hairlines → cell = (screen − 20 − 12 − 1) / 4.
      double cellOf(double screen) => (screen - 20 - 12 - 1) / 4;
      // Small screens hit the 52 floor, so four tiles never become cramped.
      expect(moreTileSize(cellOf(320)), 52);
      expect(moreTileSize(cellOf(360)), closeTo(57.4, .01));
      expect(moreTileSize(cellOf(412)), closeTo(67.8, .01));
      // A tablet width is where the 72 ceiling wins instead of the tile.
      expect(moreTileSize(cellOf(600)), 72);
    });
  });
}

import 'package:flutter/material.dart';

import 'package:tawheeed/core/design_system/components/components.dart';

/// ═══════════════════════════════════════════════════════════════
/// The «Style 2» tile derivation — flat duotone squircles. Everything
/// derives from the item's one accent color `c`, flat alpha tints only:
/// no gradients, no glossy highlights, no white borders, no shadows.
///
///   tile fill     c @ 0x24 (14 %)          1dp border c @ 0x2E (18 %)
///   corner dot    0.10·S, c @ 0x70 (27 %)  — top-end
///   glyph         mix(c, black, 10 %), darkened stepwise until it clears
///                 3:1 against the composited fill (lifted toward white on
///                 dark surfaces)
///
/// All derivations depend only on `(accent, brightness, card surface)`, so
/// each combination is computed ONCE and cached — the grid never recomputes
/// them per frame.
/// ═══════════════════════════════════════════════════════════════

/// The accent alpha tints of the Style-2 recipe, as fractions of 255.
const double _kFillAlpha = 0x24 / 255;

@immutable
class MoreDuotone {
  const MoreDuotone({
    required this.fill,
    required this.border,
    required this.dot,
    required this.glyph,
  });

  /// Squircle fill: accent at 14 % alpha over the card surface.
  final Color fill;

  /// 1dp squircle border: accent at 18 % alpha.
  final Color border;

  /// The top-end corner dot: accent at 27 %.
  final Color dot;

  /// The bold glyph color, ≥ 3:1 against the composited fill.
  final Color glyph;

  static final Map<(Color, bool, Color), MoreDuotone> _cache = {};

  factory MoreDuotone.of(Color accent,
      {required bool isDark, required Color cardSurface}) {
    return _cache[(accent, isDark, cardSurface)] ??=
        MoreDuotone._derive(accent, isDark: isDark, cardSurface: cardSurface);
  }

  /// Visible for tests: drops the memo so contrast can be re-measured.
  @visibleForTesting
  static void clearCacheForTests() => _cache.clear();

  factory MoreDuotone._derive(Color accent,
      {required bool isDark, required Color cardSurface}) {
    return MoreDuotone(
      fill: accent.withValues(alpha: _kFillAlpha),
      border: accent.withValues(alpha: 0x2E / 255),
      dot: accent.withValues(alpha: 0x70 / 255),
      glyph: readableGlyph(accent, isDark: isDark, cardSurface: cardSurface),
    );
  }

  /// The spec's glyph ink, now one shared recipe with every other duotone
  /// tile ([dsReadableGlyph] in the design system — the same ladder maths,
  /// moved there so `IconTile`/`DuotoneIconTile` measure the same way).
  static Color readableGlyph(Color accent,
          {required bool isDark, required Color cardSurface}) =>
      dsReadableGlyph(accent, isDark: isDark, cardSurface: cardSurface);

  /// WCAG 2.x contrast ratio between two colors (alpha ignored — both are
  /// opaque derivations of the palette).
  static double contrastRatio(Color a, Color b) => dsContrastRatio(a, b);
}

/// The Style-2 tile edge for the four-column grid: 20 % of the grid cell is
/// left as air, clamped so a tile never drops under 52dp or balloons past
/// 72dp. ≈ 52dp at a 320dp page, 57dp at 360dp, 68dp at 412dp, 72dp above
/// ~450dp — the icons stay small enough for four to a row.
double moreTileSize(double cellWidth) {
  final raw = 0.8 * (cellWidth - 10);
  return raw < 52 ? 52 : (raw > 72 ? 72 : raw);
}

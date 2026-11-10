import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tawheeed/core/theme/theme.dart';

/// Spacing steps from the redesign spec — pages use a 10px side padding,
/// cards sit 8 apart, and compact rows keep a 6px vertical rhythm.
class DsSpacing {
  DsSpacing._();

  static const double page = 10;
  static const double gap = 8;
  static const double rowGap = 6;
}

/// Linear blend of two colors — `mix(c, Colors.white, .68)` reads as «c
/// lightened 68% toward white». One shared helper so derived surfaces
/// (the «بیشتر» duotone tiles, icon squircles, labels) all compute the
/// same way; `Color.lerp` already resolves mixed alpha correctly.
Color mix(Color a, Color b, double t) => Color.lerp(a, b, t) ?? a;

/// The ink to draw ON an accent-filled surface (a filled button, an accent
/// chip, the app bar of a feature page).
///
/// The accent family is saturated in the light palette and lightened in the
/// dark one, so "on accent" is white by day and near-black warm ink by night.
/// Thirty screens re-typed that ternary by hand (`isDark ? const
/// Color(0xFF1A1410) : Colors.white`), which is exactly the kind of copy the
/// unification pass removes: one helper, one value, no drift.
Color dsOnAccent(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1A1410)
        : Colors.white;

/// The drop shadow under a feature page's card grid: black on a dark palette,
/// the design's warm espresso on a light one. Sixteen screens re-typed the
/// `isDark ? Colors.black : const Color(0xFF3E2723)` ternary by hand.
Color dsShadow(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? Colors.black
        : const Color(0xFF3E2723);

/// Readable variant of an identity [hue] for small text/icons on the active
/// surface: darkened on light palettes, lightened on dark ones while keeping
/// the hue. Local copy of the legacy `AppColors.darkenAccentForText` maths so
/// redesigned files never import the deprecated color classes.
Color dsContentColor(BuildContext context, Color hue) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark
      ? (Color.lerp(hue, Colors.white, 0.35) ?? hue)
      : (Color.lerp(hue, Colors.black, 0.30) ?? hue);
}

/// WCAG 2.x contrast ratio between two colors (alpha ignored — both are
/// opaque derivations of the palette).
double dsContrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + .05) / (lo + .05);
}

/// Brightness-correct semantic colours.
///
/// The status family lives as four const pairs on `AppTheme`
/// (`lightSuccess`/`darkSuccess`, …). Picking the right one was a repeated
/// `isDark ? AppTheme.darkX : AppTheme.lightX` ternary in feature code; these
/// accessors make the choice once, so a new screen cannot pair the light
/// variant with a dark surface.
abstract final class DsStatus {
  static Color success(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppTheme.darkSuccess
          : AppTheme.lightSuccess;

  static Color warning(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppTheme.darkWarning
          : AppTheme.lightWarning;

  /// Named «danger» because «error» reads like an exception in this codebase.
  static Color danger(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppTheme.darkError
          : AppTheme.lightError;

  static Color info(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppTheme.darkInfo
          : AppTheme.lightInfo;
}

/// The duotone tile's glyph ink for an identity [accent]: `mix(accent,
/// black, 10 %)` on light surfaces — kept verbatim when it already clears
/// 3:1 on the fill composited over [cardSurface], darkened one ladder step
/// at a time when it does not. On dark surfaces the same hue is lifted
/// toward white instead. The accent's HUE never changes — only its ink —
/// so a section's identity colour stays recognisable.
Color dsReadableGlyph(Color accent,
    {required bool isDark, required Color cardSurface}) {
  const fillAlpha = 0x24 / 255;
  final other = isDark ? Colors.white : Colors.black;
  final steps = isDark
      ? const [.10, .18, .26, .34, .42, .50]
      : const [.10, .16, .22, .28, .34, .40];
  final fillOnCard =
      Color.alphaBlend(accent.withValues(alpha: fillAlpha), cardSurface);
  var faintest = mix(accent, other, steps.last);
  for (final t in steps) {
    final candidate = mix(accent, other, t);
    if (dsContrastRatio(candidate, fillOnCard) >= 3) return candidate;
    faintest = candidate;
  }
  return faintest;
}

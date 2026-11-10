/// The mushaf palette: every page background and every recited-ayah colour the
/// reader can pick lives in this one file, together with the colour maths that
/// decides how they are painted.
///
/// Two invariants hold here, and both are enforced by
/// `test/features/quran/mushaf/mushaf_palette_test.dart` rather than by review:
///
///  * **no two entries are the same colour.** The old palette was grown by
///    appending whatever looked nice, so it ended up with pairs the reader
///    could not tell apart (`#F2E8D4` vs `#EFE6D6`, `#D9E4EF` vs `#E0E7EC`,
///    …). Distance is measured perceptually (CIELAB ΔE76), not by eye: two
///    entries below [kMushafBackgroundMinDeltaE] read as a duplicate whatever
///    their hex values are.
///  * **every colour is legible on the page it is painted on.** The reader has
///    eighteen light papers, seven dark ones and every shade of brown between
///    them, so the ink cannot be chosen by a luminance cut-off any more — see
///    [mushafPageInk] and [mushafRecitationInkOn].
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

// ── The contract ────────────────────────────────────────────────────────────

/// The page's own ink on a light paper: near-black, warmed so it sits on cream
/// instead of cutting into it.
const Color kMushafDarkInk = Color(0xFF26221C);

/// The page's own ink on a dark paper: cream, never pure white (white halates
/// against a dark field and the glyph edges smear).
const Color kMushafCreamInk = Color(0xFFE8DFCE);

/// Minimum CIELAB distance between two page backgrounds. At 7 the difference is
/// plainly visible on a full page of glyphs; below it the pair reads as "the
/// same colour, slightly off".
const double kMushafBackgroundMinDeltaE = 7.0;

/// Minimum CIELAB distance between two recited-ayah colours. Higher than the
/// background threshold because these are picked to tell one ayah from another
/// at a glance, not to set a mood.
const double kMushafAyahMinDeltaE = 10.0;

/// Contrast ratio the recited-ayah colour must hold against its page. WCAG AA
/// for large text, which the Quran glyphs are — deliberately below the body
/// ink's own contrast, because on the mid-tone papers there is not enough
/// headroom for both and the highlight is the one that can give: the reader can
/// see which ayah is being recited, and the glyphs beside it still carry the
/// text.
const double kMushafMinHighlightContrast = 3.0;

/// How far the recited-ayah colour may be mixed into the page's ink before it
/// stops being the colour the reader chose.
///
/// The mix is what makes a dark pick readable on a night page, and it is also
/// what destroys it: pushed all the way to the ink, every pick becomes the same
/// cream and the reader's choice is gone. Capped at 0.8, a pick keeps its hue
/// and, on a paper like «خرمایی», still reaches the contrast floor instead of
/// collapsing onto the body ink.
const double kMushafMaxHighlightMix = 0.8;

/// How strongly a saved ayah highlight washes over the paper by default — the
/// strength that makes it read as a highlighter band rather than a solid bar.
const double kMushafAyahBandAlpha = 0.25;

/// Minimum CIELAB distance between a saved ayah's band and the paper it sits
/// on. A weaker band is the reader's own marker, and below this the wash is
/// invisible on a paper of a similar hue — the reader cannot find the ayah they
/// marked. Lower than the background threshold because the band is a wash, not
/// a surface of its own.
const double kMushafAyahBandMinDeltaE = 5.0;

/// How strongly the ayah being **recited right now** is washed behind its own
/// glyphs, at full strength — the tint that marks the words the reciter is on.
/// See [mushafLiveAyahWashOn], which is free to paint less than this.
const double kMushafLiveAyahAlpha = 0.16;

// ── Colour maths ────────────────────────────────────────────────────────────

double _channel(Color color, int shift) =>
    ((color.toARGB32() >> shift) & 0xFF) / 255.0;

double _linearize(double channel) => channel <= 0.04045
    ? channel / 12.92
    : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();

double _f(double t) =>
    t > 216 / 24389 ? math.pow(t, 1 / 3).toDouble() : (841 / 108) * t + 4 / 29;

/// CIELAB coordinates of [color], D65 white point. Returns
/// `[L*, a*, b*]` — the space in which "these two colours look the same"
/// has a meaning independent of how they were written down in hex.
List<double> mushafLab(Color color) {
  final r = _linearize(_channel(color, 16));
  final g = _linearize(_channel(color, 8));
  final b = _linearize(_channel(color, 0));
  final x = 0.4124564 * r + 0.3575761 * g + 0.1804375 * b;
  final y = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b;
  final z = 0.0193339 * r + 0.1191920 * g + 0.9503041 * b;
  final fx = _f(x / 0.95047);
  final fy = _f(y / 1.0);
  final fz = _f(z / 1.08883);
  return [116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)];
}

/// Perceptual distance between two colours (CIELAB ΔE76). Below ~2.3 the
/// difference is invisible; below ~7 a large flat area of each reads as one
/// colour with a printing wobble.
double mushafColorDistance(Color a, Color b) {
  final la = mushafLab(a);
  final lb = mushafLab(b);
  final dl = la[0] - lb[0];
  final da = la[1] - lb[1];
  final db = la[2] - lb[2];
  return math.sqrt(dl * dl + da * da + db * db);
}

/// WCAG contrast ratio (1 … 21) between two colours.
double mushafContrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Whether [background] should be painted with the cream ink.
///
/// This replaces the old `luminance < 0.4` test, which was wrong wherever it
/// mattered: a mid-brown page like `#A8764C` sits just under 0.4, so it used to
/// be handed cream ink at a contrast ratio of **2.96** — the mushaf was
/// unreadable on it. Picking whichever ink actually contrasts more is correct
/// across the whole range, and it is identical to the old rule for every pale
/// paper (luminance > 0.54) and every night paper (luminance < 0.04), which is
/// all the reader shipped until now.
bool mushafNeedsLightInk(Color background) =>
    mushafContrastRatio(background, kMushafCreamInk) >
    mushafContrastRatio(background, kMushafDarkInk);

/// The page ink for [background] — the better of the two by contrast.
Color mushafPageInk(Color background) =>
    mushafNeedsLightInk(background) ? kMushafCreamInk : kMushafDarkInk;

/// The recited-ayah colour as it should be painted on [background].
///
/// A pick is chosen for its hue, and hue alone does not survive a change of
/// paper: the darker picks (indigo, plum, charcoal) sit at ~1:1 contrast on a
/// black page, where they used to be replaced by one fixed light gold — losing
/// the reader's choice entirely. Instead the pick is mixed toward that page's
/// own ink just far enough to be legible.
///
/// Mixing toward the ink is monotonic in contrast by construction: the page ink
/// is the extreme *away* from the paper's own luminance, so moving toward it can
/// only increase the contrast ratio. That makes the smallest sufficient mix a
/// binary search rather than a table of magic ratios per colour, and it means a
/// pick that already reads is returned untouched — which is every pick on every
/// light paper, where it holds 4.4:1 or better as chosen.
///
/// Two limits keep it honest:
///
///  * the target is [kMushafMinHighlightContrast], capped by the page's own ink
///    contrast, so a paper that cannot reach it is not left with a highlight
///    worse than its body text;
///  * the mix never passes [kMushafMaxHighlightMix], so the highlight cannot
///    turn into the body ink and quietly discard the reader's choice.
Color mushafRecitationInkOn(Color background, Color chosen) {
  final ink = mushafPageInk(background);
  final inkContrast = mushafContrastRatio(ink, background);
  final target = math.min(kMushafMinHighlightContrast, inkContrast);
  if (mushafContrastRatio(chosen, background) >= target) return chosen;

  Color mixedAt(double t) => Color.lerp(chosen, ink, t) ?? ink;

  // If even the identity floor cannot reach the target, that is the best the
  // reader can get on this paper — see the mid-tone papers, whose ink itself is
  // only ~4:1.
  if (mushafContrastRatio(mixedAt(kMushafMaxHighlightMix), background) <
      target) {
    return mixedAt(kMushafMaxHighlightMix);
  }

  var low = 0.0;
  var high = kMushafMaxHighlightMix;
  for (var i = 0; i < 24; i++) {
    final mid = (low + high) / 2;
    if (mushafContrastRatio(mixedAt(mid), background) >= target) {
      high = mid;
    } else {
      low = mid;
    }
  }
  return mixedAt(high);
}

/// The band a saved ayah highlight paints on [background], given the [chosen]
/// colour the reader picked.
///
/// A saved marker is a wash of the pick over the paper, and at
/// [kMushafAyahBandAlpha] that wash can fail in two opposite ways:
///
///  * a pick close to the paper's own hue all but disappears, so the reader
///    cannot see the ayah they marked — the band's own version of the palette's
///    "no two entries are the same colour" rule; and
///  * a dark pick drags the paper under the glyphs dark enough that the page ink
///    loses its contrast — the band is painted behind the *text*, so it has to
///    answer to the same [kMushafMinHighlightContrast] floor the recited-ayah
///    colour does.
///
/// Strengthening the band (mixing toward [chosen]) fixes the first and worsens
/// the second, so a single mix cannot be solved for by binary search. Instead the
/// wash is walked from the paper to the pure pick and the *softest* strength that
/// satisfies both rules is kept, which is exactly [kMushafAyahBandAlpha] on every
/// paper and pick where the wash already worked — so an ordinary highlight is
/// painted byte-for-byte as before. When the two rules cannot both be met, text
/// legibility wins and the most visible still-readable wash is used: a faint
/// marker is a nuisance, an unreadable ayah is not.
///
/// The result is an opaque colour — the wash pre-composited over the paper — so
/// the caller paints it directly and the glyphs above it keep the paper's own
/// ink.
Color mushafAyahBandOn(Color background, Color chosen) {
  final ink = mushafPageInk(background);
  Color washAt(double mix) => Color.lerp(background, chosen, mix) ?? chosen;

  const steps = 40;
  double? softest;
  var fallbackMix = 0.0;
  var fallbackVisibility = 0.0;
  for (var i = 0; i <= steps; i++) {
    final mix = i / steps;
    final wash = washAt(mix);
    if (mushafContrastRatio(wash, ink) < kMushafMinHighlightContrast) {
      continue;
    }
    final visibility = mushafColorDistance(wash, background);
    if (visibility > fallbackVisibility) {
      fallbackVisibility = visibility;
      fallbackMix = mix;
    }
    if (visibility < kMushafAyahBandMinDeltaE) continue;
    if (softest == null ||
        (mix - kMushafAyahBandAlpha).abs() <
            (softest - kMushafAyahBandAlpha).abs()) {
      softest = mix;
    }
  }
  return washAt(softest ?? fallbackMix);
}

/// The wash painted behind the ayah being recited, given the [background] it is
/// drawn on and the [recitationInk] the reader's pick resolved to there.
///
/// This wash is [recitationInk] tinted over the paper, so it is the *same
/// colour as the glyphs it sits behind* — which is precisely what makes it
/// fragile. Every step of tint moves the background toward the text on top of
/// it, so a strong enough wash swallows the very words it is meant to mark. At
/// a fixed alpha that failure is silent: nothing throws, no palette entry
/// changes, no test notices, and the recited ayah simply stops being readable
/// on that page — the mid-tone papers are where it happened, because their ink
/// only reaches ~4:1 to begin with and has little to give.
///
/// So the tint is derived, not declared: [kMushafLiveAyahAlpha] as long as the
/// glyphs keep [kMushafMinHighlightContrast] on top of it, and the strongest
/// weaker tint otherwise. The search never goes past the default — the wash is
/// a hint, not a redesign, and an ayah is still marked by its own colour when
/// the tint has to give. On a paper where even the bare ink cannot reach the
/// floor the wash is dropped altogether (the paper is returned): there is
/// nothing left to spend, and no tint is more readable than no tint.
///
/// The result is opaque — the tint pre-composited over the paper — matching
/// [mushafAyahBandOn], so the caller paints it directly and the glyphs above it
/// keep the ink they were given.
Color mushafLiveAyahWashOn(Color background, Color recitationInk) {
  Color washAt(double mix) =>
      Color.lerp(background, recitationInk, mix) ?? recitationInk;

  // Strongest passing mix wins, so the loop does not rely on contrast falling
  // monotonically as the wash deepens (`mushafRecitationInkOn` does, and says
  // so; here the range is 33 samples wide, so a scan costs nothing and assumes
  // nothing).
  const steps = 32;
  var kept = 0.0;
  for (var i = 1; i <= steps; i++) {
    final mix = kMushafLiveAyahAlpha * i / steps;
    if (mushafContrastRatio(recitationInk, washAt(mix)) <
        kMushafMinHighlightContrast) {
      continue;
    }
    kept = mix;
  }
  return washAt(kept);
}

// ── The palette ─────────────────────────────────────────────────────────────

/// One selectable page background: the colour plus the Persian name the picker
/// prints under it.
///
/// The names are not decoration. Twenty-two swatches in two families differ by
/// a few points of chroma in places, and an unnamed grid makes colours that are
/// *just* distinguishable look like the duplicates this palette exists to
/// remove.
@immutable
class MushafBackground {
  const MushafBackground(this.color, this.name);

  final Color color;
  final String name;

  /// Dark enough that the page reads with cream ink — the picker files these
  /// under «کاغذ تیره» and the chrome flips to its night palette.
  bool get isNight => mushafNeedsLightInk(color);
}

/// One selectable colour for the ayah being recited.
@immutable
class MushafRecitationColor {
  const MushafRecitationColor(this.color, this.name);

  final Color color;
  final String name;
}

/// Page backgrounds behind the transparent mushaf pages, ordered from the
/// palest paper to the darkest night and — crucially — **contiguous by family**:
/// the first [dayBackgroundCount] entries are the light papers and the rest are
/// the dark ones, so the picker can split the list in two without re-sorting it
/// and without a colour ever appearing in the «شب» group while the page paints
/// it with day ink.
///
/// Colours are no longer persisted by index (see [MushafReaderPrefs]), so this
/// list is free to be reordered, renamed and pruned. Adding a colour is still
/// append-in-family: the picker reads top-to-bottom.
///
/// The set spans the families the reader asked for — cream, chamois,
/// tan/brown, olive and green, grey and lilac, terracotta and rose, plus the
/// night papers — with chroma held low through the middles: a saturated field
/// behind thousands of small glyphs tires the eye long before an hour passes.
/// The golds and the orange-brown middles were dropped for exactly that
/// reason; the palette now tops out at «خرمایی» and the dark browns.
const List<MushafBackground> kMushafBackgrounds = [
  // ── کاغذهای روشن (dark ink) ──
  MushafBackground(Color(0xFFFDFAF0), 'کرم صدفی'),
  MushafBackground(Color(0xFFF6EDD2), 'کرم'),
  MushafBackground(Color(0xFFEEDFBB), 'شامواه روشن'),
  MushafBackground(Color(0xFFE3CC97), 'شامواه'),
  // The two saturated golds («طلایی روشن»، «طلایی») were retired at the
  // reader's request — a saturated yellow field behind thousands of small
  // glyphs tires the eye and the dark ink loses its bite. Their slots now
  // carry two readable papers the palette lacked.
  MushafBackground(Color(0xFFB9C9AC), 'خزه‌ای روشن'),
  MushafBackground(Color(0xFFD5E4F2), 'آبی آسمانی'),
  // The last gold («طلایی کهنه») and the two papers that read orange-brown
  // («بژ گرم»، «خرمایی روشن») were retired at the reader's request: on a full
  // page of glyphs they tire the eye and the dark ink loses its bite.
  // «خرمایی» stays — it is the mid-tone the contrast rules are calibrated on.
  MushafBackground(Color(0xFFA8764C), 'خرمایی'),
  MushafBackground(Color(0xFFE2E9C8), 'زیتونی روشن'),
  MushafBackground(Color(0xFFC4CE97), 'زیتونی'),
  MushafBackground(Color(0xFFCFE2D5), 'سبز مه‌آلود'),
  MushafBackground(Color(0xFFE9EDEF), 'خاکستری صدفی'),
  MushafBackground(Color(0xFFC7D0D8), 'خاکستری سرد'),
  MushafBackground(Color(0xFFE7DFF2), 'یاسی'),
  MushafBackground(Color(0xFFF0D8D2), 'سفال روشن'),
  MushafBackground(Color(0xFFD9AFA6), 'گلی'),
  // ── کاغذهای تیره (cream ink) ──
  MushafBackground(Color(0xFF875A32), 'قهوه‌ای'),
  MushafBackground(Color(0xFF5E3D22), 'قهوه‌ای تیره'),
  MushafBackground(Color(0xFF3B332A), 'شب قهوه‌ای'),
  MushafBackground(Color(0xFF241C16), 'شب شکلاتی'),
  MushafBackground(Color(0xFF16211E), 'شب زمردی'),
  MushafBackground(Color(0xFF141A24), 'شب آبی'),
  MushafBackground(Color(0xFF000000), 'شب مطلق'),
];

/// How many leading entries of [kMushafBackgrounds] are light papers. The list
/// is contiguous by family, and the test asserts the boundary is exact.
const int kMushafDayBackgroundCount = 15;

/// Colours for the ayah being recited, ordered around the hue circle (greens →
/// olives → ambers → reds → magentas → violets → blues → neutrals) so the
/// picker reads as a spectrum instead of a bag of swatches.
///
/// The default sits at index 0 to keep the historical emerald look. These paint
/// the glyphs themselves, so every one is dark enough to hold contrast on the
/// palest paper; on the dark papers [mushafRecitationInkOn] keeps the hue and
/// lifts the contrast rather than swapping the colour out.
const List<MushafRecitationColor> kMushafRecitationColors = [
  MushafRecitationColor(Color(0xFF0E7A5A), 'سبز زمردی'),
  MushafRecitationColor(Color(0xFF12796E), 'فیروزه‌ای'),
  MushafRecitationColor(Color(0xFF14512F), 'سبز جنگلی'),
  MushafRecitationColor(Color(0xFF4C6B2F), 'زیتونی'),
  MushafRecitationColor(Color(0xFF7A6A1A), 'خرمایی'),
  MushafRecitationColor(Color(0xFF8A5A16), 'کهربایی'),
  // The two true oranges («نارنجی سوخته»، «نارنجی») were retired at the
  // reader's request — the loudest hues in the set, and on the brown papers
  // they were the picks that forced the live wash to give up its tint.
  // «کهربایی» and «آجری» keep the warm end of the spectrum present.
  MushafRecitationColor(Color(0xFF9A3B22), 'آجری'),
  MushafRecitationColor(Color(0xFF9A3B3B), 'عنابی'),
  MushafRecitationColor(Color(0xFFB8365A), 'سرخابی'),
  MushafRecitationColor(Color(0xFFA32E6E), 'تمشکی'),
  MushafRecitationColor(Color(0xFF7A3BB5), 'بنفش'),
  MushafRecitationColor(Color(0xFF5B4B8A), 'ارغوانی'),
  MushafRecitationColor(Color(0xFF2F4CA8), 'نیلی'),
  MushafRecitationColor(Color(0xFF1E5AA8), 'آبی'),
  MushafRecitationColor(Color(0xFF2F5D8C), 'لاجوردی'),
  MushafRecitationColor(Color(0xFF0F5C7A), 'آبی نفتی'),
  // The two neutrals are the palette's tightest pair, so they are tinted apart
  // — a cool slate and a warm taupe — rather than both being flat greys. On a
  // night page the highlight is mixed toward cream, which costs them their
  // chroma first; as true greys they converged into one colour there.
  MushafRecitationColor(Color(0xFF3E4A5C), 'ذغالی'),
  MushafRecitationColor(Color(0xFF6E6355), 'خاکستری گرم'),
];

// ── Lookup / migration ──────────────────────────────────────────────────────

/// Index of [color] in [kMushafBackgrounds], or -1 when the value is not one of
/// the palette (a build that shipped a colour since removed).
int mushafBackgroundIndexOf(Color color) {
  for (var i = 0; i < kMushafBackgrounds.length; i++) {
    if (kMushafBackgrounds[i].color.toARGB32() == color.toARGB32()) return i;
  }
  return -1;
}

/// Index of [color] in [kMushafRecitationColors], or -1.
int mushafRecitationIndexOf(Color color) {
  for (var i = 0; i < kMushafRecitationColors.length; i++) {
    if (kMushafRecitationColors[i].color.toARGB32() == color.toARGB32()) {
      return i;
    }
  }
  return -1;
}

/// The palette entry that looks most like [color].
///
/// Used when a persisted colour is not in the palette any more — either the
/// value or the palette changed under it, as it did when the duplicates were
/// removed and the index-based storage was retired. Snapping to the nearest
/// neighbour means an existing reader keeps the page colour they chose instead
/// of being silently reset to the default, and it also covers a persisted
/// *index* from an older build.
int mushafNearestBackgroundIndexOf(Color color) {
  var best = 0;
  var bestDistance = double.infinity;
  for (var i = 0; i < kMushafBackgrounds.length; i++) {
    final d = mushafColorDistance(color, kMushafBackgrounds[i].color);
    if (d < bestDistance) {
      bestDistance = d;
      best = i;
    }
  }
  return best;
}

/// The recited-ayah entry that looks most like [color] (see
/// [mushafNearestBackgroundIndexOf]).
int mushafNearestRecitationIndexOf(Color color) {
  var best = 0;
  var bestDistance = double.infinity;
  for (var i = 0; i < kMushafRecitationColors.length; i++) {
    final d = mushafColorDistance(color, kMushafRecitationColors[i].color);
    if (d < bestDistance) {
      bestDistance = d;
      best = i;
    }
  }
  return best;
}

/// The page backgrounds the reader had before the duplicates were removed and
/// the palette was rewritten, in their persisted-index order.
///
/// Kept only so the one-time migration in [MushafReaderPrefs] can translate an
/// old `quran_bg_day` index into the colour that index used to name. Nothing
/// else may read this — it is history, not a palette.
const List<Color> kLegacyMushafBackgrounds = [
  Color(0xFFFBF3E7),
  Color(0xFFFFFFFF),
  Color(0xFFF2E8D4),
  Color(0xFFEADFC6),
  Color(0xFFE2D3B7),
  Color(0xFFD8C9A8),
  Color(0xFFD9E4EF),
  Color(0xFFD8E6D3),
  Color(0xFFEDE6E2),
  Color(0xFFC9C1BC),
  Color(0xFF3A332C),
  Color(0xFF1E1E24),
  Color(0xFF172B24),
  Color(0xFF171E2E),
  Color(0xFF000000),
  Color(0xFFFFF8EE),
  Color(0xFFDFE6D0),
  Color(0xFFE6E1F0),
  Color(0xFFEFE0DE),
  Color(0xFFD2E5E2),
  Color(0xFF1E1410),
  Color(0xFF241A2E),
  Color(0xFF2B1A1A),
  Color(0xFF10231F),
  Color(0xFF2E2A24),
];

/// The recited-ayah colours as they were persisted (index `0…6`), for the same
/// one-time migration. History, not a palette.
const List<Color> kLegacyMushafRecitationColors = [
  Color(0xFF0E7A5A),
  Color(0xFF1E5AA8),
  Color(0xFFB4531B),
  Color(0xFF7A3BB5),
  Color(0xFFB8365A),
  Color(0xFF8A6D1F),
  Color(0xFF454852),
];

/// Legacy index → colour, clamped, so a corrupt preference cannot throw.
Color mushafLegacyBackgroundColor(int index) => kLegacyMushafBackgrounds[
    index.clamp(0, kLegacyMushafBackgrounds.length - 1)];

/// Legacy recited-ayah index → colour, clamped.
Color mushafLegacyRecitationColor(int index) => kLegacyMushafRecitationColors[
    index.clamp(0, kLegacyMushafRecitationColors.length - 1)];

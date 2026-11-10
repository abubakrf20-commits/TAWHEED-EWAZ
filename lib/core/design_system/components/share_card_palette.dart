import 'package:flutter/material.dart';

/// The share-card palette — the cream «paper» every exported share image is
/// painted on (prayer times, adhkar, duas, aya/tafsir, dua-from-Quran).
///
/// It is deliberately **theme-independent**: the card is exported as a PNG and
/// is read outside the app, so it must look the same whatever phase/theme the
/// sender is in. Only its dark variant follows the app's brightness.
///
/// Before wave 1 every share screen redeclared these seven colours by hand
/// (`_cardBg`/`_cardBgLight`, `_border`/`_borderLight`, …) plus the ink
/// literals inline, which is how the export palette could drift card by card.
/// The values below are byte-identical to those declarations, so this is a pure
/// single-source extraction and the exported images do not change.
class ShareCardPalette {
  const ShareCardPalette._();

  // ── the paper ────────────────────────────────────────────────────────────
  /// Cream page of the light card.
  static const Color bg = Color(0xFFFDF6EC);

  /// Near-black page of the dark card.
  static const Color bgDark = Color(0xFF1B1F2A);

  /// Hairline around the card.
  static const Color border = Color(0xFFE3D6BE);

  /// Divider above the app signature.
  static const Color divider = Color(0xFFEADFC9);

  /// Fill of the small chips (city, calendar cells).
  static const Color chipBg = Color(0xFFF0E6D2);

  /// Text inside those chips.
  static const Color chipText = Color(0xFF5A4632);

  /// The muted label ink (app signature).
  static const Color label = Color(0xFF6B5638);

  /// The teal accent of the adhkar / Quran share cards.
  static const Color accent = Color(0xFF00897B);

  // ── light-mode ink on the cream page (dark mode uses white/white70) ──────
  /// Headlines and times.
  static const Color ink = Color(0xFF1A1A1A);

  /// Body copy.
  static const Color inkBody = Color(0xFF2A2A2A);

  /// The 4-column calendar cells.
  static const Color inkTitle = Color(0xFF26221C);

  /// Secondary body copy.
  static const Color inkMuted = Color(0xFF3A3A3A);

  /// The faintest body copy.
  static const Color inkSubtle = Color(0xFF444444);

  // ── the rotating wisdom box (prayer-times card) ──────────────────────────
  static const Color wisdomArabicDark = Color(0xFFE8C66A);
  static const Color wisdomArabicLight = Color(0xFF8E6A0F);
  static const Color wisdomPersianDark = Color(0xFFDCF0DA);
  static const Color wisdomPersianLight = Color(0xFF1F5A29);
  static const Color wisdomSourceDark = Color(0xFFA8C8A4);
  static const Color wisdomSourceLight = Color(0xFF4E7A50);
  static const Color wisdomHintDark = Color(0xFF8FBF9B);
  static const Color wisdomHintLight = Color(0xFF6FA06A);
  /// Flat fill of the rotating wisdom box — one solid tone, never a gradient.
  static const Color wisdomBgDark = Color(0xFF1A3120);
  static const Color wisdomBgLight = Color(0xFFEAF4E6);
  static const Color wisdomBorderDark = Color(0xFF2E5A38);
  static const Color wisdomBorderLight = Color(0xFFC9E0C3);
}

/// The [ShareCardPalette] resolved for the current app brightness.
///
/// Every share card used to derive this same set — paper, hairline, divider,
/// chip fill and the four ink levels — by hand, so one card could drift from
/// another. Resolving it once keeps the seven exports on one recipe; the
/// values are byte-identical to the hand-written ternaries they replace.
class ShareCardColors {
  const ShareCardColors({
    required this.isDark,
    required this.bg,
    required this.border,
    required this.divider,
    required this.chipBg,
    required this.chipText,
    required this.label,
    required this.head,
    required this.body,
    required this.muted,
  });

  factory ShareCardColors.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ShareCardColors(
      isDark: isDark,
      bg: isDark ? ShareCardPalette.bgDark : ShareCardPalette.bg,
      border: isDark
          ? Colors.white.withValues(alpha: 0.16)
          : ShareCardPalette.border,
      divider: isDark
          ? Colors.white.withValues(alpha: 0.12)
          : ShareCardPalette.divider,
      chipBg: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : ShareCardPalette.chipBg,
      chipText: isDark ? Colors.white : ShareCardPalette.chipText,
      label: isDark
          ? Colors.white.withValues(alpha: 0.9)
          : ShareCardPalette.label,
      head: isDark ? Colors.white : ShareCardPalette.ink,
      body: isDark
          ? Colors.white.withValues(alpha: 0.92)
          : ShareCardPalette.inkBody,
      muted: isDark
          ? Colors.white.withValues(alpha: 0.82)
          : ShareCardPalette.inkSubtle,
    );
  }

  final bool isDark;

  /// The paper the card is printed on.
  final Color bg;

  /// The 1.2 dp hairline around the card.
  final Color border;

  /// Hairlines between blocks.
  final Color divider;

  /// Small chips (city, calendar cells, source).
  final Color chipBg;
  final Color chipText;

  /// Muted metadata ink — labels, sources, the app signature.
  final Color label;

  /// Headlines, Arabic text and numbers.
  final Color head;

  /// Body copy.
  final Color body;

  /// The faintest body copy (explanations, tips).
  final Color muted;

  /// A faint flat wash of [accent] for chips and quiet rows — the share paper
  /// is always opaque, so the alpha is applied here, never by an Opacity.
  Color wash(Color accent, {double alpha = 0.10}) =>
      accent.withValues(alpha: alpha);
}

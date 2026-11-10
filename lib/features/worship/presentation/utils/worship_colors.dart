import 'package:flutter/material.dart';

/// Content-matched accent colors for the daily worship checklist.
///
/// Each default worship item gets its own semantic hue so the icons "read"
/// at a glance (Quran → emerald, night prayer → indigo, wudu → water blue,
/// …). Custom items fall back to a per-icon map so user-added worships stay
/// colorful too. When an item is checked it flips to the success color, so
/// these hues are picked to stay clearly distinct from it.
class WorshipColors {
  WorshipColors._();

  /// Default worship items (id → accent).
  ///
  /// Shades are deliberately deep (Material 800/900) so the same color also
  /// works as 11px badge text on a near-white surface on the light theme.
  static const Map<String, Color> byId = {
    'quran': Color(0xFF1B5E20), // قرائت قرآن — emerald
    'sadaqa': Color(0xFFAD1457), // صدقه — rose (giving)
    'tahajjud': Color(0xFF283593), // نماز شب — indigo night sky
    'fasting': Color(0xFFE65100), // روزه (سنت) — sunset orange (iftar)
    'duha': Color(0xFFF57F17), // نماز ضحی — morning amber
    'good_deeds': Color(0xFF006064), // بر والدین و صله رحم — deep cyan (family)
    'wudu': Color(0xFF01579B), // وضو — water blue
    'ghusl': Color(0xFF00695C), // غسل — deep-water teal
    'tayammum': Color(0xFF5D4037), // تیمم — dust / earth
    'prayer': Color(0xFF6A1B9A), // نماز — prayer purple
  };

  /// Custom-item icons (icon → accent) so user-added worships stay colorful.
  /// (IconData overrides ==/hashCode, so this cannot be a const map.)
  static final Map<IconData, Color> byIcon = {
    Icons.star: const Color(0xFFF57F17),
    Icons.favorite: const Color(0xFFAD1457),
    Icons.menu_book: const Color(0xFF1B5E20),
    Icons.nightlight: const Color(0xFF283593),
    Icons.restaurant: const Color(0xFFE65100),
    Icons.wb_sunny: const Color(0xFFF57F17),
    Icons.people: const Color(0xFF006064),
    Icons.mosque: const Color(0xFF6A1B9A),
    Icons.done_outline: const Color(0xFF00695C),
    Icons.volunteer_activism: const Color(0xFFB71C1C),
    Icons.self_improvement: const Color(0xFF4527A0),
    Icons.broken_image: const Color(0xFF616161),
    Icons.spa: const Color(0xFF33691E),
    Icons.clean_hands: const Color(0xFF01579B),
    Icons.shower: const Color(0xFF00695C),
    Icons.back_hand: const Color(0xFF5D4037),
  };

  /// Neutral fallback for unknown custom icons.
  static const Color fallback = Color(0xFF8C7F72);

  static Color forItem(String id, IconData icon) =>
      byId[id] ?? byIcon[icon] ?? fallback;

  /// Icon-based color for custom worships (used by the add dialog too).
  static Color forIcon(IconData icon) => byIcon[icon] ?? fallback;

  /// Averages [colors] into a single accent so the «طاعات» progress circle
  /// in the evaluation report mirrors the checklist's palette. Returns
  /// [fallback] when the list is empty.
  static Color blend(List<Color> colors) {
    if (colors.isEmpty) return fallback;
    if (colors.length == 1) return colors.first;
    final n = colors.length;
    return Color.fromARGB(
      255,
      (colors.fold<double>(0, (s, c) => s + c.r) / n * 255).round(),
      (colors.fold<double>(0, (s, c) => s + c.g) / n * 255).round(),
      (colors.fold<double>(0, (s, c) => s + c.b) / n * 255).round(),
    );
  }
}

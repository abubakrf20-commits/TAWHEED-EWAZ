import 'package:flutter/material.dart';

/// Identity and icon mapping for the kids tool.
///
/// The two identity colours come straight from the brief and are the ONLY
/// hard-coded hex this feature introduces (the brief allows tool palettes
/// outside the token system):
///   kids accent  E58A2B (نارنجی گرم), stars F2B53A (کهربایی روشن)
///   teacher accent 1F7A63 (سبز دریاچه‌ای)
/// Everything else reads `TimeThemeKit` tokens.
abstract final class Personal2Colors {
  static const Color kids = Color(0xFFE58A2B);
  static const Color kidsStars = Color(0xFFF2B53A);
  static const Color teacher = Color(0xFF1F7A63);
}

/// How a child's chosen `colorKey` maps to an accent.
///
/// The child picks a COLOUR NAME, never a photo — the brief forbids photos of
/// children. An unknown key falls back to the tool accent rather than throwing,
/// so a hand-edited backup cannot blank a card.
abstract final class KidColors {
  static const Map<String, Color> palette = {
    'orange': Personal2Colors.kids,
    'teal': Color(0xFF1F7A63),
    'blue': Color(0xFF2F6FB5),
    'purple': Color(0xFF7A5AA8),
    'rose': Color(0xFFC2607A),
    'green': Color(0xFF3E8E4A),
  };

  static Color of(String key) => palette[key] ?? Personal2Colors.kids;

  static String label(String key) => switch (key) {
        'orange' => 'نارنجی',
        'teal' => 'سبزآبی',
        'blue' => 'آبی',
        'purple' => 'بنفش',
        'rose' => 'صورتی',
        'green' => 'سبز',
        _ => 'نارنجی',
      };

  static const List<String> keys = [
    'orange',
    'teal',
    'blue',
    'purple',
    'rose',
    'green',
  ];
}

/// Icon keys used by habits, rewards and the child-mode grid.
///
/// The templates carry a string key so the JSON stays presentation-free; this
/// is the one place those keys become Material icons. An unknown key degrades
/// to a star, never an empty tile.
abstract final class KidIcons {
  static IconData of(String key) => switch (key) {
        'brush' => Icons.brush_rounded,
        'book' || 'quran' => Icons.menu_book_rounded,
        'home' => Icons.home_rounded,
        'broom' => Icons.cleaning_services_rounded,
        'heart' => Icons.favorite_rounded,
        'gift' => Icons.card_giftcard_rounded,
        'bag' => Icons.backpack_rounded,
        'moon' => Icons.nights_stay_rounded,
        'icecream' => Icons.icecream_rounded,
        'gamepad' => Icons.sports_esports_rounded,
        'park' => Icons.park_rounded,
        'movie' => Icons.movie_rounded,
        'star' => Icons.star_rounded,
        _ => Icons.star_rounded,
      };
}

/// Teacher icon keys (tajweed tiles, actions).
abstract final class TeacherIcons {
  static IconData of(String key) => switch (key) {
        'tajweed' => Icons.tune_rounded,
        'recitation' => Icons.record_voice_over_rounded,
        'hifz' => Icons.workspace_premium_rounded,
        'review' => Icons.refresh_rounded,
        _ => Icons.menu_book_rounded,
      };
}

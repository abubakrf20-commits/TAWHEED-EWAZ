import 'package:flutter/material.dart';

import 'package:tawheeed/core/theme/tool_identity.dart';

/// Identity colours of the four stage-3 tools.
///
/// These are the only hard-coded colours the feature adds — the spec names
/// them, and they are what makes each tool recognisable in the personal-tools
/// section. Everything else (surfaces, text, success/danger) comes from the
/// theme tokens.
const Color familyRelativeColor = ToolIdentity.relatives;
const Color familyKaffaraColor = ToolIdentity.kaffara;
const Color familySavingsColor = ToolIdentity.savings;

/// Avatar tint for a relative: a deterministic pick from a small palette, so
/// the same person always gets the same colour without storing one.
const List<Color> kRelativeAvatarPalette = [
  Color(0xFFD81B60),
  Color(0xFF5E35B1),
  Color(0xFF7E57C2),
  Color(0xFF4CAF50),
  Color(0xFF9B6BC0),
  Color(0xFF3E8FA8),
];

Color relativeAvatarColor(String id) {
  var hash = 0;
  for (final unit in id.codeUnits) {
    hash = (hash * 31 + unit) & 0x7FFFFFFF;
  }
  return kRelativeAvatarPalette[hash % kRelativeAvatarPalette.length];
}

/// First letter of the name, for the initial avatar. Falls back to a person
/// glyph when the name is somehow empty.
String relativeInitial(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? '؟' : trimmed.characters.first;
}

IconData savingsIconFor(String key) => switch (key) {
      'home' => Icons.home_outlined,
      'car' => Icons.directions_car_outlined,
      'travel' => Icons.flight_takeoff_outlined,
      'education' => Icons.school_outlined,
      'gift' => Icons.card_giftcard_outlined,
      'health' => Icons.favorite_outline,
      _ => Icons.savings_outlined,
    };

/// Accent palette for savings goals. The model carries an [accentKey]; this
/// maps it to a real colour so each jar can be its own hue instead of every
/// goal being forced green. Unknown keys fall back to the section colour.
const Map<String, Color> kSavingsAccentPalette = {
  'gold': Color(0xFF2E8B3D),
  'teal': Color(0xFF0E7C86),
  'blue': Color(0xFF3A5BA0),
  'purple': Color(0xFF7E57C2),
  'orange': Color(0xFFE58A2B),
  'rose': Color(0xFFD81B60),
  'amber': Color(0xFFF9A825),
};

Color savingsAccentFor(String key) =>
    kSavingsAccentPalette[key] ?? familySavingsColor;

/// Human-readable label for a savings accent key (for the picker).
String savingsAccentLabel(String key) => switch (key) {
      'gold' => 'سبز',
      'teal' => 'فیروزه‌ای',
      'blue' => 'آبی',
      'purple' => 'بنفش',
      'orange' => 'نارنجی',
      'rose' => 'صورتی',
      'amber' => 'کهربایی',
      _ => 'سبز',
    };

import 'package:flutter/material.dart';

import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

/// The books feature's colour source — the values that are neither theme
/// colours nor identity hues.
///
/// Two kinds live here on purpose:
///
/// * **The reader's page.** `BookReaderScreen` lets the reader switch between
///   a linen page and a neutral night page by hand (`reader_night_mode`), so
///   the surfaces and their ink cannot come from the active palette — they are
///   a property of the book, not of the time of day.
/// * **Chosen colours.** The six highlighter swatches and the per-category
///   library swatches are picked by the reader (or by the data), and are not
///   allowed to move with a theme pass; naming them here keeps the screen free
///   of literals without pretending they are design tokens.
///
/// `tools/design_consistency.py` allowlists one such module per feature
/// (`lib/features/**/presentation/*_palette.dart`) so the tool keeps counting
/// a feature's raw colours *as a single named source* instead of letting them
/// scatter across screens. Anything that is not a chosen colour belongs in
/// `TimeThemeKit`/`TopicHues`/`AppTheme` instead, not here.
class BookPalette {
  BookPalette._();

  // ── the reader's page ────────────────────────────────────────────────────
  /// Linen page of day mode — the app's own paper (`AppTheme.linen`).
  static const Color paperDay = AppTheme.linen;

  /// Neutral night page. Deliberately not a palette colour: the reader picks
  /// it against the ambient light, and a phase-tinted page would fight it.
  static const Color paperNight = Color(0xFF1E1E1E);

  /// Body ink on the linen page.
  static const Color inkDay = Color(0xFF2C2C2C);

  /// The paper a reader may pick, in sheet order.
  ///
  /// Surface and ink travel together: a swatch that only set the background
  /// left the ink baked into each branch, which is how «سبز» inherited the
  /// night ink in one path and the day ink in another. The `key` is what
  /// `reader_paper` persists, so reordering this list cannot repaint a
  /// reader's saved choice.
  static const List<({String key, String label, Color surface, Color ink})>
      papers = [
    (key: 'paper', label: 'کاغذی', surface: AppTheme.linen, ink: inkDay),
    (key: 'white', label: 'سفید', surface: Colors.white, ink: inkDay),
    (key: 'night', label: 'تاریک', surface: paperNight, ink: Colors.white70),
    (key: 'green', label: 'سبز', surface: AppTheme.successBg, ink: inkDay),
  ];

  /// The paper [key] names; an unknown or missing key is the linen page, the
  /// reader's default. A saved preference from a future build must never
  /// leave the page unpainted.
  static ({String key, String label, Color surface, Color ink}) paperFor(
      String? key) {
    for (final p in papers) {
      if (p.key == key) return p;
    }
    return papers.first;
  }

  /// The search strip pinned above the page.
  static const Color searchStripDay = Color(0xFFF0E6D8);
  static const Color searchStripNight = Color(0xFF2A2A2A);

  /// The wash behind a word found by the in-reader search. Pale gold rather
  /// than a saturated yellow: the page is paper, not a highlighter, and the
  /// ink on top of it stays the book's own.
  static const Color searchWash = Color(0xFFFFE082);

  // ── the reader's highlighter swatches, in picker order ───────────────────
  static const List<Color> highlights = [
    Color(0xFFFFD54F), // زرد
    Color(0xFF81C784), // سبز
    Color(0xFF4DD0E1), // فیروزه‌ای
    Color(0xFFFFB74D), // نارنجی
    Color(0xFFF06292), // صورتی
    Color(0xFF64B5F6), // آبی
  ];

  // ── کتابخانه: one identity swatch per category ───────────────────────────
  /// The library sheet's category swatches. `BookModel.category` carries the
  /// Persian key; an unknown key falls back to the palette's primary.
  static const Map<String, Color> categoryColors = {
    'فقه': Color(0xFFC9A94E),
    'عقیده': Color(0xFF6B5B95),
    'تفسیر': Color(0xFF2E86AB),
    'حدیث': Color(0xFF8D6E63),
    'سیره': Color(0xFF4CAF50),
    'اخلاق': Color(0xFFE91E63),
    'ادعیه': TopicHues.ketabkhaneh,
    'عبادات': Color(0xFF00897B),
    'ادبیات': Color(0xFFFF9800),
    'متفرقه': Color(0xFF607D8B),
    'تجوید': Color(0xFF00897B),
    'فقه و عبادات': Color(0xFFC9A94E),
    'تزکیه': TopicHues.ketabkhaneh,
  };
}

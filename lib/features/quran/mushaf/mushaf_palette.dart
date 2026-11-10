import 'package:flutter/material.dart';

/// Fixed mushaf palette (theme-independent), with a night variant for long
/// reading sessions: dark chocolate background + cream glyphs.
///
/// Light:  chocolate [#4A3525], quran hue [#1F7A63], cream [#FBF3E7].
/// Night:  very dark chocolate background, cream text, brighter emerald.
@immutable
class MushafPalette {
  /// Page background (cream / dark chocolate).
  final Color background;

  /// Quran glyphs and primary text (chocolate / cream).
  final Color text;

  /// Accent — surah headers, buttons, progress (emerald / lighter emerald).
  final Color accent;

  /// Header / mini-player background (chocolate / near-black chocolate).
  final Color chrome;

  /// Text and icons on [chrome] (cream).
  final Color onChrome;

  /// Word-highlight fill while the talaawah plays.
  final Color highlight;

  /// Sheets / dialogs background (cream / dark brown).
  final Color surface;

  /// Text on [surface].
  final Color surfaceText;

  /// Muted secondary text on [surface] (subtitles etc.).
  final Color surfaceMuted;

  /// Hairline borders (cards, inputs).
  final Color border;

  final bool isNight;

  const MushafPalette({
    required this.background,
    required this.text,
    required this.accent,
    required this.chrome,
    required this.onChrome,
    required this.highlight,
    required this.surface,
    required this.surfaceText,
    required this.surfaceMuted,
    required this.border,
    required this.isNight,
  });

  static const MushafPalette light = MushafPalette(
    background: Color(0xFFFBF3E7),
    text: Color(0xFF4A3525),
    accent: Color(0xFF1F7A63), // = SectionHues.quran — one quran identity hue
    chrome: Color(0xFF4A3525),
    onChrome: Color(0xFFFBF3E7),
    highlight: Color(0x331F7A63), // quran hue @ ~20%
    surface: Color(0xFFFBF3E7),
    surfaceText: Color(0xFF4A3525),
    surfaceMuted: Color(0x8A4A3525), // chocolate @ ~54%
    border: Color(0x1A4A3525), // chocolate @ ~10%
    isNight: false,
  );

  static const MushafPalette night = MushafPalette(
    background: Color(0xFF1E1410), // very dark chocolate
    text: Color(0xFFF3E8D6), // cream
    accent: Color(0xFF6FB59C), // lighter emerald, visible on dark
    chrome: Color(0xFF140C08), // near-black chocolate
    onChrome: Color(0xFFF3E8D6),
    highlight: Color(0x596FB59C), // emerald @ ~35% for visibility
    surface: Color(0xFF2B1D15), // dark brown
    surfaceText: Color(0xFFF3E8D6),
    surfaceMuted: Color(0xB3F3E8D6), // cream @ ~70%
    border: Color(0x24F3E8D6), // cream @ ~14%
    isNight: true,
  );
}

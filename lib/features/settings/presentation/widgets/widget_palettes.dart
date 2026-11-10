import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Time-of-day phase used by the «خودکار» widget palette. The boundaries are
/// the five adhan times (plus sunrise), so the native widget re-renders at
/// every phase flip through its existing boundary alarms.
enum WidgetPhase { night, dawn, morning, afternoon, sunset, evening }

/// One widget palette from [assets/widget_palettes.json].
class WidgetPalette {
  final String id;
  final String name;
  final String bg;
  final String bgEnd;
  final String text;
  final String accent;
  final bool light;
  final bool auto;
  final List<String> autoPhases;

  const WidgetPalette({
    required this.id,
    required this.name,
    this.bg = '#000000',
    this.bgEnd = '#000000',
    this.text = '#FFFFFF',
    this.accent = '#FFFFFF',
    this.light = false,
    this.auto = false,
    this.autoPhases = const [],
  });

  factory WidgetPalette.fromJson(Map<String, dynamic> json) => WidgetPalette(
        id: json['id'] as String,
        name: json['name'] as String,
        bg: (json['bg'] as String?) ?? '#000000',
        bgEnd: (json['bgEnd'] as String?) ?? '#000000',
        text: (json['text'] as String?) ?? '#FFFFFF',
        accent: (json['accent'] as String?) ?? '#FFFFFF',
        light: (json['light'] as bool?) ?? false,
        auto: (json['auto'] as bool?) ?? false,
        autoPhases:
            ((json['autoPhases'] as List?) ?? const []).cast<String>().toList(),
      );

  Color get bgColor => _widgetColorFromHex(bg);
  Color get bgEndColor => _widgetColorFromHex(bgEnd);
  Color get textColor => _widgetColorFromHex(text);
  Color get accentColor => _widgetColorFromHex(accent);
}

/// Loader + contract helpers over [assets/widget_palettes.json] — the single
/// source the generator, the Kotlin side and this preview all read.
class WidgetPalettes {
  static const assetPath = 'assets/widget_palettes.json';
  static const defaultPaletteId = 'brown_gold';

  static List<WidgetPalette>? _cache;
  static List<double>? _opacitySteps;

  static Future<List<WidgetPalette>> load() async {
    final cached = _cache;
    if (cached != null) return cached;
    try {
      final raw = await rootBundle.loadString(assetPath);
      return _parse(raw);
    } catch (e) {
      AppLogger.warning('WidgetPalettes', 'load failed: $e');
      return _cache = const [fallback];
    }
  }

  static List<WidgetPalette> _parse(String raw) {
    final config = jsonDecode(raw) as Map<String, dynamic>;
    _opacitySteps = ((config['opacitySteps'] as List?) ?? const [1.0])
        .cast<num>()
        .map((e) => e.toDouble())
        .toList();
    return _cache = ((config['palettes'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(WidgetPalette.fromJson)
        .toList(growable: false);
  }

  /// Test seam: parse a JSON string directly.
  static List<WidgetPalette> parseForTest(String raw) => _parse(raw);

  static const fallback = WidgetPalette(
    id: defaultPaletteId,
    name: 'قهوه‌ای طلایی',
    bg: '#3B2316',
    bgEnd: '#2A1A10',
    text: '#F5EDE3',
    accent: '#C9A94E',
  );

  static WidgetPalette byId(List<WidgetPalette> palettes, String id) =>
      palettes.firstWhere(
        (p) => p.id == id,
        orElse: () => palettes.firstWhere(
          (p) => p.id == defaultPaletteId,
          orElse: () => fallback,
        ),
      );

  /// The palette a given phase maps to via each palette's `autoPhases`.
  /// Falls back to the default palette when no palette claims the phase.
  static WidgetPalette forPhase(List<WidgetPalette> palettes, WidgetPhase phase) {
    final key = phase.name;
    for (final p in palettes) {
      if (p.autoPhases.contains(key)) return p;
    }
    return byId(palettes, defaultPaletteId);
  }

  static List<double> opacitySteps(List<WidgetPalette> palettes) =>
      _opacitySteps ?? const [1.0, 0.85, 0.7, 0.55];

  /// The selection the native resolver migrates a pre-theming install to:
  /// exact bg match first, then the nearest palette of the same lightness,
  /// and the opacity step nearest the old value. The settings page shows the
  /// same choice before the first widget render has persisted it natively.
  static (String, int) legacySelection(
    List<WidgetPalette> palettes,
    String? legacyBgHex,
    double legacyOpacity,
  ) {
    final step = _nearestStep(palettes, legacyOpacity);
    if (legacyBgHex == null) {
      return (defaultPaletteId, step);
    }
    final legacy = _parseOpaque(legacyBgHex);
    if (legacy == null) return (defaultPaletteId, step);
    for (final p in palettes) {
      if (p.bgColor.toARGB32() == legacy) return (p.id, step);
    }
    final legacyLight = _luminanceInt(legacy) > 0.5;
    final sameLightness =
        palettes.where((p) => p.light == legacyLight).toList();
    if (sameLightness.isEmpty) return (defaultPaletteId, step);
    String best = sameLightness.first.id;
    var bestDistance = double.maxFinite;
    for (final p in sameLightness) {
      final d = _colorDistance(p.bgColor.toARGB32(), legacy);
      if (d < bestDistance) {
        bestDistance = d;
        best = p.id;
      }
    }
    return (best, step);
  }

  static int _nearestStep(List<WidgetPalette> palettes, double opacity) {
    if (opacity < 0) return 0;
    final steps = opacitySteps(palettes);
    var best = 0;
    var bestDistance = double.maxFinite;
    for (var i = 0; i < steps.length; i++) {
      final d = (steps[i] - opacity).abs();
      if (d < bestDistance) {
        bestDistance = d;
        best = i;
      }
    }
    return best;
  }

  static int? _parseOpaque(String hex) {
    var h = hex.replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h';
    if (h.length != 8) return null;
    return int.tryParse(h, radix: 16);
  }

  static double _luminanceInt(int c) => _luminance(Color(c));

  static double _colorDistance(int a, int b) {
    final dr = ((a >> 16) & 0xFF) - ((b >> 16) & 0xFF);
    final dg = ((a >> 8) & 0xFF) - ((b >> 8) & 0xFF);
    final db = (a & 0xFF) - (b & 0xFF);
    return (dr * dr + dg * dg + db * db).toDouble();
  }

  /// WCAG 2.x contrast ratio between two opaque colors.
  static double contrastRatio(Color a, Color b) {
    final la = _luminance(a);
    final lb = _luminance(b);
    final lighter = la > lb ? la : lb;
    final darker = la > lb ? lb : la;
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Composite [fg] at [opacity] over [backdrop] (launcher wallpaper proxy).
  static Color composite(Color fg, double opacity, Color backdrop) => Color.fromARGB(
        255,
        ((fg.r * 255 * opacity) + (backdrop.r * 255 * (1 - opacity))).round(),
        ((fg.g * 255 * opacity) + (backdrop.g * 255 * (1 - opacity))).round(),
        ((fg.b * 255 * opacity) + (backdrop.b * 255 * (1 - opacity))).round(),
      );

  static double _luminance(Color c) {
    double channel(double v) {
      final s = v / 255.0;
      return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
    }

    return 0.2126 * channel(c.r * 255) +
        0.7152 * channel(c.g * 255) +
        0.0722 * channel(c.b * 255);
  }
}

Color _widgetColorFromHex(String hex) {
  var h = hex.replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  return Color(int.parse(h, radix: 16));
}

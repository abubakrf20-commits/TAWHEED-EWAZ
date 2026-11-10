import 'package:flutter/services.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Widget tokens loaded from [assets/content/widget_tokens.json].
///
/// Static const values are the source of truth; [init] only preloads the
/// shared JSON at boot so the Kotlin widget side can read the same file.
class WidgetTokens {
  // ── Brown + Gold Palette ──
  static const int primaryGreen = 0xFFC9A94E;
  static const int deepGreen = 0xFF5C3D2E;
  static const int mintGreen = 0xFFA89282;
  static const int bgLight = 0xFFFBF8F3;
  static const int surfaceLight = 0xFFFFFFFF;
  static const int textDark = 0xFF3B2316;
  static const int textMuted = 0xFF8B6F5E;

  static const int bgDark = 0xFF1E1208;
  static const int surfaceDark = 0xFF342418;
  static const int primaryGreenDark = 0xFFD4B96A;
  static const int textLight = 0xFFF5EDE3;
  static const int textMutedDark = 0xFF9A8A7A;

  // ── Spacing ──
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;

  // ── Radius ──
  static const double radiusSm = 8;
  static const double radiusMedium = 14;
  static const double radiusLg = 20;

  /// The home-screen widgets' corner radius — mirrors
  /// `WidgetTheme.CORNER_RADIUS_DP` and the generated skin drawables, so the
  /// settings preview, the runtime gradient and the baked skins agree.
  static const double widgetRadius = 22;

  // ── Font Sizes ──
  static const double fontXs = 10;
  static const double fontSm = 12;
  static const double fontMd = 14;
  static const double fontLg = 16;
  static const double fontXl = 20;
  static const double fontSizeTime = 28;
  static const double fontSizeCounter = 42;

  // ── Widget Dimensions ──
  static const double widgetSmallWidth = 250;
  static const double widgetSmallHeight = 140;
  static const double widgetMediumWidth = 320;
  static const double widgetMediumHeight = 220;
  static const double widgetLargeWidth = 320;
  static const double widgetLargeHeight = 340;

  // ── SharedPreferences Keys ──
  static const String keyBgColor = 'widget_bg_color';
  static const String keyOpacity = 'widget_opacity';

  /// Preload [assets/content/widget_tokens.json] so the native widget side
  /// finds it warm in the asset cache. Call once during app boot.
  static Future<void> init() async {
    try {
      await rootBundle.loadString('assets/content/widget_tokens.json');
    } catch (e) {
      AppLogger.warning('WidgetDesignTokens', 'tokens load failed: $e');
    }
  }

  // ── Helpers ──
  static String colorToHex(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
  static Color hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  static Map<String, dynamic> toMap() => {
        'primaryGreen': primaryGreen,
        'deepGreen': deepGreen,
        'mintGreen': mintGreen,
        'bgLight': bgLight,
        'surfaceLight': surfaceLight,
        'textDark': textDark,
        'textMuted': textMuted,
      };
}

import 'package:flutter/material.dart';

/// The splash field is FIXED — it is the app's opening frame, not a themed
/// surface. Nothing here reads `AppTheme`, `TimeThemeKit`, the accent preset
/// or `ThemeMode`, and the screen paints it as literal colors: a splash that
/// changed with the time of day would flash a different color for one frame
/// before the app's own theme resolved.
///
/// The ramp is the same four stops the native side carries
/// (`android/app/src/main/res/values/colors.xml` → `splash_field_*`), and
/// `res/drawable/launch_background.xml` is that ramp with NOTHING drawn on it:
/// the Android 12+ system window paints the same field and no mark, so the
/// hand-over to this frame only adds the coin and the decorations — it moves
/// no colour and draws no second logo.
class SplashColors {
  const SplashColors._();

  static const Color fieldTop = Color(0xFF24150E);
  static const Color fieldUpper = Color(0xFF4A3024);
  static const Color fieldLower = Color(0xFF7A5016);
  static const Color fieldBottom = Color(0xFFA8741F);

  /// The middle of the ramp: `splash_field_mid` on Android, and the color the
  /// Flutter ramp shows at 50 % height.
  static const Color fieldMid = Color(0xFF5F3E1E);

  /// Tagline, crescent and the loader dots.
  static const Color goldLight = Color(0xFFFFEFB8);

  /// A few of the stars — the rest are warm white.
  static const Color starBright = Color(0xFFFFF0B8);
  static const Color starSoft = Color(0xA6FFFFFF); // white @ 65 %

  /// Tile fill, border, glyph, and the label printed on the gold field.
  static const Color tileFill = Color(0x8024150E); // fieldTop @ 50 %
  static const Color tileBorder = Color(0x73FFE296); // FFE296 @ 45 %
  static const Color tileGlyph = Color(0xFFFFE9A8);
  static const Color tileLabel = Color(0xFF2A1A12);
}

/// The splash geometry, in dp. Everything the spec fixes lives here so the
/// screen, the tests and the native drawables can be read against one table.
class SplashSizes {
  const SplashSizes._();

  /// `clamp(0.7056 * screenWidth, 201.6, 288)` — the coin is the page. The
  /// box is the earlier `0.784`/`224`–`320` table scaled by 0.9 (the user's
  /// «۱۰٪ کوچکتر»), so every derived measurement (the lift, the tagline's top
  /// edge, the floor) keeps the same RELATION to the mark at every screen
  /// width, not only in the clamped range. It still fills most of the width,
  /// which is why the composition lifts it above the centre ([logoLift])
  /// instead of hanging the tagline below a dead-centre box.
  static double logoSize(double screenWidth) =>
      (screenWidth * 0.7056).clamp(201.6, 288.0);

  static const double logoMin = 201.6;
  static const double logoMax = 288;

  /// How far above the exact screen centre the coin sits. One centimetre, in
  /// the unit Android defines as 1/160 of an inch: 160 / 2.54 ≈ 63 dp.
  static const double logoLift = 63;

  /// The floor for the coin's top edge. Only ever binds on a window so short
  /// that the lift alone would push the mark off the screen.
  static const double logoTopFloor = 16;

  /// Tagline sits below the logo box.
  static const double taglineGap = 24;
  static const double taglineSize = 14.5;

  /// The splash never lets the OS font scale run past this — a 2× tagline
  /// would collide with the tiles on a short screen.
  static const double maxTextScale = 1.3;

  static const double tile = 58;
  static const double tileRadius = 19;
  static const double tileGap = 16;
  static const double tileGlyph = 28;
  static const double tileLabelSize = 11.5;
  static const double tileLabelGap = 7;
  static const double bottomPadding = 42;

  /// Crescent: ~36 dp of moon, inset from the screen's RTL-leading (right)
  /// edge and below the status bar.
  static const double moonDiameter = 36;
  static const double moonEdgeInset = 26;
  static const double moonTopInset = 36;

  static const double loaderDot = 5;
  static const double loaderGap = 8;

  /// Row width the four tiles need. Below this the tiles are hidden (never
  /// shrunk) so nothing ever clips or overflows.
  static double tilesRowWidth(double screenWidth) =>
      tile * 4 + tileGap * 3 + 32;
}

/// The splash field as ONE gradient, shared by the painter and the tests.
class SplashField {
  const SplashField._();

  /// Top-to-bottom, dark brown into gold-brown. Painted by the same
  /// `CustomPainter` as the stars rather than by a `DecoratedBox`: the coin
  /// must have no box of any kind around it, and with the field as paint the
  /// logo provably sits in it with nothing drawn between the two.
  static const LinearGradient gradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      SplashColors.fieldTop,
      SplashColors.fieldUpper,
      SplashColors.fieldLower,
      SplashColors.fieldBottom,
    ],
    stops: [0.0, 0.34, 0.70, 1.0],
  );
}

/// The splash's own assets, as ONE provider instance: the screen paints it and
/// `initState` precaches it, and both must land on the same image stream so
/// the coin never decodes twice on a weak phone.
class SplashAssets {
  const SplashAssets._();

  /// The app's real logo — the gold coin, exactly as shipped. Nothing is
  /// painted on, around or over it.
  static const String logoPath = 'assets/icon_foreground.png';

  /// The asset ships at 512 px, which covers the box at 3× density, so this
  /// is the full-detail decode. One instance, shared by the pre-cache and the
  /// widget, so the coin decodes exactly once.
  static const ImageProvider logo = AssetImage(logoPath);
}

/// The timings, in one place so the orchestrator and the tests agree.
class SplashTiming {
  const SplashTiming._();

  /// Shortest time the splash may be visible. No maximum: a slow cold start
  /// stays on the splash as long as it needs, and a fast one leaves the moment
  /// the floor has passed.
  ///
  /// Raised 400 ms → 1400 ms on 2026-10-13 at the user's request (the opening
  /// frame read too brief), then lowered to 800 ms in the 2026-10-19 audit: at
  /// 1.4 s the brand moment cost more than it gave on every cold start. 800 ms
  /// keeps the mark on screen twice as long as the original 400 ms floor.
  /// Only this floor moved: the 2 s loader delay and the 12 s hang guard are
  /// untouched, so a slow cold start still waits on its init rather than on
  /// this timer.
  static const Duration minimumShow = Duration(milliseconds: 800);

  /// The three dots only speak up once the wait is actually noticeable.
  static const Duration loaderDelay = Duration(seconds: 2);

  /// A wedged init must never mean an endless splash.
  static const Duration hangGuard = Duration(seconds: 12);

  /// Cross-fade from the splash into Home/onboarding.
  static const Duration crossFade = Duration(milliseconds: 250);
}

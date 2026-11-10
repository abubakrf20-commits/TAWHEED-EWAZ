import 'package:flutter/material.dart';

import 'package:tawheeed/core/theme/rtl_transitions.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

class AppTheme {
  AppTheme._();

  /// ═══ FONT IDENTITY ═══
  /// Calibri is the app's brand font and stays the default forever.
  /// [defaultFontFamily] is the immutable identity; [fontFamily] is the
  /// active font that follows the user's setting (defaults to Calibri) so
  /// every hardcoded `TextStyle(fontFamily: AppTheme.fontFamily)` updates
  /// consistently when the user picks Vazirmatn/Amiri.
  static const String defaultFontFamily = 'Calibri';
  static String fontFamily = defaultFontFamily;

  // ═════════════════════════════════════════════
  // SPACING SCALE (unified source of truth)
  // ═════════════════════════════════════════════
  static const double space2 = 2;
  static const double space4 = 4;
  static const double space6 = 6;
  static const double space8 = 8;
  static const double space10 = 10;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space48 = 48;
  static const double space64 = 64;

  // ═════════════════════════════════════════════
  // BORDER RADIUS (unified source of truth)
  // ═════════════════════════════════════════════
  static const double radiusNone = 0;
  static const double radiusSmall = 8;
  static const double radiusMedium = 12;
  static const double radiusLarge = 16;
  static const double radiusXLarge = 24;
  static const double radiusXxxLarge = 32;

  // ═════════════════════════════════════════════
  // CARD DESIGN COLOR PALETTE (from CardDesignSystem)
  // ═════════════════════════════════════════════
  // ─── Structural Browns
  static const Color espresso = Color(0xFF2C1810);
  static const Color walnut = Color(0xFF4A3228);
  static const Color mocha = Color(0xFF5E4338);
  static const Color cocoa = Color(0xFF6F5245);
  static const Color taupe = Color(0xFF8B7565);
  static const Color warmSand = Color(0xFFB8A696);
  // ─── Light Surfaces
  static const Color parchment = Color(0xFFFAF6F0);
  static const Color linen = Color(0xFFF5EDE3);
  static const Color shell = Color(0xFFE8DDD0);
  // ─── Dark Surfaces
  static const Color deepNight = Color(0xFF1A0F08);
  static const Color darkWalnut = Color(0xFF2A1C12);
  static const Color darkMocha = Color(0xFF352518);
  static const Color darkCocoa = Color(0xFF3F2E20);
  // ─── Gold Accents
  static const Color goldRich = Color(0xFFC48A27);

  /// The pale header/date-pill gold (`AppColors.datePillShamsi` had the same
  /// value, re-declared by 8 more files) — the second stop of the gold pair.
  static const Color goldPale = Color(0xFFC9A94E);
  static const Color goldMuted = Color(0xFFB07A1E);
  static const Color goldSoft = Color(0xFFD4B96A);
  // ─── Green Accent
  static const Color greenRich = Color(0xFF4A7C4A);
  static const Color greenMuted = Color(0xFF5B8C5A);
  static const Color greenSoft = Color(0xFF7CB57A);
  // ─── Semantic Text on Dark
  static const Color textOnDark = Color(0xFFF5EDE3);
  static const Color textOnDarkMuted = Color(0xB3F5EDE3);
  static const Color textOnDarkGhost = Color(0x80F5EDE3);
  // ─── Semantic Text on Light
  static const Color textOnLight = Color(0xFF2C1810);
  static const Color textOnLightSecondary = Color(0xFF6F5245);
  static const Color textOnLightMuted = Color(0xFF8B7565);

  // ═════════════════════════════════════════════
  // ANIMATION DURATIONS
  // ═════════════════════════════════════════════
  static const Duration fastAnim = Duration(milliseconds: 150);
  static const Duration medAnim = Duration(milliseconds: 300);

  // ═══════════════════════════════════════════════════════════
  // ACTIVE PALETTE BRIDGE (2026 redesign)
  // Every color below is driven by the active AppPalette, copied in by
  // [applyTheme] on each theme/phase change. Defaults are the gold brand
  // palette so first-frame builds and tests see coherent values.
  // ═══════════════════════════════════════════════════════════
  static AppPalette activeLightPalette = AppPalettes.goldLight;
  static AppPalette activeDarkPalette = AppPalettes.goldDark;

  // ── Light tokens
  static Color lightPrimary = AppPalettes.goldLight.primary;
  static Color lightPrimaryStrong = AppPalettes.goldLight.primaryStrong;
  static Color lightPrimarySoft = AppPalettes.goldLight.primarySoft;
  static Color lightSecondary = AppPalettes.goldLight.secondary;
  static Color lightSecondarySoft = AppPalettes.goldLight.secondarySoft;
  static Color lightTertiary = AppPalettes.goldLight.tertiary;
  static Color lightTertiarySoft = AppPalettes.goldLight.tertiarySoft;
  static Color lightBackground = AppPalettes.goldLight.pageBg;
  static Color lightSurface = AppPalettes.goldLight.surface;
  static Color lightSurfaceAlt = AppPalettes.goldLight.surfaceAlt;
  static Color lightSurfaceMuted = AppPalettes.goldLight.surfaceMuted;
  static Color lightCard = AppPalettes.goldLight.card;
  static Color lightCardTinted = AppPalettes.goldLight.surfaceMuted;
  static Color lightScaffoldTint = AppPalettes.goldLight.pageBg;
  static Color lightSurfaceTint = AppPalettes.goldLight.surface;
  static Color lightSurfaceAltTint = AppPalettes.goldLight.surfaceAlt;
  static Color lightSurfaceMutedTint = AppPalettes.goldLight.surfaceMuted;
  static Color lightCardTint = AppPalettes.goldLight.card;
  static Color lightTextPrimary = AppPalettes.goldLight.textPrimary;
  static Color lightTextSecondary = AppPalettes.goldLight.textSecondary;
  static Color lightTextMuted = AppPalettes.goldLight.textMuted;
  static Color lightOutline = AppPalettes.goldLight.outline;
  static Color lightDivider = AppPalettes.goldLight.divider;
  static Color heroTopLight = AppPalettes.goldLight.heroTop;
  static Color heroMidLight = AppPalettes.goldLight.heroMid;
  static Color heroBottomLight = AppPalettes.goldLight.heroBottom;
  static Color heroInkLight = AppPalettes.goldLight.heroInk;

  // ── Dark tokens
  static Color darkPrimary = AppPalettes.goldDark.primary;
  static Color darkPrimaryStrong = AppPalettes.goldDark.primaryStrong;
  static Color darkPrimarySoft = AppPalettes.goldDark.primarySoft;
  static Color darkSecondary = AppPalettes.goldDark.secondary;
  static Color darkSecondarySoft = AppPalettes.goldDark.secondarySoft;
  static Color darkTertiary = AppPalettes.goldDark.tertiary;
  static Color darkTertiarySoft = AppPalettes.goldDark.tertiarySoft;
  static Color darkBackground = AppPalettes.goldDark.pageBg;
  static Color darkSurface = AppPalettes.goldDark.surface;
  static Color darkSurfaceAlt = AppPalettes.goldDark.surfaceAlt;
  static Color darkSurfaceMuted = AppPalettes.goldDark.surfaceMuted;
  static Color darkCard = AppPalettes.goldDark.card;
  static Color darkCardTinted = AppPalettes.goldDark.surfaceMuted;
  static Color darkElevated = AppPalettes.goldDark.elevated;
  static Color darkScaffoldTint = AppPalettes.goldDark.pageBg;
  static Color darkSurfaceTint = AppPalettes.goldDark.surface;
  static Color darkSurfaceAltTint = AppPalettes.goldDark.surfaceAlt;
  static Color darkSurfaceMutedTint = AppPalettes.goldDark.surfaceMuted;
  static Color darkCardTint = AppPalettes.goldDark.card;
  static Color darkTextPrimary = AppPalettes.goldDark.textPrimary;
  static Color darkTextSecondary = AppPalettes.goldDark.textSecondary;
  static Color darkTextMuted = AppPalettes.goldDark.textMuted;
  static Color darkOutline = AppPalettes.goldDark.outline;
  static Color darkDivider = AppPalettes.goldDark.divider;
  static Color heroTopDark = AppPalettes.goldDark.heroTop;
  static Color heroMidDark = AppPalettes.goldDark.heroMid;
  static Color heroBottomDark = AppPalettes.goldDark.heroBottom;
  static Color heroInkDark = AppPalettes.goldDark.heroInk;

  // ── Module identity hues (fixed across every palette — the design's
  //    colored-pill language; sections keep their color in every theme)
  static Color homeAccent = SectionHues.home;
  static Color quranAccent = SectionHues.quran;
  static Color azkarAccent = SectionHues.tasbih;
  static Color calendarAccent = SectionHues.calendar;
  static Color settingsAccent = SectionHues.more;
  static Color evaluationAccent = SectionHues.evaluation;
  static Color zakatAccent = const Color(0xFF6B8E5A);
  static Color hadithAccent = const Color(0xFF00695C); // pinned design rule
  static Color hajjAccent = const Color(0xFFC9A94E);
  static Color notesAccent = const Color(0xFFF5A623);
  static Color womenAccent = const Color(0xFFEC407A);
  static Color fastingAccent = const Color(0xFF7C4DFF);
  static Color prayerAccent = const Color(0xFF4A7C5A);
  static Color purificationAccent = const Color(0xFF1565C0);
  static Color scienceAccent = const Color(0xFF6A1B9A);
  static Color duaAccent = const Color(0xFF2E7D32);
  static Color tasksAccent = const Color(0xFF5C6BC0);

  static ThemeKind? _lastKind;
  static TimePhase? _lastPhase;

  /// Applies the theme for this moment. Idempotent: skipped when the
  /// kind+phase pair is unchanged (main.dart rebuilds on phase change).
  static void applyTheme({required ThemeKind kind, required TimePhase phase}) {
    if (kind == _lastKind && phase == _lastPhase) return;
    _lastKind = kind;
    _lastPhase = phase;
    activeLightPalette = AppPalettes.of(kind: kind, phase: phase, dark: false);
    activeDarkPalette = AppPalettes.of(kind: kind, phase: phase, dark: true);
    _applyPalette(activeLightPalette, isDark: false);
    _applyPalette(activeDarkPalette, isDark: true);
  }

  static void _applyPalette(AppPalette p, {required bool isDark}) {
    if (isDark) {
      darkPrimary = p.primary;
      darkPrimaryStrong = p.primaryStrong;
      darkPrimarySoft = p.primarySoft;
      darkSecondary = p.secondary;
      darkSecondarySoft = p.secondarySoft;
      darkTertiary = p.tertiary;
      darkTertiarySoft = p.tertiarySoft;
      darkBackground = p.pageBg;
      darkSurface = p.surface;
      darkSurfaceAlt = p.surfaceAlt;
      darkSurfaceMuted = p.surfaceMuted;
      darkCard = p.card;
      darkCardTinted = p.surfaceMuted;
      darkElevated = p.elevated;
      darkScaffoldTint = p.pageBg;
      darkSurfaceTint = p.surface;
      darkSurfaceAltTint = p.surfaceAlt;
      darkSurfaceMutedTint = p.surfaceMuted;
      darkCardTint = p.card;
      darkTextPrimary = p.textPrimary;
      darkTextSecondary = p.textSecondary;
      darkTextMuted = p.textMuted;
      darkOutline = p.outline;
      darkDivider = p.divider;
      heroTopDark = p.heroTop;
      heroMidDark = p.heroMid;
      heroBottomDark = p.heroBottom;
      heroInkDark = p.heroInk;
    } else {
      lightPrimary = p.primary;
      lightPrimaryStrong = p.primaryStrong;
      lightPrimarySoft = p.primarySoft;
      lightSecondary = p.secondary;
      lightSecondarySoft = p.secondarySoft;
      lightTertiary = p.tertiary;
      lightTertiarySoft = p.tertiarySoft;
      lightBackground = p.pageBg;
      lightSurface = p.surface;
      lightSurfaceAlt = p.surfaceAlt;
      lightSurfaceMuted = p.surfaceMuted;
      lightCard = p.card;
      lightCardTinted = p.surfaceMuted;
      lightScaffoldTint = p.pageBg;
      lightSurfaceTint = p.surface;
      lightSurfaceAltTint = p.surfaceAlt;
      lightSurfaceMutedTint = p.surfaceMuted;
      lightCardTint = p.card;
      lightTextPrimary = p.textPrimary;
      lightTextSecondary = p.textSecondary;
      lightTextMuted = p.textMuted;
      lightOutline = p.outline;
      lightDivider = p.divider;
      heroTopLight = p.heroTop;
      heroMidLight = p.heroMid;
      heroBottomLight = p.heroBottom;
      heroInkLight = p.heroInk;
    }
  }

  // =========================
  // Status colors — global across every palette (semantic, not identity)
  // =========================
  static const Color lightSuccess = Color(0xFF5B8C5A);
  static const Color lightWarning = Color(0xFFC48A27);
  static const Color lightError = Color(0xFFC62828);
  static const Color lightInfo = Color(0xFF1565C0);

  static const Color darkSuccess = Color(0xFF7CB57A);
  static const Color darkWarning = Color(0xFFD4B05A);
  static const Color darkError = Color(0xFFEF5350);
  static const Color darkInfo = Color(0xFF42A5F5);

  // =========================
  // Legacy aliases
  // =========================
  static Color get primary => lightPrimary;
  static Color get primaryLight => lightTertiary;
  static Color get primaryDark => lightPrimaryStrong;
  static Color get accent => lightTertiary;
  static Color get gold => lightTertiary;
  static Color get cream => lightSurfaceAlt;
  static Color get creamDark => lightSurfaceMuted;

  static const Color success = lightSuccess;
  static const Color successBg = Color(0xFFF0F5EC);
  static const Color warning = lightWarning;
  static const Color warningBg = Color(0xFFFFF8E1);
  static const Color error = lightError;
  static const Color errorBg = Color(0xFFFFEBEE);
  static const Color info = lightInfo;
  static const Color infoBg = Color(0xFFEFF3F5);
  static const Color doneBg = Color(0xFFF0F5EC);
  static const Color doneColor = lightSuccess;

  static Color get surfaceLight => lightBackground;
  static Color get cardLight => lightCard;
  static Color get onSurfaceLight => lightTextPrimary;
  static Color get secondaryLight => lightTextSecondary;
  static Color get outlineLight => lightOutline;

  static Color get surfaceDark => darkBackground;
  static Color get surfaceDarkElevated => darkSurface;
  static Color get cardDark => darkCard;
  static Color get onSurfaceDark => darkTextPrimary;
  static Color get secondaryDark => darkTextSecondary;
  static Color get outlineDark => darkOutline;

  // =========================
  // Quran Reader Theme Colors
  // =========================
  static const Color quranLightBg = Color(0xFFF5F0E8);
  static const Color quranLightText = Color(0xFF2C1810);

  static const Color quranDarkBg = Color(0xFF0C0805);
  static const Color quranDarkText = Color(0xFFF2EDE6);

  static LinearGradient get primaryGradient => LinearGradient(
        colors: [lightTertiary, lightPrimary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get heroGradient => LinearGradient(
        colors: [lightPrimaryStrong, lightPrimary, lightTertiary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get heroGradientLight => LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [lightPrimaryStrong, lightTertiary],
      );

  static LinearGradient get heroGradientDark => LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [darkSurfaceAlt, darkPrimary],
      );

  // =========================
  // Clock Card Gradients
  // =========================
  /// Clock gradient for light mode — uses current accent primary
  static LinearGradient clockGradientLight() => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [lightTertiary, lightPrimary],
      );

  /// Clock gradient for dark mode — glowing accent tones
  static LinearGradient get clockGradientDark => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [darkPrimaryStrong, darkPrimary],
      );

  /// Next prayer color by prayer name.
  /// Accepts both Arabic names (used in the UI) and English keys (used internally).
  static Color prayerNameColor(String name) {
    return switch (name) {
      // Arabic names (displayed in UI)
      'فجر' => const Color(0xFF7C4DFF),
      'طلوع آفتاب' || 'طلوع' => const Color(0xFFFF8F00),
      'ظهر' => const Color(0xFFFFC107),
      'عصر' => const Color(0xFFFF9800),
      'مغرب' => const Color(0xFFFF5722),
      'عشاء' => const Color(0xFF5C6BC0),
      // English keys (internal use)
      'fajr' => const Color(0xFF7C4DFF),
      'sunrise' || 'shorouq' => const Color(0xFFFF8F00),
      'dhuhr' => const Color(0xFFFFC107),
      'asr' => const Color(0xFFFF9800),
      'maghrib' => const Color(0xFFFF5722),
      'isha' => const Color(0xFF5C6BC0),
      _ => const Color(0xFFC9A94E),
    };
  }

  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration pageTransition = Duration(milliseconds: 350);

  static const Map<String, Color> periodColors = {
    'fajr': Color(0xFF4A3426),
    'shorouq': Color(0xFFC9A94E),
    'morningAzkar': Color(0xFF6D5A4A),
    'duhr': Color(0xFF5C4A3A),
    'asr': Color(0xFF8B6914),
    'maghrib': Color(0xFF8B3A3A),
    'eveningAzkar': Color(0xFF4A5B6B),
    'isha': Color(0xFF3C3489),
    'night': Color(0xFF1A1420),
    'postPrayer': Color(0xFF4A3426),
  };

  static const Map<String, Color> periodColorsDark = {
    'fajr': Color(0xFFD4B96A),
    'shorouq': Color(0xFFE8D08A),
    'morningAzkar': Color(0xFFA89888),
    'duhr': Color(0xFFC4A94E),
    'asr': Color(0xFFD4A03A),
    'maghrib': Color(0xFFF87171),
    'eveningAzkar': Color(0xFF93B5D4),
    'isha': Color(0xFFA78BFA),
    'night': Color(0xFF8B7FD4),
    'postPrayer': Color(0xFF8C6E4A),
  };

  static Map<String, Color> getPeriodColors(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? periodColorsDark : periodColors;
  }

  // =========================
  // Font Scaling Helper
  // =========================
  /// Harmonious type scale — every size snaps to one of these steps so the
  /// whole app feels proportional (nothing absurdly large, nothing tiny).
  ///
  /// The small steps 8/9/10 were added so the scale is COMPLETE at the bottom:
  /// with a floor of 11 the snapper silently rounded every deliberate 8–10 up
  /// to 11 (129 call sites had asked for 8/9/9.5/10/10.5 and none of them ever
  /// got it), while dozens of hardcoded micro-labels (chart axes, PDF reports,
  /// badges) sat below the scale entirely. Now the sub-11 range is a real part
  /// of the scale, so both populations land on the same token.
  static const List<double> _typeScale = [
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    19,
    21,
    23,
    26,
    30,
    34,
    40,
    48,
    56,
  ];

  /// The shared typographic steps, exposed so [scaledFontSize]'s contract is
  /// inspectable (and enforced by `type_scale_guard_test.dart`).
  static const List<double> typeScale = _typeScale;

  /// Scales a base font size by the user's font-scale setting and snaps it
  /// to the nearest harmonious step. Usage: `fontSize: AppTheme.scaledFontSize(context, 14)`
  static double scaledFontSize(BuildContext context, double baseSize) {
    final themeBodyMedium =
        Theme.of(context).textTheme.bodyMedium?.fontSize ?? 15.0;
    final scale = themeBodyMedium / 15.0;
    final raw = baseSize * scale;
    double best = _typeScale.first;
    double bestDiff = (raw - best).abs();
    for (final s in _typeScale) {
      final d = (raw - s).abs();
      if (d < bestDiff) {
        bestDiff = d;
        best = s;
      }
    }
    return best;
  }

  // ═══════════════════════════════════════════════════════════
  // COHERENT TYPE SCALE
  // All text should derive from these steps so the app feels
  // proportional: nothing absurdly large, nothing unreadably small.
  // bodyMedium (15) is the 1.0 reference.
  // ═══════════════════════════════════════════════════════════
  static const double fsCaption = 11; // hints, meta, counters
  static const double fsLabel = 12; // small secondary text
  static const double fsBodySm = 13; // secondary body
  static const double fsBody = 14; // default body
  static const double fsBodyLg = 15; // reference body
  static const double fsTitleSm = 16; // emphasized body
  static const double fsTitle = 17; // card / dialog titles
  static const double fsHeadline = 19; // section headings
  static const double fsDisplay = 21; // screen headings
  static const double fsHero = 23; // large hero numbers/labels

  /// Context-aware accessor that respects the user's font-scale setting.
  static double scaleStep(BuildContext context, double step) =>
      scaledFontSize(context, step);

  // =========================
  // Theme Getters
  // =========================
  static ThemeData get light => _buildLightTheme();
  static ThemeData get dark => _buildDarkTheme();

  static ThemeData lightTheme({String? fontFamily, double fontScale = 1.0}) =>
      _buildLightTheme(
          fontFamily: fontFamily ?? AppTheme.fontFamily, fontScale: fontScale);
  static ThemeData darkTheme({String? fontFamily, double fontScale = 1.0}) =>
      _buildDarkTheme(
          fontFamily: fontFamily ?? AppTheme.fontFamily, fontScale: fontScale);

  static ThemeData _buildLightTheme(
      {String fontFamily = AppTheme.defaultFontFamily,
      double fontScale = 1.0}) {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: lightPrimary,
      onPrimary: Colors.white,
      primaryContainer: lightPrimarySoft,
      onPrimaryContainer: lightPrimaryStrong,
      secondary: lightSecondary,
      onSecondary: Colors.white,
      secondaryContainer: lightSecondarySoft,
      onSecondaryContainer: lightTextPrimary,
      tertiary: lightTertiary,
      onTertiary: Colors.white,
      tertiaryContainer: lightTertiarySoft,
      onTertiaryContainer: lightTextPrimary,
      error: lightError,
      onError: Colors.white,
      errorContainer: const Color(0xFFF9EAEA),
      onErrorContainer: lightError,
      surface: lightSurfaceTint,
      onSurface: lightTextPrimary,
      surfaceDim: lightSurfaceMutedTint,
      surfaceBright: lightSurfaceTint,
      surfaceContainerLowest: lightScaffoldTint,
      surfaceContainerLow: lightSurfaceAltTint,
      surfaceContainer: lightSurfaceMutedTint,
      surfaceContainerHigh: lightCardTint,
      surfaceContainerHighest: lightSurfaceMutedTint,
      onSurfaceVariant: lightTextSecondary,
      outline: lightOutline,
      outlineVariant: lightDivider,
      shadow: const Color(0x1A000000),
      scrim: const Color(0x66000000),
      inverseSurface: const Color(0xFF2D241E),
      onInverseSurface: Colors.white,
      inversePrimary: darkPrimary,
    );

    final textTheme =
        _lightTextTheme(fontFamily: fontFamily, fontScale: fontScale);

    return ThemeData(
      useMaterial3: true,
      extensions: <ThemeExtension<dynamic>>[
        TimeThemeKit(activeLightPalette),
      ],
      brightness: Brightness.light,
      fontFamily: fontFamily,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: lightScaffoldTint,
      canvasColor: lightScaffoldTint,
      splashFactory: InkRipple.splashFactory,
      // Unified RTL push/pop transitions for every route (see
      // rtl_transitions.dart) — no per-route pageBuilder needed.
      pageTransitionsTheme: appPageTransitions,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: lightScaffoldTint,
        foregroundColor: lightTextPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: lightTextPrimary,
        ),
        iconTheme: IconThemeData(
          color: lightTextPrimary,
          size: 22,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightCardTint,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: lightOutline, width: 0.5),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: lightDivider,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurfaceAltTint,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: lightTextMuted,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: lightOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: lightOutline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: lightTertiary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: lightError, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: lightError, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shadowColor: Colors.transparent,
          backgroundColor: lightPrimary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: lightSurfaceMutedTint,
          disabledForegroundColor: lightTextMuted,
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightPrimary,
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          side: BorderSide(color: lightOutline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: lightPrimary,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(lightTextPrimary),
          iconSize: WidgetStateProperty.all(22),
          padding: WidgetStateProperty.all(const EdgeInsets.all(10)),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: lightSurfaceAltTint,
        selectedColor: lightTertiarySoft,
        disabledColor: lightSurfaceMutedTint,
        secondarySelectedColor: lightTertiarySoft,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        labelStyle: textTheme.bodySmall!.copyWith(
          color: lightTextPrimary,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: textTheme.bodySmall!.copyWith(
          color: lightPrimary,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Colors.transparent),
        ),
        side: const BorderSide(color: Colors.transparent),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return lightTertiary;
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return lightTertiary.withValues(alpha: 0.5);
          }
          return lightSurfaceMutedTint;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return lightTertiary;
          return lightOutline;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return lightTertiary;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(lightPrimaryStrong),
        side: BorderSide(color: lightOutline, width: 1.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return lightTertiary;
          return lightTextMuted;
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: lightSurfaceTint,
        selectedItemColor: lightTertiary,
        unselectedItemColor: lightTextSecondary,
        selectedIconTheme: const IconThemeData(size: 24),
        unselectedIconTheme: const IconThemeData(size: 22),
        selectedLabelStyle: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: lightTertiary,
        ),
        unselectedLabelStyle: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w500,
          color: lightTextSecondary,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showUnselectedLabels: true,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: lightSurfaceTint,
        height: 76,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        indicatorColor: lightTertiarySoft,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelSmall?.copyWith(
              color: lightTertiary,
              fontWeight: FontWeight.w700,
            );
          }
          return textTheme.labelSmall?.copyWith(
            color: lightTextSecondary,
            fontWeight: FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: lightTertiary, size: 24);
          }
          return IconThemeData(color: lightTextSecondary, size: 22);
        }),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      // ONE sheet radius for the whole app. A call site must not pass its own
      // `shape:`; the few that still do are legacy copies at 18/22/24 and are
      // being folded back to this value (the mushaf reader's paper sheets keep
      // their own 30/22 on purpose — that surface is not the app's chrome).
      // 20 sits just under the 22dp card and the 24dp dialog, so the larger
      // surface still reads as the softest corner in the scale.
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: lightSurfaceTint,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lightSurfaceTint,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titleTextStyle: textTheme.titleMedium?.copyWith(
          color: lightTextPrimary,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: lightTextSecondary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF2D241E),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: lightTextSecondary,
        textColor: lightTextPrimary,
        titleTextStyle: textTheme.bodyLarge?.copyWith(
          color: lightTextPrimary,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: textTheme.bodySmall?.copyWith(
          color: lightTextSecondary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }

  static ThemeData _buildDarkTheme(
      {String fontFamily = AppTheme.defaultFontFamily,
      double fontScale = 1.0}) {
    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: darkPrimary,
      onPrimary: const Color(0xFF1A1410),
      primaryContainer: darkPrimarySoft,
      onPrimaryContainer: darkPrimaryStrong,
      secondary: darkSecondary,
      onSecondary: darkBackground,
      secondaryContainer: darkSecondarySoft,
      onSecondaryContainer: darkTextPrimary,
      tertiary: darkTertiary,
      onTertiary: darkBackground,
      tertiaryContainer: darkTertiarySoft,
      onTertiaryContainer: darkTertiary,
      error: darkError,
      onError: darkBackground,
      errorContainer: const Color(0xFF3A2222),
      onErrorContainer: darkError,
      surface: darkSurfaceTint,
      onSurface: darkTextPrimary,
      surfaceDim: darkScaffoldTint,
      surfaceBright: darkSurfaceTint,
      surfaceContainerLowest: darkScaffoldTint,
      surfaceContainerLow: darkSurfaceAltTint,
      surfaceContainer: darkCardTint,
      surfaceContainerHigh: darkCardTint,
      surfaceContainerHighest: darkSurfaceMutedTint,
      onSurfaceVariant: darkTextSecondary,
      outline: darkOutline,
      outlineVariant: darkDivider,
      shadow: const Color(0x00000000),
      scrim: const Color(0x99000000),
      inverseSurface: const Color(0xFFF0EBE3),
      onInverseSurface: const Color(0xFF1A1410),
      inversePrimary: lightPrimary,
    );

    final textTheme =
        _darkTextTheme(fontFamily: fontFamily, fontScale: fontScale);

    return ThemeData(
      useMaterial3: true,
      extensions: <ThemeExtension<dynamic>>[
        TimeThemeKit(activeDarkPalette),
      ],
      brightness: Brightness.dark,
      fontFamily: fontFamily,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: darkScaffoldTint,
      canvasColor: darkScaffoldTint,
      splashFactory: InkRipple.splashFactory,
      // Same unified RTL transitions as the light theme.
      pageTransitionsTheme: appPageTransitions,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: darkScaffoldTint,
        foregroundColor: darkTextPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: darkTextPrimary,
        ),
        iconTheme: IconThemeData(color: darkTextSecondary, size: 22),
      ),
      cardTheme: CardThemeData(
        color: darkCardTint,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side:
              BorderSide(color: darkOutline.withValues(alpha: 0.6), width: 0.5),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: darkDivider,
        thickness: 0.5,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceAltTint,
        hintStyle: textTheme.bodyMedium?.copyWith(color: darkTextMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: darkOutline.withValues(alpha: 0.6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: darkOutline.withValues(alpha: 0.6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: darkPrimary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: darkError, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: darkError, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shadowColor: Colors.transparent,
          backgroundColor: darkPrimary,
          foregroundColor: const Color(0xFF1A1410),
          disabledBackgroundColor: darkSurfaceMutedTint,
          disabledForegroundColor: darkTextMuted,
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkPrimary,
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          side: BorderSide(color: darkPrimary.withValues(alpha: 0.5)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: darkPrimary,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(darkTextSecondary),
          iconSize: WidgetStateProperty.all(22),
          padding: WidgetStateProperty.all(const EdgeInsets.all(10)),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkSurfaceAltTint,
        selectedColor: darkPrimarySoft,
        disabledColor: darkSurfaceMutedTint,
        secondarySelectedColor: darkPrimarySoft,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        labelStyle: textTheme.bodySmall!.copyWith(
          color: darkTextPrimary,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: textTheme.bodySmall!.copyWith(
          color: darkPrimaryStrong,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: darkOutline.withValues(alpha: 0.4)),
        ),
        side: BorderSide(color: darkOutline.withValues(alpha: 0.4)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return darkPrimary;
          return darkTextMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return darkPrimary.withValues(alpha: 0.35);
          }
          return darkSurfaceMutedTint;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return darkPrimary;
          return darkOutline;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return darkPrimary;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(const Color(0xFF1A1410)),
        side: BorderSide(color: darkOutline.withValues(alpha: 0.7), width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return darkPrimary;
          return darkTextMuted;
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: darkSurfaceTint,
        selectedItemColor: darkPrimary,
        unselectedItemColor: darkTextMuted,
        selectedIconTheme: const IconThemeData(size: 24),
        unselectedIconTheme: const IconThemeData(size: 22),
        selectedLabelStyle: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: darkPrimary,
        ),
        unselectedLabelStyle: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w500,
          color: darkTextMuted,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showUnselectedLabels: true,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurfaceTint,
        height: 76,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        indicatorColor: darkPrimarySoft,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelSmall?.copyWith(
              color: darkPrimary,
              fontWeight: FontWeight.w700,
            );
          }
          return textTheme.labelSmall?.copyWith(
            color: darkTextMuted,
            fontWeight: FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: darkPrimary, size: 24);
          }
          return IconThemeData(color: darkTextMuted, size: 22);
        }),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: darkElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titleTextStyle: textTheme.titleMedium?.copyWith(
          color: darkTextPrimary,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: darkTextSecondary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkElevated,
        contentTextStyle:
            textTheme.bodyMedium?.copyWith(color: darkTextPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: darkTextSecondary,
        textColor: darkTextPrimary,
        titleTextStyle: textTheme.bodyLarge?.copyWith(
          color: darkTextPrimary,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: textTheme.bodySmall?.copyWith(
          color: darkTextSecondary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  // =========================
  // Text Themes
  // =========================
  static TextTheme _lightTextTheme(
      {String fontFamily = AppTheme.defaultFontFamily,
      double fontScale = 1.0}) {
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 32 * fontScale,
        height: 1.20,
        fontWeight: FontWeight.w700,
        color: lightTextPrimary,
      ),
      displayMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 28 * fontScale,
        height: 1.20,
        fontWeight: FontWeight.w700,
        color: lightTextPrimary,
      ),
      titleLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 24 * fontScale,
        height: 1.25,
        fontWeight: FontWeight.w700,
        color: lightTextPrimary,
      ),
      titleMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 20 * fontScale,
        height: 1.30,
        fontWeight: FontWeight.w700,
        color: lightTextPrimary,
      ),
      titleSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 18 * fontScale,
        height: 1.30,
        fontWeight: FontWeight.w700,
        color: lightTextPrimary,
      ),
      bodyLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 16 * fontScale,
        height: 1.45,
        fontWeight: FontWeight.w500,
        color: lightTextPrimary,
      ),
      bodyMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 15 * fontScale,
        height: 1.50,
        fontWeight: FontWeight.w500,
        color: lightTextPrimary,
      ),
      bodySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 14 * fontScale,
        height: 1.55,
        fontWeight: FontWeight.w500,
        color: lightTextSecondary,
      ),
      labelLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 15 * fontScale,
        height: 1.30,
        fontWeight: FontWeight.w700,
        color: lightTextPrimary,
      ),
      labelMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 13 * fontScale,
        height: 1.30,
        fontWeight: FontWeight.w600,
        color: lightTextSecondary,
      ),
      labelSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 12 * fontScale,
        height: 1.20,
        fontWeight: FontWeight.w600,
        color: lightTextSecondary,
      ),
    );
  }

  static TextTheme _darkTextTheme(
      {String fontFamily = AppTheme.defaultFontFamily,
      double fontScale = 1.0}) {
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 32 * fontScale,
        height: 1.20,
        fontWeight: FontWeight.w700,
        color: darkTextPrimary,
      ),
      displayMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 28 * fontScale,
        height: 1.20,
        fontWeight: FontWeight.w700,
        color: darkTextPrimary,
      ),
      titleLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 24 * fontScale,
        height: 1.25,
        fontWeight: FontWeight.w700,
        color: darkTextPrimary,
      ),
      titleMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 20 * fontScale,
        height: 1.30,
        fontWeight: FontWeight.w700,
        color: darkTextPrimary,
      ),
      titleSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 18 * fontScale,
        height: 1.30,
        fontWeight: FontWeight.w700,
        color: darkTextPrimary,
      ),
      bodyLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 16 * fontScale,
        height: 1.45,
        fontWeight: FontWeight.w500,
        color: darkTextPrimary,
      ),
      bodyMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 15 * fontScale,
        height: 1.50,
        fontWeight: FontWeight.w500,
        color: darkTextPrimary,
      ),
      bodySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 14 * fontScale,
        height: 1.55,
        fontWeight: FontWeight.w500,
        color: darkTextSecondary,
      ),
      labelLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 15 * fontScale,
        height: 1.30,
        fontWeight: FontWeight.w700,
        color: darkTextPrimary,
      ),
      labelMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 13 * fontScale,
        height: 1.30,
        fontWeight: FontWeight.w600,
        color: darkTextSecondary,
      ),
      labelSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 12 * fontScale,
        height: 1.20,
        fontWeight: FontWeight.w600,
        color: darkTextSecondary,
      ),
    );
  }

  // =========================
  // Custom Text Styles
  // =========================
  // Getters (not const/final): they re-read the active fontFamily so a
  // mid-session font change applies to them too.
  static TextStyle get timeHeroLight => TextStyle(
        fontFamily: fontFamily,
        fontSize: 40,
        height: 1.1,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      );

  static TextStyle get timeHeroDark => TextStyle(
        fontFamily: fontFamily,
        fontSize: 40,
        height: 1.1,
        fontWeight: FontWeight.w700,
        color: darkTextPrimary,
      );

  static TextStyle get timeCardLight => TextStyle(
        fontFamily: fontFamily,
        fontSize: 26,
        height: 1.15,
        fontWeight: FontWeight.w700,
        color: lightTextPrimary,
      );

  static TextStyle get timeCardDark => TextStyle(
        fontFamily: fontFamily,
        fontSize: 26,
        height: 1.15,
        fontWeight: FontWeight.w700,
        color: darkTextPrimary,
      );

  static TextStyle get countdownLight => TextStyle(
        fontFamily: fontFamily,
        fontSize: 32,
        height: 1.1,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      );

  static TextStyle get countdownDark => TextStyle(
        fontFamily: fontFamily,
        fontSize: 32,
        height: 1.1,
        fontWeight: FontWeight.w700,
        color: darkTextPrimary,
      );

  static TextStyle tasbihNumberLight = TextStyle(
    fontFamily: fontFamily,
    fontSize: 56,
    height: 1.0,
    fontWeight: FontWeight.w700,
    color: lightTertiary,
  );

  static TextStyle tasbihNumberDark = TextStyle(
    fontFamily: fontFamily,
    fontSize: 56,
    height: 1.0,
    fontWeight: FontWeight.w700,
    color: darkPrimary,
  );

  static const TextStyle arabicLarge = TextStyle(
    fontFamily: 'Amiri',
    fontSize: 28,
    height: 1.8,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle arabicMedium = TextStyle(
    fontFamily: 'Amiri',
    fontSize: 22,
    height: 1.8,
    fontWeight: FontWeight.w700,
  );

  // =========================
  // Decorations / Helpers
  // =========================
  static List<BoxShadow> get lightCardShadow => const [
        BoxShadow(
          color: Color.fromRGBO(74, 52, 38, 0.06),
          blurRadius: 14,
          offset: Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get lightElevatedShadow => const [
        BoxShadow(
          color: Color.fromRGBO(74, 52, 38, 0.10),
          blurRadius: 24,
          offset: Offset(0, 8),
        ),
      ];

  static BoxDecoration lightCardDecoration({double radius = 22}) {
    return BoxDecoration(
      color: lightCardTint,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: lightCardShadow,
    );
  }

  static BoxDecoration darkCardDecoration({double radius = 22}) {
    return BoxDecoration(
      color: darkCardTint,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: darkOutline.withValues(alpha: 0.6), width: 0.5),
    );
  }

  static BoxDecoration heroLightDecoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: heroGradientLight,
      boxShadow: lightElevatedShadow,
    );
  }

  static BoxDecoration heroDarkDecoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: heroGradientDark,
    );
  }
}

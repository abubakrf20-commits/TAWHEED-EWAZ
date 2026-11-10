import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/app_colors.dart';
import 'package:tawheeed/core/design_system/islamic_pattern.dart';

/// ═══════════════════════════════════════════════════════════════
/// COMPLETE VISUAL REDESIGN: Card & Surface Design System
/// ═══════════════════════════════════════════════════════════════
///
/// This replaces the flat brown box pattern with a layered,
/// premium surface language. Every card in the app should
/// derive from these tokens.
class CardDesignSystem {
  CardDesignSystem._();

  // ═══════════════════════════════════════════════════════════
  // COLOR TOKENS — Premium Brown + Restrained Gold
  // ═══════════════════════════════════════════════════════════

  // ─── Structural Browns ────────────────────────────────────
  static const Color parchment = AppTheme.parchment;
  static const Color linen = AppTheme.linen;
  static const Color shell = AppTheme.shell;

  static const Color deepNight = AppTheme.deepNight;
  static const Color darkWalnut = AppTheme.darkWalnut;
  static const Color darkMocha = AppTheme.darkMocha;
  static const Color darkCocoa = AppTheme.darkCocoa;

  static const Color goldRich = AppTheme.goldRich;
  static const Color goldMuted = AppTheme.goldMuted;
  static const Color goldSoft = AppTheme.goldSoft;

  static const Color greenRich = AppTheme.greenRich;
  static const Color greenMuted = AppTheme.greenMuted;
  static const Color greenSoft = AppTheme.greenSoft;

  static const Color textOnDark = AppTheme.textOnDark;
  static const Color textOnDarkMuted = AppTheme.textOnDarkMuted;
  static const Color textOnDarkGhost = AppTheme.textOnDarkGhost;
  static const Color textOnLight = AppTheme.textOnLight;
  static const Color textOnLightSecondary = AppTheme.textOnLightSecondary;
  static const Color textOnLightMuted = AppTheme.textOnLightMuted;

  // ═══════════════════════════════════════════════════════════
  // TYPOGRAPHY TOKENS — Confident & Clear
  // ═══════════════════════════════════════════════════════════

  /// Section title style for cards
  static TextStyle cardSectionTitle(BuildContext ctx) => TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: AppTheme.scaledFontSize(ctx, 14),
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary(ctx),
      );

  // ═══════════════════════════════════════════════════════════
  // SPACING SCALE (delegated to AppTheme)
  // ═══════════════════════════════════════════════════════════

  static const double space2 = AppTheme.space2;
  static const double space4 = AppTheme.space4;
  static const double space6 = AppTheme.space6;
  static const double space8 = AppTheme.space8;
  static const double space10 = AppTheme.space10;
  static const double space12 = AppTheme.space12;
  static const double space16 = AppTheme.space16;
  static const double space20 = AppTheme.space20;
  static const double space24 = AppTheme.space24;
  static const double space32 = AppTheme.space32;

  // ═══════════════════════════════════════════════════════════
  // RADIUS SCALE (delegated to AppTheme)
  // ═══════════════════════════════════════════════════════════

  static const double radiusNone = AppTheme.radiusNone;
  static const double radiusXS = AppTheme.radiusSmall;
  static const double radiusSM = AppTheme.radiusMedium;
  static const double radiusMD = AppTheme.radiusLarge;
  static const double radiusLG = AppTheme.radiusXLarge;
  static const double radiusXL = AppTheme.radiusXxxLarge;

  // ═══════════════════════════════════════════════════════════
  // SHADOW / DEPTH TOKENS
  // ═══════════════════════════════════════════════════════════

  /// Subtle lift for standard cards
  static List<BoxShadow> get shadowSubtle => [
        const BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 14,
          offset: Offset(0, 6),
        ),
      ];

  /// Medium elevation for feature cards
  static List<BoxShadow> get shadowMedium => [
        const BoxShadow(
          color: Color(0x12000000),
          blurRadius: 22,
          offset: Offset(0, 10),
        ),
        const BoxShadow(
          color: Color(0x06000000),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ];

  /// Hero card shadow — warm-tinted
  static List<BoxShadow> heroShadow(bool isDark) => [
        BoxShadow(
          color: (isDark ? const Color(0x33555555) : const Color(0x204A3228)),
          blurRadius: 30,
          offset: const Offset(0, 14),
          spreadRadius: -4,
        ),
      ];

  // ═══════════════════════════════════════════════════════════
  // SURFACE COMPOSITION HELPERS
  // ═══════════════════════════════════════════════════════════

  /// Standard card surface — palette-driven (2026 theme core).
  static BoxDecoration surfaceCard(BuildContext ctx) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark
          ? AppTheme.activeDarkPalette.card
          : AppTheme.activeLightPalette.card,
      borderRadius: BorderRadius.circular(radiusMD),
      boxShadow: isDark ? [] : shadowSubtle,
    );
  }

  /// Inner panel (recessed area inside a card)
  static BoxDecoration innerPanel(BuildContext ctx) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? const Color(0x1AFFFFFF) : const Color(0x1A000000),
      borderRadius: BorderRadius.circular(radiusSM),
    );
  }

  /// Gold accent line (thin decorative rule)
  static BoxDecoration get goldAccentLine => const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0x00C9A94E), Color(0x60C9A94E), Color(0x00C9A94E)],
        ),
      );

  /// Divider between sections
  static Widget sectionDivider(BuildContext ctx) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: space16),
      color: isDark ? const Color(0x1FFFFFFF) : const Color(0x1F000000),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SURFACE TINT / ELEVATION TOKENS
  // ═══════════════════════════════════════════════════════════

  /// Unified surface tint — a single warm wash applied to lifted cards so
  /// elevation reads consistently across the app.
  static Color surfaceTint(bool isDark) =>
      isDark ? const Color(0x14C9A94E) : const Color(0x0AC9A94E);

  /// Elevation level 0 — flat surface (no lift).
  static List<BoxShadow> elevation0(bool isDark) => [];

  /// Elevation level 1 — subtle lift for inline panels.
  static List<BoxShadow> elevation1(bool isDark) => [
        BoxShadow(
          color: isDark ? const Color(0x30000000) : const Color(0x0D000000),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ];

  /// Elevation level 2 — feature card lift.
  static List<BoxShadow> elevation2(bool isDark) => [
        BoxShadow(
          color: isDark ? const Color(0x35000000) : const Color(0x15000000),
          blurRadius: 18,
          offset: const Offset(0, 7),
        ),
      ];

  // ═══════════════════════════════════════════════════════════
  // GOLD FRAME COMPOSITION
  // ═══════════════════════════════════════════════════════════

  /// Gold gradient used for the outer frame of premium cards.
  static const LinearGradient goldFrameGradient = LinearGradient(
    colors: [goldSoft, goldRich, goldMuted],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Inner chocolate-brown gradient surface (the "card" inside the gold frame).
  static LinearGradient chocolateSurface(bool isDark) => LinearGradient(
        colors: isDark
            ? [AppTheme.espresso, AppTheme.darkWalnut, AppTheme.darkMocha]
            : [AppTheme.walnut, AppTheme.mocha, AppTheme.cocoa],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
}

/// ═══════════════════════════════════════════════════════════════
/// REUSABLE GOLD-FRAMED CARD
/// Wraps any child in a chocolate-brown surface encased by a thin
/// gold-gradient frame, with the optional subtle Islamic pattern overlay.
/// Use this to give the whole home tab a unified "premium" surface.
/// ═══════════════════════════════════════════════════════════════
class GoldFramedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double frameThickness;
  final bool showPattern;
  final double radius;
  final bool useChocolate;

  const GoldFramedCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.frameThickness = 2.5,
    this.showPattern = false,
    this.radius = CardDesignSystem.radiusXL,
    this.useChocolate = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inner = Container(
      decoration: BoxDecoration(
        color: useChocolate
            ? null
            : (isDark
                ? AppTheme.activeDarkPalette.card
                : AppTheme.activeLightPalette.card),
        gradient:
            useChocolate ? CardDesignSystem.chocolateSurface(isDark) : null,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Stack(
        children: [
          if (showPattern)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                // Cached layer — the pattern painter must not repaint every
                // scroll frame on weak devices.
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: IslamicPatternPainter(
                      color: CardDesignSystem.goldRich,
                      opacity: isDark ? 0.05 : 0.07,
                    ),
                  ),
                ),
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        gradient: CardDesignSystem.goldFrameGradient,
        borderRadius: BorderRadius.circular(radius + 3),
        boxShadow: CardDesignSystem.elevation2(isDark),
      ),
      padding: EdgeInsets.all(frameThickness),
      child: inner,
    );
  }
}

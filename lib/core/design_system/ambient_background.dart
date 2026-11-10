import 'package:flutter/material.dart';

import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

/// ═══════════════════════════════════════════════════════════════
/// AmbientBackground — soft, low-opacity "glow" blobs over a base
/// gradient derived from the ACTIVE palette (the 2026 theme core).
///
/// The base is a subtle shade inside the palette's page background, so
/// the whole app follows the selected theme — gold, a pinned phase, or
/// the live time-of-day phase. A per-module [accent] still overrides
/// the glow hues so each screen can keep its own identity color.
///
/// When [accent] is set, the surface also takes a whisper of that hue
/// (4 % light / 5 % dark): that is the shell's "each section has its own
/// light" signature — خانه reads navy, قرآن emerald, تسبیح gold, تقویم
/// violet, ارزیابی rust, بیشتر orange.
///
/// **Deliberately not animated.** The shell swaps tabs with an
/// [IndexedStack], so the content changes on one frame; fading the field
/// for 300–400 ms would add ~20 full-page gradient repaints on the phones
/// this app targets, for a difference nobody sees under the new content.
/// The colour is applied on the same frame as the tab change — zero extra
/// frames, zero extra layers.
/// ═══════════════════════════════════════════════════════════════
class AmbientBackground extends StatelessWidget {
  final Widget child;
  final bool includeGlow;

  /// Optional per-module accent. When provided, the glow blobs use this
  /// identity color instead of the palette hues (performance-cheap static
  /// gradients).
  final Color? accent;

  const AmbientBackground({
    super.key,
    required this.child,
    this.includeGlow = true,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // The active palette is the single source of the background; the statics
    // mirror exactly what MaterialApp's ThemeData carries for this moment.
    final palette =
        isDark ? AppTheme.activeDarkPalette : AppTheme.activeLightPalette;
    final base =
        Color.lerp(palette.pageBg, palette.surface, 0.55) ?? palette.pageBg;

    final a = accent;
    // A 4–5 % wash is enough to read as "the same room, different light"
    // without touching text contrast (textPrimary sits far above 4.5:1 on
    // every palette, and the wash moves the surface by a few units).
    final tintedBase =
        a == null ? base : (Color.lerp(base, a, isDark ? 0.05 : 0.04) ?? base);
    final glowColors = a != null
        ? (a, a.withValues(alpha: 0.7), palette.heroMid)
        : (palette.heroTop, palette.tertiary, palette.heroMid);

    // MediaQuery.sizeOf, not MediaQuery.of: the blobs only depend on the
    // height, and `.of` would rebuild this field on every keyboard frame.
    final height = MediaQuery.sizeOf(context).height;

    return Stack(
      children: [
        // Base gradient — inside the active palette (plus the accent wash).
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [palette.pageBg, tintedBase],
            ),
          ),
        ),
        // Ambient glow blobs
        if (includeGlow) ...[
          // Top-right glow — palette hero hue (or module accent)
          Positioned(
            top: -120,
            right: -80,
            child: _glow(280, glowColors.$1, isDark ? 0.10 : 0.13),
          ),
          // Bottom-left glow — brand gold, shared by every palette
          Positioned(
            bottom: -110,
            left: -90,
            child: _glow(300, AppPalette.heroGoldDeep, isDark ? 0.05 : 0.08),
          ),
          // Center-left glow — palette tertiary (or module accent)
          Positioned(
            top: height * 0.34,
            left: -70,
            child: _glow(240, glowColors.$2, isDark ? 0.09 : 0.08),
          ),
          // Subtle extra glow in dark mode
          if (isDark)
            Positioned(
              top: height * 0.15,
              right: -60,
              child: _glow(200, glowColors.$3, 0.06),
            ),
        ],
        child,
      ],
    );
  }

  Widget _glow(double size, Color color, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0)
          ],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }
}

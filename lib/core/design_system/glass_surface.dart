import 'package:flutter/material.dart';
import 'package:tawheeed/core/design_system/card_design_system.dart';
import 'package:tawheeed/core/theme/theme.dart';

/// ═══════════════════════════════════════════════════════════════
/// GlassSurface — the app's card surface, painted from the ACTIVE
/// palette (2026 theme core).
///
/// The base tint and the hairline border follow the selected theme —
/// gold, a pinned phase, or the live time-of-day phase — so cards read
/// as part of the page instead of a fixed warm layer over it. An
/// explicit [tint]/[borderColor] still wins for callers that need a
/// special surface. Blur is intentionally NOT used (BackdropFilter) for
/// performance. An optional `accent` adds a cheap, subtle diagonal
/// gradient giving each module a unique identity without hurting weak
/// devices.
/// ═══════════════════════════════════════════════════════════════
class GlassSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final bool borderGold;
  final Color? tint;
  final Color? borderColor;
  final List<BoxShadow>? boxShadow;

  /// Per-module identity accent — fades softly into the base tint.
  final Color? accent;

  /// Opacity of the accent wash (kept low so text stays readable).
  final double accentOpacity;

  const GlassSurface({
    super.key,
    required this.child,
    this.padding,
    this.radius = 22,
    this.borderGold = true,
    this.tint,
    this.borderColor,
    this.boxShadow,
    this.accent,
    this.accentOpacity = 0.05,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette =
        isDark ? AppTheme.activeDarkPalette : AppTheme.activeLightPalette;
    final base = tint ?? palette.card;
    final alpha = isDark ? 0.92 : 0.96;
    final resolvedBorder = borderColor ??
        (borderGold
            ? palette.tertiary.withValues(alpha: isDark ? 0.30 : 0.28)
            : palette.outline.withValues(alpha: isDark ? 0.55 : 0.80));

    final Decoration decoration;
    if (accent != null) {
      decoration = BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            base.withValues(alpha: alpha),
            (Color.lerp(base, accent, accentOpacity) ?? base)
                .withValues(alpha: alpha),
          ],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: resolvedBorder),
        boxShadow: boxShadow ?? CardDesignSystem.elevation1(isDark),
      );
    } else {
      decoration = BoxDecoration(
        color: base.withValues(alpha: alpha),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: resolvedBorder),
        boxShadow: boxShadow ?? CardDesignSystem.elevation1(isDark),
      );
    }

    return Container(
      padding: padding,
      decoration: decoration,
      child: child,
    );
  }
}

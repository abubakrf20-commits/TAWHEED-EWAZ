import 'package:flutter/material.dart';

import 'package:tawheeed/core/design_system/components/tokens.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

/// The shared duotone icon tile (Style 2): every accent tile on settings
/// pages draws the SAME shape so the redesign reads as one system.
///
/// Geometry: a squircle S×S with radius 0.32·S, fill accent @14% and a 1dp
/// border accent @18%; the glyph at 0.54·S centered in [dsReadableGlyph] —
/// the accent's own ink, stepped until it clears 3:1 on the composited fill
/// (the accent HUE never changes). Flat alphas only — no gradient, no blur,
/// no Opacity layer, no decorative back circle (dropped with the «بیشتر»
/// tiles in af973c1; one shape everywhere).
///
/// Sizes: 38dp in rows, 34 in dense rows, 32 in the per-prayer card.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    required this.color,
    this.size = 38,
    this.iconSize,
    this.semanticLabel,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double? iconSize;

  /// Announce the tile when it stands alone (icon-only affordance).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final s = size;
    final radius = 0.32 * s;
    final glyphColor = dsReadableGlyph(
      color,
      isDark: Theme.of(context).brightness == Brightness.dark,
      cardSurface: TimeThemeKit.of(context).palette.card,
    );
    return Container(
      constraints: BoxConstraints.tightFor(width: s, height: s),
      decoration: BoxDecoration(
        // 0x24/255 == 14 % — the same fill dsReadableGlyph measures against,
        // so every tile recipe agrees exactly.
        color: color.withValues(alpha: 0x24 / 255),
        borderRadius: BorderRadius.circular(radius),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Center(
        child: Icon(
          icon,
          size: iconSize ?? 0.54 * s,
          color: glyphColor,
          semanticLabel: semanticLabel,
        ),
      ),
    );
  }
}

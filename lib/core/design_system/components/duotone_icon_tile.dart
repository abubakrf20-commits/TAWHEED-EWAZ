import 'package:flutter/material.dart';

import 'package:tawheeed/core/design_system/components/tokens.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

/// The shared duotone icon tile of the redesigned home — every accent tile
/// on the page (prayer rows, rawatib boxes, timeline chips, reminder rows)
/// draws the SAME shape so the page reads as one system.
///
/// Geometry (from the approved spec): a squircle S×S with radius 0.32·S,
/// fill accent @14% and a 1dp border accent @18%; the glyph at 0.54·S
/// centered in [dsReadableGlyph] — the accent's own ink, stepped until it
/// clears 3:1 on the composited fill (the accent HUE never changes). Flat
/// alphas only — no gradient, no blur, no Opacity layer, no decorative back
/// circle (dropped with the «بیشتر» tiles in af973c1; one shape everywhere).
class DuotoneIconTile extends StatelessWidget {
  const DuotoneIconTile({
    super.key,
    required this.accent,
    required this.icon,
    this.size = 28,
  });

  final Color accent;
  final IconData icon;

  /// Edge length in logical pixels: 28 on prayer rows / rawatib boxes,
  /// 24 on timeline chips, 34 on reminder rows.
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = size;
    final radius = 0.32 * s;
    final glyphColor = dsReadableGlyph(
      accent,
      isDark: Theme.of(context).brightness == Brightness.dark,
      cardSurface: TimeThemeKit.of(context).palette.card,
    );
    return Container(
      constraints: BoxConstraints.tightFor(width: s, height: s),
      decoration: BoxDecoration(
        // 0x24/255 == 14 % — the same fill dsReadableGlyph measures against
        // (MoreDuotone's _kFillAlpha), so every tile recipe agrees exactly.
        color: accent.withValues(alpha: 0x24 / 255),
        borderRadius: BorderRadius.circular(radius),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Center(child: Icon(icon, size: 0.54 * s, color: glyphColor)),
    );
  }
}

import 'package:flutter/material.dart';

import 'package:tawheeed/core/theme/time_theme.dart';

/// The grab handle every bottom sheet wears.
///
/// Before this, each sheet drew its own: width 36 / 38 / 40, radius 2 or 99,
/// and three different colour sources (`outline`, `textMuted @ 30 %`,
/// `dividerColor`). Two sheets opened back to back showed two different bars
/// for the same affordance.
///
/// One geometry, one ink: 38×4, fully rounded, the phase accent at 28 %. The
/// mushaf reader's paper sheets keep their own 40 dp handle on purpose — that
/// surface is paper, not app chrome.
class SheetHandle extends StatelessWidget {
  const SheetHandle({
    super.key,
    this.color,
    this.width = 38,
    this.margin,
  });

  /// Ink of the bar. Defaults to the active palette's accent at 28 %.
  final Color? color;

  /// Bar width. The kit value is 38; a sheet may pass a wider one only when
  /// its own content is wider than the app's sheets (none does today).
  final double width;

  final EdgeInsetsGeometry? margin;

  static const double height = 4;
  static const double defaultWidth = 38;

  @override
  Widget build(BuildContext context) {
    final p = TimeThemeKit.of(context).palette;
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: (color ?? p.accent).withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }
}

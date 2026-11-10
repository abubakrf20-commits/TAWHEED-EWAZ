import 'package:flutter/material.dart';

import 'package:tawheeed/core/design_system/components/tokens.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

/// The redesign's default card: the palette card surface (white on light
/// palettes), radius 22, the phase's hairline card border and NO heavy
/// shadows. Padding defaults to the spec's 10.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(DsSpacing.page),
    this.onTap,
    this.onLongPress,
    this.radius = 22,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double radius;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final decoration = BoxDecoration(
      color: color ?? t.card,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? t.outline, width: .5),
    );
    if (onTap == null && onLongPress == null) {
      // The transparent Material is not decoration: a ListTile (or
      // SwitchListTile) inside a card paints its background and ink on the
      // nearest Material ancestor, and Flutter asserts when that ancestor is
      // above a coloured box — the ripple would be hidden by the card itself.
      return Container(
        padding: padding,
        decoration: decoration,
        child: Material(type: MaterialType.transparency, child: child),
      );
    }
    return Material(
      type: MaterialType.transparency,
      child: Ink(
        decoration: decoration,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

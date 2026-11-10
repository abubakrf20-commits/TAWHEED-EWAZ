import 'package:flutter/material.dart';

import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

/// Translucent white pill for the hero gradient: gold icon, 11px white text,
/// an optional refresh hint when tappable. Promoted from the home hero.
class GlassChip extends StatelessWidget {
  const GlassChip({
    super.key,
    required this.icon,
    required this.text,
    this.onTap,
  });

  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0x24FFFFFF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppPalette.heroGold),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  color: Colors.white,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 3),
              Icon(
                Icons.refresh_rounded,
                size: 11,
                color: Colors.white.withValues(alpha: .55),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Gold hairline pill for the hero gradient — gold text on transparent fill.
class OutlineChip extends StatelessWidget {
  const OutlineChip({super.key, required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.heroGold, width: .5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: AppPalette.heroGold),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: AppTheme.scaledFontSize(context, 11),
              color: AppPalette.heroGold,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small translucent pill with a colored dot — the hero's triple-calendar
/// chips (shamsi / hijri / gregorian).
class SmallChip extends StatelessWidget {
  const SmallChip({super.key, required this.text, required this.dot});

  final String text;
  final Color dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0x1FFFFFFF),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(shape: BoxShape.circle, color: dot),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: AppTheme.scaledFontSize(context, 10.5),
              color: Colors.white,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tiny gold badge for «next/now» markers on light card surfaces (spec:
/// «بعدی» on the next-prayer row, «اکنون» on the current rawatib chip).
class BadgeChip extends StatelessWidget {
  const BadgeChip({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppPalette.heroGold.withValues(alpha: isDark ? 0.18 : 0.30),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 10),
          fontWeight: FontWeight.w700,
          color: isDark ? AppPalette.heroGold : AppPalette.goldDark,
        ),
      ),
    );
  }
}

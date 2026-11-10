import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

/// Shared hero header widget for all education tabs (نماز/وضو/حج/رمضان/زکاة).
/// Provides a consistent gradient header with icon, title and subtitle.
class EducationHeroHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;

  const EducationHeroHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = TimeThemeKit.of(context).palette;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: isDark ? 0.09 : 0.06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 26, color: accentColor),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: AppTheme.scaledFontSize(context, 18),
              fontWeight: FontWeight.w800,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppTheme.scaledFontSize(context, 13),
              color: t.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared section header for education tab content sections.
class EducationSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? accentColor;

  const EducationSectionHeader({
    super.key,
    required this.title,
    required this.icon,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final color = accentColor ?? t.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            title,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: AppTheme.scaledFontSize(context, 15),
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

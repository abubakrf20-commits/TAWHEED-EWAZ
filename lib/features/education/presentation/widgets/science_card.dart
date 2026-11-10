import 'package:flutter/material.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/education/data/sciences_content.dart';

class ScienceCategoryCard extends StatelessWidget {
  final ScienceCategory category;
  final List<ScienceData> sciences;
  final ValueChanged<ScienceData> onScienceTap;

  const ScienceCategoryCard({
    super.key,
    required this.category,
    required this.sciences,
    required this.onScienceTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final accent = SciencesContent.accentOf(category);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DuotoneIconTile(
                  accent: accent,
                  icon: SciencesContent.glyphOf(category),
                  size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.label,
                      style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 13.5),
                          fontWeight: FontWeight.w500,
                          color: dsContentColor(context, accent)),
                    ),
                    Text(
                      '${sciences.length} علم',
                      style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 11),
                          color: t.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: sciences
                .map((s) => _ScienceTile(
                      science: s,
                      accent: accent,
                      onTap: !s.isComplete ? null : () => onScienceTap(s),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ScienceTile extends StatelessWidget {
  final ScienceData science;
  final Color accent;

  /// null for a «به‌زودی» entry: a coming-soon item is NOT navigable.
  final VoidCallback? onTap;
  const _ScienceTile({required this.science, required this.accent, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use approximately half width minus spacing
        final itemWidth =
            ((constraints.maxWidth - 6) / 2).clamp(0.0, double.infinity);
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: itemWidth,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: t.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Per-item emoji replaced by the group's duotone glyph
                // (the documented icon mapping); semantically labelled for
                // TalkBack with the science title itself.
                Semantics(
                  label: science.title,
                  child: DuotoneIconTile(
                      accent: accent,
                      icon: SciencesContent.glyphOf(science.category)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        science.title,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 12),
                          fontWeight: FontWeight.w600,
                          color: t.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!science.isComplete) ...[
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'به‌زودی',
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              fontSize: AppTheme.scaledFontSize(context, 9),
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_left, size: 14, color: t.textMuted),
              ],
            ),
          ),
        );
      },
    );
  }
}

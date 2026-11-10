import 'package:flutter/material.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/tools/inheritance/data/inheritance_content.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/widgets/inheritance_section_card.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/inheritance_palette.dart';

class InheritanceBasicsTab extends StatelessWidget {
  const InheritanceBasicsTab({super.key});

  @override
  Widget build(BuildContext context) {
    if (!InheritanceContent.isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? InheritancePalette.accentDark : InheritancePalette.accent;
    final sections = InheritanceContent.basicsSections;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          DsSpacing.page, 12, DsSpacing.page, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.auto_stories, size: 20, color: accent),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'مقدمه علم فرائض',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 15),
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SelectionArea(
                child: Text(
                  InheritanceContent.introText,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    color: TimeThemeKit.of(context).palette.textSecondary,
                    height: 1.8,
                  ),
                  textAlign: TextAlign.justify,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        ...InheritanceContent.introAyat.asMap().entries.map((entry) {
          return Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: TimeThemeKit.of(context).palette.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: accent.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      '${entry.key + 1}',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 11),
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SelectionArea(
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        color: TimeThemeKit.of(context).palette.textPrimary,
                        height: 1.9,
                      ),
                      textAlign: TextAlign.justify,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 14),
        ...sections.map(
          (s) => InheritanceSectionCard(
            id: s['id'] as int,
            title: s['title'] as String,
            icon: s['icon'] as String? ?? 'article',
            subsections:
                (s['subsections'] as List).cast<Map<String, dynamic>>(),
            accent: accent,
          ),
        ),
      ],
    );
  }
}

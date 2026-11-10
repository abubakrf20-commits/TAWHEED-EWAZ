import 'package:flutter/material.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/tools/inheritance/data/inheritance_content.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/widgets/inheritance_section_card.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/inheritance_palette.dart';

class InheritanceRulesTab extends StatelessWidget {
  const InheritanceRulesTab({super.key});

  @override
  Widget build(BuildContext context) {
    if (!InheritanceContent.isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? InheritancePalette.accentDark : InheritancePalette.accent;
    final sections = InheritanceContent.rulesSections;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          DsSpacing.page, 12, DsSpacing.page, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.account_balance, size: 20, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'قواعد و مسائل',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 15),
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'مسائل خاص، مناسخات، وصیت، دیون و اختلافات مذاهب',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 11),
                        color: TimeThemeKit.of(context).palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ...sections.map((s) {
          if (s['tableHeader'] != null) {
            return _buildFiqhTable(context, accent, s);
          }
          return InheritanceSectionCard(
            id: s['id'] as int,
            title: s['title'] as String,
            icon: s['icon'] as String? ?? 'article',
            subsections:
                (s['subsections'] as List).cast<Map<String, dynamic>>(),
            accent: accent,
          );
        }),
      ],
    );
  }

  Widget _buildFiqhTable(
      BuildContext context, Color accent, Map<String, dynamic> s) {
    final header = (s['tableHeader'] as List).cast<String>();
    final body = (s['tableBody'] as List).cast<Map<String, dynamic>>();
    final subsections =
        (s['subsections'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: TimeThemeKit.of(context).palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: accent,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '${s['id']}',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  s['title'] as String,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 14),
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
                dataTextStyle: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  color: TimeThemeKit.of(context).palette.textSecondary,
                  height: 1.5,
                ),
                columnSpacing: 12,
                horizontalMargin: 8,
                columns: header
                    .map((h) => DataColumn(
                        label: Text(h,
                            style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontWeight: FontWeight.w700))))
                    .toList(),
                rows: body.map((row) {
                  final cells = (row['row'] as List).cast<String>();
                  return DataRow(
                    cells: cells
                        .asMap()
                        .entries
                        .map((e) => DataCell(Text(e.value)))
                        .toList(),
                  );
                }).toList(),
              ),
            ),
          ),
          if (subsections.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: subsections.map((sub) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accent.withValues(alpha: 0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (sub['title'] != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  sub['title'] as String,
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize:
                                        AppTheme.scaledFontSize(context, 13),
                                    fontWeight: FontWeight.w700,
                                    color: accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (sub['body'] != null)
                          SelectionArea(
                            child: Text(
                              sub['body'] as String,
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize:
                                    AppTheme.scaledFontSize(context, 12.5),
                                color: TimeThemeKit.of(context).palette.textSecondary,
                                height: 1.75,
                              ),
                              textAlign: TextAlign.justify,
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/education/data/sciences_content.dart';

class BranchList extends StatelessWidget {
  final List<String> subtopics;
  final Color accent;
  const BranchList({
    super.key,
    required this.subtopics,
    this.accent = SciencesContent.accent,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.account_tree_outlined, size: 16, color: accent),
            const SizedBox(width: 6),
            Text('شاخه‌ها و مباحث',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 14),
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              for (int i = 0; i < subtopics.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 5),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SelectableText(subtopics[i],
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                                fontSize: AppTheme.scaledFontSize(context, 13),
                                height: 1.5,
                                color: t.textPrimary)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

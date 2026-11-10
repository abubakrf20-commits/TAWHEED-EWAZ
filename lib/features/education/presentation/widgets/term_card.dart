import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/education/data/sciences_content.dart';

class TermSection extends StatelessWidget {
  final List<TermData> terms;
  final Color accent;
  const TermSection({
    super.key,
    required this.terms,
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
            Icon(Icons.menu_book_outlined, size: 16, color: accent),
            const SizedBox(width: 6),
            Text('اصطلاحات کلیدی',
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
              for (int i = 0; i < terms.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(terms[i].term.trim(),
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                              fontSize: AppTheme.scaledFontSize(context, 13),
                              fontWeight: FontWeight.w700,
                              color: accent)),
                      const SizedBox(height: 4),
                      SelectableText(terms[i].definition.trim(),
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                              fontSize: AppTheme.scaledFontSize(context, 12),
                              height: 1.5,
                              color: t.textMuted)),
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

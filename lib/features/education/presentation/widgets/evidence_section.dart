import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/education/data/sciences_content.dart';

class EvidenceSection extends StatelessWidget {
  final List<String> evidence;
  final Color accent;
  const EvidenceSection({
    super.key,
    required this.evidence,
    this.accent = SciencesContent.accent,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;

    if (evidence.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.menu_book_rounded, size: 16, color: accent),
            const SizedBox(width: 6),
            Text('ادله از کتاب و سنت',
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 14),
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              for (int i = 0; i < evidence.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: evidence[i].contains('﴿')
                              ? const Color(0xFF2E7D6B).withValues(alpha: 0.14)
                              : const Color(0xFF9A6B1E).withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          evidence[i].contains('﴿') ? 'قرآن' : 'سنت',
                          style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 10),
                            fontWeight: FontWeight.w700,
                            color: evidence[i].contains('﴿')
                                ? const Color(0xFF2E7D6B)
                                : const Color(0xFF9A6B1E),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SelectableText(
                          evidence[i],
                          style: TextStyle(
                              fontSize: AppTheme.scaledFontSize(context, 12),
                              height: 1.8,
                              color: t.textMuted),
                          textDirection: TextDirection.rtl,
                        ),
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

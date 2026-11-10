import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

class CommonMistakesSection extends StatelessWidget {
  final List<String> mistakes;
  const CommonMistakesSection({super.key, required this.mistakes});

  @override
  Widget build(BuildContext context) {
    if (mistakes.isEmpty) return const SizedBox.shrink();

    final t = TimeThemeKit.of(context).palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.warning_amber_outlined,
                size: 16, color: Color(0xFFB85C5C)),
            const SizedBox(width: 6),
            Text('اشتباهات رایج',
                textDirection: TextDirection.rtl,
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
            color: const Color(0xFFB85C5C).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: const Color(0xFFB85C5C).withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              for (int i = 0; i < mistakes.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.close,
                          size: 14, color: Color(0xFFB85C5C)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SelectableText(mistakes[i],
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                                fontSize: AppTheme.scaledFontSize(context, 12),
                                height: 1.5,
                                color: t.textMuted)),
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

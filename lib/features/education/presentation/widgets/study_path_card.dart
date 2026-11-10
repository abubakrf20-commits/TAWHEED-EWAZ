import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/education/data/sciences_content.dart';
import 'package:tawheeed/core/design_system/components/components.dart';

class StudyPathSection extends StatelessWidget {
  final String studyPath;
  const StudyPathSection({super.key, required this.studyPath});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final onPrimary = dsOnAccent(context);
    final steps =
        studyPath.split('\n').where((s) => s.trim().isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.route_outlined,
                size: 18, color: SciencesContent.accent),
            const SizedBox(width: 8),
            Text('مسیر پیشنهادی مطالعه',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 16),
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary)),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SciencesContent.accent.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: SciencesContent.accent.withValues(alpha: 0.15)),
          ),
          child: Column(
            children: List.generate(steps.length, (i) {
              final step = steps[i];
              final stepNum = i + 1;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: SciencesContent.accent,
                        shape: BoxShape.circle,
                      ),
                      child: Text('$stepNum',
                          style: TextStyle(
                              fontSize: AppTheme.scaledFontSize(context, 12),
                              fontWeight: FontWeight.w700,
                              color: onPrimary)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SelectableText(
                        step.replaceFirst(RegExp(r'^\d+[\.\-\)]\s*'), ''),
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 13),
                            height: 1.6,
                            color: t.textMuted),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

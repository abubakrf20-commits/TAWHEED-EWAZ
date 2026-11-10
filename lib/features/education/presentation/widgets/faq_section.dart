import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/education/data/sciences_content.dart';

class FaqSection extends StatefulWidget {
  final List<FaqData> faqs;
  final Color accent;
  const FaqSection({
    super.key,
    required this.faqs,
    this.accent = SciencesContent.accent,
  });

  @override
  State<FaqSection> createState() => _FaqSectionState();
}

class _FaqSectionState extends State<FaqSection> {
  int? _expandedIndex;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.help_outline, size: 16, color: widget.accent),
            const SizedBox(width: 6),
            Text('پرسش‌های متداول',
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 14),
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary)),
          ],
        ),
        const SizedBox(height: 8),
        ...widget.faqs.asMap().entries.map((entry) {
          final i = entry.key;
          final faq = entry.value;
          final isExpanded = _expandedIndex == i;
          return Container(
            margin:
                EdgeInsets.only(bottom: i < widget.faqs.length - 1 ? 10 : 0),
            decoration: BoxDecoration(
              color: t.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: t.outline, width: 0.5),
            ),
            child: Column(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () =>
                      setState(() => _expandedIndex = isExpanded ? null : i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 18,
                          color: widget.accent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(faq.question,
                              style: TextStyle(
                                  fontSize:
                                      AppTheme.scaledFontSize(context, 13),
                                  fontWeight: FontWeight.w600,
                                  color: t.textPrimary)),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: SelectableText(
                      faq.answer,
                      style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 12),
                          height: 1.6,
                          color: t.textMuted),
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                  crossFadeState: isExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 200),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

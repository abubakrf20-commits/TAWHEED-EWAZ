import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/education/data/sciences_content.dart';

class RelatedSciencesSection extends StatelessWidget {
  final List<String> relatedIds;
  final Color accent;
  final void Function(String id) onScienceTap;

  const RelatedSciencesSection({
    super.key,
    required this.relatedIds,
    required this.onScienceTap,
    this.accent = SciencesContent.accent,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;

    final sciences =
        relatedIds.map(SciencesContent.byId).whereType<ScienceData>().toList();
    if (sciences.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.link_outlined, size: 16, color: accent),
            const SizedBox(width: 6),
            Text('علوم مرتبط',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 14),
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary)),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: sciences
              .map((s) => InkWell(
                    onTap: () => onScienceTap(s.id),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: accent.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // The per-science emoji is gone: the chip carries the
                          // target's own category glyph, the chip hue stays the
                          // current science's accent.
                          Icon(SciencesContent.glyphOf(s.category),
                              size: 13, color: accent),
                          const SizedBox(width: 4),
                          Text(s.title,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                  fontSize:
                                      AppTheme.scaledFontSize(context, 11),
                                  fontWeight: FontWeight.w600,
                                  color: accent)),
                        ],
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

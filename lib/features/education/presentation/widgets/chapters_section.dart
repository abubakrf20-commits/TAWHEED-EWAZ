import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/education/data/sciences_content.dart';

class ChaptersSection extends StatelessWidget {
  final List<ChapterData> chapters;
  final Color accent;

  const ChaptersSection({
    super.key,
    required this.chapters,
    this.accent = SciencesContent.accent,
  });

  static const _palette = [
    0xFF1A7A7A,
    0xFFB87D2E,
    0xFF3D7D5A,
    0xFF8B5E7C,
    0xFF2E6FA0,
    0xFFA86B3C,
    0xFF4A7B6F,
    0xFF7D5C8C,
    0xFFC4755D,
    0xFF3D7D6B,
  ];

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            children: [
              Icon(Icons.menu_book, size: 18, color: accent),
              const SizedBox(width: 8),
              Text(
                'مباحث و تفصیل',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 15),
                  fontWeight: FontWeight.w700,
                  color: t.textPrimary,
                ),
              ),
            ],
          ),
        ),
        ...chapters.asMap().entries.map((entry) {
          final idx = entry.key;
          final chapter = entry.value;
          final c = Color(_palette[idx % _palette.length]);

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, idx, chapter, c),
                _buildBody(context, chapter, c),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildHeader(
      BuildContext context, int idx, ChapterData chapter, Color c) {
    return Container(
      decoration: BoxDecoration(
        color: c,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Center(
              child: Text(
                '${idx + 1}',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 13),
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              chapter.title,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 14.5),
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, ChapterData chapter, Color c) {
    final t = TimeThemeKit.of(context).palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (chapter.body != null && chapter.body!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SelectionArea(
                child: Text(
                  chapter.body!,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    color: t.textSecondary,
                    height: 1.85,
                  ),
                  textAlign: TextAlign.justify,
                ),
              ),
            ),
          ...chapter.subsections.map((sub) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildSubsection(context, sub, c),
              )),
        ],
      ),
    );
  }

  Widget _buildSubsection(
      BuildContext context, ChapterSubsection sub, Color c) {
    final t = TimeThemeKit.of(context).palette;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sub.title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      sub.title!,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 13.5),
                        fontWeight: FontWeight.w700,
                        color: c,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (sub.body != null && sub.body!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SelectionArea(
                child: Text(
                  sub.body!,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12.5),
                    color: t.textSecondary,
                    height: 1.8,
                  ),
                  textAlign: TextAlign.justify,
                ),
              ),
            ),
          if (sub.verses.isNotEmpty)
            ...sub.verses.map((v) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _buildVerse(context, v, c),
                )),
          if (sub.items.isNotEmpty)
            ...sub.items.map((item) => _buildItem(context, item, c)),
        ],
      ),
    );
  }

  Widget _buildVerse(BuildContext context, String verse, Color c) {
    final t = TimeThemeKit.of(context).palette;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          right: BorderSide(color: c, width: 3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.format_quote, size: 16, color: c.withValues(alpha: 0.5)),
          const SizedBox(width: 8),
          Expanded(
            child: SelectionArea(
              child: Text(
                verse,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  color: t.textPrimary,
                  height: 1.7,
                ),
                textAlign: TextAlign.justify,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, String item, Color c) {
    final t = TimeThemeKit.of(context).palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, right: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 5),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectionArea(
              child: Text(
                item,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 12.5),
                  color: t.textSecondary,
                  height: 1.65,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:tawheeed/core/design_system/components/share_card_palette.dart';
import 'package:tawheeed/core/design_system/components/share_card_shell.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/hadeeth_enc/domain/entities/hadeeth_enc_hadith.dart';
import 'package:tawheeed/features/hadeeth_enc/presentation/hadeeth_palette.dart';
import 'package:tawheeed/shared/utils/text_highlight.dart';

/// Content blocks of a hadith card.
enum HadeethShareContent {
  arabic('متن عربی', Icons.text_fields),
  translation('ترجمه', Icons.translate),
  source('منبع و صحت', Icons.verified_outlined),
  explanation('شرح', Icons.lightbulb_outline),
  tips('نکات حدیث', Icons.tips_and_updates_outlined);

  const HadeethShareContent(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// The «نکات حدیث» bullet lines: each non-empty line of the source
/// benefits field becomes one bullet point.
List<String> hadeethTipLines(String benefits) => [
      for (final line in benefits.split('\n'))
        if (line.trim().isNotEmpty) line.trim(),
    ];

/// The beautiful single-page cream card used both in the detail screen and
/// the share-image preview: Arabic text first, then ترجمه، منبع، صحت، شرح
/// and نکات حدیث — everything inside one unified box.
class HadeethShareCard extends StatelessWidget {
  final HadeethEncHadith hadith;
  final int? sequence;
  final Set<HadeethShareContent> content;
  final bool showBranding;

  /// Literal matched by a More deep-search hit; every occurrence is shaded so
  /// the reader lands on the word they searched. Empty paints nothing.
  final String highlightQuery;

  /// When set, the FIRST block [highlightQuery] occurs in is keyed with it so
  /// the detail screen can scroll straight to that block. The share image
  /// passes none: it always captures the card from the top.
  final GlobalKey? matchAnchor;

  const HadeethShareCard({
    super.key,
    required this.hadith,
    this.sequence,
    this.content = const {
      HadeethShareContent.arabic,
      HadeethShareContent.translation,
      HadeethShareContent.source,
      HadeethShareContent.explanation,
      HadeethShareContent.tips,
    },
    this.showBranding = true,
    this.highlightQuery = '',
    this.matchAnchor,
  });

  @override
  Widget build(BuildContext context) {
    const accent = TopicHues.hadeethEnc;
    final c = ShareCardColors.of(context);

    // The first block the query actually occurs in gets the anchor; later
    // matches still paint, but only one block can be scrolled to.
    final query = highlightQuery.trim();
    var anchored = false;
    Widget anchor(String text, Widget child) {
      if (anchored || matchAnchor == null || query.isEmpty) return child;
      if (TextHighlight.findMatches(text, query).isEmpty) return child;
      anchored = true;
      return KeyedSubtree(key: matchAnchor, child: child);
    }

    return ShareCardShell(
      children: [
        ShareCardHeader(
          icon: Icons.menu_book_outlined,
          title: 'حدیث شماره ${sequence ?? hadith.sequence ?? hadith.id}',
          subtitle: 'موسوعه الأحادیث النبویة',
          accent: accent,
        ),
        const SizedBox(height: 14),
        // Arabic text
        if (content.contains(HadeethShareContent.arabic) &&
            hadith.textAr.trim().isNotEmpty) ...[
          anchor(
            hadith.textAr.trim(),
            _HighlightedText(
              hadith.textAr.trim(),
              query: highlightQuery,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: 'Amiri',
                fontFamilyFallback: const ['Calibri'],
                fontSize: AppTheme.scaledFontSize(context, 18),
                height: 2.0,
                fontWeight: FontWeight.w600,
                color: c.head,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: ShareCardDivider(),
          ),
        ],
        // Persian translation
        if (content.contains(HadeethShareContent.translation) &&
            hadith.text.trim().isNotEmpty) ...[
          const ShareCardLabel(
            icon: Icons.translate,
            label: 'ترجمه',
            accent: accent,
          ),
          const SizedBox(height: 6),
          anchor(
            hadith.text.trim(),
            _HighlightedText(
              hadith.text.trim(),
              query: highlightQuery,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 14.5),
                height: 1.9,
                color: c.body,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        // Source + grade on one line
        if (content.contains(HadeethShareContent.source) &&
            (hadith.takhrij.trim().isNotEmpty ||
                hadith.grade.trim().isNotEmpty)) ...[
          Row(
            children: [
              if (hadith.takhrij.trim().isNotEmpty)
                Expanded(
                  child: _Chip(
                    icon: Icons.menu_book_outlined,
                    text: hadith.takhrij.trim(),
                    color: accent,
                  ),
                ),
              if (hadith.takhrij.trim().isNotEmpty &&
                  hadith.grade.trim().isNotEmpty)
                const SizedBox(width: 8),
              if (hadith.grade.trim().isNotEmpty)
                _Chip(
                  icon: Icons.verified_outlined,
                  text: hadith.grade.trim(),
                  color: HadeethPalette.grade(hadith.grade),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        // Explanation
        if (content.contains(HadeethShareContent.explanation) &&
            hadith.explanation.trim().isNotEmpty) ...[
          const ShareCardLabel(
            icon: Icons.lightbulb_outline,
            label: 'شرح',
            accent: accent,
          ),
          const SizedBox(height: 6),
          anchor(
            hadith.explanation.trim(),
            _HighlightedText(
              hadith.explanation.trim(),
              query: highlightQuery,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 13.5),
                height: 1.9,
                color: c.muted,
              ),
            ),
          ),
        ],
        // Tips (نکات حدیث)
        if (content.contains(HadeethShareContent.tips) &&
            hadith.benefits.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          const ShareCardLabel(
            icon: Icons.tips_and_updates_outlined,
            label: 'نکات حدیث',
            accent: accent,
          ),
          const SizedBox(height: 6),
          for (final tip in hadeethTipLines(hadith.benefits))
            anchor(
              tip,
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _HighlightedText(
                        tip,
                        query: highlightQuery,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 13.5),
                          height: 1.8,
                          color: c.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
        if (showBranding) ...[
          const SizedBox(height: 16),
          const ShareCardFooter(section: 'موسوعه الأحادیث النبویة'),
        ],
      ],
    );
  }
}

/// Plain text, or the same text with every occurrence of the deep-search
/// literal shaded. Kept out of the share image path by construction: the
/// image renders this widget with an empty query.
class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;
  final TextAlign? textAlign;
  final TextDirection? textDirection;

  const _HighlightedText(
    this.text, {
    required this.query,
    required this.style,
    this.textAlign,
    this.textDirection,
  });

  @override
  Widget build(BuildContext context) {
    final q = query.trim();
    if (q.isEmpty) {
      return Text(text,
          style: style, textAlign: textAlign, textDirection: textDirection);
    }
    return Text.rich(
      TextSpan(
        style: style,
        children: TextHighlight.spans(
          text,
          q,
          baseStyle: style,
          highlightStyle:
              TextHighlight.defaultHighlightStyle(context, base: style),
        ),
      ),
      textAlign: textAlign,
      textDirection: textDirection,
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _Chip({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.09),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 11.5),
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

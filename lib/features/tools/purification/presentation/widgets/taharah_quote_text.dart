import 'package:flutter/material.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

// ════════════════════════════════════════════════════════════════
// LOSSLESS QUOTE SPLITTER (presentation only)
//
// taharah.json bodies embed Quran (`﴿…﴾ [+ `[سوره: آیه]`]`) and hadith
// (`«…»` [+ `(منبع)`]) markers inside Persian prose. The flat design
// presents those spans as quote BLOCKS without touching a single
// character: the concatenation of the returned segments, in reading
// order, equals the input byte-for-byte (guard test:
// test/features/tools/purification/taharah_content_lossless_test.dart).
//
// Classification is marker-based ONLY: a span is a quote exactly when
// it is delimited by the paired marker glyphs that are already in the
// data. An unclosed marker (or any other text) stays plain — rendering
// it plain is lossless, so an uncertain span can never re-word or
// re-order religious text.
// ════════════════════════════════════════════════════════════════

const String _quranOpen = '﴿';
const String _quranClose = '﴾';
const String _hadithOpen = '«';
const String _hadithClose = '»';

/// One rendered span of a taharah paragraph.
class TaharahSegment {
  /// Exact substring of the source (never re-worded, never trimmed).
  final String text;

  /// True when the span is a marker-delimited Quran/hadith block.
  final bool isQuote;

  /// True for ﴿…﴾ (Quran); false for «…» (hadith). Meaningless when
  /// [isQuote] is false.
  final bool isQuran;

  const TaharahSegment({
    required this.text,
    required this.isQuote,
    this.isQuran = false,
  });
  @override
  String toString() => text;
}

/// Takes the citation right after a closing marker — `[سوره: آیه]` for
/// Quran and `(صحیح مسلم)`-style for hadith — into the SAME span, so a
/// citation never strands alone in plain text. Only a citation
/// character starts the capture; without one, no span is invented.
///
/// Returns the END INDEX of the citation (or [start] when there is
/// none) — never a substring: the caller keeps an index-based cursor,
/// so no span can silently swallow unclassified text (a swallowed span
/// would both misclassify and break losslessness).
int _citationEnd(String body, int start) {
  var j = start;
  while (j < body.length && body[j] == ' ') {
    j++; // Spaces BEFORE the citation are part of the quote span.
  }
  if (j >= body.length) return start;
  final open = body[j];
  if (open != '[' && open != '(') return start;
  final close = open == '[' ? ']' : ')';
  final end = body.indexOf(close, j + 1);
  if (end < 0) return start;
  return end + 1;
}

/// Splits ONE paragraph (no `\n\n` inside) into segments. The joined
/// segments equal the input exactly.
List<TaharahSegment> splitTaharahQuotesInParagraph(String paragraph) {
  final out = <TaharahSegment>[];
  final buf = StringBuffer();
  void flush() {
    if (buf.isNotEmpty) {
      out.add(TaharahSegment(text: buf.toString(), isQuote: false));
      buf.clear();
    }
  }

  var i = 0;
  while (i < paragraph.length) {
    final ch = paragraph[i];
    if (ch == _quranOpen) {
      final close = paragraph.indexOf(_quranClose, i + 1);
      if (close < 0) {
        flush();
        out.add(TaharahSegment(text: paragraph.substring(i), isQuote: false));
        return out;
      }
      flush();
      final ce = _citationEnd(paragraph, close + 1);
      out.add(TaharahSegment(
        text: paragraph.substring(i, ce),
        isQuote: true,
        isQuran: true,
      ));
      i = ce;
    } else if (ch == _hadithOpen) {
      final close = paragraph.indexOf(_hadithClose, i + 1);
      if (close < 0) {
        flush();
        out.add(TaharahSegment(text: paragraph.substring(i), isQuote: false));
        return out;
      }
      flush();
      final ce = _citationEnd(paragraph, close + 1);
      out.add(
        TaharahSegment(text: paragraph.substring(i, ce), isQuote: true),
      );
      i = ce;
    } else {
      buf.write(ch);
      i++;
    }
  }
  flush();
  return out;
}

/// Splits a full body into paragraphs (`\n\n` separators, the data's own
/// paragraph rhythm) and each paragraph into quote segments. Every layer
/// is invertible: join(paragraphs, '\n\n') == body, and within a
/// paragraph the joined segments == that paragraph.
List<List<TaharahSegment>> splitTaharahQuotes(String body) {
  final paragraphs = body.split('\n\n');
  return [
    for (final p in paragraphs)
      p.isEmpty
          ? [TaharahSegment(text: p, isQuote: false)]
          : splitTaharahQuotesInParagraph(p),
  ];
}

// ════════════════════════════════════════════════════════════════
// FLAT CONTENT CARDS
//
// The purification screen's own flat language (matches the qibla /
// sciences redesign): hairline AppCards, solid-alpha tint fills only,
// duotone tiles, NO gradient / glow / heavy shadow — and bodies run
// through the lossless splitter so Quran/hadith spans get a quiet
// quote block. Text sources are never altered.
// ════════════════════════════════════════════════════════════════

/// A flat card showing exactly ONE quote block (a marker-delimited
/// Quran or hadith span) full-width above/below nothing — used by the
/// body renderer. Kept private; see [TaharahRichText].
class _QuoteBlock extends StatelessWidget {
  final TaharahSegment segment;
  final Color accent;

  const _QuoteBlock({required this.segment, required this.accent});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: SelectableText(
        segment.text,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 13),
          color: t.textSecondary,
          height: 1.8,
        ),
      ),
    );
  }
}

class TaharahRichText extends StatelessWidget {
  final String body;
  final Color accent;

  const TaharahRichText({super.key, required this.body, required this.accent});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final paragraphs = splitTaharahQuotes(body);

    final rows = <Widget>[];
    for (final (pi, paragraph) in paragraphs.indexed) {
      // The layout gap RENDERS the source '\n\n' separator; character
      // round-trip is guaranteed at the segment level (the losslessness
      // test joins every paragraph's segments and re-joins with '\n\n').
      if (pi > 0) rows.add(const SizedBox(height: 8));
      for (final segment in paragraph) {
        rows.add(segment.isQuote
            ? _QuoteBlock(segment: segment, accent: accent)
            : SelectableText(
                segment.text,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 13),
                  color: t.textSecondary,
                  height: 1.6,
                ),
              ));
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }
}

/// Flat numbered entry (replaces the shadowed [NumberedCard] on this
/// screen; numbering order must not change the content).
class TaharahNumberedCard extends StatelessWidget {
  final int number;
  final String title;
  final String body;
  final int total;

  /// Accent for the number chip + quote blocks. Null → the screen
  /// hue.
  final Color? accentColor;

  const TaharahNumberedCard({
    super.key,
    required this.number,
    required this.title,
    required this.body,
    required this.total,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final color = accentColor ?? TopicHues.purification;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text('$number',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 15),
                      fontWeight: FontWeight.w800,
                      color: dsContentColor(context, color),
                    )),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: SelectableText(
                  title,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 14),
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: color.withValues(alpha: 0.1)),
          const SizedBox(height: 8),
          TaharahRichText(body: body, accent: color),
        ],
      ),
    );
  }
}

/// Flat ruling/definition card (replaces [RulingCard] on this screen).
class TaharahRulingCard extends StatelessWidget {
  final String title;
  final String body;
  final Color? accentColor;

  const TaharahRulingCard({
    super.key,
    required this.title,
    required this.body,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final color = accentColor ?? TopicHues.purification;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final gold = dark ? t.primary : t.tertiary;
    final chipColor = accentColor ?? gold;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: chipColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.article_outlined, size: 18, color: chipColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SelectableText(
                  title,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 14),
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TaharahRichText(body: body, accent: color),
        ],
      ),
    );
  }
}

/// Flat bullet list card for the plain string lists (sunan, mustahabb…).
///
/// NOTE: [title] is NOT rendered with a leading icon — the caller's
/// SectionHeader already carries the icon; keeping the card quiet keeps
/// the flat language (no repeated glyph noise).
class TaharahListCard extends StatelessWidget {
  final String title;
  final List<String> items;
  final Color? accentColor;

  const TaharahListCard({
    super.key,
    required this.title,
    required this.items,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final color = accentColor ?? TopicHues.purification;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 14),
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          for (final (i, item) in items.indexed)
            Padding(
              padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SelectableText(
                      item,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 13),
                        color: t.textSecondary,
                        height: 1.7,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

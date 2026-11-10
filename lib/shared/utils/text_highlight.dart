import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';

/// ═══════════════════════════════════════════════════════════════
/// Text highlighting utilities for search results.
///
/// Supports Arabic-aware matching (ignores tashkeel and normalizes
/// alif/ta-marbuta variants) while still highlighting the exact word in the
/// ORIGINAL text. This is achieved by normalizing the text while keeping a
/// map from each normalized character back to its position in the original
/// string, so matched ranges can be projected back onto the original text.
///
/// Reuse this anywhere search results need the matched word shaded/highlighted
/// (hadith, quran, notes, ...).
/// ═══════════════════════════════════════════════════════════════
class TextHighlight {
  TextHighlight._();

  /// Normalize a string for search matching and return the normalized string
  /// together with a map: `map[i]` is the index in [s] of the i-th normalized
  /// character. Removes Arabic diacritics (tashkeel), unifies alif/ta-marbuta/
  /// ya variants, and lowercases latin letters so both Arabic and English
  /// queries match.
  static ({String norm, List<int> map}) normalizeWithMap(String s) {
    final buf = StringBuffer();
    final map = <int>[];
    for (int i = 0; i < s.length; i++) {
      final code = s.codeUnitAt(i);
      // Skip Arabic tashkeel and superscript alif.
      if ((code >= 0x064B && code <= 0x065F) || code == 0x0670) continue;
      // Skip tatweel (kashida).
      if (code == 0x0640) continue;

      String out = s[i];
      switch (out) {
        case 'أ':
        case 'إ':
        case 'آ':
        case 'ٱ':
          out = 'ا';
        case 'ة':
          out = 'ه';
        case 'ى':
          out = 'ي';
        case 'ؤ':
          out = 'و';
        case 'ئ':
          out = 'ي';
        default:
          out = out.toLowerCase();
      }
      buf.write(out);
      map.add(i);
    }
    return (norm: buf.toString(), map: map);
  }

  /// Convenience: normalized string only (matches [normalizeWithMap]).
  static String normalize(String s) => normalizeWithMap(s).norm;

  /// The key the Arabic-only hadith databases are searched with: [normalize]
  /// plus the two letters a Persian keyboard writes differently from the
  /// Arabic copy (ی U+06CC → ي U+064A, ک U+06A9 → ك U+0643).
  ///
  /// Their `arabic_normalized` column never contains the Persian forms, so
  /// without this fold a Persian-typed «کتاب» finds nothing in «كتاب». An
  /// Arabic-typed query passes through unchanged — the mapping only adds rows.
  static String arabicSearchKey(String s) => normalize(s)
      .replaceAll('\u06CC', '\u064A')
      .replaceAll('\u06A9', '\u0643');

  /// The exact substring of [text] that [query] matches under THIS class's
  /// normalization — the literal to hand to [spans] on a destination screen.
  ///
  /// Needed by callers whose search ran on a different normalizer (the hadith
  /// databases match with [normalize] itself): deriving the literal from the
  /// row keeps the paint independent of which folds the searcher applied.
  static String literalMatch(String text, String query) {
    final matches = findMatches(text, query);
    if (matches.isEmpty) return '';
    final first = matches.first;
    if (first.end <= first.start) return '';
    return text.substring(first.start, first.end).trim();
  }

  /// Find all match ranges (start, endExclusive) in the ORIGINAL [text] where
  /// [query] occurs (after normalization). Returns empty if no match.
  static List<({int start, int end})> findMatches(String text, String query) {
    final result = <({int start, int end})>[];
    if (query.trim().isEmpty) return result;

    final normText = normalizeWithMap(text);
    final normQuery = normalize(query);
    if (normQuery.isEmpty || normText.norm.isEmpty) return result;

    int from = 0;
    while (true) {
      final idx = normText.norm.indexOf(normQuery, from);
      if (idx < 0) break;
      final startOrig = normText.map[idx];
      final endNormIdx = idx + normQuery.length; // exclusive in norm space
      final endOrig = endNormIdx < normText.map.length
          ? normText.map[endNormIdx]
          : text.length;
      result.add((start: startOrig, end: endOrig));
      from = idx + normQuery.length;
    }
    return result;
  }

  /// Build [InlineSpan]s for the full [text], shading every occurrence of
  /// [query] with [highlightStyle]. Non-matching parts use [baseStyle].
  static List<InlineSpan> spans(
    String text,
    String query, {
    TextStyle? baseStyle,
    required TextStyle highlightStyle,
  }) {
    final matches = findMatches(text, query);
    if (matches.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }
    final spans = <InlineSpan>[];
    int cursor = 0;
    for (final m in matches) {
      if (m.start > cursor) {
        spans.add(
            TextSpan(text: text.substring(cursor, m.start), style: baseStyle));
      }
      spans.add(TextSpan(
          text: text.substring(m.start, m.end), style: highlightStyle));
      cursor = m.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: baseStyle));
    }
    return spans;
  }

  /// Build a compact single-context snippet around the FIRST match, with the
  /// matched word highlighted. Useful for one-line search result rows.
  ///
  /// [context] is the number of characters kept on each side of the match.
  /// Adds a leading/trailing ellipsis when the text is trimmed.
  static List<InlineSpan> snippetSpans(
    String text,
    String query, {
    int context = 40,
    TextStyle? baseStyle,
    required TextStyle highlightStyle,
  }) {
    final matches = findMatches(text, query);
    if (matches.isEmpty) {
      final trimmed = text.length > context * 2
          ? '${text.substring(0, context * 2).trimRight()}…'
          : text;
      return [TextSpan(text: trimmed, style: baseStyle)];
    }

    final first = matches.first;
    int start = first.start - context;
    int end = first.end + context;
    final bool hasPrefix = start > 0;
    final bool hasSuffix = end < text.length;
    if (start < 0) start = 0;
    if (end > text.length) end = text.length;

    // Try to snap to word boundaries (space) for cleaner snippets.
    if (hasPrefix) {
      final sp = text.indexOf(' ', start);
      if (sp != -1 && sp < first.start) start = sp + 1;
    }
    if (hasSuffix) {
      final sp = text.lastIndexOf(' ', end);
      if (sp != -1 && sp > first.end) end = sp;
    }

    final spans = <InlineSpan>[];
    if (hasPrefix) spans.add(TextSpan(text: '… ', style: baseStyle));

    // Highlight all matches that fall within [start, end].
    int cursor = start;
    for (final m in matches) {
      if (m.end <= start || m.start >= end) continue;
      final ms = m.start < start ? start : m.start;
      final me = m.end > end ? end : m.end;
      if (ms > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, ms), style: baseStyle));
      }
      spans.add(TextSpan(text: text.substring(ms, me), style: highlightStyle));
      cursor = me;
    }
    if (cursor < end) {
      spans.add(TextSpan(text: text.substring(cursor, end), style: baseStyle));
    }
    if (hasSuffix) spans.add(TextSpan(text: ' …', style: baseStyle));
    return spans;
  }

  /// Default highlight style: a shaded background behind the matched word.
  static TextStyle defaultHighlightStyle(
    BuildContext context, {
    TextStyle? base,
    Color? background,
    Color? foreground,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = background ??
        (isDark ? AppTheme.goldPale : const Color(0xFFFFE082));
    return (base ?? const TextStyle()).copyWith(
      backgroundColor: bg,
      color: foreground ??
          (isDark ? const Color(0xFF1A1410) : const Color(0xFF3E2723)),
      fontWeight: FontWeight.w700,
    );
  }
}

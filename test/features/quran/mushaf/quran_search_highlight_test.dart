import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/quran/mushaf/quran_search_highlight.dart';

/// The match highlight maps a hit found in the *normalized* verse back onto
/// the *original* diacritized text. These tests pin that mapping: the exact
/// characters returned, the diacritics absorbed at the edges, the letter-variant
/// folding, and the multi-word behaviour that mirrors the search service.
void main() {
  group('searchMatchRanges', () {
    test('marks a plain word exactly', () {
      const text = 'بسم الله الرحمن الرحيم';
      final ranges = searchMatchRanges(text, 'الرحمن');
      expect(ranges.length, 1);
      expect(
        text.substring(ranges.single.start, ranges.single.end),
        'الرحمن',
      );
    });

    test('maps through diacritics and covers the whole rendered word', () {
      // ٱ + ل + ل + fatha + shadda + ه + kasra
      const text = 'ٱللَّهِ';
      final ranges = searchMatchRanges(text, 'الله');
      expect(ranges.length, 1);
      expect(ranges.single.start, 0);
      expect(ranges.single.end, text.length,
          reason: 'the trailing kasra is absorbed so the mark sits on the word');
    });

    test('folds letter variants (alef, ta marbuta)', () {
      // ر fatha ح sukun م fatha ة damma
      const text = 'رَحْمَةٌ';
      expect(searchMatchRanges(text, 'رحمه'), isNotEmpty,
          reason: 'ta marbuta normalizes to ha on both sides');
      expect(searchMatchRanges(text, 'رحمه').single.end, text.length);

      const withAlef = 'إِنَّ';
      expect(searchMatchRanges(withAlef, 'ان'), isNotEmpty,
          reason: 'hamza-alef normalizes to bare alef');
    });

    test('a multi-word query marks each word independently', () {
      const text = 'بسم الله الرحمن الرحيم';
      final ranges = searchMatchRanges(text, 'بسم الرحيم');
      expect(ranges.length, 2);
      expect(text.substring(ranges[0].start, ranges[0].end), 'بسم');
      expect(text.substring(ranges[1].start, ranges[1].end), 'الرحيم');
    });

    test('scattered query words both get marked', () {
      const text = 'الرحمن علم القرآن';
      final ranges = searchMatchRanges(text, 'الرحمن القرآن');
      expect(ranges.length, 2);
      expect(text.substring(ranges[0].start, ranges[0].end), 'الرحمن');
      expect(text.substring(ranges[1].start, ranges[1].end), 'القرآن');
    });

    test('a repeated word is marked at every occurrence', () {
      const text = 'قل هو الله أحد الله الصمد';
      final ranges = searchMatchRanges(text, 'الله');
      expect(ranges.length, 2);
      expect(ranges[0].end, lessThan(ranges[1].start));
    });

    test('overlapping hits merge into one range', () {
      // «قال» also occurs inside «قالوا».
      const text = 'قالوا وقال';
      final ranges = searchMatchRanges(text, 'قال قالوا');
      expect(ranges.length, 2);
      expect(text.substring(ranges[0].start, ranges[0].end), 'قالوا');
      expect(text.substring(ranges[1].start, ranges[1].end), 'قال');
    });

    test('returns nothing when the query does not occur', () {
      expect(searchMatchRanges('الرحمن الرحيم', 'ززز'), isEmpty);
    });

    test('returns nothing for an empty or whitespace query', () {
      expect(searchMatchRanges('الرحمن', ''), isEmpty);
      expect(searchMatchRanges('الرحمن', '   '), isEmpty);
      expect(searchMatchRanges('', 'الرحمن'), isEmpty);
    });
  });

  group('buildSearchHighlightSpan', () {
    const match = Color(0xFF1F7A63);
    const bg = Color(0x291F7A63);

    test('no match -> one plain span, no children', () {
      const text = 'قل هو الله أحد';
      final span = buildSearchHighlightSpan(
        text: text,
        query: 'ززز',
        matchColor: match,
        matchBackground: bg,
      );
      expect(span.text, text);
      expect(span.children, isNull);
    });

    test('marks the match and keeps the full text intact', () {
      const text = 'قل هو الله أحد';
      final span = buildSearchHighlightSpan(
        text: text,
        query: 'الله',
        matchColor: match,
        matchBackground: bg,
      );
      expect(span.toPlainText(), text);

      final marked = span.children!.whereType<TextSpan>().where(
            (s) => s.style?.backgroundColor == bg,
          );
      expect(marked.length, 1);
      expect(marked.single.text, 'الله');
      expect(marked.single.style?.color, match);
    });
  });
}

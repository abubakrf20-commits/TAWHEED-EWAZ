import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/books/presentation/book_page_text.dart';

/// The reader paints runs of the PAGE's own text; `BookHighlight` stores
/// offsets in the same space. A run builder that shifted an offset by one
/// would move every saved highlight, so these tests pin the arithmetic rather
/// than the look.
void main() {
  group('paragraphs', () {
    test('splits on line feeds and keeps every character otherwise', () {
      const text = 'اول\nدوم و سوم\n\nچهارم';
      final ranges = BookPageText.paragraphs(text);
      expect(ranges.map((r) => text.substring(r.start, r.end)).toList(),
          ['اول', 'دوم و سوم', 'چهارم']);
    });

    test('a page without line feeds is ONE paragraph', () {
      const text = 'یک بند پیوسته';
      final ranges = BookPageText.paragraphs(text);
      expect(ranges, [(start: 0, end: text.length)]);
    });

    test('never returns an empty range', () {
      expect(BookPageText.paragraphs('\n\n\n'), isEmpty);
      expect(BookPageText.paragraphs(''), isEmpty);
    });
  });

  group('runs', () {
    const text = 'الحمد لله رب العالمين (3) ثم';

    test('cover the range exactly once, body first', () {
      final runs = BookPageText.runs(
          text: text, rangeStart: 0, rangeEnd: text.length);
      expect(runs.first.start, 0);
      expect(runs.last.end, text.length);
      for (var i = 1; i < runs.length; i++) {
        expect(runs[i].start, runs[i - 1].end, reason: 'no gap, no overlap');
      }
    });

    test('a saved highlight is clipped to the paragraph', () {
      final runs = BookPageText.runs(
        text: text,
        rangeStart: 0,
        rangeEnd: 6,
        highlights: [(start: 3, end: 12, index: 0)],
      );
      expect(runs.map((r) => r.ink).toList(),
          [BookInk.body, BookInk.highlight]);
      expect(runs.last.start, 3);
      expect(runs.last.end, 6);
      expect(runs.last.highlightIndex, 0);
    });

    test('a search hit inside a highlight loses to the highlight', () {
      final runs = BookPageText.runs(
        text: text,
        rangeStart: 0,
        rangeEnd: text.length,
        highlights: [(start: 0, end: 12, index: 2)],
        searchMatches: [(start: 7, end: 10)],
      );
      expect(runs.where((r) => r.ink == BookInk.search), isEmpty);
      expect(runs.first.ink, BookInk.highlight);
      expect(runs.first.highlightIndex, 2);
    });

    test('only a footnote whose note exists becomes a marker', () {
      final withNote = BookPageText.runs(
        text: text,
        rangeStart: 0,
        rangeEnd: text.length,
        footnotes: {'3'},
      );
      final marker =
          withNote.singleWhere((r) => r.ink == BookInk.footnote);
      expect(text.substring(marker.start, marker.end), '(3)');

      final withoutNote = BookPageText.runs(
        text: text,
        rangeStart: 0,
        rangeEnd: text.length,
      );
      expect(withoutNote.where((r) => r.ink == BookInk.footnote), isEmpty);
    });

    test('an out-of-range highlight cannot escape the paragraph', () {
      final runs = BookPageText.runs(
        text: 'قصير',
        rangeStart: 0,
        rangeEnd: 4,
        highlights: [(start: 40, end: 90, index: 0)],
      );
      expect(runs.single.ink, BookInk.body);
      expect(runs.single.end, 4);
    });

    test('an empty range paints nothing', () {
      expect(BookPageText.runs(text: text, rangeStart: 4, rangeEnd: 4), isEmpty);
    });
  });

  group('noteIds', () {
    test('lists a page\'s note numbers in reading order, each once', () {
      const text = 'قال (3) ثم قال (7) ثم كرّر (3) و(12) و(مقام) لا يُعدّ.';
      expect(BookPageText.noteIds(text), ['3', '7', '12']);
    });

    test('a page without markers carries no apparatus', () {
      expect(BookPageText.noteIds('بند عارٍ من الأرقام'), isEmpty);
    });

    test('bracketed markers count too — some editions use them', () {
      const text = 'قال [2] ثم قال (3) ثم [2].';
      expect(BookPageText.noteIds(text), ['2', '3']);
    });
  });
}

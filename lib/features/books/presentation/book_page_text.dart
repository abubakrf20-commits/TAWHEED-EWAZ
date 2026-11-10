/// Cutting one printed page into paragraphs, and one paragraph into inked
/// runs (body / search hit / saved highlight / footnote marker).
///
/// Pure, so the reader's painting rules are unit-testable without pumping a
/// `SelectableText`: every run is expressed in offsets of the PAGE's own text,
/// which is also the coordinate space `BookHighlight` is stored in. A run
/// builder that silently shifted an offset would move every saved highlight
/// and every search hit by a word.
library;

/// What a run of page text is painted as.
enum BookInk {
  /// Plain body text.
  body,

  /// A match of the current in-reader query.
  search,

  /// A saved [BookHighlight].
  highlight,

  /// A `(N)` marker whose note exists in the book's footnote map.
  footnote,
}

/// A half-open `[start, end)` slice of the page text, painted as [ink].
class BookTextRun {
  const BookTextRun(
    this.start,
    this.end,
    this.ink, {
    this.highlightIndex = -1,
  });

  final int start;
  final int end;
  final BookInk ink;

  /// Index into the page's highlight list, so the painter can pick that
  /// highlight's colour. `-1` for every other kind.
  final int highlightIndex;

  int get length => end - start;
}

/// Paragraph ranges and ink runs of a page.
abstract final class BookPageText {
  const BookPageText._();

  static const int _newline = 0x0A;

  /// The footnote marker the book files use: `(12)` — or `[12]` in the
  /// editions whose apparatus is bracketed.
  static final RegExp _footnoteMark = RegExp(r'\((\d+)\)|\[(\d+)\]');

  /// The bare id of a marker match, whichever bracket the file used.
  static String _markId(RegExpMatch m) => m.group(1) ?? m.group(2)!;

  /// Paragraph ranges of [text], split on line feeds.
  ///
  /// Empty paragraphs (the blank lines a source file sometimes carries) are
  /// dropped, so the reader never paints a zero-height row; the paragraph gap
  /// it draws between entries is the only vertical rhythm.
  static List<({int start, int end})> paragraphs(String text) {
    final out = <({int start, int end})>[];
    var start = 0;
    for (var i = 0; i <= text.length; i++) {
      final boundary = i == text.length || text.codeUnitAt(i) == _newline;
      if (!boundary) continue;
      if (i > start) out.add((start: start, end: i));
      start = i + 1;
    }
    return out;
  }

  /// The note numbers this page's markers point at, in the order they are
  /// met, each id once — the apparatus a printed page sets at its foot.
  ///
  /// Ids are kept as written so they line up with the marker in the text and
  /// with the book's own footnote map.
  static List<String> noteIds(String text) {
    final out = <String>[];
    final seen = <String>{};
    for (final m in _footnoteMark.allMatches(text)) {
      final id = _markId(m);
      if (seen.add(id)) out.add(id);
    }
    return out;
  }

  /// Ordered, non-overlapping runs that cover exactly `[rangeStart, rangeEnd)`.
  ///
  /// Precedence on an overlap: a footnote marker wins over a highlight, which
  /// wins over a search hit, which wins over body text. Without a fixed order
  /// a highlighted word containing a search hit would paint twice and the
  /// later span would erase the earlier ink.
  static List<BookTextRun> runs({
    required String text,
    required int rangeStart,
    required int rangeEnd,
    Iterable<({int start, int end})> searchMatches = const [],
    Iterable<({int start, int end, int index})> highlights = const [],
    Set<String> footnotes = const {},
  }) {
    final start = rangeStart.clamp(0, text.length);
    final end = rangeEnd.clamp(start, text.length);
    if (end <= start) return const [];

    final marks = <BookTextRun>[];

    if (footnotes.isNotEmpty) {
      for (final m in _footnoteMark.allMatches(text, start)) {
        if (m.start >= end) break;
        if (m.end > end) continue;
        if (!footnotes.contains(_markId(m))) continue;
        marks.add(BookTextRun(m.start, m.end, BookInk.footnote));
      }
    }
    for (final h in highlights) {
      final s = h.start.clamp(start, end);
      final e = h.end.clamp(s, end);
      if (e > s) {
        marks.add(
            BookTextRun(s, e, BookInk.highlight, highlightIndex: h.index));
      }
    }
    for (final m in searchMatches) {
      final s = m.start.clamp(start, end);
      final e = m.end.clamp(s, end);
      if (e > s) marks.add(BookTextRun(s, e, BookInk.search));
    }

    marks.sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      if (byStart != 0) return byStart;
      return _rank(a.ink).compareTo(_rank(b.ink));
    });

    final out = <BookTextRun>[];
    var cursor = start;
    for (final mark in marks) {
      if (mark.end <= cursor) continue;
      final from = mark.start < cursor ? cursor : mark.start;
      if (from > cursor) out.add(BookTextRun(cursor, from, BookInk.body));
      out.add(BookTextRun(
        from,
        mark.end,
        mark.ink,
        highlightIndex: mark.highlightIndex,
      ));
      cursor = mark.end;
    }
    if (cursor < end) out.add(BookTextRun(cursor, end, BookInk.body));
    return out;
  }

  static int _rank(BookInk ink) => switch (ink) {
        BookInk.footnote => 0,
        BookInk.highlight => 1,
        BookInk.search => 2,
        BookInk.body => 3,
      };
}

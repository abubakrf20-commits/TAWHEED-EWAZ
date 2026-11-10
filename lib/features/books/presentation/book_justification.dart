import 'package:flutter/widgets.dart';

/// Whether a paragraph may be set justified.
///
/// `TextAlign.justify` stretches every line but the last to the full column,
/// so for a paragraph of `k` lines it adds exactly
/// `columnWidth − naturalWidth` to each of the first `k − 1`. On a wide column
/// with many words that is a hair per gap and reads as a ruled page; on a
/// narrow column with two or three words the same stretch tears the line
/// apart. The page cannot hyphenate Persian and must not insert a character
/// into the text — a page's text is the offset space stored highlights live
/// in (`BookPageText` states this) — so the honest answer is a decision per
/// paragraph: set it justified only where justification cannot gap.
///
/// [minLineFill] is that decision. A line that already fills four fifths of
/// its column is widened by at most a quarter; below that the words tear.
/// Measured on this reader: the default page (308 dp, 16 sp) has its worst
/// non-final line at 268.2 dp — fill 0.871, stretch 1.15 — and justifies,
/// while 28 sp over the same column breaks that line to 119.8 dp — fill 0.389,
/// stretch 2.57 — and falls back to ragged. The 0.8 floor leaves the default
/// page a tenth of headroom rather than sitting on the edge.
///
/// The decision is a rendering choice: it changes the paragraph's `textAlign`
/// and nothing else. No caller may let it touch [text].
abstract final class BookJustification {
  const BookJustification._();

  /// The share of the column a non-final line must already occupy.
  ///
  /// A fill of `f` bounds the stretch at `1 / f`, so 0.8 caps it at 1.25.
  static const double minLineFill = 0.8;

  /// Whether [text] reads well set justified inside [width].
  ///
  /// Measures the paragraph once, as it would lay out ragged, and inspects
  /// every line but the last: a line needs at least one space to be stretched
  /// at all, and one that is already wide enough for its column passes. All
  /// the lines must pass — justification stretches the whole paragraph, so
  /// one short line is enough to tear it.
  ///
  /// Single-word and single-line paragraphs are never justified: Skia has
  /// nothing to stretch, and a lone line is set as it broke.
  static bool accepts({
    required String text,
    required double width,
    required TextStyle style,
    required TextScaler textScaler,
    required TextDirection direction,
  }) {
    if (width <= 0 || text.trim().isEmpty) return false;
    // Laid out ragged on purpose (TextAlign.start is TextPainter's default):
    // the line widths below are the natural ones, which is what decides
    // whether stretching them would tear the column.
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: textScaler,
    );
    try {
      painter.layout(maxWidth: width);
      final lines = painter.computeLineMetrics();
      if (lines.length < 2) return false;
      var offset = 0;
      for (var i = 0; i < lines.length; i++) {
        final range = painter.getLineBoundary(TextPosition(offset: offset));
        if (!range.isValid || range.end <= offset) return false;
        final line = text.substring(range.start, range.end);
        offset = range.end;
        if (i == lines.length - 1) continue;
        // A line with no space has nothing to stretch; it is not a reprieve,
        // it simply cannot be the evidence against justification.
        final gaps = _spacedWords(line).length - 1;
        if (gaps < 1) continue;
        if (lines[i].width < width * minLineFill) return false;
      }
      // Every counted line passed. A paragraph whose lines were all single
      // words is still justified: there is nothing that could tear.
      return true;
    } finally {
      painter.dispose();
    }
  }

  /// Splits [line] on the spaces the engine can stretch.
  ///
  /// Trailing whitespace is dropped first: the soft wrap ends a line with a
  /// space, and counting it would let a line look like it had a gap it does
  /// not. A نیم‌فاصله (U+200C) or a non-breaking space (U+00A0) is not a break
  /// opportunity — the engine never widens one — so neither is counted.
  static List<String> _spacedWords(String line) {
    final trimmed = line.trimRight();
    if (trimmed.isEmpty) return const [];
    return trimmed.split(' ').where((word) => word.isNotEmpty).toList();
  }
}

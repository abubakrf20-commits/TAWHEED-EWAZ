// The reader never inserts a character into a page's text to improve a line
// break, and it does not set every paragraph justified. Two measured facts drive
// this file:
//
// 1. The engine wraps a compound wider than the column by breaking it inside the
//    column — never by running it off the edge — but it does not choose the
//    break: measured at 120 dp it ended a line mid-segment even though a
//    نیم‌فاصله joint that fitted was available. Nothing is therefore inserted to
//    coax a break, and nothing may be: a page's text is the offset space its
//    stored highlights and search hits live in (BookPageText states this), so
//    one inserted character would shift every offset after it. The joint is
//    still a real orthographic form, not a space — glued < jointed < spaced, the
//    sandwich this file measures.
// 2. `TextAlign.justify` stretches every line but the last to the full column, so
//    on a narrow column with two or three words it tears the line apart. The
//    reader therefore justifies a paragraph only where no line would tear
//    (book_justification.dart), and this file pins that decision at the reader's
//    real column widths and font sizes: the default page (308 dp, 16 sp) stays
//    justified, while 28 sp over the same column falls back to ragged.
//
// The face is read from disk because the test binding's default font is a
// stand-in: only a real Persian face gives these cases their true metrics.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/books/presentation/book_justification.dart';

const String _family = 'ReaderVazirmatn';
const int _zwnj = 0x200C;

// The reader's own range: book_reader_screen clamps the size to 12..28 and
// opens at 16.
const List<double> _sizes = [12, 16, 22, 28];

// The width the three margin steps put a line at, on a narrow phone and on a
// tablet, rebuilt from the page's own arithmetic by _contentWidth().
const List<double> _frames = [320, 360, 900];
const List<double> _margins = [16, 26, 38];
const double _gutter = 12;

const String _body =
    'بسم الله الرحمن الرحیم. ستایش از آنِ خداوندی است که آفرینش را بر پایهٔ حکمت '
    'خویش سامان داد و کتاب‌های آسمانی را راهنمای بندگانش قرار داد؛ آنگاه پیامبران '
    'را یکی پس از دیگری برانگیخت تا مردمان را از تاریکی‌ها به روشنایی برند و از '
    'پرستش بت‌ها بازدارند و به یکتاپرستی فرا خوانند.';

const String _longCompound =
    'از جمله نکات غیرقابل‌پیش‌بینی و پیچیده در این باب، آن است که برخی از '
    'می‌خواستند بی‌آنکه خود بدانند سببِ گمراهی دیگران شوند.';

const String _veryLongToken = 'غیرقابل‌پیش‌بینی‌ترین‌ها‌ی‌شان';

const String _passage = '$_body $_longCompound $_longCompound';

/// The measure cap, read out of the page so that changing it re-measures at the
/// new columns instead of leaving a stale number pinned here.
double _measureCap() {
  final source = File(
    'lib/features/books/presentation/widgets/book_reader_page.dart',
  ).readAsStringSync();
  final matches = RegExp(
    r'constraints\.maxWidth - (\d+(?:\.\d+)?)',
  ).allMatches(source).toList();
  expect(
    matches,
    hasLength(1),
    reason: 'the page no longer writes its measure cap as '
        '`constraints.maxWidth - N`, so this matrix cannot derive its columns',
  );
  return double.parse(matches.single.group(1)!);
}

/// Mirrors the page's own arithmetic: the width past the cap is split between
/// the two margins, and the fold margin is added to one side only.
double _contentWidth({
  required double frameWidth,
  required double sideMargin,
  required double cap,
  double gutter = 0,
}) {
  final extra = (frameWidth - cap) / 2;
  final base = sideMargin + (extra > 0 ? extra : 0);
  return frameWidth - 2 * base - gutter;
}

TextPainter _painter(
  String text,
  double width, {
  required double fontSize,
  TextAlign align = TextAlign.start,
}) {
  return TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontFamily: _family, fontSize: fontSize, height: 1.95),
    ),
    textDirection: TextDirection.rtl,
    textAlign: align,
  )..layout(maxWidth: width);
}

/// Every line end, walking the way a reader moves through the paragraph.
List<int> _lineEnds(TextPainter painter) {
  final ends = <int>[];
  var cursor = 0;
  final count = painter.computeLineMetrics().length;
  for (var i = 0; i < count; i++) {
    final range = painter.getLineBoundary(TextPosition(offset: cursor));
    if (range.end <= cursor) break;
    ends.add(range.end);
    cursor = range.end;
  }
  return ends;
}

/// The non-final lines of [text] that hold a gap the engine could stretch, keyed
/// by line index. A one-word line has nothing to stretch, so it can never be the
/// evidence against justification.
Map<int, double> _stretchableLines(TextPainter painter, String text) {
  final lines = painter.computeLineMetrics();
  final widths = <int, double>{};
  var offset = 0;
  for (var i = 0; i < lines.length; i++) {
    final range = painter.getLineBoundary(TextPosition(offset: offset));
    if (!range.isValid || range.end <= offset) break;
    final line = text.substring(range.start, range.end).trimRight();
    offset = range.end;
    if (i == lines.length - 1) continue;
    if (line.split(' ').where((word) => word.isNotEmpty).length < 2) continue;
    widths[i] = lines[i].width;
  }
  return widths;
}

/// The column the reader gives a line at the default frame and the «عادی»
/// margin, rebuilt from the page's own arithmetic.
double _defaultWidth(double cap) =>
    _contentWidth(frameWidth: 360, sideMargin: 26, cap: cap);

Iterable<double> _readerWidths(double cap) sync* {
  for (final frame in _frames) {
    for (final margin in _margins) {
      yield _contentWidth(
        frameWidth: frame,
        sideMargin: margin,
        cap: cap,
      );
      yield _contentWidth(
        frameWidth: frame,
        sideMargin: margin,
        cap: cap,
        gutter: _gutter,
      );
    }
  }
}

void main() {
  setUpAll(() async {
    final bytes = File(
      'assets/fonts/Vazirmatn-Regular.ttf',
    ).readAsBytesSync();
    final loader = FontLoader(_family)
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  });

  test('no line is wider than its column, at any reader width and size', () {
    final cap = _measureCap();
    for (final width in _readerWidths(cap)) {
      for (final size in _sizes) {
        for (final text in [_passage, _longCompound]) {
          final lines =
              _painter(text, width, fontSize: size).computeLineMetrics();
          expect(lines, isNotEmpty);
          for (final line in lines) {
            expect(
              line.width,
              lessThanOrEqualTo(width + 0.5),
              reason: 'column ${width.toStringAsFixed(1)} dp at $size sp '
                  'laid out a ${line.width.toStringAsFixed(1)} dp line',
            );
          }
        }
      }
    }
  });

  test('a compound too wide for the column is broken, never run off the edge',
      () {
    const text = 'متن $_veryLongToken و ادامهٔ سخن تا پایان جمله.';
    final start = text.indexOf(_veryLongToken);
    final end = start + _veryLongToken.length;
    for (final width in const [80.0, 120.0, 160.0]) {
      final painter = _painter(text, width, fontSize: 15);
      expect(
        painter.computeLineMetrics().length,
        greaterThan(1),
        reason: 'the engine should wrap a token wider than $width dp',
      );
      expect(
        _lineEnds(painter),
        anyElement(allOf(greaterThan(start), lessThan(end))),
        reason: 'no line ended inside the compound, so it either overflowed '
            'or was moved whole',
      );
      for (final line in painter.computeLineMetrics()) {
        expect(line.width, lessThanOrEqualTo(width + 0.5));
      }
    }
  });

  test('a نیم‌فاصله shapes as a joint, and a wide compound breaks in the column',
      () {
    const text = 'متن $_veryLongToken و ادامهٔ سخن تا پایان جمله.';
    final start = text.indexOf(_veryLongToken);
    final stop = start + _veryLongToken.length;
    final joint = String.fromCharCode(_zwnj);
    expect(
      _veryLongToken.contains(joint),
      isTrue,
      reason: 'the fixture lost its نیم‌فاصله',
    );
    expect(
      _veryLongToken.contains(' '),
      isFalse,
      reason: 'the fixture must not read the joint as an ordinary space',
    );

    // The joint is its own orthographic form: glued is narrower than jointed,
    // and jointed is narrower than the same letters held apart by a space. A
    // reader that dropped or spaced the character could not produce this.
    double naturalWidth(String token) =>
        _painter(token, double.infinity, fontSize: 15).width;
    final jointed = naturalWidth(_veryLongToken);
    final glued = naturalWidth(_veryLongToken.replaceAll(joint, ''));
    final spaced = naturalWidth(_veryLongToken.replaceAll(joint, ' '));
    expect(glued, lessThan(jointed));
    expect(jointed, lessThan(spaced));

    // Broken inside the column, and inside the compound — where the break
    // lands is the engine's choice (measured: not always a joint), which is
    // exactly why nothing is inserted to steer it.
    for (final width in const [120.0, 160.0]) {
      final painter = _painter(text, width, fontSize: 15);
      expect(
        _lineEnds(painter),
        anyElement(allOf(greaterThan(start), lessThan(stop))),
        reason: 'no line ended inside the compound at $width dp, so it either '
            'overflowed or was moved whole',
      );
      for (final line in painter.computeLineMetrics()) {
        expect(
          line.width,
          lessThanOrEqualTo(width + 0.5),
          reason: 'a ${line.width.toStringAsFixed(1)} dp line overflowed the '
              '$width dp column',
        );
      }
    }
  });

  test('no reader source inserts a break character into page text', () {
    final offenders = <String>[];
    for (final entity
        in Directory('lib/features/books').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (source.contains('\u200B') || source.contains('\u00AD')) {
        offenders.add(entity.path);
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'a ZWSP or soft hyphen in reader source would shift every stored '
          'highlight offset on the page it touches',
    );
  });

  test('a paragraph is justified only where no line would tear', () {
    final cap = _measureCap();
    var justified = 0;
    var ragged = 0;
    for (final width in _readerWidths(cap)) {
      for (final size in _sizes) {
        final style = TextStyle(
          fontFamily: _family,
          fontSize: size,
          height: 1.95,
        );
        final natural = _painter(_passage, width, fontSize: size);
        final stretchable = _stretchableLines(natural, _passage);
        final accepted = BookJustification.accepts(
          text: _passage,
          width: width,
          style: style,
          textScaler: TextScaler.noScaling,
          direction: TextDirection.rtl,
        );
        final label = 'column ${width.toStringAsFixed(0)} dp at $size sp';
        if (!accepted) {
          ragged++;
          expect(
            stretchable.values.any(
              (lineWidth) => lineWidth < width * BookJustification.minLineFill,
            ),
            isTrue,
            reason: '$label refused justification although every stretchable '
                'line already filled the column',
          );
          continue;
        }
        justified++;
        expect(stretchable, isNotEmpty, reason: label);
        for (final entry in stretchable.entries) {
          expect(
            entry.value,
            greaterThanOrEqualTo(width * BookJustification.minLineFill - 0.5),
            reason: '$label accepted with line ${entry.key} at '
                '${entry.value.toStringAsFixed(1)} dp',
          );
        }
        final justifiedPainter = _painter(
          _passage,
          width,
          fontSize: size,
          align: TextAlign.justify,
        );
        final naturalLines = natural.computeLineMetrics();
        final justifiedLines = justifiedPainter.computeLineMetrics();
        expect(
          justifiedLines,
          hasLength(naturalLines.length),
          reason: 'justification must not re-break the paragraph',
        );
        for (var i = 0; i < naturalLines.length; i++) {
          expect(
            justifiedLines[i].width,
            lessThanOrEqualTo(width + 0.5),
            reason: '$label: a justified line overflowed its column',
          );
        }
        // The last line is the paragraph's short tail and is never stretched.
        expect(
          justifiedLines.last.width,
          closeTo(naturalLines.last.width, 0.5),
          reason: label,
        );
        for (final index in stretchable.keys) {
          expect(
            justifiedLines[index].width,
            closeTo(width, 0.5),
            reason: '$label: line $index carries a gap, so it must fill',
          );
        }
      }
    }
    expect(justified, greaterThan(0), reason: 'the reader never justifies');
    expect(ragged, greaterThan(0), reason: 'the policy never refuses');
  });

  test('the reader’s default page stays justified; 28 sp over it does not', () {
    final cap = _measureCap();
    final width = _defaultWidth(cap);
    expect(width, closeTo(308, 0.5));
    TextStyle styleAt(double size) => TextStyle(
          fontFamily: _family,
          fontSize: size,
          height: 1.95,
        );
    bool acceptsAt(double size) => BookJustification.accepts(
          text: _passage,
          width: width,
          style: styleAt(size),
          textScaler: TextScaler.noScaling,
          direction: TextDirection.rtl,
        );
    // The widest non-final line already fills 87 % of the column at 16 sp, so
    // justification stretches it by 15 % — the default page stays justified.
    expect(acceptsAt(16), isTrue);
    // The same column at 28 sp leaves one two-word line at 39 % of its width;
    // justifying it would stretch that line by 157 %, so it is set ragged.
    expect(acceptsAt(28), isFalse);
    final natural = _painter(_passage, width, fontSize: 28);
    final stretchable = _stretchableLines(natural, _passage);
    expect(stretchable, isNotEmpty);
    final narrowest = stretchable.values.reduce((a, b) => a < b ? a : b);
    expect(narrowest / width, lessThan(BookJustification.minLineFill));
  });

  group('justification policy', () {
    bool acceptsAt(String text, double width, {double size = 16}) =>
        BookJustification.accepts(
          text: text,
          width: width,
          style: TextStyle(fontFamily: _family, fontSize: size, height: 1.95),
          textScaler: TextScaler.noScaling,
          direction: TextDirection.rtl,
        );

    test('refuses text that cannot be justified', () {
      expect(acceptsAt('', 308), isFalse);
      expect(acceptsAt('   ', 308), isFalse);
      expect(acceptsAt(_passage, 0), isFalse);
      expect(acceptsAt(_passage, -10), isFalse);
      // One line has no interior line to stretch.
      expect(acceptsAt('بسم الله الرحمن الرحیم', 588), isFalse);
    });

    test('accepts a paragraph that fills every line it has', () {
      expect(acceptsAt(_passage, 588), isTrue);
    });
  });
}

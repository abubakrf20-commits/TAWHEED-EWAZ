import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/shared/utils/number_format.dart';

/// The single fraction formatter must never let RTL reorder the two numbers.
/// These tests render the real widget layer, so the bidi algorithm actually
/// runs — a pure string compare cannot catch a reordering.
void main() {
  String two(int a, int b) =>
      '${NumberFormat.ltrIsolated('$a')} از ${NumberFormat.ltrIsolated('$b')}';

  test('Latin digits, Persian word order, per-number isolation', () {
    expect(NumberFormat.fraction(124, 604), two(124, 604));
    expect(NumberFormat.fraction(1, 5), two(1, 5));
    expect(NumberFormat.fraction(0, 604), two(0, 604));
    expect(NumberFormat.fraction(29, 48), two(29, 48));
  });

  test('the phrase itself is never isolated', () {
    // Whole-phrase isolation is the reported bug: the run gets an LTR base,
    // so an RTL reader sees the two counters swapped. The word «از» must sit
    // BETWEEN two isolates, not inside one.
    final s = NumberFormat.fraction(124, 604);
    expect(s, contains('\u2069 از \u2066'));
    expect(s, isNot(startsWith('\u2066124 از 604\u2069')));
  });

  test('negative operands clamp to zero', () {
    expect(NumberFormat.fraction(-3, 10), two(0, 10));
    expect(NumberFormat.fraction(4, -10), two(4, 0));
  });

  test('the isolate wraps only with isolate characters', () {
    final s = NumberFormat.ltrIsolated('29 / 48');
    expect(s.codeUnitAt(0), 0x2066); // LEFT-TO-RIGHT ISOLATE
    expect(s.codeUnitAt(s.length - 1), 0x2069); // POP DIRECTIONAL ISOLATE
    expect(s, contains('29 / 48'));
  });

  group('formatSigned — explicit sign, true minus, isolated', () {
    test('zero has no sign', () {
      expect(NumberFormat.formatSigned(0), NumberFormat.ltrIsolated('0'));
    });

    test('positive values carry an ASCII plus', () {
      expect(NumberFormat.formatSigned(2), NumberFormat.ltrIsolated('+2'));
      expect(NumberFormat.formatSigned(70), NumberFormat.ltrIsolated('+70'));
    });

    test('negative values use U+2212, never the hyphen', () {
      final s = NumberFormat.formatSigned(-5);
      expect(s, NumberFormat.ltrIsolated('−5'));
      expect(s, contains('−'));
      expect(s, isNot(contains('-')));
    });
  });

  group('formatDegrees — value and sign stay glued', () {
    test('integral values drop the .0', () {
      expect(NumberFormat.formatDegrees(18), NumberFormat.ltrIsolated('18°'));
      expect(NumberFormat.formatDegrees(18.0), NumberFormat.ltrIsolated('18°'));
    });

    test('fractional values keep their decimals', () {
      expect(
          NumberFormat.formatDegrees(18.5), NumberFormat.ltrIsolated('18.5°'));
    });

    test('negative angles keep the true minus inside', () {
      expect(
          NumberFormat.formatDegrees(-5), NumberFormat.ltrIsolated('-5°'));
    });
  });

  group('formatMinutes — number isolated, unit in the RTL run', () {
    test('unit follows the isolated number', () {
      expect(NumberFormat.formatMinutes(5),
          '${NumberFormat.ltrIsolated('5')} دقیقه');
    });
  });

  group('rendered inside RTL and LTR paragraphs', () {
    Future<void> pump(WidgetTester tester, String body,
        {TextDirection direction = TextDirection.rtl}) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: direction,
          child: MaterialApp(
            home: Scaffold(
              body: Center(child: Text('مقدار: $body — تمام')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('signed value keeps sign order in RTL', (tester) async {
      await pump(tester, NumberFormat.formatSigned(-5));
      expect(tester.takeException(), isNull);
      final data = tester.widget<Text>(find.textContaining('−5')).data!;
      expect(data.indexOf('−'), lessThan(data.indexOf('5')));
    });

    testWidgets('signed value keeps sign order in LTR', (tester) async {
      await pump(tester, NumberFormat.formatSigned(-5),
          direction: TextDirection.ltr);
      expect(tester.takeException(), isNull);
      final data = tester.widget<Text>(find.textContaining('−5')).data!;
      expect(data.indexOf('−'), lessThan(data.indexOf('5')));
    });

    testWidgets('degrees never mirror in RTL', (tester) async {
      await pump(tester, NumberFormat.formatDegrees(18));
      expect(tester.takeException(), isNull);
      final data = tester.widget<Text>(find.textContaining('18°')).data!;
      expect(data.indexOf('18'), lessThan(data.indexOf('°')));
    });
  });

  group('rendered inside a Persian (RTL) line', () {
    // The whole paragraph is Persian, so bidi applies to the fraction as a
    // substring — exactly the case that used to swap the counters.
    Future<void> pump(WidgetTester tester, String body) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.rtl,
          child: MaterialApp(
            home: Scaffold(
              body: Center(child: Text('صفحه‌ها: $body — تمام')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the fraction keeps its on-screen order', (tester) async {
      await pump(tester, NumberFormat.fraction(124, 604));
      expect(tester.takeException(), isNull);

      final finder = find.textContaining('از');
      expect(finder, findsOneWidget);
      final data = tester.widget<Text>(finder).data!;

      // Visual-order hard check: the FIRST operand must sit to the RIGHT of
      // the second in an RTL line, i.e. the reader meets «124» first. A
      // whole-phrase isolate lays the run out left-to-right inside the RTL
      // paragraph and this assertion is what catches it (measured, 2026-10-19:
      // whole-phrase gave x(first)=0 < x(second)=40).
      final paragraph = tester.renderObject<RenderParagraph>(finder);
      double? left(String digits) {
        final start = data.indexOf(digits);
        final boxes = paragraph.getBoxesForSelection(
            TextSelection(baseOffset: start, extentOffset: start + digits.length));
        return boxes.isEmpty ? null : boxes.first.left;
      }

      final first = left('124');
      final second = left('604');
      expect(first, isNotNull);
      expect(second, isNotNull);
      expect(first!, greaterThan(second!));
    });

    testWidgets('an isolated digit run keeps its digits in order',
        (tester) async {
      await pump(tester, NumberFormat.ltrIsolated('29 / 48'));
      expect(tester.takeException(), isNull);

      final finder = find.textContaining('48');
      expect(finder, findsOneWidget);
      final data = tester.widget<Text>(finder).data!;
      expect(data.indexOf('29'), lessThan(data.indexOf('48')));
      expect(data, contains('29 / 48'));
    });
  });
}

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/shared/widgets/number_input_formatters.dart';

/// Drives the formatter the way a text field does: the widget hands over the
/// text plus the caret, and the caret is what this test is really about.
TextEditingValue _type(String typed, {int? caret}) {
  const formatter = LatinGroupingFormatter();
  final value = TextEditingValue(
    text: typed,
    selection: TextSelection.collapsed(offset: caret ?? typed.length),
  );
  return formatter.formatEditUpdate(TextEditingValue.empty, value);
}

void main() {
  group('NumberFormat.groupDigits', () {
    test('groups by threes from the right', () {
      expect(NumberFormat.groupDigits('1000'), '1,000');
      expect(NumberFormat.groupDigits('10000000'), '10,000,000');
      expect(NumberFormat.groupDigits('999'), '999');
    });

    test('is stable over its own output', () {
      final once = NumberFormat.groupDigits('12345678');
      expect(NumberFormat.groupDigits(once), once);
    });

    test('folds Persian and Arabic-Indic digits before grouping', () {
      expect(NumberFormat.groupDigits('۱۰۰۰۰۰۰۰'), '10,000,000');
      expect(NumberFormat.groupDigits('١٢٣٤٥'), '12,345');
    });

    test('groups only the integer part of a decimal', () {
      expect(NumberFormat.groupDigits('1234.5678'), '1,234.5678');
      expect(NumberFormat.groupDigits('12.'), '12.');
      expect(NumberFormat.groupDigits('-12345'), '-12,345');
    });

    test('passes through anything that is not a number', () {
      expect(NumberFormat.groupDigits(''), '');
      expect(NumberFormat.groupDigits('abc'), 'abc');
      expect(NumberFormat.groupDigits('1105*3'), '1105*3');
    });

    test('grouped() takes a number and never reprints .0', () {
      expect(NumberFormat.grouped(10000000), '10,000,000');
      expect(NumberFormat.grouped(10000000.0), '10,000,000');
      expect(NumberFormat.grouped(333.33), '333.33');
      // A quantity is grouped even at four digits — the ungrouped helper for
      // a year or a page is `en`.
      expect(NumberFormat.grouped(2026), '2,026');
    });

    test('parse reads back what the app prints', () {
      expect(NumberFormat.parse(NumberFormat.formatPlain(10000000)),
          10000000.0);
      expect(NumberFormat.parse('1,234.5'), 1234.5);
    });

    test('formatGram groups a heavy amount', () {
      expect(NumberFormat.formatGram(12000), '12,000 گرم');
      expect(NumberFormat.formatGram(31.5), '31.5 گرم');
    });

    test('formatBytes groups a size that passes 1,000 units', () {
      // `formatBytes` returns an LTR-isolated run, so the asserts look for the
      // text inside the marks.
      expect(NumberFormat.formatBytes(1073741824), contains('1.0GB'));
      expect(NumberFormat.formatBytes(1023 * 1048576), contains('1,023.0MB'));
      expect(NumberFormat.formatBytes(0), contains('0KB'));
    });
  });

  group('LatinGroupingFormatter', () {
    test('groups while typing', () {
      expect(_type('10000000').text, '10,000,000');
    });

    test('keeps the caret after the digits it was following', () {
      // Ten digits typed, caret at the end of the ten — not at the end of the
      // twelve characters the separators made.
      final v = _type('1000000000');
      expect(v.text, '1,000,000,000');
      expect(v.selection.extentOffset, 13);
      // Continuing from there must append after the last digit.
      expect(_type('10000000004').selection.extentOffset, 14);
    });

    test('a caret in the middle does not jump to the end', () {
      // «100|000» — three digits before the caret in «1,000,000» sits right
      // after the leading group.
      final v = _type('100000', caret: 3);
      expect(v.text, '100,000');
      expect(v.selection.extentOffset, 3);
    });

    test('drops anything that is not a digit (or one decimal point)', () {
      expect(_type('12abc34').text, '1,234');
      expect(_type('12.34.56').text, '12.3456');
      expect(_type('1,2,3').text, '123');
    });

    test('allowDecimal: false refuses a point', () {
      const formatter = LatinGroupingFormatter(allowDecimal: false);
      final v = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
            text: '12.34', selection: TextSelection.collapsed(offset: 5)),
      );
      expect(v.text, '1,234');
    });

    test('accepts a value typed with Persian digits', () {
      final v = _type('۱۰۰۰۰۰۰۰');
      expect(v.text, '10,000,000');
      expect(v.selection.extentOffset, 10);
    });

    test('an empty field stays empty and unselected', () {
      expect(_type('').text, '');
      expect(_type('').selection.extentOffset, 0);
    });
  });

  group('LatinDigitFoldFormatter', () {
    test('folds without touching the rest of the text', () {
      const fold = LatinDigitFoldFormatter();
      final v = fold.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
            text: '۲۱:۳۰', selection: TextSelection.collapsed(offset: 5)),
      );
      expect(v.text, '21:30');
      expect(v.selection.extentOffset, 5);
    });
  });
}

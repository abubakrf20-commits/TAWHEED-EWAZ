import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

void main() {
  group('NumberFormat.formatPlain', () {
    test('groups whole amounts', () {
      expect(NumberFormat.formatPlain(4200000), '4,200,000');
      expect(NumberFormat.formatPlain(0), '0');
      expect(NumberFormat.formatPlain(-1500), '-1,500');
    });

    test('keeps a fractional amount and its separators', () {
      // The old fallback ran toStringAsFixed(0): it rounded the fraction away
      // AND skipped grouping, so 12345.5 printed as "12346" while 12346.0
      // printed as "12,346" on the same screen.
      expect(NumberFormat.formatPlain(12345.5), '12,345.5');
      expect(NumberFormat.formatPlain(1234.25), '1,234.25');
      expect(NumberFormat.formatPlain(-1234.5), '-1,234.5');
    });

    test('drops a trailing zero but keeps one decimal', () {
      expect(NumberFormat.formatPlain(2.10), '2.1');
      expect(NumberFormat.formatPlain(2.05), '2.05');
    });

    test('small fractions stay ungrouped', () {
      expect(NumberFormat.formatPlain(12.5), '12.5');
      expect(NumberFormat.formatPlain(0.5), '0.5');
    });

    test('a non-finite value never prints NaN', () {
      expect(NumberFormat.formatPlain(double.nan), '0');
      expect(NumberFormat.formatPlain(double.infinity), '0');
    });

    test('en stays ungrouped so a year is never «1,403»', () {
      // Four digits is a Jalali year, a hijri year, a page and a verse number
      // before it is ever a count: grouping here printed «16 دی 1,403» and
      // «1,403» wherever the app shows a year. Quantities that can grow go
      // through `grouped()`.
      expect(NumberFormat.en(1403), '1403');
      expect(NumberFormat.en(20000), '20000');
      expect(NumberFormat.en(-1500), '-1500');
      expect(NumberFormat.en(604), '604');
      expect(NumberFormat.en(0), '0');
    });

    test('round-trips through parse', () {
      expect(NumberFormat.parse(NumberFormat.formatPlain(4200000)), 4200000);
    });
  });

  group('NumberFormat.formatMoney', () {
    test('glues the unit on, or degrades to a bare number', () {
      expect(NumberFormat.formatMoney(1500000, 'تومان'), '1,500,000 تومان');
      expect(NumberFormat.formatMoney(1500000, ''), '1,500,000');
    });
  });
}

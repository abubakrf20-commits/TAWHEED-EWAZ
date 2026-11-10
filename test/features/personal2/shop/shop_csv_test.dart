import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/personal2/shop/services/shop_csv.dart';

/// CSV import/export: dialect, validation, duplicate detection and the
/// round trip. Parsing is pure (the isolate wrapper just hosts it), so these
/// run without a database.
void main() {
  group('dialect', () {
    test('the headers carry the documented columns', () {
      expect(ShopCsv.productHeader,
          'name,barcode,category,unit,sellPrice,buyPrice,stock');
      expect(ShopCsv.customerHeader, 'name,phone,address,creditLimit,balance');
    });
  });

  group('import validation', () {
    test('a clean file parses with zero errors', () {
      final result = ShopCsv.parseProducts(
        '${ShopCsv.productHeader}\n'
        'چای احمد,6274123390,,عدد,250000,200000,2.5\n'
        'شکر,,قند,بسته,60000,45000,10\n',
      );
      expect(result.errors, isEmpty);
      expect(result.duplicateBarcodes, isEmpty);
      expect(result.rows, hasLength(2));
      expect(result.rows.first.name, 'چای احمد');
      expect(result.rows.first.barcode, '6274123390');
      expect(result.rows.first.sellPrice, 250000);
      expect(result.rows.first.stockMilli, 2500,
          reason: '2.5 units = 2500 milli');
      expect(result.rows.last.stockMilli, 10000);
    });

    test('Persian digits in prices parse (the keyboard writes them)', () {
      final result = ShopCsv.parseProducts(
        '${ShopCsv.productHeader}\n'
        'چای,,قند,عدد,۲۵۰۰۰۰,۲۰۰۰۰۰,۱٫۵\n',
      );
      expect(result.errors, isEmpty);
      expect(result.rows.single.sellPrice, 250000);
      expect(result.rows.single.stockMilli, 1500);
    });

    test('a bad price is a row-level error, not a crash', () {
      final result = ShopCsv.parseProducts(
        '${ShopCsv.productHeader}\n'
        'چای,,قند,عدد,دویست,200000,1\n',
      );
      expect(result.rows, isEmpty);
      expect(result.errors.single.message, contains('قیمت فروش'));
      expect(result.errors.single.lineNumber, 2);
    });

    test('a missing name is refused', () {
      final result = ShopCsv.parseProducts(
        '${ShopCsv.productHeader}\n'
        ',12345,,,100,50,1\n',
      );
      expect(result.errors.single.message, contains('نام'));
    });

    test('duplicate barcodes are reported for the preview', () {
      final result = ShopCsv.parseProducts(
        '${ShopCsv.productHeader}\n'
        'چای,12345,,عدد,100,50,1\n'
        'شکر,12345,,عدد,200,80,2\n',
      );
      expect(result.rows, hasLength(2),
          reason: 'rows parse; the duplicate is a preview warning');
      expect(result.duplicateBarcodes, ['12345']);
      expect(result.hasErrors, isTrue);
    });

    test('quoted commas survive (a comma inside a product name)', () {
      final result = ShopCsv.parseProducts(
        '${ShopCsv.productHeader}\n'
        '"چای، احمد",6274123390,,عدد,250000,200000,1\n',
      );
      expect(result.rows.single.name, 'چای، احمد');
      expect(result.rows.single.barcode, '6274123390');
    });

    test('sub-milli precision is rejected like everywhere else', () {
      final result = ShopCsv.parseProducts(
        '${ShopCsv.productHeader}\n'
        'چای,,,عدد,100,50,1.2345\n',
      );
      // parseQtyToMilli returns null → stock falls back to 0, row survives.
      expect(result.rows.single.stockMilli, 0);
    });

    test('the header row is skipped by shape, not by line number', () {
      final result = ShopCsv.parseProducts(
        'name,barcode,category,unit,sellPrice,buyPrice,stock\n'
        'چای,,,عدد,100,50,1\n',
      );
      expect(result.rows, hasLength(1));
      expect(result.errors, isEmpty);
    });
  });

  test('the isolate wrapper returns the same result as the pure call', () async {
    final content = '${ShopCsv.productHeader}\n'
        'چای,6274123390,,عدد,250000,200000,2.5\n';
    final viaIsolate = await ShopCsv.runImportParse(content);
    final direct = ShopCsv.parseProducts(content);
    expect(viaIsolate.rows.length, direct.rows.length);
    expect(viaIsolate.rows.first.name, direct.rows.first.name);
  });
}

import 'dart:convert';
import 'dart:isolate';

import 'package:tawheeed/features/personal2/shop/data/shop_dao.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop_domain.dart';

/// CSV import/export for products and customers.
///
/// Parsing runs in `Isolate.run` (the budget rule: no bulk work on the UI
/// isolate); the DAO writes validated rows in 200-row transaction chunks. The
/// dialect is deliberately boring: UTF-8, comma separated, quoted fields when
/// needed, no BOM, one header row. MONEY stays integer — the import reads
/// plain integers (a `1,500` value is two columns, which is why the format
/// forbids thousands separators), and stock accepts fractional text («1.5»)
/// through the same fixed-point parser the POS uses.
class CsvProductRow {
  const CsvProductRow({
    required this.lineNumber,
    required this.name,
    required this.barcode,
    required this.sellPrice,
    required this.buyPrice,
    required this.stockMilli,
  });

  final int lineNumber;
  final String name;
  final String barcode;
  final int sellPrice;
  final int buyPrice;
  final int stockMilli;
}

/// One row-level error from the import preview.
class CsvRowError {
  const CsvRowError(this.lineNumber, this.message);

  final int lineNumber;
  final String message;
}

/// The parse result: good rows plus the errors, so the preview can show
/// «۴۰ ردیف سالم، ۲ خطا» before anything is written.
class CsvImportResult {
  const CsvImportResult({
    required this.rows,
    required this.errors,
    required this.duplicateBarcodes,
  });

  final List<CsvProductRow> rows;
  final List<CsvRowError> errors;
  final List<String> duplicateBarcodes;

  bool get hasErrors => errors.isNotEmpty || duplicateBarcodes.isNotEmpty;
}

class ShopCsv {
  ShopCsv._();

  static const String productHeader =
      'name,barcode,category,unit,sellPrice,buyPrice,stock';
  static const String customerHeader = 'name,phone,address,creditLimit,balance';

  // ── Export ───────────────────────────────────────────────────────────

  static String exportProducts(List<ShopProduct> products) {
    final buffer = StringBuffer('$productHeader\n');
    for (final p in products) {
      buffer.writeln([
        _field(p.name),
        '', // barcodes join in Stage 3's full export; the importer reads it
        '',
        'عدد',
        p.sellPrice,
        p.buyPriceLast,
        qtyMilliToText(p.stockMilliCached),
      ].join(','));
    }
    return buffer.toString();
  }

  static String exportCustomers(
      List<ShopCustomer> customers, Map<String, int> balances) {
    final buffer = StringBuffer('$customerHeader\n');
    for (final c in customers) {
      buffer.writeln([
        _field(c.name),
        _field(c.phone),
        _field(c.address),
        c.creditLimit ?? '',
        balances[c.id] ?? 0,
      ].join(','));
    }
    return buffer.toString();
  }

  /// Quotes a field when it contains a comma, quote or newline; doubles the
  /// quotes inside.
  static String _field(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  // ── Import (products) ────────────────────────────────────────────────

  /// Parses product CSV text. Pure and CPU-bound — callers use
  /// [runImportParse] for the isolate.
  static CsvImportResult parseProducts(String content) {
    final errors = <CsvRowError>[];
    final rows = <CsvProductRow>[];
    final seenBarcodes = <String>{};
    final duplicates = <String>{};

    final lines = const LineSplitter().convert(content);
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) continue;
      final lineNumber = i + 1;
      if (i == 0 && line.trim().startsWith('name')) continue; // header

      final cells = _splitLine(line);
      if (cells.length < 5) {
        errors.add(CsvRowError(lineNumber,
            'ستون‌ها کم است (نام، بارکد، دسته، واحد، فروش، خرید، موجودی)'));
        continue;
      }
      final name = cells[0].trim();
      if (name.isEmpty) {
        errors.add(CsvRowError(lineNumber, 'نام خالی است'));
        continue;
      }
      final barcode = cells[1].trim();
      if (barcode.isNotEmpty && !seenBarcodes.add(barcode)) {
        duplicates.add(barcode);
      }
      final sell = int.tryParse(_asciiDigits(cells[4].trim()));
      if (sell == null || sell < 0) {
        errors.add(
            CsvRowError(lineNumber, 'قیمت فروش «${cells[4]}» نامعتبر است'));
        continue;
      }
      final buy = int.tryParse(_asciiDigits(cells[5].trim())) ?? 0;
      final stockText = cells.length > 6 ? cells[6].trim() : '';
      final stockMilli =
          stockText.isEmpty ? 0 : (parseQtyToMilli(stockText) ?? 0);

      rows.add(CsvProductRow(
        lineNumber: lineNumber,
        name: name,
        barcode: barcode,
        sellPrice: sell,
        buyPrice: buy < 0 ? 0 : buy,
        stockMilli: stockMilli,
      ));
    }
    return CsvImportResult(
      rows: rows,
      errors: errors,
      duplicateBarcodes: duplicates.toList(),
    );
  }

  /// The isolate wrapper: parse off the UI isolate.
  static Future<CsvImportResult> runImportParse(String content) {
    return Isolate.run(() => parseProducts(content));
  }

  /// Writes the validated rows in 200-row transaction chunks, so a 5,000-row
  /// import never holds one giant write lock nor blocks frames between
  /// chunks.
  static Future<int> importProducts(
      ShopDao dao, List<CsvProductRow> rows) async {
    var written = 0;
    for (var start = 0; start < rows.length; start += 200) {
      final chunk = rows.sublist(
          start, (start + 200) < rows.length ? start + 200 : rows.length);
      await dao.db.transaction(() async {
        for (final row in chunk) {
          final ok = await dao.saveProduct(
            id: 'prd_${row.lineNumber}_${DateTime.now().microsecondsSinceEpoch}',
            name: row.name,
            normalizedName: row.name,
            sellPrice: row.sellPrice,
            buyPrice: row.buyPrice,
            trackStock: true,
            active: true,
            openingStockMilli: row.stockMilli,
            openingCost: row.buyPrice,
            barcodes: row.barcode.isEmpty ? const [] : [row.barcode],
          );
          if (ok) written++;
        }
      });
    }
    return written;
  }

  /// Splits one CSV line honoring quotes (a quoted comma is data).
  static List<String> _splitLine(String line) {
    final out = <String>[];
    final current = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < line.length && line[i + 1] == '"') {
            current.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          current.write(ch);
        }
      } else if (ch == '"') {
        inQuotes = true;
      } else if (ch == ',') {
        out.add(current.toString());
        current.clear();
      } else {
        current.write(ch);
      }
    }
    out.add(current.toString());
    return out;
  }

  static String _asciiDigits(String input) {
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    final out = StringBuffer();
    for (final ch in input.runes) {
      final idx = fa.indexOf(String.fromCharCode(ch));
      out.write(idx >= 0 ? idx.toString() : String.fromCharCode(ch));
    }
    return out.toString();
  }
}

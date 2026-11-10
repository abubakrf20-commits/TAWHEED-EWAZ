import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'package:tawheeed/features/expenses/domain/entities/expense_model.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Exports the expenses ledger to a CSV file and hands it to the share sheet.
///
/// The file starts with a UTF-8 BOM so Excel/WPS open the Persian columns
/// correctly; amounts stay as plain numbers so they can be summed in a
/// spreadsheet. Columns: تاریخ (شمسی)، نوع، عنوان، دسته، مبلغ، توضیحات.
class ExpenseExporter {
  ExpenseExporter._();

  static String buildCsv(List<ExpenseModel> expenses) {
    final sorted = [...expenses]..sort((a, b) => b.date.compareTo(a.date));

    final buffer = StringBuffer('\uFEFF');
    buffer.writeln(_row(['تاریخ', 'نوع', 'عنوان', 'دسته', 'مبلغ', 'توضیحات']));
    for (final e in sorted) {
      final j = Jalali.fromDateTime(e.date);
      final date =
          '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';
      buffer.writeln(_row([
        date,
        e.isIncome ? 'درآمد' : 'هزینه',
        e.title,
        e.category,
        e.amount.toStringAsFixed(0),
        e.note ?? '',
      ]));
    }
    return buffer.toString();
  }

  static String _row(List<String> cells) => cells.map(_escape).join(',');

  static String _escape(String value) {
    final v = value.replaceAll('"', '""');
    // Quote whenever a separator/quote/newline is present so Excel parses it
    // as a single cell even for titles containing commas (ASCII or Persian).
    if (v.contains(',') ||
        v.contains('،') ||
        v.contains('"') ||
        v.contains('\n')) {
      return '"$v"';
    }
    return v;
  }

  /// Writes [csv] to a temp file and opens the share sheet. Returns false when
  /// sharing fails (never throws).
  static Future<bool> share(String csv,
      {String fileName = 'expenses.csv'}) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(utf8.encode(csv));
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, mimeType: 'text/csv')]),
      );
      return true;
    } catch (e) {
      AppLogger.warning('ExpenseExporter', 'share failed: $e');
      return false;
    }
  }
}

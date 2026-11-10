import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/core/constants/date_constants.dart';
import 'package:tawheeed/features/expenses/domain/entities/expense_model.dart';
import 'package:tawheeed/features/tools/shared/pdf_report_util.dart';

const PdfColor _expenseAccent = PdfColor.fromInt(0xFFE53935);
const PdfColor _ink = PdfColor.fromInt(0xFF263238);

String _jalaliDate(DateTime d) {
  final j = Jalali.fromDateTime(d);
  return '${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';
}

/// A printable A4 report of the ledger for one Jalali month (or a whole
/// year when [jalaliMonth] is null): period summary, per-category totals
/// against their budget limits, and every transaction of the period.
///
/// Built on the same [buildToolReportPdf] scaffold the zakat/hifz reports
/// use, so all tool PDFs share header, footer and fonts.
Future<Uint8List> buildExpenseReportPdf({
  required List<ExpenseModel> expenses,
  required int jalaliYear,
  int? jalaliMonth,
  Map<String, double> budgets = const {},
  String unit = 'تومان',
}) async {
  final rows = expenses.where((e) {
    final j = Jalali.fromDateTime(e.date);
    if (j.year != jalaliYear) return false;
    return jalaliMonth == null || j.month == jalaliMonth;
  }).toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  double totalIn = 0, totalOut = 0;
  final byCategory = <String, ({double income, double expense})>{};
  for (final e in rows) {
    final c = byCategory[e.category] ?? (income: 0.0, expense: 0.0);
    if (e.isIncome) {
      totalIn += e.amount;
      byCategory[e.category] =
          (income: c.income + e.amount, expense: c.expense);
    } else {
      totalOut += e.amount;
      byCategory[e.category] =
          (income: c.income, expense: c.expense + e.amount);
    }
  }

  final period = jalaliMonth == null
      ? '$jalaliYear'
      : '${DateConstants.persianMonths[jalaliMonth - 1]} $jalaliYear';

  // Month-by-month totals — only meaningful for a whole-year report; the
  // chart on the report screen shows exactly this, so the PDF mirrors it.
  final monthly = <int, ({double income, double expense})>{};
  if (jalaliMonth == null) {
    for (final e in rows) {
      final m = Jalali.fromDateTime(e.date).month;
      final c = monthly[m] ?? (income: 0.0, expense: 0.0);
      monthly[m] = e.isIncome
          ? (income: c.income + e.amount, expense: c.expense)
          : (income: c.income, expense: c.expense + e.amount);
    }
  }

  final categoryEntries = byCategory.entries.toList()
    ..sort((a, b) => b.value.expense.compareTo(a.value.expense));

  final body = <pw.Widget>[
    pdfSection(
      title: 'خلاصهٔ دوره — $period',
      accent: _expenseAccent,
      children: [
        pdfRow('دریافت‌ها', '${enMoney(totalIn)} $unit',
            _expenseAccent),
        pdfRow('پرداخت‌ها', '${enMoney(totalOut)} $unit',
            _expenseAccent),
        pdfRow(
            'موجود دوره', '${enMoney(totalIn - totalOut)} $unit',
            _expenseAccent,
            bold: true),
        pdfRow('تعداد تراکنش‌ها', enDigits(rows.length), _expenseAccent),
      ],
    ),
    if (monthly.isNotEmpty)
      pdfSection(
        title: 'ماه‌های $jalaliYear',
        accent: _expenseAccent,
        children: [
          for (var m = 1; m <= 12; m++)
            if (monthly[m] case final totals?)
              pdfRow(
                DateConstants.persianMonths[m - 1],
                'درآمد ${enMoney(totals.income)} $unit / '
                'هزینه ${enMoney(totals.expense)} $unit',
                _expenseAccent,
              ),
        ],
      ),
    if (categoryEntries.isNotEmpty)
      pdfSection(
        title: 'دسته‌ها',
        accent: _expenseAccent,
        children: [
          for (final entry in categoryEntries)
            pdfRow(
              entry.key,
              _categoryLine(entry.value, budgets[entry.key], unit),
              _expenseAccent,
            ),
        ],
      ),
    if (rows.isNotEmpty)
      pdfSection(
        title: 'تراکنش‌ها',
        accent: _expenseAccent,
        children: [
          for (final e in rows)
            pdfRow(
              '${_jalaliDate(e.date)} — ${e.title}',
              '${e.isIncome ? '+' : '-'}${enMoney(e.amount)} $unit',
              _expenseAccent,
            ),
        ],
      ),
    if (rows.isEmpty)
      pw.Text(
        'در این دوره تراکنشی ثبت نشده است.',
        textDirection: pw.TextDirection.rtl,
        style: const pw.TextStyle(fontSize: 11, color: _ink),
      ),
  ];

  return buildToolReportPdf(
    title: 'گزارش هزینه‌ها',
    subtitle: 'دوره: $period — برنامهٔ جامع توحید',
    accent: _expenseAccent,
    body: body,
  );
}

String _categoryLine(
  ({double income, double expense}) totals,
  double? limit,
  String unit,
) {
  final spent = '${enMoney(totals.expense)} $unit';
  if (totals.income > 0) {
    return 'هزینه $spent / درآمد ${enMoney(totals.income)} $unit';
  }
  if (limit == null || !limit.isFinite) return spent;
  final over = totals.expense > limit;
  return '$spent / سقف ${enMoney(limit)} $unit'
      '${over ? ' — بیش از سقف' : ''}';
}

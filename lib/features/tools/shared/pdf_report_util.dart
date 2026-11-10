import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

final Map<bool, Future<pw.Font>> _fontCache = {};

/// Loads Vazirmatn (regular/bold) once and reuses it so Persian/Arabic text
/// renders correctly in PDFs (Helvetica has no Arabic-script glyphs).
Future<pw.Font> pdfVazirFont({required bool bold}) =>
    _fontCache[bold] ??= () async {
      final data = await rootBundle.load(
        bold
            ? 'assets/fonts/Vazirmatn-Bold.ttf'
            : 'assets/fonts/Vazirmatn-Regular.ttf',
      );
      return pw.Font.ttf(data);
    }();

Uint8List? _logoCache;

/// Loads the app logo (assets/logo2.png) once and reuses it.
Future<Uint8List> pdfLogoBytes() async {
  if (_logoCache != null) return _logoCache!;
  final data = await rootBundle.load('assets/logo2.png');
  _logoCache = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  return _logoCache!;
}

/// Latin digits for `n`, thousands-grouped (product standard).
///
/// Grouping only starts at four digits, so a day count prints exactly as
/// before while a money figure reads «10,000,000».
String enDigits(num n) => NumberFormat.groupDigits(n.toStringAsFixed(0));

/// Latin-digit **money** for a report row: grouped, and keeping up to two
/// decimals instead of rounding them off.
///
/// WHY apart from [enDigits]: reports used `enDigits(amount.round())` on every
/// line, so each row lost up to half a unit of its own — and, worse, the rows
/// no longer added up to the total printed above them. Formatting rows and
/// totals through the same function keeps the column self-consistent.
String enMoney(num n) => NumberFormat.formatPlain(n.toDouble());

/// A single-page A4 report document with a shared header/footer scaffold.
///
/// [body] items are laid out vertically (RTL reading order is achieved by
/// listing children in the order they should appear from the right).
Future<Uint8List> buildToolReportPdf({
  required String title,
  required String subtitle,
  required PdfColor accent,
  required List<pw.Widget> body,
}) async {
  final reg = await pdfVazirFont(bold: false);
  final bold = await pdfVazirFont(bold: true);
  final logo = await pdfLogoBytes();

  final doc = pw.Document(
    title: title,
    author: 'توحید',
    theme: pw.ThemeData.withFont(base: reg, bold: bold),
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 40),
      header: (ctx) => _headerWidget(title, accent, logo),
      footer: (ctx) => _footerWidget(ctx.pageNumber, bold),
      build: (ctx) => [
        pw.SizedBox(height: 10),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xFFFDF6EC),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Text(
            subtitle,
            textDirection: pw.TextDirection.rtl,
            style: pw.TextStyle(
              font: bold,
              fontSize: 12,
              color: _inkMuted,
            ),
          ),
        ),
        pw.SizedBox(height: 12),
        ...body,
      ],
    ),
  );

  return doc.save();
}

/// Shares a generated PDF file through the system share sheet.
Future<void> shareToolReportPdf({
  required Uint8List bytes,
  required String fileName,
}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName')
    ..writeAsBytesSync(bytes, flush: true);
  await SharePlus.instance.share(ShareParams(
    files: [XFile(file.path, mimeType: 'application/pdf')],
  ));
}

/// A small header row: logo + title on the right, a colored accent bar — set
/// on a cream band so the report header matches the app's share cards.
pw.Widget _headerWidget(String title, PdfColor accent, Uint8List logo) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: pw.BoxDecoration(
      color: const PdfColor.fromInt(0xFFFDF6EC),
      borderRadius: pw.BorderRadius.circular(12),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.ClipOval(
          child: pw.Image(
            pw.MemoryImage(logo),
            width: 32,
            height: 32,
            fit: pw.BoxFit.cover,
          ),
        ),
        pw.Text(
          title,
          textDirection: pw.TextDirection.rtl,
          style: const pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: _ink,
          ),
        ),
        pw.Container(
          width: 4,
          height: 22,
          decoration: pw.BoxDecoration(
            color: accent,
            borderRadius: pw.BorderRadius.circular(2),
          ),
        ),
      ],
    ),
  );
}

pw.Widget _footerWidget(int page, pw.Font bold) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(
        'برنامهٔ جامع توحید',
        textDirection: pw.TextDirection.rtl,
        style: pw.TextStyle(font: bold, fontSize: 8, color: _inkMuted),
      ),
      pw.Text(
        'صفحه ${enDigits(page)}',
        textDirection: pw.TextDirection.rtl,
        style: const pw.TextStyle(fontSize: 8, color: _inkMuted),
      ),
    ],
  );
}

/// A labeled key/value row (label on the right, value on the left).
pw.Widget pdfRow(String label, String value, PdfColor accent,
    {bool bold = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          textDirection: pw.TextDirection.rtl,
          style: const pw.TextStyle(
            fontSize: 11,
            color: _inkMuted,
          ),
        ),
        pw.Text(
          value,
          textDirection: pw.TextDirection.rtl,
          style: pw.TextStyle(
            fontSize: 11,
            color: bold ? accent : _ink,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    ),
  );
}

/// A bordered box used to group a section of the report.
pw.Widget pdfSection({
  required String title,
  required List<pw.Widget> children,
  required PdfColor accent,
}) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 10),
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _a(accent, 0.35)),
      borderRadius: pw.BorderRadius.circular(10),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(
          title,
          textDirection: pw.TextDirection.rtl,
          style: pw.TextStyle(
            fontSize: 12,
            color: accent,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 6),
        ...children,
      ],
    ),
  );
}

const PdfColor _ink = PdfColor.fromInt(0xFF263238);
const PdfColor _inkMuted = PdfColor.fromInt(0xFF78909C);

PdfColor _a(PdfColor c, double alpha) =>
    PdfColor(c.red, c.green, c.blue, alpha);

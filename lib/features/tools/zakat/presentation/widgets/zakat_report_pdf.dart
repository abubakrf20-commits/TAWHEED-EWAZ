import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/features/tools/shared/pdf_report_util.dart';
import 'package:tawheeed/features/tools/zakat/domain/entities/zakat_result.dart';
import 'package:tawheeed/features/tools/zakat/domain/services/zakat_calculator.dart';

/// Builds a printable A4 PDF report for a zakat calculation.
Future<Uint8List> buildZakatReportPdf({required ZakatResult result}) async {
  const accent = PdfColor.fromInt(0xFF00695C);

  // واحد پولی که کاربر محاسبه را با آن انجام داده — PDF پیش‌تر عدد را
  // بدون واحد چاپ می‌کرد، که با پشتیبانی چند واحد پول گمراه‌کننده است.
  final unit = result.currency.unit;

  // Obligations are always rounded UP to the whole toman/kilogram: rounding
  // down would shortchange the poor (زکات بر ذمه تا قطعی‌البرائت به بالا).
  int due(num v) => v.ceil();

  final body = <pw.Widget>[];

  body.add(pdfSection(
    title: 'خلاصهٔ زکات',
    accent: accent,
    children: [
      pdfRow('مذهب', zakatMadhabLabel(result.madhab), accent),
      pdfRow('مبنای نصاب', result.nisabBasis, accent),
      // The printed cell is money: grouped, or a reader cannot tell 4200000
      // from 42,000,000 in an A4 report they may only see on paper.
      pdfRow('حد نصاب',
          '${NumberFormat.grouped(result.nisabThreshold.round())} $unit',
          accent),
      pdfRow('کل دارایی',
          '${NumberFormat.grouped(result.totalAssets.round())} $unit',
          accent),
      pdfRow('کل بدهی',
          '${NumberFormat.grouped(result.totalDebts.round())} $unit',
          accent),
      pdfRow('دارایی خالص',
          '${NumberFormat.grouped(result.netAssets.round())} $unit',
          accent),
      pdfRow(
          'پایان سال قمری (حول)', result.hawlComplete ? 'بله' : 'خیر', accent),
      if (result.totalCashZakat > 0)
        pdfRow('جمع زکات نقدی',
            '${NumberFormat.grouped(due(result.totalCashZakat))} $unit',
            accent,
            bold: true),
      if (result.zakatAmount > 0)
        pdfRow('زکات پول/طلا/نقره',
            '${NumberFormat.grouped(due(result.zakatAmount))} $unit',
            accent)
      else if (!result.meetsNisab)
        pdfRow('وضعیت', 'نصاب نرسیده است', accent, bold: true),
      if (!result.priceKnown)
        pdfRow('قیمت نصاب', 'وارد نشده — نصاب قابل محاسبه نیست', accent),
    ],
  ));

  if (result.grazingNote.isNotEmpty) {
    body.add(pdfSection(
      title: 'وضعیت زکات دام',
      accent: accent,
      children: [
        pdfRow('توضیح', result.grazingNote, accent),
        if (result.hasLivestockZakat)
          pdfRow('زکات واجب', result.livestockDescription, accent, bold: true),
      ],
    ));
  }

  if (result.hasAgricultureZakat) {
    body.add(pdfSection(
      title: 'زکات حبوبات (غلات و میوه‌ها)',
      accent: accent,
      children: [
        pdfRow('نصاب (5 وسق)',
            result.agricultureNisabReached ? 'رسیده' : 'نرسیده', accent),
        pdfRow(
            'میزان زکات', '${enDigits(result.agricultureRate * 100)}٪', accent),
        pdfRow('زکات (کیلوگرم)', enDigits(due(result.agricultureZakat)), accent,
            bold: true),
        if (result.agricultureZakatValue > 0)
          pdfRow('ارزش زکات',
              '${NumberFormat.grouped(due(result.agricultureZakatValue))} $unit',
              accent),
      ],
    ));
  }

  if (result.hasHoneyZakat) {
    body.add(pdfSection(
      title: 'زکات عسل',
      accent: accent,
      children: [
        pdfRow('نصاب (62 کیلوگرم)',
            result.honeyNisabReached ? 'رسیده' : 'نرسیده', accent),
        pdfRow('مقدار زکات',
            '${enDigits(due(result.honeyZakatKg))} کیلوگرم (10٪)', accent,
            bold: true),
      ],
    ));
  }

  if (result.hasHorsesZakat) {
    body.add(pdfSection(
      title: 'زکات اسب',
      accent: accent,
      children: [
        pdfRow(
            'نصاب (5 رأس)', result.horsesNisabMet ? 'رسیده' : 'نرسیده', accent),
        pdfRow('زکات (ارزش)',
            '${NumberFormat.grouped(due(result.horsesZakatValue))} $unit',
            accent,
            bold: true),
      ],
    ));
  }

  if (result.kanzZakat > 0) {
    body.add(pdfSection(
      title: 'زکات گنج (یک‌پنجم)',
      accent: accent,
      children: [
        pdfRow('مقدار یک‌پنجم',
            '${NumberFormat.grouped(due(result.kanzZakat))} $unit', accent,
            bold: true),
      ],
    ));
  }

  if (result.friendlyDebtZakat > 0 || result.uglyDebtZakat > 0) {
    body.add(pdfSection(
      title: 'زکات دین‌ها',
      accent: accent,
      children: [
        if (result.friendlyDebtZakat > 0)
          pdfRow('دین مرجو (قابل وصول) — هر سال با حول',
              '${NumberFormat.grouped(due(result.friendlyDebtZakat))} $unit',
              accent),
        if (result.uglyDebtZakat > 0)
          pdfRow('دین غیرمرجو (پس از وصول) — برای یک سال',
              '${NumberFormat.grouped(result.uglyDebtZakat.round())} $unit',
              accent),
      ],
    ));
  }

  if (result.mixtureApplied) {
    body.add(pdfSection(
      title: 'قاعدهٔ خلط (احتیاطی)',
      accent: accent,
      children: [
        pw.Text(
          result.mixtureDescription,
          textDirection: pw.TextDirection.rtl,
          style: const pw.TextStyle(
              fontSize: 10, color: PdfColor.fromInt(0xFF546E7A)),
        ),
      ],
    ));
  }

  body.add(pdfSection(
    title: 'توضیحات',
    accent: accent,
    children: [
      pw.Text(
        result.explanation,
        textDirection: pw.TextDirection.rtl,
        style: const pw.TextStyle(
            fontSize: 10, color: PdfColor.fromInt(0xFF546E7A)),
      ),
      if (result.breakdownLines.isNotEmpty) ...[
        pw.SizedBox(height: 4),
        for (final line in result.breakdownLines)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Text(
              '• $line',
              textDirection: pw.TextDirection.rtl,
              style: const pw.TextStyle(
                  fontSize: 9, color: PdfColor.fromInt(0xFF78909C)),
            ),
          ),
      ],
    ],
  ));

  return buildToolReportPdf(
    title: 'گزارش زکات',
    subtitle: 'محاسبهٔ زکات بر اساس احکام فقهی',
    accent: accent,
    body: body,
  );
}

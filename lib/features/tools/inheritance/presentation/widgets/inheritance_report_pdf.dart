import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:tawheeed/features/tools/inheritance/domain/blocked_heirs.dart';
import 'package:tawheeed/features/tools/inheritance/domain/inheritance_calculator.dart';
import 'package:tawheeed/features/tools/inheritance/domain/inheritance_share_text.dart';
import 'package:tawheeed/features/tools/shared/pdf_report_util.dart';

// ── Colours (must match the share card) ─────────────────────────────────
const PdfColor _ink = PdfColor.fromInt(0xFF2A2A2A);
const PdfColor _inkMuted = PdfColor.fromInt(0xFF4A4A4A);
const PdfColor _accent = PdfColor.fromInt(0xFF7B1FA2);
const PdfColor _accentDeep = PdfColor.fromInt(0xFF4A148C);
const PdfColor _track = PdfColor.fromInt(0xFFE7E7E7);
const PdfColor _boxBg = PdfColor.fromInt(0xFFEFEFEF);
const PdfColor _label = PdfColor.fromInt(0xFF6E6E6E);

// Pre-tinted fills (channels mixed toward white — never rely on the pdf
// package's alpha compositing, see [_tint]).
final PdfColor _chipBg = _mixWhite(const PdfColor.fromInt(0xFF7B1FA2), 0.82);
final PdfColor _estateBg = _mixWhite(const PdfColor.fromInt(0xFF7B1FA2), 0.93);

/// Lightens [c] toward white by [t] (0..1). NOTE: the pdf package's own alpha
/// compositing painted note-boxes as SOLID dark rectangles (the alpha channel
/// is ignored on some fill paths — a 6% purple fill rendered as 0.29 grey),
/// hiding the text inside. Mixing channels toward white is deterministic and
/// always legible.
PdfColor _mixWhite(PdfColor c, double t) => PdfColor(
      c.red + (1 - c.red) * t,
      c.green + (1 - c.green) * t,
      c.blue + (1 - c.blue) * t,
    );

PdfColor _noteBg(PdfColor accent) => _mixWhite(accent, 0.90);

/// Formats an amount with Latin digits and the Persian thousand separator
/// (e.g. `450000` → «450٬000») followed by the unit, mirroring the share card.
///
/// بدون واحد، عدد در PDF بی‌معناست: با پشتیبانی چند واحد پول، «2,125,000»
/// نمی‌گوید تومان است یا دلار.
String _money(double v, [String unit = '']) {
  final s = v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2);
  final parts = s.split('.');
  final digits = parts[0].split('').reversed.toList();
  final grouped = <String>[];
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && i % 3 == 0) grouped.add('٬');
    grouped.add(digits[i]);
  }
  final body = grouped.reversed.join();
  final amount = parts.length > 1 ? '$body.${parts[1]}' : body;
  return unit.isEmpty ? amount : '$amount $unit';
}

/// Builds a printable A4 PDF report for an inheritance calculation,
/// styled to match the purple share card: issue banner with بسم الله and
/// chips, an estate summary box, an اصل مسأله stats strip, per-heir share
/// rows with fraction + amount + proportional bar, and the توحید logo footer.
Future<Uint8List> buildInheritanceReportPdf({
  required InheritanceResult result,
  required double estate,
  String unit = 'تومان',
  List<BlockedHeir>? blockedHeirs,
  String? namedProblem,
}) async {
  final reg = await pdfVazirFont(bold: false);
  final bold = await pdfVazirFont(bold: true);
  final logo = await pdfLogoBytes();

  final rows = result.shares
      .where((s) => s.shareType != ShareType.mandatoryWill)
      .toList();

  // Display-only Hare rounding: printed percents add to exactly 100 and
  // printed amounts to exactly the sum of the listed shares; independent
  // per-row rounding can otherwise show 99%/101% or a unit short.
  final rowAmounts = [for (final s in rows) s.amount];
  final rowTotal = rowAmounts.fold<double>(0.0, (a, b) => a + b);
  final displayAmounts = hareAllocate(rowAmounts, rowTotal);
  final percents = harePercents(rowAmounts);

  // ── Helper widgets ────────────────────────────────────────────────────
  pw.Widget banner() {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 18),
      decoration: pw.BoxDecoration(
        gradient: const pw.LinearGradient(
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
          colors: <PdfColor>[_accent, _accentDeep],
        ),
        borderRadius: pw.BorderRadius.circular(16),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
            textDirection: pw.TextDirection.rtl,
            style: pw.TextStyle(
              font: reg,
              fontSize: 12,
              color: PdfColors.white,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'نتایج تقسیم میراث',
            textDirection: pw.TextDirection.rtl,
            style:
                pw.TextStyle(font: bold, fontSize: 19, color: PdfColors.white),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              _chip(madhabLabel(result.madhab), font: reg),
              pw.SizedBox(width: 6),
              _chip(result.methodLabel, font: reg),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget estateBox() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _estateBg,
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Column(
        children: [
          _kv('ترکه اولیه', _money(estate, unit), bold),
          pw.SizedBox(height: 3),
          _kv(
            result.mandatoryWillAmount > 0
                ? 'ترکه پس از هزینه، دیون و وصیت عادی'
                : 'ترکه قابل تقسیم',
            _money(result.netEstate, unit),
            bold,
          ),
          if (result.mandatoryWillAmount > 0) ...[
            pw.SizedBox(height: 3),
            _kv('وصیت واجبه (کسر شده)', _money(result.mandatoryWillAmount, unit),
                bold),
            pw.SizedBox(height: 3),
            _kv('مانده برای وراث اصلی', _money(result.estateForMainHeirs, unit),
                bold),
          ],
        ],
      ),
    );
  }

  pw.Widget statsStrip() {
    return pw.Row(
      children: [
        pw.Expanded(
            child: _statBox('اصل مسأله', enDigits(result.baseAsl),
                font: reg, bold: bold)),
        if (result.baseAsl != result.correctedAsl) ...[
          pw.SizedBox(width: 6),
          pw.Expanded(
            child: _statBox(
              result.baseAsl < result.correctedAsl ? 'پس از عول' : 'پس از رد',
              enDigits(result.correctedAsl),
              font: reg,
              bold: bold,
            ),
          ),
        ],
        pw.SizedBox(width: 6),
        pw.Expanded(
          child: _statBox('جمع سهمها', _money(result.totalAllocated, unit),
              font: reg, bold: bold),
        ),
      ],
    );
  }

  pw.Widget shareRow(
    InheritanceShare s, {
    required double displayAmount,
    required int percent,
  }) {
    final c = _shareColor(s.shareType);
    final ratio = result.totalAllocated > 0
        ? (s.amount / result.totalAllocated).clamp(0.0, 1.0)
        : 0.0;
    final prefix = s.count > 1
        ? '${heirLabel(s.type)} (${enDigits(s.count)} نفر)'
        : heirLabel(s.type);
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 3.5,
                height: 30,
                decoration: pw.BoxDecoration(
                  color: c,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(prefix,
                            textDirection: pw.TextDirection.rtl,
                            style: pw.TextStyle(
                                font: bold, fontSize: 11, color: _ink)),
                        pw.Text('$percent٪',
                            textDirection: pw.TextDirection.rtl,
                            style: pw.TextStyle(
                                font: bold, fontSize: 10, color: _inkMuted)),
                      ],
                    ),
                    pw.SizedBox(height: 3),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(s.fraction.toArString(),
                            textDirection: pw.TextDirection.rtl,
                            style: pw.TextStyle(
                                font: reg, fontSize: 10, color: _inkMuted)),
                        pw.Text(_money(displayAmount, unit),
                            textDirection: pw.TextDirection.rtl,
                            style: pw.TextStyle(
                                font: bold, fontSize: 10, color: _ink)),
                      ],
                    ),
                    pw.SizedBox(height: 5),
                    pw.ClipRRect(
                      horizontalRadius: 3,
                      verticalRadius: 3,
                      child: pw.Row(
                        children: [
                          pw.Expanded(
                            flex: (ratio * 1000).round().clamp(0, 1000),
                            child: pw.Container(height: 6, color: c),
                          ),
                          pw.Expanded(
                            flex:
                                (1000 - (ratio * 1000).round()).clamp(0, 1000),
                            child: pw.Container(height: 6, color: _track),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (s.reason.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Padding(
              padding: const pw.EdgeInsets.only(right: 12),
              child: pw.Text(s.reason,
                  textDirection: pw.TextDirection.rtl,
                  style:
                      pw.TextStyle(font: reg, fontSize: 9, color: _inkMuted)),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget sectionTitle(String title) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12, bottom: 8),
      child: pw.Row(
        children: [
          pw.Container(width: 3, height: 14, color: _accent),
          pw.SizedBox(width: 6),
          pw.Text(title,
              textDirection: pw.TextDirection.rtl,
              style: pw.TextStyle(font: bold, fontSize: 13, color: _ink)),
        ],
      ),
    );
  }

  // ── Document ──────────────────────────────────────────────────────────
  final doc = pw.Document(
    title: 'گزارش تقسیم میراث',
    author: 'توحید',
    theme: pw.ThemeData.withFont(base: reg, bold: bold),
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 40),
      footer: (ctx) => _pdfFooter(ctx.pageNumber, bold, logo),
      build: (ctx) => [
        banner(),
        pw.SizedBox(height: 12),
        estateBox(),
        pw.SizedBox(height: 12),
        statsStrip(),
        sectionTitle('سهم هر وارث'),
        for (var i = 0; i < rows.length; i++)
          shareRow(rows[i],
              displayAmount: displayAmounts[i], percent: percents[i]),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('جمع سهمها',
                textDirection: pw.TextDirection.rtl,
                style: pw.TextStyle(font: bold, fontSize: 11, color: _ink)),
            pw.Text(_money(result.totalAllocated, unit),
                textDirection: pw.TextDirection.rtl,
                style: pw.TextStyle(font: bold, fontSize: 11, color: _accent)),
          ],
        ),
        if (namedProblem != null) ...[
          sectionTitle('مسألهٔ مشهور'),
          _noteBox(namedProblem, accent: _accent, font: reg),
        ],
        if (result.mandatoryWillAmount > 0) ...[
          sectionTitle('وصیت واجبه (نوههای یتیم)'),
          _noteBox('مبلغ وصیت واجبه: ${_money(result.mandatoryWillAmount, unit)}',
              accent: _accent, font: reg),
        ],
        if (blockedHeirs != null && blockedHeirs.isNotEmpty) ...[
          sectionTitle('محجوبان (محرومشدگان از ارث)'),
          for (final h in blockedHeirs)
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(width: 3, height: 14, color: _inkMuted),
                  pw.SizedBox(width: 6),
                  pw.Expanded(
                    child: pw.Text(
                      '${heirLabel(h.type)} (${enDigits(h.count)}) — ${h.reason}',
                      textDirection: pw.TextDirection.rtl,
                      style: pw.TextStyle(font: reg, fontSize: 10, color: _ink),
                    ),
                  ),
                ],
              ),
            ),
        ],
        if (result.warnings.isNotEmpty || result.notes.isNotEmpty) ...[
          sectionTitle('توضیحات'),
          for (final w in result.warnings)
            _noteBox('• $w',
                accent: const PdfColor.fromInt(0xFFC62828), font: reg),
          for (final n in result.notes)
            _noteBox('• $n', accent: _inkMuted, font: reg),
        ],
      ],
    ),
  );

  return doc.save();
}

// ── Private helpers ───────────────────────────────────────────────────────

pw.Widget _chip(String text, {required pw.Font font}) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: pw.BoxDecoration(
      color: _chipBg,
      borderRadius: pw.BorderRadius.circular(10),
    ),
    child: pw.Text(text,
        textDirection: pw.TextDirection.rtl,
        style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.white)),
  );
}

pw.Widget _kv(String label, String value, pw.Font bold) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(label,
          textDirection: pw.TextDirection.rtl,
          style: pw.TextStyle(font: bold, fontSize: 10, color: _label)),
      pw.Text(value,
          textDirection: pw.TextDirection.rtl,
          style: pw.TextStyle(font: bold, fontSize: 11, color: _ink)),
    ],
  );
}

pw.Widget _statBox(String label, String value,
    {required pw.Font font, required pw.Font bold}) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
    decoration: pw.BoxDecoration(
      color: _boxBg,
      borderRadius: pw.BorderRadius.circular(10),
    ),
    child: pw.Column(
      children: [
        pw.Text(label,
            textDirection: pw.TextDirection.rtl,
            style: pw.TextStyle(font: font, fontSize: 8, color: _label)),
        pw.SizedBox(height: 2),
        pw.Text(value,
            textDirection: pw.TextDirection.rtl,
            style: pw.TextStyle(font: bold, fontSize: 12, color: _ink)),
      ],
    ),
  );
}

pw.Widget _noteBox(String text,
    {required PdfColor accent, required pw.Font font}) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 6),
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: pw.BoxDecoration(
      color: _noteBg(accent),
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Text(text,
        textDirection: pw.TextDirection.rtl,
        style: pw.TextStyle(font: font, fontSize: 10, color: accent)),
  );
}

PdfColor _shareColor(ShareType t) {
  switch (t) {
    case ShareType.fard:
      return _accent;
    case ShareType.asaba:
      return const PdfColor.fromInt(0xFF00897B);
    case ShareType.radd:
      return const PdfColor.fromInt(0xFF1E88E5);
    case ShareType.hajb:
      return const PdfColor.fromInt(0xFF9E9E9E);
    case ShareType.mandatoryWill:
      return const PdfColor.fromInt(0xFF5D4037);
  }
}

pw.Widget _pdfFooter(int page, pw.Font bold, Uint8List logo) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Row(
        children: [
          pw.ClipOval(
            child: pw.Image(
              pw.MemoryImage(logo),
              width: 20,
              height: 20,
              fit: pw.BoxFit.cover,
            ),
          ),
          pw.SizedBox(width: 6),
          pw.Text('برنامهٔ جامع توحید',
              textDirection: pw.TextDirection.rtl,
              style: pw.TextStyle(font: bold, fontSize: 8, color: _inkMuted)),
        ],
      ),
      pw.Text('صفحه ${enDigits(page)}',
          textDirection: pw.TextDirection.rtl,
          style: pw.TextStyle(font: bold, fontSize: 8, color: _inkMuted)),
    ],
  );
}

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/core/constants/date_constants.dart';
import 'package:tawheeed/features/hifz/domain/entities/hafiz_model.dart';
import 'package:tawheeed/features/hifz/domain/hifz_report.dart';

const PdfColor _ink = PdfColor.fromInt(0xFF263238);
const PdfColor _inkMuted = PdfColor.fromInt(0xFF78909C);
const PdfColor _paper = PdfColor.fromInt(0xFFFDFBF7);

/// PdfColor with alpha (0..1).
PdfColor _a(PdfColor c, double alpha) =>
    PdfColor(c.red, c.green, c.blue, alpha);

final Map<bool, Future<pw.Font>> _fontCache = {};

/// Loads Vazirmatn (regular/bold) once and reuses it, so Persian text
/// renders correctly in the PDF (Helvetica has no Arabic-script glyphs).
Future<pw.Font> _vazir({required bool bold}) => _fontCache[bold] ??= () async {
      final data = await rootBundle.load(
        bold
            ? 'assets/fonts/Vazirmatn-Bold.ttf'
            : 'assets/fonts/Vazirmatn-Regular.ttf',
      );
      return pw.Font.ttf(data);
    }();

Uint8List? _logoCache;

/// Loads the app logo (assets/logo2.png) once and reuses it, so it can be
/// embedded in the PDF header as a circular image.
Future<Uint8List> _logoBytes() async {
  if (_logoCache != null) return _logoCache!;
  final data = await rootBundle.load('assets/logo2.png');
  _logoCache = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  return _logoCache!;
}

String _en(int n) => '$n';

/// 0..1 fraction -> flex units (0..1000) for pdf Expanded bars.
int _pct(double f) => (f.clamp(0.0, 1.0) * 1000).round();

/// Yearly bar fraction, keeping a tiny visible sliver for non-zero values.
double _barFrac(int pages, int maxPages) =>
    pages == 0 ? 0 : (pages / maxPages).clamp(0.02, 1.0);

/// Builds a real, multi-page printable PDF report for the hifz feature.
///
/// The caller passes the ALREADY-COMPUTED period/year reports (the same
/// objects shown on screen) so the PDF always matches what the user sees.
/// pw.MultiPage paginates automatically when content overflows a page.
///
/// NOTE: `pw.Row` has no RTL support; RTL ordering is achieved by listing
/// children in the order they should appear from the right.
Future<Uint8List> buildHifzReportPdf({
  required HafizModel hafiz,
  required String periodLabel,
  required HifzPeriodReport? monthReport,
  required HifzYearReport? yearReport,
  Map<int, int>? pagesByDay,
  int? dayCount,
}) async {
  final accent = PdfColor.fromHex(hafiz.colorHex.replaceFirst('#', ''));
  final isMonth = monthReport != null;
  final logo = await _logoBytes();

  pw.Widget header() => pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: pw.BoxDecoration(
          color: accent,
          borderRadius: pw.BorderRadius.circular(10),
        ),
        child: pw.Row(
          children: [
            pw.Container(
              width: 34,
              height: 34,
              decoration: const pw.BoxDecoration(
                color: PdfColors.white,
                shape: pw.BoxShape.circle,
              ),
              child: pw.ClipRRect(
                horizontalRadius: 17,
                verticalRadius: 17,
                child: pw.Image(
                  pw.MemoryImage(logo),
                  fit: pw.BoxFit.cover,
                ),
              ),
            ),
            pw.SizedBox(width: 10),
            pw.Container(
              width: 30,
              height: 30,
              alignment: pw.Alignment.center,
              decoration: const pw.BoxDecoration(
                color: PdfColors.white,
                shape: pw.BoxShape.circle,
              ),
              child: pw.Text(
                hafiz.name.isEmpty ? '؟' : hafiz.name.substring(0, 1),
                style: pw.TextStyle(
                  color: accent,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('گزارش حفظ قرآن',
                      style: const pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold)),
                  pw.Text('${hafiz.name} — $periodLabel',
                      style: pw.TextStyle(
                          color: _a(PdfColors.white, 0.85), fontSize: 10)),
                ],
              ),
            ),
            pw.SizedBox(width: 10),
            pw.Text('﴿حفظ﴾',
                style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 12)),
          ],
        ),
      );

  pw.Widget sectionTitle(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6, top: 4),
        child: pw.Text(t,
            style: const pw.TextStyle(
                color: _ink, fontSize: 11, fontWeight: pw.FontWeight.bold)),
      );

  pw.Widget statsRow(HifzPeriodReport r) => pw.Row(
        children: [
          _statCard(accent, 'حفظ جدید', '${_en(r.lessonPages)} صفحه',
              '${_en(r.lessonCount)} درس'),
          pw.SizedBox(width: 8),
          _statCard(accent, 'سبق', _en(r.sabaqCount), ''),
          pw.SizedBox(width: 8),
          _statCard(accent, 'مراجعه', _en(r.murajaahCount), ''),
        ],
      );

  pw.Widget qualityBlock(HifzPeriodReport r) {
    pw.Widget row(String label, QualityCounts q) => pw.Row(
          children: [
            _qualityChip(
                'عالی', q.excellent, const PdfColor.fromInt(0xFF2E7D32)),
            pw.SizedBox(width: 5),
            _qualityChip('متوسط', q.medium, const PdfColor.fromInt(0xFFF9A825)),
            pw.SizedBox(width: 5),
            _qualityChip('ضعیف', q.weak, const PdfColor.fromInt(0xFFE53935)),
            pw.SizedBox(width: 8),
            pw.SizedBox(
              width: 70,
              child: pw.Text(label,
                  style: const pw.TextStyle(color: _ink, fontSize: 10)),
            ),
          ],
        );

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _paper,
        border: pw.Border.all(color: _a(_inkMuted, 0.3)),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('کیفیت مرورها',
              style: const pw.TextStyle(
                  color: _ink, fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          row('سبق', r.sabaqQuality),
          pw.SizedBox(height: 4),
          row('مراجعه', r.murajaahQuality),
        ],
      ),
    );
  }

  pw.Widget progressBlock(HifzPeriodReport r) {
    final frac = r.progressFraction.clamp(0.0, 1.0);
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _paper,
        border: pw.Border.all(color: _a(_inkMuted, 0.3)),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('پیشرفت کل (${_en(r.cumulativePages)} از ${_en(604)} صفحه)',
              style: const pw.TextStyle(
                  color: _ink, fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.ClipRRect(
            horizontalRadius: 4,
            verticalRadius: 4,
            child: pw.Container(
              height: 10,
              color: _a(_inkMuted, 0.15),
              child: pw.Row(
                children: [
                  if (frac < 1)
                    pw.Expanded(
                      flex: 1000 - _pct(frac),
                      child: pw.Container(height: 10, color: _a(_inkMuted, 0)),
                    ),
                  if (frac > 0)
                    pw.Expanded(
                      flex: _pct(frac),
                      child: pw.Container(height: 10, color: accent),
                    ),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '${(frac * 100).toStringAsFixed(1)}٪ · رشد این دوره: ${_en(r.periodGrowthPages)} صفحه',
            style: const pw.TextStyle(color: _inkMuted, fontSize: 9),
          ),
        ],
      ),
    );
  }

  final doc = pw.Document(
    title: 'گزارش حفظ قرآن — ${hafiz.name}',
    author: 'توحید',
    subject: 'گزارش حفظ، سبق و مراجعه',
  );

  if (isMonth) {
    final r = monthReport;
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(16),
        theme: pw.ThemeData.withFont(
          base: await _vazir(bold: false),
          bold: await _vazir(bold: true),
        ),
        build: (ctx) => [
          header(),
          pw.SizedBox(height: 10),
          sectionTitle('آمار دوره'),
          statsRow(r),
          pw.SizedBox(height: 8),
          qualityBlock(r),
          pw.SizedBox(height: 8),
          progressBlock(r),
          pw.SizedBox(height: 8),
          sectionTitle('توزیع روزانهٔ حفظ'),
          _dayDistributionTable(accent, pagesByDay ?? const {}, dayCount ?? 30),
          pw.SizedBox(height: 10),
          pw.Text('تولید شده در ${_generatedAt()}',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(color: _inkMuted, fontSize: 9)),
        ],
      ),
    );
  } else {
    final yr = yearReport!;
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(16),
        theme: pw.ThemeData.withFont(
          base: await _vazir(bold: false),
          bold: await _vazir(bold: true),
        ),
        build: (ctx) => [
          header(),
          pw.SizedBox(height: 10),
          sectionTitle('آمار سالانه'),
          statsRow(yr.total),
          pw.SizedBox(height: 8),
          qualityBlock(yr.total),
          pw.SizedBox(height: 8),
          progressBlock(yr.total),
          pw.SizedBox(height: 8),
          sectionTitle('به تفکیک ماه'),
          _yearlyTable(accent, yr),
          pw.SizedBox(height: 12),
          sectionTitle('روند رشد صفحات تجمعی'),
          _trendChart(accent, yr),
          pw.SizedBox(height: 10),
          pw.Text('تولید شده در ${_generatedAt()}',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(color: _inkMuted, fontSize: 9)),
        ],
      ),
    );
  }

  return doc.save();
}

/// Saves [bytes] to a temp PDF and opens the system share sheet.
Future<void> shareHifzReportPdf({
  required Uint8List bytes,
  required String fileName,
  String? text,
}) async {
  final dir = await getTemporaryDirectory();
  final file =
      await File('${dir.path}/$fileName').writeAsBytes(bytes, flush: true);
  await SharePlus.instance.share(ShareParams(
    files: [XFile(file.path, mimeType: 'application/pdf')],
    text: text,
  ));
}

String _generatedAt() {
  final j = Jalali.now();
  return '${_en(j.day)} ${DateConstants.persianMonths[j.month - 1]} ${_en(j.year)}';
}

// ── Building blocks ─────────────────────────────────────────────────

pw.Widget _statCard(PdfColor accent, String label, String value, String sub) {
  return pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: _paper,
        border: pw.Border.all(color: _a(_inkMuted, 0.3)),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            width: 22,
            height: 22,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: _a(accent, 0.12),
              shape: pw.BoxShape.circle,
            ),
            child: pw.Text(label.substring(0, 1),
                style: pw.TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 4),
          pw.Text(value,
              style: const pw.TextStyle(
                  color: _ink, fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.Text(label,
              style: const pw.TextStyle(color: _inkMuted, fontSize: 9)),
          if (sub.isNotEmpty)
            pw.Text(sub,
                style: const pw.TextStyle(color: _inkMuted, fontSize: 8)),
        ],
      ),
    ),
  );
}

pw.Widget _qualityChip(String label, int count, PdfColor color) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: pw.BoxDecoration(
      color: _a(color, 0.12),
      borderRadius: pw.BorderRadius.circular(6),
      border: pw.Border.all(color: _a(color, 0.5)),
    ),
    child: pw.Text('$label: ${_en(count)}',
        style: pw.TextStyle(color: color, fontSize: 9)),
  );
}

/// Simplified weekly bar chart: 7 bars for each week, with day labels.
pw.Widget _dayDistributionTable(
    PdfColor accent, Map<int, int> pagesByDay, int dayCount) {
  // Group pages by week (Sat–Fri, 7-day buckets).
  final weekTotals = <int>[];
  final weekLabels = <String>[];
  for (var w = 0; w * 7 < dayCount; w++) {
    var total = 0;
    final startDay = w * 7 + 1;
    final endDay = (startDay + 6).clamp(1, dayCount);
    final label = '${_en(startDay)}–${_en(endDay)}';
    for (var d = startDay; d <= endDay; d++) {
      total += pagesByDay[d] ?? 0;
    }
    weekTotals.add(total);
    weekLabels.add(label);
  }
  final maxWeek =
      weekTotals.isEmpty ? 1 : weekTotals.reduce((a, b) => a > b ? a : b);
  if (maxWeek == 0) return pw.SizedBox();

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('پراکندگی روزانه',
          style: const pw.TextStyle(
              color: _ink, fontSize: 10, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      for (var w = 0; w < weekTotals.length; w++)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Row(
            children: [
              pw.SizedBox(
                width: 72,
                child: pw.Text(weekLabels[w],
                    style: const pw.TextStyle(color: _inkMuted, fontSize: 8)),
              ),
              pw.SizedBox(width: 4),
              pw.Expanded(
                child: pw.ClipRRect(
                  horizontalRadius: 3,
                  verticalRadius: 3,
                  child: pw.Container(
                    height: 14,
                    color: _a(_inkMuted, 0.10),
                    child: pw.Row(children: [
                      pw.Expanded(
                        flex: 1000 - _pct(_barFrac(weekTotals[w], maxWeek)),
                        child: pw.Container(height: 14),
                      ),
                      pw.Expanded(
                        flex: _pct(_barFrac(weekTotals[w], maxWeek)),
                        child: pw.Container(height: 14, color: accent),
                      ),
                    ]),
                  ),
                ),
              ),
              pw.SizedBox(width: 6),
              pw.SizedBox(
                width: 48,
                child: pw.Text('${_en(weekTotals[w])} ص',
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(color: accent, fontSize: 9)),
              ),
            ],
          ),
        ),
    ],
  );
}

pw.Widget _yearlyTable(PdfColor accent, HifzYearReport year) {
  var maxPages = 1;
  for (final m in year.months) {
    if (m.report.lessonPages > maxPages) maxPages = m.report.lessonPages;
  }
  return pw.Column(
    children: [
      for (final m in year.months)
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
          child: pw.Row(
            children: [
              pw.SizedBox(
                width: 96,
                child: pw.Text(
                  '${_en(m.report.lessonPages)} صفحه · س ${_en(m.report.sabaqCount)} · م ${_en(m.report.murajaahCount)}',
                  style: const pw.TextStyle(color: _inkMuted, fontSize: 8),
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Expanded(
                child: pw.ClipRRect(
                  horizontalRadius: 3,
                  verticalRadius: 3,
                  child: pw.Container(
                    height: 12,
                    color: _a(_inkMuted, 0.12),
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 1000 -
                              _pct(_barFrac(m.report.lessonPages, maxPages)),
                          child:
                              pw.Container(height: 12, color: _a(_inkMuted, 0)),
                        ),
                        pw.Expanded(
                          flex: _pct(_barFrac(m.report.lessonPages, maxPages)),
                          child: pw.Container(height: 12, color: accent),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              pw.SizedBox(width: 6),
              pw.SizedBox(
                width: 62,
                child: pw.Text(DateConstants.persianMonths[m.jMonth - 1],
                    textAlign: pw.TextAlign.right,
                    style: const pw.TextStyle(color: _ink, fontSize: 9)),
              ),
            ],
          ),
        ),
    ],
  );
}

pw.Widget _trendChart(PdfColor accent, HifzYearReport year) {
  final trend = year.inYearCumulativeTrend;
  final maxValue = trend.isEmpty
      ? 1.0
      : trend
          .reduce((a, b) => a > b ? a : b)
          .toDouble()
          .clamp(1.0, 1 << 31)
          .toDouble();
  final values = <pw.PointChartValue>[
    for (var i = 0; i < trend.length; i++)
      pw.PointChartValue(i.toDouble(), trend[i].toDouble()),
  ];
  final monthNames = [
    for (var i = 0; i < 12; i++)
      DateConstants.persianMonths[i].length <= 4
          ? DateConstants.persianMonths[i]
          : DateConstants.persianMonths[i].substring(0, 4),
  ];

  return pw.Container(
    height: 130,
    decoration: pw.BoxDecoration(
      color: _paper,
      border: pw.Border.all(color: _a(accent, 0.3)),
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Chart(
      grid: pw.CartesianGrid(
        xAxis: pw.FixedAxis.fromStrings(
          monthNames,
          divisions: true,
          ticks: true,
          color: _a(_inkMuted, 0.5),
          textStyle: const pw.TextStyle(color: _inkMuted, fontSize: 8),
        ),
        yAxis: pw.FixedAxis<double>(
          [0, maxValue / 2, maxValue],
          divisions: true,
          ticks: true,
          format: (v) => _en(v.round()),
          color: _a(_inkMuted, 0.5),
          textStyle: const pw.TextStyle(color: _inkMuted, fontSize: 8),
        ),
      ),
      datasets: [
        pw.LineDataSet<pw.PointChartValue>(
          data: values,
          color: accent,
          lineColor: accent,
          pointSize: 2.5,
          drawSurface: true,
          surfaceColor: accent,
          surfaceOpacity: 0.12,
        ),
      ],
    ),
  );
}

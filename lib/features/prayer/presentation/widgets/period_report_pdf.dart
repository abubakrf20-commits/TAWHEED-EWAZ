import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/features/prayer/presentation/providers/period_provider.dart';
import 'package:tawheeed/features/tools/shared/pdf_report_util.dart';

/// Builds and shares an A4 PDF report of the user's monthly-cycle history.
Future<void> buildAndSharePeriodReport(Period notifier,
    {int hijriOffset = 2}) async {
  final body = <pw.Widget>[];

  // ── وضعیت امروز ────────────────────────────────────────────────────────────
  final today = notifier.getTodayStatus();
  final todayMsg = (today['message'] as String?) ?? '—';
  body.add(pdfSection(
    title: 'وضعیت امروز',
    children: [pdfRow('وضعیت', todayMsg, _pink)],
    accent: _pink,
  ));

  // ── آمار چرخه ──────────────────────────────────────────────────────────────
  final stats = notifier.cycleStats();
  if (stats != null) {
    body.add(pdfSection(
      title: 'آمار چرخه (فقط حیض)',
      accent: _pink,
      children: [
        pdfRow('میانگین طول چرخه',
            '${enDigits(stats.averageCycle.round())} روز', _pink,
            bold: true),
        pdfRow('میانگین طول عادت',
            '${enDigits(stats.averagePeriod.round())} روز', _pink),
        if (stats.shortestCycle != null)
          pdfRow('کوتاه‌ترین چرخه', '${enDigits(stats.shortestCycle!)} روز',
              _pink),
        if (stats.longestCycle != null)
          pdfRow(
              'بلندترین چرخه', '${enDigits(stats.longestCycle!)} روز', _pink),
        if (stats.regularity != null)
          pdfRow('انتظام سیکل', periodRegularityLabel(stats.regularity), _pink),
      ],
    ));
  }

  // ── بارداری ────────────────────────────────────────────────────────────────
  final state = notifier.currentSnapshot;
  if (state != null && state.isPregnant) {
    final due = state.pregnancyDueDate;
    body.add(pdfSection(
      title: 'بارداری',
      accent: _pink,
      children: [
        pdfRow('وضعیت', 'فعال — پیش‌بینی چرخه متوقف است', _pink, bold: true),
        if (due != null) pdfRow('تاریخ تخمینی زایمان', _faJalali(due), _pink),
      ],
    ));
  }

  // ── روزه‌های قضا ───────────────────────────────────────────────────────────
  if (state != null && (state.qadaFastsOwed > 0 || state.qadaFastsDone > 0)) {
    body.add(pdfSection(
      title: 'روزه‌های قضا',
      accent: _pink,
      children: [
        pdfRow('واجب', '${enDigits(state.qadaFastsOwed)} روز', _pink),
        pdfRow('ادا شده', '${enDigits(state.qadaFastsDone)} روز', _pink),
        pdfRow('باقی‌مانده', '${enDigits(state.qadaFastsRemaining)} روز', _pink,
            bold: true),
      ],
    ));
  }

  // ── قضای روزهٔ رمضان ───────────────────────────────────────────────────────
  final ramadan =
      notifier.getRamadanSummary(DateTime.now().year, hijriOffset: hijriOffset);
  final missed = (ramadan['missedDays'] as int?) ?? 0;
  if (missed > 0) {
    body.add(pdfSection(
      title: 'روزهای حیض در ماه رمضان امسال',
      accent: _pink,
      children: [
        pdfRow('تعداد روزهای قضا بر اساس ثبت‌شده', '${enDigits(missed)} روز',
            _pink,
            bold: true),
      ],
    ));
  }

  // ── تاریخچه ────────────────────────────────────────────────────────────────
  final history = notifier.getHistorySummary();
  if (history.isNotEmpty) {
    final rows = <pw.Widget>[];
    for (final h in history) {
      final typeLabel = h['typeLabel'] as String;
      final range = '${_faJalali(h['startDate'] as DateTime)}  تا  '
          '${h['endDate'] == null ? 'اکنون' : _faJalali(h['endDate'] as DateTime)}';
      final length = '${enDigits(h['periodDays'] as int)} روز';
      final flow = h['flowLabel'] as String?;
      final istihadha = h['istihadhaTypeLabel'] as String?;
      rows.add(pdfRow(
          typeLabel == 'استحاضه' ? istihadha ?? typeLabel : typeLabel,
          '$range — $length${flow != null ? ' (شدت: $flow)' : ''}',
          _pink));
    }
    body.add(pdfSection(
      title: 'تاریخچهٔ آخرین دوره‌ها',
      accent: _pink,
      children: rows,
    ));
  }

  // ── روند اخیر چرخه ─────────────────────────────────────────────────────────
  final gaps = notifier.recentCycleGaps();
  if (gaps.length >= 2) {
    body.add(pdfSection(
      title: 'روند اخیر فاصلهٔ چرخه‌ها',
      accent: _pink,
      children: [
        pdfRow('فاصله‌های ثبت‌شده (روز)', gaps.map(enDigits).join('، '), _pink),
        pdfRow(
            'میانگین این فاصله‌ها',
            '${enDigits((gaps.reduce((a, b) => a + b) / gaps.length).round())} روز',
            _pink),
      ],
    ));
  }

  // ── پیش‌بینی بعدی ──────────────────────────────────────────────────────────
  final prediction = notifier.predict();
  if (prediction != null && !(state?.isPregnant ?? false)) {
    body.add(pdfSection(
      title: 'پیش‌بینی',
      accent: _pink,
      children: [
        pdfRow('شروع عادت بعدی', _faJalali(prediction.nextPeriodStart), _pink,
            bold: true),
        pdfRow('تا شروع دورهٔ بعدی',
            '${enDigits(prediction.daysUntilNextPeriod)} روز', _pink),
      ],
    ));
  }

  final bytes = await buildToolReportPdf(
    title: 'گزارش پریودی',
    subtitle: 'خلاصهٔ چرخه، تاریخچه و احکام مرتبط',
    accent: _pink,
    body: body,
  );
  await shareToolReportPdf(bytes: bytes, fileName: 'period_report.pdf');
}

const PdfColor _pink = PdfColor.fromInt(0xFFEC407A);

String _faJalali(DateTime date) {
  final j = Jalali.fromDateTime(date);
  return '${enDigits(j.year)}/${enDigits(j.month)}/${enDigits(j.day)}';
}

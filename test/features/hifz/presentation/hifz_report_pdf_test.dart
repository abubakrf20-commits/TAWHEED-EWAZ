import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
// Binding must be initialized so rootBundle can load the Vazirmatn fonts
// that the PDF builder embeds for Persian text.
import 'package:flutter_test/flutter_test.dart' as ft
    show TestWidgetsFlutterBinding;
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/features/hifz/domain/entities/hafiz_model.dart';
import 'package:tawheeed/features/hifz/domain/entities/hifz_lesson_model.dart';
import 'package:tawheeed/features/hifz/domain/entities/hifz_review_model.dart';
import 'package:tawheeed/features/hifz/domain/hifz_report.dart';
import 'package:tawheeed/features/hifz/presentation/widgets/hifz_report_pdf.dart';

HafizModel _hafiz() => HafizModel(
      id: 'h1',
      name: 'محمد',
      colorHex: '#00695C',
      createdAt: DateTime(2025),
    );

List<HifzLessonModel> _lessons() {
  final now = DateTime.now();
  return [
    HifzLessonModel(
      id: 'l1',
      hafizId: 'h1',
      date: now.subtract(const Duration(days: 1)),
      surahFrom: 2,
      ayahFrom: 1,
      surahTo: 2,
      ayahTo: 6,
      pages: 2,
      createdAt: now.subtract(const Duration(days: 1)),
    ),
    HifzLessonModel(
      id: 'l2',
      hafizId: 'h1',
      date: now.subtract(const Duration(days: 40)),
      surahFrom: 18,
      ayahFrom: 1,
      surahTo: 18,
      ayahTo: 5,
      pages: 1,
      createdAt: now.subtract(const Duration(days: 40)),
    ),
  ];
}

List<HifzReviewModel> _reviews() {
  final now = DateTime.now();
  return [
    HifzReviewModel(
      id: 'r1',
      hafizId: 'h1',
      date: now.subtract(const Duration(days: 2)),
      type: ReviewType.sabaq,
      surahFrom: 2,
      ayahFrom: 1,
      surahTo: 2,
      ayahTo: 6,
      pages: 2,
      quality: ReviewQuality.excellent,
      createdAt: now.subtract(const Duration(days: 2)),
    ),
    HifzReviewModel(
      id: 'r2',
      hafizId: 'h1',
      date: now.subtract(const Duration(days: 3)),
      type: ReviewType.murajaah,
      surahFrom: 1,
      ayahFrom: 1,
      surahTo: 2,
      ayahTo: 5,
      pages: 3,
      quality: ReviewQuality.medium,
      createdAt: now.subtract(const Duration(days: 3)),
    ),
  ];
}

void main() {
  ft.TestWidgetsFlutterBinding.ensureInitialized();
  final j = Jalali.now();
  final lessons = _lessons();
  final reviews = _reviews();

  HifzPeriodReport monthReport() => buildPeriodReport(
        lessons: lessons,
        reviews: reviews,
        start: Jalali(j.year, j.month).toDateTime(),
        end: Jalali(j.year, j.month).addMonths(1).toDateTime(),
      );

  HifzYearReport yearReport() => buildYearReport(
        lessons: lessons,
        reviews: reviews,
        jYear: j.year,
        monthStarts: [
          for (var m = 1; m <= 12; m++) Jalali(j.year, m).toDateTime()
        ],
        yearEnd: Jalali(j.year + 1).toDateTime(),
      );

  void expectPdf(Uint8List bytes) {
    expect(bytes, isNotEmpty);
    final head = String.fromCharCodes(bytes.take(5));
    expect(head, '%PDF-');
    final text = String.fromCharCodes(bytes);
    // The catalog / page tree objects carry /Type markers.
    expect(text.contains('/Type'), isTrue,
        reason: 'PDF should contain its object tree');
    // A multi-page-capable document declares a page count.
    expect(text.contains('/Count'), isTrue,
        reason: 'PDF should declare its page count');
    // Vazirmatn must be embedded so Persian text renders.
    expect(text.contains('Vazirmatn'), isTrue,
        reason: 'PDF should embed the Vazirmatn font for Persian text');
    // The app logo must be embedded as an image XObject so the header
    // shows it (the image is FlateDecode-compressed, so look for the
    // image XObject marker rather than the raw PNG signature).
    expect(text.contains('/Subtype/Image'), isTrue,
        reason: 'PDF should embed the app logo image');
  }

  test('monthly PDF report builds as a valid multi-section document', () async {
    final bytes = await buildHifzReportPdf(
      hafiz: _hafiz(),
      periodLabel: 'مهر ۱۴۰۵',
      monthReport: monthReport(),
      yearReport: null,
      pagesByDay: {1: 2, 2: 1},
      dayCount: 30,
    );
    expectPdf(bytes);
  });

  test('yearly PDF report builds as a valid multi-page document', () async {
    final bytes = await buildHifzReportPdf(
      hafiz: _hafiz(),
      periodLabel: 'سال ۱۴۰۵',
      monthReport: null,
      yearReport: yearReport(),
    );
    expectPdf(bytes);
  });

  test('yearly PDF is a genuinely multi-page document', () async {
    final bytes = await buildHifzReportPdf(
      hafiz: _hafiz(),
      periodLabel: 'سال ۱۴۰۵',
      monthReport: null,
      yearReport: yearReport(),
    );
    // The /Count entry of the page tree reports the number of pages.
    final text = String.fromCharCodes(bytes);
    final match = RegExp(r'/Count\s+(\d+)').firstMatch(text);
    expect(match, isNotNull, reason: 'PDF should declare its page count');
    final pages = int.parse(match!.group(1)!);
    expect(pages, greaterThanOrEqualTo(2),
        reason: 'Yearly report (12 months + trend chart) should span '
            'multiple pages');
  });
}

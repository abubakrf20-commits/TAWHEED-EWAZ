import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/hifz/domain/entities/hafiz_model.dart';
import 'package:tawheeed/features/hifz/domain/entities/hifz_lesson_model.dart';
import 'package:tawheeed/features/hifz/domain/entities/hifz_review_model.dart';
import 'package:tawheeed/features/hifz/presentation/screens/hifz_report_screen.dart';

HafizModel _hafiz() =>
    HafizModel(id: 'h1', name: 'محمد', createdAt: DateTime(2025));

// Records are dated NOW (inside the current Jalali month even on its first
// day) so the report — which opens on the current month — always shows them.
final _now = DateTime.now();

List<HifzLessonModel> _lessons() => [
      HifzLessonModel(
        id: 'l1',
        hafizId: 'h1',
        date: _now,
        surahFrom: 2,
        ayahFrom: 1,
        surahTo: 2,
        ayahTo: 6,
        pages: 2,
        createdAt: _now,
      ),
    ];

List<HifzReviewModel> _reviews() => [
      HifzReviewModel(
        id: 'r1',
        hafizId: 'h1',
        date: _now,
        type: ReviewType.sabaq,
        surahFrom: 2,
        ayahFrom: 1,
        surahTo: 2,
        ayahTo: 6,
        pages: 2,
        quality: ReviewQuality.excellent,
        createdAt: _now,
      ),
    ];

void main() {
  testWidgets('renders the monthly report with stats and quality',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HifzReportScreen(
          hafiz: _hafiz(),
          lessons: _lessons(),
          reviews: _reviews(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('گزارش حفظ قرآن'), findsWidgets);
    expect(find.text('حفظ جدید'), findsOneWidget);
    expect(find.text('سبق'), findsWidgets);
    expect(find.text('مراجعه'), findsWidgets);
    // Stat cards: 2 pages of حفظ + 1 sabaq + 0 muraja'ah.
    expect(find.text('2 صفحه'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
    // Quality chips for سبق and مراجعه.
    expect(find.textContaining('عالی'), findsWidgets);
    expect(find.textContaining('متوسط'), findsWidgets);
    // Daily distribution grid header.
    expect(find.text('توزیع روزانهٔ حفظ'), findsOneWidget);
  });

  testWidgets('switches to the yearly report with 12 month rows',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HifzReportScreen(
          hafiz: _hafiz(),
          lessons: _lessons(),
          reviews: _reviews(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('سالانه'));
    await tester.pumpAndSettle();

    expect(find.text('به تفکیک ماه'), findsOneWidget);
    expect(find.text('فروردین'), findsOneWidget);
    expect(find.text('اسفند'), findsOneWidget);
    expect(find.textContaining('صفحه'), findsWidgets);
    // Cumulative growth trend chart is present in the yearly report.
    expect(find.text('روند رشد صفحات تجمعی'), findsOneWidget);
  });
}

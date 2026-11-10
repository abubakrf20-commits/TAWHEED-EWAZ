import 'package:tawheeed/core/constants/date_constants.dart';
import 'package:tawheeed/features/worship/domain/evaluation_calculator.dart';

/// Pure text-report builder (single source for the shareable monthly
/// summary). Takes primitive fields instead of [EvaluationState] so both the
/// extracted-state file and the provider's internal class can feed it
/// without an ambiguity between the two same-named types.
String buildMonthlyReport(
  int? monthlyScore, {
  required String performanceRating,
  required double dailyAverage,
  required int currentStreak,
  required int bestStreak,
  required int worshipDone,
  required int worshipTotal,
  required List<int> monthlyScores,
  required int totalCompleted,
  required int totalSkipped,
  DateTime? now,
}) {
  final timestamp = now ?? DateTime.now();
  final buf = StringBuffer();
  final jalali = EvaluationCalculator.toJalali(timestamp);
  final monthLabel = DateConstants.persianMonths[jalali.month - 1];
  buf.writeln('📊 گزارش ماه $monthLabel ${jalali.year}');
  buf.writeln('═' * 30);
  buf.writeln('امتیاز ماه: ${monthlyScore ?? 0}');
  buf.writeln('ارزیابی: $performanceRating');
  buf.writeln('میانگین روزانه: ${dailyAverage.toStringAsFixed(1)}');
  buf.writeln('رکورد زنجیره: $currentStreak روز');
  buf.writeln('بهترین زنجیره: $bestStreak روز');
  buf.writeln();
  buf.writeln('📋 طاعات');
  buf.writeln('انجام شده امروز: $worshipDone/$worshipTotal');
  buf.writeln();
  buf.writeln('📅 خلاصه ماه');
  for (int i = 0; i < monthlyScores.length; i++) {
    if (monthlyScores[i] > 0) {
      buf.writeln('روز ${i + 1}: ${monthlyScores[i]} امتیاز');
    }
  }
  buf.writeln();
  buf.writeln('مجموع اذکار انجام شده: $totalCompleted');
  buf.writeln('مجموع اذکار رها شده: $totalSkipped');
  return buf.toString();
}

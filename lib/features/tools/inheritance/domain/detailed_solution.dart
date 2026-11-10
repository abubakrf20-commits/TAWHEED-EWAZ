import 'package:tawheeed/shared/utils/number_format.dart';

import 'inheritance_calculator.dart';
import 'madhab_calculator.dart';
import 'named_problems.dart';

/// یک گام از حل تفصیلی: عنوان + چند سطر توضیح.
class SolutionStep {
  final String title;
  final List<String> lines;

  const SolutionStep(this.title, this.lines);
}

/// حل تفصیلی گام‌به‌گام مسأله ارث.
class DetailedSolution {
  final InheritanceResult result;
  final List<SolutionStep> steps;

  /// نام مسألهٔ مشهور (مثل الغراوين، المشتركة) اگر قابل شناسایی بود.
  final String? namedProblem;

  /// همهٔ مسائل مشهوری که روی این صفت منطبق شدند.
  final List<NamedProblem> namedProblems;

  const DetailedSolution({
    required this.result,
    required this.steps,
    this.namedProblem,
    this.namedProblems = const [],
  });
}

/// ساخت حل تفصیلی گام‌به‌گام بر اساس خروجی موتور ارث.
DetailedSolution calculateDetailedSolution(InheritanceInput input) {
  final result = getCalculator(input.madhab).calculate(input);
  final steps = <SolutionStep>[];
  final namedProblems = detectNamedProblems(input);
  final named = namedProblems.isEmpty ? null : namedProblems.first.fullName;

  // ── گام 1: وارثان و فرض‌های آنان ──
  if (result.shares.isEmpty) {
    steps.add(const SolutionStep(
      'گام 1: وارثان',
      ['هیچ‌یک از وراث شناخته‌شده حضور ندارد؛ ترکه به بیت‌المال تعلق می‌گیرد.'],
    ));
  } else {
    steps.add(SolutionStep('گام 1: وارثان و سهم‌های آنان', [
      for (final s in result.shares)
        '${heirLabel(s.type)}${s.count > 1 ? ' (${s.count} نفر)' : ''}: ${s.fraction.toArString()} — ${s.reason}',
    ]));
  }

  // ── گام 2: أصل المسألة ──
  final aslLines = <String>[];
  if (result.baseAsl > 0) {
    final denoms = result.shares
        .map((s) => s.fraction.d)
        .where((d) => d > 1)
        .toSet()
        .toList()
      ..sort();
    aslLines.add(
        'اصل مسأله = ${result.baseAsl} (کم‌ترین مضرب مشترک مخرج‌های فرض‌ها${denoms.isNotEmpty ? ' ${denoms.join('، ')}' : ''}).');
  } else {
    aslLines.add(
        'فرض‌ها همه با هم برابر با کل ترکه‌اند؛ اصل مسأله‌ای برای تصحیح نیاز نیست.');
  }
  if (result.method == 'awl') {
    aslLines.add(
        'چون مجموع فرض‌ها از کل ترکه بیشتر بود، اصل مسأله از ${result.baseAsl} به ${result.correctedAsl} عول (افزایش) یافت.');
  } else if (result.method == 'radd') {
    aslLines.add(
        'چون پس از فرض‌ها باقی‌مانده‌ای بود و عصبهای نبود، طبق قاعده «رد» اصل مسأله ${result.correctedAsl} شد.');
  } else if (result.baseAsl != result.correctedAsl) {
    aslLines.add('اصل مسأله پس از تصحيح: ${result.correctedAsl}.');
  }
  steps.add(SolutionStep('گام 2: اصل مسأله و تصحیح آن', aslLines));

  // ── گام 3: توزیع سهام ──
  if (result.shares.isNotEmpty && result.correctedAsl > 0) {
    final sharesLines = <String>[];
    var totalUnits = 0;
    for (final s in result.shares) {
      final units = s.fraction.n * (result.correctedAsl ~/ s.fraction.d);
      totalUnits += units;
      sharesLines.add(
          '${heirLabel(s.type)}: ${s.fraction.toArString()} از ${result.correctedAsl} سهم یعنی $units سهم.');
    }
    sharesLines.add('جمع سهام: $totalUnits از ${result.correctedAsl}.');
    if (result.method == 'radd') {
      sharesLines
          .add('باقی‌مانده بر اساس نسبت فرض‌های غیرِ همسری بین آنان «رد» شد.');
    }
    steps.add(
        SolutionStep('گام 3: توزیع سهام (به واحد اصل مسأله)', sharesLines));
  }

  // ── گام 4: محاسبه مبالغ ──
  if (result.shares.isNotEmpty && result.netEstate > 0) {
    final moneyLines = <String>[];
    final unitValue = result.netEstate / result.correctedAsl;
    // Grouped: the estate is the largest number on the page, and «12000000»
    // next to «12,000,000» on the summary card read as two different figures.
    moneyLines.add(
        'ارزش هر سهم = ${NumberFormat.groupDigits(result.netEstate.toStringAsFixed(0))} '
        '÷ ${result.correctedAsl} = '
        '${NumberFormat.groupDigits(unitValue.toStringAsFixed(2))}.');
    for (final s in result.shares) {
      if (s.count > 1) {
        moneyLines.add('${heirLabel(s.type)}: مجموع '
            '${NumberFormat.groupDigits(s.amount.toStringAsFixed(0))} '
            '(هر نفر '
            '${NumberFormat.groupDigits((s.amount / s.count).toStringAsFixed(0))}).');
      } else {
        moneyLines.add('${heirLabel(s.type)}: '
            '${NumberFormat.groupDigits(s.amount.toStringAsFixed(0))}.');
      }
    }
    steps.add(SolutionStep('گام 4: محاسبه مبالغ نقدی', moneyLines));
  }

  // ── گام 5: نکات تکمیلی ──
  if (result.notes.isNotEmpty) {
    steps.add(SolutionStep('گام 5: نکات تکمیلی', result.notes));
  }

  return DetailedSolution(
    result: result,
    steps: steps,
    namedProblem: named,
    namedProblems: namedProblems,
  );
}

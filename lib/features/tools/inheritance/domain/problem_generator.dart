import 'dart:math';

import 'inheritance_calculator.dart';
import 'madhab_calculator.dart';

/// یک مسأله تصادفی تولیدشده به‌همراه پاسخ درست آن.
class GeneratedProblem {
  final InheritanceInput input;
  final InheritanceResult result;
  final Madhab madhab;

  const GeneratedProblem({
    required this.input,
    required this.result,
    required this.madhab,
  });

  /// فهرست وارثان حاضر (برای نمایش مسأله).
  String get description {
    final parts = <String>[];
    for (final s in result.shares) {
      parts.add('${heirLabel(s.type)}${s.count > 1 ? ' ×${s.count}' : ''}');
    }
    return parts.join('، ');
  }

  /// پاسخ درست: کسر هر وارث.
  Map<HeirType, double> get correctFractions => {
        for (final s in result.shares) s.type: s.fraction.toDouble(),
      };
}

/// نتیجه بررسی پاسخ کاربر.
class AnswerCheck {
  final Map<HeirType, bool> results;
  final double score; // 0..1
  final List<String> feedback;

  const AnswerCheck({
    required this.results,
    required this.score,
    required this.feedback,
  });
}

final List<HeirType> _leafPool = [
  HeirType.grandson,
  HeirType.granddaughter,
];

InheritanceInput _randomInput(Random rng) {
  final estate = (rng.nextInt(90) + 10) * 1000.0;

  // همسر
  final spouseRoll = rng.nextInt(10);
  final int husband = spouseRoll < 3 ? 1 : 0;
  final int wife = spouseRoll >= 6 ? 1 : 0;

  // فرزندان
  final int son = rng.nextInt(3);
  final int daughter = rng.nextInt(3);

  // والدین
  final int father = rng.nextInt(2);
  final int mother = rng.nextInt(2);

  // پدربزرگ/مادربزرگ
  final int grandfather = rng.nextInt(2);
  final int maternalGrandmother = rng.nextInt(2);

  // خواهر/برادرها
  int count() => rng.nextInt(3);
  final int fullBrother = count();
  final int fullSister = count();
  final int paternalBrother = count();
  final int paternalSister = count();
  final int maternalBrother = count();
  final int maternalSister = count();

  // وارث دور
  final HeirType? leaf =
      rng.nextInt(10) == 0 ? _leafPool[rng.nextInt(_leafPool.length)] : null;

  return InheritanceInput(
    estate: estate,
    husband: husband,
    wife: wife,
    son: son,
    daughter: daughter,
    father: father,
    mother: mother,
    grandfather: grandfather,
    maternalGrandmother: maternalGrandmother,
    fullBrother: fullBrother,
    fullSister: fullSister,
    paternalBrother: paternalBrother,
    paternalSister: paternalSister,
    maternalBrother: maternalBrother,
    maternalSister: maternalSister,
    grandson: leaf == HeirType.grandson ? 1 : 0,
    granddaughter: leaf == HeirType.granddaughter ? 1 : 0,
  );
}

/// تولید یک مسأله ارث تصادفی معتبر.
GeneratedProblem generateRandomProblem({
  Madhab madhab = Madhab.jumhur,
  Random? random,
}) {
  final rng = random ?? Random();
  for (var attempt = 0; attempt < 80; attempt++) {
    final input = _randomInput(rng);
    final withMadhab = input.copyWith(madhab: madhab);
    final result = getCalculator(madhab).calculate(withMadhab);
    if (result.shares.isNotEmpty &&
        result.totalAllocated > 0 &&
        result.netEstate > 0) {
      return GeneratedProblem(
        input: withMadhab,
        result: result,
        madhab: madhab,
      );
    }
  }
  // ضمانت: یک مسأله سادهٔ همیشه-معتبر
  const fallback = InheritanceInput(estate: 6000, daughter: 1);
  final r = getCalculator(madhab).calculate(fallback);
  return GeneratedProblem(input: fallback, result: r, madhab: madhab);
}

/// ساخت یک آزمون شامل چند مسأله.
List<GeneratedProblem> generateExam({
  required int questionCount,
  Madhab madhab = Madhab.jumhur,
  Random? random,
}) {
  final rng = random ?? Random();
  return [
    for (var i = 0; i < questionCount; i++)
      generateRandomProblem(madhab: madhab, random: rng),
  ];
}

/// بررسی پاسخ کاربر برای یک مسأله.
///
/// [userFractions] کسر هر وارث را (از 0 تا 1) می‌دهد. مقدار 0 یعنی
/// «به این وارث ارث نمی‌رسد».
AnswerCheck checkProblemAnswer(
  GeneratedProblem problem,
  Map<HeirType, double> userFractions,
) {
  const tol = 1e-6;
  final correct = problem.correctFractions;
  final results = <HeirType, bool>{};
  final feedback = <String>[];
  var correctCount = 0;
  final allTypes = <HeirType>{...correct.keys, ...userFractions.keys};

  for (final t in allTypes) {
    final expected = correct[t] ?? 0.0;
    final got = userFractions[t] ?? 0.0;
    final ok = (expected - got).abs() <= tol;
    results[t] = ok;
    if (ok) correctCount++;
    if (!ok) {
      feedback.add(
          '${heirLabel(t)}: پاسخ شما ${got.toStringAsFixed(4)} ولی درست ${expected.toStringAsFixed(4)} است.');
    }
  }

  final score = allTypes.isEmpty ? 0.0 : correctCount / allTypes.length;
  return AnswerCheck(results: results, score: score, feedback: feedback);
}

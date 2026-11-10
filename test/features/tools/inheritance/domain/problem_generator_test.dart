import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/tools/inheritance/domain/inheritance_calculator.dart';
import 'package:tawheeed/features/tools/inheritance/domain/problem_generator.dart';

void main() {
  test('مولد: 100 مسأله تصادفی همگی معتبرند', () {
    final rng = Random(42);
    for (var i = 0; i < 100; i++) {
      final p = generateRandomProblem(random: rng);
      expect(p.result.shares, isNotEmpty);
      expect(p.result.totalAllocated, greaterThan(0));
      expect(p.result.netEstate, greaterThan(0));
    }
  });

  test('آزمون: ساخت 5 سؤال', () {
    final exam = generateExam(questionCount: 5, random: Random(1));
    expect(exam.length, 5);
    for (final q in exam) {
      expect(q.description, isNotEmpty);
      expect(q.correctFractions, isNotEmpty);
    }
  });

  test('بررسی پاسخ درست → نمره 1', () {
    final p = generateRandomProblem(random: Random(7));
    final check = checkProblemAnswer(p, p.correctFractions);
    expect(check.score, 1.0);
    expect(check.feedback, isEmpty);
  });

  test('بررسی پاسخ غلط → نمره کمتر از 1 و بازخورد', () {
    final p = generateRandomProblem(random: Random(8));
    final wrong = <HeirType, double>{};
    final first = p.result.shares.first.type;
    wrong[first] = p.result.shares.first.fraction.toDouble() + 0.1;
    final check = checkProblemAnswer(p, wrong);
    expect(check.score, lessThan(1.0));
    expect(check.feedback, isNotEmpty);
  });
}

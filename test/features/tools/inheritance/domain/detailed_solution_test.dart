import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/tools/inheritance/domain/detailed_solution.dart';
import 'package:tawheeed/features/tools/inheritance/domain/inheritance_calculator.dart';

void main() {
  test('أصل المسألة برای زوج + دو دختر: أصل 12 و پس از رد 4', () {
    final s = calculateDetailedSolution(const InheritanceInput(
      estate: 8000,
      husband: 1,
      daughter: 2,
    ));
    // زوج با فرزند 1/4 و دو دختر 2/3 → مجموع 11/12، باقی 1/12 رد می‌شود.
    expect(s.result.method, 'radd');
    expect(s.result.baseAsl, 12);
    expect(s.result.correctedAsl, 4);
    expect(s.steps.length, greaterThanOrEqualTo(2));
  });

  test('عول: زوج + دو خواهر شقیقه + دو خواهر مادری → أصل 6 عال به 9', () {
    final s = calculateDetailedSolution(const InheritanceInput(
      estate: 8000,
      husband: 1,
      fullSister: 2,
      maternalSister: 2,
    ));
    expect(s.result.method, 'awl');
    expect(s.result.baseAsl, 6);
    expect(s.result.correctedAsl, 9);
    expect(s.steps.length, greaterThanOrEqualTo(3));
  });

  test('رد: دختر + مادر → أصل 6 و پس از رد 4', () {
    final s = calculateDetailedSolution(const InheritanceInput(
      estate: 8000,
      daughter: 1,
      mother: 1,
    ));
    expect(s.result.method, 'radd');
    expect(s.result.baseAsl, 6);
    expect(s.result.correctedAsl, 4);
  });

  test('شناسایی مسأله مشترکه (المنبرية)', () {
    final s = calculateDetailedSolution(const InheritanceInput(
      estate: 9000,
      husband: 1,
      mother: 1,
      maternalBrother: 2,
      fullBrother: 1,
    ));
    expect(s.namedProblem, 'مسأله مشترکه (المنبرية، الحمارية، المشركة)');
  });

  test('شناسایی الغراوين', () {
    final s = calculateDetailedSolution(const InheritanceInput(
      estate: 12000,
      husband: 1,
      mother: 1,
      father: 1,
    ));
    expect(s.namedProblem, 'مسأله عمری (الغراوان، العمریتان)');
  });

  test('گام مبالغ نقدی: مجموع مبالغ با ترکه برابر است', () {
    final s = calculateDetailedSolution(const InheritanceInput(
      estate: 6000,
      wife: 1,
      daughter: 1,
      father: 1,
    ));
    expect(s.result.totalAllocated, closeTo(6000, 0.001));
    expect(s.steps.length, greaterThanOrEqualTo(4));
  });
}

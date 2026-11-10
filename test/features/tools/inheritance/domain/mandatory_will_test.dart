import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/tools/inheritance/domain/inheritance_calculator.dart';
import 'package:tawheeed/features/tools/inheritance/domain/mandatory_will.dart';

void main() {
  final egypt = mandatoryWillLaws.first;

  test('وصیت واجبه: پدر + نوه‌های پسرِ فوت‌شده', () {
    final r = calculateMandatoryWill(
      const InheritanceInput(
        estate: 9000,
        father: 1,
        grandson: 1,
        granddaughter: 1,
      ),
      egypt,
    );
    expect(r.applies, isTrue);
    // سهم پسر در حالت فرضی = 5/6 × 9000 = 7500 → محدود به 1/3 = 3000
    expect(r.mandatoryAmount, closeTo(3000, 0.001));
    expect(r.orphans.length, 2);
    expect(r.orphans[0].type, HeirType.grandson);
    expect(r.orphans[0].amount, closeTo(2000, 0.001));
    expect(r.orphans[1].amount, closeTo(1000, 0.001));
    // باقی 6000 به پدر می‌رسد
    expect(r.remainingResult.totalAllocated, closeTo(6000, 0.001));
    expect(r.totalAllocated, closeTo(9000, 0.001));
  });

  test('وصیت واجبه زمانی اعمال نمی‌شود که نوه‌ی یتیمی نیست', () {
    final r = calculateMandatoryWill(
      const InheritanceInput(estate: 9000, father: 1, son: 1),
      egypt,
    );
    expect(r.applies, isFalse);
    expect(r.mandatoryAmount, 0);
  });

  test('وصیت واجبه محدود به ثلث است', () {
    final r = calculateMandatoryWill(
      const InheritanceInput(
        estate: 9000,
        wife: 1,
        grandson: 2,
        granddaughter: 1,
      ),
      egypt,
    );
    expect(r.applies, isTrue);
    expect(r.mandatoryAmount, lessThanOrEqualTo(3000.0 + 0.001));
  });
}

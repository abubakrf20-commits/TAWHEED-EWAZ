import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/tools/inheritance/domain/inheritance_calculator.dart';
import 'package:tawheeed/features/tools/inheritance/domain/special_cases.dart';

void main() {
  test('حمل: زوج تنها + نوزاد → ذخیره 3/4 ترکه', () {
    final r = calculateSpecialCase(
      const InheritanceInput(estate: 4000, husband: 1),
      SpecialCaseKind.unbornChild,
    );
    expect(r.scenarios.length, 2);
    // اگر پسر: زوج 1/4، پسر 3/4 (تعصیب)
    expect(r.scenarios[0].result.shares.any((s) => s.type == HeirType.son),
        isTrue);
    // اگر دختر: زوج 1/4، دختر 1/2 + رد 1/4 = 3/4
    expect(r.scenarios[1].result.shares.any((s) => s.type == HeirType.daughter),
        isTrue);
    expect(reservedForSpecialCase(r), closeTo(3000, 0.001));
  });

  test('مفقود: زوج + برادر مفقود → اگر زنده باشد برادر نیمی می‌گیرد', () {
    final r = calculateSpecialCase(
      const InheritanceInput(estate: 4000, husband: 1),
      SpecialCaseKind.missingPerson,
    );
    expect(r.scenarios.length, 2);
    expect(r.scenarios[0].pendingShare, closeTo(2000, 0.001)); // برادر 1/2
    expect(reservedForSpecialCase(r), closeTo(2000, 0.001));
  });

  test('خنثی: پدر + مادر + فرزند خنثی', () {
    final r = calculateSpecialCase(
      const InheritanceInput(estate: 6000, father: 1, mother: 1),
      SpecialCaseKind.intersex,
    );
    expect(r.scenarios.length, 2);
    // مذکر: پدر 1/6، مادر 1/6، پسر 2/3
    expect(r.scenarios[0].pendingShare, closeTo(4000, 0.001));
    // مؤنث: دختر 1/2، پدر 1/6 + تعصیب (1/6)، مادر 1/6
    expect(r.scenarios[1].pendingShare, closeTo(3000, 0.001));
    expect(reservedForSpecialCase(r), closeTo(4000, 0.001));
  });
}

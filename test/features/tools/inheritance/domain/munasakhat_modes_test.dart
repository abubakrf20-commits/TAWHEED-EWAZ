import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/tools/inheritance/domain/inheritance_calculator.dart';
import 'package:tawheeed/features/tools/inheritance/domain/munasakhat_modes.dart';

void main() {
  group('calculateMergedMunasakhat (ضمن طبقة ورثة الميت الأول)', () {
    test('مرحلتان: الميت الأول ثم الميت الثاني', () {
      final r = calculateMergedMunasakhat('مناسخات', [
        (
          'متوفی اول (پدر)',
          const InheritanceInput(
            estate: 1000,
            son: 2,
          ),
        ),
        (
          'متوفی دوم (پسر)',
          const InheritanceInput(
            wife: 1,
            daughter: 1,
          ),
        ),
      ]);
      expect(r.stages.length, 2);
      expect(r.totalEstate, 1000);
      // المرحلة الأولى تقسم التركة على الابنين.
      expect(r.stages[0].result.shares.length, 1);
      expect(r.stages[0].result.shares.single.type, HeirType.son);
    });
  });

  group('calculateGharqaHadma (الغرقى والهدمى)', () {
    test('موتان في حادث واحد لا يرث أحدهما من الآخر', () {
      final r = calculateGharqaHadma('غرقى', [
        (
          'الأب',
          const InheritanceInput(
            estate: 1000,
            wife: 1,
            son: 1,
            daughter: 1,
          ),
        ),
        (
          'الابن',
          const InheritanceInput(
            estate: 500,
            wife: 1,
            daughter: 1,
          ),
        ),
      ]);
      expect(r.stages.length, 2);
      expect(r.totalEstate, 1000);
      // تركة الأب: الزوجة ثمن = 125.
      final father = r.stages[0];
      expect(
        father.result.shares.firstWhere((s) => s.type == HeirType.wife).amount,
        closeTo(125, 0.001),
      );
      // تركة الابن (500): مع وجود ابنته للزوجة الثمن = 62.5.
      final son = r.stages[1];
      expect(
        son.result.shares.firstWhere((s) => s.type == HeirType.wife).amount,
        closeTo(62.5, 0.001),
      );
      expect(r.explanation, isNotEmpty);
    });
  });

  test('وصف طريقة الغرقى والهدمى موجود', () {
    expect(gharqaHadmaMethodDescription, isNotEmpty);
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/tools/inheritance/domain/inheritance_calculator.dart';
import 'package:tawheeed/features/tools/inheritance/domain/special_cases.dart';

void main() {
  group('calculatePregnancyCase (الحمل)', () {
    test('ينتج ثماني نتائج (سقط حتى أربعة)', () {
      final r = calculatePregnancyCase(
        const InheritanceInput(
          estate: 800,
          wife: 1,
        ),
        PregnancyRelation.wife,
      );
      expect(r.scenarios.length, 8);
    });

    test('السقط لا أثر له والأول يورث كاملًا للزوجة', () {
      final r = calculatePregnancyCase(
        const InheritanceInput(
          estate: 800,
          wife: 1,
        ),
        PregnancyRelation.wife,
      );
      // سقط ميتًا → الزوجة ترث الثمن فقط.
      final stillborn = r.scenarios.first;
      expect(stillborn.result.shares.single.type, HeirType.wife);
      expect(stillborn.pendingShare, 0);
      // ولد ذكر → له سبعة أثمان التركة (الزوجة الثمن).
      final male = r.scenarios[1];
      expect(male.pendingShare, closeTo(700, 0.001));
      // الاحتياط يساوي أكبر سهم ممكن للفرع.
      expect(r.reservedAmount, closeTo(700, 0.001));
    });
  });

  group('calculateIntersexCase (الخنثى)', () {
    test('حالة الانكشاف: سناريوهان واحتياط الأكبر', () {
      final r = calculateIntersexCase(
        const InheritanceInput(
          estate: 600,
          father: 1,
          mother: 1,
        ),
        HeirType.son,
        IntersexMode.disclosed,
      );
      expect(r.scenarios.length, 2);
      expect(reservedForSpecialCase(r), closeTo(400, 0.001));
    });

    test('عدم الانكشاف (المالكية): يُعامَل كأنثى فقط', () {
      final r = calculateIntersexCase(
        const InheritanceInput(
          madhab: Madhab.maliki,
          estate: 600,
          father: 1,
          mother: 1,
        ),
        HeirType.son,
        IntersexMode.undisclosed,
      );
      expect(r.scenarios.length, 1);
      expect(r.scenarios.single.label, contains('مؤنث'));
      expect(r.scenarios.single.pendingShare, closeTo(300, 0.001));
    });
  });

  group('calculateBondmanCase (العبد المبعض)', () {
    test('عند الحنابلة: يرث بقدر الجزء الحر', () {
      final r = calculateBondmanCase(
        const InheritanceInput(
          madhab: Madhab.hanbali,
          estate: 800,
          son: 1,
        ),
        HeirType.son,
      );
      // الابن الوحيد يرث كل التركة.
      expect(r.inheritedAmount, closeTo(400, 0.001));
      expect(r.withheldAmount, closeTo(400, 0.001));
    });

    test('الجزء الحر الكامل → يرث الكل ولا يُحتجز شيء', () {
      final r = calculateBondmanCase(
        const InheritanceInput(
          madhab: Madhab.saudi,
          estate: 800,
          son: 1,
        ),
        HeirType.son,
        freeFraction: 1,
      );
      expect(r.inheritedAmount, closeTo(800, 0.001));
      expect(r.withheldAmount, closeTo(0, 0.001));
    });

    test('غير الحنابلة → خطأ', () {
      expect(
        () => calculateBondmanCase(
          const InheritanceInput(
            estate: 800,
            son: 1,
          ),
          HeirType.son,
        ),
        throwsArgumentError,
      );
    });

    test('كسري غير صالح → خطأ', () {
      expect(
        () => calculateBondmanCase(
          const InheritanceInput(
            madhab: Madhab.hanbali,
            estate: 800,
            son: 1,
          ),
          HeirType.son,
          freeFraction: 0,
        ),
        throwsArgumentError,
      );
    });
  });
}

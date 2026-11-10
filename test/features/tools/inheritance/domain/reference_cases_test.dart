import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/tools/inheritance/domain/inheritance_calculator.dart';
import 'package:tawheeed/features/tools/inheritance/domain/madhab_calculator.dart';
import 'package:tawheeed/features/tools/inheritance/domain/madhab_rules.dart';

InheritanceShare? shareOf(InheritanceResult r, HeirType t) =>
    r.shares.where((s) => s.type == t).firstOrNull;

void expectFrac(InheritanceResult r, HeirType t, double expected,
    {String? reason}) {
  final s = shareOf(r, t);
  expect(s, isNotNull, reason: '${heirLabel(t)} missing. ${reason ?? ''}');
  expect(s!.fraction.toDouble(), closeTo(expected, 1e-9),
      reason: '${heirLabel(t)} share mismatch. ${reason ?? ''}');
}

void expectBlocked(InheritanceResult r, HeirType t, {String? reason}) {
  expect(shareOf(r, t), isNull,
      reason: '${heirLabel(t)} should be blocked. ${reason ?? ''}');
}

/// True غراوين (عمريتان): زوج/زوجة + أم + أب بدون إخوة.
/// For all madhabs: أم = 1/3 of the remainder after the spouse.
void main() {
  group('غراوین (عمريتان) — spouse + mother + father, no siblings', () {
    for (final m in Madhab.values) {
      test('husband + mother + father ($m): 1/2, 1/6, 1/3', () {
        final r = getCalculator(m).calculate(InheritanceInput(
          estate: 12000,
          husband: 1,
          mother: 1,
          father: 1,
          madhab: m,
        ));
        expectFrac(r, HeirType.husband, 1 / 2, reason: '$m');
        expectFrac(r, HeirType.mother, 1 / 6, reason: '$m');
        expectFrac(r, HeirType.father, 1 / 3, reason: '$m');
        expect(r.totalAllocated, closeTo(12000, 0.001));
      });

      test('wife + mother + father ($m): 1/4, 1/4, 1/2', () {
        final r = getCalculator(m).calculate(InheritanceInput(
          estate: 12000,
          wife: 1,
          mother: 1,
          father: 1,
          madhab: m,
        ));
        expectFrac(r, HeirType.wife, 1 / 4, reason: '$m');
        expectFrac(r, HeirType.mother, 1 / 4, reason: '$m');
        expectFrac(r, HeirType.father, 1 / 2, reason: '$m');
        expect(r.totalAllocated, closeTo(12000, 0.001));
      });
    }
  });

  group('غراوین با إخوة — spouse + mother + father + full brother', () {
    // قول عمر: الأم ثلث الباقي بعد الزوج والأب عاصب يأخذ كل الباقي،
    // فالإخوة محجوبون بالأب لا شيء لهم (المقاسمة من نتایج قول علي).
    test('Hanafi (قول عمر): أم = ثلث الباقي = 1/6, أب = 1/3 والأخ محجوب', () {
      final r = getCalculator(Madhab.hanafi).calculate(const InheritanceInput(
        estate: 12000,
        husband: 1,
        mother: 1,
        father: 1,
        fullBrother: 1,
      ));
      expectFrac(r, HeirType.husband, 1 / 2);
      expectFrac(r, HeirType.mother, 1 / 6);
      expectFrac(r, HeirType.father, 1 / 3);
      expectBlocked(r, HeirType.fullBrother);
      expect(r.totalAllocated, closeTo(12000, 0.001));
    });

    test('Shafii (قول عمر): أم = ثلث الباقي = 1/6, أب = 1/3 والأخ محجوب', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 12000,
        husband: 1,
        mother: 1,
        father: 1,
        fullBrother: 1,
      ));
      expectFrac(r, HeirType.husband, 1 / 2);
      expectFrac(r, HeirType.mother, 1 / 6);
      expectFrac(r, HeirType.father, 1 / 3);
      expectBlocked(r, HeirType.fullBrother);
      expect(r.totalAllocated, closeTo(12000, 0.001));
    });

    test('Maliki (قول علي): أم = ثلث الأصل = 1/3', () {
      final r = getCalculator(Madhab.maliki).calculate(const InheritanceInput(
        estate: 12000,
        husband: 1,
        mother: 1,
        father: 1,
        fullBrother: 1,
      ));
      expectFrac(r, HeirType.husband, 1 / 2);
      expectFrac(r, HeirType.mother, 1 / 3);
      // الباقي 1/6 بين أب وأخ بالتساوي
      expectFrac(r, HeirType.father, 1 / 12);
      expectFrac(r, HeirType.fullBrother, 1 / 12);
      expect(r.totalAllocated, closeTo(12000, 0.001));
    });

    test('Hanbali (قول علي): أم = ثلث الأصل = 1/3', () {
      final r = getCalculator(Madhab.hanbali).calculate(const InheritanceInput(
        estate: 12000,
        husband: 1,
        mother: 1,
        father: 1,
        fullBrother: 1,
      ));
      expectFrac(r, HeirType.husband, 1 / 2);
      expectFrac(r, HeirType.mother, 1 / 3);
      expectFrac(r, HeirType.father, 1 / 12);
      expectFrac(r, HeirType.fullBrother, 1 / 12);
      expect(r.totalAllocated, closeTo(12000, 0.001));
    });
  });

  group('غراوین — القولان متلازمان لا يُخلطان', () {
    // الأم لا تأخذ ثلث الأصل إلا حيث يقاسم الأبُ الإخوة، ولا يقاسمهم إلا
    // حيث تأخذ الأم ثلث الأصل: قول عمر أو قول علي وزيد — كلها معًا.
    for (final m in Madhab.values) {
      test('$m: أم ثلث الأصل ⟺ أب + إخوة في المقاسمة', () {
        final r = getCalculator(m).calculate(InheritanceInput(
          estate: 12000,
          husband: 1,
          mother: 1,
          father: 1,
          fullBrother: 1,
          madhab: m,
        ));
        final thirdOfWhole = MadhabRules.gharrawainMotherThirdOfWhole(m);
        expectFrac(r, HeirType.husband, 1 / 2, reason: '$m');
        expectFrac(r, HeirType.mother, thirdOfWhole ? 1 / 3 : 1 / 6,
            reason: '$m');
        if (thirdOfWhole) {
          expectFrac(r, HeirType.father, 1 / 12, reason: '$m');
          expectFrac(r, HeirType.fullBrother, 1 / 12, reason: '$m');
        } else {
          expectFrac(r, HeirType.father, 1 / 3, reason: '$m');
          expectBlocked(r, HeirType.fullBrother, reason: '$m');
        }
        expect(r.totalAllocated, closeTo(12000, 0.001));
      });
    }
  });

  group('غراوین با أخت — spouse + mother + father + full sister', () {
    test('Shafii (قول عمر): أم = ثلث الباقي = 1/6، أب = 1/3 والأخت محجوبة', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 12000,
        husband: 1,
        mother: 1,
        father: 1,
        fullSister: 1,
      ));
      expectFrac(r, HeirType.husband, 1 / 2);
      expectFrac(r, HeirType.mother, 1 / 6);
      expectFrac(r, HeirType.father, 1 / 3);
      expectBlocked(r, HeirType.fullSister);
      expect(r.totalAllocated, closeTo(12000, 0.001));
    });

    test('Maliki: أم = 1/3، أب وأخت 2:1 على 1/6', () {
      final r = getCalculator(Madhab.maliki).calculate(const InheritanceInput(
        estate: 12000,
        husband: 1,
        mother: 1,
        father: 1,
        fullSister: 1,
      ));
      expectFrac(r, HeirType.husband, 1 / 2);
      expectFrac(r, HeirType.mother, 1 / 3);
      expectFrac(r, HeirType.father, 1 / 9);
      expectFrac(r, HeirType.fullSister, 1 / 18);
      expect(r.totalAllocated, closeTo(12000, 0.001));
    });
  });

  group('عول (increase of the asl)', () {
    test('wife + parents + 2 daughters → asl 27', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 27000,
        wife: 1,
        father: 1,
        mother: 1,
        daughter: 2,
      ));
      expect(r.method, 'awl');
      expectFrac(r, HeirType.wife, 3 / 27);
      expectFrac(r, HeirType.father, 4 / 27);
      expectFrac(r, HeirType.mother, 4 / 27);
      expectFrac(r, HeirType.daughter, 16 / 27);
    });

    test('husband + two full sisters + two maternal sisters → asl 9', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 9000,
        husband: 1,
        fullSister: 2,
        maternalSister: 2,
      ));
      expect(r.method, 'awl');
      expectFrac(r, HeirType.husband, 3 / 9);
      expectFrac(r, HeirType.fullSister, 4 / 9);
      expectFrac(r, HeirType.maternalSister, 2 / 9);
    });

    test('husband + full sister + paternal sister → asl 7', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 7000,
        husband: 1,
        fullSister: 1,
        paternalSister: 1,
      ));
      expect(r.method, 'awl');
      expectFrac(r, HeirType.husband, 3 / 7);
      expectFrac(r, HeirType.fullSister, 3 / 7);
      expectFrac(r, HeirType.paternalSister, 1 / 7);
    });
  });

  group('رد (return)', () {
    test('daughter + mother → 3/4 : 1/4', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 12000,
        daughter: 1,
        mother: 1,
      ));
      expect(r.method, 'radd');
      expectFrac(r, HeirType.daughter, 3 / 4);
      expectFrac(r, HeirType.mother, 1 / 4);
    });

    test('husband + two daughters → husband 1/4, daughters 3/4', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 12000,
        husband: 1,
        daughter: 2,
      ));
      expect(r.method, 'radd');
      expectFrac(r, HeirType.husband, 1 / 4);
      expectFrac(r, HeirType.daughter, 3 / 4);
    });

    test('husband + daughter + granddaughter → 1/4 : 9/16 : 3/16', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 1600,
        husband: 1,
        daughter: 1,
        granddaughter: 1,
      ));
      expect(r.method, 'radd');
      expectFrac(r, HeirType.husband, 1 / 4);
      expectFrac(r, HeirType.daughter, 9 / 16);
      expectFrac(r, HeirType.granddaughter, 3 / 16);
    });
  });

  group('بنت الابن (granddaughter) rules', () {
    test('two granddaughters alone → all to them (2/3 fard + radd)', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 6000,
        granddaughter: 2,
      ));
      expectFrac(r, HeirType.granddaughter, 1);
    });

    test('daughter (1) + granddaughter → 1/2 : 1/6 fards then radd', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 12000,
        daughter: 1,
        granddaughter: 1,
      ));
      // بنت 1/2، بنت الابن 1/6 (تكملة الثلثين)، الباقي 1/3 رد بالتناسب
      expectFrac(r, HeirType.daughter, 3 / 4);
      expectFrac(r, HeirType.granddaughter, 1 / 4);
    });

    test('granddaughter is blocked by a son', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 6000,
        son: 1,
        granddaughter: 1,
      ));
      expectBlocked(r, HeirType.granddaughter);
    });
  });

  group('مسائل مشتركة (منبرية/حماریة)', () {
    test('husband + mother + 2 maternal brothers + full brother (Shafii)', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 9000,
        husband: 1,
        mother: 1,
        maternalBrother: 2,
        fullBrother: 1,
      ));
      expect(r.method, 'normal');
      expectFrac(r, HeirType.husband, 1 / 2);
      expectFrac(r, HeirType.mother, 1 / 6);
      // المجموعة المشتركة: الأخوان لأم + الأخ الشقيق يتقاسمان 1/3 بالتساوي
      // فردًا فردًا؛ سهم مجموعة الأخوين لأم = 2/9.
      expectFrac(r, HeirType.maternalBrother, 2 / 9);
      expectFrac(r, HeirType.fullBrother, 1 / 9);
      expect(r.totalAllocated, closeTo(9000, 0.001));
    });
  });

  group('أكدرية (grandfather + spouse + mother + one sister)', () {
    test('husband + mother + grandfather + full sister (jumhur)', () {
      final r = getCalculator(Madhab.jumhur).calculate(const InheritanceInput(
        estate: 27000,
        husband: 1,
        mother: 1,
        grandfather: 1,
        fullSister: 1,
      ));
      expect(r.method, 'awl');
      expectFrac(r, HeirType.husband, 9 / 27);
      expectFrac(r, HeirType.mother, 6 / 27);
      expectFrac(r, HeirType.grandfather, 8 / 27);
      expectFrac(r, HeirType.fullSister, 4 / 27);
      expect(r.totalAllocated, closeTo(27000, 0.001));
    });

    test('wife + mother + grandfather + paternal sister (jumhur)', () {
      final r = getCalculator(Madhab.jumhur).calculate(const InheritanceInput(
        estate: 45000,
        wife: 1,
        mother: 1,
        grandfather: 1,
        paternalSister: 1,
      ));
      expect(r.method, 'awl');
      expectFrac(r, HeirType.wife, 9 / 45);
      expectFrac(r, HeirType.mother, 12 / 45);
      expectFrac(r, HeirType.grandfather, 16 / 45);
      expectFrac(r, HeirType.paternalSister, 8 / 45);
      expect(r.totalAllocated, closeTo(45000, 0.001));
    });
  });

  group('مسائل محققة من almwareeth.com (الجد مع الإخوة)', () {
    test('of3h8f4z: جد + أشقاء + لأب + لأم → الجد 1/3', () {
      final r = getCalculator(Madhab.jumhur).calculate(const InheritanceInput(
        estate: 27000,
        grandfather: 1,
        fullBrother: 1,
        fullSister: 1,
        paternalBrother: 1,
        paternalSister: 1,
        maternalBrother: 1,
        maternalSister: 1,
      ));
      // المعادّة: 8 رؤوس → نصيب الجد من المقاسمة 1/4 < 1/3 → الجد 1/3
      expectFrac(r, HeirType.grandfather, 1 / 3);
      expectFrac(r, HeirType.fullBrother, 4 / 9);
      expectFrac(r, HeirType.fullSister, 2 / 9);
      expectBlocked(r, HeirType.paternalBrother);
      expectBlocked(r, HeirType.paternalSister);
      expectBlocked(r, HeirType.maternalBrother);
      expectBlocked(r, HeirType.maternalSister);
      expect(r.totalAllocated, closeTo(27000, 0.001));
    });

    test('oc2m6p9c: زوج + أم + جد + أخ شقيق + أخوين لأم (شبه المالكية)', () {
      final r = getCalculator(Madhab.jumhur).calculate(const InheritanceInput(
        estate: 9000,
        husband: 1,
        mother: 1,
        grandfather: 1,
        fullBrother: 1,
        maternalBrother: 2,
      ));
      // الثلث الباقي بعد الزوج (1/2) والأم (1/6) يأخذه الجد كله لأن أولاد
      // الأم محجوبون بالجد فيسقط الأخ الشقيق أيضًا (شبه المالكية).
      expectFrac(r, HeirType.husband, 1 / 2);
      expectFrac(r, HeirType.mother, 1 / 6);
      expectFrac(r, HeirType.grandfather, 1 / 3);
      expectBlocked(r, HeirType.fullBrother);
      expectBlocked(r, HeirType.maternalBrother);
      expect(r.totalAllocated, closeTo(9000, 0.001));
    });

    test('شبه المالكية: شافعي/حنبلي يشاركون الجد الأخَ (بخلاف الجمهور)', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 9000,
        husband: 1,
        mother: 1,
        grandfather: 1,
        fullBrother: 1,
        maternalBrother: 2,
      ));
      // باقي المذاهب: مشاركة الجد للأخ → الجد 1/6 والأخ الشقيق 1/6.
      expectFrac(r, HeirType.husband, 1 / 2);
      expectFrac(r, HeirType.mother, 1 / 6);
      expectFrac(r, HeirType.grandfather, 1 / 6);
      expectFrac(r, HeirType.fullBrother, 1 / 6);
      expect(r.totalAllocated, closeTo(9000, 0.001));
    });

    test('on6j7u3h: أم + جد + شقيقة + أخ لأب + أخت لأب (تكملة الشقيقة)', () {
      final r = getCalculator(Madhab.jumhur).calculate(const InheritanceInput(
        estate: 5400,
        mother: 1,
        grandfather: 1,
        fullSister: 1,
        paternalBrother: 1,
        paternalSister: 1,
      ));
      // أم 3/18، جد 5/18 (المقاسمة = ثلث الباقي = 5/18)، ثم «نكمل للشقيقة
      // فرضها وهو النصف» (9/18) مما كان سيأخذه الأخوة لأب في المعادّة،
      // وما تبقى (1/18) لهم بنسبة 2:1.
      expectFrac(r, HeirType.mother, 1 / 6);
      expectFrac(r, HeirType.grandfather, 5 / 18);
      expectFrac(r, HeirType.fullSister, 1 / 2);
      expectFrac(r, HeirType.paternalBrother, 1 / 27);
      expectFrac(r, HeirType.paternalSister, 1 / 54);
      expect(r.totalAllocated, closeTo(5400, 0.001));
    });

    test('جد + شقيقة + أخ لأب: الشقيقة تكمّل إلى النصف من نصيب الأخ لأب', () {
      final r = getCalculator(Madhab.jumhur).calculate(const InheritanceInput(
        estate: 1000,
        grandfather: 1,
        fullSister: 1,
        paternalBrother: 1,
      ));
      // المقاسمة من 5 رؤوس → الجد 2/5، ثم الشقيقة 1/2، والأخ لأب 1/10.
      expectFrac(r, HeirType.grandfather, 2 / 5);
      expectFrac(r, HeirType.fullSister, 1 / 2);
      expectFrac(r, HeirType.paternalBrother, 1 / 10);
      expect(r.totalAllocated, closeTo(1000, 0.001));
    });

    test('جد + شقيقة + أخت لأب: الشقيقة تكمّل إلى النصف والأخت لأب لا شيء', () {
      final r = getCalculator(Madhab.jumhur).calculate(const InheritanceInput(
        estate: 600,
        grandfather: 1,
        fullSister: 1,
        paternalSister: 1,
      ));
      // المقاسمة من 4 رؤوس → الجد 1/2، والباقي نصفه للشقيقة تكملةً لفرضها
      // فلا يبقى شيء للأخت لأب.
      expectFrac(r, HeirType.grandfather, 1 / 2);
      expectFrac(r, HeirType.fullSister, 1 / 2);
      expectBlocked(r, HeirType.paternalSister);
      expect(r.totalAllocated, closeTo(600, 0.001));
    });

    test('أم + جد + أخت شقيقة: الباقي دون النصف تأخذه الشقيقة كله', () {
      final r = getCalculator(Madhab.jumhur).calculate(const InheritanceInput(
        estate: 900,
        mother: 1,
        grandfather: 1,
        fullSister: 1,
      ));
      // أم 1/3، الباقي 2/3: الجد 4/9 (مقاسمة أفضل)، والباقي 2/9 دون النصف
      // فتأخذه الشقيقة كله.
      expectFrac(r, HeirType.mother, 1 / 3);
      expectFrac(r, HeirType.grandfather, 4 / 9);
      expectFrac(r, HeirType.fullSister, 2 / 9);
      expect(r.totalAllocated, closeTo(900, 0.001));
    });
  });

  group('حجب الجدّات (القريبة تحجب البعيدة)', () {
    test('جمهور: أم الأم تحجب جدّة بعيدة من جهة الأب', () {
      final r = getCalculator(Madhab.jumhur).calculate(const InheritanceInput(
        estate: 6000,
        maternalGrandmother: 1,
        paternalGreatGrandmotherFather: 1,
      ));
      expectFrac(r, HeirType.maternalGrandmother, 1);
      expectBlocked(r, HeirType.paternalGreatGrandmotherFather);
    });

    test('شافعي: أم الأم تحجب البعيدة من الجهتين', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 6000,
        maternalGrandmother: 1,
        greatMaternalGrandmother: 1,
        paternalGreatGrandmotherMother: 1,
      ));
      expectFrac(r, HeirType.maternalGrandmother, 1);
      expectBlocked(r, HeirType.greatMaternalGrandmother);
      expectBlocked(r, HeirType.paternalGreatGrandmotherMother);
    });

    test('شافعي: أم الأب تحجب بعيدة جهة الأب فقط', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 6000,
        paternalGrandmother: 1,
        paternalGreatGrandmotherFather: 1,
        greatMaternalGrandmother: 1,
      ));
      // أم الأب تحجب بعيدتي الأب، لكن أم أم الأم (بعيدة جهة الأم) ترث.
      expectBlocked(r, HeirType.paternalGreatGrandmotherFather);
      expectFrac(r, HeirType.greatMaternalGrandmother, 1 / 2);
    });

    test('مالكي: أم الأم تحجب البعيدة من الجهتين', () {
      final r = getCalculator(Madhab.maliki).calculate(const InheritanceInput(
        estate: 6000,
        maternalGrandmother: 1,
        paternalGreatGrandmotherFather: 1,
      ));
      expectFrac(r, HeirType.maternalGrandmother, 1);
      expectBlocked(r, HeirType.paternalGreatGrandmotherFather);
    });

    test('أم تحجب كل الجدّات', () {
      final r = getCalculator(Madhab.jumhur).calculate(const InheritanceInput(
        estate: 6000,
        mother: 1,
        maternalGrandmother: 1,
        paternalGrandmother: 1,
      ));
      expectFrac(r, HeirType.mother, 1);
      expectBlocked(r, HeirType.maternalGrandmother);
      expectBlocked(r, HeirType.paternalGrandmother);
    });

    test('جدّتان قريبتان تتقاسمان السدس', () {
      final r = getCalculator(Madhab.jumhur).calculate(const InheritanceInput(
        estate: 12000,
        maternalGrandmother: 1,
        paternalGrandmother: 1,
      ));
      // فرض 1/6 مقسوم بينهما (1/12 لكل) ثم ردّ الباقي عليهما → 1/2 لكل
      expectFrac(r, HeirType.maternalGrandmother, 1 / 2);
      expectFrac(r, HeirType.paternalGrandmother, 1 / 2);
      expect(r.totalAllocated, closeTo(12000, 0.001));
    });
  });

  group('عصبة عمومة الأب (fatherUncle / fatherCousin)', () {
    test('عمویِ پدر (fatherUncleFull) عصبه است', () {
      final r = getCalculator(Madhab.jumhur).calculate(const InheritanceInput(
        estate: 6000,
        fatherUncleFull: 1,
      ));
      expectFrac(r, HeirType.fatherUncleFull, 1);
    });

    test('عمویِ پدر شقیق، عمویِ پدرِ پدری را حجب میکند', () {
      final r = getCalculator(Madhab.jumhur).calculate(const InheritanceInput(
        estate: 6000,
        fatherUncleFull: 1,
        fatherUnclePaternal: 1,
      ));
      expectFrac(r, HeirType.fatherUncleFull, 1);
      expectBlocked(r, HeirType.fatherUnclePaternal);
    });

    test('پسرِ عمویِ پدر (fatherCousinFull) عصبه است', () {
      final r = getCalculator(Madhab.jumhur).calculate(const InheritanceInput(
        estate: 6000,
        fatherCousinFull: 1,
      ));
      expectFrac(r, HeirType.fatherCousinFull, 1);
    });

    test('ترتیب عصبه: عمویِ پدر مقدم بر پسرِ عمویِ پدر', () {
      final r = getCalculator(Madhab.jumhur).calculate(const InheritanceInput(
        estate: 6000,
        fatherUncleFull: 1,
        fatherCousinFull: 1,
      ));
      expectFrac(r, HeirType.fatherUncleFull, 1);
      expectBlocked(r, HeirType.fatherCousinFull);
    });
  });

  group('پدرِ پدربزرگ (great grandfather)', () {
    test('great grandfather عصبه است', () {
      final r = getCalculator(Madhab.jumhur).calculate(const InheritanceInput(
        estate: 6000,
        greatGrandfather: 1,
      ));
      expectFrac(r, HeirType.greatGrandfather, 1);
    });

    test('پدربزرگ، پدرِ پدربزرگ را حجب میکند', () {
      final r = getCalculator(Madhab.jumhur).calculate(const InheritanceInput(
        estate: 6000,
        grandfather: 1,
        greatGrandfather: 1,
      ));
      expectFrac(r, HeirType.grandfather, 1);
      expectBlocked(r, HeirType.greatGrandfather);
    });
  });

  group('أصل مسائل الإخوة', () {
    test('father + mother + son → 1/6 : 1/6 : 2/3', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 6000,
        father: 1,
        mother: 1,
        son: 1,
      ));
      expectFrac(r, HeirType.father, 1 / 6);
      expectFrac(r, HeirType.mother, 1 / 6);
      expectFrac(r, HeirType.son, 2 / 3);
    });

    test('father + mother + daughter → 1/3 : 1/6 : 1/2', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 6000,
        father: 1,
        mother: 1,
        daughter: 1,
      ));
      expectFrac(r, HeirType.father, 1 / 3); // 1/6 فرض + تعصيب
      expectFrac(r, HeirType.mother, 1 / 6);
      expectFrac(r, HeirType.daughter, 1 / 2);
    });

    test('father + mother only → 2/3 : 1/3', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 6000,
        father: 1,
        mother: 1,
      ));
      expectFrac(r, HeirType.father, 2 / 3);
      expectFrac(r, HeirType.mother, 1 / 3);
    });

    test('daughter + full brother (عصبة مع الغير) → 1/2 : 1/2', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 6000,
        daughter: 1,
        fullBrother: 1,
      ));
      expectFrac(r, HeirType.daughter, 1 / 2);
      expectFrac(r, HeirType.fullBrother, 1 / 2);
    });

    test('daughter + full sister (عصبة مع الغير) → 1/2 : 1/2', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 6000,
        daughter: 1,
        fullSister: 1,
      ));
      expectFrac(r, HeirType.daughter, 1 / 2);
      expectFrac(r, HeirType.fullSister, 1 / 2);
    });

    test('full sister + paternal sister → 1/2 + 1/6, radd → 3/4 : 1/4', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 6000,
        fullSister: 1,
        paternalSister: 1,
      ));
      expectFrac(r, HeirType.fullSister, 3 / 4);
      expectFrac(r, HeirType.paternalSister, 1 / 4);
    });

    test('two full sisters + one paternal sister → 2/3 fard, paternal blocked',
        () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 6000,
        fullSister: 2,
        paternalSister: 1,
      ));
      // الأختان الشقيقتان بلغتا الثلثين، فلا مكملة للأخت لأب.
      expectFrac(r, HeirType.fullSister, 1); // 2/3 فرض + رد
      expectBlocked(r, HeirType.paternalSister);
      expect(r.totalAllocated, closeTo(6000, 0.001));
    });
  });

  group('حجب (blocking)', () {
    test('son blocks grandson and brothers', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 6000,
        son: 1,
        grandson: 1,
        fullBrother: 1,
      ));
      expectBlocked(r, HeirType.grandson);
      expectBlocked(r, HeirType.fullBrother);
    });

    test('father blocks grandfather and brothers', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 6000,
        father: 1,
        grandfather: 1,
        fullBrother: 1,
      ));
      expectBlocked(r, HeirType.grandfather);
      expectBlocked(r, HeirType.fullBrother);
    });

    test('mother blocks grandmother', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 6000,
        mother: 1,
        paternalGrandmother: 1,
      ));
      expectBlocked(r, HeirType.paternalGrandmother);
    });

    test('full brother blocks paternal brother but not maternal', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 6000,
        fullBrother: 1,
        paternalBrother: 1,
        maternalBrother: 1,
      ));
      expectBlocked(r, HeirType.paternalBrother);
      expectFrac(r, HeirType.fullBrother, 5 / 6);
      expectFrac(r, HeirType.maternalBrother, 1 / 6);
    });
  });

  group('تعصيب الترتيب (asaba order)', () {
    test('son of paternal uncle inherits only when no closer asaba', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 6000,
        paternalUncleSon: 1,
      ));
      expectFrac(r, HeirType.paternalUncleSon, 1);
    });

    test('nephew blocks paternal uncle', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 6000,
        nephewFull: 1,
        paternalUncle: 1,
      ));
      expectFrac(r, HeirType.nephewFull, 1);
      expectBlocked(r, HeirType.paternalUncle);
    });
  });

  group('توسعة 37 وارثًا (الأحفاد الأعمق والأعمام)', () {
    test('great grandson is asaba below grandson', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 4000,
        wife: 1,
        greatGrandson: 1,
      ));
      // نتيجة پسر فرع وارث است → همسر 1/8 و نتیجه پسر 7/8 (عصبه)
      expectFrac(r, HeirType.wife, 1 / 8);
      expectFrac(r, HeirType.greatGrandson, 7 / 8);
    });

    test('grandson blocks great grandson', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 4000,
        grandson: 1,
        greatGrandson: 1,
      ));
      expectFrac(r, HeirType.grandson, 1);
      expectBlocked(r, HeirType.greatGrandson);
    });

    test('great granddaughter: فرض 1/2 alone', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 6000,
        greatGranddaughter: 1,
      ));
      expectFrac(r, HeirType.greatGranddaughter, 1);
    });

    test('great granddaughter: تكملة 1/6 مع بنت واحدة', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 6000,
        daughter: 1,
        greatGranddaughter: 1,
        father: 1,
      ));
      expectFrac(r, HeirType.daughter, 1 / 2);
      expectFrac(r, HeirType.greatGranddaughter, 1 / 6);
      // الأب عصبة يأخذ الباقي (1/6)
      expectFrac(r, HeirType.father, 1 / 3);
    });

    test('nephew son (ابن ابن الأخ) asaba', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 6000,
        mother: 1,
        nephewSonFull: 1,
      ));
      expectFrac(r, HeirType.mother, 1 / 3);
      expectFrac(r, HeirType.nephewSonFull, 2 / 3);
    });

    test('nephewFull blocks nephewSon', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 6000,
        nephewFull: 1,
        nephewSonFull: 1,
      ));
      expectFrac(r, HeirType.nephewFull, 1);
      expectBlocked(r, HeirType.nephewSonFull);
    });

    test('عم لأب (paternal uncle half-brother of father) takes asaba', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 6000,
        paternalUnclePaternal: 1,
      ));
      expectFrac(r, HeirType.paternalUnclePaternal, 1);
    });

    test('عم شقيق يحجب عم لأب', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 6000,
        paternalUncle: 1,
        paternalUnclePaternal: 1,
      ));
      expectFrac(r, HeirType.paternalUncle, 1);
      expectBlocked(r, HeirType.paternalUnclePaternal);
    });

    test('ابن العم لأب (paternal cousin half) takes asaba', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 6000,
        paternalUncleSonPaternal: 1,
      ));
      expectFrac(r, HeirType.paternalUncleSonPaternal, 1);
    });

    test('عصبة بالغير (الأخت مع البنت) تسبق ابن الأخ', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 6000,
        daughter: 1,
        fullSister: 1,
        nephewFull: 1,
      ));
      expectFrac(r, HeirType.daughter, 1 / 2);
      expectFrac(r, HeirType.fullSister, 1 / 2);
      expectBlocked(r, HeirType.nephewFull);
    });
  });
}

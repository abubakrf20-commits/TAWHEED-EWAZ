import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/tools/inheritance/domain/inheritance_calculator.dart';
import 'package:tawheeed/features/tools/inheritance/domain/madhab_calculator.dart';
import 'package:tawheeed/features/tools/inheritance/domain/mandatory_will.dart';

/// بازبینی کامل دقت موتور میراث (فاز ۲ ممیزی).
///
/// - الف: مسائل کلاسیک قطعی (جدول عول، الرد، الحجب، التعصيب بالأخت)
/// - ب: مسائل محلولة من الكتب المعتمدة (الفقه الإسلامي وأدلته — الزحيلي،
///      نهاية المحتاج — الرملي) کپاسخ «قطعی»
/// - ج: فروق المذاهب والقوانين المدنية التسعة
/// - د: الوصية الواجبة
/// - هـ: مناسخات
/// - و: خواص پایدار (موازنه/فیوزینگ) روی هر ۱۴ مقدار مذهب

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

InheritanceInput _set(InheritanceInput i, HeirType t, int v) {
  switch (t) {
    case HeirType.husband:
      return i.copyWith(husband: v);
    case HeirType.wife:
      return i.copyWith(wife: v);
    case HeirType.mother:
      return i.copyWith(mother: v);
    case HeirType.father:
      return i.copyWith(father: v);
    case HeirType.maternalGrandmother:
      return i.copyWith(maternalGrandmother: v);
    case HeirType.paternalGrandmother:
      return i.copyWith(paternalGrandmother: v);
    case HeirType.greatMaternalGrandmother:
      return i.copyWith(greatMaternalGrandmother: v);
    case HeirType.paternalGreatGrandmotherFather:
      return i.copyWith(paternalGreatGrandmotherFather: v);
    case HeirType.paternalGreatGrandmotherMother:
      return i.copyWith(paternalGreatGrandmotherMother: v);
    case HeirType.grandfather:
      return i.copyWith(grandfather: v);
    case HeirType.greatGrandfather:
      return i.copyWith(greatGrandfather: v);
    case HeirType.daughter:
      return i.copyWith(daughter: v);
    case HeirType.son:
      return i.copyWith(son: v);
    case HeirType.granddaughter:
      return i.copyWith(granddaughter: v);
    case HeirType.grandson:
      return i.copyWith(grandson: v);
    case HeirType.greatGranddaughter:
      return i.copyWith(greatGranddaughter: v);
    case HeirType.greatGrandson:
      return i.copyWith(greatGrandson: v);
    case HeirType.fullSister:
      return i.copyWith(fullSister: v);
    case HeirType.fullBrother:
      return i.copyWith(fullBrother: v);
    case HeirType.paternalSister:
      return i.copyWith(paternalSister: v);
    case HeirType.paternalBrother:
      return i.copyWith(paternalBrother: v);
    case HeirType.maternalSister:
      return i.copyWith(maternalSister: v);
    case HeirType.maternalBrother:
      return i.copyWith(maternalBrother: v);
    case HeirType.nephewPaternal:
      return i.copyWith(nephewPaternal: v);
    case HeirType.nephewFull:
      return i.copyWith(nephewFull: v);
    case HeirType.nephewSonPaternal:
      return i.copyWith(nephewSonPaternal: v);
    case HeirType.nephewSonFull:
      return i.copyWith(nephewSonFull: v);
    case HeirType.paternalUnclePaternal:
      return i.copyWith(paternalUnclePaternal: v);
    case HeirType.paternalUncle:
      return i.copyWith(paternalUncle: v);
    case HeirType.paternalUncleSonPaternal:
      return i.copyWith(paternalUncleSonPaternal: v);
    case HeirType.paternalUncleSon:
      return i.copyWith(paternalUncleSon: v);
    case HeirType.paternalUncleGrandsonPaternal:
      return i.copyWith(paternalUncleGrandsonPaternal: v);
    case HeirType.paternalUncleGrandson:
      return i.copyWith(paternalUncleGrandson: v);
    case HeirType.fatherUnclePaternal:
      return i.copyWith(fatherUnclePaternal: v);
    case HeirType.fatherUncleFull:
      return i.copyWith(fatherUncleFull: v);
    case HeirType.fatherCousinPaternal:
      return i.copyWith(fatherCousinPaternal: v);
    case HeirType.fatherCousinFull:
      return i.copyWith(fatherCousinFull: v);
    case HeirType.paternalAunt:
      return i.copyWith(paternalAunt: v);
    case HeirType.maternalUncle:
      return i.copyWith(maternalUncle: v);
    case HeirType.maternalAunt:
      return i.copyWith(maternalAunt: v);
    case HeirType.nieceFull:
      return i.copyWith(nieceFull: v);
    case HeirType.niecePaternal:
      return i.copyWith(niecePaternal: v);
    case HeirType.nieceSon:
      return i.copyWith(nieceSon: v);
    case HeirType.uncleDaughter:
      return i.copyWith(uncleDaughter: v);
  }
}

InheritanceInput mk({
  double estate = 1000,
  Madhab madhab = Madhab.jumhur,
  Map<HeirType, int> heirs = const {},
}) {
  var i = InheritanceInput(estate: estate, madhab: madhab);
  for (final e in heirs.entries) {
    i = _set(i, e.key, e.value);
  }
  return i;
}

void main() {
  group('أ) جدول العول — مسائل کلاسیک قطعی', () {
    test('زوج + شقيقتان (1/2+2/3) → عول إلى 7: 3/7، 4/7', () {
      final r = getCalculator(Madhab.jumhur)
          .calculate(mk(heirs: {HeirType.husband: 1, HeirType.fullSister: 2}));
      expect(r.method, 'awl');
      expect(r.baseAsl, 6);
      expect(r.correctedAsl, 7);
      expectFrac(r, HeirType.husband, 3 / 7);
      expectFrac(r, HeirType.fullSister, 4 / 7);
    });

    test('زوج + شقيقة + أخت لأب → عول إلى 7', () {
      final r = getCalculator(Madhab.jumhur).calculate(mk(heirs: {
        HeirType.husband: 1,
        HeirType.fullSister: 1,
        HeirType.paternalSister: 1
      }));
      expect(r.method, 'awl');
      expectFrac(r, HeirType.husband, 3 / 7);
      expectFrac(r, HeirType.fullSister, 3 / 7);
      expectFrac(r, HeirType.paternalSister, 1 / 7);
    });

    test(
        'زوج + أم + بنت (فرع) → ردّ: 1/4، 3/16، 9/16 (الباقي يُردّ على غير الزوجين)',
        () {
      final r = getCalculator(Madhab.jumhur).calculate(mk(estate: 1600, heirs: {
        HeirType.husband: 1,
        HeirType.mother: 1,
        HeirType.daughter: 1
      }));
      expect(r.method, 'radd');
      expect(r.baseAsl, 12);
      expect(r.correctedAsl, 16);
      expectFrac(r, HeirType.husband, 4 / 16);
      expectFrac(r, HeirType.mother, 3 / 16);
      expectFrac(r, HeirType.daughter, 9 / 16);
      expect(r.totalAllocated, closeTo(1600, 0.01));
    });

    test('زوج + أم + بنتان → عول إلى 13: 3/13، 2/13، 8/13 (أم سدس بسبب الفرع)',
        () {
      final r = getCalculator(Madhab.jumhur).calculate(mk(estate: 1300, heirs: {
        HeirType.husband: 1,
        HeirType.mother: 1,
        HeirType.daughter: 2
      }));
      expect(r.method, 'awl');
      expect(r.baseAsl, 12);
      expect(r.correctedAsl, 13);
      expectFrac(r, HeirType.husband, 3 / 13);
      expectFrac(r, HeirType.mother, 2 / 13);
      expectFrac(r, HeirType.daughter, 8 / 13);
      expect(r.totalAllocated, closeTo(1300, 0.01));
    });

    test('زوجة + أب + أم + بنتان → عول إلى 27', () {
      for (final m in Madhab.values) {
        final r = getCalculator(m).calculate(mk(madhab: m, heirs: {
          HeirType.wife: 1,
          HeirType.father: 1,
          HeirType.mother: 1,
          HeirType.daughter: 2
        }));
        expect(r.method, 'awl', reason: '$m');
        expectFrac(r, HeirType.wife, 3 / 27, reason: '$m');
        expectFrac(r, HeirType.father, 4 / 27, reason: '$m');
        expectFrac(r, HeirType.mother, 4 / 27, reason: '$m');
        expectFrac(r, HeirType.daughter, 16 / 27, reason: '$m');
        expect(r.totalAllocated, closeTo(1000, 0.01), reason: '$m');
      }
    });

    test('زوج + أب + أم + بنتان → عول إلى 15 (الإجمال 15/12)', () {
      final r = getCalculator(Madhab.jumhur).calculate(mk(heirs: {
        HeirType.husband: 1,
        HeirType.father: 1,
        HeirType.mother: 1,
        HeirType.daughter: 2
      }));
      expect(r.method, 'awl');
      expect(r.correctedAsl, 15);
      expectFrac(r, HeirType.husband, 3 / 15);
      expectFrac(r, HeirType.father, 2 / 15);
      expectFrac(r, HeirType.mother, 2 / 15);
      expectFrac(r, HeirType.daughter, 8 / 15);
      expect(r.totalAllocated, closeTo(1000, 0.01));
    });

    test('زوج من غير فرع {جد + أخ شقيق} → مقاسمة 1/4 : 1/4 (جمهور)', () {
      final r = getCalculator(Madhab.jumhur).calculate(mk(heirs: {
        HeirType.husband: 1,
        HeirType.grandfather: 1,
        HeirType.fullBrother: 1
      }));
      expectFrac(r, HeirType.husband, 1 / 2);
      expectFrac(r, HeirType.grandfather, 1 / 4);
      expectFrac(r, HeirType.fullBrother, 1 / 4);
      expect(r.totalAllocated, closeTo(1000, 0.01));
    });

    test('حنفي/سعودي: الجد يحجب الأخ → جد 1/2، الأخ محجوب', () {
      for (final m in [Madhab.hanafi, Madhab.saudi]) {
        final r = getCalculator(m).calculate(mk(madhab: m, heirs: {
          HeirType.husband: 1,
          HeirType.grandfather: 1,
          HeirType.fullBrother: 1
        }));
        expectFrac(r, HeirType.husband, 1 / 2, reason: '$m');
        expectFrac(r, HeirType.grandfather, 1 / 2, reason: '$m');
        expectBlocked(r, HeirType.fullBrother, reason: '$m');
        expect(r.totalAllocated, closeTo(1000, 0.01), reason: '$m');
      }
    });

    test('زوج + أخ شقيق + أخوان لأم (بلا أم): الأخ قاصر الباقي 1/6', () {
      final r = getCalculator(Madhab.jumhur).calculate(mk(heirs: {
        HeirType.husband: 1,
        HeirType.fullBrother: 1,
        HeirType.maternalBrother: 2
      }));
      expectFrac(r, HeirType.husband, 1 / 2);
      expectFrac(r, HeirType.maternalBrother, 1 / 3);
      expectFrac(r, HeirType.fullBrother, 1 / 6);
      expect(r.totalAllocated, closeTo(1000, 0.01));
    });
  });

  group('ب) مسائل الرد — قطعي', () {
    test('زوج + أم → 1/2 : 1/2 (رد على الأم فقط)', () {
      final r = getCalculator(Madhab.jumhur)
          .calculate(mk(heirs: {HeirType.husband: 1, HeirType.mother: 1}));
      expect(r.method, 'radd');
      expectFrac(r, HeirType.husband, 1 / 2);
      expectFrac(r, HeirType.mother, 1 / 2);
    });

    test('زوجة + أم → 1/4 : 3/4', () {
      final r = getCalculator(Madhab.jumhur)
          .calculate(mk(heirs: {HeirType.wife: 1, HeirType.mother: 1}));
      expect(r.method, 'radd');
      expectFrac(r, HeirType.wife, 1 / 4);
      expectFrac(r, HeirType.mother, 3 / 4);
    });

    test('زوج + أم + بنت → 1/4 : 3/16 : 9/16 (رد للأم والبنت بنسبة فرضهما)',
        () {
      final r = getCalculator(Madhab.jumhur).calculate(mk(estate: 1600, heirs: {
        HeirType.husband: 1,
        HeirType.mother: 1,
        HeirType.daughter: 1
      }));
      expectFrac(r, HeirType.husband, 1 / 4);
      expectFrac(r, HeirType.mother, 3 / 16);
      expectFrac(r, HeirType.daughter, 9 / 16);
      expect(r.totalAllocated, closeTo(1600, 0.01));
    });

    test('أم + بنتان → 1/5 : 4/5 (رد على نسبة 1:4)', () {
      final r = getCalculator(Madhab.jumhur).calculate(
          mk(estate: 1500, heirs: {HeirType.mother: 1, HeirType.daughter: 2}));
      expect(r.method, 'radd');
      expectFrac(r, HeirType.mother, 1 / 5);
      expectFrac(r, HeirType.daughter, 4 / 5);
      expect(r.totalAllocated, closeTo(1500, 0.01));
    });

    test('زوجة + أخت شقيقة → 1/4 : 3/4', () {
      final r = getCalculator(Madhab.jumhur)
          .calculate(mk(heirs: {HeirType.wife: 1, HeirType.fullSister: 1}));
      expectFrac(r, HeirType.wife, 1 / 4);
      expectFrac(r, HeirType.fullSister, 3 / 4);
    });
  });

  group('ج) أحكام قطعية من الكتب المعتمدة', () {
    test('زوجة + شقيقة + أخ لأب + ابن أخ شقيق: 1/4، 1/2، 1/4، ولابن الأخ حجب',
        () {
      final r = getCalculator(Madhab.jumhur).calculate(mk(heirs: {
        HeirType.wife: 1,
        HeirType.fullSister: 1,
        HeirType.paternalBrother: 1,
        HeirType.nephewFull: 1
      }));
      expect(r.baseAsl, 4);
      expectFrac(r, HeirType.wife, 1 / 4);
      expectFrac(r, HeirType.fullSister, 1 / 2);
      expectFrac(r, HeirType.paternalBrother, 1 / 4);
      expectBlocked(r, HeirType.nephewFull);
    });

    test('زوج + أم + بنت + إخوة لأم + أخت لأب + عم شقيق: البنت تخلف، الرد للأم',
        () {
      final r = getCalculator(Madhab.jumhur).calculate(mk(heirs: {
        HeirType.husband: 1,
        HeirType.mother: 1,
        HeirType.daughter: 1,
        HeirType.maternalBrother: 2,
        HeirType.paternalSister: 1,
        HeirType.paternalUncle: 1
      }));
      expect(r.baseAsl, 12);
      expectFrac(r, HeirType.husband, 3 / 12);
      expectFrac(r, HeirType.mother, 2 / 12);
      expectFrac(r, HeirType.daughter, 6 / 12);
      expectFrac(r, HeirType.paternalSister, 1 / 12);
      expectBlocked(r, HeirType.maternalBrother);
      expectBlocked(r, HeirType.paternalUncle);
    });

    test(
        'بنت + بنت ابن + زوجتان + جدة + شقيقتان + أخ لأب: 1/2، 1/6، 1/8، 1/6، 1/24',
        () {
      final r =
          getCalculator(Madhab.jumhur).calculate(mk(estate: 24000, heirs: {
        HeirType.daughter: 1,
        HeirType.granddaughter: 1,
        HeirType.wife: 2,
        HeirType.paternalGrandmother: 1,
        HeirType.fullSister: 2,
        HeirType.paternalBrother: 1
      }));
      expect(r.baseAsl, 24);
      expect(r.totalAllocated, closeTo(24000, 0.01));
      expectFrac(r, HeirType.daughter, 12 / 24);
      expectFrac(r, HeirType.granddaughter, 4 / 24);
      expectFrac(r, HeirType.wife, 3 / 24);
      expectFrac(r, HeirType.paternalGrandmother, 4 / 24);
      expectFrac(r, HeirType.fullSister, 1 / 24);
      expectBlocked(r, HeirType.paternalBrother);
    });

    test(
        'بنت + بنت ابن + شقيقة + أم أم أم + أم أب: 1/2، 1/6، 1/6 (عصبة)، أم أب 1/6',
        () {
      final r = getCalculator(Madhab.jumhur).calculate(mk(heirs: {
        HeirType.daughter: 1,
        HeirType.granddaughter: 1,
        HeirType.fullSister: 1,
        HeirType.greatMaternalGrandmother: 1,
        HeirType.paternalGrandmother: 1
      }));
      expect(r.baseAsl, 6);
      expectFrac(r, HeirType.daughter, 3 / 6);
      expectFrac(r, HeirType.granddaughter, 1 / 6);
      expectFrac(r, HeirType.fullSister, 1 / 6);
      expectFrac(r, HeirType.paternalGrandmother, 1 / 6);
      expectBlocked(r, HeirType.greatMaternalGrandmother);
      expect(r.totalAllocated, closeTo(1000, 0.01));
    });

    test('شقيقة + أختان لأم + أخوان لأم + عم + أخ لأب: 1/2، 1/3، الأخ لأب 1/6',
        () {
      final r = getCalculator(Madhab.jumhur).calculate(mk(heirs: {
        HeirType.fullSister: 1,
        HeirType.maternalSister: 2,
        HeirType.maternalBrother: 2,
        HeirType.paternalUncle: 1,
        HeirType.paternalBrother: 1
      }));
      expect(r.baseAsl, 6);
      expectFrac(r, HeirType.fullSister, 3 / 6);
      // مجموع أولاد الأم (4) = 1/3؛ كل واحد بمفرده 1/6
      expectFrac(r, HeirType.maternalBrother, 1 / 6);
      expectFrac(r, HeirType.paternalBrother, 1 / 6);
      expectBlocked(r, HeirType.paternalUncle);
      expect(r.totalAllocated, closeTo(1000, 0.01));
    });

    test(
        'بنت + بنتا ابن + ابن ابن ابن + بنت ابن ابن + أب: 1/2، 1/6، أب 1/6، الحفيد 2:1',
        () {
      final r = getCalculator(Madhab.jumhur).calculate(mk(heirs: {
        HeirType.daughter: 1,
        HeirType.granddaughter: 2,
        HeirType.greatGrandson: 1,
        HeirType.greatGranddaughter: 1,
        HeirType.father: 1
      }));
      expect(r.baseAsl, 6);
      expectFrac(r, HeirType.daughter, 3 / 6);
      expectFrac(r, HeirType.granddaughter, 1 / 6);
      expectFrac(r, HeirType.father, 1 / 6);
      expectFrac(r, HeirType.greatGrandson, 1 / 9);
      expectFrac(r, HeirType.greatGranddaughter, 1 / 18);
      expect(r.totalAllocated, closeTo(1000, 0.01));
    });

    test(
        'بنت + شقيقة + شقيق + أخت لأب + أخت لأم: 1/2، عصبة الشقيقة 1/6، الشقيق 2/6',
        () {
      final r = getCalculator(Madhab.jumhur).calculate(mk(heirs: {
        HeirType.daughter: 1,
        HeirType.fullSister: 1,
        HeirType.fullBrother: 1,
        HeirType.paternalSister: 1,
        HeirType.maternalSister: 1
      }));
      expectFrac(r, HeirType.daughter, 3 / 6);
      expectFrac(r, HeirType.fullBrother, 2 / 6);
      expectFrac(r, HeirType.fullSister, 1 / 6);
      expectBlocked(r, HeirType.paternalSister);
      expectBlocked(r, HeirType.maternalSister);
    });

    test(
        'البنت تحجب الإخوة لأم إجماعًا: بنت + أخ لأم → البنت كل المال، الأخ محجوب',
        () {
      for (final m in Madhab.values) {
        final r = getCalculator(m).calculate(mk(
            madhab: m,
            heirs: {HeirType.daughter: 1, HeirType.maternalBrother: 1}));
        expectFrac(r, HeirType.daughter, 1, reason: '$m');
        expectBlocked(r, HeirType.maternalBrother, reason: '$m');
        expect(r.totalAllocated, closeTo(1000, 0.01), reason: '$m');
      }
    });

    test('بنت الابن تحجب الإخوة لأم إجماعًا', () {
      final r = getCalculator(Madhab.jumhur).calculate(mk(
          estate: 6000,
          heirs: {HeirType.granddaughter: 1, HeirType.maternalBrother: 1}));
      expectFrac(r, HeirType.granddaughter, 1);
      expectBlocked(r, HeirType.maternalBrother);
    });

    test('تعصيب بالأخت مع الغير مع فرع أنثى: بنت + شقيقة + أخ لأب', () {
      // الأخت الشقيقة مع البنت بمنزلة الأخ الشقيق → تأخذ الباقي وتحجب الأخ لأب
      final r = getCalculator(Madhab.jumhur).calculate(mk(estate: 2000, heirs: {
        HeirType.daughter: 1,
        HeirType.fullSister: 1,
        HeirType.paternalBrother: 1
      }));
      expectFrac(r, HeirType.daughter, 1 / 2);
      expectFrac(r, HeirType.fullSister, 1 / 2);
      expectBlocked(r, HeirType.paternalBrother);
      expect(r.totalAllocated, closeTo(2000, 0.01));
    });

    test('تعصيب بالأخت: بنت + أخت شقيقة → 1/2 : 1/2 (حديث معاذ)', () {
      final r = getCalculator(Madhab.jumhur)
          .calculate(mk(heirs: {HeirType.daughter: 1, HeirType.fullSister: 1}));
      expectFrac(r, HeirType.daughter, 1 / 2);
      expectFrac(r, HeirType.fullSister, 1 / 2);
    });

    test('تعصيب بالأخت: بنت + أخت لأب → 1/2 : 1/2', () {
      final r = getCalculator(Madhab.jumhur).calculate(
          mk(heirs: {HeirType.daughter: 1, HeirType.paternalSister: 1}));
      expectFrac(r, HeirType.daughter, 1 / 2);
      expectFrac(r, HeirType.paternalSister, 1 / 2);
    });

    test('بنتان + أخت لأب → 2/3 : 1/3', () {
      final r = getCalculator(Madhab.jumhur).calculate(
          mk(heirs: {HeirType.daughter: 2, HeirType.paternalSister: 1}));
      expectFrac(r, HeirType.daughter, 2 / 3);
      expectFrac(r, HeirType.paternalSister, 1 / 3);
    });
  });

  group('د) فروق المذاهب والقوانين التسعة', () {
    test('أردن/تونس: ردّ شامل للزوج مع البنت → 1/3 : 2/3', () {
      for (final m in [Madhab.jordanian, Madhab.tunisia1956]) {
        final r = getCalculator(m).calculate(
            mk(madhab: m, heirs: {HeirType.husband: 1, HeirType.daughter: 1}));
        expect(r.method, 'radd', reason: '$m');
        expectFrac(r, HeirType.husband, 1 / 3, reason: '$m');
        expectFrac(r, HeirType.daughter, 2 / 3, reason: '$m');
        expect(r.totalAllocated, closeTo(1000, 0.01), reason: '$m');
      }
    });

    test('أردن/تونس: زوج + أم → 3/5 : 2/5 (رد شامل)', () {
      for (final m in [Madhab.jordanian, Madhab.tunisia1956]) {
        final r = getCalculator(m).calculate(
            mk(madhab: m, heirs: {HeirType.husband: 1, HeirType.mother: 1}));
        expectFrac(r, HeirType.husband, 3 / 5, reason: '$m');
        expectFrac(r, HeirType.mother, 2 / 5, reason: '$m');
        expect(r.totalAllocated, closeTo(1000, 0.01), reason: '$m');
      }
    });

    test(
        'جمهور/حنفي/شافعي/مالكي/قوانين : رد على غير الزوجين → زوج + أم 1/2:1/2',
        () {
      for (final m in [
        Madhab.jumhur,
        Madhab.hanafi,
        Madhab.shafii,
        Madhab.maliki,
        Madhab.hanbali,
        Madhab.egyptian,
        Madhab.saudi,
        Madhab.algerian,
        Madhab.moroccan,
        Madhab.emirati,
        Madhab.omani,
        Madhab.kuwaiti,
      ]) {
        final r = getCalculator(m).calculate(
            mk(madhab: m, heirs: {HeirType.husband: 1, HeirType.mother: 1}));
        expectFrac(r, HeirType.husband, 1 / 2, reason: '$m');
        expectFrac(r, HeirType.mother, 1 / 2, reason: '$m');
      }
    });

    test('حنبلي/سعودي: الردّ على الإخوة لأم → زوج + أخت لأم = 1/2 : 1/2', () {
      for (final m in [Madhab.hanbali, Madhab.saudi]) {
        final r = getCalculator(m).calculate(mk(
            madhab: m,
            heirs: {HeirType.husband: 1, HeirType.maternalSister: 1}));
        expectFrac(r, HeirType.husband, 1 / 2, reason: '$m');
        expectFrac(r, HeirType.maternalSister, 1 / 2, reason: '$m');
        expect(r.totalAllocated, closeTo(1000, 0.011), reason: '$m');
      }
    });

    test('تونس 1956: الردّ شامل (مع الزوج) → زوج + أخت لأم = 3/4 : 1/4', () {
      final r = getCalculator(Madhab.tunisia1956).calculate(
          mk(heirs: {HeirType.husband: 1, HeirType.maternalSister: 1}));
      expectFrac(r, HeirType.husband, 3 / 4);
      expectFrac(r, HeirType.maternalSister, 1 / 4);
      expect(r.totalAllocated, closeTo(1000, 0.01));
    });

    test('باقي المذاهب: لا ردّ على الإخوة لأم → الباقي لبيت المال', () {
      for (final m in [
        Madhab.jumhur,
        Madhab.hanafi,
        Madhab.shafii,
        Madhab.maliki,
        Madhab.egyptian,
      ]) {
        final r = getCalculator(m).calculate(mk(
            madhab: m,
            heirs: {HeirType.husband: 1, HeirType.maternalSister: 1}));
        expectFrac(r, HeirType.husband, 1 / 2, reason: '$m');
        expectFrac(r, HeirType.maternalSister, 1 / 6, reason: '$m');
        expect(r.totalAllocated, closeTo(1000 * 2 / 3, 0.011), reason: '$m');
      }
    });

    test('أردني: الردّ شامل للأزواج — زوج + أخت لأم → 5/6 : 1/6', () {
      final r = getCalculator(Madhab.jordanian).calculate(
          mk(heirs: {HeirType.husband: 1, HeirType.maternalSister: 1}));
      expectFrac(r, HeirType.husband, 5 / 6);
      expectFrac(r, HeirType.maternalSister, 1 / 6);
      expect(r.totalAllocated, closeTo(1000, 0.01));
    });

    test('سعودي: لا مشتركة → الأشقاء محرومون من ثلث أولاد الأم', () {
      final r = getCalculator(Madhab.saudi).calculate(mk(heirs: {
        HeirType.husband: 1,
        HeirType.mother: 1,
        HeirType.maternalBrother: 2,
        HeirType.fullBrother: 1
      }));
      expectFrac(r, HeirType.husband, 1 / 2);
      expectFrac(r, HeirType.mother, 1 / 6);
      expectFrac(r, HeirType.maternalBrother, 1 / 3);
      expectBlocked(r, HeirType.fullBrother);
    });

    test('تونس 1956 (فصل 121): البنت تأخذ الباقي ردًا ويسقط الأخ', () {
      final r = getCalculator(Madhab.tunisia1956).calculate(
          mk(heirs: {HeirType.daughter: 1, HeirType.fullBrother: 1}));
      expectFrac(r, HeirType.daughter, 1);
      expectBlocked(r, HeirType.fullBrother);
    });

    test('تونس/مغرب: ذوو الأرحام لا يرثون (بيت المال)', () {
      for (final m in [Madhab.tunisia1956, Madhab.moroccan]) {
        final r = getCalculator(m)
            .calculate(mk(madhab: m, heirs: {HeirType.nieceSon: 1}));
        expectBlocked(r, HeirType.nieceSon, reason: '$m');
        expect(r.totalAllocated, 0, reason: '$m');
      }
    });

    test('بقية المذاهب والقوانين: ابن الأخت (ذو رحم) يرث كامل التركة', () {
      for (final m in [
        Madhab.jumhur,
        Madhab.hanafi,
        Madhab.shafii,
        Madhab.maliki,
        Madhab.hanbali,
        Madhab.egyptian,
        Madhab.saudi,
        Madhab.algerian,
        Madhab.jordanian,
        Madhab.emirati,
        Madhab.omani,
        Madhab.kuwaiti,
      ]) {
        final r = getCalculator(m)
            .calculate(mk(madhab: m, heirs: {HeirType.nieceSon: 1}));
        expectFrac(r, HeirType.nieceSon, 1, reason: '$m');
      }
    });

    test('ترتيب ذوي الأرحام: ابن الأخت مقدم على بنت العم', () {
      final r = getCalculator(Madhab.jumhur).calculate(
          mk(heirs: {HeirType.nieceSon: 1, HeirType.uncleDaughter: 1}));
      expectFrac(r, HeirType.nieceSon, 1);
      expectBlocked(r, HeirType.uncleDaughter);
    });

    test('فروض بلا عصبة + ذو رحم → أقرب ذي رحم يرث الباقي (زوج + عمه)', () {
      final r = getCalculator(Madhab.jumhur).calculate(
          mk(heirs: {HeirType.husband: 1, HeirType.paternalAunt: 1}));
      expect(r.method, 'distantKindred');
      expectFrac(r, HeirType.husband, 1 / 2);
      expectFrac(r, HeirType.paternalAunt, 1 / 2);
    });

    test('زوجة + بنت عم → زوجة ربع، بنت العم ثلاثة أرباع', () {
      final r = getCalculator(Madhab.jumhur)
          .calculate(mk(heirs: {HeirType.wife: 1, HeirType.uncleDaughter: 1}));
      expect(r.method, 'distantKindred');
      expectFrac(r, HeirType.wife, 1 / 4);
      expectFrac(r, HeirType.uncleDaughter, 3 / 4);
    });

    test('دختر + عمه → دختر نصف، عمه نصف (باقي)', () {
      final r = getCalculator(Madhab.jumhur).calculate(
          mk(heirs: {HeirType.daughter: 1, HeirType.paternalAunt: 1}));
      expect(r.method, 'distantKindred');
      expectFrac(r, HeirType.daughter, 1 / 2);
      expectFrac(r, HeirType.paternalAunt, 1 / 2);
    });

    test('کلاسیک سوری/لبنانی: زوج 1/4 و دختر 1/2 و بنت عم 1/4', () {
      final r = getCalculator(Madhab.jumhur).calculate(mk(heirs: {
        HeirType.husband: 1,
        HeirType.daughter: 1,
        HeirType.uncleDaughter: 1
      }));
      expect(r.method, 'distantKindred');
      expectFrac(r, HeirType.husband, 1 / 4);
      expectFrac(r, HeirType.daughter, 1 / 2);
      expectFrac(r, HeirType.uncleDaughter, 1 / 4);
    });

    test('عصبة موجود → ذوو الأرحام لا يرثون الباقي', () {
      final r = getCalculator(Madhab.jumhur)
          .calculate(mk(heirs: {HeirType.son: 1, HeirType.paternalAunt: 1}));
      expectFrac(r, HeirType.son, 1);
      expectBlocked(r, HeirType.paternalAunt);
    });

    test('تونس/مغرب: مع فروض بلا عصبة، أرحام محجوبون (ردّ/بیت‌المال)', () {
      for (final m in [Madhab.tunisia1956, Madhab.moroccan]) {
        final r = getCalculator(m).calculate(
            mk(madhab: m, heirs: {HeirType.wife: 1, HeirType.paternalAunt: 1}));
        // تونس 1956 الرد شامل الجميع (حتى الزوجة)؛ المغرب الزوجة مستثناة من الرد
        // فالبقية لا تُردّ عليها بل تُوقَف لبيت المال.
        expectFrac(r, HeirType.wife, m == Madhab.tunisia1956 ? 1.0 : 1 / 4,
            reason: '$m');
        expectBlocked(r, HeirType.paternalAunt, reason: '$m');
        expect(r.method, m == Madhab.tunisia1956 ? 'radd' : 'baytMal',
            reason: '$m');
      }
    });

    test('حنفي/جمهور: الأم ثلث أو سدس حسب عدد الإخوة — أم + أخ لأم + زوج', () {
      // أخ واحد لا يسقط ثلث الأم عند الجمهور (1/3)، والحنفي يسقطه (1/6)
      // لكن بعد الرد تُصبح النتيجة النهائية متساوية (أم = ثلث).
      final jumhur = getCalculator(Madhab.jumhur).calculate(mk(heirs: {
        HeirType.husband: 1,
        HeirType.mother: 1,
        HeirType.maternalBrother: 1
      }));
      expectFrac(jumhur, HeirType.husband, 1 / 2);
      expectFrac(jumhur, HeirType.mother, 1 / 3);
      expectFrac(jumhur, HeirType.maternalBrother, 1 / 6);
      final hanafi = getCalculator(Madhab.hanafi).calculate(mk(heirs: {
        HeirType.husband: 1,
        HeirType.mother: 1,
        HeirType.maternalBrother: 1
      }));
      // حنفي: الأخ الواحد يسقط الثلث للإم (سُدس)، ثم يُردّ الباقي على الأم فقط
      expectFrac(hanafi, HeirType.husband, 1 / 2);
      expectFrac(hanafi, HeirType.maternalBrother, 1 / 6);
      expectFrac(hanafi, HeirType.mother, 1 / 3);
    });
  });

  group('هـ) الوصية الواجبة', () {
    test('قانون مصر (م.76): مقدار = سهم الابن قياسًا، محدود‌بثلث التركة', () {
      final res = calculateMandatoryWill(
        const InheritanceInput(
          estate: 9000,
          wife: 1,
          daughter: 1,
          grandson: 1, // نوه يتيم (ابن الابن المتوفى)
        ),
        mandatoryWillLaws.first, // مصر — قانون وصية رقم 71 لسنة 1946
      );
      expect(res.applies, isTrue);
      // بالقتراض: الابن يكون 7/12 من التركة → محدود بالثلث = 3000
      expect(res.mandatoryAmount, closeTo(3000, 0.001));
      expect(res.orphans.length, 1);
      expect(res.orphans.first.amount, closeTo(3000, 0.001));
      // باقي التركة (6000) وزعت بين الزوجة والبنت
      expect(res.remainingResult.totalAllocated, closeTo(6000, 0.001));
      expect(res.totalAllocated, closeTo(9000, 0.001));
    });

    test('وصية واجبة داخل موتور المذاهب (madhab + applyMandatoryWill)', () {
      final r = getCalculator(Madhab.egyptian).calculate(const InheritanceInput(
        estate: 9000,
        wife: 1,
        daughter: 1,
        orphanGrandsons: 1,
        applyMandatoryWill: true,
      ));
      // يكسر من التركة ثم يوزع الباقي 6000؛ والوصية = الثلث
      expect(r.mandatoryWillAmount, closeTo(3000, 0.001));
      expect(r.estateForMainHeirs, closeTo(6000, 0.001));
      // سهم الوصية يُضاف كسهم مستقل في القائمة → المجموع = 9000
      expect(r.totalAllocated, closeTo(9000, 0.001));
      final will = shareOf(r, HeirType.grandson);
      expect(will, isNotNull);
      expect(will!.shareType, ShareType.mandatoryWill);
      expect(will.amount, closeTo(3000, 0.001));
    });
  });

  group('و) مناسخات (دو مرحله)', () {
    test('میراث زوجة + ابن + بنت ثم فوت الابن بزوجة وابنة', () {
      final c = calculateMunasakhat(
        'مناسخات ساده',
        [
          (
            'متوفی اول (پدر)',
            const InheritanceInput(estate: 8000, wife: 1, son: 1, daughter: 1)
          ),
          ('متوفی دوم (پسر)', const InheritanceInput(wife: 1, daughter: 1)),
        ],
      );
      expect(c.stages.length, 2);
      final stage1 = c.stages[0].result;
      expect(stage1.totalAllocated, closeTo(8000, 0.01));
      final stage2 = c.stages[1].result;
      // دارایی مرحله دوم = سهم پسر از مرحله اول (2/3 از 7000)
      expect(stage2.estate, closeTo(4666.6666, 0.5));
      expect(stage2.totalAllocated, closeTo(stage2.estate, 0.5));
    });
  });

  group('ز) خواص پایدار (فیوزینگ) روی هر ۱۴ مذهب', () {
    final rng = Random(20260214);
    const pool = [
      HeirType.husband,
      HeirType.wife,
      HeirType.mother,
      HeirType.father,
      HeirType.daughter,
      HeirType.son,
      HeirType.granddaughter,
      HeirType.grandson,
      HeirType.fullSister,
      HeirType.fullBrother,
      HeirType.paternalSister,
      HeirType.paternalBrother,
      HeirType.maternalSister,
      HeirType.maternalBrother,
      HeirType.grandfather,
      HeirType.greatGrandfather,
      HeirType.nephewFull,
      HeirType.nephewPaternal,
      HeirType.paternalUncle,
      HeirType.fatherUncleFull,
    ];

    for (var round = 0; round < 60; round++) {
      final makeup = <HeirType, int>{};
      final nTypes = 1 + rng.nextInt(6);
      for (var j = 0; j < nTypes; j++) {
        final t = pool[rng.nextInt(pool.length)];
        // همسر: مرد یا زن، نه هر دو
        if (t == HeirType.husband) makeup[HeirType.wife] = 0;
        if (t == HeirType.wife) makeup[HeirType.husband] = 0;
        makeup[t] = 1 + rng.nextInt(4);
      }
      final heirs = Map<HeirType, int>.from(makeup)
        ..removeWhere((k, v) => v == 0);

      test('نمونه $round: جمع سهمها، مقدار سهم، و صحت pipeline', () {
        for (final m in Madhab.values) {
          final input = mk(madhab: m, heirs: heirs);
          final r = getCalculator(m).calculate(input);
          final reason = '$m $heirs';

          if (r.shares.isEmpty) continue; // ممکن معتبر: همه محجوبند (بيت المال)
          var sumAmt = 0.0;
          var sumFrac = 0.0;
          for (final s in r.shares) {
            expect(ShareType.values, contains(s.shareType), reason: reason);
            expect(s.count, greaterThan(0), reason: reason);
            expect(s.fraction.toDouble(), greaterThan(0), reason: reason);
            expect(s.fraction.toDouble(), lessThanOrEqualTo(1), reason: reason);
            expect(s.amount, closeTo(1000 * s.fraction.toDouble(), 0.01),
                reason: '$reason ${s.type}');
            sumAmt += s.amount;
            sumFrac += s.fraction.toDouble();
          }
          // مجموع الفروض لا يتجاوز التركة (العول يضبط، والرد يكمل)
          expect(sumFrac, lessThanOrEqualTo(1 + 1e-9), reason: reason);
          expect(sumAmt, closeTo(1000 * sumFrac, 0.02), reason: reason);
          expect(sumAmt, lessThanOrEqualTo(1000 + 0.02), reason: reason);

          // وارث حاضر وأعطى سهمًا → مبلغ موجب
          for (final e in heirs.entries) {
            final s = shareOf(r, e.key);
            if (s != null) {
              expect(s.amount, greaterThan(0), reason: reason);
            }
          }
        }
      });
    }
  });
}

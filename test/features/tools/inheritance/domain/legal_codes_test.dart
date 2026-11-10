import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/tools/inheritance/domain/inheritance_calculator.dart';
import 'package:tawheeed/features/tools/inheritance/domain/madhab_calculator.dart';

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

void main() {
  group('قانون سعودی: الجد یحجب الإخوة', () {
    test('جد + أخ شقیق: الجد یأخذ کل الباقی', () {
      final r = getCalculator(Madhab.saudi).calculate(const InheritanceInput(
        estate: 12000,
        grandfather: 1,
        fullBrother: 1,
      ));
      expectFrac(r, HeirType.grandfather, 1);
      expectBlocked(r, HeirType.fullBrother);
    });

    test('تفاوت با جمهور: الجمهور یقاسم (الجد 1/2)', () {
      final r = getCalculator(Madhab.jumhur).calculate(const InheritanceInput(
        estate: 12000,
        grandfather: 1,
        fullBrother: 1,
      ));
      expectFrac(r, HeirType.grandfather, 1 / 2);
      expectFrac(r, HeirType.fullBrother, 1 / 2);
    });
  });

  group('قانون سعودی: عدم تطبیق المسألة المشترکة', () {
    test('زوج + أم + أخوان لأم + أخ شقیق: الأشقاء لا یشرکون', () {
      final r = getCalculator(Madhab.saudi).calculate(const InheritanceInput(
        estate: 9000,
        husband: 1,
        mother: 1,
        maternalBrother: 2,
        fullBrother: 1,
      ));
      // زوج 1/2، أم 1/6، الإخوة لأم 1/3 (بلا مشارکة الأخ الشقیق).
      expectFrac(r, HeirType.husband, 1 / 2);
      expectFrac(r, HeirType.mother, 1 / 6);
      expectFrac(r, HeirType.maternalBrother, 1 / 3);
      expectBlocked(r, HeirType.fullBrother);
    });

    test('الجمهور یطبق المشترکة: الأشقاء یشارکون', () {
      final r = getCalculator(Madhab.jumhur).calculate(const InheritanceInput(
        estate: 9000,
        husband: 1,
        mother: 1,
        maternalBrother: 2,
        fullBrother: 1,
      ));
      expectFrac(r, HeirType.maternalBrother, 2 / 9);
      expectFrac(r, HeirType.fullBrother, 1 / 9);
    });
  });

  group('قانون سعودی: لا أکدریة (الجد یأخذ کل الباقی)', () {
    test('زوج + أم + جد + أخت شقیقة', () {
      final r = getCalculator(Madhab.saudi).calculate(const InheritanceInput(
        estate: 27000,
        husband: 1,
        mother: 1,
        grandfather: 1,
        fullSister: 1,
      ));
      expectFrac(r, HeirType.husband, 1 / 2);
      expectFrac(r, HeirType.mother, 1 / 3);
      expectFrac(r, HeirType.grandfather, 1 / 6);
      expectBlocked(r, HeirType.fullSister);
    });
  });

  group('قانون أردنی: الرد یشمل الزوج (إصلاح 2019)', () {
    test('زوج + أم: الباقی یوزع علیهما معًا', () {
      final r =
          getCalculator(Madhab.jordanian).calculate(const InheritanceInput(
        estate: 6000,
        husband: 1,
        mother: 1,
      ));
      expect(r.method, 'radd');
      expectFrac(r, HeirType.husband, 3 / 5);
      expectFrac(r, HeirType.mother, 2 / 5);
    });

    test('الجمهور: الزوج لا یرد إلیه', () {
      final r = getCalculator(Madhab.jumhur).calculate(const InheritanceInput(
        estate: 6000,
        husband: 1,
        mother: 1,
      ));
      expect(r.method, 'radd');
      expectFrac(r, HeirType.husband, 1 / 2);
      expectFrac(r, HeirType.mother, 1 / 2);
    });
  });

  group('قانون أردنی: مقاسمة الجد للأخوات (إصلاح 2019)', () {
    test('جد + أخت شقیقة: مقاسمة 2:1', () {
      final r =
          getCalculator(Madhab.jordanian).calculate(const InheritanceInput(
        estate: 9000,
        grandfather: 1,
        fullSister: 1,
      ));
      expectFrac(r, HeirType.grandfather, 2 / 3);
      expectFrac(r, HeirType.fullSister, 1 / 3);
    });

    test('الحنفی یحجبها (خلاف قبل الإصلاح)', () {
      final r = getCalculator(Madhab.hanafi).calculate(const InheritanceInput(
        estate: 9000,
        grandfather: 1,
        fullSister: 1,
      ));
      expectFrac(r, HeirType.grandfather, 1);
      expectBlocked(r, HeirType.fullSister);
    });
  });

  group('تونس 1956: إصلاح إلغاء تعصیب الإخوة على البنت', () {
    test('بنت + أخ شقیق: البنت تأخذ کل الترکة', () {
      final r =
          getCalculator(Madhab.tunisia1956).calculate(const InheritanceInput(
        estate: 6000,
        daughter: 1,
        fullBrother: 1,
      ));
      expectFrac(r, HeirType.daughter, 1);
      expectBlocked(r, HeirType.fullBrother);
    });

    test('بنت + زوج + أخ شقیق: زوج 1/4 والبنت 3/4', () {
      final r =
          getCalculator(Madhab.tunisia1956).calculate(const InheritanceInput(
        estate: 12000,
        daughter: 1,
        husband: 1,
        fullBrother: 1,
      ));
      expectFrac(r, HeirType.husband, 1 / 4);
      expectFrac(r, HeirType.daughter, 3 / 4);
      expectBlocked(r, HeirType.fullBrother);
    });

    test('بنت + عمو (عم): البنت تأخذ کل الترکة', () {
      final r =
          getCalculator(Madhab.tunisia1956).calculate(const InheritanceInput(
        estate: 6000,
        daughter: 1,
        paternalUncle: 1,
      ));
      expectFrac(r, HeirType.daughter, 1);
      expectBlocked(r, HeirType.paternalUncle);
    });

    test('بنتان + أخ شقیق: البنتان تأخذان کل الترکة', () {
      final r =
          getCalculator(Madhab.tunisia1956).calculate(const InheritanceInput(
        estate: 6000,
        daughter: 2,
        fullBrother: 1,
      ));
      expectFrac(r, HeirType.daughter, 1);
      expectBlocked(r, HeirType.fullBrother);
    });
  });

  group('تونس 1956: الرد شامل حتى للزوجین', () {
    test('همسر + مادر: ردّ على الطرفین', () {
      final r =
          getCalculator(Madhab.tunisia1956).calculate(const InheritanceInput(
        estate: 12000,
        wife: 1,
        mother: 1,
      ));
      expect(r.method, 'radd');
      expectFrac(r, HeirType.wife, 3 / 7);
      expectFrac(r, HeirType.mother, 4 / 7);
    });
  });

  group('تونس/المغرب: ذوو الأرحام لا یرثون', () {
    test('تونس: عمه فقط → بیت المال (بلا حصة)', () {
      final r = getCalculator(Madhab.tunisia1956)
          .calculate(const InheritanceInput(estate: 6000, paternalAunt: 1));
      expect(r.shares, isEmpty);
      expect(r.method, isNot('distantKindred'));
    });

    test('المغرب: عمه فقط → بیت المال (بلا حصة)', () {
      final r = getCalculator(Madhab.moroccan)
          .calculate(const InheritanceInput(estate: 6000, paternalAunt: 1));
      expect(r.shares, isEmpty);
      expect(r.method, isNot('distantKindred'));
    });

    test('الجمهور: العمه (ذو رحم) ترث کل الترکة', () {
      final r = getCalculator(Madhab.jumhur)
          .calculate(const InheritanceInput(estate: 6000, paternalAunt: 1));
      expect(r.method, 'distantKindred');
      expectFrac(r, HeirType.paternalAunt, 1);
    });
  });

  group('قوانین الجمهور (مصری/کویتی/اماراتی/عمانی): الجد یقاسم', () {
    for (final m in [
      Madhab.egyptian,
      Madhab.kuwaiti,
      Madhab.emirati,
      Madhab.omani,
    ]) {
      test('جد + أخ شقیق ($m): مقاسمة 1/2', () {
        final r = getCalculator(m).calculate(const InheritanceInput(
          estate: 12000,
          grandfather: 1,
          fullBrother: 1,
        ));
        expectFrac(r, HeirType.grandfather, 1 / 2, reason: '$m');
        expectFrac(r, HeirType.fullBrother, 1 / 2, reason: '$m');
      });
    }
  });

  group('الوصایا المتعددة والموافقة على تجاوز الثلث', () {
    test('ثلاث وصایا تساوی الثلث بدون موافقة → تنفذ کلًا', () {
      final r = getCalculator(Madhab.jumhur).calculate(const InheritanceInput(
        estate: 9000,
        willAmount: 1000,
        willAmount2: 1000,
        willAmount3: 1000,
        son: 1,
      ));
      expect(r.netEstate, 6000);
      expect(r.warnings, isEmpty);
    });

    test('وصایا تتجاوز الثلث بدون موافقة → تقتطع إلى الثلث', () {
      final r = getCalculator(Madhab.jumhur).calculate(const InheritanceInput(
        estate: 9000,
        willAmount: 2000,
        willAmount2: 1500,
        willAmount3: 1000, // مجموع 4500 > 3000
        son: 1,
      ));
      expect(r.netEstate, 6000);
      expect(r.warnings, isNotEmpty);
    });

    test('مع موافقة الورثة: تجاوز الثلث جایز', () {
      final r = getCalculator(Madhab.jumhur).calculate(const InheritanceInput(
        estate: 9000,
        willAmount: 2000,
        willAmount2: 1500,
        willAmount3: 1000,
        heirsConsentExceedThird: true,
        son: 1,
      ));
      expect(r.netEstate, 4500);
      expect(r.warnings, isEmpty);
    });

    test('الوصية من ثلث الباقي بعد الديون (لا من ثلث التركة الكاملة)', () {
      // تركة 9000 وعليها ديون 3000 → الثلث من الباقي (6000) هو 2000.
      final r = getCalculator(Madhab.jumhur).calculate(const InheritanceInput(
        estate: 9000,
        debts: 3000,
        willAmount: 3000,
        son: 1,
      ));
      expect(r.netEstate, 9000 - 3000 - 2000); // 4000
      expect(r.warnings, isNotEmpty);
    });

    test('مع الديون والموافقة: الأساس هو الباقي بعد الديون', () {
      final r = getCalculator(Madhab.jumhur).calculate(const InheritanceInput(
        estate: 9000,
        debts: 3000,
        willAmount: 3000,
        heirsConsentExceedThird: true,
        son: 1,
      ));
      expect(r.netEstate, 9000 - 3000 - 3000); // 3000
      expect(r.warnings, isEmpty);
    });

    test('ديون تتجاوز التركة: الوصية تصفر ولا تنفذ', () {
      final r = getCalculator(Madhab.jumhur).calculate(const InheritanceInput(
        estate: 9000,
        debts: 15000,
        willAmount: 3000,
        son: 1,
      ));
      // الوصية لا تنفذ (الثلث من الباقي سلبيًا = صفر)، والديون تلتهم التركة.
      expect(r.netEstate, -6000);
      expect(r.totalAllocated, 0);
      expect(r.warnings, isNotEmpty);
    });
  });

  group('الوصية الواجبة في الحاسبة الرئيسية', () {
    test(
        'أب + نوه‌های پسرِ فوت‌شده: وصیت واجبه به‌اندازه سهم پدر (محدود به ثلث)',
        () {
      final r = getCalculator(Madhab.jumhur).calculate(const InheritanceInput(
        estate: 9000,
        applyMandatoryWill: true,
        orphanGrandsons: 1,
        orphanGranddaughters: 1,
        father: 1,
      ));
      // سهم الابن في الحالة الفرضية = 5/6 × 9000 = 7500 → محدود إلى 3000.
      expect(r.mandatoryWillAmount, closeTo(3000, 0.001));
      final gs = shareOf(r, HeirType.grandson)!;
      final gd = shareOf(r, HeirType.granddaughter)!;
      expect(gs.shareType, ShareType.mandatoryWill);
      expect(gs.amount, closeTo(2000, 0.001));
      expect(gd.amount, closeTo(1000, 0.001));
      expectFrac(r, HeirType.father, 1);
      expect(r.totalAllocated, closeTo(9000, 0.001));
    });

    test('با وجود پسر زنده: وصیت واجبه سهم یک‌پسر است نه همه پسرها', () {
      final r = getCalculator(Madhab.jumhur).calculate(const InheritanceInput(
        estate: 9000,
        applyMandatoryWill: true,
        orphanGrandsons: 1,
        son: 1,
      ));
      // الفرض: ابنان → سهم الابن المتوفى = 1/2 من 9000 = 4500 → محدود إلى 3000.
      expect(r.mandatoryWillAmount, closeTo(3000, 0.001));
      expect(shareOf(r, HeirType.grandson)!.amount, closeTo(3000, 0.001));
      // الباقي 6000 للابن الحي.
      expectFrac(r, HeirType.son, 1);
      expect(r.totalAllocated, closeTo(9000, 0.001));
    });

    test('الابن وحده (الفرضی) یأخذ کل الترکه → الوصیة الواجبة تقتطع إلى الثلث',
        () {
      final r = getCalculator(Madhab.jumhur).calculate(const InheritanceInput(
        estate: 9000,
        applyMandatoryWill: true,
        orphanGrandsons: 2,
        orphanGranddaughters: 1,
      ));
      // الفرض: الابن وحده يرث كل التركة (9000) → محدود إلى 3000.
      expect(r.mandatoryWillAmount, closeTo(3000, 0.001));
      // التقسيم 2:1 للذكر والأنثى: وحدتان لكل ذكر وواحدة للأنثى (4:1).
      expect(shareOf(r, HeirType.grandson)!.amount, closeTo(2400, 0.001));
      expect(shareOf(r, HeirType.granddaughter)!.amount, closeTo(600, 0.001));
      expect(r.totalAllocated, closeTo(3000, 0.001));
    });

    test('الوصية الواجبة تحسب من ثلث الباقي بعد الديون', () {
      final r = getCalculator(Madhab.jumhur).calculate(const InheritanceInput(
        estate: 9000,
        debts: 3000,
        applyMandatoryWill: true,
        orphanGrandsons: 1,
        father: 1,
      ));
      // الباقي 6000: سهم الابن الفرضي 5/6×6000 = 5000 → محدود إلى 2000.
      expect(r.mandatoryWillAmount, closeTo(2000, 0.001));
      expect(shareOf(r, HeirType.grandson)!.amount, closeTo(2000, 0.001));
      expectFrac(r, HeirType.father, 1);
      expect(r.totalAllocated, closeTo(6000, 0.001));
    });

    test('بدون تفعيل الوصية الواجبة: النوه وراث عادی', () {
      final r = getCalculator(Madhab.jumhur).calculate(const InheritanceInput(
        estate: 9000,
        grandson: 1,
        father: 1,
      ));
      expect(r.mandatoryWillAmount, 0);
      // الابن (النوه) يرث تعصيبًا كما هو مألوف.
      expect(shareOf(r, HeirType.grandson)!.shareType, ShareType.asaba);
      expectFrac(r, HeirType.grandson, 5 / 6);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/tools/zakat/domain/entities/zakat_input.dart';
import 'package:tawheeed/features/tools/zakat/domain/entities/zakat_result.dart';
import 'package:tawheeed/features/tools/zakat/domain/services/zakat_calculator.dart';

void main() {
  group('ZakatCalculator — القواعد المذهبية', () {
    test('نصاب النقود عند الجمهور = قيمة نصاب الذهب', () {
      const input = ZakatInput(
        goldPricePerGram24: 1000,
        silverPricePerGram: 1000,
      );
      // نصاب الذهب 85×1000 = 85000؛ نصاب الفضة 595×1000 = 595000.
      expect(ZakatCalculator.moneyNisabThreshold(input), 85000);
    });

    test('نصاب النقود عند الحنابلة والأحناف = أقل النصابين', () {
      const input = ZakatInput(
        madhab: ZakatMadhab.hanafi,
        goldPricePerGram24: 1000,
        silverPricePerGram: 100,
      );
      // أقلُّ من (85000) و(59500) هو 59500.
      expect(ZakatCalculator.moneyNisabThreshold(input), 59500);
    });

    test('عيار الذهب والفضة يحددان وزن الخالص', () {
      final r = ZakatCalculator.calculate(const ZakatInput(
        goldGrams: 100,
        goldKarat: 18,
        silverGrams: 1000,
        silverFineness: 500,
        goldPricePerGram24: 1000,
        silverPricePerGram: 1000,
      ));
      expect(r.goldPureGrams, closeTo(75, 0.001));
      expect(r.silverPureGrams, closeTo(500, 0.001));
    });

    test('زكاة العسل العشر عند الحنابلة فقط (نصاب 62 كجم)', () {
      const hanbali = ZakatInput(
        madhab: ZakatMadhab.hanbali,
        honeyKg: 62,
      );
      final r1 = ZakatCalculator.calculate(hanbali);
      expect(r1.honeyNisabReached, isTrue);
      expect(r1.honeyZakatKg, closeTo(6.2, 0.001));

      const shafii = ZakatInput(
        madhab: ZakatMadhab.shafii,
        honeyKg: 100,
      );
      final r2 = ZakatCalculator.calculate(shafii);
      expect(r2.honeyNisabReached, isFalse);
      expect(r2.honeyZakatKg, 0);
    });

    test('زكاة الخيل عند الحنفية فقط، مع الحول، ونصابها خمس فأكثر', () {
      final hanafi = ZakatCalculator.calculate(const ZakatInput(
        madhab: ZakatMadhab.hanafi,
        hawlComplete: true,
        horses: 5,
        horsePricePerHead: 1000,
      ));
      expect(hanafi.horsesNisabMet, isTrue);
      expect(hanafi.horsesZakatValue, closeTo(125, 0.001));

      // بدون حول، زكاة الخيل لا تجب حتى عند الحنفية
      expect(
        ZakatCalculator.calculate(const ZakatInput(
          madhab: ZakatMadhab.hanafi,
          horses: 5,
          horsePricePerHead: 1000,
        )).horsesZakatValue,
        0,
      );

      // عند غير الحنفية لا زكاة في الخيل
      expect(
        ZakatCalculator.calculate(const ZakatInput(
          horses: 5,
          horsePricePerHead: 1000,
          hawlComplete: true,
        )).horsesZakatValue,
        0,
      );

      final below = ZakatCalculator.calculate(const ZakatInput(horses: 4));
      expect(below.horsesNisabMet, isFalse);
      expect(below.horsesZakatValue, 0);
    });

    test('زكاة كنز الجاهلية الخُمس', () {
      final r = ZakatCalculator.calculate(const ZakatInput(kanzValue: 10000));
      expect(r.kanzZakat, closeTo(2000, 0.001));
    });

    test('الدين المرجو يزكّى كل سنة مع الحول، وغير المرجو محتمل پس از قبض', () {
      const withHawl = ZakatInput(
        goldPricePerGram24: 1000,
        friendlyDebt: 85000,
        uglyDebt: 85000,
        hawlComplete: true,
      );
      final r1 = ZakatCalculator.calculate(withHawl);
      expect(r1.friendlyDebtZakat, closeTo(2125, 0.001));
      // غير مرجو: محتمل پس از وصول، برای 1 سال (نمایش اطلاعاتی)
      expect(r1.uglyDebtZakat, closeTo(2125, 0.001));

      // بدون حول، دين مرجو واجب نیست
      const noHawl = ZakatInput(
        goldPricePerGram24: 1000,
        friendlyDebt: 85000,
      );
      expect(ZakatCalculator.calculate(noHawl).friendlyDebtZakat, 0);
    });

    test('الخلطة: عند الحنابلة والأحناف دون غيرهم', () {
      // كلٌّ منفردًا دون النصاب، لكن المجموع يبلغ أقل النصابين.
      final r = ZakatCalculator.calculate(const ZakatInput(
        madhab: ZakatMadhab.hanbali,
        goldPricePerGram24: 1000,
        silverPricePerGram: 1000,
        cashAndBank: 90000,
        goldGrams: 20,
        silverGrams: 200,
      ));
      expect(r.mixtureApplied, isTrue);
      expect(r.mixtureDescription, isNotEmpty);

      // عند الجمهور/الشافعي لا يُجمع بين الذهب والفضة.
      final shafii = ZakatCalculator.calculate(const ZakatInput(
        madhab: ZakatMadhab.shafii,
        goldPricePerGram24: 1000,
        silverPricePerGram: 1000,
        cashAndBank: 90000,
        goldGrams: 20,
        silverGrams: 200,
      ));
      expect(shafii.mixtureApplied, isFalse);
    });

    test('السوم: المالكية لا تشترطه في بهيمة الأنعام', () {
      const maliki = ZakatInput(
        madhab: ZakatMadhab.maliki,
        sheep: 40,
        hawlComplete: true,
      );
      expect(ZakatCalculator.livestockNisabMet(maliki, 40, 0, 0, 0), isTrue);

      const jumhur = ZakatInput(
        sheep: 40,
        hawlComplete: true,
      );
      expect(ZakatCalculator.livestockNisabMet(jumhur, 40, 0, 0, 0), isFalse);
      expect(
        ZakatCalculator.calculate(
          const ZakatInput(
            sheep: 40,
            hawlComplete: true,
          ),
        ).grazingNote,
        isNotEmpty,
      );
    });

    test('لا تُدرج بهيمة الأنعام غير السائمة عند الجمهور', () {
      final result = ZakatCalculator.calculate(const ZakatInput(
        sheep: 40,
        hawlComplete: true,
      ));
      expect(result.livestockNisabMet, isFalse);
      expect(result.hasLivestockZakat, isFalse);
      expect(result.hasZakat, isFalse);
    });

    test('تجاوز وصف دام لا يتخطى شروط النصاب والسوم والحول', () {
      final result = ZakatCalculator.calculate(const ZakatInput(
        sheep: 40,
        hawlComplete: true,
        livestockDescriptionOverride: 'وصف يدوي',
      ));
      expect(result.livestockDescription, isEmpty);
      expect(result.hasLivestockZakat, isFalse);
    });

    test('تُدرج بهيمة الأنعام غير السائمة عند المالكية', () {
      final result = ZakatCalculator.calculate(const ZakatInput(
        madhab: ZakatMadhab.maliki,
        sheep: 40,
        hawlComplete: true,
      ));
      expect(result.livestockNisabMet, isTrue);
      expect(result.hasLivestockZakat, isTrue);
    });

    test('الحول الناقص أو النصاب الناقص لا ينتج زكاة دام', () {
      final noHawl = ZakatCalculator.calculate(const ZakatInput(
        madhab: ZakatMadhab.maliki,
        sheep: 40,
        grazing: true,
      ));
      final belowNisab = ZakatCalculator.calculate(const ZakatInput(
        madhab: ZakatMadhab.maliki,
        sheep: 39,
        grazing: true,
        hawlComplete: true,
      ));
      expect(noHawl.hasLivestockZakat, isFalse);
      expect(belowNisab.hasLivestockZakat, isFalse);
    });

    test('زكاة الأنعام: الأربعون شاة فأكثر', () {
      expect(ZakatCalculator.livestockDue(40, 0, 0, 0), contains('1'));
      expect(ZakatCalculator.livestockDue(0, 0, 30, 0), contains('تیبع'));
      expect(ZakatCalculator.livestockDue(0, 0, 0, 5), contains('گوسفند'));
      expect(ZakatCalculator.livestockDue(10, 0, 0, 0), isEmpty);
    });
  });

  group('ZakatCalculator — مسیرهای اصلی نقدی', () {
    // قیمت طلا 1000 ⇒ نصاب طلا 85×1000 = 85000 (مبنای خودکارِ جمهور).
    test('زکات نقدی اصلی: خالصِ بالای نصاب × 2.5٪', () {
      final r = ZakatCalculator.calculate(const ZakatInput(
        goldPricePerGram24: 1000,
        cashAndBank: 200000,
        hawlComplete: true,
      ));
      expect(r.netAssets, 200000);
      expect(r.meetsNisab, isTrue);
      expect(r.zakatAmount, closeTo(5000, 0.001));
    });

    test('بدهی از دارایی کسر می‌شود و زکات بر خالص است', () {
      final r = ZakatCalculator.calculate(const ZakatInput(
        goldPricePerGram24: 1000,
        cashAndBank: 200000,
        debts: 100000,
        hawlComplete: true,
      ));
      expect(r.netAssets, 100000);
      expect(r.zakatAmount, closeTo(2500, 0.001));

      // بدهی زیاد، خالص را زیر نصاب می‌بَرَد ⇒ زکات نقدی ندارد.
      final below = ZakatCalculator.calculate(const ZakatInput(
        goldPricePerGram24: 1000,
        cashAndBank: 200000,
        debts: 130000,
        hawlComplete: true,
      ));
      expect(below.netAssets, 70000);
      expect(below.meetsNisab, isFalse);
      expect(below.zakatAmount, 0);
    });

    test('کالای تجاری در دارایی زکات‌پذیر نقدی شمرده می‌شود', () {
      final r = ZakatCalculator.calculate(const ZakatInput(
        goldPricePerGram24: 1000,
        businessValue: 200000,
        hawlComplete: true,
      ));
      expect(r.businessValue, 200000);
      expect(r.netAssets, 200000);
      expect(r.meetsNisab, isTrue);
      expect(r.zakatAmount, closeTo(5000, 0.001));
    });

    test('گردکردن تعهد: به بالا تا تومانِ کامل', () {
      // 100001 × 0.025 = 2500.025 ⇒ 2501 (به بالا، تا حق فقرا کم نشود).
      final r = ZakatCalculator.calculate(const ZakatInput(
        goldPricePerGram24: 1000,
        cashAndBank: 100001,
        hawlComplete: true,
      ));
      expect(r.zakatAmount, closeTo(2501, 0.001));
    });
  });

  group('ZakatCalculator — مبنای نصاب (طلا/نقره)', () {
    test('انتخاب صریح مبنای نقره آستانه را پایین می‌آورد (حتی مذهب غیرحنفی)',
        () {
      const base =
          ZakatInput(goldPricePerGram24: 1000, silverPricePerGram: 100);
      // خودکار/جمهور → طلا 85000.
      expect(ZakatCalculator.moneyNisabThreshold(base), 85000);
      // طلا → همان 85000؛ نقره → 595×100 = 59500.
      expect(
        ZakatCalculator.moneyNisabThreshold(
            base.copyWith(nisabBasis: ZakatNisabBasis.gold)),
        85000,
      );
      expect(
        ZakatCalculator.moneyNisabThreshold(
            base.copyWith(nisabBasis: ZakatNisabBasis.silver)),
        59500,
      );
    });

    test('مبنای نقره در calculate باعث وجوب زکات می‌شود که مبنای طلا ندارد',
        () {
      const input = ZakatInput(
        goldPricePerGram24: 1000,
        silverPricePerGram: 100,
        cashAndBank: 60000,
        hawlComplete: true,
      );
      final silver = ZakatCalculator.calculate(
          input.copyWith(nisabBasis: ZakatNisabBasis.silver));
      expect(silver.nisabThreshold, 59500);
      expect(silver.meetsNisab, isTrue);
      expect(silver.zakatAmount, closeTo(1500, 0.001));

      final gold = ZakatCalculator.calculate(
          input.copyWith(nisabBasis: ZakatNisabBasis.gold));
      expect(gold.nisabThreshold, 85000);
      expect(gold.meetsNisab, isFalse);
      expect(gold.zakatAmount, 0);
    });

    test('مبنای خودکار رفتار پیشین مذهبی را حفظ می‌کند', () {
      const base = ZakatInput(
        goldPricePerGram24: 1000,
        silverPricePerGram: 100,
        cashAndBank: 60000,
        hawlComplete: true,
      );
      final jumhur = ZakatCalculator.calculate(base);
      final hanafi =
          ZakatCalculator.calculate(base.copyWith(madhab: ZakatMadhab.hanafi));
      expect(jumhur.nisabThreshold, 85000); // جمهور → طلا
      expect(hanafi.nisabThreshold, 59500); // حنفی → نقره
    });
  });

  group('ZakatCalculator — نبودِ قیمت (هیچ پیش‌فرضی)', () {
    test('بدون قیمت، نصاب نامعلوم می‌ماند و هیچ زکاتی جعل نمی‌شود', () {
      final r = ZakatCalculator.calculate(const ZakatInput(
        cashAndBank: 3000000000,
        hawlComplete: true,
      ));
      // قبلاً اینجا قیمت ثابت ۲۵٬۰۰۰٬۰۰۰ تومان فرض می‌شد؛ حالا نبودِ قیمت
      // یعنی «قابل محاسبه نیست»، نه یک عدد کهنه.
      expect(r.priceKnown, isFalse);
      expect(r.nisabThreshold, 0);
      expect(r.meetsNisab, isFalse);
      expect(r.zakatAmount, 0);
    });

    test('با قیمت کاربر، نصاب همان قیمت را دنبال می‌کند', () {
      final r = ZakatCalculator.calculate(const ZakatInput(
        goldPricePerGram24: 30000000,
        silverPricePerGram: 900000,
        cashAndBank: 3000000000,
        hawlComplete: true,
      ));
      expect(r.priceKnown, isTrue);
      expect(r.nisabThreshold, closeTo(85 * 30000000, 1));
    });
  });

  group('ZakatResult — الخصائص الجديدة', () {
    test('hasSpecialZakat يشمل الكنز والديون', () {
      const r = ZakatResult(
        totalAssets: 0,
        totalDebts: 0,
        netAssets: 0,
        goldValue: 0,
        goldPureGrams: 0,
        silverValue: 0,
        cashAndBank: 0,
        businessValue: 0,
        nisabThreshold: 0,
        nisabBasis: '',
        zakatAmount: 0,
        zakatRate: 0.025,
        meetsNisab: false,
        hawlComplete: false,
        explanation: '',
        breakdownLines: [],
        kanzZakat: 100,
      );
      expect(r.hasSpecialZakat, isTrue);
      expect(r.hasZakat, isTrue);
    });

    test('التعليمة الافتراضية للمذهب الجمهور', () {
      const r = ZakatResult(
        totalAssets: 0,
        totalDebts: 0,
        netAssets: 0,
        goldValue: 0,
        goldPureGrams: 0,
        silverValue: 0,
        cashAndBank: 0,
        businessValue: 0,
        nisabThreshold: 0,
        nisabBasis: '',
        zakatAmount: 0,
        zakatRate: 0.025,
        meetsNisab: false,
        hawlComplete: false,
        explanation: '',
        breakdownLines: [],
      );
      expect(r.madhab, ZakatMadhab.jumhur);
    });
  });
}

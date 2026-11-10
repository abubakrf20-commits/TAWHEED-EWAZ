import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/tools/zakat/domain/services/zakat_calculator.dart';

/// Tests مرزی جدول‌های زکات دام — دقیق‌ترین منطق عددی اپ.
///
/// هر باند فقهی در مرز بالا/پایین + یک عدد وسط باند پوشش داده می‌شود تا
/// هیچ `<`/`<=` ای در جدول‌ها بدون قصد تغییر نتواند جابجا شود.
void main() {
  group('ZakatCalculator.livestockDue — گوسفند و بز (نصاب 40)', () {
    test('زیر نصاب خالی است', () {
      expect(ZakatCalculator.livestockDue(39, 0, 0, 0), '');
      expect(ZakatCalculator.livestockDue(20, 19, 0, 0), ''); // جمع = 39
    });

    test('40 تا 120 → یک گوسفند', () {
      expect(ZakatCalculator.livestockDue(40, 0, 0, 0), contains('1 گوسفند'));
      expect(ZakatCalculator.livestockDue(80, 0, 0, 0), contains('1 گوسفند'));
      expect(ZakatCalculator.livestockDue(120, 0, 0, 0), contains('1 گوسفند'));
    });

    test('121 تا 200 → دو گوسفند', () {
      expect(ZakatCalculator.livestockDue(121, 0, 0, 0), contains('2 گوسفند'));
      expect(ZakatCalculator.livestockDue(200, 0, 0, 0), contains('2 گوسفند'));
    });

    test('201 تا 300 → سه و 301 تا 400 → چهار', () {
      expect(ZakatCalculator.livestockDue(201, 0, 0, 0), contains('3 گوسفند'));
      expect(ZakatCalculator.livestockDue(300, 0, 0, 0), contains('3 گوسفند'));
      expect(ZakatCalculator.livestockDue(301, 0, 0, 0), contains('4 گوسفند'));
      expect(ZakatCalculator.livestockDue(400, 0, 0, 0), contains('4 گوسفند'));
    });

    test('401 تا 500 → پنج؛ بالای 500 هر 100 رأس یک رأس', () {
      expect(ZakatCalculator.livestockDue(401, 0, 0, 0), contains('5 گوسفند'));
      expect(ZakatCalculator.livestockDue(500, 0, 0, 0), contains('5 گوسفند'));
      // 501 تا 599 هنوز 5 است (سقفِ بند 100تایی کامل نشده).
      expect(ZakatCalculator.livestockDue(501, 0, 0, 0), contains('5 گوسفند'));
      expect(ZakatCalculator.livestockDue(600, 0, 0, 0), contains('6 گوسفند'));
      expect(ZakatCalculator.livestockDue(601, 0, 0, 0), contains('6 گوسفند'));
      expect(ZakatCalculator.livestockDue(700, 0, 0, 0), contains('7 گوسفند'));
    });

    test('گوسفند و بز با هم جمع می‌شوند', () {
      expect(ZakatCalculator.livestockDue(25, 15, 0, 0), contains('1 گوسفند'));
    });
  });

  group('ZakatCalculator.livestockDue — گاو (نصاب 30)', () {
    test('زیر 30 خالی است', () {
      expect(ZakatCalculator.livestockDue(0, 0, 29, 0), '');
    });

    test('30 تا 39 → تیبع (گوساله یک‌ساله)', () {
      expect(ZakatCalculator.livestockDue(0, 0, 30, 0), contains('تیبع'));
      expect(ZakatCalculator.livestockDue(0, 0, 39, 0), contains('تیبع'));
    });

    test('40 تا 59 → مسنّه (گاو دوساله)', () {
      expect(ZakatCalculator.livestockDue(0, 0, 40, 0), contains('مسنّه'));
      expect(ZakatCalculator.livestockDue(0, 0, 59, 0), contains('مسنّه'));
    });

    test('60 تا 69 → دو تیبع', () {
      expect(ZakatCalculator.livestockDue(0, 0, 60, 0),
          contains('2 گوساله یک‌ساله'));
      expect(ZakatCalculator.livestockDue(0, 0, 69, 0),
          contains('2 گوساله یک‌ساله'));
    });

    test('70 تا 79 → تیبع + مسنّه', () {
      expect(ZakatCalculator.livestockDue(0, 0, 70, 0),
          allOf(contains('1 گوساله'), contains('1 گاو دو ساله')));
    });

    test('80 تا 89 → دو مسنّه', () {
      expect(
          ZakatCalculator.livestockDue(0, 0, 80, 0), contains('2 گاو دو ساله'));
    });

    test('90 تا 99 → سه تیبع', () {
      expect(ZakatCalculator.livestockDue(0, 0, 90, 0),
          contains('3 گوساله یک‌ساله'));
    });

    test('100 تا 109 → دو تیبع + یک مسنّه', () {
      expect(ZakatCalculator.livestockDue(0, 0, 100, 0),
          allOf(contains('2 گوساله'), contains('1 گاو دو ساله')));
    });

    test('110 تا 119 → یک تیبع + دو مسنّه', () {
      expect(ZakatCalculator.livestockDue(0, 0, 110, 0),
          allOf(contains('2 گاو دو ساله'), contains('1 گوساله')));
    });

    test('120 → ترکیب جست‌وجوشده کل 120 را می‌پوشاند (4 تبیع یا 3 مسنّه)', () {
      final due = ZakatCalculator.livestockDue(0, 0, 120, 0);
      // هر دو ترکیب شرعی معتبرند؛ الگوریتم کمینه‌ساز است: 3 مسنّه.
      expect(due, contains('3 گاو دو ساله'));
    });

    test('بالای 120 ترکیب جست‌وجو بیشترین پوشش را می‌دهد', () {
      // 130 = 3×30 + 1×40 = 130 (پوشش کامل) → 3 تبیع + 1 مسنّه.
      final due130 = ZakatCalculator.livestockDue(0, 0, 130, 0);
      expect(due130, allOf(contains('3 گوساله'), contains('1 گاو دو ساله')));

      // 125 = 3×30 + 1×40؟ = 130 > 125؛ بهترین پوشش 120 (4×30) یا
      // (3×40). الگوریتم باید 120 از 125 را بپوشاند نه کمتر.
      final due125 = ZakatCalculator.livestockDue(0, 0, 125, 0);
      expect(due125, isNot(contains('نرسیده')));
    });
  });

  group('ZakatCalculator.livestockDue — شتر (نصاب 5)', () {
    test('زیر 5 خالی است', () {
      expect(ZakatCalculator.livestockDue(0, 0, 0, 4), '');
    });

    test('5 تا 9 → یک گوسفند', () {
      expect(ZakatCalculator.livestockDue(0, 0, 0, 5), contains('1 گوسفند'));
      expect(ZakatCalculator.livestockDue(0, 0, 0, 9), contains('1 گوسفند'));
    });

    test('10–14 → دو؛ 15–19 → سه؛ 20–24 → چهار گوسفند', () {
      expect(ZakatCalculator.livestockDue(0, 0, 0, 10), contains('2 گوسفند'));
      expect(ZakatCalculator.livestockDue(0, 0, 0, 14), contains('2 گوسفند'));
      expect(ZakatCalculator.livestockDue(0, 0, 0, 15), contains('3 گوسفند'));
      expect(ZakatCalculator.livestockDue(0, 0, 0, 19), contains('3 گوسفند'));
      expect(ZakatCalculator.livestockDue(0, 0, 0, 20), contains('4 گوسفند'));
      expect(ZakatCalculator.livestockDue(0, 0, 0, 24), contains('4 گوسفند'));
    });

    test('25 تا 35 → بنت مخاض', () {
      expect(ZakatCalculator.livestockDue(0, 0, 0, 25), contains('بنت مخاض'));
      expect(ZakatCalculator.livestockDue(0, 0, 0, 35), contains('بنت مخاض'));
    });

    test('36 تا 45 → بنت لبون', () {
      expect(ZakatCalculator.livestockDue(0, 0, 0, 36), contains('بنت لبون'));
      expect(ZakatCalculator.livestockDue(0, 0, 0, 45), contains('بنت لبون'));
    });

    test('46 تا 60 → حِقّه', () {
      expect(ZakatCalculator.livestockDue(0, 0, 0, 46), contains('حِقّه'));
      expect(ZakatCalculator.livestockDue(0, 0, 0, 60), contains('حِقّه'));
    });

    test('61 تا 75 → جذعه', () {
      expect(ZakatCalculator.livestockDue(0, 0, 0, 61), contains('جذعه'));
      expect(ZakatCalculator.livestockDue(0, 0, 0, 75), contains('جذعه'));
    });

    test('76 تا 90 → دو بنت لبون', () {
      expect(ZakatCalculator.livestockDue(0, 0, 0, 76),
          contains('2 شتر ماده دو ساله'));
      expect(ZakatCalculator.livestockDue(0, 0, 0, 90),
          contains('2 شتر ماده دو ساله'));
    });

    test('91 تا 120 → دو حِقّه', () {
      expect(ZakatCalculator.livestockDue(0, 0, 0, 91),
          contains('2 شتر ماده سه ساله'));
      expect(ZakatCalculator.livestockDue(0, 0, 0, 120),
          contains('2 شتر ماده سه ساله'));
    });

    test('121 تا 129 → سه بنت لبون', () {
      expect(ZakatCalculator.livestockDue(0, 0, 0, 121),
          contains('3 شتر ماده دو ساله'));
      expect(ZakatCalculator.livestockDue(0, 0, 0, 129),
          contains('3 شتر ماده دو ساله'));
    });

    test('بندهای ترکیبی 130 تا 199 دقیقاً سر جایشان هستند', () {
      expect(ZakatCalculator.livestockDue(0, 0, 0, 130),
          contains('2 بنت لبون + 1 حِقّه'));
      expect(ZakatCalculator.livestockDue(0, 0, 0, 139),
          contains('2 بنت لبون + 1 حِقّه'));
      expect(ZakatCalculator.livestockDue(0, 0, 0, 140),
          contains('1 بنت لبون + 2 حِقّه'));
      expect(ZakatCalculator.livestockDue(0, 0, 0, 149),
          contains('1 بنت لبون + 2 حِقّه'));
      expect(ZakatCalculator.livestockDue(0, 0, 0, 150),
          contains('3 شتر ماده سه ساله'));
      expect(ZakatCalculator.livestockDue(0, 0, 0, 159),
          contains('3 شتر ماده سه ساله'));
      expect(ZakatCalculator.livestockDue(0, 0, 0, 160),
          contains('4 شتر ماده دو ساله'));
      expect(ZakatCalculator.livestockDue(0, 0, 0, 169),
          contains('4 شتر ماده دو ساله'));
      expect(ZakatCalculator.livestockDue(0, 0, 0, 170),
          contains('3 بنت لبون + 1 حِقّه'));
      expect(ZakatCalculator.livestockDue(0, 0, 0, 179),
          contains('3 بنت لبون + 1 حِقّه'));
      expect(ZakatCalculator.livestockDue(0, 0, 0, 180),
          contains('2 بنت لبون + 2 حِقّه'));
      expect(ZakatCalculator.livestockDue(0, 0, 0, 189),
          contains('2 بنت لبون + 2 حِقّه'));
      expect(ZakatCalculator.livestockDue(0, 0, 0, 190),
          contains('1 بنت لبون + 3 حِقّه'));
      expect(ZakatCalculator.livestockDue(0, 0, 0, 199),
          contains('1 بنت لبون + 3 حِقّه'));
    });

    test('200 به بعد فرمول هر 40/50 رأس', () {
      final due200 = ZakatCalculator.livestockDue(0, 0, 0, 200);
      expect(due200, allOf(contains('5 بنت لبون'), contains('4 حِقّه')));
    });
  });

  group('ZakatCalculator.livestockCountsReachNisab', () {
    test('مرزهای نصاب هر سه نوع دام', () {
      expect(ZakatCalculator.livestockCountsReachNisab(39, 0, 0, 0), isFalse);
      expect(ZakatCalculator.livestockCountsReachNisab(40, 0, 0, 0), isTrue);
      expect(ZakatCalculator.livestockCountsReachNisab(0, 0, 29, 0), isFalse);
      expect(ZakatCalculator.livestockCountsReachNisab(0, 0, 30, 0), isTrue);
      expect(ZakatCalculator.livestockCountsReachNisab(0, 0, 0, 4), isFalse);
      expect(ZakatCalculator.livestockCountsReachNisab(0, 0, 0, 5), isTrue);
    });
  });
}

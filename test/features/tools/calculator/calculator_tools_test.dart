import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/tools/calculator/data/calculator_tools.dart';

void main() {
  group('percent', () {
    test('percentOf', () {
      expect(CalculatorTools.percentOf(200, 15), closeTo(30, 1e-9));
      expect(CalculatorTools.percentOf(50, 100), 50);
      expect(CalculatorTools.percentOf(0, 10), 0);
    });

    test('percentRatio', () {
      expect(CalculatorTools.percentRatio(30, 200), closeTo(15, 1e-9));
      expect(CalculatorTools.percentRatio(25, 100), 25);
      expect(CalculatorTools.percentRatio(10, 0), isNull);
    });

    test('percentIncrease / percentDecrease', () {
      expect(CalculatorTools.percentIncrease(1000, 15), closeTo(1150, 1e-9));
      expect(CalculatorTools.percentDecrease(1000, 15), closeTo(850, 1e-9));
      expect(CalculatorTools.percentIncrease(200, 0), 200);
      expect(CalculatorTools.percentDecrease(100, 100), 0);
    });
  });

  group('discount', () {
    test('discountAmount and finalPrice', () {
      expect(CalculatorTools.discountAmount(500000, 20), 100000);
      expect(CalculatorTools.finalPrice(500000, 20), 400000);
      expect(CalculatorTools.finalPrice(100, 0), 100);
      expect(CalculatorTools.finalPrice(100, 100), 0);
    });
  });

  group('age', () {
    test('ageFrom computes years/months/days', () {
      final birth = DateTime(2000, 6, 15);
      final today = DateTime(2024, 6, 15);
      final a = CalculatorTools.ageFrom(birth, today);
      expect(a.years, 24);
      expect(a.months, 0);
      expect(a.days, 0);
    });

    test('ageFrom handles month/day borrow', () {
      final birth = DateTime(2000, 1, 15);
      final today = DateTime(2024, 3);
      final a = CalculatorTools.ageFrom(birth, today);
      expect(a.years, 24);
      expect(a.months, 1);
      expect(a.days, 15);
    });

    test('ageFrom never reports negative days', () {
      final birth = DateTime(2000, 1, 31);
      final today = DateTime(2024, 3);
      final a = CalculatorTools.ageFrom(birth, today);
      expect(a.years, 24);
      expect(a.months, 1);
      expect(a.days, greaterThanOrEqualTo(0));
    });

    test('ageFrom future birth is zero', () {
      final birth = DateTime(2030);
      final today = DateTime(2024, 6, 15);
      final a = CalculatorTools.ageFrom(birth, today);
      expect(a.years, 0);
      expect(a.months, 0);
      expect(a.days, 0);
    });

    test('totalDaysBetween and totalMonths', () {
      expect(
          CalculatorTools.totalDaysBetween(
              DateTime(2024), DateTime(2024, 1, 31)),
          30);
      expect(
          CalculatorTools.totalDaysBetween(DateTime(2000), DateTime(2000)), 0);
      expect(CalculatorTools.totalMonths(DateTime(2000), DateTime(2001)),
          closeTo(12, 1));
    });

    test('daysToNextBirthday', () {
      // تولد بعدی در همان سال
      expect(
          CalculatorTools.daysToNextBirthday(
              DateTime(1990, 12, 25), DateTime(2024, 12)),
          24);
      // تولد امسال گذشته؛ سال بعد
      expect(
          CalculatorTools.daysToNextBirthday(
              DateTime(1990, 1, 15), DateTime(2024, 3)),
          greaterThan(300));
      // امروز تولد است
      expect(
          CalculatorTools.daysToNextBirthday(
              DateTime(1990, 3), DateTime(2024, 3)),
          0);
      // ۲۹ بهمن در سال غیرکبیسه → ۲۸ بهمن
      expect(
          CalculatorTools.daysToNextBirthday(
              DateTime(2000, 2, 29), DateTime(2023, 2, 27)),
          1);
    });
  });

  group('unit conversion', () {
    test('length', () {
      expect(CalculatorTools.convertLength(1, 'کیلومتر', 'متر'), 1000);
      expect(CalculatorTools.convertLength(100, 'سانتی‌متر', 'متر'), 1);
      expect(CalculatorTools.convertLength(1, 'مایل', 'کیلومتر'),
          closeTo(1.609344, 1e-6));
    });

    test('mass', () {
      expect(CalculatorTools.convertMass(1, 'کیلوگرم', 'گرم'), 1000);
      expect(CalculatorTools.convertMass(500, 'گرم', 'کیلوگرم'), 0.5);
      expect(CalculatorTools.convertMass(1, 'تُن', 'کیلوگرم'), 1000);
    });

    test('temperature', () {
      expect(
          CalculatorTools.convertTemperature(0, 'سانتی‌گراد', 'فارنهایت'), 32);
      expect(CalculatorTools.convertTemperature(100, 'سانتی‌گراد', 'فارنهایت'),
          212);
      expect(CalculatorTools.convertTemperature(0, 'سانتی‌گراد', 'کلوین'),
          closeTo(273.15, 1e-9));
      expect(CalculatorTools.convertTemperature(32, 'فارنهایت', 'سانتی‌گراد'),
          closeTo(0, 1e-9));
    });

    test('volume', () {
      expect(CalculatorTools.convertVolume(1, 'لیتر', 'میلی‌لیتر'), 1000);
      expect(CalculatorTools.convertVolume(1, 'متر مکعب', 'لیتر'), 1000);
      expect(CalculatorTools.convertVolume(1, 'گالن (آمریکا)', 'لیتر'),
          closeTo(3.785411784, 1e-9));
    });

    test('time', () {
      expect(CalculatorTools.convertTime(1, 'ساعت', 'دقیقه'), 60);
      expect(CalculatorTools.convertTime(1, 'روز', 'ساعت'), 24);
      expect(CalculatorTools.convertTime(60, 'ثانیه', 'دقیقه'), 1);
    });

    test('data', () {
      expect(CalculatorTools.convertData(1, 'گیگابایت', 'مگابایت'), 1024);
      expect(CalculatorTools.convertData(1024, 'کیلوبایت', 'مگابایت'), 1);
      expect(CalculatorTools.convertData(1, 'ترابایت', 'گیگابایت'), 1024);
    });
  });

  group('format', () {
    test('format drops trailing zeros', () {
      expect(CalculatorTools.format(10.0), '10');
      expect(CalculatorTools.format(2.5), '2.5');
      expect(CalculatorTools.format(1 / 3), contains('.'));
    });

    test('formatMoney adds thousands separators', () {
      expect(CalculatorTools.formatMoney(500000), '500,000');
      expect(CalculatorTools.formatMoney(1234567.5), '1,234,567.5');
      expect(CalculatorTools.formatMoney(99), '99');
    });

    test('fa renders English digits', () {
      expect(CalculatorTools.en(1403), '1403');
      expect(CalculatorTools.en(0), '0');
    });
  });

  group('qard hasan', () {
    test('qardHasanMonthlyPayment divides principal evenly', () {
      final m = CalculatorTools.qardHasanMonthlyPayment(1200000, 12)!;
      expect(m, closeTo(100000, 1e-9));
    });

    test('qardHasanMonthlyPayment handles months that do not divide evenly',
        () {
      final m = CalculatorTools.qardHasanMonthlyPayment(1000000, 3)!;
      expect(m, closeTo(333333.33, 0.01));
    });

    test('invalid inputs return null', () {
      expect(CalculatorTools.qardHasanMonthlyPayment(0, 12), isNull);
      expect(CalculatorTools.qardHasanMonthlyPayment(1000, 0), isNull);
      expect(CalculatorTools.qardHasanMonthlyPayment(-5, 12), isNull);
    });
  });
}

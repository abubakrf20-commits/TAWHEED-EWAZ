import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/shared/models/app_currency.dart';

void main() {
  group('AppCurrency', () {
    test('تومان واحد پیش‌فرض و تنها واحد ایرانیِ بدون تبدیل است', () {
      expect(AppCurrency.toman.isIranian, isTrue);
      expect(AppCurrency.toman.unit, 'تومان');
    });

    test('ریال دیگر در فهرست واحدها نیست', () {
      // کاربر «تومان کافیه» را خواست: نه ریال ایران، نه ریال سعودی.
      expect(AppCurrency.values.map((c) => c.label), isNot(contains('ریال')));
      expect(AppCurrency.fromCode('SAR'), AppCurrency.toman);
    });

    test('واحدهای غیرایرانی قیمت پیش‌فرض ندارند', () {
      for (final c in [
        AppCurrency.dollar,
        AppCurrency.dirham,
        AppCurrency.afghani,
        AppCurrency.euro,
      ]) {
        expect(c.isIranian, isFalse, reason: c.code);
      }
    });

    test('کدها یکتا و پایدارند', () {
      final codes = AppCurrency.values.map((c) => c.code).toSet();
      expect(codes.length, AppCurrency.values.length);
      expect(AppCurrency.toman.code, 'IRT');
    });

    test('fromCode ناشناخته یا خالی به تومان برمی‌گردد', () {
      expect(AppCurrency.fromCode(null), AppCurrency.toman);
      expect(AppCurrency.fromCode(''), AppCurrency.toman);
      expect(AppCurrency.fromCode('XXX'), AppCurrency.toman);
      expect(AppCurrency.fromCode('AFN'), AppCurrency.afghani);
    });
  });
}

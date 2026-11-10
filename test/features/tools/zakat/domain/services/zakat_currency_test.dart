import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/shared/models/app_currency.dart';
import 'package:tawheeed/features/tools/zakat/domain/entities/zakat_input.dart';
import 'package:tawheeed/features/tools/zakat/domain/services/zakat_calculator.dart';

/// محاسبه در واحدهای غیرتومانی.
///
/// ریاضیات زکات واحدless است، پس تنها چیزی که باید تضمین شود این است که
/// قیمت‌های پیش‌فرض ایرانی هرگز به واحد دیگر سرایت نکنند و «نصاب نامعلوم»
/// هرگز به «زکات واجب شد» ترجمه نشود.
void main() {
  group('ZakatCalculator — واحد پول', () {
    test('تومان: قیمت دستی، واحد و مبلغ درست', () {
      const input = ZakatInput(
        cashAndBank: 3000000000,
        hawlComplete: true,
        goldPricePerGram24: 25000000,
      );
      final r = ZakatCalculator.calculate(input);
      expect(r.priceKnown, isTrue);
      expect(r.currency, AppCurrency.toman);
      expect(r.unit, 'تومان');
      // 85 گرم × 25,000,000 = 2,125,000,000 → 2.5٪ از 3 میلیارد
      expect(r.nisabThreshold, 2125000000);
      expect(r.zakatAmount, 75000000);
    });

    test('دلار بدون قیمت: نصاب نامعلوم است و زکاتی واجب نمی‌شود', () {
      const input = ZakatInput(
        cashAndBank: 50000,
        hawlComplete: true,
        currency: AppCurrency.dollar,
      );
      final r = ZakatCalculator.calculate(input);
      expect(r.priceKnown, isFalse);
      expect(r.meetsNisab, isFalse);
      expect(r.zakatAmount, 0, reason: 'نصاب صفر نباید همه را واجب کند');
      expect(r.nisabThreshold, 0,
          reason: 'قیمت تومانی نباید به دلار تفسیر شود');
      expect(r.explanation, contains('قیمت روز'));
      expect(r.breakdownLines.join(' '), contains('دلار'));
      expect(r.breakdownLines.join(' '), isNot(contains('تومان')));
    });

    test('دلار با قیمت دستی: نصاب و زکات به دلار حساب می‌شود', () {
      const input = ZakatInput(
        cashAndBank: 6000,
        hawlComplete: true,
        goldPricePerGram24: 60,
        currency: AppCurrency.dollar,
      );
      final r = ZakatCalculator.calculate(input);
      expect(r.priceKnown, isTrue);
      // 85 گرم × 60 دلار = 5,100 دلار نصاب
      expect(r.nisabThreshold, 5100);
      expect(r.zakatAmount, 150); // 2.5٪ از 6,000
      expect(r.unit, 'دلار');
    });

    test('افغانی: واحد در متن نتیجه و توضیح ظاهر می‌شود', () {
      const input = ZakatInput(
        cashAndBank: 600000,
        hawlComplete: true,
        goldPricePerGram24: 6000,
        currency: AppCurrency.afghani,
      );
      final r = ZakatCalculator.calculate(input);
      expect(r.priceKnown, isTrue);
      // 85 گرم × 6,000 افغانی = 510,000 نصاب؛ 2.5٪ از 600,000 = 15,000
      expect(r.nisabThreshold, 510000);
      expect(r.zakatAmount, 15000);
      expect(r.breakdownLines.join(' '), contains('افغانی'));
    });

    test('دین مرجو هم بدون نصاب معلوم واجب نمی‌شود', () {
      const input = ZakatInput(
        friendlyDebt: 1000000,
        hawlComplete: true,
        currency: AppCurrency.dirham,
      );
      final r = ZakatCalculator.calculate(input);
      expect(r.priceKnown, isFalse);
      expect(r.friendlyDebtZakat, 0);
    });

    test('toSummaryText واحد انتخابی را به کار می‌برد', () {
      const input = ZakatInput(
        cashAndBank: 6000,
        hawlComplete: true,
        goldPricePerGram24: 60,
        currency: AppCurrency.dollar,
      );
      final text = ZakatCalculator.calculate(input).toSummaryText();
      expect(text, contains('دلار'));
      expect(text, isNot(contains('تومان')));
    });
  });
}

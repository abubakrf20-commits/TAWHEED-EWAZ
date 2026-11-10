import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/shared/models/app_currency.dart';
import 'package:tawheeed/shared/services/currency_store.dart';

/// واحد پول مشترک ابزارهای مالی.
///
/// دو چیز اینجا باید تضمین شود:
///  ۱) نبودِ کلید هرگز خطا نمی‌دهد و به تومان برمی‌گردد (نصب‌های قدیمی هیچ
///     کلید واحدی نداشتند).
///  ۲) واحد حسابگرها و واحد دفتر هزینه‌ها **از هم جدا** می‌مانند؛ وگرنه
///     آزمایش کردن دلار در حسابگر زکات، برچسب تاریخ هزینه‌ها را عوض می‌کرد.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppCurrency', () {
    test('کد ناشناخته یا خالی به تومان برمی‌گردد', () {
      expect(AppCurrency.fromCode(null), AppCurrency.toman);
      expect(AppCurrency.fromCode(''), AppCurrency.toman);
      expect(AppCurrency.fromCode('XXX'), AppCurrency.toman);
      expect(AppCurrency.fromCode('USD'), AppCurrency.dollar);
    });

    test('تومان تنها واحد ایرانی است؛ بقیه عدد بازار ایران را نمی‌پذیرند', () {
      expect(AppCurrency.toman.isIranian, isTrue);
      expect(AppCurrency.dollar.isIranian, isFalse);
      expect(AppCurrency.afghani.isIranian, isFalse,
          reason: 'افغانی واحد ایران نیست؛ عدد تومانی نباید مقیاسش شود');
    });

    test('ریال ایران و ریال سعودی حذف شده‌اند و نصب قدیمی به تومان برمی‌گردد',
        () {
      // «تومان کافیه» — هر دو واحد از انتخابگر بیرون رفتند. کلید واحد در prefs
      // کد پایدارش است نه اندیس، پس یک نصب قدیمی که «IRR» ذخیره کرده بود
      // بی‌صدا به تومان می‌آید و هیچ داده‌ای نمی‌سوزد.
      expect(AppCurrency.values.map((c) => c.code), isNot(contains('IRR')));
      expect(AppCurrency.values.map((c) => c.code), isNot(contains('SAR')));
      expect(AppCurrency.fromCode('IRR'), AppCurrency.toman);
      expect(AppCurrency.fromCode('SAR'), AppCurrency.toman);
    });
  });

  group('CurrencyStore', () {
    test('بدون کلید، تومان است', () async {
      expect(await CurrencyStore.calculators.load(), AppCurrency.toman);
    });

    test('ذخیره و خواندن با کلید مشترک', () async {
      await CurrencyStore.calculators.save(AppCurrency.afghani);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_currency_code'), 'AFN');
      expect(await CurrencyStore.calculators.load(), AppCurrency.afghani);
    });

    test('واحد دلخواه ذخیره و بازخوانی می‌شود', () async {
      await CurrencyStore.calculators.save(AppCurrency.custom('سکه'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_currency_code'), AppCurrency.customCode);
      expect(prefs.getString('app_currency_code_custom_name'), 'سکه');

      final loaded = await CurrencyStore.calculators.load();
      expect(loaded.isCustom, isTrue);
      expect(loaded.unit, 'سکه',
          reason: 'برچسب فیلدها و نتیجه همان نامی است که کاربر نوشته');
    });

    test('نام خالی یا کد دلخواه بدون نام به تومان برمی‌گردد', () {
      expect(AppCurrency.custom('   '), AppCurrency.toman);
      expect(AppCurrency.fromCode(AppCurrency.customCode), AppCurrency.toman);
      expect(
          AppCurrency.fromCode('USD', customName: 'سکه'), AppCurrency.dollar);
    });

    test('انتخاب قبلی زکات (کلید قدیمی) به کلید مشترک مهاجرت می‌کند', () async {
      SharedPreferences.setMockInitialValues({'zakat_currency_code': 'USD'});
      expect(await CurrencyStore.calculators.load(), AppCurrency.dollar);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_currency_code'), 'USD',
          reason: 'مهاجرت باید یک‌باره نوشته شود تا بقیهٔ ابزارها هم ببینند');
    });

    test('واحد دفتر هزینه‌ها از واحد حسابگرها مستقل است', () async {
      await CurrencyStore.calculators.save(AppCurrency.dollar);
      expect(await CurrencyStore.ledger.load(), AppCurrency.toman,
          reason: 'دلار در حسابگر زکات نباید دفتر هزینه‌ها را عوض کند');

      await CurrencyStore.ledger.save(AppCurrency.afghani);
      expect(CurrencyStore.calculators.current, AppCurrency.dollar);
      expect(await CurrencyStore.calculators.load(), AppCurrency.dollar);
    });

    test('notifier پس از save مقدار تازه را نگه می‌دارد', () async {
      final seen = <AppCurrency>[];
      void listener() => seen.add(CurrencyStore.calculators.current);
      CurrencyStore.calculators.notifier.addListener(listener);
      addTearDown(
          () => CurrencyStore.calculators.notifier.removeListener(listener));

      await CurrencyStore.calculators.save(AppCurrency.euro);
      expect(seen, [AppCurrency.euro]);
    });
  });
}

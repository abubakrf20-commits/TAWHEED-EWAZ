import 'package:flutter/widgets.dart';
import 'package:tawheeed/shared/models/app_currency.dart';
import 'package:tawheeed/shared/services/currency_store.dart';

/// دسترسی **خواندنی** به واحد پول مشترک برای تب‌های یک ابزار مالی.
///
/// مسئله‌ای که این mixin حل می‌کند: ابزار میراث ده تب دارد و پنج‌تایشان مبلغ
/// می‌گیرند یا نشان می‌دهند. اگر هر تب خودش prefs را بخواند، کد تکراری می‌شود
/// و برچسب‌ها بین تب‌ها ناهماهنگ می‌مانند.
///
/// اینجا یک منبع حقیقت وجود دارد ([CurrencyStore.calculators]) و همهٔ تب‌ها
/// به تغییرش گوش می‌دهند، پس همه با هم به‌روز می‌شوند — اما هیچ‌کدام **نمی‌نویسند**.
/// واحد پول فقط از تنظیمات عوض می‌شود ([settings_screen]`s «واحد حساب‌گرها» و
/// «واحد دفتر هزینه‌ها» ردیف‌ها)؛ ابزارها فقط تماشاگرند. `tools/quality_check.py`
/// این را به‌عنوان یک دروازه بررسی می‌کند: هیچ `CurrencyStore…save(` بیرون از
/// صفحهٔ تنظیمات مجاز نیست. اگر روزی ابزاری واقعاً به تغییر واحد نیاز داشت،
/// دکمه‌اش باید کاربر را به همان ردیف تنظیمات بفرستد، نه اینکه خودش بنویسد.
mixin CurrencyAwareState<T extends StatefulWidget> on State<T> {
  AppCurrency currency = AppCurrency.toman;

  /// کلمهٔ واحد برای برچسب فیلدها و متن نتیجه.
  String get unit => currency.unit;

  @override
  void initState() {
    super.initState();
    CurrencyStore.calculators.notifier.addListener(_handleCurrencyChange);
    CurrencyStore.calculators.load();
  }

  @override
  void dispose() {
    CurrencyStore.calculators.notifier.removeListener(_handleCurrencyChange);
    super.dispose();
  }

  void _handleCurrencyChange() {
    final next = CurrencyStore.calculators.current;
    if (!mounted || next == currency) return;
    setState(() => currency = next);
    onCurrencyChanged(next);
  }

  /// قلاب برای تب‌هایی که با عوض شدن واحد باید فیلد یا نتیجه‌ای را دوباره
  /// بسازند (مثلاً قیمت ذخیره‌شدهٔ واحد قبلی را دور بریزند).
  void onCurrencyChanged(AppCurrency next) {}
}

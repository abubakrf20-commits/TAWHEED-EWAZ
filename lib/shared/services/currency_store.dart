import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/shared/models/app_currency.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// نگه‌داری واحد پول در SharedPreferences.
///
/// دو نمونهٔ مستقل وجود دارد، چون معنای «واحد» در آن‌ها یکی نیست:
///
/// * [calculators] — واحد **ورود و نمایش** همهٔ بخش‌های مالی که مبلغ را
///   محاسبه یا نگه می‌دارند: زکات، زکات فطر، میراث، کفاره، قلک، بدهی و مالی و
///   حساب مغازه. عوض کردنش هیچ عددی را خراب نمی‌کند، چون عددها ثابت‌اند و
///   فقط واحدشان عوض می‌شود.
/// * [ledger] — واحد **دفتر هزینه‌ها**. مبالغ تراکنش‌ها از قبل ذخیره شده‌اند و
///   عددشان تبدیل نمی‌شود، پس این ردیف جدا نگه داشته می‌شود تا یک آزمایش
///   واحد در حسابگرها برچسب تاریخ هزینه‌ها را عوض نکند.
///
/// هر دو انبار نام **واحد دلخواه** را هم ذخیره می‌کنند ([customName])، چون
/// کد `CUSTOM` تنها نمی‌گوید کاربر چه نوشته است.
///
/// [notifier] برای این است که صفحه‌های باز با هم هم‌زمان به‌روز شوند؛ منبع
/// حقیقت همان prefs است و این فقط آینهٔ درون‌حافظه‌ای آن است.
class CurrencyStore {
  CurrencyStore._(this._key, this._legacyKeys);

  /// واحد همهٔ بخش‌های مالی — کلید قدیمی زکات به‌عنوان مهاجرت خوانده می‌شود
  /// تا کاربرانی که واحدشان را در نسخهٔ قبل انتخاب کرده‌اند انتخابشان را از
  /// دست ندهند.
  static final CurrencyStore calculators = CurrencyStore._(
    'app_currency_code',
    const ['zakat_currency_code'],
  );

  /// واحد دفتر هزینه‌ها — عمداً از حسابگرها جدا و بدون مهاجرت از کلید زکات.
  static final CurrencyStore ledger =
      CurrencyStore._('expenses_currency_code', const []);

  /// نام کوتاه برای «واحد مشترک همهٔ بخش‌های مالی».
  static CurrencyStore get shared => calculators;

  final String _key;
  final List<String> _legacyKeys;

  final ValueNotifier<AppCurrency> notifier =
      ValueNotifier<AppCurrency>(AppCurrency.toman);

  /// نام واحد دلخواه، جدا از کد ذخیره می‌شود. خالی یعنی واحدی دلخواه نیست.
  String _customName = '';

  /// آخرین مقدار خوانده‌شده (یا ذخیره‌شده) بدون I/O.
  AppCurrency get current => notifier.value;

  String get customName => _customName;

  /// خواندن از prefs. خطا هرگز به بالا پرتاب نمی‌شود: واحد پول تنظیمی است
  /// که نبودش باید به پیش‌فرض تومان بینجامد، نه به صفحهٔ خطا.
  Future<AppCurrency> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_key);
      String? legacy;
      for (final key in _legacyKeys) {
        legacy ??= prefs.getString(key);
      }
      _customName = prefs.getString(_customKey) ?? _fallbackCustom(prefs) ?? '';
      final resolved = AppCurrency.fromCode(
        stored ?? legacy,
        customName: _customName,
      );
      _customName = resolved.isCustom ? resolved.unit : '';
      notifier.value = resolved;
      // مهاجرت یک‌باره: انتخاب قبلی کاربر در کلید قدیمی، به کلید مشترک منتقل
      // می‌شود تا همهٔ ابزارها یک واحد ببینند.
      if (stored == null && legacy != null) {
        await prefs.setString(_key, resolved.code);
        if (resolved.isCustom) {
          await prefs.setString(_customKey, resolved.unit);
        }
      }
      return resolved;
    } catch (e) {
      AppLogger.warning('currency_store', 'load failed for $_key: $e');
      return notifier.value;
    }
  }

  String get _customKey => '${_key}_custom_name';

  /// نام واحد دلخواهِ ذخیره‌شده زیر یکی از کلیدهای قدیمی (اگر بود).
  String? _fallbackCustom(SharedPreferences prefs) {
    for (final key in _legacyKeys) {
      final name = prefs.getString('${key}_custom_name');
      if (name != null && name.isNotEmpty) return name;
    }
    return null;
  }

  Future<void> save(AppCurrency currency) async {
    notifier.value = currency;
    _customName = currency.isCustom ? currency.unit : '';
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, currency.code);
      if (currency.isCustom) {
        await prefs.setString(_customKey, currency.unit);
      } else {
        await prefs.remove(_customKey);
      }
    } catch (e) {
      AppLogger.warning('currency_store', 'save failed for $_key: $e');
    }
  }
}

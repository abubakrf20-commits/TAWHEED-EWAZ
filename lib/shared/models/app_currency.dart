import 'package:flutter/foundation.dart' show immutable;

/// واحد پول برنامه — **یک** واحد برای همهٔ بخش‌های مالی.
///
/// هیچ‌کدام از ابزارهای مالی این برنامه (زکات، زکات فطر، میراث، کفاره، قلک،
/// بدهی و مالی، دفتر هزینه‌ها، حساب مغازه) به **تبدیل ارز** نیاز ندارند: کاربر
/// همهٔ مبالغ را به یک واحد وارد می‌کند و محاسبه فقط نسبت‌های ثابت و
/// «مقدار × قیمت واحد» را اعمال می‌کند. پس «ارز» اینجا یعنی **واحد ورود و
/// نمایش**، نه یک نرخ تبدیل.
///
/// این کلاس جای `enum` نشسته است تا کاربر بتواند واحد خودش را بنویسد:
/// [values] همان فهرست ثابت قبلی است و [custom] واحد دلخواه می‌سازد. برابری
/// بر پایهٔ [code] و [unit] است، پس `AppCurrency.toman == AppCurrency.toman`
/// و یک واحد دلخواه با همان نام هم با خودش برابر می‌ماند.
///
/// تنها جایی که واحد واقعاً معنای عددی دارد، قیمت‌های پیش‌فرض بازار ایران است:
/// آن اعداد فقط برای **تومان** نوشته شده‌اند ([isIranian]). برای هر واحد دیگر
/// هیچ عددی به‌عنوان قیمت فرض نمی‌شود و فیلد قیمت خالی می‌ماند.
@immutable
class AppCurrency {
  const AppCurrency({
    required this.code,
    required this.label,
    required this.unit,
  });

  /// تومان — واحد پیش‌فرض و رفتار تاریخی برنامه.
  static const AppCurrency toman = AppCurrency(
    code: 'IRT',
    label: 'تومان',
    unit: 'تومان',
  );

  static const AppCurrency dollar = AppCurrency(
    code: 'USD',
    label: 'دلار آمریکا',
    unit: 'دلار',
  );

  static const AppCurrency dirham = AppCurrency(
    code: 'AED',
    label: 'درهم امارات',
    unit: 'درهم',
  );

  static const AppCurrency afghani = AppCurrency(
    code: 'AFN',
    label: 'افغانی افغانستان',
    unit: 'افغانی',
  );

  static const AppCurrency iraqiDinar = AppCurrency(
    code: 'IQD',
    label: 'دینار عراق',
    unit: 'دینار',
  );

  static const AppCurrency euro = AppCurrency(
    code: 'EUR',
    label: 'یورو',
    unit: 'یورو',
  );

  /// واحدهای آماده، به همان ترتیبی که در انتخابگر می‌آیند.
  static const List<AppCurrency> values = [
    toman,
    dollar,
    dirham,
    afghani,
    iraqiDinar,
    euro,
  ];

  /// کد پایدار واحد دلخواه. نامش جدا در prefs ذخیره می‌شود، چون در [code]
  /// نمی‌گنجد.
  static const String customCode = 'CUSTOM';

  /// واحد دلخواه کاربر؛ [name] همان چیزی است که در فیلدها و نتیجه می‌آید
  /// («سکه»، «لیر»، «من»). نام خالی پذیرفته نمی‌شود و به تومان برمی‌گردد.
  factory AppCurrency.custom(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return toman;
    final short = trimmed.length > 24 ? trimmed.substring(0, 24) : trimmed;
    return AppCurrency(code: customCode, label: short, unit: short);
  }

  /// کد پایدار برای ذخیره در SharedPreferences — هرگز تغییر نکند.
  final String code;

  /// نام کامل واحد، برای انتخابگر.
  final String label;

  /// کلمهٔ کوتاهی که در برچسب فیلدها و متن نتیجه می‌آید («تومان»، «دلار»…).
  final String unit;

  /// آیا این واحد را خود کاربر نوشته است.
  bool get isCustom => code == customCode;

  /// آیا اعداد پیش‌فرض بازار ایران (طلا/نقره/دلار و قوت غالب) برای این واحد
  /// معتبرند. ریال ایران و ریال سعودی از این فهرست بیرون رفته‌اند — تومان
  /// کفایت می‌کند — پس ایرانی بودن همان تومان بودن است.
  bool get isIranian => code == toman.code;

  /// بازیابی از prefs؛ کد ناشناخته یا خالی به تومان برمی‌گردد تا دادهٔ
  /// قدیمی کاربر (که کلید واحد نداشت) بی‌صدا از دست نرود. برای واحد دلخواه
  /// [customName] خوانده می‌شود و اگر خالی باشد هم به تومان می‌رسیم.
  static AppCurrency fromCode(String? code, {String? customName}) {
    if (code == null || code.isEmpty) return toman;
    if (code == customCode) {
      final name = (customName ?? '').trim();
      return name.isEmpty ? toman : AppCurrency.custom(name);
    }
    for (final c in values) {
      if (c.code == code) return c;
    }
    return toman;
  }

  @override
  bool operator ==(Object other) =>
      other is AppCurrency && other.code == code && other.unit == unit;

  @override
  int get hashCode => Object.hash(code, unit);

  @override
  String toString() => 'AppCurrency($code, $unit)';
}

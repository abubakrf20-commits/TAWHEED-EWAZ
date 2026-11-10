import 'month_display.dart';

class DateConstants {
  DateConstants._();

  /// Iranian solar month names.
  static const List<String> iranianMonths = [
    'فروردین',
    'اردیبهشت',
    'خرداد',
    'تیر',
    'مرداد',
    'شهریور',
    'مهر',
    'آبان',
    'آذر',
    'دی',
    'بهمن',
    'اسفند',
  ];

  /// Afghan solar month names — the same twelve months, named as in Afghanistan.
  static const List<String> afghanMonths = [
    'حمل',
    'ثور',
    'جوزا',
    'سرطان',
    'اسد',
    'سنبله',
    'میزان',
    'عقرب',
    'قوس',
    'جدی',
    'دلو',
    'حوت',
  ];

  /// The solar month names to display, per the user's «روش عرضه ماه» choice.
  ///
  /// A getter, not a const, so every existing caller follows the setting
  /// without threading a parameter through the app. A widget that must repaint
  /// when the choice flips needs `MonthDisplayScope.of(context)` in its build.
  static List<String> get persianMonths =>
      monthsFor(monthDisplayNotifier.value);

  static List<String> monthsFor(MonthDisplay display) =>
      display == MonthDisplay.afghan ? afghanMonths : iranianMonths;

  static const List<String> hijriMonths = [
    'محرم',
    'صفر',
    'ربیع‌الاول',
    'ربیع‌الثانی',
    'جمادی‌الاول',
    'جمادی‌الثانی',
    'رجب',
    'شعبان',
    'رمضان',
    'شوال',
    'ذی‌قعده',
    'ذی‌حجه',
  ];

  static const List<String> gregorianMonths = [
    'ژانویه',
    'فوریه',
    'مارس',
    'آوریل',
    'می',
    'ژوئن',
    'ژوئیه',
    'اوت',
    'سپتامبر',
    'اکتبر',
    'نوامبر',
    'دسامبر',
  ];

  static const List<String> weekDays = [
    'دوشنبه',
    'سه‌شنبه',
    'چهارشنبه',
    'پنجشنبه',
    'جمعه',
    'شنبه',
    'یکشنبه',
  ];
}

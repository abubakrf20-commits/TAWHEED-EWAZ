import 'package:tawheeed/core/utils/calendar_days.dart';
import 'package:tawheeed/features/tools/moon/domain/services/lunar_calculator.dart';

/// تقویم هجری نجومی — شروع ماه از محاق واقعی (به جای جدول ام‌القری)
///
/// قاعده: روز هجری جدید از غروبِ روزِ محاق آغاز می‌شود. یعنی اگر محاق در
/// 11 ژانویه رخ دهد، شامگاه 11 ژانویه = شب 1 ماه جدید است و روز 12 ژانویه
/// = 1 ماه جدید.
///
/// این کلاس مکمل [HijriUtils] جدولی است — سال/ماه از همان چارچوب
/// ام‌القری گرفته می‌شود اما «روز» بر اساس فاصله تا آخرین محاق قبل از
/// غروب محاسبه می‌شود، بنابراین با رویت واقعی هلال هم‌خوانی بیشتری دارد.
class AstronomicalHijri {
  AstronomicalHijri._();

  /// اطلاعات ماه هجری برای یک روز میلادی:
  /// - monthStart: تاریخ میلادیِ روزِ اول ماه (روز بعد از محاق)
  /// - dayInMonth: روز جاری ماه (1..30)
  /// - isNewMoonDay: آیا امروز روزِ محاق است (شب امشب = هلال)
  static ({
    DateTime monthStart,
    int dayInMonth,
    bool isConjunctionDay,
    DateTime nextNewMoon,
    int monthLength,
  }) lunarMonthInfo(DateTime gDate) {
    // امروز به‌صورت نیمه‌شب محلی — ساعتِ روز در هیچ محاسبه‌ای دخالت ندارد.
    final today = DateTime(gDate.year, gDate.month, gDate.day);

    // «مقارنهٔ بازِ امروز»: مقارنه‌ای که لحظه‌اش داخل همین روز تقویمی است
    // (نیمه‌شب امروز <= مقارنه < نیمه‌شب فردا) یا آخرین مقارنهٔ قبل از آن.
    // فقط یک روز عقب می‌رویم؛ مقارنه‌های ماهانه ~۲۹.۵ روز فاصله دارند.
    var nm =
        LunarCalculator.lastNewMoonBefore(today.add(const Duration(days: 1)));
    while (!nm.isBefore(today.add(const Duration(days: 1)))) {
      nm = LunarCalculator.lastNewMoonBefore(
          nm.subtract(const Duration(hours: 1)));
    }
    final nmLocal = DateTime(nm.year, nm.month, nm.day);

    // اگر مقارنهٔ باز داخل امروز است، امروز خودِ روز محاق است: چارچوب
    // «ماهِ جاری» تا پایان همین شب همان ماه قبلی می‌ماند (روز آخر = روز
    // محاق) و ماه جدید از فردا شروع می‌شود. به این ترتیب روز ۳۰ فقط در
    // ماه ۳۰روزه دیده می‌شود و شمارهٔ روزها پیوسته پیش می‌رود.
    final isConjunctionDay = nmLocal.isAtSameMomentAs(today);

    final prevNm = isConjunctionDay
        ? LunarCalculator.lastNewMoonBefore(
            nm.subtract(const Duration(hours: 1)))
        : nm;
    final prevLocal = DateTime(prevNm.year, prevNm.month, prevNm.day);

    // مقارنهٔ پایانیِ چارچوب: روزِ محاق = امروز؛ غیر آن = نخستین مقارنهٔ
    // بعد از امروز (که حتماً فردا یا بعدتر است).
    final nextNm = LunarCalculator.nextNewMoon(today);
    final nextLocal = DateTime(nextNm.year, nextNm.month, nextNm.day);

    final monthStart = isConjunctionDay
        ? prevLocal.add(const Duration(days: 1))
        : nmLocal.add(const Duration(days: 1));

    // طول ماه = تعداد روزهای [monthStart .. nextLocal] و شمارهٔ روز از
    // همان کسر — پس dayInMonth هرگز از monthLength فراتر نمی‌رود.
    // شمارش با calendarDaysBetween (تاریخ‌های UTC) انجام می‌شود تا یک روز
    // ۲۳ساعتهٔ تغییر ساعت تابستانی، `.inDays` را یک واحد کوتاه نکند.
    final monthLength = calendarDaysBetween(monthStart, nextLocal) + 1;
    final dayInMonth = calendarDaysBetween(monthStart, today) + 1;

    return (
      monthStart: monthStart,
      dayInMonth: dayInMonth.clamp(1, 30),
      isConjunctionDay: isConjunctionDay,
      nextNewMoon: nextNm,
      monthLength: monthLength.clamp(29, 30),
    );
  }
}

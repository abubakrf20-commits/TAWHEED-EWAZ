/// Pure, testable logic for the extra calculator modes
/// (درصد، تخفیف، سن، تبدیل واحد).
library;
import 'package:tawheeed/shared/utils/number_format.dart';

class CalculatorTools {
  CalculatorTools._();

  /// Convert an integer to English (Latin) digits — shared standard.
  static String en(int n) => NumberFormat.en(n);

  // ── درصد ──────────────────────────────────────────────────────────

  /// `percent` درصد از `value`.
  static double percentOf(double value, double percent) =>
      value * percent / 100;

  /// `value` چند درصد از `total` است (total=0 → null).
  static double? percentRatio(double value, double total) {
    if (total == 0) return null;
    return value * 100 / total;
  }

  /// مقدار پس از افزايش درصدی (value * (1 + p/100)).
  static double percentIncrease(double value, double percent) =>
      value * (1 + percent / 100);

  /// مقدار پس از کاهش درصدی (value * (1 - p/100)).
  static double percentDecrease(double value, double percent) =>
      value * (1 - percent / 100);

  // ── تخفیف ─────────────────────────────────────────────────────────

  static double discountAmount(double price, double percent) =>
      price * percent / 100;

  static double finalPrice(double price, double percent) =>
      price - discountAmount(price, percent);

  // ── سن ────────────────────────────────────────────────────────────

  /// Age in (years, months, days) from a Gregorian birth date to [today].
  static ({int years, int months, int days}) ageFrom(
      DateTime birth, DateTime today) {
    var years = today.year - birth.year;
    var months = today.month - birth.month;
    var days = today.day - birth.day;
    if (days < 0) {
      months -= 1;
      days += DateTime(today.year, today.month, 0).day;
      // Birth day may exceed the borrow month's length (e.g. Jan 31 vs Feb).
      // Clamp to zero instead of reporting negative days.
      if (days < 0) days = 0;
    }
    if (months < 0) {
      years -= 1;
      months += 12;
    }
    if (years < 0) {
      years = 0;
      months = 0;
      days = 0;
    }
    return (years: years, months: months, days: days);
  }

  /// مجموع روزهای بین دو تاریخ.
  static int totalDaysBetween(DateTime from, DateTime to) =>
      to.difference(from).inDays;

  /// مجموع ماه‌های کامل (تقریبی با میانگین 30.44 روز).
  static int totalMonths(DateTime birth, DateTime today) =>
      (totalDaysBetween(birth, today) / 30.44).round();

  /// روزهای باقی‌مانده تا تولد بعدی (0 اگر امروز تولد باشد).
  static int daysToNextBirthday(DateTime birth, DateTime today) {
    var next = _birthdayInYear(birth, today.year);
    if (_isSameDate(next, today)) return 0;
    if (next.isBefore(today)) {
      next = _birthdayInYear(birth, today.year + 1);
    }
    return next.difference(today).inDays;
  }

  /// تولد در سال [year]؛ روز 29 اسفندِ کبیسه را در سال‌های غیرکبیسه
  /// به آخرین روز همان ماه (28) محدود می‌کند.
  static DateTime _birthdayInYear(DateTime birth, int year) {
    final maxDay = DateTime(year, birth.month + 1, 0).day;
    final day = birth.day > maxDay ? maxDay : birth.day;
    return DateTime(year, birth.month, day);
  }

  static bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ── تبدیل واحد ────────────────────────────────────────────────────

  /// Length: each unit's multiplier relative to meters.
  static const Map<String, double> _lengthToMeter = {
    'متر': 1,
    'کیلومتر': 1000,
    'سانتی‌متر': 0.01,
    'میلی‌متر': 0.001,
    'مایل': 1609.344,
    'یارد': 0.9144,
    'فوت': 0.3048,
    'اینچ': 0.0254,
  };

  /// Mass: each unit's multiplier relative to kilograms.
  static const Map<String, double> _massToKg = {
    'کیلوگرم': 1,
    'گرم': 0.001,
    'میلی‌گرم': 0.000001,
    'تُن': 1000,
    'پوند': 0.45359237,
    'اونس': 0.028349523125,
  };

  /// Volume: each unit's multiplier relative to liters.
  static const Map<String, double> _volumeToLiter = {
    'لیتر': 1,
    'میلی‌لیتر': 0.001,
    'متر مکعب': 1000,
    'گالن (آمریکا)': 3.785411784,
    'گالن (انگلیس)': 4.54609,
    'پیمانه (cup)': 0.2365882365,
  };

  /// Time: each unit's multiplier relative to seconds.
  static const Map<String, double> _timeToSecond = {
    'ثانیه': 1,
    'دقیقه': 60,
    'ساعت': 3600,
    'روز': 86400,
    'هفته': 604800,
    'ماه': 2629800, // میانگین 30.44 روز
    'سال': 31557600, // سال نجومی (365.25 روز)
  };

  /// Data: each unit's multiplier relative to bytes.
  static const Map<String, double> _dataToByte = {
    'بایت': 1,
    'کیلوبایت': 1024,
    'مگابایت': 1024 * 1024,
    'گیگابایت': 1024 * 1024 * 1024,
    'ترابایت': 1024.0 * 1024 * 1024 * 1024,
  };

  /// Temperature conversions in Celsius.
  static double celsiusTo(double value, String unit) {
    switch (unit) {
      case 'فارنهایت':
        return value * 9 / 5 + 32;
      case 'کلوین':
        return value + 273.15;
      default:
        return value;
    }
  }

  static double toCelsius(double value, String unit) {
    switch (unit) {
      case 'فارنهایت':
        return (value - 32) * 5 / 9;
      case 'کلوین':
        return value - 273.15;
      default:
        return value;
    }
  }

  static double convertTemperature(double value, String from, String to) {
    return celsiusTo(toCelsius(value, from), to);
  }

  static List<String> lengthUnits() => _lengthToMeter.keys.toList();
  static List<String> massUnits() => _massToKg.keys.toList();
  static List<String> volumeUnits() => _volumeToLiter.keys.toList();
  static List<String> timeUnits() => _timeToSecond.keys.toList();
  static List<String> dataUnits() => _dataToByte.keys.toList();
  static const List<String> temperatureUnits = [
    'سانتی‌گراد',
    'فارنهایت',
    'کلوین'
  ];

  static double convertLength(double value, String from, String to) {
    final m = value * (_lengthToMeter[from] ?? 0.0);
    return m / (_lengthToMeter[to] ?? 0.0);
  }

  static double convertMass(double value, String from, String to) {
    final kg = value * (_massToKg[from] ?? 0.0);
    return kg / (_massToKg[to] ?? 0.0);
  }

  static double convertVolume(double value, String from, String to) {
    final l = value * (_volumeToLiter[from] ?? 0.0);
    return l / (_volumeToLiter[to] ?? 0.0);
  }

  static double convertTime(double value, String from, String to) {
    final sec = value * (_timeToSecond[from] ?? 0.0);
    return sec / (_timeToSecond[to] ?? 0.0);
  }

  static double convertData(double value, String from, String to) {
    final b = value * (_dataToByte[from] ?? 0.0);
    return b / (_dataToByte[to] ?? 0.0);
  }

  // ── قسط قرض الحسنه ──────────────────────────────────────────────

  /// Monthly installment for an interest-free loan (قرض الحسنه).
  /// The principal is divided equally over [months]; no interest is charged.
  /// Returns null when inputs are invalid (amount<=0, months<=0).
  static double? qardHasanMonthlyPayment(double amount, int months) {
    if (amount <= 0 || months <= 0) return null;
    return amount / months;
  }

  /// Round for display: up to 10 significant decimals, drop trailing zeros.
  static String format(double value) {
    if (value == value.roundToDouble() && value.abs() < 1e15) {
      return value.toInt().toString();
    }
    if (value.abs() >= 1e15 || (value.abs() < 1e-10 && value != 0)) {
      return value.toStringAsExponential(6);
    }
    final rounded = double.parse(value.toStringAsFixed(10));
    var str = rounded.toString();
    if (str.contains('.') && !str.contains('e')) {
      str = str.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return str;
  }

  /// Format a price with thousands separators + optional decimals.
  /// Grouping delegates to the shared [NumberFormat] (single source).
  static String formatMoney(double value) {
    final s = format(value);
    if (value.abs() < 1000 || s.contains('e')) return s;
    final neg = s.startsWith('-');
    final body = neg ? s.substring(1) : s;
    final dot = body.indexOf('.');
    final intPart = dot < 0 ? body : body.substring(0, dot);
    final frac = dot < 0 ? '' : body.substring(dot);
    final grouped = NumberFormat.formatPlain(double.parse(intPart));
    return '${neg ? '-' : ''}$grouped$frac';
  }
}

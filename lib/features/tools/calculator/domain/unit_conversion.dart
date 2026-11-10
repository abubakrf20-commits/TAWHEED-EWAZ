/// Unit-converter domain: categories, local units and conversion maths for
/// the calculator's «تبدیل واحد» tab (audit item P2-B-UNITS).
///
/// LOCAL units (من، سیر، مثقال، نخود، خروار) are Persian-market traditional
/// weights. Per docs/PERSONAL_AUDIT/03_DECISIONS.md: the five shipped
/// defaults are EDITABLE BASES flagged unverified — any other local unit
/// ships as an empty «مبنا را وارد کنید» row and is never guessed. Bases are
/// relative to kilograms and persisted so user edits survive restarts and
/// travel in the backup.
library;

/// The converter categories in display order.
enum UnitCategory {
  length('طول'),
  mass('جرم'),
  area('مساحت'),
  volume('حجم'),
  temperature('دما'),
  speed('سرعت'),
  time('زمان'),
  data('داده'),
  local('محلی ★');

  const UnitCategory(this.titleFa);
  final String titleFa;
}

/// Length: multiplier relative to meters.
const Map<String, double> unitLengthToMeter = {
  'متر': 1,
  'کیلومتر': 1000,
  'سانتی‌متر': 0.01,
  'میلی‌متر': 0.001,
  'مایل': 1609.344,
  'یارد': 0.9144,
  'فوت': 0.3048,
  'اینچ': 0.0254,
  'مایل دریایی': 1852,
};

/// Area: multiplier relative to square meters.
const Map<String, double> unitAreaToSquareMeter = {
  'متر مربع': 1,
  'کیلومتر مربع': 1000000,
  'سانتی‌متر مربع': 0.0001,
  'هکتار': 10000,
  'فوت مربع': 0.09290304,
  'یارد مربع': 0.83612736,
  'جریب': 4046.8564224,
};

/// Speed: multiplier relative to meters per second.
const Map<String, double> unitSpeedToMeterPerSecond = {
  'متر بر ثانیه': 1,
  'کیلومتر بر ساعت': 1000 / 3600,
  'مایل بر ساعت': 1609.344 / 3600,
  'گره (ناتیکال)': 1852 / 3600,
  'فوت بر ثانیه': 0.3048,
};

/// The five shipped LOCAL weight units with their default bases (kg per
/// unit), flagged unverified until the user confirms them.
const List<({String name, double defaultBaseKg, String note})>
    defaultLocalUnits = [
  (
    name: 'من (تبریز)',
    defaultBaseKg: 3,
    note: 'رایج تبریز؛ در شهرهای دیگر متفاوت است.',
  ),
  (name: 'سیر', defaultBaseKg: 0.075, note: 'یک‌چهلم من تبریز.'),
  (
    name: 'مثقال',
    defaultBaseKg: 0.004608,
    note: '۱۸۰ دانه جو؛ پایهٔ سکه‌ و طلا.',
  ),
  (name: 'نخود', defaultBaseKg: 0.000192, note: 'یک‌بیست‌وچهارم مثقال.'),
  (name: 'خروار', defaultBaseKg: 300, note: '۳۰۰ من تبریز؛ واحد کشاورزی.'),
];

/// Converts between two units of [category] using the supplied local bases.
///
/// Returns null when a unit name is unknown or a base is unset (an empty
/// «مبنا را وارد کنید» row) — the UI shows the base editor instead of
/// guessing.
double? convertUnits({
  required UnitCategory category,
  required double value,
  required String from,
  required String to,
  required Map<String, double> localBasesKg,
}) {
  switch (category) {
    case UnitCategory.length:
      return _via(unitLengthToMeter, value, from, to);
    case UnitCategory.area:
      return _via(unitAreaToSquareMeter, value, from, to);
    case UnitCategory.speed:
      return _via(unitSpeedToMeterPerSecond, value, from, to);
    case UnitCategory.mass:
      return _via(unitMassToKg, value, from, to);
    case UnitCategory.volume:
      return _via(unitVolumeToLiter, value, from, to);
    case UnitCategory.time:
      return _via(unitTimeToSecond, value, from, to);
    case UnitCategory.data:
      return _via(unitDataToByte, value, from, to);
    case UnitCategory.temperature:
      return convertTemperature(value, from, to);
    case UnitCategory.local:
      // «کیلوگرم» is always available as the bridge (base 1) so a local unit
      // can convert straight into the metric system.
      final fromBase = from == 'کیلوگرم' ? 1.0 : localBasesKg[from];
      final toBase = to == 'کیلوگرم' ? 1.0 : localBasesKg[to];
      if (fromBase == null || toBase == null || toBase == 0) return null;
      return value * fromBase / toBase;
  }
}

double? _via(Map<String, double> table, double value, String from, String to) {
  final fromFactor = table[from];
  final toFactor = table[to];
  if (fromFactor == null || toFactor == null || toFactor == 0) return null;
  return value * fromFactor / toFactor;
}

// The stage-2 tables re-exported so the panel reads one file.
const Map<String, double> unitMassToKg = {
  'کیلوگرم': 1,
  'گرم': 0.001,
  'میلی‌گرم': 0.000001,
  'تُن': 1000,
  'پوند': 0.45359237,
  'اونس': 0.028349523125,
};

const Map<String, double> unitVolumeToLiter = {
  'لیتر': 1,
  'میلی‌لیتر': 0.001,
  'متر مکعب': 1000,
  'گالن (آمریکا)': 3.785411784,
  'گالن (انگلیس)': 4.54609,
  'پیمانه (cup)': 0.2365882365,
};

const Map<String, double> unitTimeToSecond = {
  'ثانیه': 1,
  'دقیقه': 60,
  'ساعت': 3600,
  'روز': 86400,
  'هفته': 604800,
  'ماه': 2629800,
  'سال': 31557600,
};

const Map<String, double> unitDataToByte = {
  'بایت': 1,
  'کیلوبایت': 1024,
  'مگابایت': 1024 * 1024,
  'گیگابایت': 1024 * 1024 * 1024,
  'ترابایت': 1024.0 * 1024 * 1024 * 1024,
};

double convertTemperature(double value, String from, String to) {
  double toCelsius(double v, String unit) => switch (unit) {
        'فارنهایت' => (v - 32) * 5 / 9,
        'کلوین' => v + 273.15,
        _ => v,
      };
  double fromCelsius(double c, String unit) => switch (unit) {
        'فارنهایت' => c * 9 / 5 + 32,
        'کلوین' => c - 273.15,
        _ => c,
      };
  return fromCelsius(toCelsius(value, from), to);
}

/// Formats up to 6 significant digits (the spec's display rule), dropping
/// trailing zeros; falls back to exponential for extremes.
String formatUnitValue(double value) {
  if (value == 0) return '0';
  if (value == value.roundToDouble() && value.abs() < 1e15) {
    return value.toInt().toString();
  }
  if (value.abs() >= 1e15 || value.abs() < 1e-10) {
    return value.toStringAsExponential(6);
  }
  final magnitude = value.abs();
  final digits = magnitude < 1 ? 6 : (6 - magnitude.toStringAsFixed(0).length);
  final str = value.toStringAsFixed(digits.clamp(0, 10));
  var out = str.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  if (out.endsWith('.')) out = out.substring(0, out.length - 1);
  return out;
}

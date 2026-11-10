/// Pure conversion + display rules for the calculator's «تبدیل واحد» tab.
///
/// * factors come from `assets/data/units.json` (one source), temperature uses
///   explicit formulas because a scale is not a multiplication;
/// * the result is rounded to 10 significant digits first, then displayed with
///   at most 6 — that removes the `0.30000000000000004` class of noise while
///   keeping a small «من» readable;
/// * a negative amount is refused everywhere except temperature.
library;

import 'package:tawheeed/features/tools/calculator/data/units/local_unit.dart';
import 'package:tawheeed/features/tools/calculator/data/units/unit_models.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

class UnitConversion {
  const UnitConversion({required this.value, required this.formula});

  final double value;

  /// «۱ من = ۳ کیلوگرم» — the line under the fields.
  final String formula;
}

class UnitConverterEngine {
  const UnitConverterEngine();

  /// Converts [value] from [fromId] to [toId] inside [category].
  ///
  /// Returns null when the input is not valid for the category (a negative
  /// length, a zero factor) — the UI shows «—» instead of an invented number.
  double? convert({
    required UnitCategory category,
    required String fromId,
    required String toId,
    required double value,
    List<LocalUnit> localUnits = const [],
  }) {
    if (value.isNaN || value.isInfinite) return null;
    if (category.isTemperature) {
      return _temperature(value, fromId, toId);
    }
    if (value < 0) return null;

    final fromFactor = _factorOf(category, fromId, localUnits);
    final toFactor = _factorOf(category, toId, localUnits);
    if (fromFactor == null || toFactor == null) return null;
    if (fromFactor <= 0 || toFactor <= 0) return null;

    final base = value * fromFactor;
    final result = base / toFactor;
    return roundToSignificant(result, 10);
  }

  /// The unit list of a category, with the user's local edits merged in.
  List<UnitDef> unitsOf(UnitCategory category, List<LocalUnit> localUnits) {
    if (!category.isLocal) return category.units;
    final merged = <String, UnitDef>{
      for (final u in category.units) u.id: u,
    };
    for (final local in localUnits) {
      merged[local.id] = UnitDef(
        id: local.id,
        label: local.name,
        factor: local.factor,
      );
    }
    return merged.values.toList();
  }

  double? _factorOf(
    UnitCategory category,
    String unitId,
    List<LocalUnit> localUnits,
  ) {
    for (final u in unitsOf(category, localUnits)) {
      if (u.id == unitId) return u.factor;
    }
    return null;
  }

  double? _temperature(double value, String fromId, String toId) {
    if (fromId == toId) return value;
    // to Celsius first, then out.
    final double celsius;
    switch (fromId) {
      case 'f':
        celsius = (value - 32) * 5 / 9;
      case 'k':
        celsius = value - 273.15;
      default:
        celsius = value;
    }
    switch (toId) {
      case 'f':
        return roundToSignificant(celsius * 9 / 5 + 32, 10);
      case 'k':
        return roundToSignificant(celsius + 273.15, 10);
      default:
        return roundToSignificant(celsius, 10);
    }
  }
}

/// Rounds to [digits] significant digits. Values too small/large to round
/// meaningfully are returned unchanged.
double roundToSignificant(double value, int digits) {
  if (value == 0 || value.isNaN || value.isInfinite) return value;
  final magnitude = value.abs();
  final shift = (magnitude < 1e-12 || magnitude >= 1e15)
      ? 0
      : int.tryParse(
            magnitude.toStringAsExponential(digits - 1).split('e').last,
          ) ??
          0;
  final factor = _pow10(digits - 1 - shift);
  return (value * factor).roundToDouble() / factor;
}

double _pow10(int exponent) {
  var result = 1.0;
  if (exponent >= 0) {
    for (var i = 0; i < exponent; i++) {
      result *= 10;
    }
  } else {
    for (var i = 0; i < -exponent; i++) {
      result /= 10;
    }
  }
  return result;
}

/// Display form: at most 6 significant digits, trailing zeros trimmed,
/// thousands separated. [persianDigits] swaps the Latin digits for ۰–۹.
String formatConvertedValue(
  double value, {
  bool persianDigits = false,
}) {
  final rounded = roundToSignificant(value, 6);
  final abs = rounded.abs();
  String text;
  if (abs != 0 && abs < 0.000001) {
    text = rounded.toStringAsExponential(3);
  } else if (rounded == rounded.roundToDouble() && abs < 1e15) {
    text = NumberFormat.formatPlain(rounded);
  } else {
    // 6 significant digits, at most 9 decimals so 0.000001 stays legible.
    var fixed = rounded.toStringAsFixed(9);
    if (fixed.contains('.')) {
      fixed = fixed.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    final parts = fixed.split('.');
    final intPart = int.tryParse(parts.first) ?? 0;
    final grouped = NumberFormat.formatPlain(intPart.toDouble());
    text = parts.length > 1 ? '$grouped.${parts[1]}' : grouped;
    if (rounded < 0 && !text.startsWith('-')) text = '-$text';
  }
  return persianDigits ? toPersianDigits(text) : text;
}

/// Latin digits → Persian digits, separators and letters untouched.
String toPersianDigits(String text) {
  const digits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    final ch = String.fromCharCode(rune);
    final index = int.tryParse(ch);
    if (index != null && ch.length == 1) {
      buffer.write(digits[index]);
    } else {
      buffer.write(ch);
    }
  }
  return buffer.toString();
}

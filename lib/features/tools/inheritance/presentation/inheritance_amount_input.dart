import 'package:tawheeed/shared/utils/number_format.dart';

/// Outcome of parsing one inheritance amount field.
///
/// `NumberFormat.parse` is deliberately forgiving: anything it cannot read
/// becomes `0`. That is wrong for a calculator that divides the estate, because
/// a negative or infinite amount silently produces nonsense shares (and a
/// negative "testament" would *grow* the net estate). Every money field in the
/// inheritance tool therefore goes through [parseNonNegativeAmount].
class AmountParseResult {
  /// The parsed value; `0` when [error] is set.
  final double value;

  /// A user-facing Persian message, or `null` when the text was valid.
  final String? error;

  const AmountParseResult(this.value, this.error);

  bool get ok => error == null;
}

/// Parses [text] as a finite, non-negative amount.
///
/// * empty / whitespace → `0` (an untouched optional field)
/// * unparsable, negative, `NaN` or infinite → [error] with [label] named
///
/// [allowZero] is `false` for the estate, which must be a real amount.
AmountParseResult parseNonNegativeAmount(
  String text, {
  required String label,
  bool allowZero = true,
}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    if (allowZero) return const AmountParseResult(0, null);
    return AmountParseResult(0, 'لطفاً «$label» را به درستی وارد کنید.');
  }
  final value = NumberFormat.parse(trimmed);
  if (!value.isFinite) {
    return AmountParseResult(
        0, 'مقدار «$label» معتبر نیست — عددی بزرگ‌تر از حد مجاز وارد شده است.');
  }
  if (value < 0) {
    return AmountParseResult(0, 'مقدار «$label» نمی‌تواند منفی باشد.');
  }
  if (value == 0 && !allowZero) {
    return AmountParseResult(0, 'لطفاً «$label» را به درستی وارد کنید.');
  }
  // `NumberFormat.parse` maps unreadable text to 0 — a real "abc" must be an
  // error, not silently zero. Digits, grouping separators and an optional
  // decimal part are the only accepted shapes.
  if (value == 0 && !_isZero(trimmed)) {
    return AmountParseResult(0, 'مقدار «$label» معتبر نیست.');
  }
  return AmountParseResult(value, null);
}

bool _isZero(String raw) {
  var s = raw.replaceAll('٬', ',').replaceAll('٫', '.');
  s = s.replaceAll(',', '');
  s = NumberFormat.normalizeDigits(s);
  return double.tryParse(s) == 0;
}

/// Parses the estate field: required, finite and greater than zero.
AmountParseResult parseEstate(String text) =>
    parseNonNegativeAmount(text, label: 'مبلغ کل ترکه', allowZero: false);

/// Parses the money fields that come off the net estate (funeral costs, debts
/// and wills) and checks they cannot exceed it.
class DeductionsParseResult {
  final double funeral;
  final double debts;
  final double will1;
  final double will2;
  final double will3;
  final String? error;

  const DeductionsParseResult(
      this.funeral, this.debts, this.will1, this.will2, this.will3, this.error);

  bool get ok => error == null;

  double get totalWill => will1 + will2 + will3;
}

/// Parses funeral / debt / will amounts.
///
/// A non-positive remainder is not an error (an estate fully consumed by debt
/// is legitimate), but *negative* money and more than the estate in a single
/// mandatory will are rejected with a message.
DeductionsParseResult parseDeductions({
  required String funeralText,
  required String debtText,
  required String willText,
  required String will2Text,
  required String will3Text,
  required double estate,
}) {
  final funeral = parseNonNegativeAmount(funeralText, label: 'هزینه کفن');
  if (!funeral.ok) return _fail(funeral.error!);
  final debt = parseNonNegativeAmount(debtText, label: 'بدهی‌ها');
  if (!debt.ok) return _fail(debt.error!);
  final w1 = parseNonNegativeAmount(willText, label: 'وصیت');
  if (!w1.ok) return _fail(w1.error!);
  final w2 = parseNonNegativeAmount(will2Text, label: 'وصیت دوم');
  if (!w2.ok) return _fail(w2.error!);
  final w3 = parseNonNegativeAmount(will3Text, label: 'وصیت سوم');
  if (!w3.ok) return _fail(w3.error!);

  if (estate.isFinite && funeral.value + debt.value > estate) {
    return _fail('مجموع کفن و بدهی نمی‌تواند از مبلغ کل ترکه بیشتر باشد.');
  }
  final eachWill = [w1, w2, w3].map((w) => w.value).toList();
  for (var i = 0; i < eachWill.length; i++) {
    if (eachWill[i] > 0 && !estate.isFinite) {
      return _fail('مبلغ کل ترکه معتبر نیست.');
    }
    if (eachWill[i] > 0 && eachWill[i] > estate) {
      return _fail('مبلغ وصیت نمی‌تواند از مبلغ کل ترکه بیشتر باشد.');
    }
  }
  return DeductionsParseResult(
      funeral.value, debt.value, w1.value, w2.value, w3.value, null);
}

DeductionsParseResult _fail(String message) =>
    DeductionsParseResult(0, 0, 0, 0, 0, message);

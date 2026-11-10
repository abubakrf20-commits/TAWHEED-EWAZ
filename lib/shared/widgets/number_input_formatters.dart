import 'package:flutter/services.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// The app's number-field formatters — one home for what a typed digit run
/// becomes, so no screen restates the digit folding or the grouping.
///
/// Latin digits are a product rule (see `test/core/utils/latin_digits_guard_test.dart`)
/// and `intl` is banned in `lib`, so thousands grouping lives here with the
/// folding it has to happen before.

/// Folds a typed ۰-۹/٠-٩ into ASCII digits and leaves every other character
/// alone, so a free-text `HH:mm` field can never store a Persian-digit value
/// that the app would later print as Persian digits.
class LatinDigitFoldFormatter extends TextInputFormatter {
  const LatinDigitFoldFormatter();

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final folded = NumberFormat.normalizeDigits(newValue.text);
    if (folded == newValue.text) return newValue;
    return TextEditingValue(
      text: folded,
      selection: newValue.selection.copyWith(
        baseOffset: newValue.selection.baseOffset.clamp(0, folded.length),
        extentOffset: newValue.selection.extentOffset.clamp(0, folded.length),
      ),
    );
  }
}

/// The app's quantity-entry formatter: Latin digits AND live thousands
/// grouping, so «10000000» reads «10,000,000» while it is being typed.
///
/// Pair it only with a field whose reader is separator-tolerant —
/// [NumberFormat.parse] (and the inheritance `parseNonNegativeAmount` built on
/// it) strips the grouping marks. That is why identifier fields — a year, a
/// page, a hadith number, a PIN — keep a plain digit filter instead: they are
/// read by `int.tryParse` and their value is not a quantity.
///
/// The caret is RE-MAPPED, not collapsed. Inserting a separator moves every
/// index after it, so the position carries over by counting the DIGITS before
/// the old caret and landing after that many digits in the grouped text —
/// typing at the end, typing in the middle and selecting a range all keep
/// working.
class LatinGroupingFormatter extends TextInputFormatter {
  const LatinGroupingFormatter({this.allowDecimal = true});

  /// Whether a decimal point may stay in the field. Grams and money amounts
  /// read decimals; a head count never does.
  final bool allowDecimal;

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final selection = newValue.selection;
    final folded = NumberFormat.normalizeDigits(newValue.text);
    // A leading minus SURVIVES: several money fields (the inheritance debts,
    // the dongi expense) answer a negative amount with their own Persian
    // message, and silently eating the sign would take that voice away from
    // the validator and hand it a positive number instead.
    final negative = folded.trimLeft().startsWith('-');
    var kept =
        folded.replaceAll(allowDecimal ? _nonNumeric : _nonDigit, '');
    if (negative) kept = '-$kept';
    if (allowDecimal) {
      final firstDot = kept.indexOf('.');
      if (firstDot >= 0) {
        kept = kept.substring(0, firstDot + 1) +
            kept.substring(firstDot + 1).replaceAll('.', '');
      }
    }
    final grouped = NumberFormat.groupDigits(kept);
    if (grouped == newValue.text && selection.isCollapsed) return newValue;
    if (!selection.isValid) {
      return TextEditingValue(
          text: grouped,
          selection: TextSelection.collapsed(offset: grouped.length));
    }
    return TextEditingValue(
      text: grouped,
      selection: TextSelection(
        baseOffset: _caretFor(kept, grouped, selection.baseOffset),
        extentOffset: _caretFor(kept, grouped, selection.extentOffset),
      ),
    );
  }

  /// Maps a caret index of the UNGROUPED text onto the grouped text.
  static int _caretFor(String plain, String grouped, int offset) {
    if (offset <= 0) return 0;
    final digits = _digitsBefore(plain, offset);
    if (digits == 0) return 0;
    var seen = 0;
    for (var i = 0; i < grouped.length; i++) {
      if (_isDigit(grouped.codeUnitAt(i))) {
        seen++;
        if (seen == digits) return i + 1;
      }
    }
    return grouped.length;
  }

  static int _digitsBefore(String text, int offset) {
    final end = offset.clamp(0, text.length);
    var count = 0;
    for (var i = 0; i < end; i++) {
      if (_isDigit(text.codeUnitAt(i))) count++;
    }
    return count;
  }

  static bool _isDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;

  static final RegExp _nonDigit = RegExp(r'[^0-9]');
  static final RegExp _nonNumeric = RegExp(r'[^0-9.]');
}

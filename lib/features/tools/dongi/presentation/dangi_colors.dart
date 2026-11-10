import 'package:flutter/material.dart';
import 'package:tawheeed/features/tools/dongi/domain/dangi_categories.dart';
import 'package:tawheeed/features/tools/dongi/domain/entities/dangi_models.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/core/theme/theme.dart';

/// Parses an amount typed into a dangi form.
///
/// `double.tryParse` alone was wrong in three ways: it rejected the Persian
/// digits Persian keyboards and the app's own display use, it accepted
/// `1e400` (which is `Infinity`, and an infinite expense would poison every
/// balance in the group), and it silently turned unreadable text into nothing.
/// Returns `null` for anything that is not a finite amount.
double? parseDangiAmount(String? text) {
  final raw = (text ?? '').trim();
  if (raw.isEmpty) return null;
  var s = NumberFormat.normalizeDigits(raw)
      .replaceAll('٬', ',')
      .replaceAll('٫', '.');
  // Strict shape: an optional sign, then either plain digits or proper
  // thousands grouping, with an optional decimal part. This rejects `1e400`
  // (which parses as Infinity), `12abc`, `1/2` and `12,34,56`.
  final shape = RegExp(r'^-?\d{1,3}(,\d{3})*(\.\d+)?$|^-?\d+(\.\d+)?$');
  if (!shape.hasMatch(s)) return null;
  s = s.replaceAll(',', '');
  final value = double.tryParse(s);
  if (value == null || !value.isFinite) return null;
  return value;
}

/// Parses a stored group color, or `null` when it is not a usable color.
///
/// `colorHex` comes from the database and from restored backups, so it cannot
/// be trusted to be a well-formed `#RRGGBB` string: an older row, a
/// hand-edited backup or a shorthand used to crash the whole screen with a
/// `FormatException` from `int.parse`.
///
/// Accepted: `#RGB`, `#RRGGBB`, `#AARRGGBB`, `RRGGBB`, `0xFFRRGGBB`, in any
/// case, with optional surrounding whitespace.
Color? tryDangiColorFromHex(String? hex) {
  var s = (hex ?? '').trim();
  if (s.isEmpty) return null;
  s = s.replaceFirst(RegExp('^#'), '').replaceFirst(RegExp('^0[xX]'), '');
  if (s.isEmpty) return null;
  // Expand the #RGB shorthand.
  if (s.length == 3) s = s.split('').map((c) => '$c$c').join();
  if (s.length == 6) s = 'FF$s';
  if (s.length != 8) return null;
  final value = int.tryParse(s, radix: 16);
  if (value == null) return null;
  return Color(value);
}

/// [tryDangiColorFromHex] with a fallback instead of `null`.
Color dangiColorFromHex(String? hex,
        {Color fallback = const Color(0xFF00ACC1)}) =>
    tryDangiColorFromHex(hex) ?? fallback;

/// Whether [hex] can be rendered, so a broken stored value can be replaced by
/// the edit form instead of being written back unchanged.
bool isValidDangiHex(String? hex) => tryDangiColorFromHex(hex) != null;

/// The accent color of [group], or [fallback] when its stored value is broken.
Color dangiAccentColor(DangiGroupModel group,
        {Color fallback = const Color(0xFF00ACC1)}) =>
    dangiColorFromHex(group.colorHex, fallback: fallback);

/// Icon for a category (presentation mapping).
IconData categoryIcon(DangiExpenseCategory c) {
  switch (c) {
    case DangiExpenseCategory.food:
      return Icons.restaurant;
    case DangiExpenseCategory.transport:
      return Icons.directions_car;
    case DangiExpenseCategory.lodging:
      return Icons.hotel;
    case DangiExpenseCategory.shopping:
      return Icons.shopping_bag;
    case DangiExpenseCategory.fun:
      return Icons.celebration;
    case DangiExpenseCategory.other:
      return Icons.category;
  }
}

/// The settlement card's printed-paper palette.
///
/// The card is rendered offscreen and exported as an image, so like every share
/// surface it carries its own light page instead of following the app's theme —
/// the picture has to read on any chat background. It is the dongi feature's
/// colour source, which is why it lives here and not in the card's build method.
class DangiSettlementPalette {
  const DangiSettlementPalette._();

  /// The warm off-white page.
  static const Color paper = Color(0xFFFDFBF7);

  /// Names and amounts.
  static const Color ink = Color(0xFF263238);

  /// Section labels and the footer.
  static const Color muted = Color(0xFF78909C);

  /// The dark end of the header band and the amount chips' text (`TopicHues.dangi`
  /// is the light end).
  static const Color accentDark = Color(0xFF00838F);

  /// The «همه چیز تسویه است» box's hairline.
  static const Color settledBorder = Color(0xFFA5D6A7);
}

/// Color for a category (presentation mapping).
Color categoryColor(DangiExpenseCategory c) {
  switch (c) {
    case DangiExpenseCategory.food:
      return AppTheme.warning;
    case DangiExpenseCategory.transport:
      return const Color(0xFF1565C0);
    case DangiExpenseCategory.lodging:
      return const Color(0xFF6A1B9A);
    case DangiExpenseCategory.shopping:
      return AppTheme.success;
    case DangiExpenseCategory.fun:
      return const Color(0xFFAD1457);
    case DangiExpenseCategory.other:
      return const Color(0xFF546E7A);
  }
}

import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/core/constants/date_constants.dart';
import 'package:tawheeed/features/tools/dongi/domain/dangi_categories.dart';
import 'package:tawheeed/features/tools/dongi/domain/entities/dangi_models.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// All expenses of one calendar day, with their subtotal.
class DangiDateGroup {
  const DangiDateGroup({
    required this.date,
    required this.expenses,
    required this.subtotal,
  });

  final DateTime date;
  final List<DangiExpenseModel> expenses;
  final double subtotal;
}

/// All expenses of one category, with their total and share of the whole.
class DangiCategoryGroup {
  const DangiCategoryGroup({
    required this.category,
    required this.expenses,
    required this.total,
  });

  final DangiExpenseCategory category;
  final List<DangiExpenseModel> expenses;
  final double total;
}

/// Immutable, pre-grouped view of a group's expenses — what the report
/// screen renders before settlement so nothing is forgotten.
class DangiExpenseReport {
  const DangiExpenseReport._({
    required this.expenses,
    required this.byDate,
    required this.byCategory,
    required this.total,
  });

  final List<DangiExpenseModel> expenses;

  /// Grouped by day, newest day first; expenses within a day newest first.
  final List<DangiDateGroup> byDate;

  /// Grouped by category, biggest total first.
  final List<DangiCategoryGroup> byCategory;

  final double total;

  int get count => expenses.length;

  /// Largest single category total (for progress-bar scaling).
  double get maxCategoryTotal =>
      byCategory.isEmpty ? 0 : byCategory.first.total;
}

/// Builds the report from a flat expense list (pure, testable).
DangiExpenseReport buildDangiExpenseReport(List<DangiExpenseModel> expenses) {
  final byDateMap = <DateTime, List<DangiExpenseModel>>{};
  for (final e in expenses) {
    final day = DateTime(e.date.year, e.date.month, e.date.day);
    byDateMap.putIfAbsent(day, () => []).add(e);
  }
  final byDate = byDateMap.entries.map((entry) {
    final dayExpenses = List.of(entry.value)
      ..sort((a, b) => b.date.compareTo(a.date));
    return DangiDateGroup(
      date: entry.key,
      expenses: dayExpenses,
      subtotal: dayExpenses.fold(0, (s, e) => s + e.amount),
    );
  }).toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  final byCategoryMap = <DangiExpenseCategory, List<DangiExpenseModel>>{};
  for (final e in expenses) {
    byCategoryMap
        .putIfAbsent(DangiExpenseCategory.fromId(e.category), () => [])
        .add(e);
  }
  final byCategory = byCategoryMap.entries
      .map((entry) => DangiCategoryGroup(
            category: entry.key,
            expenses: entry.value,
            total: entry.value.fold(0, (s, e) => s + e.amount),
          ))
      .toList()
    ..sort((a, b) => b.total.compareTo(a.total));

  return DangiExpenseReport._(
    expenses: expenses,
    byDate: byDate,
    byCategory: byCategory,
    total: expenses.fold(0, (s, e) => s + e.amount),
  );
}

/// Persian date label like «14 مهر 1405».
String dangiDateLabel(DateTime date) {
  final j = Jalali.fromDateTime(date);
  return '${en(j.day)} ${DateConstants.persianMonths[j.month - 1]} '
      '${en(j.year)}';
}

/// Persian weekday + date label like «دوشنبه، 14 مهر 1405».
///
/// [DateConstants.weekDays] is indexed by the Gregorian [DateTime.weekday]
/// (1 = Monday .. 7 = Sunday), so we use that — not the Jalali weekday.
String dangiDateLabelWithWeekday(DateTime date) {
  return '${DateConstants.weekDays[date.weekday - 1]}، '
      '${dangiDateLabel(date)}';
}

/// Renders [n] with Latin (English) digits — shared standard.
String en(int n) => NumberFormat.en(n);

/// Formats [v] with Latin digits and the standard thousand separator
/// («,»): `450000` → «450,000». Non-whole values keep two decimals:
/// `1234.5` → «1,234.50». Grouping delegates to the shared [NumberFormat].
String faMoney(double v) {
  if (v < 0) return '-${faMoney(-v)}';
  if (v == v.roundToDouble()) return NumberFormat.formatPlain(v);
  final parts = v.toStringAsFixed(2).split('.');
  return '${NumberFormat.formatPlain(double.parse(parts[0]))}.${parts[1]}';
}

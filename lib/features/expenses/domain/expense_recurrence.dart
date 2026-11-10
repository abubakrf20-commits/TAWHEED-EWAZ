/// Recurrence rules for expenses («ورودی‌های تکراری»).
///
/// The pattern lives in [ExpenseModel.recurringType] as one of the constants
/// below. A recurring source row keeps [ExpenseModel.nextDueDate]; when that
/// date arrives, the expenses provider materializes a plain copy dated that
/// day and advances the source to the next cycle.
class ExpenseRecurrence {
  ExpenseRecurrence._();

  static const String daily = 'daily';
  static const String weekly = 'weekly';
  static const String monthly = 'monthly';

  static bool isSupported(String? type) =>
      type == daily || type == weekly || type == monthly;

  static String? label(String? type) {
    switch (type) {
      case daily:
        return 'روزانه';
      case weekly:
        return 'هفتگی';
      case monthly:
        return 'ماهانه';
      default:
        return null;
    }
  }

  /// The date of the cycle after [from] for the given pattern.
  ///
  /// Monthly keeps the same day-of-month and clamps to the target month's
  /// length (Jan 31 → Feb 28/29 → Mar 31), so a rent entry stays anchored.
  static DateTime next(DateTime from, String type) {
    final y = from.year;
    final m = from.month;
    final d = from.day;
    switch (type) {
      case daily:
        return DateTime(y, m, d + 1);
      case weekly:
        return DateTime(y, m, d + 7);
      case monthly:
        final nextMonthFirst = DateTime(y, m + 1);
        final lastDay =
            DateTime(nextMonthFirst.year, nextMonthFirst.month + 1, 0).day;
        return DateTime(nextMonthFirst.year, nextMonthFirst.month,
            d > lastDay ? lastDay : d);
      default:
        return from;
    }
  }
}

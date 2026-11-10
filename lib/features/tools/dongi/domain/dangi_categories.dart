/// Expense categories for dangi (bill-split) groups.
///
/// The [id] is what is stored in the database; [label] is the Persian name
/// shown in the UI. Icons and colors live in the presentation layer.
enum DangiExpenseCategory {
  food('food', 'غذا'),
  transport('transport', 'حمل و نقل'),
  lodging('lodging', 'اقامت'),
  shopping('shopping', 'خرید'),
  fun('fun', 'تفریح'),
  other('other', 'سایر');

  const DangiExpenseCategory(this.id, this.label);

  final String id;
  final String label;

  /// Resolves a stored id, falling back to [other] for unknown values
  /// (e.g. rows created before the category column existed).
  static DangiExpenseCategory fromId(String id) =>
      values.firstWhere((c) => c.id == id, orElse: () => other);
}

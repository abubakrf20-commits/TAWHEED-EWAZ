class ExpenseModel {
  final String id;
  final String title;
  final double amount;
  final bool isIncome;
  final String category;
  final DateTime date;
  final String? note;

  /// Recurring source row: [recurringType] is one of ExpenseRecurrence's
  /// patterns and [nextDueDate] is the next date whose copy still needs to be
  /// materialized. Generated copies are plain rows (both null).
  final bool isRecurring;
  final String? recurringType;
  final DateTime? nextDueDate;
  final DateTime createdAt;

  const ExpenseModel({
    required this.id,
    required this.title,
    required this.amount,
    this.isIncome = false,
    this.category = 'عام',
    required this.date,
    this.note,
    this.isRecurring = false,
    this.recurringType,
    this.nextDueDate,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? date;

  ExpenseModel copyWith({
    String? id,
    String? title,
    double? amount,
    bool? isIncome,
    String? category,
    DateTime? date,
    String? note,
    bool? isRecurring,
    Object? recurringType = _unset,
    Object? nextDueDate = _unset,
    DateTime? createdAt,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      isIncome: isIncome ?? this.isIncome,
      category: category ?? this.category,
      date: date ?? this.date,
      note: note ?? this.note,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringType: recurringType == _unset
          ? this.recurringType
          : recurringType as String?,
      nextDueDate:
          nextDueDate == _unset ? this.nextDueDate : nextDueDate as DateTime?,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static const Object _unset = Object();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'isIncome': isIncome,
        'category': category,
        'date': date.toIso8601String(),
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ExpenseModel.fromJson(Map<String, dynamic> json) => ExpenseModel(
        id: json['id'] as String,
        title: json['title'] as String,
        amount: (json['amount'] as num).toDouble(),
        isIncome: json['isIncome'] as bool? ?? false,
        category: json['category'] as String? ?? 'عام',
        date: DateTime.parse(json['date'] as String),
        note: json['note'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
      );
}

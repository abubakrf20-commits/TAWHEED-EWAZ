/// A dangi (bill-split) group.
class DangiGroupModel {
  const DangiGroupModel({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String colorHex;
  final DateTime createdAt;

  DangiGroupModel copyWith({
    String? id,
    String? name,
    String? colorHex,
    DateTime? createdAt,
  }) {
    return DangiGroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// A member of a dangi group.
class DangiMemberModel {
  const DangiMemberModel({
    required this.id,
    required this.groupId,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String groupId;
  final String name;
  final DateTime createdAt;
}

/// An expense: one member paid. By default everyone splits it equally, but the
/// expense may carry per-member [consumers] amounts (each person's own dish).
class DangiExpenseModel {
  const DangiExpenseModel({
    required this.id,
    required this.groupId,
    required this.payerId,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    required this.createdAt,
    this.consumers = const {},
  });

  final String id;
  final String groupId;
  final String payerId;
  final String title;

  /// Expense category id from [DangiExpenseCategory] (e.g. 'food').
  final String category;
  final double amount;
  final DateTime date;
  final DateTime createdAt;

  /// memberId → consumed amount. Empty keeps the legacy equal split among all
  /// group members; non-empty means each listed member owes exactly their own
  /// amount («ساندویچ 200 / ساندویچ 300 / پیتزا 500»).
  final Map<String, double> consumers;

  /// True when this expense is shared equally by everyone (no per-member list).
  bool get isSharedEqually => consumers.isEmpty;

  DangiExpenseModel copyWith({
    String? payerId,
    String? category,
    double? amount,
    DateTime? date,
    String? title,
    Map<String, double>? consumers,
  }) {
    return DangiExpenseModel(
      id: id,
      groupId: groupId,
      payerId: payerId ?? this.payerId,
      title: title ?? this.title,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      createdAt: createdAt,
      consumers: consumers ?? this.consumers,
    );
  }
}

/// Everything a group delete removes, captured *before* the rows go away so the
/// UI can undo it by re-inserting the exact prior rows (same ids, same consumer
/// shares) rather than recomputing balances.
class DangiGroupSnapshot {
  const DangiGroupSnapshot({
    required this.group,
    required this.members,
    required this.expenses,
  });

  final DangiGroupModel group;
  final List<DangiMemberModel> members;
  final List<DangiExpenseModel> expenses;
}

/// Everything a member delete removes or mutates: the member, the expenses they
/// paid (deleted outright) and the expenses whose per-member consumer share was
/// stripped. Undo re-inserts all three in their original form.
class DangiMemberSnapshot {
  const DangiMemberSnapshot({
    required this.member,
    required this.ownExpenses,
    required this.strippedExpenses,
  });

  final DangiMemberModel member;
  final List<DangiExpenseModel> ownExpenses;
  final List<DangiExpenseModel> strippedExpenses;
}

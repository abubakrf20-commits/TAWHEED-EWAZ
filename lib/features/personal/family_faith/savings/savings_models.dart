/// Data model and money math for «قلک» (stage 3).
///
/// Pure Dart. A goal is a target and a list of deposits; a withdrawal is simply
/// a negative deposit, which keeps the history honest (the balance is always
/// the sum, and nothing has to be reconciled). No interest, no projection
/// promises — the ETA is arithmetic on what the user actually saved, and is
/// withheld until there is enough history to mean anything.
library;

class SavingsGoal {
  const SavingsGoal({
    required this.id,
    required this.title,
    required this.targetAmount,
    required this.createdAt,
    this.targetDate,
    this.iconKey = 'savings',
    this.accentKey = 'gold',
    this.note = '',
    this.remindWeekly = false,
    this.archived = false,
  });

  final String id;
  final String title;
  final double targetAmount;
  final DateTime createdAt;

  /// Optional deadline. When set, the detail screen can say how much a month
  /// would be needed to arrive on time.
  final DateTime? targetDate;
  final String iconKey;
  final String accentKey;
  final String note;

  /// Weekly deposit nudge; off by default.
  final bool remindWeekly;
  final bool archived;

  bool get isActive => !archived;

  SavingsGoal copyWith({
    String? title,
    double? targetAmount,
    Object? targetDate = _unset,
    String? iconKey,
    String? accentKey,
    String? note,
    bool? remindWeekly,
    bool? archived,
  }) =>
      SavingsGoal(
        id: id,
        title: title ?? this.title,
        targetAmount: targetAmount ?? this.targetAmount,
        targetDate: targetDate == _unset ? this.targetDate : targetDate as DateTime?,
        iconKey: iconKey ?? this.iconKey,
        accentKey: accentKey ?? this.accentKey,
        note: note ?? this.note,
        remindWeekly: remindWeekly ?? this.remindWeekly,
        archived: archived ?? this.archived,
        createdAt: createdAt,
      );
}

const Object _unset = Object();

class Deposit {
  const Deposit({
    required this.id,
    required this.goalId,
    required this.date,
    required this.amount,
    this.note = '',
  });

  final String id;
  final String goalId;
  final DateTime date;

  /// Negative for a withdrawal.
  final double amount;
  final String note;

  bool get isWithdrawal => amount < 0;
}

/// Everything the goal card and detail screen need, computed once.
class SavingsProgress {
  const SavingsProgress({
    required this.saved,
    required this.target,
    required this.remaining,
    required this.fraction,
    required this.depositCount,
    required this.milestonesReached,
    this.monthlyAverage,
    this.etaDays,
    this.monthsToDeadline,
    this.perMonthNeeded,
    this.daysSinceFirstDeposit,
  });

  final double saved;
  final double target;
  final double remaining;

  /// 0…1 (capped), safe when [target] is zero.
  final double fraction;
  final int depositCount;

  /// Which of 25/50/75/100 % are reached, as percentages.
  final List<int> milestonesReached;

  /// Mean positive deposit per month over the last three months, when any.
  final double? monthlyAverage;

  /// Days left at the observed pace; null until there is enough history.
  final int? etaDays;

  /// Whole months from today to [SavingsGoal.targetDate]; null without one.
  final int? monthsToDeadline;

  /// What would be needed each month to arrive on [SavingsGoal.targetDate].
  final double? perMonthNeeded;
  final int? daysSinceFirstDeposit;

  bool get isComplete => target > 0 && saved >= target;
  bool get hasEta => etaDays != null;
}

const List<int> kSavingsMilestones = [25, 50, 75, 100];

/// Average monthly deposit over the trailing [months] months.
///
/// Only positive deposits count: a withdrawal must not make the pace look
/// worse than the saving habit is, and it must not be able to divide by zero.
double? savingsMonthlyAverage(
  List<Deposit> deposits,
  DateTime now, {
  int months = 3,
}) {
  final end = DateTime(now.year, now.month, now.day);
  final start = DateTime(end.year, end.month - months, end.day);
  var total = 0.0;
  var any = false;
  for (final deposit in deposits) {
    if (deposit.amount <= 0) continue;
    final day = DateTime(deposit.date.year, deposit.date.month, deposit.date.day);
    if (day.isBefore(start) || day.isAfter(end)) continue;
    total += deposit.amount;
    any = true;
  }
  if (!any) return null;
  return total / months;
}

/// Full progress picture for one goal.
///
/// The ETA needs **at least two deposits spread over at least 14 days**; below
/// that, one deposit would imply an absurdly fast pace and the card would
/// promise a date it cannot keep.
SavingsProgress savingsProgress({
  required SavingsGoal goal,
  required List<Deposit> deposits,
  required DateTime now,
}) {
  final saved = deposits.fold<double>(0, (sum, d) => sum + d.amount);
  final target = goal.targetAmount <= 0 ? 0.0 : goal.targetAmount;
  final remaining = target - saved < 0 ? 0.0 : target - saved;
  final fraction = target <= 0 ? (saved > 0 ? 1.0 : 0.0) : (saved / target).clamp(0.0, 1.0);

  final positives = deposits.where((d) => d.amount > 0).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  final firstPositive = positives.isEmpty ? null : positives.first.date;
  final daysSinceFirst = firstPositive == null
      ? null
      : DateTime(now.year, now.month, now.day)
          .difference(DateTime(
              firstPositive.year, firstPositive.month, firstPositive.day))
          .inDays;

  int? etaDays;
  if (positives.length >= 2 && (daysSinceFirst ?? 0) >= 14) {
    final perDay = saved / daysSinceFirst!.clamp(1, 100000);
    if (perDay > 0) etaDays = (remaining / perDay).ceil();
  }

  final average = savingsMonthlyAverage(deposits, now);

  int? monthsToDeadline;
  double? perMonthNeeded;
  final deadline = goal.targetDate;
  if (deadline != null) {
    final today = DateTime(now.year, now.month, now.day);
    final months = (deadline.year - today.year) * 12 +
        (deadline.month - today.month) +
        (deadline.day >= today.day ? 0 : -1);
    monthsToDeadline = months < 0 ? 0 : months;
    perMonthNeeded =
        months <= 0 ? remaining : remaining / months;
  }

  return SavingsProgress(
    saved: saved,
    target: target,
    remaining: remaining,
    fraction: fraction.toDouble(),
    depositCount: deposits.length,
    milestonesReached: [
      for (final milestone in kSavingsMilestones)
        if (fraction * 100 + 0.0001 >= milestone) milestone,
    ],
    monthlyAverage: average,
    etaDays: etaDays,
    monthsToDeadline: monthsToDeadline,
    perMonthNeeded: perMonthNeeded,
    daysSinceFirstDeposit: daysSinceFirst,
  );
}

/// The first milestone crossing between [before] and [after], or null.
///
/// Used for the one gentle in-app celebration per milestone; crossing two at
/// once (a large deposit) reports the highest one so the user sees 50 %, not
/// two animations in a row.
int? crossedMilestone(double before, double after) {
  final from = (before * 100).clamp(0, 100);
  final to = (after * 100).clamp(0, 100);
  int? crossed;
  for (final milestone in kSavingsMilestones) {
    if (from < milestone && to >= milestone) crossed = milestone;
  }
  return crossed;
}

/// Guard for a withdrawal: it can never take the balance below zero.
double maxWithdrawable(List<Deposit> deposits) {
  final saved = deposits.fold<double>(0, (sum, d) => sum + d.amount);
  return saved < 0 ? 0 : saved;
}

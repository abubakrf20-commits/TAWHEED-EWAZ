import 'package:tawheeed/features/tools/dongi/domain/dangi_settlement.dart';
import 'package:tawheeed/features/tools/dongi/domain/entities/dangi_models.dart';

/// Per-member breakdown of a group's expenses — what each person paid, what
/// they consumed and their net balance. Used by the report's «تفکیک اعضا»
/// view and by the balance chips on the group screen.
class DangiMemberSummary {
  const DangiMemberSummary({
    required this.member,
    required this.paid,
    required this.consumed,
    required this.net,
  });

  final DangiMemberModel member;

  /// Sum of expenses this member paid.
  final double paid;

  /// Sum of what this member actually consumed: for consumer expenses their
  /// exact per-member amount, otherwise their equal split share.
  final double consumed;

  /// `paid − consumed`. Positive = the member is a creditor (should receive),
  /// negative = they owe. Matches [DangiSettlement.balances].
  final double net;
}

/// Computes the per-member summaries for a group. Pure and testable.
///
/// Consumer expenses credit each listed member with exactly their own amount;
/// every other expense is split equally among all members. Members that never
/// appear still get their equal-split shares (e.g. as the payer).
List<DangiMemberSummary> buildDangiMemberSummaries({
  required List<DangiMemberModel> members,
  required List<DangiExpenseModel> expenses,
}) {
  if (members.isEmpty || expenses.isEmpty) return const [];

  final byIndex = <int, Map<String, double>>{};
  for (var i = 0; i < expenses.length; i++) {
    if (expenses[i].consumers.isNotEmpty) byIndex[i] = expenses[i].consumers;
  }

  final nets = DangiSettlement.balances(
    memberIds: [for (final m in members) m.id],
    expenses: [
      for (final e in expenses) (payerId: e.payerId, amount: e.amount),
    ],
    consumerSharesByIndex: byIndex,
  );

  final paid = <String, double>{for (final m in members) m.id: 0};
  final consumed = <String, double>{for (final m in members) m.id: 0};

  for (final e in expenses) {
    if (paid.containsKey(e.payerId)) {
      paid[e.payerId] = (paid[e.payerId] ?? 0.0) + e.amount;
    }
    if (e.consumers.isNotEmpty) {
      e.consumers.forEach((id, amt) {
        if (consumed.containsKey(id)) {
          consumed[id] = (consumed[id] ?? 0.0) + amt;
        }
      });
    } else {
      final per = e.amount / members.length;
      for (final m in members) {
        consumed[m.id] = (consumed[m.id] ?? 0.0) + per;
      }
    }
  }

  return [
    for (final m in members)
      DangiMemberSummary(
        member: m,
        paid: paid[m.id] ?? 0,
        consumed: consumed[m.id] ?? 0,
        net: nets[m.id] ?? 0,
      ),
  ]..sort((a, b) => b.paid.compareTo(a.paid));
}

import 'dart:math' as math;

import 'package:tawheeed/features/tools/dongi/domain/entities/dangi_models.dart';

/// One debt edge: [fromId] owes [toId] the given amount.
class SettlementTransfer {
  const SettlementTransfer({
    required this.fromId,
    required this.toId,
    required this.amount,
  });

  final String fromId;
  final String toId;
  final double amount;
}

/// Pure settlement for a dangi (bill-split) group.
///
/// Every expense is split equally among ALL members of the group — unless the
/// expense carries per-member [consumers][consumerSharesByIndex], in which
/// case each listed member owes exactly their own amount and the payer is
/// credited with the sum. This class computes each member's net balance
/// (paid − owed) and then reduces the debt graph to a minimal set of
/// transfers (who pays whom, how much).
class DangiSettlement {
  DangiSettlement._();

  /// Member ids of the group, e.g. `['a', 'b', 'c']`.
  static List<SettlementTransfer> settle({
    required List<String> memberIds,
    required List<({String payerId, double amount})> expenses,

    /// Per-expense consumer amounts (memberId → consumed amount), keyed by the
    /// expense's index in [expenses]. When an expense has a non-empty entry
    /// here, each listed member owes exactly that amount and the payer is
    /// credited with the sum of the listed shares; absent entries fall back to
    /// the legacy equal split among all members.
    Map<int, Map<String, double>> consumerSharesByIndex = const {},
  }) {
    if (memberIds.isEmpty) return const [];

    final balances = DangiSettlement.balances(
      memberIds: memberIds,
      expenses: expenses,
      consumerSharesByIndex: consumerSharesByIndex,
    );

    // Greedy minimal-transaction matching with rounding tolerance.
    final creditors = <String, double>{
      for (final e in balances.entries)
        if (e.value > 0.01) e.key: e.value,
    };
    final debtors = <String, double>{
      for (final e in balances.entries)
        if (e.value < -0.01) e.key: -e.value,
    };

    final transfers = <SettlementTransfer>[];
    while (debtors.isNotEmpty && creditors.isNotEmpty) {
      // Pick the largest debtor and the largest creditor.
      final from = debtors.entries.reduce((a, b) => a.value > b.value ? a : b);
      final to = creditors.entries.reduce((a, b) => a.value > b.value ? a : b);
      final amount = math.min(from.value, to.value);
      transfers.add(SettlementTransfer(
        fromId: from.key,
        toId: to.key,
        amount: _round2(amount),
      ));
      debtors[from.key] = from.value - amount;
      creditors[to.key] = to.value - amount;
      if ((debtors[from.key] ?? 0.0) < 0.01) debtors.remove(from.key);
      if ((creditors[to.key] ?? 0.0) < 0.01) creditors.remove(to.key);
    }
    return transfers;
  }

  /// Net balance per member for the given expenses: **positive** = will
  /// receive, **negative** = owes. Shares the same per-expense rules as
  /// [settle], so the balances shown in the UI always match the drawn-up
  /// transfers. Pure and shared with the report/group screens.
  static Map<String, double> balances({
    required List<String> memberIds,
    required List<({String payerId, double amount})> expenses,
    Map<int, Map<String, double>> consumerSharesByIndex = const {},
  }) {
    if (memberIds.isEmpty) return {};

    final balances = <String, double>{for (final id in memberIds) id: 0.0};
    final share = <String, double>{for (final id in memberIds) id: 0.0};
    final memberSet = balances.keys.toSet();
    final count = memberIds.length;

    for (var i = 0; i < expenses.length; i++) {
      final e = expenses[i];
      // Legacy row whose payer is no longer in the group: nobody can be
      // credited for it, and charging members for it would invent a phantom
      // debt, so it cannot participate in settlement at all.
      if (!memberSet.contains(e.payerId)) continue;
      final shares = consumerSharesByIndex[i];
      if (shares != null && shares.isNotEmpty) {
        // Per-member consumption: each listed member owes exactly their own
        // amount and the payer is credited with the sum of those shares.
        // Shares naming a removed member are ignored on both sides — not
        // owed, not credited — so nobody is left holding the residual.
        var paid = 0.0;
        shares.forEach((id, amt) {
          if (!memberSet.contains(id)) return;
          share[id] = (share[id] ?? 0) + amt;
          paid += amt;
        });
        balances[e.payerId] = (balances[e.payerId] ?? 0) + paid;
      } else {
        final perPerson = e.amount / count;
        balances[e.payerId] = (balances[e.payerId] ?? 0) + e.amount;
        for (final id in memberIds) {
          share[id] = (share[id] ?? 0) + perPerson;
        }
      }
    }
    for (final id in memberIds) {
      balances[id] = (balances[id] ?? 0) - (share[id] ?? 0);
    }
    return balances;
  }

  static double _round2(double v) => (v * 100).roundToDouble() / 100;
}

/// Reserved category id marking a settlement row inside the expense table.
///
/// «ثبت تسویه» stores one row per transfer: the debtor as payer and the
/// creditor as the only consumer. The existing balance math therefore zeroes
/// every debt without any schema change, and the records survive
/// backup/restore like normal expenses (and can be deleted to cancel one).
const String dangiSettlementCategory = 'settlement';

/// Whether [e] is a recorded settlement (a transfer) instead of a real
/// spending — totals, reports and the expense list treat the two differently.
bool isDangiSettlement(DangiExpenseModel e) =>
    e.category == dangiSettlementCategory;

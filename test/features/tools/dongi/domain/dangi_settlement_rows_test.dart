import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/tools/dongi/domain/dangi_settlement.dart';
import 'package:tawheeed/features/tools/dongi/domain/entities/dangi_models.dart';

/// Settlement rows («ثبت تسویه») are ordinary expense rows: the debtor is the
/// payer and the creditor the only consumer — these tests pin that contract,
/// because the zeroing of every balance depends on it.
void main() {
  const members = ['a', 'b', 'c'];

  DangiExpenseModel row({
    required String id,
    required String payerId,
    required double amount,
    Map<String, double> consumers = const {},
    String category = 'food',
  }) =>
      DangiExpenseModel(
        id: id,
        groupId: 'g',
        payerId: payerId,
        title: 'x',
        category: category,
        amount: amount,
        date: DateTime(2026, 9, 22),
        createdAt: DateTime(2026, 9, 22),
        consumers: consumers,
      );

  test('isDangiSettlement only matches the reserved category id', () {
    expect(isDangiSettlement(row(id: '1', payerId: 'a', amount: 1)), isFalse);
    expect(
      isDangiSettlement(row(
          id: '2', payerId: 'a', amount: 1, category: dangiSettlementCategory)),
      isTrue,
    );
  });

  test('recording the transfers zeroes every balance', () {
    final expenses = <({String payerId, double amount})>[
      (payerId: 'a', amount: 300),
    ];
    final before = DangiSettlement.balances(
      memberIds: members,
      expenses: expenses,
    );
    expect(before['a'], closeTo(200, 0.01));
    expect(before['b'], closeTo(-100, 0.01));
    expect(before['c'], closeTo(-100, 0.01));

    final transfers = DangiSettlement.settle(
      memberIds: members,
      expenses: expenses,
    );
    expect(transfers, hasLength(2));

    // The same data with the transfers stored as settlement rows …
    final withSettlements = [
      ...expenses,
      for (final t in transfers) (payerId: t.fromId, amount: t.amount),
    ];
    final shares = <int, Map<String, double>>{
      for (var i = 0; i < transfers.length; i++)
        expenses.length + i: {transfers[i].toId: transfers[i].amount},
    };

    final after = DangiSettlement.balances(
      memberIds: members,
      expenses: withSettlements,
      consumerSharesByIndex: shares,
    );
    for (final id in members) {
      expect(after[id], closeTo(0, 0.01), reason: 'balance of $id');
    }

    // … and nothing is left to settle.
    expect(
      DangiSettlement.settle(
        memberIds: members,
        expenses: withSettlements,
        consumerSharesByIndex: shares,
      ),
      isEmpty,
    );
  });
}

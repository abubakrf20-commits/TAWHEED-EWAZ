import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/tools/dongi/domain/dangi_settlement.dart';

void main() {
  group('DangiSettlement', () {
    test('empty group returns empty', () {
      expect(DangiSettlement.settle(memberIds: [], expenses: []), isEmpty);
    });

    test('single payer split equally', () {
      final t = DangiSettlement.settle(
        memberIds: ['a', 'b', 'c'],
        expenses: [(payerId: 'a', amount: 300)],
      );
      // b and c each owe 100 to a => 2 transfers
      expect(t.length, 2);
      expect(t.every((e) => e.toId == 'a'), isTrue);
      expect(t.fold(0.0, (s, e) => s + e.amount), closeTo(200, 0.01));
    });

    test('balanced expenses produce no transfers', () {
      final t = DangiSettlement.settle(
        memberIds: ['a', 'b'],
        expenses: [(payerId: 'a', amount: 100), (payerId: 'b', amount: 100)],
      );
      expect(t, isEmpty);
    });

    test('two payers minimal transfers', () {
      final t = DangiSettlement.settle(
        memberIds: ['a', 'b', 'c'],
        expenses: [(payerId: 'a', amount: 120), (payerId: 'b', amount: 60)],
      );
      // total 180 /3=60 each => a +60, b 0, c -60 => c -> a 60
      expect(t.length, 1);
      expect(t.first.fromId, 'c');
      expect(t.first.toId, 'a');
      expect(t.first.amount, closeTo(60, 0.01));
    });

    test('consumer shares override the equal split', () {
      // a pays 500, consumes 200; b consumes 300; c consumes nothing.
      final t = DangiSettlement.settle(
        memberIds: ['a', 'b', 'c'],
        expenses: [(payerId: 'a', amount: 500)],
        consumerSharesByIndex: {
          0: {'a': 200, 'b': 300},
        },
      );
      // a is +300, b is −300, c is 0 => single transfer b → a 300.
      expect(t.length, 1);
      expect(t.first.fromId, 'b');
      expect(t.first.toId, 'a');
      expect(t.first.amount, closeTo(300, 0.01));
    });

    test('mixed equal and consumer expenses settle correctly', () {
      // Expense 0: equal split 300 / 3 = 100 each, paid by a.
      // Expense 1: consumer shares {a: 200, b: 250, c: 150} (sum 600), paid by c.
      final t = DangiSettlement.settle(
        memberIds: ['a', 'b', 'c'],
        expenses: [
          (payerId: 'a', amount: 300),
          (payerId: 'c', amount: 600),
        ],
        consumerSharesByIndex: {
          1: {'a': 200, 'b': 250, 'c': 150},
        },
      );
      // a: +300 −100 −200 = 0; b: −100 −250 = −350; c: +600 −100 −150 = +350.
      // => single transfer b → c 350.
      expect(t.length, 1);
      expect(t.first.fromId, 'b');
      expect(t.first.toId, 'c');
      expect(t.first.amount, closeTo(350, 0.01));
    });
  });

  group('DangiSettlement.balances', () {
    test('matches the settle results per member', () {
      final b = DangiSettlement.balances(
        memberIds: ['a', 'b', 'c'],
        expenses: [
          (payerId: 'a', amount: 300),
          (payerId: 'c', amount: 600),
        ],
        consumerSharesByIndex: {
          1: {'a': 200, 'b': 250, 'c': 150},
        },
      );
      expect(b['a'], closeTo(0, 0.01));
      expect(b['b'], closeTo(-350, 0.01));
      expect(b['c'], closeTo(350, 0.01));
    });

    test('empty group yields an empty map', () {
      expect(
        DangiSettlement.balances(memberIds: [], expenses: []),
        isEmpty,
      );
    });
  });
}

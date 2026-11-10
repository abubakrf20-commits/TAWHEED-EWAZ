import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart' show Color;
import 'package:tawheeed/features/tools/dongi/domain/dangi_settlement.dart';
import 'package:tawheeed/features/tools/dongi/presentation/dangi_colors.dart';

void main() {
  group('settlement leaves no residual', () {
    /// Balances after recording [DangiSettlement.settle]'s output as extra
    /// expenses must be zero, otherwise «تسویه» cannot close the group.
    Map<String, double> balancesAfterSettle({
      required List<String> memberIds,
      required List<({String payerId, double amount})> expenses,
      Map<int, Map<String, double>> consumerSharesByIndex = const {},
    }) {
      final transfers = DangiSettlement.settle(
        memberIds: memberIds,
        expenses: expenses,
        consumerSharesByIndex: consumerSharesByIndex,
      );
      final withTransfers = [
        ...expenses,
        for (final t in transfers)
          (
            payerId: t.fromId,
            amount: t.amount,
          ),
      ];
      final shares = <int, Map<String, double>>{
        ...consumerSharesByIndex,
        for (var i = 0; i < transfers.length; i++)
          expenses.length + i: {transfers[i].toId: transfers[i].amount},
      };
      return DangiSettlement.balances(
        memberIds: memberIds,
        expenses: withTransfers,
        consumerSharesByIndex: shares,
      );
    }

    void expectClosed(String name, List<String> ids,
        List<({String payerId, double amount})> expenses,
        {Map<int, Map<String, double>> consumerSharesByIndex = const {}}) {
      final balances = balancesAfterSettle(
        memberIds: ids,
        expenses: expenses,
        consumerSharesByIndex: consumerSharesByIndex,
      );
      for (final id in ids) {
        // Anything left must be sub-rial dust (an amount under one rial cannot
        // be recorded as a transfer, and the UI prints whole rials).
        expect(balances[id] ?? 0, closeTo(0, 0.0101), reason: '$name / $id');
      }
    }

    test('a three-way split with thirds closes exactly', () {
      expectClosed('thirds', [
        'a',
        'b',
        'c'
      ], [
        (payerId: 'a', amount: 100),
        (payerId: 'b', amount: 100),
        (payerId: 'c', amount: 100.01),
      ]);
    });

    test('a repeating-decimal split closes exactly', () {
      // 100 / 3 is not representable, so per-member shares are endless
      // fractions: the emitted transfer amounts must still add up.
      expectClosed('repeating', [
        'a',
        'b',
        'c',
        'd'
      ], [
        (payerId: 'a', amount: 1000),
        (payerId: 'b', amount: 1),
        (payerId: 'c', amount: 1),
        (payerId: 'd', amount: 1),
      ]);
    });

    test('many small expenses close exactly', () {
      expectClosed('many', [
        'a',
        'b',
        'c'
      ], [
        for (var i = 0; i < 20; i++)
          (payerId: ['a', 'b', 'c'][i % 3], amount: 33.33),
      ]);
    });

    test('per-member consumer shares close exactly', () {
      expectClosed('consumers', [
        'a',
        'b',
        'c'
      ], [
        (payerId: 'a', amount: 300),
        (payerId: 'b', amount: 250),
      ], consumerSharesByIndex: {
        0: {'a': 100, 'b': 120, 'c': 80},
        1: {'a': 90, 'b': 160},
      });
    });

    test('balances always sum to zero', () {
      final balances = DangiSettlement.balances(
        memberIds: ['a', 'b', 'c'],
        expenses: [
          (payerId: 'a', amount: 300.55),
          (payerId: 'c', amount: 12.45),
        ],
      );
      expect(balances.values.fold(0.0, (s, v) => s + v), closeTo(0, 0.0001));
    });

    test('a sub-rial balance produces no transfer', () {
      // 0.004 rial of dust must not become a settlement row.
      final t = DangiSettlement.settle(
        memberIds: ['a', 'b'],
        expenses: [(payerId: 'a', amount: 0.004)],
      );
      expect(t, isEmpty);
    });

    test('rounding is carried so a long chain of transfers stays exact', () {
      // Odd amounts across several members: independently rounding each
      // transfer used to leave a few hundredths behind, so «تسویه» never
      // reached zero.
      const payers = ['a', 'b', 'c', 'd', 'e', 'a', 'b', 'c', 'd', 'a'];
      final expenses = [
        for (final p in payers) (payerId: p, amount: 33.33),
      ];
      final t = DangiSettlement.settle(
        memberIds: ['a', 'b', 'c', 'd', 'e'],
        expenses: expenses,
      );
      expect(t, isNotEmpty);
      final balances = balancesAfterSettle(
          memberIds: ['a', 'b', 'c', 'd', 'e'], expenses: expenses);
      for (final entry in balances.entries) {
        expect(entry.value, closeTo(0, 0.0101), reason: entry.key);
      }
    });

    test('no transfer names a non-member', () {
      final t = DangiSettlement.settle(
        memberIds: ['a', 'b'],
        expenses: [
          // Legacy row: the payer is not a member of the group.
          (payerId: 'ghost', amount: 500),
          (payerId: 'a', amount: 100),
        ],
      );
      for (final transfer in t) {
        expect(t.any((e) => e.fromId == 'ghost' || e.toId == 'ghost'), isFalse);
        expect(['a', 'b'], contains(transfer.fromId));
        expect(['a', 'b'], contains(transfer.toId));
      }
    });

    test('a legacy non-member payer does not create a phantom balance', () {
      final balances = DangiSettlement.balances(
        memberIds: ['a', 'b'],
        expenses: [(payerId: 'ghost', amount: 500)],
      );
      expect(balances.keys.toSet(), {'a', 'b'});
    });

    test('a consumer naming a removed member leaves nobody with its share', () {
      final balances = DangiSettlement.balances(
        memberIds: ['a', 'b'],
        expenses: [(payerId: 'a', amount: 300)],
        consumerSharesByIndex: {
          0: {'a': 100, 'gone': 200},
        },
      );
      // 'gone' is not a member, so its 200 is ignored on both sides: the payer
      // is not credited for it and no phantom debt is left behind.
      expect(balances.keys.toSet(), {'a', 'b'});
      expect(balances['a'], closeTo(0, 0.0001));
      expect(balances['b'], closeTo(0, 0.0001));
      expect(balances.values.fold(0.0, (s, v) => s + v), closeTo(0, 0.0001));
    });

    test('transfer amounts are never negative or zero', () {
      final t = DangiSettlement.settle(
        memberIds: ['a', 'b', 'c'],
        expenses: [
          (payerId: 'a', amount: 0.01),
          (payerId: 'b', amount: 0.01),
          (payerId: 'c', amount: 0.01),
        ],
      );
      for (final transfer in t) {
        expect(transfer.amount, greaterThan(0));
        expect(transfer.fromId, isNot(transfer.toId));
      }
    });
  });

  group('tryDangiColorFromHex', () {
    test('reads the well-formed shapes', () {
      expect(tryDangiColorFromHex('#00ACC1'), const Color(0xFF00ACC1));
      expect(tryDangiColorFromHex('00ACC1'), const Color(0xFF00ACC1));
      // #RGB shorthand.
      expect(tryDangiColorFromHex('#0AC'), const Color(0xFF00AACC));
      // #AARRGGBB.
      expect(tryDangiColorFromHex('#8000ACC1'), const Color(0x8000ACC1));
      expect(tryDangiColorFromHex('  #00acc1  '), const Color(0xFF00ACC1));
      expect(tryDangiColorFromHex('0xFF00ACC1'), const Color(0xFF00ACC1));
    });

    test('returns null instead of throwing for broken values', () {
      for (final value in [
        null,
        '',
        '   ',
        '#',
        '0x',
        'red',
        '#0ACC1',
        '#00AC',
        '#00ACC',
        '#00ACC12',
        '#00ACC1234',
        '#GGGGGG',
        '##00ACC1',
        'rgb(1,2,3)',
      ]) {
        expect(tryDangiColorFromHex(value), isNull,
            reason: 'accepted "$value"');
      }
    });

    test('dangiColorFromHex falls back', () {
      expect(dangiColorFromHex('nope', fallback: const Color(0xFF123456)),
          const Color(0xFF123456));
      expect(dangiColorFromHex(null), isNotNull);
    });

    test('isValidDangiHex mirrors the parser', () {
      expect(isValidDangiHex('#00ACC1'), isTrue);
      expect(isValidDangiHex(''), isFalse);
      expect(isValidDangiHex('nope'), isFalse);
    });
  });

  group('parseDangiAmount', () {
    test('reads Latin and Persian digits with separators', () {
      expect(parseDangiAmount('1234'), 1234);
      expect(parseDangiAmount('۱۲۳۴'), 1234);
      expect(parseDangiAmount('١٢٣٤'), 1234);
      expect(parseDangiAmount('1,234'), 1234);
      expect(parseDangiAmount('۱٬۲۳۴'), 1234);
      expect(parseDangiAmount('12.5'), 12.5);
      expect(parseDangiAmount('۱۲٫۵'), 12.5);
      expect(parseDangiAmount('0'), 0);
    });

    test('rejects unreadable and non-finite text', () {
      for (final value in [
        null,
        '',
        '   ',
        'abc',
        '12abc',
        '1e400',
        '-1e400',
        '1/2',
        '12,34,56',
      ]) {
        expect(parseDangiAmount(value), isNull, reason: 'accepted "$value"');
      }
    });

    test('keeps a negative amount readable so callers can reject it', () {
      expect(parseDangiAmount('-500'), -500);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/tools/dongi/domain/dangi_member_summary.dart';
import 'package:tawheeed/features/tools/dongi/domain/entities/dangi_models.dart';

DangiMemberModel _member(String id, String name) => DangiMemberModel(
    id: id, groupId: 'g1', name: name, createdAt: DateTime(2025));

DangiExpenseModel _expense({
  required String id,
  required String payerId,
  required double amount,
  Map<String, double> consumers = const {},
}) =>
    DangiExpenseModel(
      id: id,
      groupId: 'g1',
      payerId: payerId,
      title: 'هزینه $id',
      category: 'food',
      amount: amount,
      date: DateTime(2025, 1, 2),
      createdAt: DateTime(2025, 1, 2),
      consumers: consumers,
    );

void main() {
  final ali = _member('m1', 'علی');
  final reza = _member('m2', 'رضا');

  test('empty input yields an empty summary', () {
    expect(
      buildDangiMemberSummaries(members: const [], expenses: const []),
      isEmpty,
    );
    expect(
      buildDangiMemberSummaries(members: [ali], expenses: const []),
      isEmpty,
    );
  });

  test('equal-split expenses give everyone their fair share', () {
    final s = buildDangiMemberSummaries(
      members: [ali, reza],
      expenses: [
        _expense(id: 'e1', payerId: 'm1', amount: 300),
        _expense(id: 'e2', payerId: 'm2', amount: 100),
      ],
    );
    final a = s.firstWhere((x) => x.member.id == 'm1');
    final r = s.firstWhere((x) => x.member.id == 'm2');
    // ali paid 300, consumed 150+50=200 → net +100
    expect(a.paid, 300);
    expect(a.consumed, 200);
    expect(a.net, closeTo(100, 0.01));
    // reza paid 100, consumed 150+50=200 → net −100
    expect(r.paid, 100);
    expect(r.consumed, 200);
    expect(r.net, closeTo(-100, 0.01));
  });

  test('consumer expenses count exact per-member amounts', () {
    final s = buildDangiMemberSummaries(
      members: [ali, reza],
      expenses: [
        _expense(
          id: 'e1',
          payerId: 'm1',
          amount: 500,
          consumers: {'m1': 200, 'm2': 300},
        ),
      ],
    );
    final a = s.firstWhere((x) => x.member.id == 'm1');
    final r = s.firstWhere((x) => x.member.id == 'm2');
    expect(a.paid, 500);
    expect(a.consumed, 200);
    expect(a.net, closeTo(300, 0.01));
    expect(r.consumed, 300);
    expect(r.net, closeTo(-300, 0.01));
  });

  test('net balances sum to zero across the group', () {
    final s = buildDangiMemberSummaries(
      members: [ali, reza],
      expenses: [
        _expense(
          id: 'e1',
          payerId: 'm1',
          amount: 300,
          consumers: {'m1': 120, 'm2': 180},
        ),
      ],
    );
    final total = s.fold(0.0, (sum, x) => sum + x.net);
    expect(total.abs(), lessThan(0.01));
  });
}

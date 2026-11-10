import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/tools/dongi/domain/dangi_settlement.dart';
import 'package:tawheeed/features/tools/dongi/domain/dangi_settlement_text.dart';
import 'package:tawheeed/features/tools/dongi/domain/entities/dangi_models.dart';

final _members = [
  DangiMemberModel(id: 'a', groupId: 'g1', name: 'علی', createdAt: _t),
  DangiMemberModel(id: 'b', groupId: 'g1', name: 'رضا', createdAt: _t),
];

final _t = DateTime(2025);

void main() {
  group('buildSettlementShareText', () {
    test('includes group name, total and each transfer line', () {
      final text = buildSettlementShareText(
        groupName: 'سفر مشهد',
        members: _members,
        transfers: const [
          SettlementTransfer(fromId: 'a', toId: 'b', amount: 150000),
        ],
        total: 450000,
      );

      expect(text, contains('سفر مشهد'));
      expect(text, contains('450,000'));
      expect(text, contains('علی باید به رضا بپردازد: 150,000'));
      expect(text, contains('توحید'));
    });

    test('resolves unknown member ids to the raw id', () {
      final text = buildSettlementShareText(
        groupName: 'گ',
        members: [
          DangiMemberModel(id: 'a', groupId: 'g', name: 'علی', createdAt: _t),
        ],
        transfers: const [
          SettlementTransfer(fromId: 'x', toId: 'a', amount: 10),
        ],
        total: 20,
      );
      expect(text, contains('x باید به علی بپردازد: 10'));
    });

    test('empty transfers produce the "all settled" message', () {
      final text = buildSettlementShareText(
        groupName: 'س',
        members: _members,
        transfers: const [],
        total: 0,
      );
      expect(text, contains('تسویه است'));
      expect(text, isNot(contains('باید به')));
    });

    test('multiple transfers are each listed on their own line', () {
      final text = buildSettlementShareText(
        groupName: 'س',
        members: _members,
        transfers: const [
          SettlementTransfer(fromId: 'a', toId: 'b', amount: 100),
          SettlementTransfer(fromId: 'b', toId: 'a', amount: 40),
        ],
        total: 500,
      );
      expect(text, contains('علی باید به رضا بپردازد: 100'));
      expect(text.split('\n').where((l) => l.startsWith('• ')), hasLength(2));
    });
  });
}

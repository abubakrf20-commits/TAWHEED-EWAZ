import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/tools/dongi/data/daos/dangi_dao.dart';
import 'package:tawheeed/features/tools/dongi/domain/dangi_settlement.dart';
import 'package:tawheeed/features/tools/dongi/presentation/providers/dangi_provider.dart';

void main() {
  late AppDatabase db;
  late DangiDao dao;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.withConnection(NativeDatabase.memory());
    dao = DangiDao(db);
    container = ProviderContainer(overrides: [
      dangiDaoProvider.overrideWithValue(dao),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('settleGroup records the transfers, zeroes the balances and undoes',
      () async {
    final notifier = container.read(dangiProvider.notifier);
    await notifier.addGroup(
      name: 'سفر',
      colorHex: '#00ACC1',
      memberNames: ['علی', 'حسین'],
    );
    final group = container.read(dangiProvider).groups.first;
    final members = container.read(dangiProvider).membersOf(group.id);
    final ali = members.firstWhere((m) => m.name == 'علی');
    await notifier.addExpense(
      groupId: group.id,
      payerId: ali.id,
      title: 'شام',
      category: 'food',
      amount: 300,
    );
    expect(container.read(dangiProvider).totalOf(group.id), 300);

    final ids = await notifier.settleGroup(group.id);

    final settled = container.read(dangiProvider);
    expect(ids, hasLength(1));
    expect(settled.settlementsOf(group.id), hasLength(1));
    // The settlement is stored like an expense (so it survives backup) but
    // the «مجموع هزینه‌ها» must not count it twice.
    expect(settled.expensesOf(group.id), hasLength(2));
    expect(settled.totalOf(group.id), 300);

    final all = settled.expensesOf(group.id);
    final balances = DangiSettlement.balances(
      memberIds: [for (final m in settled.membersOf(group.id)) m.id],
      expenses: [for (final e in all) (payerId: e.payerId, amount: e.amount)],
      consumerSharesByIndex: {
        for (var i = 0; i < all.length; i++)
          if (all[i].consumers.isNotEmpty) i: all[i].consumers,
      },
    );
    for (final value in balances.values) {
      expect(value, closeTo(0, 0.01));
    }

    // «لغو» deletes the whole recorded batch again.
    await notifier.undoSettlement(ids);
    final undone = container.read(dangiProvider);
    expect(undone.settlementsOf(group.id), isEmpty);
    expect(undone.expensesOf(group.id), hasLength(1));
    expect(undone.totalOf(group.id), 300);
  });

  test('settleGroup on an already settled group records nothing', () async {
    final notifier = container.read(dangiProvider.notifier);
    await notifier.addGroup(
      name: 'تنها',
      colorHex: '#00ACC1',
      memberNames: ['علی'],
    );
    final group = container.read(dangiProvider).groups.first;
    final ali = container.read(dangiProvider).membersOf(group.id).first;
    await notifier.addExpense(
      groupId: group.id,
      payerId: ali.id,
      title: 'شام',
      category: 'food',
      amount: 300,
    );

    // One member pays for themselves → nothing to transfer.
    expect(await notifier.settleGroup(group.id), isEmpty);
    expect(container.read(dangiProvider).settlementsOf(group.id), isEmpty);
  });
}

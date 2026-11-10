import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/tools/dongi/data/daos/dangi_dao.dart';
import 'package:tawheeed/features/tools/dongi/domain/entities/dangi_models.dart';
import 'package:tawheeed/features/tools/dongi/domain/dangi_settlement.dart';

void main() {
  late AppDatabase db;
  late DangiDao dao;

  setUp(() {
    db = AppDatabase.withConnection(NativeDatabase.memory());
    dao = DangiDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('group CRUD', () async {
    await dao.upsertGroup(DangiGroupModel(
      id: 'g1',
      name: 'سفر مشهد',
      colorHex: '#00ACC1',
      createdAt: DateTime(2025),
    ));
    final groups = await dao.getAllGroups();
    expect(groups.length, 1);
    expect(groups.first.name, 'سفر مشهد');

    final got = await dao.getGroup('g1');
    expect(got, isNotNull);
    expect(got!.colorHex, '#00ACC1');

    await dao.deleteGroup('g1');
    expect(await dao.getAllGroups(), isEmpty);
  });

  test('deleteGroup cascades members and expenses', () async {
    await dao.upsertGroup(DangiGroupModel(
      id: 'g1',
      name: 'سفر',
      colorHex: '#00ACC1',
      createdAt: DateTime(2025),
    ));
    await dao.upsertMember(DangiMemberModel(
      id: 'm1',
      groupId: 'g1',
      name: 'علی',
      createdAt: DateTime(2025),
    ));
    await dao.upsertExpense(DangiExpenseModel(
      id: 'e1',
      groupId: 'g1',
      payerId: 'm1',
      title: 'شام',
      category: 'food',
      amount: 300,
      date: DateTime(2025, 1, 2),
      createdAt: DateTime(2025, 1, 2),
    ));

    await dao.deleteGroup('g1');
    expect(await dao.getMembers('g1'), isEmpty);
    expect(await dao.getExpenses('g1'), isEmpty);
  });

  test('members and expenses are scoped per group', () async {
    for (final gid in ['g1', 'g2']) {
      await dao.upsertGroup(DangiGroupModel(
        id: gid,
        name: 'گروه $gid',
        colorHex: '#00ACC1',
        createdAt: DateTime(2025),
      ));
      await dao.upsertMember(DangiMemberModel(
        id: 'm_$gid',
        groupId: gid,
        name: 'عضو $gid',
        createdAt: DateTime(2025),
      ));
      await dao.upsertExpense(DangiExpenseModel(
        id: 'e_$gid',
        groupId: gid,
        payerId: 'm_$gid',
        title: 'هزینه $gid',
        category: 'food',
        amount: 100,
        date: DateTime(2025, 1, 2),
        createdAt: DateTime(2025, 1, 2),
      ));
    }
    expect((await dao.getMembers('g1')).length, 1);
    expect((await dao.getMembers('g2')).length, 1);
    expect((await dao.getExpenses('g1')).first.title, 'هزینه g1');
    expect((await dao.getExpenses('g2')).first.title, 'هزینه g2');
  });

  test('deleteMember removes member and their expenses', () async {
    await dao.upsertGroup(DangiGroupModel(
      id: 'g1',
      name: 'سفر',
      colorHex: '#00ACC1',
      createdAt: DateTime(2025),
    ));
    await dao.upsertMember(DangiMemberModel(
      id: 'm1',
      groupId: 'g1',
      name: 'علی',
      createdAt: DateTime(2025),
    ));
    await dao.upsertExpense(DangiExpenseModel(
      id: 'e1',
      groupId: 'g1',
      payerId: 'm1',
      title: 'شام',
      category: 'food',
      amount: 300,
      date: DateTime(2025, 1, 2),
      createdAt: DateTime(2025, 1, 2),
    ));
    await dao.deleteMember('m1', 'g1');
    expect(await dao.getMembers('g1'), isEmpty);
    expect(await dao.getExpenses('g1'), isEmpty);
  });

  test('expenses ordered newest first', () async {
    await dao.upsertGroup(DangiGroupModel(
      id: 'g1',
      name: 'سفر',
      colorHex: '#00ACC1',
      createdAt: DateTime(2025),
    ));
    await dao.upsertMember(DangiMemberModel(
      id: 'm1',
      groupId: 'g1',
      name: 'علی',
      createdAt: DateTime(2025),
    ));
    for (var i = 0; i < 3; i++) {
      await dao.upsertExpense(DangiExpenseModel(
        id: 'e$i',
        groupId: 'g1',
        payerId: 'm1',
        title: 'هزینه $i',
        category: 'food',
        amount: 10.0 * (i + 1),
        date: DateTime(2025, 1, 10 - i),
        createdAt: DateTime(2025, 1, 10 - i),
      ));
    }
    final expenses = await dao.getExpenses('g1');
    expect(expenses.length, 3);
    expect(expenses.first.title, 'هزینه 0'); // newest date first
  });

  test('upsert with same id updates title, category, amount and date',
      () async {
    await dao.upsertGroup(DangiGroupModel(
      id: 'g1',
      name: 'سفر',
      colorHex: '#00ACC1',
      createdAt: DateTime(2025),
    ));
    await dao.upsertMember(DangiMemberModel(
      id: 'm1',
      groupId: 'g1',
      name: 'علی',
      createdAt: DateTime(2025),
    ));
    await dao.upsertExpense(DangiExpenseModel(
      id: 'e1',
      groupId: 'g1',
      payerId: 'm1',
      title: 'شام',
      category: 'food',
      amount: 300,
      date: DateTime(2025, 1, 2),
      createdAt: DateTime(2025, 1, 2),
    ));

    await dao.upsertExpense(DangiExpenseModel(
      id: 'e1', // same id -> update
      groupId: 'g1',
      payerId: 'm1',
      title: 'بنزین',
      category: 'transport',
      amount: 150,
      date: DateTime(2025, 1, 5),
      createdAt: DateTime(2025, 1, 2),
    ));

    final expenses = await dao.getExpenses('g1');
    expect(expenses, hasLength(1)); // updated, not duplicated
    expect(expenses.first.title, 'بنزین');
    expect(expenses.first.category, 'transport');
    expect(expenses.first.amount, 150);
    expect(expenses.first.date, DateTime(2025, 1, 5));
  });

  test('per-member consumers are persisted and survive a read back', () async {
    await dao.upsertGroup(DangiGroupModel(
      id: 'g1',
      name: 'سفر',
      colorHex: '#00ACC1',
      createdAt: DateTime(2025),
    ));
    await dao.upsertMember(DangiMemberModel(
      id: 'm1',
      groupId: 'g1',
      name: 'علی',
      createdAt: DateTime(2025),
    ));

    // A consumer-mode expense must come back with its exact shares.
    await dao.upsertExpense(DangiExpenseModel(
      id: 'e1',
      groupId: 'g1',
      payerId: 'm1',
      title: 'ساندویچ',
      category: 'food',
      amount: 500,
      date: DateTime(2025, 1, 2),
      createdAt: DateTime(2025, 1, 2),
      consumers: {'m1': 200, 'm2': 300},
    ));

    var e = (await dao.getExpenses('g1')).first;
    expect(e.consumers, {'m1': 200, 'm2': 300});

    // Clearing the consumers restores the equal-split behaviour.
    await dao.upsertExpense(e.copyWith(consumers: {}));
    e = (await dao.getExpenses('g1')).first;
    expect(e.consumers, isEmpty);
  });

  test('removeConsumerFromExpenses strips a deleted member share', () async {
    await dao.upsertGroup(DangiGroupModel(
      id: 'g1',
      name: 'سفر',
      colorHex: '#00ACC1',
      createdAt: DateTime(2025),
    ));
    for (final mid in ['m1', 'm2']) {
      await dao.upsertMember(DangiMemberModel(
        id: mid,
        groupId: 'g1',
        name: 'عضو $mid',
        createdAt: DateTime(2025),
      ));
    }
    await dao.upsertExpense(DangiExpenseModel(
      id: 'e1',
      groupId: 'g1',
      payerId: 'm1',
      title: 'شام',
      category: 'food',
      amount: 300,
      date: DateTime(2025, 1, 2),
      createdAt: DateTime(2025, 1, 2),
      consumers: {'m1': 100, 'm2': 200},
    ));
    await dao.upsertExpense(DangiExpenseModel(
      id: 'e2',
      groupId: 'g1',
      payerId: 'm1',
      title: 'پیتزا',
      category: 'food',
      amount: 50,
      date: DateTime(2025, 1, 3),
      createdAt: DateTime(2025, 1, 3),
      consumers: {'m1': 50},
    ));

    await dao.removeConsumerFromExpenses(['e1', 'e2'], 'm1');

    final e1 = (await dao.getExpenses('g1')).firstWhere((e) => e.id == 'e1');
    expect(e1.consumers, {'m2': 200});
    final e2 = (await dao.getExpenses('g1')).firstWhere((e) => e.id == 'e2');
    expect(e2.consumers, isEmpty);
  });

  group('member scoping', () {
    setUp(() async {
      for (final gid in ['g1', 'g2']) {
        await dao.upsertGroup(DangiGroupModel(
          id: gid,
          name: 'گروه $gid',
          colorHex: '#00ACC1',
          createdAt: DateTime(2025),
        ));
        await dao.upsertMember(DangiMemberModel(
          id: 'm_$gid',
          groupId: gid,
          name: 'عضو $gid',
          createdAt: DateTime(2025),
        ));
      }
      await dao.upsertExpense(DangiExpenseModel(
        id: 'e_g1',
        groupId: 'g1',
        payerId: 'm_g1',
        title: 'هزینه',
        category: 'food',
        amount: 100,
        date: DateTime(2025, 1, 2),
        createdAt: DateTime(2025, 1, 2),
      ));
    });

    test('deleteMember ignores a member of a different group', () async {
      // m_g1 belongs to g1; asking to remove it "from g2" must be a no-op —
      // the old implementation ignored the group and deleted the member plus
      // every expense they paid, in any group.
      final removed = await dao.deleteMember('m_g1', 'g2');
      expect(removed, isFalse);
      expect((await dao.getMembers('g1')).length, 1);
      expect((await dao.getExpenses('g1')).length, 1);
    });

    test('deleteMember reports whether the member existed', () async {
      expect(await dao.deleteMember('nope', 'g1'), isFalse);
      expect(await dao.deleteMember('m_g1', 'g1'), isTrue);
    });

    test('deleteMember only removes expenses of its own group', () async {
      await dao.upsertExpense(DangiExpenseModel(
        id: 'e_g2',
        groupId: 'g2',
        payerId: 'm_g2',
        title: 'هزینه ۲',
        category: 'food',
        amount: 50,
        date: DateTime(2025, 1, 2),
        createdAt: DateTime(2025, 1, 2),
      ));

      await dao.deleteMember('m_g1', 'g1');

      expect(await dao.getExpenses('g1'), isEmpty);
      expect((await dao.getExpenses('g2')).length, 1);
    });
  });

  group('stale member rejection', () {
    setUp(() async {
      await dao.upsertGroup(DangiGroupModel(
        id: 'g1',
        name: 'سفر',
        colorHex: '#00ACC1',
        createdAt: DateTime(2025),
      ));
      await dao.upsertMember(DangiMemberModel(
        id: 'm1',
        groupId: 'g1',
        name: 'علی',
        createdAt: DateTime(2025),
      ));
    });

    test('an expense for a non-member is rejected', () async {
      // A stale screen must not be able to record spendings nobody can be
      // charged for.
      expect(
        () => dao.upsertExpense(DangiExpenseModel(
          id: 'e_bad',
          groupId: 'g1',
          payerId: 'ghost',
          title: 'شام',
          category: 'food',
          amount: 300,
          date: DateTime(2025, 1, 2),
          createdAt: DateTime(2025, 1, 2),
        )),
        throwsA(isA<DangiStaleMemberException>()),
      );
      expect(await dao.getExpenses('g1'), isEmpty);
    });

    test('a batch containing a stale payer writes nothing at all', () async {
      await expectLater(
        dao.insertExpenses([
          DangiExpenseModel(
            id: 'ok',
            groupId: 'g1',
            payerId: 'm1',
            title: 'شام',
            category: 'food',
            amount: 100,
            date: DateTime(2025, 1, 2),
            createdAt: DateTime(2025, 1, 2),
          ),
          DangiExpenseModel(
            id: 'bad',
            groupId: 'g1',
            payerId: 'ghost',
            title: 'پیتزا',
            category: 'food',
            amount: 50,
            date: DateTime(2025, 1, 3),
            createdAt: DateTime(2025, 1, 3),
          ),
        ]),
        throwsA(isA<DangiStaleMemberException>()),
      );
      // Atomic: the valid row must not survive either.
      expect(await dao.getExpenses('g1'), isEmpty);
    });

    test('a group with no members accepts writes (nothing to validate)',
        () async {
      await dao.upsertGroup(DangiGroupModel(
        id: 'g_empty',
        name: 'گروه خالی',
        colorHex: '#00ACC1',
        createdAt: DateTime(2025),
      ));
      await dao.insertExpenses([
        DangiExpenseModel(
          id: 'e1',
          groupId: 'g_empty',
          payerId: 'anyone',
          title: 'شام',
          category: 'food',
          amount: 100,
          date: DateTime(2025, 1, 2),
          createdAt: DateTime(2025, 1, 2),
        ),
      ]);
      expect((await dao.getExpenses('g_empty')).length, 1);
    });
  });

  group('atomic multi-row writes', () {
    test('createGroupWithMembers writes the group and every member', () async {
      await dao.createGroupWithMembers(
        DangiGroupModel(
          id: 'g1',
          name: 'سفر',
          colorHex: '#00ACC1',
          createdAt: DateTime(2025),
        ),
        [
          for (var i = 0; i < 3; i++)
            DangiMemberModel(
              id: 'm$i',
              groupId: 'g1',
              name: 'عضو $i',
              createdAt: DateTime(2025),
            ),
        ],
      );
      expect((await dao.getMembers('g1')).length, 3);
    });

    test('deleteExpenses removes a whole batch', () async {
      await dao.upsertGroup(DangiGroupModel(
        id: 'g1',
        name: 'سفر',
        colorHex: '#00ACC1',
        createdAt: DateTime(2025),
      ));
      await dao.upsertMember(DangiMemberModel(
        id: 'm1',
        groupId: 'g1',
        name: 'علی',
        createdAt: DateTime(2025),
      ));
      await dao.insertExpenses([
        for (var i = 0; i < 3; i++)
          DangiExpenseModel(
            id: 'e$i',
            groupId: 'g1',
            payerId: 'm1',
            title: 'تسویه $i',
            category: dangiSettlementCategory,
            amount: 10.0 * (i + 1),
            date: DateTime(2025, 1, 2),
            createdAt: DateTime(2025, 1, 2),
            consumers: {'m1': 10.0 * (i + 1)},
          ),
      ]);
      expect((await dao.getExpenses('g1')).length, 3);

      await dao.deleteExpenses(['e0', 'e2']);
      expect((await dao.getExpenses('g1')).map((e) => e.id), ['e1']);
    });
  });
}

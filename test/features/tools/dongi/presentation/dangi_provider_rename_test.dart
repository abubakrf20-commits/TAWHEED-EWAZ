import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/tools/dongi/data/daos/dangi_dao.dart';
import 'package:tawheeed/features/tools/dongi/domain/entities/dangi_models.dart';
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

  Future<void> seed() async {
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
      amount: 30000,
    );
  }

  test('renaming a member via updateGroup keeps their expenses', () async {
    await seed();
    final state = container.read(dangiProvider);
    final group = state.groups.first;
    final members = state.membersOf(group.id);
    final ali = members.firstWhere((m) => m.name == 'علی');
    final hossein = members.firstWhere((m) => m.name == 'حسین');
    final expenseBefore = state.expensesOf(group.id).first;

    // «علی» → «امیر» در همان ویرایش گروه
    await container.read(dangiProvider.notifier).updateGroup(group, [
      (id: ali.id, name: 'امیر'),
      (id: hossein.id, name: 'حسین'),
    ]);

    final after = container.read(dangiProvider);
    final renamed = after.membersOf(group.id);
    expect(renamed.map((m) => m.name), contains('امیر'));
    expect(renamed.length, 2);

    // هزینه حفظ شده و payerId همان id قبلی است
    final expenses = after.expensesOf(group.id);
    expect(expenses.length, 1);
    expect(expenses.first.title, 'شام');
    expect(expenses.first.amount, 30000);
    expect(expenses.first.payerId, expenseBefore.payerId);
  });

  test('removing a member removes their expenses (by design)', () async {
    await seed();
    final state = container.read(dangiProvider);
    final group = state.groups.first;
    final members = state.membersOf(group.id);
    final hossein = members.firstWhere((m) => m.name == 'حسین');

    await container.read(dangiProvider.notifier).updateGroup(group, [
      (id: hossein.id, name: 'حسین'),
    ]);

    final after = container.read(dangiProvider);
    expect(after.membersOf(group.id).length, 1);
    expect(after.membersOf(group.id).first.name, 'حسین');
    expect(after.expensesOf(group.id), isEmpty);
  });

  test('renameMember keeps expenses and updates the name', () async {
    await seed();
    final state = container.read(dangiProvider);
    final group = state.groups.first;
    final ali = state.membersOf(group.id).firstWhere((m) => m.name == 'علی');

    await container
        .read(dangiProvider.notifier)
        .renameMember(ali.id, group.id, 'مهدی');

    final after = container.read(dangiProvider);
    final member = after.membersOf(group.id).firstWhere((m) => m.id == ali.id);
    expect(member.name, 'مهدی');
    expect(after.expensesOf(group.id).length, 1);
    expect(after.expensesOf(group.id).first.payerId, ali.id);
  });

  test('per-member consumers are saved and survive a full reload', () async {
    await seed();
    final state = container.read(dangiProvider);
    final group = state.groups.first;
    final members = state.membersOf(group.id);
    final ali = members.firstWhere((m) => m.name == 'علی');
    final hossein = members.firstWhere((m) => m.name == 'حسین');

    final notifier = container.read(dangiProvider.notifier);
    await notifier.addExpense(
      groupId: group.id,
      payerId: ali.id,
      title: 'ساندویچ',
      category: 'food',
      amount: 500,
      consumers: {ali.id: 200, hossein.id: 300},
    );

    DangiExpenseModel expenseOf(String title) =>
        container.read(dangiProvider).expensesOf(group.id).firstWhere(
              (e) => e.title == title,
            );

    // Persisted immediately after the add.
    expect(expenseOf('ساندویچ').consumers, {ali.id: 200, hossein.id: 300});

    // A full reload from the database must bring the shares back — consumers
    // live in the expense rows now, not in a side-store.
    await notifier.reload();
    expect(expenseOf('ساندویچ').consumers, {ali.id: 200, hossein.id: 300});
  });

  test('deleting a member strips their share from other expenses', () async {
    await seed();
    final state = container.read(dangiProvider);
    final group = state.groups.first;
    final members = state.membersOf(group.id);
    final ali = members.firstWhere((m) => m.name == 'علی');
    final hossein = members.firstWhere((m) => m.name == 'حسین');

    final notifier = container.read(dangiProvider.notifier);
    await notifier.addExpense(
      groupId: group.id,
      payerId: ali.id,
      title: 'پیتزا',
      category: 'food',
      amount: 300,
      consumers: {ali.id: 150, hossein.id: 150},
    );

    await notifier.deleteMember(hossein.id, group.id);

    final after = container.read(dangiProvider);
    expect(after.membersOf(group.id).any((m) => m.id == hossein.id), isFalse);
    final expenses = after.expensesOf(group.id);
    // «شام» (paid by علی) survived; hossein's share of «پیتزا» is gone.
    expect(expenses.any((e) => e.title == 'شام'), isTrue);
    final pizza = expenses.firstWhere((e) => e.title == 'پیتزا');
    expect(pizza.consumers, {ali.id: 150});
  });
}

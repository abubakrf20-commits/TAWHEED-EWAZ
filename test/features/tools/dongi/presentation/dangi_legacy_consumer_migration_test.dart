import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/tools/dongi/data/daos/dangi_dao.dart';
import 'package:tawheeed/features/tools/dongi/domain/entities/dangi_models.dart';
import 'package:tawheeed/features/tools/dongi/presentation/providers/dangi_provider.dart';

void main() {
  const legacyKey = 'dangi_consumers_v1';

  late AppDatabase db;
  late DangiDao dao;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.withConnection(NativeDatabase.memory());
    dao = DangiDao(db);
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// Builds the container and waits for the initial (migrating) load to finish.
  Future<void> load() async {
    container =
        ProviderContainer(overrides: [dangiDaoProvider.overrideWithValue(dao)]);
    await container.read(dangiProvider.notifier).reload();
  }

  /// Inserts a group with two members and one expense with no consumers,
  /// bypassing the provider so no migration runs yet.
  Future<({String groupId, String m1, String m2, String expenseId})>
      seed() async {
    const groupId = 'g1';
    await dao.upsertGroup(DangiGroupModel(
      id: groupId,
      name: 'g',
      colorHex: '#00ACC1',
      createdAt: DateTime(2025),
    ));
    await dao.upsertMember(DangiMemberModel(
        id: 'm1', groupId: groupId, name: 'a', createdAt: DateTime(2025)));
    await dao.upsertMember(DangiMemberModel(
        id: 'm2', groupId: groupId, name: 'b', createdAt: DateTime(2025)));
    await dao.upsertExpense(DangiExpenseModel(
      id: 'e1',
      groupId: groupId,
      payerId: 'm1',
      title: 'lunch',
      category: 'food',
      amount: 300,
      date: DateTime(2025, 1, 2),
      createdAt: DateTime(2025, 1, 2),
    ));
    return (groupId: groupId, m1: 'm1', m2: 'm2', expenseId: 'e1');
  }

  void setLegacy(Map<String, Object?> map) {
    SharedPreferences.setMockInitialValues({legacyKey: jsonEncode(map)});
  }

  test('migrates recognised shares into the expense row', () async {
    final ids = await seed();
    setLegacy({
      ids.expenseId: {ids.m1: 100.0, ids.m2: 200.0},
    });

    await load();
    final state = container.read(dangiProvider);
    expect(state.loaded, isTrue);

    final expense = state.expensesOf(ids.groupId).first;
    expect(expense.consumers, {ids.m1: 100.0, ids.m2: 200.0});
    // The database is now the source of truth, so the legacy key is dropped.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(legacyKey), isNull);
  });

  test('drops the key even when nothing could be migrated', () async {
    final ids = await seed();
    // Every entry names a member that no longer exists in this group.
    setLegacy({
      ids.expenseId: {'gone': 100.0},
    });

    await load();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(legacyKey), isNull);
    final expense = (await dao.getExpenses(ids.groupId))
        .firstWhere((e) => e.id == ids.expenseId);
    expect(expense.consumers, isEmpty);
  });

  test('ignores negative, zero and non-finite legacy amounts', () async {
    final ids = await seed();
    setLegacy({
      ids.expenseId: {ids.m1: -100.0, ids.m2: 0},
    });

    await load();

    final expense = (await dao.getExpenses(ids.groupId))
        .firstWhere((e) => e.id == ids.expenseId);
    // Nothing usable was left, so the row keeps its empty (equal-split) map
    // rather than gaining a negative share.
    expect(expense.consumers, isEmpty);
  });

  test('never records a share larger than the expense', () async {
    final ids = await seed();
    setLegacy({
      ids.expenseId: {ids.m1: 100.0, ids.m2: 9999.0},
    });

    await load();

    final expense = (await dao.getExpenses(ids.groupId))
        .firstWhere((e) => e.id == ids.expenseId);
    expect(expense.consumers, {ids.m1: 100.0});
  });

  test('does not touch an expense that already has consumers', () async {
    final ids = await seed();
    await dao.upsertExpense((await dao.getExpenses(ids.groupId))
        .first
        .copyWith(consumers: {ids.m1: 50.0, ids.m2: 250.0}));
    setLegacy({
      ids.expenseId: {ids.m1: 10.0},
    });

    await load();

    final expense = (await dao.getExpenses(ids.groupId))
        .firstWhere((e) => e.id == ids.expenseId);
    expect(expense.consumers, {ids.m1: 50.0, ids.m2: 250.0});
  });

  test('malformed legacy JSON leaves the data untouched', () async {
    final ids = await seed();
    SharedPreferences.setMockInitialValues({legacyKey: 'not json'});

    await load();

    final expense = (await dao.getExpenses(ids.groupId))
        .firstWhere((e) => e.id == ids.expenseId);
    expect(expense.consumers, isEmpty);
  });

  test('a non-numeric legacy value is skipped but valid ones survive',
      () async {
    final ids = await seed();
    setLegacy({
      ids.expenseId: {ids.m1: 'oops', ids.m2: 300.0},
    });

    await load();

    final expense = (await dao.getExpenses(ids.groupId))
        .firstWhere((e) => e.id == ids.expenseId);
    expect(expense.consumers, {ids.m2: 300.0});
  });
}

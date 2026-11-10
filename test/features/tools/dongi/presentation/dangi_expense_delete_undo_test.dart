import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/tools/dongi/data/daos/dangi_dao.dart';
import 'package:tawheeed/features/tools/dongi/presentation/providers/dangi_provider.dart';
import 'package:tawheeed/features/tools/dongi/presentation/screens/dangi_group_screen.dart';

/// Real-async Drift operations need a flush under the widget test's
/// fake-async clock (same pattern as the tasks undo test).
const ioFlush = Duration(milliseconds: 80);

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

  test('addExpense stores the picked date instead of "now"', () async {
    final notifier = container.read(dangiProvider.notifier);
    await notifier.addGroup(
      name: 'سفر',
      colorHex: '#00ACC1',
      memberNames: ['علی'],
    );
    final group = container.read(dangiProvider).groups.first;
    final ali = container.read(dangiProvider).membersOf(group.id).first;

    await notifier.addExpense(
      groupId: group.id,
      payerId: ali.id,
      title: 'ناهار دیروز',
      category: 'food',
      amount: 120,
      date: DateTime(2025, 5, 4),
    );

    final e = container.read(dangiProvider).expensesOf(group.id).single;
    expect(e.date, DateTime(2025, 5, 4));
  });

  testWidgets('deleting an expense offers undo that restores it',
      (tester) async {
    var groupId = '';
    await tester.runAsync(() async {
      final notifier = container.read(dangiProvider.notifier);
      await notifier.addGroup(
        name: 'سفر',
        colorHex: '#00ACC1',
        memberNames: ['علی', 'رضا'],
      );
      final group = container.read(dangiProvider).groups.first;
      groupId = group.id;
      final ali = container.read(dangiProvider).membersOf(groupId).first;
      await notifier.addExpense(
        groupId: groupId,
        payerId: ali.id,
        title: 'شام',
        category: 'food',
        amount: 300,
      );
    });

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: DangiGroupScreen(groupId: groupId)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('شام'), findsOneWidget);

    // Tile → delete icon → confirm in the dialog.
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'حذف'));
    await tester.pumpAndSettle();
    // The delete hits the (real-async) Drift DB — flush it so the undo
    // action has something to restore.
    await tester.runAsync(() => Future<void>.delayed(ioFlush));
    await tester.pumpAndSettle();

    expect(find.text('شام'), findsNothing);
    expect(find.text('«شام» حذف شد'), findsOneWidget);

    // Undo brings the expense back (UI + database).
    await tester.tap(find.text('بازگردانی'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(ioFlush));
    await tester.pumpAndSettle();

    expect(find.text('شام'), findsOneWidget);
    expect(container.read(dangiProvider).expensesOf(groupId), hasLength(1));
  });
}

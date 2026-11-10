import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/personal/family_faith/data/family_faith_repository.dart';
import 'package:tawheeed/features/personal/family_faith/family_faith_providers.dart';
import 'package:tawheeed/features/personal/family_faith/presentation/savings_screen.dart';
import 'package:tawheeed/features/personal/family_faith/savings/savings_models.dart';

import 'family_faith_test_kit.dart';

final _now = DateTime(2026, 9, 12, 8);

SavingsSnapshot _snapshot() => SavingsSnapshot(
      goals: [
        SavingsGoal(
          id: 'g1',
          title: 'سفر شمال',
          targetAmount: 10000000,
          targetDate: DateTime(2027, 3, 1),
          iconKey: 'travel',
          createdAt: DateTime(2026, 6, 1),
        ),
      ],
      deposits: [
        Deposit(
          id: 'd1',
          goalId: 'g1',
          date: DateTime(2026, 8, 1),
          amount: 2000000,
        ),
        Deposit(
          id: 'd2',
          goalId: 'g1',
          date: DateTime(2026, 9, 1),
          amount: 1000000,
        ),
        Deposit(
          id: 'd3',
          goalId: 'g1',
          date: DateTime(2026, 9, 5),
          amount: -500000,
          note: 'برداشت',
        ),
      ],
    );

Future<void> _pump(
  WidgetTester tester, {
  SavingsSnapshot? snapshot,
  Widget? screen,
  Size size = const Size(360, 1400),
  double scale = 1,
}) async {
  applyDayTheme();
  SharedPreferences.setMockInitialValues({});
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(familyTestApp(
    size: size,
    scale: scale,
    overrides: [
      savingsRepositoryProvider
          .overrideWithValue(FakeSavingsRepository(snapshot ?? _snapshot())),
      savingsRemindersProvider.overrideWithValue(NoopSavingsReminders()),
    ],
    child: screen ?? SavingsScreen(nowOverride: _now),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the list shows the goal, its figures and the ETA chip',
      (tester) async {
    await _pump(tester);
    expect(find.text('سفر شمال'), findsOneWidget);
    expect(find.text('2,500,000 تومان از 10,000,000 تومان'), findsOneWidget);
    expect(find.text('مجموع پس‌انداز'), findsOneWidget);
    expect(find.text('25٪'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no overflow at 320 dp with text scale 1.3', (tester) async {
    await _pump(tester, size: const Size(320, 1500), scale: 1.3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty state invites the first goal', (tester) async {
    await _pump(tester, snapshot: const SavingsSnapshot());
    expect(find.text('هنوز هدفی نساخته‌اید'), findsOneWidget);
    expect(find.text('ساختن نخستین هدف'), findsOneWidget);
  });

  testWidgets('the detail screen shows the remaining amount and history',
      (tester) async {
    await _pump(
      tester,
      screen: SavingsGoalScreen(goalId: 'g1', nowOverride: _now),
    );
    expect(find.text('باقی‌مانده: 7,500,000 تومان'), findsOneWidget);
    expect(find.text('تاریخچهٔ واریز'), findsOneWidget);
    expect(find.text('برداشت'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a missing goal degrades to a message, not a crash',
      (tester) async {
    await _pump(
      tester,
      screen: SavingsGoalScreen(goalId: 'nope', nowOverride: _now),
    );
    expect(find.textContaining('این هدف پیدا نشد'), findsOneWidget);
  });

  testWidgets('golden: savings list (day, 360)', (tester) async {
    await _pump(tester);
    await expectLater(
      find.byType(SavingsScreen),
      matchesGoldenFile('goldens/savings_list_day.png'),
    );
  });

  testWidgets('golden: savings detail (day, 360)', (tester) async {
    await _pump(
      tester,
      screen: SavingsGoalScreen(goalId: 'g1', nowOverride: _now),
    );
    await expectLater(
      find.byType(SavingsGoalScreen),
      matchesGoldenFile('goldens/savings_detail_day.png'),
    );
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/goals/data/repositories/goal_repository_impl.dart';
import 'package:tawheeed/features/goals/domain/goal_query.dart';
import 'package:tawheeed/features/goals/domain/repositories/goal_repository.dart';
import 'package:tawheeed/features/goals/presentation/screens/goals_screen.dart';

class _Repo implements GoalRepository {
  _Repo(this.goals);
  final List<GoalTableData> goals;

  @override
  Future<List<GoalTableData>> getGoals({bool includeArchived = false}) async =>
      goals.where((g) => includeArchived || !g.isArchived).toList();

  @override
  Future<GoalTableData?> getGoal(String id) async =>
      goals.where((g) => g.id == id).firstOrNull;

  @override
  Future<void> upsertGoal(GoalTableCompanion entry) async {}

  @override
  Future<void> deleteGoal(String id) async {}

  @override
  Future<void> setArchived(String id, bool archived) async {}

  @override
  Future<void> clearSourceLink(String id) async {}

  @override
  Future<int> goalTotal(String goalId) async => 0;

  @override
  Future<Map<String, int>> totalsByGoal(List<String> goalIds) async => {};

  @override
  Future<int> progressOn(String goalId, String date) async => 0;

  @override
  Future<Map<String, int>> progressByDay(String goalId,
          {String? from, String? to}) async =>
      {};

  @override
  Future<Map<String, List<String>>> positiveDaysByGoal(
          List<String> goalIds) async =>
      {};

  @override
  Future<List<GoalProgressTableData>> progressEntries(String goalId,
          {int limit = 200}) async =>
      [];

  @override
  Future<void> addProgress(GoalProgressTableCompanion entry) async {}

  @override
  Future<void> updateProgress(String id, int amount) async {}

  @override
  Future<void> deleteProgressEntry(String id) async {}
}

GoalTableData _goal(
  String id, {
  String title = 'هدف',
  String category = 'hifz',
  int priority = 0,
  bool active = true,
  bool archived = false,
}) {
  final now = DateTime.now();
  return GoalTableData(
    id: id,
    title: title,
    description: '',
    category: category,
    startDate: '',
    deadline: '',
    targetType: 'count',
    targetNumber: 30,
    dailyTarget: 0,
    priority: priority,
    remindEnabled: false,
    remindAt: '',
    linkedType: '',
    linkedId: '',
    isActive: active,
    isArchived: archived,
    createdAt: now,
    updatedAt: now,
  );
}

/// The filter chips live in their own horizontal scroller, separate from the
/// vertically scrolling goal list.
Finder _chipRow() => find.byWidgetPredicate(
      (w) => w is ListView && w.scrollDirection == Axis.horizontal,
      description: 'horizontal chip row',
    );

/// The reset button in the fixed top row.
Finder _clearFilters() => find.byTooltip('پاک کردن فیلترها');

Future<void> _pump(WidgetTester tester, List<GoalTableData> goals) async {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [goalRepositoryProvider.overrideWithValue(_Repo(goals))],
      child: const MaterialApp(home: GoalsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the filter bar stays out of the way until something is active',
      (tester) async {
    await _pump(tester, [_goal('1')]);

    // An always-on row of chips is a wall of controls on a list that usually
    // needs none of them.
    expect(find.text('اتمام‌یافته‌ها'), findsNothing);
    expect(_clearFilters(), findsNothing);
  });

  testWidgets('a search query alone does not add a redundant clear button',
      (tester) async {
    await _pump(tester, [_goal('1', title: 'حفظ')]);
    await tester.enterText(find.byType(TextField), 'حفظ');
    await tester.pumpAndSettle();

    // The suffix × already clears the text; a second "clear" beside it would
    // look like it should do something else.
    expect(_clearFilters(), findsNothing);
    expect(find.byTooltip('پاک کردن جست‌وجو'), findsOneWidget);
  });

  testWidgets('the reset button is reachable without scrolling the chip row',
      (tester) async {
    await _pump(tester, [
      _goal('1', title: 'حفظ کل'),
      _goal('2', title: 'حفظ جزء', category: 'quran'),
    ]);

    await tester.enterText(find.byType(TextField), 'حفظ');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'قرآن'));
    await tester.pumpAndSettle();

    // This used to be the last chip in a horizontal row, so it sat past the
    // right edge and only appeared after a sideways scroll.
    expect(_clearFilters(), findsOneWidget);
    expect(find.text('پاک کردن همه'), findsNothing);
    expect(
      find.descendant(of: _chipRow(), matching: _clearFilters()),
      findsNothing,
      reason: 'the reset must not live in the scrolling filter row',
    );

    await tester.tap(_clearFilters());
    await tester.pumpAndSettle();

    // Chip filter and search text both go, and the search field shows empty.
    expect(find.text('حفظ کل'), findsOneWidget);
    expect(find.text('حفظ جزء'), findsOneWidget);
    expect(_clearFilters(), findsNothing);
    expect(find.byTooltip('پاک کردن جست‌وجو'), findsNothing);
  });

  testWidgets(
      'clearing from the "no matches" empty state also clears the field',
      (tester) async {
    await _pump(tester, [
      _goal('1', title: 'حفظ کل'),
      _goal('2', title: 'حفظ جزء', category: 'quran'),
    ]);

    // A query nothing matches, so the empty state's own reset button appears.
    await tester.enterText(find.byType(TextField), 'ناموجود');
    await tester.pumpAndSettle();
    expect(find.text('چیزی با این فیلترها پیدا نشد'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'پاک کردن فیلترها'));
    await tester.pumpAndSettle();

    // The list is back. If the field still read «ناموجود», the screen would be
    // claiming a search that no longer applies, and the next character the
    // user types would be appended to the query they just dismissed.
    expect(find.text('حفظ کل'), findsOneWidget);
    expect(find.text('حفظ جزء'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, isEmpty);
    expect(find.byTooltip('پاک کردن جست‌وجو'), findsNothing);
  });

  testWidgets('typing narrows the list, and clearing it brings the goal back',
      (tester) async {
    await _pump(tester, [
      _goal('1', title: 'حفظ جزء سی'),
      _goal('2', title: 'ترجمه سوره'),
    ]);
    expect(find.text('حفظ جزء سی'), findsOneWidget);
    expect(find.text('ترجمه سوره'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ترجمه');
    await tester.pumpAndSettle();
    expect(find.text('حفظ جزء سی'), findsNothing);
    expect(find.text('ترجمه سوره'), findsOneWidget);

    // The suffix clear button appears only once there is something to clear.
    await tester.tap(find.byTooltip('پاک کردن جست‌وجو'));
    await tester.pumpAndSettle();
    expect(find.text('حفظ جزء سی'), findsOneWidget);
  });

  testWidgets('a category chip filters, and re-tapping it releases the filter',
      (tester) async {
    await _pump(tester, [
      _goal('1', title: 'حفظ کل'),
      _goal('2', title: 'حفظ جزء', category: 'quran'),
    ]);

    await tester.enterText(find.byType(TextField), 'حفظ');
    await tester.pumpAndSettle();
    expect(find.text('حفظ کل'), findsOneWidget);
    expect(find.text('حفظ جزء'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'قرآن'));
    await tester.pumpAndSettle();
    expect(find.text('حفظ کل'), findsNothing);
    expect(find.text('حفظ جزء'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'قرآن'));
    await tester.pumpAndSettle();
    expect(find.text('حفظ کل'), findsOneWidget);
    expect(find.text('حفظ جزء'), findsOneWidget);
  });

  testWidgets('"clear all" also puts the sort back to the default order',
      (tester) async {
    await _pump(tester, [
      _goal('1', title: 'حفظ کل'),
      _goal('2', title: 'حفظ جزء', category: 'quran'),
    ]);

    await tester.enterText(find.byType(TextField), 'حفظ');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'قرآن'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('ترتیب'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(GoalSort.deadline.label).last);
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget, reason: 'sort index 2 = deadline');

    await tester.tap(_clearFilters());
    await tester.pumpAndSettle();

    // Leaving the ordering changed while every other control reads "reset"
    // would be a trap: the list looks default but is quietly sorted
    // differently.
    expect(find.text('1'), findsOneWidget,
        reason: 'sort index back to 1 = manual');
  });

  testWidgets('the sort menu is numbered 1..n in the order it is declared',
      (tester) async {
    await _pump(tester, [_goal('1')]);

    // A bare icon leaves the ordering undiscoverable; the index says where you
    // are, so the menu can open on the active entry.
    final order = GoalSort.values.map((s) => s.label).toList();
    expect(order, isNotEmpty);
    await tester.tap(find.byTooltip('ترتیب'));
    await tester.pumpAndSettle();
    for (final label in order) {
      expect(find.text(label), findsOneWidget);
    }
  });
}

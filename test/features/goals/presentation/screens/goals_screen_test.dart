import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/goals/domain/repositories/goal_repository.dart';
import 'package:tawheeed/features/goals/data/repositories/goal_repository_impl.dart';
import 'package:tawheeed/features/goals/presentation/screens/goals_screen.dart';
import 'package:tawheeed/features/goals/presentation/utils/goal_dates.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// In-memory fake so widget tests never touch the platform database.
class _FakeGoalRepository implements GoalRepository {
  final List<GoalTableData> goals;
  final Map<String, List<GoalProgressTableData>> progress;

  /// Rows the UI tried to log — the point of the quick-add tests.
  final List<GoalProgressTableCompanion> added = [];

  _FakeGoalRepository({required this.goals, this.progress = const {}});

  @override
  Future<List<GoalTableData>> getGoals({bool includeArchived = false}) async =>
      goals.where((g) => includeArchived || !g.isArchived).toList();

  @override
  Future<GoalTableData?> getGoal(String id) async {
    for (final g in goals) {
      if (g.id == id) return g;
    }
    return null;
  }

  @override
  Future<void> upsertGoal(GoalTableCompanion entry) async {}

  @override
  Future<void> deleteGoal(String id) async {}

  @override
  Future<void> setArchived(String id, bool archived) async {
    final i = goals.indexWhere((g) => g.id == id);
    if (i == -1) return;
    goals[i] = goals[i].copyWith(isArchived: archived);
  }

  @override
  Future<void> clearSourceLink(String id) async {
    final i = goals.indexWhere((g) => g.id == id);
    if (i == -1) return;
    goals[i] = goals[i].copyWith(linkedType: '', linkedId: '');
  }

  @override
  Future<int> goalTotal(String goalId) async {
    final rows = progress[goalId] ?? const [];
    return rows.fold<int>(0, (sum, r) => sum + r.amount);
  }

  @override
  Future<Map<String, int>> totalsByGoal(List<String> goalIds) async => {
        for (final id in goalIds) id: await goalTotal(id),
      };

  @override
  Future<int> progressOn(String goalId, String date) async {
    final rows = progress[goalId] ?? const [];
    return rows
        .where((r) => r.date == date)
        .fold<int>(0, (sum, r) => sum + r.amount);
  }

  @override
  Future<Map<String, int>> progressByDay(String goalId,
      {String? from, String? to}) async {
    final out = <String, int>{};
    for (final r in progress[goalId] ?? const <GoalProgressTableData>[]) {
      if (from != null && r.date.compareTo(from) < 0) continue;
      if (to != null && r.date.compareTo(to) > 0) continue;
      out[r.date] = (out[r.date] ?? 0) + r.amount;
    }
    return {for (final key in out.keys.toList()..sort()) key: out[key]!};
  }

  @override
  Future<void> addProgress(GoalProgressTableCompanion entry) async {
    added.add(entry);
  }

  @override
  Future<void> updateProgress(String id, int amount) async {}

  @override
  Future<void> deleteProgressEntry(String id) async {}

  @override
  Future<Map<String, List<String>>> positiveDaysByGoal(
      List<String> goalIds) async {
    final out = <String, List<String>>{};
    for (final id in goalIds) {
      final days = <String>{
        for (final r in progress[id] ?? const <GoalProgressTableData>[])
          if (r.amount > 0) r.date,
      }.toList()
        ..sort();
      if (days.isNotEmpty) out[id] = days;
    }
    return out;
  }

  @override
  Future<List<GoalProgressTableData>> progressEntries(String goalId,
      {int limit = 200}) async {
    final rows = [...?progress[goalId]];
    rows.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
    });
    return rows.take(limit).toList();
  }
}

GoalTableData _goal(
  String id, {
  int target = 30,
  String deadline = '',
  bool archived = false,
  bool active = true,
  String targetType = 'count',
  int dailyTarget = 0,
}) {
  final now = DateTime.now();
  return GoalTableData(
    id: id,
    title: 'هدف $id',
    description: '',
    category: 'hifz',
    startDate: '',
    deadline: deadline,
    targetType: targetType,
    targetNumber: target,
    dailyTarget: dailyTarget,
    priority: 1,
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

Future<void> _pumpGoals(WidgetTester tester, GoalRepository repo) async {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [goalRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: GoalsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('goal list renders Latin digits for totals and percent',
      (tester) async {
    // 10 of 30 → 33٪ and «10 از 30».
    await _pumpGoals(
      tester,
      _FakeGoalRepository(
        goals: [_goal('1')],
        progress: {
          '1': [
            GoalProgressTableData(
              id: 'p1',
              goalId: '1',
              date: '2026-09-01',
              amount: 10,
              createdAt: DateTime.now(),
            ),
          ],
        },
      ),
    );

    expect(find.text('33٪'), findsOneWidget);
    // The formatter isolates each number so the phrase cannot mirror in RTL.
    expect(find.text(NumberFormat.fraction(10, 30)), findsOneWidget);
    expect(find.text('هدف 1'), findsOneWidget);
  });

  testWidgets('overdue deadline surfaces a warning line on the card',
      (tester) async {
    final yesterday = DateTime.now().subtract(const Duration(days: 2));
    final iso =
        '${yesterday.year.toString().padLeft(4, '0')}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
    await _pumpGoals(
      tester,
      _FakeGoalRepository(goals: [_goal('1', deadline: iso)]),
    );

    expect(find.textContaining('روز از مهلت گذشته'), findsOneWidget);
    // The overdue deadline renders as a colored pill chip with an icon.
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('active goals hide archived ones from the main list',
      (tester) async {
    await _pumpGoals(
      tester,
      _FakeGoalRepository(
        goals: [_goal('1'), _goal('2', archived: true)],
      ),
    );

    expect(find.text('هدف 1'), findsOneWidget);
    expect(find.text('هدف 2'), findsNothing);
  });

  testWidgets('quick-add on a count goal logs the daily target in one tap',
      (tester) async {
    final repo = _FakeGoalRepository(
      goals: [_goal('1', dailyTarget: 5)],
    );
    await _pumpGoals(tester, repo);

    await tester.tap(find.byKey(const ValueKey('goal_quick_1')));
    await tester.pumpAndSettle();

    expect(repo.added, hasLength(1));
    expect(repo.added.single.amount.value, 5);
    expect(repo.added.single.date.value, goalTodayIso());
    expect(repo.added.single.goalId.value, '1');
  });

  testWidgets('boolean goal gets a check toggle, not a plus', (tester) async {
    final repo = _FakeGoalRepository(
      goals: [_goal('1', target: 0, targetType: 'boolean')],
    );
    await _pumpGoals(tester, repo);

    // Nothing logged today → outline check, and tapping records 1 for today.
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('goal_quick_1')));
    await tester.pumpAndSettle();

    expect(repo.added, hasLength(1));
    expect(repo.added.single.amount.value, 1);
    expect(repo.added.single.date.value, goalTodayIso());
  });

  testWidgets('templates sheet lists every ready-made goal', (tester) async {
    await _pumpGoals(tester, _FakeGoalRepository(goals: [_goal('1')]));

    await tester.tap(find.byKey(const ValueKey('goals_templates')));
    await tester.pumpAndSettle();

    expect(find.text('قالب آماده'), findsOneWidget);
    expect(find.text('نماز اول وقت'), findsOneWidget);
    expect(find.text('حفظ 1 صفحه در روز'), findsOneWidget);
    expect(find.text('مطالعه 10 صفحه در روز'), findsOneWidget);
    expect(find.text('اذکار روزانه'), findsOneWidget);
    expect(find.text('30 دقیقه حرکت در روز'), findsOneWidget);
  });
}

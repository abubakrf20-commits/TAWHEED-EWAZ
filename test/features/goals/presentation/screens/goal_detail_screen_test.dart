import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/design_system/components/failure_view.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/goals/data/repositories/goal_repository_impl.dart';
import 'package:tawheeed/features/goals/domain/repositories/goal_repository.dart';
import 'package:tawheeed/features/goals/presentation/screens/goal_detail_screen.dart';

/// In-memory fake so widget tests never touch the platform database.
class _FakeGoalRepository implements GoalRepository {
  final GoalTableData goal;
  final List<GoalProgressTableData> progress;

  _FakeGoalRepository({required this.goal, this.progress = const []});

  /// Set to make the lifetime total query fail, which the screen must show as
  /// an error rather than silently render as 0.
  Object? totalError;

  @override
  Future<List<GoalTableData>> getGoals({bool includeArchived = false}) async =>
      [goal];

  @override
  Future<GoalTableData?> getGoal(String id) async => goal;

  @override
  Future<void> upsertGoal(GoalTableCompanion entry) async {}

  @override
  Future<void> deleteGoal(String id) async {}

  @override
  Future<void> setArchived(String id, bool archived) async {}

  @override
  Future<void> clearSourceLink(String id) async {}

  @override
  Future<int> goalTotal(String goalId) async {
    if (totalError != null) throw totalError!;
    return progress.fold<int>(0, (sum, r) => sum + r.amount);
  }

  @override
  Future<Map<String, int>> totalsByGoal(List<String> goalIds) async => {
        for (final id in goalIds) id: await goalTotal(id),
      };

  @override
  Future<int> progressOn(String goalId, String date) async => progress
      .where((r) => r.date == date)
      .fold<int>(0, (sum, r) => sum + r.amount);

  @override
  Future<Map<String, int>> progressByDay(String goalId,
      {String? from, String? to}) async {
    final out = <String, int>{};
    for (final r in progress) {
      if (from != null && r.date.compareTo(from) < 0) continue;
      if (to != null && r.date.compareTo(to) > 0) continue;
      out[r.date] = (out[r.date] ?? 0) + r.amount;
    }
    // Same ordering the SQL `ORDER BY date` guarantees.
    return {for (final key in out.keys.toList()..sort()) key: out[key]!};
  }

  @override
  Future<void> addProgress(GoalProgressTableCompanion entry) async {}

  @override
  Future<void> updateProgress(String id, int amount) async {}

  @override
  Future<void> deleteProgressEntry(String id) async {}

  @override
  Future<Map<String, List<String>>> positiveDaysByGoal(
      List<String> goalIds) async {
    final days = <String>{
      for (final r in progress)
        if (r.amount > 0) r.date,
    }.toList()
      ..sort();
    return days.isEmpty ? {} : {'g1': days};
  }

  @override
  Future<List<GoalProgressTableData>> progressEntries(String goalId,
      {int limit = 200}) async {
    final rows = [...progress];
    rows.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
    });
    return rows.take(limit).toList();
  }
}

GoalTableData _goal({required String deadline, int target = 30}) {
  final now = DateTime.now();
  return GoalTableData(
    id: 'g1',
    title: 'حفظ جزء',
    description: '',
    category: 'hifz',
    startDate: '',
    deadline: deadline,
    targetType: 'count',
    targetNumber: target,
    dailyTarget: 0,
    priority: 1,
    remindEnabled: false,
    remindAt: '',
    linkedType: '',
    linkedId: '',
    isActive: true,
    isArchived: false,
    createdAt: now,
    updatedAt: now,
  );
}

String _iso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

Future<void> _pumpDetail(
  WidgetTester tester,
  GoalRepository repo,
) async {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [goalRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: GoalDetailScreen(goalId: 'g1')),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('deadline panel shows days left and required daily pace',
      (tester) async {
    final deadline = DateTime.now().add(const Duration(days: 10));
    final repo = _FakeGoalRepository(
      goal: _goal(
        deadline: _iso(deadline),
      ),
    );

    await _pumpDetail(tester, repo);

    expect(find.text('10 روز تا پایان هدف'), findsOneWidget);
    expect(find.textContaining('در روز'), findsOneWidget);
    expect(find.text('سرعت لازم'), findsOneWidget);
  });

  testWidgets(
      'panel projects a finish date when the recent pace would complete it',
      (tester) async {
    final deadline = DateTime.now().add(const Duration(days: 20));
    final progress = <GoalProgressTableData>[];
    // Six recent days with 2/day: the 7-day average is > 0 and the goal is
    // NOT yet complete (12 of 30), so a finish-date projection must appear.
    for (var i = 1; i <= 6; i++) {
      final d = DateTime.now().subtract(Duration(days: i));
      progress.add(GoalProgressTableData(
        id: 'p$i',
        goalId: 'g1',
        date: _iso(d),
        amount: 2,
        createdAt: d,
      ));
    }
    final repo = _FakeGoalRepository(
      goal: _goal(
        deadline: _iso(deadline),
      ),
      progress: progress,
    );

    await _pumpDetail(tester, repo);

    expect(find.text('پیش‌بینی پایان'), findsOneWidget);
  });

  testWidgets('overdue deadline turns the panel red with days-past wording',
      (tester) async {
    final deadline = DateTime.now().subtract(const Duration(days: 3));
    final repo = _FakeGoalRepository(
      goal: _goal(
        deadline: _iso(deadline),
      ),
    );

    await _pumpDetail(tester, repo);

    expect(find.text('3 روز از مهلت گذشته'), findsOneWidget);
  });

  testWidgets('panel is hidden when the goal has no deadline', (tester) async {
    final repo = _FakeGoalRepository(
        goal: _goal(
      deadline: '',
    ));

    await _pumpDetail(tester, repo);

    expect(find.textContaining('روز تا پایان هدف'), findsNothing);
    expect(find.text('سرعت لازم'), findsNothing);
  });

  testWidgets('a failed total shows an error, not a made-up zero',
      (tester) async {
    // The regression this locks down: the old body read the total provider as
    // `.value ?? 0`, so a failed SUM rendered «۰ از ۳۰» with total confidence.
    // A wrong number shown as fact is worse than a visible failure.
    final repo = _FakeGoalRepository(
      goal: _goal(deadline: _iso(DateTime.now().add(const Duration(days: 5)))),
    )..totalError = Exception('db down');

    await _pumpDetail(tester, repo);

    // The shared error surface's retry button — a stable marker that the
    // error branch rendered at all. Read from the constant rather than a
    // literal: the label is app-wide now, and this test is about the branch
    // being taken, not about the wording.
    expect(find.text(FailureView.retryLabel), findsOneWidget);
    // And the fabricated total must be gone entirely.
    expect(find.textContaining('۰ از'), findsNothing);
  });

  testWidgets('a goal with no progress is not shown as an error',
      (tester) async {
    final repo = _FakeGoalRepository(
      goal: _goal(deadline: _iso(DateTime.now().add(const Duration(days: 5)))),
    );

    await _pumpDetail(tester, repo);

    // A genuine zero total is a real answer and must still render, without
    // borrowing the error surface's wording.
    expect(find.text(FailureView.retryLabel), findsNothing);
    expect(find.textContaining('از'), findsWidgets);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/goals/data/repositories/goal_repository_impl.dart';
import 'package:tawheeed/features/goals/domain/repositories/goal_repository.dart';
import 'package:tawheeed/features/goals/presentation/providers/goals_provider.dart';

class _FakeGoalRepository implements GoalRepository {
  final List<GoalTableData> goals;
  _FakeGoalRepository(this.goals);

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
  Future<void> setArchived(String id, bool archived) async {
    final i = goals.indexWhere((g) => g.id == id);
    if (i != -1) goals[i] = goals[i].copyWith(isArchived: archived);
  }

  @override
  Future<void> clearSourceLink(String id) async {
    final i = goals.indexWhere((g) => g.id == id);
    if (i == -1) return;
    goals[i] = goals[i].copyWith(linkedType: '', linkedId: '');
  }

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
  Future<void> addProgress(GoalProgressTableCompanion entry) async {}

  @override
  Future<void> updateProgress(String id, int amount) async {}

  @override
  Future<void> deleteProgressEntry(String id) async {}

  @override
  Future<Map<String, List<String>>> positiveDaysByGoal(
          List<String> goalIds) async =>
      {};

  @override
  Future<List<GoalProgressTableData>> progressEntries(String goalId,
          {int limit = 200}) async =>
      [];
}

GoalTableData _goal(String id, {bool archived = false}) => GoalTableData(
      id: id,
      title: 'هدف $id',
      description: '',
      category: 'hifz',
      startDate: '',
      deadline: '',
      targetType: 'count',
      targetNumber: 30,
      dailyTarget: 0,
      priority: 1,
      remindEnabled: false,
      remindAt: '',
      linkedType: '',
      linkedId: '',
      isActive: true,
      isArchived: archived,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

ProviderContainer _container(GoalRepository repo) {
  final container = ProviderContainer(
    overrides: [goalRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('archivedGoalsProvider returns only archived goals', () async {
    // The defect: this provider passed `includeArchived: true` straight
    // through, but that flag means "don't hide archived rows" — it does not
    // mean "only archived". The «بایگانی» sheet therefore listed the two
    // active goals alongside the archived one.
    final repo = _FakeGoalRepository([
      _goal('active1'),
      _goal('active2'),
      _goal('archived1', archived: true),
    ]);
    final container = _container(repo);

    final archived = await container.read(archivedGoalsProvider.future);

    expect(archived.map((g) => g.id), ['archived1']);
  });

  test('goalsProvider excludes archived goals', () async {
    final repo = _FakeGoalRepository([
      _goal('active1'),
      _goal('archived1', archived: true),
    ]);
    final container = _container(repo);

    final active = await container.read(goalsProvider.future);

    expect(active.map((g) => g.id), ['active1']);
  });

  test('an empty archive is an empty list, not the active list', () async {
    final repo = _FakeGoalRepository([_goal('active1')]);
    final container = _container(repo);

    expect(await container.read(archivedGoalsProvider.future), isEmpty);
  });
}

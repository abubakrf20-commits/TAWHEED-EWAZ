import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/goals/data/repositories/goal_repository_impl.dart';
import 'package:tawheeed/features/goals/domain/goal_source_link.dart';
import 'package:tawheeed/features/goals/domain/repositories/goal_repository.dart';
import 'package:tawheeed/features/goals/presentation/providers/goals_provider.dart';
import 'package:tawheeed/features/goals/presentation/screens/goal_detail_screen.dart';
import 'package:tawheeed/features/hifz/data/daos/hifz_dao.dart';
import 'package:tawheeed/features/khatm/domain/repositories/khatm_repository.dart';
import 'package:tawheeed/features/notes/domain/repositories/note_repository.dart';

class _Repo implements GoalRepository {
  _Repo(this.goal);
  final GoalTableData goal;

  /// Set when the screen asks to clear a link, so the test can assert it.
  String? clearedLink;

  @override
  Future<void> clearSourceLink(String id) async => clearedLink = id;

  @override
  Future<GoalTableData?> getGoal(String id) async => goal;

  @override
  Future<List<GoalTableData>> getGoals({bool includeArchived = false}) async =>
      [goal];

  @override
  Future<int> goalTotal(String goalId) async => 3;

  @override
  Future<void> upsertGoal(GoalTableCompanion entry) async {}

  @override
  Future<void> deleteGoal(String id) async {}

  @override
  Future<void> setArchived(String id, bool archived) async {}

  @override
  Future<Map<String, int>> totalsByGoal(List<String> goalIds) async =>
      {'g1': 3};

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

GoalTableData _goal({String type = '', String id = ''}) {
  final now = DateTime.now();
  return GoalTableData(
    id: 'g1',
    title: 'حفظ جزء',
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
    linkedType: type,
    linkedId: id,
    isActive: true,
    isArchived: false,
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> _pump(
  WidgetTester tester,
  _Repo repo, {
  required LinkedSourceSnapshot? snapshot,
}) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        goalRepositoryProvider.overrideWithValue(repo),
        // Overrides the resolver, so the card can be driven into every state
        // without standing up the notes / hifz / khatm provider graphs.
        goalSourceLinkResolverProvider.overrideWithValue(
          _StubResolver(snapshot),
        ),
      ],
      child: const MaterialApp(home: GoalDetailScreen(goalId: 'g1')),
    ),
  );
  await tester.pumpAndSettle();
}

class _StubResolver implements GoalSourceLinkResolver {
  _StubResolver(this.snapshot);
  final LinkedSourceSnapshot? snapshot;

  @override
  Future<LinkedSourceSnapshot> resolve(String type, String id) async =>
      snapshot ?? LinkedSourceSnapshot.unknown;

  @override
  NoteRepository? Function() get notes => _null;

  @override
  HifzDao? Function() get hifz => _null;

  @override
  KhatmRepository? Function() get khatm => _null;
}

T? _null<T>() => null;

void main() {
  testWidgets('an unlinked goal shows no source card at all', (tester) async {
    await _pump(tester, _Repo(_goal()), snapshot: null);

    // Permanent empty furniture on every goal would be noise, so the card is
    // omitted rather than rendered blank.
    expect(find.text('منبع متصل'), findsNothing);
    expect(find.text('حذف اتصال'), findsNothing);
  });

  testWidgets('a live link shows the source, its state, and the read-only note',
      (tester) async {
    await _pump(
      tester,
      _Repo(_goal(type: 'khatm', id: 'k1')),
      snapshot: const LinkedSourceSnapshot(
        type: 'khatm',
        title: 'ختم جمعه',
        summary: '151 از 604 صفحه',
        fraction: 0.25,
      ),
    );

    expect(find.text('ختم'), findsOneWidget);
    expect(find.text('ختم جمعه'), findsOneWidget);
    expect(find.text('151 از 604 صفحه'), findsOneWidget);
    expect(find.textContaining('فقط نمایش داده می‌شود'), findsOneWidget);
    // A healthy link offers nothing to clear.
    expect(find.text('حذف اتصال'), findsNothing);
  });

  testWidgets('a fraction draws a progress bar; no fraction draws none',
      (tester) async {
    await _pump(
      tester,
      _Repo(_goal(type: 'khatm', id: 'k1')),
      snapshot: const LinkedSourceSnapshot(
        type: 'khatm',
        title: 'ختم',
        summary: 'x',
        fraction: 0.5,
      ),
    );
    final withBar = tester.widgetList<LinearProgressIndicator>(find.byType(
      LinearProgressIndicator,
    ));
    expect(withBar.any((w) => w.value == 0.5), isTrue);

    // A note reports no ratio. An empty bar would be a fabricated number, so
    // the indicator must be absent rather than 0%.
    await _pump(
      tester,
      _Repo(_goal(type: 'note', id: 'n1')),
      snapshot: const LinkedSourceSnapshot(
        type: 'note',
        title: 'برنامه',
        summary: 'خط اول',
      ),
    );
    final withoutBar = tester
        .widgetList<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator))
        .where((w) => w.value == 0.0 || w.value == null);
    expect(withoutBar, isEmpty);
  });

  testWidgets('a deleted source says so and offers to clear the link',
      (tester) async {
    final repo = _Repo(_goal(type: 'note', id: 'gone'));
    await _pump(
      tester,
      repo,
      snapshot: const LinkedSourceSnapshot(
        type: 'note',
        title: 'یادداشت',
        summary: 'یادداشت حذف شده است.',
        missing: true,
      ),
    );

    // A dangling id shown as a blank space reads as data loss.
    expect(find.textContaining('حذف شده'), findsOneWidget);
    expect(find.text('حذف اتصال'), findsOneWidget);

    await tester.tap(find.text('حذف اتصال'));
    await tester.pumpAndSettle();
    expect(repo.clearedLink, 'g1');
  });
}

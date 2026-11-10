import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/goals/data/repositories/goal_repository_impl.dart';
import 'package:tawheeed/features/goals/domain/goal_query.dart';
import 'package:tawheeed/features/goals/domain/goal_source_link.dart';
import 'package:tawheeed/features/goals/domain/repositories/goal_repository.dart';
import 'package:tawheeed/features/goals/presentation/utils/goal_dates.dart';
import 'package:tawheeed/features/goals/presentation/utils/goal_ids.dart';
import 'package:tawheeed/features/goals/services/goal_reminder_scheduler.dart';
import 'package:tawheeed/features/hifz/data/daos/hifz_dao.dart';
import 'package:tawheeed/features/khatm/data/repositories/khatm_repository_impl.dart';
import 'package:tawheeed/features/notes/data/repositories/note_repository_impl.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Guards the cold-start reminder sync so it runs once per app launch, the
/// same way the task provider does.
var _remindersArmed = false;

/// Goals that are not archived — the main list.
final goalsProvider = FutureProvider<List<GoalTableData>>((ref) async {
  final repo = ref.watch(goalRepositoryProvider);
  final goals = await repo.getGoals();
  if (!_remindersArmed) {
    _remindersArmed = true;
    // Daily goal reminders do not survive a reboot, so they are re-armed here.
    // Fire-and-forget: a scheduling failure must not fail the list query.
    unawaited(_armReminders(repo, goals));
  }
  return goals;
});

Future<void> _armReminders(
    GoalRepository repo, List<GoalTableData> goals) async {
  try {
    final totals = await repo.totalsByGoal(goals.map((g) => g.id).toList());
    await GoalReminderScheduler.syncAll(goals, totals);
  } catch (e) {
    AppLogger.warning('goals_provider', 'reminder sync failed: $e');
  }
}

/// Archived goals — the «بایگانی» sheet.
///
/// The sheet was permanently empty. It asked for `includeArchived: true` and
/// then filtered the result for `isArchived` in the widget, but that flag only
/// means "stop hiding archived rows", so the unfiltered list came back full of
/// ACTIVE goals and every one of them failed the filter.
final archivedGoalsProvider = FutureProvider<List<GoalTableData>>((ref) async {
  final all =
      await ref.watch(goalRepositoryProvider).getGoals(includeArchived: true);
  return all.where((g) => g.isArchived).toList();
});

/// Totals for every visible goal, in one query.
///
/// The list screen used to watch a per-goal `goalTotalProvider`, which meant
/// N SUM queries and N table scans to draw N cards. This groups once.
///
/// Goals with no progress rows are absent from the map rather than mapped to
/// zero; callers read with a zero default.
final goalTotalsProvider = FutureProvider<Map<String, int>>((ref) async {
  final goals = await ref.watch(goalsProvider.future);
  return ref
      .read(goalRepositoryProvider)
      .totalsByGoal(goals.map((g) => g.id).toList());
});

/// The user's search text, filters and ordering.
///
/// Plain `StateProvider`-style mutable state rather than query parameters:
/// these are view preferences, they should survive a rebuild and a trip to
/// the editor, and re-querying the database for a keystroke would be pure
/// waste over a list that is already in memory.
class GoalListOptionsController extends Notifier<GoalListOptions> {
  @override
  GoalListOptions build() => const GoalListOptions();

  GoalFilter get filter => state.filter;
  GoalSort get sort => state.sort;

  void setQuery(String query) => state = GoalListOptions(
        filter: state.filter.copyWith(query: query),
        sort: sort,
      );

  void setSort(GoalSort value) =>
      state = GoalListOptions(filter: filter, sort: value);

  void setCategory(String? category) => state = GoalListOptions(
        filter: category == null
            ? filter.copyWith(clearCategory: true)
            : filter.copyWith(category: category),
        sort: sort,
      );

  void setPriority(int? priority) => state = GoalListOptions(
        filter: priority == null
            ? filter.copyWith(clearPriority: true)
            : filter.copyWith(priority: priority),
        sort: sort,
      );

  void setHideCompleted(bool value) => state = GoalListOptions(
        filter: filter.copyWith(hideCompleted: value),
        sort: sort,
      );

  void clear() => state = const GoalListOptions();
}

final goalListOptionsProvider =
    NotifierProvider<GoalListOptionsController, GoalListOptions>(
        GoalListOptionsController.new);

/// The sorted, filtered list the screen draws.
///
/// Depends on the raw goals, the totals and the active days, so it rebuilds
/// whenever any of them change — including right after a write, because every
/// mutation invalidates all three.
final goalListEntriesProvider =
    FutureProvider<List<GoalListEntry>>((ref) async {
  final goals = await ref.watch(goalsProvider.future);
  if (goals.isEmpty) return const [];
  final ids = goals.map((g) => g.id).toList();
  final repo = ref.watch(goalRepositoryProvider);
  final totals = await repo.totalsByGoal(ids);
  final days = await repo.positiveDaysByGoal(ids);
  final options = ref.watch(goalListOptionsProvider);
  final today = DateTime.now();

  return applyGoalQuery(
    [
      for (final g in goals)
        GoalListEntry(
          goal: g,
          total: totals[g.id] ?? 0,
          streak: goalStreakFrom(days[g.id] ?? const [], today: today),
        ),
    ],
    filter: options.filter,
    sort: options.sort,
    today: today,
  );
});

final goalDetailProvider =
    FutureProvider.family<GoalTableData?, String>((ref, id) {
  return ref.watch(goalRepositoryProvider).getGoal(id);
});

/// Lifetime total for the detail screen.
final goalTotalProvider = FutureProvider.family<int, String>((ref, id) {
  return ref.watch(goalRepositoryProvider).goalTotal(id);
});

/// Per-day sums for a goal, oldest first. One map feeds the chart, the
/// 7-day pace average and the history list.
final goalProgressProvider =
    FutureProvider.family<Map<String, int>, String>((ref, id) {
  return ref.watch(goalRepositoryProvider).progressByDay(id);
});

/// The individual entries behind a goal, newest first.
///
/// Separate from [goalProgressProvider] because the per-day sums cannot
/// identify a row, and the history needs row ids to offer edit and delete.
final goalEntriesProvider =
    FutureProvider.family<List<GoalProgressTableData>, String>((ref, id) {
  return ref.watch(goalRepositoryProvider).progressEntries(id);
});

/// Streak arithmetic for a goal, from its positive days.
final goalStreakProvider = FutureProvider.family<GoalStreak, String>((ref, id) {
  return ref.watch(goalRepositoryProvider).positiveDaysByGoal([id]).then(
      (m) => goalStreakFrom(m[id] ?? const [], today: DateTime.now()));
});

/// Resolves linked sources (note / hafiz / khatm) for display.
///
/// The collaborators are passed as thunks rather than read here, so the
/// resolver stays a pure function of its three dependencies and the goals
/// domain keeps no import of the notes, hifz or khatm provider graphs.
final goalSourceLinkResolverProvider = Provider<GoalSourceLinkResolver>((ref) {
  return GoalSourceLinkResolver(
    notes: () => ref.read(noteRepositoryProvider),
    hifz: () => ref.read(hifzDaoProvider),
    khatm: () => ref.read(khatmRepositoryProvider),
  );
});

/// A goal's linked source, resolved for display. Null when the goal is not
/// linked at all, which the detail screen renders as no card rather than as
/// an error.
final goalSourceLinkProvider =
    FutureProvider.family<LinkedSourceSnapshot?, String>((ref, id) async {
  final goal = await ref.watch(goalDetailProvider(id).future);
  if (goal == null || goal.linkedType.isEmpty || goal.linkedId.isEmpty) {
    return null;
  }
  return ref
      .watch(goalSourceLinkResolverProvider)
      .resolve(goal.linkedType, goal.linkedId);
});

/// How much has been logged today.
final goalTodayCountProvider = FutureProvider.family<int, String>((ref, id) {
  return ref.watch(goalRepositoryProvider).progressOn(id, goalTodayIso());
});

/// Whether a boolean (انجام/نشد) goal is checked off today.
///
/// Was reading every progress row of the goal and scanning it in Dart to
/// answer a yes/no question, when `progressOn` exists for exactly that.
final goalTodayProvider = FutureProvider.family<bool, String>((ref, id) async {
  final count = await ref.watch(goalTodayCountProvider(id).future);
  return count > 0;
});

/// «امروز X از Y هدف» — the home-screen tally.
///
/// [total] counts only goals still OPEN today: an inactive goal asks nothing
/// of the user, and a goal whose overall target is met has stopped asking
/// too (the same rule [GoalReminderScheduler] uses to silence it) — counting
/// either would make the fraction a lie about what is left to do.
final goalsTodaySummaryProvider =
    FutureProvider<({int done, int total})>((ref) async {
  final goals = await ref.watch(goalsProvider.future);
  final repo = ref.read(goalRepositoryProvider);
  final today = goalTodayIso();
  var done = 0;
  var total = 0;
  for (final g in goals.where((g) => g.isActive)) {
    final totalAll = await repo.goalTotal(g.id);
    final metOverall = g.targetType == 'boolean'
        ? totalAll > 0
        : (g.targetNumber > 0 && totalAll >= g.targetNumber);
    if (metOverall) continue;
    total++;
    final logged = await repo.progressOn(g.id, today);
    final needed =
        g.targetType == 'boolean' ? 1 : (g.dailyTarget > 0 ? g.dailyTarget : 1);
    if (logged >= needed) done++;
  }
  return (done: done, total: total);
});

/// Re-run every query that could show stale goal data.
///
/// The screens used to hand-roll `ref.invalidate(goalsProvider)` in four
/// places, and the editor only invalidated the list — so after saving an
/// edit the detail and progress providers kept their old values. A dead
/// `refetchGoals` helper existed for this job but was never called and did
/// not cover the family providers anyway.
void invalidateGoal(WidgetRef ref, String goalId) {
  ref.invalidate(goalsProvider);
  ref.invalidate(archivedGoalsProvider);
  ref.invalidate(goalTotalsProvider);
  ref.invalidate(goalListEntriesProvider);
  ref.invalidate(goalDetailProvider(goalId));
  ref.invalidate(goalTotalProvider(goalId));
  ref.invalidate(goalProgressProvider(goalId));
  ref.invalidate(goalEntriesProvider(goalId));
  ref.invalidate(goalStreakProvider(goalId));
  ref.invalidate(goalTodayCountProvider(goalId));
  ref.invalidate(goalTodayProvider(goalId));
  ref.invalidate(goalSourceLinkProvider(goalId));
  ref.invalidate(goalsTodaySummaryProvider);
}

/// Archive or restore a goal, flipping only the flag.
Future<void> setGoalArchived(
    WidgetRef ref, String goalId, bool archived) async {
  await ref.read(goalRepositoryProvider).setArchived(goalId, archived);
  invalidateGoal(ref, goalId);
  // Archiving has to stop the reminder, otherwise a goal the user has put away
  // keeps showing up every morning. Restoring has to start it again: the
  // startup sweep only runs once per process, so a goal un-archived in the
  // same session stayed silent until the app was restarted.
  if (archived) {
    await GoalReminderScheduler.cancelByPayload(goalId);
  } else {
    await _resyncReminder(ref, goalId);
  }
}

/// Delete a goal and everything logged against it.
///
/// The screen used to call the repository directly, which left the scheduled
/// reminder pending: the payload is derived from the goal id, and nothing
/// cancels it, so a deleted goal kept waking the user up.
Future<void> deleteGoal(WidgetRef ref, String goalId) async {
  await ref.read(goalRepositoryProvider).deleteGoal(goalId);
  await GoalReminderScheduler.cancelByPayload(goalId);
  ref.invalidate(goalsProvider);
  ref.invalidate(archivedGoalsProvider);
  ref.invalidate(goalTotalsProvider);
  ref.invalidate(goalListEntriesProvider);
}

/// Everything needed to put a deleted goal back: the row plus its full
/// progress history, since the cascade wipes the children with it.
class GoalUndoSnapshot {
  final GoalTableData goal;
  final List<GoalProgressTableData> entries;
  const GoalUndoSnapshot(this.goal, this.entries);
}

/// Delete a goal and return a snapshot the UI can offer to restore.
///
/// The capture must happen before [deleteGoal]: the ON DELETE CASCADE removes
/// the progress rows with the parent, so anything after the delete is too
/// late to undo faithfully.
Future<GoalUndoSnapshot> deleteGoalWithSnapshot(
    WidgetRef ref, GoalTableData goal) async {
  // A large limit rather than the DAO's 200-row default: a boolean goal
  // checked daily for a year has ~365 rows, and undoing a delete that only
  // restored 200 of them would silently lose history.
  final entries = await ref
      .read(goalRepositoryProvider)
      .progressEntries(goal.id, limit: 100000);
  await deleteGoal(ref, goal.id);
  return GoalUndoSnapshot(goal, entries);
}

/// Re-insert a deleted goal and its progress, then re-arm its reminder.
///
/// Takes a [ProviderContainer] rather than a `WidgetRef` on purpose: the
/// restore fires from a SnackBar action after the detail screen has popped,
/// so the screen's own ref is already dead. A container grabbed before the
/// navigation lives for as long as the app.
Future<void> restoreGoal(
    ProviderContainer container, GoalUndoSnapshot snapshot) async {
  final repo = container.read(goalRepositoryProvider);
  await repo.upsertGoal(snapshot.goal.toCompanion(false));
  for (final entry in snapshot.entries) {
    await repo.addProgress(entry.toCompanion(false));
  }
  final id = snapshot.goal.id;
  container
    ..invalidate(goalsProvider)
    ..invalidate(archivedGoalsProvider)
    ..invalidate(goalTotalsProvider)
    ..invalidate(goalListEntriesProvider)
    ..invalidate(goalDetailProvider(id))
    ..invalidate(goalTotalProvider(id))
    ..invalidate(goalProgressProvider(id))
    ..invalidate(goalEntriesProvider(id))
    ..invalidate(goalStreakProvider(id))
    ..invalidate(goalTodayCountProvider(id))
    ..invalidate(goalTodayProvider(id))
    ..invalidate(goalSourceLinkProvider(id))
    ..invalidate(goalsTodaySummaryProvider);
  // The delete cancelled the scheduled reminder; putting the goal back has to
  // schedule it again or a restored goal stays silent.
  final goal = await repo.getGoal(id);
  if (goal != null) {
    final total = await repo.goalTotal(id);
    final complete = goal.targetType == 'boolean'
        ? total > 0
        : (goal.targetNumber > 0 && total >= goal.targetNumber);
    await GoalReminderScheduler.syncFor(goal, isComplete: complete);
  }
}

/// Re-arm one goal's reminder after its progress changed.
///
/// A reminder is dropped once the target is met (see [GoalStreak] and
/// [GoalReminderScheduler.shouldSchedule]) — a daily "keep going" prompt on a
/// finished goal is the most likely reason a user turns reminders off for
/// everything.
Future<void> _resyncReminder(WidgetRef ref, String goalId) async {
  final repo = ref.read(goalRepositoryProvider);
  final goal = await repo.getGoal(goalId);
  if (goal == null) {
    await GoalReminderScheduler.cancelByPayload(goalId);
    return;
  }
  final total = await repo.goalTotal(goalId);
  final complete = goal.targetType == 'boolean'
      ? total > 0
      : (goal.targetNumber > 0 && total >= goal.targetNumber);
  await GoalReminderScheduler.syncFor(goal, isComplete: complete);
}

/// Check off (or undo) today on a boolean goal.
Future<void> toggleBooleanToday(
  WidgetRef ref,
  GoalTableData goal, {
  required bool doneToday,
}) async {
  final today = goalTodayIso();
  final id = booleanProgressId(goal.id, today);
  final repo = ref.read(goalRepositoryProvider);
  if (doneToday) {
    await repo.deleteProgressEntry(id);
  } else {
    await repo.addProgress(GoalProgressTableCompanion(
      id: Value(id),
      goalId: Value(goal.id),
      date: Value(today),
      amount: const Value(1),
      createdAt: Value(DateTime.now()),
    ));
  }
  invalidateGoal(ref, goal.id);
  unawaited(_resyncReminder(ref, goal.id));
}

/// Log progress. [date] defaults to today; pass an earlier day to back-fill
/// a forgotten entry, which the old UI made impossible because every caller
/// hardcoded today.
Future<void> addGoalProgress(
  WidgetRef ref,
  String goalId,
  int amount, {
  String? date,
}) async {
  await ref.read(goalRepositoryProvider).addProgress(
        GoalProgressTableCompanion(
          id: Value(newProgressId()),
          goalId: Value(goalId),
          date: Value(date ?? goalTodayIso()),
          amount: Value(amount),
          createdAt: Value(DateTime.now()),
        ),
      );
  invalidateGoal(ref, goalId);
  // This is the call that can complete a goal, so it is the one that has to
  // re-check the reminder.
  unawaited(_resyncReminder(ref, goalId));
}

/// Correct a mistyped amount in place.
Future<void> updateGoalProgress(
  WidgetRef ref,
  String goalId,
  String entryId,
  int amount,
) async {
  await ref.read(goalRepositoryProvider).updateProgress(entryId, amount);
  invalidateGoal(ref, goalId);
  unawaited(_resyncReminder(ref, goalId));
}

/// Remove one logged entry.
Future<void> deleteGoalProgress(
  WidgetRef ref,
  String goalId,
  String entryId,
) async {
  await ref.read(goalRepositoryProvider).deleteProgressEntry(entryId);
  invalidateGoal(ref, goalId);
  // Deleting can un-complete a goal, which has to bring its reminder back.
  unawaited(_resyncReminder(ref, goalId));
}

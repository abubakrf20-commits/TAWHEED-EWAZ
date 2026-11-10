import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/features/tasks/domain/entities/subtask.dart';
import 'package:tawheeed/features/tasks/domain/entities/task_model.dart';
import 'package:tawheeed/features/tasks/domain/task_recurrence.dart';
import 'package:tawheeed/features/tasks/services/task_reminder_scheduler.dart';
import 'package:tawheeed/features/tasks/data/daos/task_aux_dao.dart';

import 'package:tawheeed/features/tasks/data/repositories/task_repository_impl.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/entity_ids.dart';

/// Completed tasks older than this many days leave the main lists for the
/// «بایگانی» archive section.
const taskArchiveThresholdDays = 30;

/// Whether [t] belongs in the archive: completed and untouched for more than
/// [taskArchiveThresholdDays]. Falls back to updated/created stamps when the
/// completion stamp is missing (legacy rows).
bool isTaskArchived(TaskModel t) {
  if (!t.isCompleted) return false;
  final done = t.completedAt ?? t.updatedAt ?? t.createdAt;
  final day = DateTime(done.year, done.month, done.day);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return today.difference(day).inDays > taskArchiveThresholdDays;
}

final taskListProvider =
    NotifierProvider<TaskListNotifier, List<TaskModel>>(TaskListNotifier.new);

/// Where the very first DB load got to.
///
/// WHY three states and not a bool: the old flag meant "the read finished",
/// success or failure alike — so a failed query marked the list loaded and the
/// screen offered «اولین کارت را بساز» to someone whose fifty tasks had simply
/// not been read.
enum TasksLoadStatus { loading, ready, failed }

final tasksLoadedProvider =
    NotifierProvider<TasksLoadedNotifier, TasksLoadStatus>(
        TasksLoadedNotifier.new);

class TasksLoadedNotifier extends Notifier<TasksLoadStatus> {
  @override
  TasksLoadStatus build() => TasksLoadStatus.loading;

  void markLoaded() => state = TasksLoadStatus.ready;

  void markFailed() => state = TasksLoadStatus.failed;

  void markLoading() => state = TasksLoadStatus.loading;
}

final tasksByDateProvider =
    Provider.autoDispose.family<List<TaskModel>, DateTime>((ref, date) {
  final tasks = ref.watch(taskListProvider);
  return tasks.where((t) {
    if (t.dueDate == null) return false;
    final d = t.dueDate!;
    return d.year == date.year && d.month == date.month && d.day == date.day;
  }).toList();
});

final taskIdsProvider = Provider<List<String>>((ref) {
  return ref.watch(taskListProvider).map((t) => t.id).toList();
});

final taskByIdProvider =
    Provider.autoDispose.family<TaskModel?, String>((ref, id) {
  for (final t in ref.watch(taskListProvider)) {
    if (t.id == id) return t;
  }
  return null;
});

/// Completion history (newest first) of one task — feeds streaks and stats.
final taskHistoryProvider =
    FutureProvider.autoDispose.family<List<DateTime>, String>((ref, id) async {
  return ref.read(taskAuxDaoProvider).completionsOf(id);
});

/// Streak + total completions of one task for the tile/dialog badges.
final taskStreakProvider = FutureProvider.autoDispose
    .family<({int streak, String unit, int total}), String>((ref, id) async {
  final task = ref.watch(taskByIdProvider(id));
  final completions = await ref.read(taskAuxDaoProvider).completionsOf(id);
  final streak = TaskRecurrence.currentStreak(
    completions,
    task?.recurringType,
    DateTime.now(),
  );
  // The badge names the period the streak counts, which is the task's own
  // cadence — «۳ روز» over a monthly task was simply wrong.
  final unit = switch (TaskRecurrence.baseOf(task?.recurringType)) {
    TaskRecurrence.weekly => 'هفته',
    TaskRecurrence.monthly => 'ماه',
    TaskRecurrence.everyNDays => 'دوره',
    _ => 'روز',
  };
  return (streak: streak, unit: unit, total: completions.length);
});

/// What [TaskListNotifier.deleteTask] keeps in memory so the delete snackbar
/// can restore a task completely — the cascade also drops its aux rows.
class _DeletedTask {
  const _DeletedTask({
    required this.task,
    required this.completions,
    required this.subtasks,
  });

  final TaskModel task;
  final List<DateTime> completions;
  final List<Subtask> subtasks;
}

class TaskListNotifier extends Notifier<List<TaskModel>> {
  bool _loaded = false;

  /// Resolved when the initial DB load finishes. Mutations await it: the
  /// load assigns `state` wholesale from a snapshot taken before they could
  /// run, so a task added in the first moment after opening the screen was
  /// clobbered out of the list (it existed on disk, but vanished from view
  /// until the next restart).
  Completer<void> _ready = Completer<void>();

  @override
  List<TaskModel> build() {
    _ready = Completer<void>();
    _load();
    return [];
  }

  Future<void> _awaitReady() async {
    if (!_ready.isCompleted) await _ready.future;
  }

  String _generateId() => newEntityId();

  Future<void> _load() async {
    var ok = false;
    try {
      final repo = ref.read(taskRepositoryProvider);
      await repo.migrateFromLegacyIfNeeded();
      final tasks = await repo.getAllTasks();
      if (!_loaded) {
        _loaded = true;
        state = tasks;
        // Re-arm due-date reminders after a cold start / reboot.
        unawaited(TaskReminderScheduler.syncAll(tasks));
      }
      ok = true;
    } catch (e) {
      AppLogger.warning('task_provider', 'initial load failed: $e');
    } finally {
      _ready.complete();
      if (ref.mounted) {
        final notifier = ref.read(tasksLoadedProvider.notifier);
        if (ok) {
          notifier.markLoaded();
        } else {
          notifier.markFailed();
        }
      }
    }
  }

  /// Re-runs the initial read after a failure — the load is guarded by
  /// `_loaded`, so the retry button would otherwise be a no-op.
  Future<void> reload() async {
    _loaded = false;
    _ready = Completer<void>();
    if (ref.mounted) {
      ref.read(tasksLoadedProvider.notifier).markLoading();
    }
    await _load();
  }

  Future<String?> addTask({
    required String title,
    String? description,
    bool isRecurring = false,
    String? recurringType,
    DateTime? dueDate,
    bool remindEnabled = false,
    String? remindAt,
    int priority = 0,
    List<String> tags = const [],
  }) async {
    await _awaitReady();
    final id = _generateId();
    final now = DateTime.now();
    final task = TaskModel(
      id: id,
      title: title,
      description: description,
      isRecurring: isRecurring,
      recurringType: recurringType,
      dueDate: dueDate,
      remindEnabled: remindEnabled,
      remindAt: remindAt,
      createdAt: now,
      updatedAt: now,
      priority: priority,
      tags: tags,
    );
    state = [task, ...state];
    try {
      await ref.read(taskRepositoryProvider).saveTask(task);
    } catch (e) {
      AppLogger.warning('task_provider', 'error: $e');
      state = state.where((t) => t.id != id).toList();
      return null;
    }
    unawaited(TaskReminderScheduler.syncFor(task));
    return id;
  }

  Future<void> toggleTask(String id) async {
    await _awaitReady();
    final list = state;
    final idx = list.indexWhere((t) => t.id == id);
    if (idx >= 0) {
      final updated = await _buildToggled(list[idx]);
      if (updated == null) return;
      final original = state;
      state = [...list]..[idx] = updated;
      try {
        await ref.read(taskRepositoryProvider).saveTask(updated);
      } catch (e) {
        AppLogger.warning('task_provider', 'error: $e');
        state = original;
        return;
      }
      _afterToggle(updated, completing: !list[idx].isCompleted);
      return;
    }
    if (!_loaded) {
      final fromDb = await ref.read(taskRepositoryProvider).getTask(id);
      if (fromDb == null) return;
      final updated = await _buildToggled(fromDb);
      if (updated == null) return;
      final original = state;
      state = [...state, updated];
      try {
        await ref.read(taskRepositoryProvider).saveTask(updated);
      } catch (e) {
        AppLogger.warning('task_provider', 'error: $e');
        state = original;
        return;
      }
      _afterToggle(updated, completing: !fromDb.isCompleted);
    }
  }

  /// Completion/un-completion transition shared by both toggle paths.
  /// A daily/weekly duty rolls straight to its next occurrence: it stays in
  /// the pending list (with [completedAt] kept as the last-completion stamp)
  /// instead of filling the «انجام شده» archive day after day.
  Future<TaskModel?> _buildToggled(TaskModel previous) async {
    final now = DateTime.now();
    final completing = !previous.isCompleted;
    var updated = previous.copyWith(
      isCompleted: completing,
      completedAt: completing ? now : null,
      updatedAt: now,
    );
    if (completing && previous.hasRecurrence) {
      updated = updated.copyWith(
        isCompleted: false,
        dueDate: TaskRecurrence.nextDue(
          type: previous.recurringType!,
          dueDate: previous.dueDate,
          completedAt: now,
        ),
      );
    }
    return updated;
  }

  void _afterToggle(TaskModel updated, {required bool completing}) {
    if (completing) {
      // Per-occurrence history for streaks/stats (recurring duties roll
      // forward, so without this log every completion would be forgotten).
      final at = updated.completedAt ?? DateTime.now();
      unawaited(ref.read(taskAuxDaoProvider).logCompletion(updated.id, at));
    }
    if (updated.hasRecurrence && !updated.isCompleted) {
      unawaited(TaskReminderScheduler.syncFor(updated));
    } else if (completing) {
      unawaited(TaskReminderScheduler.cancelFor(updated));
    } else {
      // Re-opened before the due date → re-arm its reminder.
      unawaited(TaskReminderScheduler.syncFor(updated));
    }
  }

  Future<void> updateTask(TaskModel task) async {
    await _awaitReady();
    final list = state;
    final idx = list.indexWhere((t) => t.id == task.id);
    if (idx >= 0) {
      final previous = list[idx];
      final updated = task.copyWith(updatedAt: DateTime.now());
      state = [...list]..[idx] = updated;
      try {
        await ref.read(taskRepositoryProvider).saveTask(updated);
      } catch (e) {
        AppLogger.warning('task_provider', 'error: $e');
        state = [...list]..[idx] = previous;
        return;
      }
      unawaited(TaskReminderScheduler.syncFor(updated));
      return;
    }
    if (!_loaded) {
      final fromDb = await ref.read(taskRepositoryProvider).getTask(task.id);
      if (fromDb != null) {
        final updated = task.copyWith(updatedAt: DateTime.now());
        state = [...state, updated];
        try {
          await ref.read(taskRepositoryProvider).saveTask(updated);
        } catch (e) {
          AppLogger.warning('task_provider', 'error: $e');
          state = state.where((t) => t.id != task.id).toList();
          return;
        }
        unawaited(TaskReminderScheduler.syncFor(updated));
      }
    }
  }

  Future<void> deleteTask(String id) async {
    await _awaitReady();
    final list = state;
    final idx = list.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    final removed = list[idx];
    // Optimistic: the tile disappears immediately; the aux snapshot below is
    // best-effort so a slow/failed DB read never blocks the UI.
    state = list.where((t) => t.id != id).toList();
    try {
      await ref.read(taskRepositoryProvider).deleteTask(id);
    } catch (e) {
      AppLogger.warning('task_provider', 'error: $e');
      state = list;
      return;
    }
    unawaited(TaskReminderScheduler.cancelByPayload(id));
    // Snapshot the task's history and subtasks before the cascade delete so
    // the snackbar can restore the whole thing. Best effort: on failure the
    // undo still restores the task itself, just without history.
    final aux = ref.read(taskAuxDaoProvider);
    List<DateTime> completions = const [];
    List<Subtask> subtasks = const [];
    try {
      completions = await aux.completionsOf(id);
      subtasks = await aux.subtasksOf(id);
      // Cascade: history + subtasks belong to the deleted task.
      await aux.clearHistory(id);
      await aux.clearSubtasks(id);
    } catch (_) {
      AppLogger.warning('task_provider', 'operation failed');
    }
    _lastDeleted = _DeletedTask(
      task: removed,
      completions: completions,
      subtasks: subtasks,
    );
  }

  /// Snapshot of the last deleted task (with its aux rows) for undo.
  _DeletedTask? _lastDeleted;

  /// Restores the task removed by the last [deleteTask]: the task row itself,
  /// its completion history (streaks/stats) and its subtasks.
  Future<void> undoLastDelete() async {
    final snapshot = _lastDeleted;
    if (snapshot == null) return;
    _lastDeleted = null;
    final list = state;
    if (list.any((t) => t.id == snapshot.task.id)) return;
    state = [snapshot.task, ...list];
    try {
      await ref.read(taskRepositoryProvider).saveTask(snapshot.task);
    } catch (e) {
      AppLogger.warning('task_provider', 'error: $e');
      state = list;
      return;
    }
    final aux = ref.read(taskAuxDaoProvider);
    for (final at in snapshot.completions) {
      await aux.logCompletion(snapshot.task.id, at);
    }
    for (final s in snapshot.subtasks) {
      await aux.upsertSubtask(s);
    }
    unawaited(TaskReminderScheduler.syncFor(snapshot.task));
  }

  /// Completed tasks removed by the last [clearCompleted], kept in memory so
  /// the snackbar can restore them.
  List<TaskModel> _lastCleared = const [];

  Future<void> clearCompleted() async {
    final list = state;
    final removed = list.where((t) => t.isCompleted).toList();
    final remaining = list.where((t) => !t.isCompleted).toList();
    if (removed.isEmpty) return;
    state = remaining;
    try {
      await ref.read(taskRepositoryProvider).clearCompleted();
    } catch (e) {
      AppLogger.warning('task_provider', 'error: $e');
      state = list;
      return;
    }
    final aux = ref.read(taskAuxDaoProvider);
    for (final t in removed) {
      unawaited(TaskReminderScheduler.cancelByPayload(t.id));
      unawaited(aux.clearHistory(t.id));
      unawaited(aux.clearSubtasks(t.id));
    }
    _lastCleared = removed;
  }

  /// Restores the tasks deleted by the last [clearCompleted] (undo snackbar).
  /// Re-inserts each row with its original id so completion stamps survive.
  Future<void> undoClearCompleted() async {
    final removed = _lastCleared;
    if (removed.isEmpty) return;
    _lastCleared = const [];
    final current = state;
    final toRestore =
        removed.where((t) => !current.any((e) => e.id == t.id)).toList();
    if (toRestore.isEmpty) return;
    state = [...toRestore, ...current];
    for (final t in toRestore) {
      try {
        await ref.read(taskRepositoryProvider).saveTask(t);
        unawaited(TaskReminderScheduler.syncFor(t));
      } catch (e) {
        AppLogger.warning('task_provider', 'error: $e');
        state = state.where((e) => e.id != t.id).toList();
      }
    }
  }
}

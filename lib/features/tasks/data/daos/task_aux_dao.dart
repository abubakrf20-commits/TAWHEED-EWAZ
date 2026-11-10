import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';
import 'package:tawheeed/features/tasks/domain/entities/subtask.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

final taskAuxDaoProvider = Provider<TaskAuxDao>((ref) {
  return TaskAuxDao(ref.read(appDatabaseProvider));
});

/// Raw-SQL access to the task auxiliary tables (completion history +
/// subtasks). The tables are plain `CREATE TABLE` schemas (see
/// [TaskAuxTables]) so no Drift codegen is involved.
class TaskAuxDao {
  final AppDatabase db;
  TaskAuxDao(this.db);

  // ── Completion history ──────────────────────────────────────────────

  /// Records one completion of [taskId] at [at]. Never throws.
  Future<void> logCompletion(String taskId, DateTime at) async {
    try {
      await db.customStatement(
        'INSERT INTO task_completion_log (task_id, completed_at) VALUES (?, ?)',
        [taskId, at.millisecondsSinceEpoch],
      );
    } catch (e) {
      AppLogger.warning('TaskAuxDao', 'logCompletion failed: $e');
    }
  }

  /// All completion instants of [taskId], newest first. Never throws.
  Future<List<DateTime>> completionsOf(String taskId) async {
    try {
      final rows = await db.customSelect(
        'SELECT completed_at FROM task_completion_log '
        'WHERE task_id = ? ORDER BY completed_at DESC',
        variables: [Variable.withString(taskId)],
      ).get();
      return [
        for (final r in rows)
          DateTime.fromMillisecondsSinceEpoch(r.read<int>('completed_at')),
      ];
    } catch (e) {
      AppLogger.warning('TaskAuxDao', 'completionsOf failed: $e');
      return const [];
    }
  }

  /// Every completion since [from] (inclusive), newest first. Powers the
  /// weekly stats card. Never throws.
  Future<List<DateTime>> completionsSince(DateTime from) async {
    try {
      final rows = await db.customSelect(
        'SELECT completed_at FROM task_completion_log '
        'WHERE completed_at >= ? ORDER BY completed_at DESC',
        variables: [Variable.withInt(from.millisecondsSinceEpoch)],
      ).get();
      return [
        for (final r in rows)
          DateTime.fromMillisecondsSinceEpoch(r.read<int>('completed_at')),
      ];
    } catch (e) {
      AppLogger.warning('TaskAuxDao', 'completionsSince failed: $e');
      return const [];
    }
  }

  /// Deletes the whole history of [taskId] (called on task delete).
  Future<void> clearHistory(String taskId) async {
    try {
      await db.customStatement(
        'DELETE FROM task_completion_log WHERE task_id = ?',
        [taskId],
      );
    } catch (e) {
      AppLogger.warning('TaskAuxDao', 'clearHistory failed: $e');
    }
  }

  // ── Subtasks ────────────────────────────────────────────────────────

  Future<List<Subtask>> subtasksOf(String taskId) async {
    try {
      final rows = await db.customSelect(
        'SELECT id, title, is_completed, position FROM task_subtask '
        'WHERE task_id = ? ORDER BY position ASC, rowid ASC',
        variables: [Variable.withString(taskId)],
      ).get();
      return [
        for (final r in rows)
          Subtask(
            id: r.read<String>('id'),
            taskId: taskId,
            title: r.read<String>('title'),
            isCompleted: r.read<int>('is_completed') == 1,
            position: r.read<int>('position'),
          ),
      ];
    } catch (e) {
      AppLogger.warning('TaskAuxDao', 'subtasksOf failed: $e');
      return const [];
    }
  }

  Future<void> upsertSubtask(Subtask s) async {
    try {
      await db.customStatement(
        'INSERT INTO task_subtask (id, task_id, title, is_completed, position) '
        'VALUES (?, ?, ?, ?, ?) '
        'ON CONFLICT(id) DO UPDATE SET '
        'title = excluded.title, '
        'is_completed = excluded.is_completed, '
        'position = excluded.position',
        [s.id, s.taskId, s.title, s.isCompleted ? 1 : 0, s.position],
      );
    } catch (e) {
      AppLogger.warning('TaskAuxDao', 'upsertSubtask failed: $e');
    }
  }

  Future<void> deleteSubtask(String id) async {
    try {
      await db.customStatement(
        'DELETE FROM task_subtask WHERE id = ?',
        [id],
      );
    } catch (e) {
      AppLogger.warning('TaskAuxDao', 'deleteSubtask failed: $e');
    }
  }

  /// Deletes every subtask of [taskId] (called on task delete).
  Future<void> clearSubtasks(String taskId) async {
    try {
      await db.customStatement(
        'DELETE FROM task_subtask WHERE task_id = ?',
        [taskId],
      );
    } catch (e) {
      AppLogger.warning('TaskAuxDao', 'clearSubtasks failed: $e');
    }
  }
}

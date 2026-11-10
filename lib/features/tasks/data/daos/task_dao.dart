import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';
import 'package:tawheeed/features/tasks/domain/entities/task_model.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

final taskDaoProvider = Provider<TaskDao>((ref) {
  return TaskDao(ref.read(appDatabaseProvider));
});

class TaskDao {
  final AppDatabase db;
  TaskDao(this.db);

  Future<List<TaskModel>> getAllTasks() async {
    final rows = await db.select(db.tasksTable).get();
    return rows.map(_toModel).toList();
  }

  Future<TaskModel?> getTask(String id) async {
    final row = await (db.select(db.tasksTable)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toModel(row);
  }

  Future<void> upsertTask(TaskModel task) async {
    await db.into(db.tasksTable).insertOnConflictUpdate(
          TasksTableData(
            id: task.id,
            title: task.title,
            description: task.description,
            isCompleted: task.isCompleted,
            isRecurring: task.isRecurring,
            recurringType: task.recurringType,
            dueDate: task.dueDate,
            remindEnabled: task.remindEnabled,
            remindAt: task.remindAt,
            createdAt: task.createdAt,
            updatedAt: task.updatedAt,
            completedAt: task.completedAt,
            priority: task.priority,
            tags: task.tags.join(','),
          ),
        );
  }

  /// Alias for [upsertTask] — matches the naming used by the old TaskRepository.
  Future<void> saveTask(TaskModel task) => upsertTask(task);

  Future<void> deleteTask(String id) async {
    await (db.delete(db.tasksTable)..where((t) => t.id.equals(id))).go();
  }

  Future<void> clearCompleted() async {
    await (db.delete(db.tasksTable)..where((t) => t.isCompleted.equals(true)))
        .go();
  }

  Future<List<TaskModel>> getTasksByDate(DateTime date) async {
    final all = await getAllTasks();
    return all.where((t) {
      if (t.dueDate == null) return false;
      final d = t.dueDate!;
      return d.year == date.year && d.month == date.month && d.day == date.day;
    }).toList();
  }

  /// One-time migration of the legacy raw `tasks.sqlite` database into Drift.
  /// Safe to call repeatedly (guarded by a SharedPreferences flag).
  Future<void> migrateFromLegacyIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migratedFlag) == true) return;

    final dir = await getApplicationDocumentsDirectory();
    final legacyFile = File(p.join(dir.path, 'tasks.sqlite'));
    if (!await legacyFile.exists()) {
      await prefs.setBool(_migratedFlag, true);
      return;
    }

    try {
      final old = sqlite3.open(legacyFile.path);
      final result = old.select('SELECT * FROM task_table');
      for (final row in result) {
        await upsertTask(
          TaskModel(
            id: row['id'] as String,
            title: row['title'] as String,
            description: _strOrNull(row['description']),
            isCompleted: (row['is_completed'] as int) == 1,
            isRecurring: (row['is_recurring'] as int) == 1,
            recurringType: _strOrNull(row['recurring_type']),
            dueDate: row['due_date'] != null
                ? DateTime.parse(row['due_date'] as String)
                : null,
            createdAt: DateTime.parse(row['created_at'] as String),
            updatedAt: row['updated_at'] != null
                ? DateTime.parse(row['updated_at'] as String)
                : null,
            completedAt: row['completed_at'] != null
                ? DateTime.parse(row['completed_at'] as String)
                : null,
            priority: row['priority'] as int,
            tags: _strOrNull(row['tags'])?.isNotEmpty == true
                ? (row['tags'] as String).split(',')
                : const [],
          ),
        );
      }
      old.close();
    } catch (e) {
      AppLogger.warning('TaskDao', 'Legacy tasks migration failed: $e');
    }

    await prefs.setBool(_migratedFlag, true);
  }

  static const String _migratedFlag = 'tasks_migrated_v1';

  static String? _strOrNull(Object? v) {
    final s = v as String?;
    return s != null && s.isNotEmpty ? s : null;
  }

  TaskModel _toModel(TasksTableData r) {
    return TaskModel(
      id: r.id,
      title: r.title,
      description: r.description,
      isCompleted: r.isCompleted,
      isRecurring: r.isRecurring,
      recurringType: r.recurringType,
      dueDate: r.dueDate,
      remindEnabled: r.remindEnabled,
      remindAt: r.remindAt,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
      completedAt: r.completedAt,
      priority: r.priority,
      tags: r.tags.isNotEmpty ? r.tags.split(',') : const [],
    );
  }
}

import 'package:tawheeed/features/tasks/domain/entities/task_model.dart';

abstract class TaskRepository {
  Future<List<TaskModel>> getAllTasks();
  Future<TaskModel?> getTask(String id);
  Future<void> saveTask(TaskModel task);
  Future<void> deleteTask(String id);
  Future<void> clearCompleted();
  Future<void> migrateFromLegacyIfNeeded();
}

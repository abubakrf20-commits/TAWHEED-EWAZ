import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/features/tasks/data/daos/task_dao.dart';
import 'package:tawheeed/features/tasks/domain/entities/task_model.dart';
import 'package:tawheeed/features/tasks/domain/repositories/task_repository.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepositoryImpl(ref.read(taskDaoProvider));
});

class TaskRepositoryImpl implements TaskRepository {
  final TaskDao _dao;
  TaskRepositoryImpl(this._dao);

  @override
  Future<List<TaskModel>> getAllTasks() => _dao.getAllTasks();

  @override
  Future<TaskModel?> getTask(String id) => _dao.getTask(id);

  @override
  Future<void> saveTask(TaskModel task) => _dao.saveTask(task);

  @override
  Future<void> deleteTask(String id) => _dao.deleteTask(id);

  @override
  Future<void> clearCompleted() => _dao.clearCompleted();

  @override
  Future<void> migrateFromLegacyIfNeeded() => _dao.migrateFromLegacyIfNeeded();
}

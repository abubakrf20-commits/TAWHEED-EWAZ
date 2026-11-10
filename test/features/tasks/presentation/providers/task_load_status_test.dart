import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/tasks/data/repositories/task_repository_impl.dart';
import 'package:tawheeed/features/tasks/domain/entities/task_model.dart';
import 'package:tawheeed/features/tasks/domain/repositories/task_repository.dart';
import 'package:tawheeed/features/tasks/presentation/providers/task_provider.dart';

/// A repository whose read can be made to fail once, then succeed.
class _FakeTaskRepository implements TaskRepository {
  _FakeTaskRepository({this.tasks = const []});

  List<TaskModel> tasks;
  bool failNextLoad = false;
  int loadCalls = 0;

  @override
  Future<List<TaskModel>> getAllTasks() async {
    loadCalls++;
    if (failNextLoad) {
      failNextLoad = false;
      throw StateError('sqlite: disk I/O error');
    }
    return List.of(tasks);
  }

  @override
  Future<TaskModel?> getTask(String id) async =>
      tasks.where((t) => t.id == id).firstOrNull;

  @override
  Future<void> saveTask(TaskModel task) async {
    tasks = [...tasks.where((t) => t.id != task.id), task];
  }

  @override
  Future<void> deleteTask(String id) async {
    tasks = tasks.where((t) => t.id != id).toList();
  }

  @override
  Future<void> clearCompleted() async {
    tasks = tasks.where((t) => !t.isCompleted).toList();
  }

  @override
  Future<void> migrateFromLegacyIfNeeded() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TaskModel task(String id, String title) => TaskModel(
        id: id,
        title: title,
        createdAt: DateTime(2026, 3, 15),
      );

  test('a successful read reports ready, not merely finished', () async {
    final repo = _FakeTaskRepository(tasks: [task('t1', 'خواندن')]);
    final container = ProviderContainer(
      overrides: [taskRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    expect(container.read(tasksLoadedProvider), TasksLoadStatus.loading);
    container.read(taskListProvider);
    await container.pump();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(container.read(tasksLoadedProvider), TasksLoadStatus.ready);
    expect(container.read(taskListProvider).single.title, 'خواندن');
  });

  test('a failed read reports failed so the screen cannot claim an empty list',
      () async {
    final repo = _FakeTaskRepository(tasks: [task('t1', 'خواندن')])
      ..failNextLoad = true;
    final container = ProviderContainer(
      overrides: [taskRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    container.read(taskListProvider);
    await container.pump();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(container.read(tasksLoadedProvider), TasksLoadStatus.failed);
    expect(container.read(taskListProvider), isEmpty);
  });

  test('reload clears the loaded guard so the retry actually re-reads',
      () async {
    final repo = _FakeTaskRepository(tasks: [task('t1', 'خواندن')])
      ..failNextLoad = true;
    final container = ProviderContainer(
      overrides: [taskRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    container.read(taskListProvider);
    await container.pump();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(container.read(tasksLoadedProvider), TasksLoadStatus.failed);
    expect(repo.loadCalls, 1);

    await container.read(taskListProvider.notifier).reload();
    await container.pump();

    expect(repo.loadCalls, 2);
    expect(container.read(tasksLoadedProvider), TasksLoadStatus.ready);
    expect(container.read(taskListProvider).single.title, 'خواندن');
  });
}

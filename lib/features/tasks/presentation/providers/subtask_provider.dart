import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tawheeed/features/tasks/data/daos/task_aux_dao.dart';
import 'package:tawheeed/features/tasks/domain/entities/subtask.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/entity_ids.dart';

part 'subtask_provider.g.dart';

/// Checklist («زیرکارها») of one task, ordered by position.
@riverpod
class SubtaskList extends _$SubtaskList {
  /// Set by [build] — kept as a field so mutating methods can reach it
  /// (same shape as [BookBookmark]'s build-param family).
  @override
  String taskId = '';

  /// Resolved when the initial load finishes — same guard (and same reason)
  /// as [TaskListNotifier]: a subtask added during the load window was
  /// clobbered by the wholesale `state =` assignment.
  Completer<void> _ready = Completer<void>();

  @override
  List<Subtask> build(String taskId) {
    this.taskId = taskId;
    _ready = Completer<void>();
    _load();
    return [];
  }

  Future<void> _awaitReady() async {
    if (!_ready.isCompleted) await _ready.future;
  }

  Future<void> _load() async {
    try {
      state = await ref.read(taskAuxDaoProvider).subtasksOf(taskId);
    } catch (e) {
      AppLogger.warning('SubtaskList', 'load failed: $e');
    } finally {
      _ready.complete();
    }
  }

  String _generateId() => newEntityId();

  Future<void> addSubtask(String title) async {
    await _awaitReady();
    final text = title.trim();
    if (text.isEmpty) return;
    final item = Subtask(
      id: _generateId(),
      taskId: taskId,
      title: text,
      position: state.length,
    );
    state = [...state, item];
    await ref.read(taskAuxDaoProvider).upsertSubtask(item);
  }

  Future<void> toggleSubtask(String id) async {
    await _awaitReady();
    final idx = state.indexWhere((s) => s.id == id);
    if (idx < 0) return;
    final updated = state[idx].copyWith(isCompleted: !state[idx].isCompleted);
    state = [...state]..[idx] = updated;
    await ref.read(taskAuxDaoProvider).upsertSubtask(updated);
  }

  Future<void> renameSubtask(String id, String title) async {
    await _awaitReady();
    final text = title.trim();
    if (text.isEmpty) return;
    final idx = state.indexWhere((s) => s.id == id);
    if (idx < 0) return;
    final updated = state[idx].copyWith(title: text);
    state = [...state]..[idx] = updated;
    await ref.read(taskAuxDaoProvider).upsertSubtask(updated);
  }

  Future<void> deleteSubtask(String id) async {
    await _awaitReady();
    state = state.where((s) => s.id != id).toList();
    await ref.read(taskAuxDaoProvider).deleteSubtask(id);
  }

  /// Done/total for the tile progress bar.
  static (int done, int total) progressOf(List<Subtask> items) {
    if (items.isEmpty) return (0, 0);
    final done = items.where((s) => s.isCompleted).length;
    return (done, items.length);
  }
}

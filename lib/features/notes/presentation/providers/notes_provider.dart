import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/database/app_database.dart';

import 'package:tawheeed/features/notes/data/repositories/note_repository_impl.dart';
import 'package:tawheeed/features/notes/services/voice_note_recorder.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Manual (non-codegen) AsyncNotifier, deliberately kept out of `@riverpod`:
/// the generator reports `InvalidTypeException` for the drift row type
/// [NoteTableData] used as state (hand-written [AsyncNotifierProvider] has no
/// such restriction). Provider name/semantics are identical either way.
final notesProvider = AsyncNotifierProvider<NotesNotifier, List<NoteTableData>>(
    NotesNotifier.new);

class NotesNotifier extends AsyncNotifier<List<NoteTableData>> {
  @override
  Future<List<NoteTableData>> build() async {
    ref.onDispose(() {
      // Do not leave a pending timer behind; the file it guards is orphaned
      // either way once the provider is gone.
      _pendingAudioCleanup?.cancel();
      _pendingAudioCleanup = null;
    });
    final repo = ref.read(noteRepositoryProvider);
    final notes = await repo.getAllNotes();
    notes.sort(_sortNotes);
    return notes;
  }

  int _sortNotes(NoteTableData a, NoteTableData b) {
    if (a.isPinned && !b.isPinned) return -1;
    if (!a.isPinned && b.isPinned) return 1;
    return b.updatedAt.compareTo(a.updatedAt);
  }

  Future<void> addNote(String title, String content, List<String> tags,
      {String folder = '',
      int colorIndex = 0,
      bool isPinned = false,
      String audioPath = '',
      int audioDurationMs = 0}) async {
    // Unique id without a new dependency: millisecond timestamp + a 32-bit
    // random salt, so two creations inside the same millisecond (paste storms,
    // double taps) no longer collide like the old timestamp-only id did.
    final id =
        '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1 << 32)}';
    final note = NoteTableData(
      id: id,
      title: title,
      content: content,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      tags: tags.join(','),
      folder: folder.trim(),
      isDone: false,
      colorIndex: colorIndex,
      isPinned: isPinned,
      audioPath: audioPath,
      audioDurationMs: audioDurationMs,
    );
    await ref.read(noteRepositoryProvider).upsertNote(note);
    final current = state.value;
    if (current == null) return;
    final notes = [note, ...current]..sort(_sortNotes);
    state = AsyncData(notes);
  }

  Future<void> deleteNote(String id) async {
    final notes = state.value;
    if (notes == null) return;
    final idx = notes.indexWhere((n) => n.id == id);
    if (idx < 0) return;
    final snapshot = notes;
    final removed = notes[idx];
    // Kept in memory so the delete snackbar can restore it (undo).
    _lastDeleted = removed;
    state = AsyncData([...notes]..removeAt(idx));
    try {
      await ref.read(noteRepositoryProvider).deleteNote(id);
    } catch (e) {
      AppLogger.warning('Notes', 'delete failed, restoring: $e');
      state = AsyncData(snapshot);
      _lastDeleted = null;
      return;
    }
    // The row is gone, but the clip must survive the undo window: [undoLastDelete]
    // re-inserts the row and its player would otherwise point at a file that no
    // longer exists. Deleting it immediately restored a note that could only be
    // read, not played. Cleanup therefore waits for the snackbar to lapse, and
    // is flushed early once a *new* delete makes the old one un-undoable.
    _scheduleAudioCleanup(removed.audioPath);
  }

  /// Undo window shown by the delete snackbar, plus a small grace margin so a
  /// tap landing right at the deadline still finds its clip.
  static const _undoWindow = Duration(seconds: 5);
  static const _cleanupGrace = Duration(seconds: 2);

  Timer? _pendingAudioCleanup;
  String? _pendingAudioPath;

  void _scheduleAudioCleanup(String path) {
    if (path.isEmpty) return;
    // The previous delete can no longer be undone (undo is single-slot), so its
    // file can go now.
    final previous = _pendingAudioPath;
    _pendingAudioPath = path;
    _pendingAudioCleanup?.cancel();
    if (previous != null && previous != path) {
      unawaited(VoiceNoteRecorder.deleteStored(previous));
    }
    _pendingAudioCleanup = Timer(_undoWindow + _cleanupGrace, () {
      _pendingAudioCleanup = null;
      final due = _pendingAudioPath;
      _pendingAudioPath = null;
      if (due != null) unawaited(VoiceNoteRecorder.deleteStored(due));
    });
  }

  /// The note removed by the most recent [deleteNote] call, if it has not
  /// been restored yet.
  NoteTableData? _lastDeleted;

  /// Restores the note removed by the last [deleteNote] (undo snackbar).
  /// Re-inserts it with its original id so timestamps/color survive.
  Future<void> undoLastDelete() async {
    final note = _lastDeleted;
    if (note == null) return;
    _lastDeleted = null;
    final current = state.value ?? [];
    if (current.any((n) => n.id == note.id)) return;
    state = AsyncData([note, ...current]..sort(_sortNotes));
    try {
      await ref.read(noteRepositoryProvider).upsertNote(note);
      // Restored: cancel the pending deletion of its clip.
      if (_pendingAudioPath == note.audioPath) {
        _pendingAudioCleanup?.cancel();
        _pendingAudioCleanup = null;
        _pendingAudioPath = null;
      }
    } catch (e) {
      AppLogger.warning('Notes', 'undo-persist failed, restoring: $e');
      state = AsyncData(current);
    }
  }

  Future<void> toggleNoteDone(String id) async {
    final notes = state.value;
    if (notes == null) return;
    final idx = notes.indexWhere((n) => n.id == id);
    if (idx < 0) return;
    final updated = notes[idx]
        .copyWith(isDone: !notes[idx].isDone, updatedAt: DateTime.now());
    state = AsyncData([...notes]..[idx] = updated);
    try {
      await ref.read(noteRepositoryProvider).upsertNote(updated);
    } catch (e) {
      AppLogger.warning('Notes', 'persist failed, reverting: $e');
      state = AsyncData(notes);
    }
  }

  Future<void> toggleNotePin(String id) async {
    final notes = state.value;
    if (notes == null) return;
    final idx = notes.indexWhere((n) => n.id == id);
    if (idx < 0) return;
    final previous = notes[idx];
    final updated = previous.copyWith(
        isPinned: !previous.isPinned, updatedAt: DateTime.now());
    final sorted = [...notes]..[idx] = updated;
    sorted.sort(_sortNotes);
    state = AsyncData(sorted);
    try {
      await ref.read(noteRepositoryProvider).upsertNote(updated);
    } catch (e) {
      AppLogger.warning('Notes', 'persist failed, reverting: $e');
      state = AsyncData(notes);
    }
  }

  Future<void> setNoteColor(String id, int colorIndex) async {
    final notes = state.value;
    if (notes == null) return;
    final idx = notes.indexWhere((n) => n.id == id);
    if (idx < 0) return;
    final updated =
        notes[idx].copyWith(colorIndex: colorIndex, updatedAt: DateTime.now());
    state = AsyncData([...notes]..[idx] = updated);
    try {
      await ref.read(noteRepositoryProvider).upsertNote(updated);
    } catch (e) {
      AppLogger.warning('Notes', 'persist failed, reverting: $e');
      state = AsyncData(notes);
    }
  }

  Future<void> editNote(String id, String title, String content) async {
    final notes = state.value;
    if (notes == null) return;
    final idx = notes.indexWhere((n) => n.id == id);
    if (idx < 0) return;
    final updated = notes[idx]
        .copyWith(title: title, content: content, updatedAt: DateTime.now());
    state = AsyncData([...notes]..[idx] = updated);
    try {
      await ref.read(noteRepositoryProvider).upsertNote(updated);
    } catch (e) {
      AppLogger.warning('Notes', 'persist failed, reverting: $e');
      state = AsyncData(notes);
    }
  }
}

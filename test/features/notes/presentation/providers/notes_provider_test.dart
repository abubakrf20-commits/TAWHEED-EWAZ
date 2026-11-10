import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/features/notes/presentation/providers/notes_provider.dart';
import 'package:tawheeed/features/notes/data/daos/note_dao.dart';
import '../../../../core/database/mock_daos.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late MockNoteDao mockNoteDao;

  setUp(() {
    mockNoteDao = MockNoteDao();
    container = ProviderContainer(overrides: [
      noteDaoProvider.overrideWithValue(mockNoteDao),
    ]);
  });

  tearDown(() {
    container.dispose();
  });

  group('notesProvider', () {
    test('build returns empty list when no notes exist', () async {
      final notes = await container.read(notesProvider.future);
      expect(notes, isEmpty);
    });

    test('addNote adds a note to the list', () async {
      await container
          .read(notesProvider.notifier)
          .addNote('Title', 'Content', ['tag1']);
      final notes = container.read(notesProvider).value!;
      expect(notes.length, 1);
      expect(notes.first.title, 'Title');
      expect(notes.first.content, 'Content');
    });

    test('addNote persists via DAO', () async {
      await container.read(notesProvider.notifier).addNote('T', 'C', []);
      final stored = await mockNoteDao.getAllNotes();
      expect(stored.length, 1);
    });

    test('deleteNote removes a note', () async {
      await container.read(notesProvider.notifier).addNote('T', 'C', []);
      final note = container.read(notesProvider).value!.first;
      await container.read(notesProvider.notifier).deleteNote(note.id);
      final notes = container.read(notesProvider).value!;
      expect(notes, isEmpty);
    });

    test('undoLastDelete restores the last deleted note', () async {
      await container
          .read(notesProvider.notifier)
          .addNote('برای حذف', 'متن', ['قرآن']);
      final note = container.read(notesProvider).value!.first;

      await container.read(notesProvider.notifier).deleteNote(note.id);
      expect(container.read(notesProvider).value!, isEmpty);
      expect(await mockNoteDao.getAllNotes(), isEmpty);

      await container.read(notesProvider.notifier).undoLastDelete();

      final restored = container.read(notesProvider).value!;
      expect(restored, hasLength(1));
      expect(restored.first.id, note.id);
      expect(restored.first.title, 'برای حذف');
      expect(restored.first.tags, 'قرآن');
      // Re-persisted, not only present in memory.
      expect(await mockNoteDao.getAllNotes(), hasLength(1));

      // A second undo is a no-op (nothing left to restore).
      await container.read(notesProvider.notifier).undoLastDelete();
      expect(container.read(notesProvider).value!, hasLength(1));
    });

    test('toggleNoteDone toggles isDone', () async {
      await container.read(notesProvider.notifier).addNote('T', 'C', []);
      final note = container.read(notesProvider).value!.first;
      expect(note.isDone, false);

      await container.read(notesProvider.notifier).toggleNoteDone(note.id);
      final updated = container.read(notesProvider).value!.first;
      expect(updated.isDone, true);
    });

    test('toggleNotePin toggles isPinned and moves to top', () async {
      await container.read(notesProvider.notifier).addNote('Note1', '', []);
      await container.read(notesProvider.notifier).addNote('Note2', '', []);
      final n2 = container.read(notesProvider).value!.last;

      await container.read(notesProvider.notifier).toggleNotePin(n2.id);
      final notes = container.read(notesProvider).value!;
      expect(notes.first.isPinned, true);
      expect(notes.last.isPinned, false);
    });
  });
}

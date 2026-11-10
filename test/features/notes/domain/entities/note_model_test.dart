import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/notes/domain/entities/note_model.dart';

void main() {
  final now = DateTime(2026, 7, 10, 14);

  group('NoteModel', () {
    test('constructor sets required fields', () {
      final note = NoteModel(
        id: '1',
        title: 'My Note',
        content: 'Note content here',
        createdAt: now,
        updatedAt: now,
      );
      expect(note.id, '1');
      expect(note.title, 'My Note');
      expect(note.content, 'Note content here');
      expect(note.createdAt, now);
    });

    test('constructor sets default values', () {
      final note = NoteModel(
        id: '1',
        title: 'Test',
        content: 'Content',
        createdAt: now,
        updatedAt: now,
      );
      expect(note.updatedAt, now);
      expect(note.tags, isEmpty);
      expect(note.isPinned, false);
    });

    test('constructor sets custom values', () {
      final updated = now.add(const Duration(hours: 1));
      final note = NoteModel(
        id: '2',
        title: 'Important',
        content: 'Prayer times',
        createdAt: now,
        updatedAt: updated,
        tags: ['prayer'],
        isPinned: true,
      );
      expect(note.updatedAt, updated);
      expect(note.tags, ['prayer']);
      expect(note.isPinned, true);
    });

    group('copyWith', () {
      test('creates new object with same field values when no args', () {
        final note = NoteModel(
          id: '1',
          title: 'T',
          content: 'C',
          createdAt: now,
          updatedAt: now,
        );
        final copy = note.copyWith();
        expect(copy.id, note.id);
        expect(copy.title, note.title);
      });

      test('replaces tags list', () {
        final note = NoteModel(
          id: '1',
          title: 'T',
          content: 'C',
          createdAt: now,
          updatedAt: now,
        );
        final copy = note.copyWith(tags: ['quran', 'dhikr']);
        expect(copy.tags, ['quran', 'dhikr']);
      });
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/worship/domain/entities/evaluation_note.dart';

void main() {
  final now = DateTime(2026, 7, 10, 14);

  group('EvaluationNote', () {
    test('constructor sets required fields', () {
      final note = EvaluationNote(
        id: '1',
        title: 'Review',
        content: 'Good progress',
        createdAt: now,
      );
      expect(note.id, '1');
      expect(note.title, 'Review');
      expect(note.content, 'Good progress');
      expect(note.createdAt, now);
    });

    test('constructor sets default values', () {
      final note = EvaluationNote(
        id: '1',
        title: 'Review',
        content: 'Good',
        createdAt: now,
      );
      expect(note.updatedAt, isNull);
      expect(note.tags, isEmpty);
      expect(note.isDone, false);
      expect(note.colorIndex, 0);
      expect(note.isPinned, false);
    });

    test('constructor sets custom values', () {
      final updated = now.add(const Duration(hours: 1));
      final note = EvaluationNote(
        id: '2',
        title: 'Weekly',
        content: 'Need improvement',
        createdAt: now,
        updatedAt: updated,
        tags: ['prayer', 'quran'],
        isDone: true,
        colorIndex: 2,
        isPinned: true,
      );
      expect(note.updatedAt, updated);
      expect(note.tags, ['prayer', 'quran']);
      expect(note.isDone, true);
      expect(note.colorIndex, 2);
      expect(note.isPinned, true);
    });

    group('copyWith', () {
      test('creates new object with same field values when no args', () {
        final note = EvaluationNote(
          id: '1',
          title: 'Test',
          content: 'Content',
          createdAt: now,
        );
        final copy = note.copyWith();
        expect(copy.id, note.id);
        expect(copy.title, note.title);
      });

      test('replaces single field', () {
        final note = EvaluationNote(
          id: '1',
          title: 'Test',
          content: 'Content',
          createdAt: now,
        );
        final copy = note.copyWith(isDone: true);
        expect(copy.isDone, true);
        expect(copy.title, 'Test');
      });
    });
  });
}

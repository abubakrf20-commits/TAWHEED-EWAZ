import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/adhkar/tasbih/domain/entities/tasbih_model.dart';

void main() {
  final now = DateTime(2026, 7, 10, 14, 30);

  group('TasbihModel', () {
    test('constructor sets required fields', () {
      final model = TasbihModel(
        id: '1',
        name: 'Tasbih 1',
        targetDhikr: 'سبحان الله',
        targetCount: 100,
        createdAt: now,
      );
      expect(model.id, '1');
      expect(model.name, 'Tasbih 1');
      expect(model.targetDhikr, 'سبحان الله');
      expect(model.targetCount, 100);
      expect(model.createdAt, now);
    });

    test('constructor sets default values', () {
      final model = TasbihModel(
        id: '1',
        name: 'Test',
        targetDhikr: 'الحمد لله',
        targetCount: 33,
        createdAt: now,
      );
      expect(model.currentCount, 0);
      expect(model.totalLifetimeCount, 0);
      expect(model.updatedAt, isNull);
      expect(model.isCompleted, false);
      expect(model.isFavorite, false);
      expect(model.color, isNull);
    });

    test('constructor sets custom values', () {
      final updated = now.add(const Duration(hours: 1));
      final model = TasbihModel(
        id: '2',
        name: 'Evening',
        targetDhikr: 'الله أكبر',
        targetCount: 34,
        currentCount: 10,
        totalLifetimeCount: 100,
        createdAt: now,
        updatedAt: updated,
        isFavorite: true,
        color: 'green',
      );
      expect(model.currentCount, 10);
      expect(model.totalLifetimeCount, 100);
      expect(model.updatedAt, updated);
      expect(model.isFavorite, true);
      expect(model.color, 'green');
    });

    group('progress', () {
      test('returns 0 when targetCount is 0', () {
        final model = TasbihModel(
          id: '1',
          name: 'Test',
          targetDhikr: 'سبحان الله',
          targetCount: 0,
          createdAt: now,
        );
        expect(model.progress, 0.0);
      });

      test('returns ratio of current to target', () {
        final model = TasbihModel(
          id: '1',
          name: 'Test',
          targetDhikr: 'سبحان الله',
          targetCount: 100,
          currentCount: 25,
          createdAt: now,
        );
        expect(model.progress, 0.25);
      });

      test('clamps at 1.0', () {
        final model = TasbihModel(
          id: '1',
          name: 'Test',
          targetDhikr: 'سبحان الله',
          targetCount: 100,
          currentCount: 200,
          createdAt: now,
        );
        expect(model.progress, 1.0);
      });
    });

    group('copyWith', () {
      test('creates new object with same field values when no args', () {
        final model = TasbihModel(
          id: '1',
          name: 'Test',
          targetDhikr: 'سبحان الله',
          targetCount: 100,
          createdAt: now,
        );
        final copy = model.copyWith();
        expect(copy.id, model.id);
        expect(copy.name, model.name);
      });

      test('replaces single field', () {
        final model = TasbihModel(
          id: '1',
          name: 'Test',
          targetDhikr: 'سبحان الله',
          targetCount: 100,
          createdAt: now,
        );
        final copy = model.copyWith(currentCount: 50);
        expect(copy.currentCount, 50);
        expect(copy.name, 'Test');
      });
    });
  });
}

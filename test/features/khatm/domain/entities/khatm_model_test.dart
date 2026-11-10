import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/khatm/domain/entities/khatm_model.dart';

void main() {
  final startDate = DateTime(2026, 7);
  final endDate = DateTime(2026, 8);
  final targetDate = DateTime(2026, 12, 31);

  group('KhatmModel', () {
    test('constructor sets required fields', () {
      final khatm = KhatmModel(
        id: '1',
        title: 'Khatm Quran',
        type: KhatmType.quran,
        startDate: startDate,
      );
      expect(khatm.id, '1');
      expect(khatm.title, 'Khatm Quran');
      expect(khatm.type, KhatmType.quran);
      expect(khatm.startDate, startDate);
    });

    test('constructor sets default values', () {
      final khatm = KhatmModel(
        id: '1',
        title: 'Test',
        type: KhatmType.quran,
        startDate: startDate,
      );
      expect(khatm.status, KhatmStatus.pending);
      expect(khatm.totalParts, 30);
      expect(khatm.completedParts, 0);
      expect(khatm.endDate, isNull);
      expect(khatm.targetDate, isNull);
      expect(khatm.participantIds, isEmpty);
      expect(khatm.description, isNull);
      expect(khatm.isPublic, false);
    });

    test('constructor sets custom values', () {
      final khatm = KhatmModel(
        id: '2',
        title: 'Group Khatm',
        type: KhatmType.book,
        status: KhatmStatus.active,
        totalParts: 10,
        completedParts: 3,
        startDate: startDate,
        endDate: endDate,
        targetDate: targetDate,
        participantIds: ['user1', 'user2'],
        description: 'Monthly book study',
        isPublic: true,
      );
      expect(khatm.status, KhatmStatus.active);
      expect(khatm.totalParts, 10);
      expect(khatm.completedParts, 3);
      expect(khatm.endDate, endDate);
      expect(khatm.targetDate, targetDate);
      expect(khatm.participantIds, ['user1', 'user2']);
      expect(khatm.description, 'Monthly book study');
      expect(khatm.isPublic, true);
    });

    group('progress', () {
      test('returns 0 when totalParts is 0', () {
        final khatm = KhatmModel(
          id: '1',
          title: 'Test',
          type: KhatmType.quran,
          totalParts: 0,
          startDate: startDate,
        );
        expect(khatm.progress, 0.0);
      });

      test('returns ratio of completed to total', () {
        final khatm = KhatmModel(
          id: '1',
          title: 'Test',
          type: KhatmType.quran,
          completedParts: 15,
          startDate: startDate,
        );
        expect(khatm.progress, 0.5);
      });

      test('clamps at 1.0', () {
        final khatm = KhatmModel(
          id: '1',
          title: 'Test',
          type: KhatmType.quran,
          completedParts: 40,
          startDate: startDate,
        );
        expect(khatm.progress, 1.0);
      });
    });

    group('copyWith', () {
      test('creates new object with same field values when no args', () {
        final khatm = KhatmModel(
          id: '1',
          title: 'Test',
          type: KhatmType.quran,
          startDate: startDate,
        );
        final copy = khatm.copyWith();
        expect(copy.id, khatm.id);
        expect(copy.title, khatm.title);
      });

      test('replaces status', () {
        final khatm = KhatmModel(
          id: '1',
          title: 'Test',
          type: KhatmType.quran,
          startDate: startDate,
        );
        final copy = khatm.copyWith(status: KhatmStatus.completed);
        expect(copy.status, KhatmStatus.completed);
      });
    });
  });
}

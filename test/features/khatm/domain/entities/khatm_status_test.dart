import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/khatm/data/models/khatm_model.dart';
import 'package:tawheeed/features/khatm/domain/entities/khatm_status.dart';

void main() {
  group('KhatmStatus (derived)', () {
    test('has all four lifecycle values', () {
      expect(KhatmStatus.values.length, 4);
      expect(
          KhatmStatus.values,
          containsAll([
            KhatmStatus.pending,
            KhatmStatus.active,
            KhatmStatus.completed,
            KhatmStatus.cancelled,
          ]));
    });

    test('a khatm with no pages read is pending', () {
      final k = KhatmModel(
          id: 'k1',
          title: 'ختم',
          startDate: DateTime(2026, 9),
          targetDays: 30);
      expect(k.status, KhatmStatus.pending);
      expect(k.statusLabelFa, 'شروع نشده');
    });

    test('reading any page flips the status to active', () {
      final k = KhatmModel(
          id: 'k1',
          title: 'ختم',
          startDate: DateTime(2026, 9),
          targetDays: 30,
          pagesRead: [true, ...List.filled(603, false)]);
      expect(k.status, KhatmStatus.active);
      expect(k.statusLabelFa, 'در جریان');
    });

    test('isCompleted wins over the read-page count', () {
      final k = KhatmModel(
          id: 'k1',
          title: 'ختم',
          startDate: DateTime(2026, 9),
          targetDays: 30,
          isCompleted: true);
      expect(k.status, KhatmStatus.completed);
      expect(k.statusLabelFa, 'تکمیل شده');
    });

    test('cancelled is never derived from stored data', () {
      // Reserved for an explicit abandon flow; the projection must not
      // produce it from isCompleted/pages alone.
      final k = KhatmModel(
          id: 'k1',
          title: 'ختم',
          startDate: DateTime(2026, 9),
          targetDays: 30);
      expect(k.status, isNot(KhatmStatus.cancelled));
    });
  });
}

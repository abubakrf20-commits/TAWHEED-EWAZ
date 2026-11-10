import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/khatm/data/models/khatm_model.dart';

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  KhatmModel fresh({required int targetDays, DateTime? start}) => KhatmModel(
        id: 'k',
        title: 'ختم',
        startDate: start ?? today,
        targetDays: targetDays,
      );

  group('KhatmModel.dailyTarget', () {
    test('spreads all 604 pages over the full target window', () {
      // A khatm started today over 7 days must ask for ceil(604/7), independent
      // of the current clock time — the old `difference().inDays` truncated on
      // the time of day and could silently return ceil(604/6).
      expect(fresh(targetDays: 7).dailyTarget, (604 / 7).ceil());
    });

    test('is stable against a late time-of-day on the start date', () {
      // Regression for the DST / time-of-day truncation: start today at 23:30,
      // one-day target. Counting elapsed hours would give 0 or 1 depending on
      // when the test runs; calendar-day counting always yields 1.
      final start = DateTime(now.year, now.month, now.day, 23, 30);
      expect(fresh(targetDays: 1, start: start).dailyTarget, 604);
    });

    test('never divides by zero once the deadline has passed', () {
      final start = today.subtract(const Duration(days: 10));
      // Deadline 5 days ago → clamps the denominator to 1 → the whole
      // remainder in one day, no NaN/Infinity.
      expect(fresh(targetDays: 5, start: start).dailyTarget, 604);
    });

    test('shrinks as pages are read', () {
      final khatm = fresh(targetDays: 7);
      for (var i = 0; i < 302; i++) {
        khatm.pagesRead[i] = true;
      }
      expect(khatm.remainingPages, 302);
      expect(khatm.dailyTarget, (302 / 7).ceil());
    });
  });
}

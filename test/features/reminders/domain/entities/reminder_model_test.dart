import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/reminders/domain/entities/reminder_model.dart'
    as rm;

void main() {
  group('timeOfDayFa', () {
    test('plain clock time is zero-padded', () {
      expect(rm.timeOfDayFa(hour: 6, minute: 5), '06:05');
      expect(rm.timeOfDayFa(hour: 20, minute: 30), '20:30');
    });

    test('prayer at exact time drops the offset', () {
      expect(
          rm.timeOfDayFa(hour: 12, minute: 0, prayerRef: 'dhuhr'), 'وقت ظهر');
    });

    test('negative offset reads «قبل از»', () {
      expect(
          rm.timeOfDayFa(
              hour: 12,
              minute: 0,
              prayerRef: 'dhuhr',
              prayerOffsetMinutes: -15),
          '15 دقیقه قبل از ظهر');
    });

    test('positive offset reads «بعد از»', () {
      expect(
          rm.timeOfDayFa(
              hour: 17,
              minute: 0,
              prayerRef: 'maghrib',
              prayerOffsetMinutes: 30),
          '30 دقیقه بعد از مغرب');
    });

    test('multiple and unknown refs pass through', () {
      expect(rm.prayerNamesFa('fajr,isha'), 'صبح، عشاء');
      expect(rm.prayerNamesFa('custom'), 'custom');
    });
  });

  group('repeat labels', () {
    test('empty and full week both mean «هر روز»', () {
      expect(rm.repeatSummaryFa([]), 'هر روز');
      expect(rm.repeatSummaryFa([0, 1, 2, 3, 4, 5, 6]), 'هر روز');
      expect(rm.repeatChipFa([]), 'هر روز');
    });

    test('selected days join with Persian separators', () {
      expect(rm.repeatSummaryFa([0, 2, 4]), 'شنبه، دوشنبه، چهارشنبه');
      expect(rm.repeatChipFa([0, 2, 4]), 'ش · د · چ');
    });

    test('legacy out-of-range values fall back to the number', () {
      expect(rm.repeatSummaryFa([7, 9]), '7، 9');
      expect(rm.repeatChipFa([7]), '7');
    });
  });

  group('matchesDay', () {
    // 2026-09-26 is a Saturday (شنبه, Persian index 0).
    final saturday = DateTime(2026, 9, 26);
    final sunday = DateTime(2026, 9, 27);

    test('specific date matches only that calendar day', () {
      expect(
          rm.matchesDay(saturday,
              specificDate: DateTime(2026, 9, 26), daysOfWeek: [1]),
          isTrue);
      expect(
          rm.matchesDay(sunday,
              specificDate: DateTime(2026, 9, 26), daysOfWeek: [1]),
          isFalse);
    });

    test('empty day list matches every day', () {
      expect(rm.matchesDay(sunday, daysOfWeek: []), isTrue);
    });

    test('0 = شنبه convention with legacy 7 normalisation', () {
      expect(rm.matchesDay(saturday, daysOfWeek: [0]), isTrue);
      expect(rm.matchesDay(saturday, daysOfWeek: [7]), isTrue,
          reason: 'legacy rows stored 7 for Saturday');
      expect(rm.matchesDay(sunday, daysOfWeek: [0]), isFalse);
      expect(rm.matchesDay(sunday, daysOfWeek: [1]), isTrue);
    });
  });

  group('recurrenceKindFa', () {
    test('date-bound vs repeating', () {
      expect(
          rm.recurrenceKindFa(specificDate: DateTime(2026, 9, 26)), 'یک‌بار');
      expect(rm.recurrenceKindFa(), 'تکرار');
    });
  });
}

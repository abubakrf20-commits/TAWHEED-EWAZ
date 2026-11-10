import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/shared/services/notification_ids.dart';

/// Guards the reserved notification-ID map: no two ranges may overlap,
/// otherwise one scheduler silently overwrites another's notifications
/// (e.g. custom reminders used to clobber the pre-adhan notices).
void main() {
  // Every individually-allocated id in the registry.
  List<int> singletons() => [
        NotificationIds.fajr,
        NotificationIds.dhuhr,
        NotificationIds.asr,
        NotificationIds.maghrib,
        NotificationIds.isha,
        NotificationIds.morningAzkar,
        NotificationIds.eveningAzkar,
        NotificationIds.duha,
        NotificationIds.tomorrowFajr,
        NotificationIds.tomorrowDhuhr,
        NotificationIds.tomorrowAsr,
        NotificationIds.tomorrowMaghrib,
        NotificationIds.tomorrowIsha,
        NotificationIds.tomorrowDuha,
        NotificationIds.postFajr,
        NotificationIds.postDhuhr,
        NotificationIds.postAsr,
        NotificationIds.postMaghrib,
        NotificationIds.postIsha,
        NotificationIds.manualPostFajr,
        NotificationIds.manualPostDhuhr,
        NotificationIds.manualPostAsr,
        NotificationIds.manualPostMaghrib,
        NotificationIds.manualPostIsha,
        NotificationIds.tomorrowPostFajr,
        NotificationIds.tomorrowPostDhuhr,
        NotificationIds.tomorrowPostAsr,
        NotificationIds.tomorrowPostMaghrib,
        NotificationIds.tomorrowPostIsha,
        NotificationIds.tomorrowMorningAzkar,
        NotificationIds.tomorrowEveningAzkar,
        NotificationIds.preAdhanFajr,
        NotificationIds.preAdhanDhuhr,
        NotificationIds.preAdhanAsr,
        NotificationIds.preAdhanMaghrib,
        NotificationIds.preAdhanIsha,
        NotificationIds.tomorrowPreAdhanFajr,
        NotificationIds.tomorrowPreAdhanDhuhr,
        NotificationIds.tomorrowPreAdhanAsr,
        NotificationIds.tomorrowPreAdhanMaghrib,
        NotificationIds.tomorrowPreAdhanIsha,
        NotificationIds.dayAfterTomorrowPreAdhanFajr,
        NotificationIds.dayAfterTomorrowPreAdhanDhuhr,
        NotificationIds.dayAfterTomorrowPreAdhanAsr,
        NotificationIds.dayAfterTomorrowPreAdhanMaghrib,
        NotificationIds.dayAfterTomorrowPreAdhanIsha,
        NotificationIds.dayAfterTomorrowFajr,
        NotificationIds.dayAfterTomorrowDhuhr,
        NotificationIds.dayAfterTomorrowAsr,
        NotificationIds.dayAfterTomorrowMaghrib,
        NotificationIds.dayAfterTomorrowIsha,
        NotificationIds.dayAfterTomorrowDuha,
        NotificationIds.dayAfterTomorrowPostFajr,
        NotificationIds.dayAfterTomorrowPostDhuhr,
        NotificationIds.dayAfterTomorrowPostAsr,
        NotificationIds.dayAfterTomorrowPostMaghrib,
        NotificationIds.dayAfterTomorrowPostIsha,
        NotificationIds.dayAfterTomorrowMorningAzkar,
        NotificationIds.dayAfterTomorrowEveningAzkar,
        NotificationIds.quranReminder,
        NotificationIds.khatmReminder,
        NotificationIds.dailyVerse,
        NotificationIds.dailyHadith,
        NotificationIds.dailyDua,
        NotificationIds.fridayReminder,
        NotificationIds.fastingMonday,
        NotificationIds.fastingThursday,
        NotificationIds.snooze,
        NotificationIds.testAdhan,
      ];

  // Closed ranges [start, end] claimed by multi-id allocators.
  List<List<int>> ranges() => [
        // Custom user reminders.
        [NotificationIds.customReminderBase, NotificationIds.customReminderMax],
        // Per-day daily-content window: base + day-of-year (1..366).
        [
          NotificationIds.dailyVerseDayBase,
          NotificationIds.dailyVerseDayBase + 366
        ],
        [
          NotificationIds.dailyHadithDayBase,
          NotificationIds.dailyHadithDayBase + 366
        ],
        [
          NotificationIds.dailyDuaDayBase,
          NotificationIds.dailyDuaDayBase + 366
        ],
        // ایام بیض window: base + 0-based day-of-year.
        [
          NotificationIds.ayamAlBidhDayBase,
          NotificationIds.ayamAlBidhDayBase + 366
        ],
        // Islamic events: islamicEventBase .. islamicEventMax.
        [NotificationIds.islamicEventBase, NotificationIds.islamicEventMax],
        // Task due-date reminders: 10000-10999 (TaskReminderScheduler._idBase).
        [10000, 10999],
      ];

  bool inRange(int id, List<int> r) => id >= r[0] && id <= r[1];

  test('singleton ids are unique and clear of every reserved range', () {
    final ids = singletons();
    expect(ids.toSet().length, ids.length,
        reason: 'duplicate singleton notification id');

    for (final id in ids) {
      for (final r in ranges()) {
        expect(inRange(id, r), isFalse,
            reason: 'id $id falls inside reserved range ${r[0]}-${r[1]}');
      }
    }
  });

  test('reserved ranges do not overlap each other', () {
    final rs = ranges();
    for (var i = 0; i < rs.length; i++) {
      for (var j = i + 1; j < rs.length; j++) {
        final overlap = rs[i][0] <= rs[j][1] && rs[j][0] <= rs[i][1];
        expect(overlap, isFalse,
            reason:
                'ranges ${rs[i][0]}-${rs[i][1]} and ${rs[j][0]}-${rs[j][1]} overlap');
      }
    }
  });

  test('custom reminder range is clear of the pre-adhan range 500-524', () {
    expect(
        NotificationIds.customReminderBase <= 524 &&
            NotificationIds.customReminderMax >= 500,
        isFalse,
        reason: 'custom reminders must not touch pre-adhan ids 500-524');
  });
}

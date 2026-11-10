import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/prayer/domain/entities/prayer_tracker_entities.dart';
import 'package:tawheeed/features/prayer/domain/home_day_model.dart';
import 'package:tawheeed/features/prayer/domain/prayer_clock.dart';
import 'package:tawheeed/shared/models/day_time.dart';

import 'package:tawheeed/features/prayer/domain/entities/prayer_info.dart'
    as pi;

pi.PrayerInfo _p(int h, int m) => pi.PrayerInfo(
      name: 'x',
      arabicName: 'x',
      time: DayTime(hour: h, minute: m),
    );

pi.PrayerTimes _times(DateTime day) => pi.PrayerTimes(
      date: day,
      fajr: _p(4, 31),
      shorouq: _p(5, 49),
      duhr: _p(11, 43),
      asr: _p(15, 4),
      maghrib: _p(17, 38),
      isha: _p(18, 49),
    );

void main() {
  final schedule = PrayerSchedule.fromToday(_times(DateTime(2026, 10, 5)));
  final nextFajr = DateTime(2026, 10, 6, 4, 31);

  DateTime t(int h, [int m = 0, int s = 0]) => DateTime(2026, 10, 5, h, m, s);

  HomeDayState stateAt(
    DateTime now, {
    Map<FardhPrayer, PrayerStatus> statuses = const {},
    bool sunriseDone = false,
    bool exempt = false,
  }) {
    final snap = computeSnapshot(schedule, now);
    return homeDayState(
      schedule,
      now,
      snap,
      fardStatuses: statuses,
      sunriseDone: sunriseDone,
      exempt: exempt,
    );
  }

  group('homeDayState — prayer rows', () {
    test('between sunrise and dhuhr NO row is now; dhuhr carries بعدی', () {
      // Bug #7: sunrise is not a prayer window — the card must not pretend
      // طلوع آفتاب is «اکنون» or «تا پایان وقت».
      final st = stateAt(t(9));
      expect(st.openWindow, isNull);
      expect(st.rows.every((r) => r.state != PrayerRowState.now), isTrue);
      expect(st.rowOf(PrayerId.dhuhr).state, PrayerRowState.next);
      expect(st.rowOf(PrayerId.sunrise).state, PrayerRowState.upcoming);
      expect(st.periodLabel, 'اشراق و صبح');
    });

    test('fajr window: fajr row now, dhuhr next', () {
      final st = stateAt(t(5));
      expect(st.openWindow, FardhPrayer.fajr);
      expect(st.rowOf(PrayerId.fajr).state, PrayerRowState.now);
      expect(st.rowOf(PrayerId.dhuhr).state, PrayerRowState.next);
      expect(st.periodLabel, 'فجر');
    });

    test('dhuhr window: dhuhr now, asr next', () {
      final st = stateAt(t(12, 39));
      expect(st.openWindow, FardhPrayer.dhuhr);
      expect(st.rowOf(PrayerId.dhuhr).state, PrayerRowState.now);
      expect(st.rowOf(PrayerId.asr).state, PrayerRowState.next);
      expect(st.periodLabel, 'ظهر');
    });

    test('isha window stays open through the night', () {
      final st = stateAt(t(19, 30));
      expect(st.openWindow, FardhPrayer.isha);
      expect(st.rowOf(PrayerId.isha).state, PrayerRowState.now);
      expect(st.periodLabel, 'عشاء');
    });

    test('done wins over the open window', () {
      final st = stateAt(
        t(12, 39),
        statuses: {FardhPrayer.dhuhr: PrayerStatus.done},
      );
      expect(st.rowOf(PrayerId.dhuhr).state, PrayerRowState.done);
      expect(st.rowOf(PrayerId.dhuhr).checked, isTrue);
      expect(st.openWindow, FardhPrayer.dhuhr);
      expect(st.doneFardhCount, 1);
    });

    test('qada counts as done (the toggle cycle passes through it)', () {
      final st = stateAt(
        t(9),
        statuses: {FardhPrayer.fajr: PrayerStatus.qada},
      );
      expect(st.rowOf(PrayerId.fajr).state, PrayerRowState.done);
      expect(st.rowOf(PrayerId.fajr).checked, isTrue);
      expect(st.doneFardhCount, 1);
    });

    test('missed rows appear only after their window closes', () {
      final st = stateAt(t(20));
      expect(st.missed, {
        FardhPrayer.fajr,
        FardhPrayer.dhuhr,
        FardhPrayer.asr,
        FardhPrayer.maghrib,
      });
      expect(st.rowOf(PrayerId.fajr).state, PrayerRowState.missed);
      // Sunrise is never missed — it is not a prayer.
      expect(st.rowOf(PrayerId.sunrise).state, PrayerRowState.upcoming);
      expect(st.rowOf(PrayerId.isha).state, PrayerRowState.now);
    });

    test('exempt (hayz) days never show missed', () {
      final st = stateAt(t(20), exempt: true);
      expect(st.missed, isEmpty);
      // Tomorrow's fajr is the next adhan, but today's fajr row — long past
      // its window — must not wear the «بعدی» badge.
      expect(st.rowOf(PrayerId.fajr).state, PrayerRowState.upcoming);
      expect(
        st.rows.every((r) => r.state != PrayerRowState.next),
        isTrue,
      );
    });

    test('sunrise check rides on duha, not on the fardh statuses', () {
      final st = stateAt(t(9), sunriseDone: true);
      expect(st.rowOf(PrayerId.sunrise).checked, isTrue);
      expect(st.rowOf(PrayerId.sunrise).state, PrayerRowState.done);
      expect(st.doneFardhCount, 0);
    });

    test('period labels follow the app\'s own mapping', () {
      expect(stateAt(t(1)).periodLabel, 'شب');
      expect(stateAt(t(4, 40)).periodLabel, 'فجر');
      expect(stateAt(t(9)).periodLabel, 'اشراق و صبح');
      expect(stateAt(t(12, 39)).periodLabel, 'ظهر');
      expect(stateAt(t(15, 30)).periodLabel, 'عصر'); // asr is 15:04
      expect(stateAt(t(18)).periodLabel, 'مغرب');
      expect(stateAt(t(19)).periodLabel, 'عشاء');
    });
  });

  group('rawatib windows', () {
    test('the six tracked sunnahs reuse the app\'s fardh windows', () {
      final byId = {
        for (final w in rawatibWindows(schedule.today, nextFajr)) w.id: w,
      };
      final fajr = byId[SunnahPrayer.fajrRawatib];
      expect(fajr?.start, t(4, 31));
      expect(fajr?.end, t(5, 49));
      final dhuhrBefore = byId[SunnahPrayer.dhuhrRawatibBefore];
      expect(dhuhrBefore?.start, t(11, 43));
      expect(dhuhrBefore?.end, t(15, 4));
      final dhuhrAfter = byId[SunnahPrayer.dhuhrRawatibAfter];
      expect(dhuhrAfter?.start, t(11, 43));
      expect(dhuhrAfter?.end, t(15, 4));
      final maghrib = byId[SunnahPrayer.maghribRawatib];
      expect(maghrib?.start, t(17, 38));
      expect(maghrib?.end, t(18, 49));
      // Isha-after ends at the night's midpoint: 17:38 + 10h53m/2.
      final isha = byId[SunnahPrayer.ishaRawatib];
      expect(isha?.start, t(18, 49));
      expect(isha?.end, t(23, 4, 30));
      // وتر stays available until the next fajr (documented default).
      final witr = byId[SunnahPrayer.witr];
      expect(witr?.start, t(18, 49));
      expect(witr?.end, nextFajr);
    });

    test('duha runs 20 minutes after sunrise until dhuhr', () {
      final w = duhaWindow(schedule.today);
      expect(w.start, t(6, 9));
      expect(w.end, t(11, 43));
    });

    test('degenerate spans fall back to the day rollover', () {
      final weird = DayTimes(
        fajr: DateTime(2026, 6, 21, 2),
        sunrise: DateTime(2026, 6, 21, 10),
        dhuhr: DateTime(2026, 6, 21, 10, 10),
        asr: DateTime(2026, 6, 21, 12),
        maghrib: DateTime(2026, 6, 21, 23),
        isha: DateTime(2026, 6, 21, 23, 30),
      );
      final windows = rawatibWindows(weird, DateTime(2026, 6, 21, 22));
      final isha = windows.firstWhere((w) => w.id == SunnahPrayer.ishaRawatib);
      expect(isha.end, DateTime(2026, 6, 22));
    });
  });

  group('azkar timeline', () {
    test('the nine windows are chronological and carry no post-prayer node',
        () {
      final windows =
          azkarTimelineWindows(day: schedule.today, nextFajr: nextFajr);
      expect(windows.map((w) => w.index).toList(), [0, 1, 2, 3, 4, 5, 6, 7, 8]);
      for (var i = 1; i < windows.length; i++) {
        expect(windows[i].start.isAfter(windows[i - 1].start), isTrue);
      }
      expect(windows.first.start, t(3, 31)); // fajr − 1h
      expect(windows.last.end, DateTime(2026, 10, 6, 3, 31)); // next fajr − 1h
    });

    test('active indices keep the old widget\'s exact boundaries', () {
      Set<int> at(DateTime now) => azkarActiveIndices(
            day: schedule.today,
            nextFajr: nextFajr,
            now: now,
          );
      expect(at(t(3)), {8});
      // fajr−1h = 03:31, so 04:00 sits inside the fajr window but after the
      // night wrap's boundary — node 8 is NOT active there.
      expect(at(t(4)), {0, 9});
      expect(at(t(4, 31)), {0, 9}); // exactly at fajr: strict after fails
      expect(at(t(11, 45)), {3, 9});
      expect(at(t(16, 30)), {4, 5, 9});
      expect(at(t(23)), {8});
    });

    test('the fallback maps hour-of-day like the old timer did', () {
      expect(azkarFallbackIndices(4), {0, 9});
      expect(azkarFallbackIndices(7), {1});
      expect(azkarFallbackIndices(10), {2});
      expect(azkarFallbackIndices(13), {3, 9});
      expect(azkarFallbackIndices(1), {8});
      expect(azkarFallbackIndices(21), {7, 9});
    });
  });
}

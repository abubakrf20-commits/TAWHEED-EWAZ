import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/prayer/domain/entities/prayer_info.dart'
    as pi;
import 'package:tawheeed/features/prayer/domain/prayer_clock.dart';
import 'package:tawheeed/shared/models/day_time.dart';

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
  final day = DateTime(2026, 10, 5);
  final schedule = PrayerSchedule.fromToday(_times(day));

  DateTime t(int h, [int m = 0, int s = 0]) => DateTime(2026, 10, 5, h, m, s);

  group('PrayerSchedule.fromToday', () {
    test('builds yesterday/tomorrow from the app\'s computed today', () {
      expect(schedule.yesterday.fajr, DateTime(2026, 10, 4, 4, 31));
      expect(schedule.today.maghrib, DateTime(2026, 10, 5, 17, 38));
      expect(schedule.tomorrow.isha, DateTime(2026, 10, 6, 18, 49));
    });
  });

  group('computeSnapshot', () {
    // The arc is anchored on FAJR: six equal segments
    // fajr→sunrise→dhuhr→asr→maghrib→isha→fajr. Fajr is dot 0 and lights up
    // as soon as its adhan has passed; the far end of the arc is tomorrow's
    // fajr, where the marker has come full circle.

    test('mid-afternoon: next is maghrib, arc in segment 3, sunset phase', () {
      final snap = computeSnapshot(schedule, t(16, 30));
      expect(snap.nextId, PrayerId.maghrib);
      expect(snap.phase, TimePhase.sunset);
      // fajr, shorouq, dhuhr and asr are behind the marker.
      expect(snap.passedDots, 4);
      expect(snap.progress, greaterThan(3 / 6));
      expect(snap.progress, lessThan(4 / 6));
      expect(snap.iqamahTime, isNull);
      expect(snap.nextAdhanTime, DateTime(2026, 10, 5, 17, 38));
    });

    test('just after fajr: the fajr dot is already lit, arc at its start', () {
      final snap = computeSnapshot(schedule, t(4, 40));
      expect(snap.nextId, PrayerId.dhuhr); // sunrise has no adhan
      expect(snap.passedDots, 1); // fajr only
      expect(snap.progress, greaterThan(0));
      expect(snap.progress, lessThan(1 / 6));
      expect(snap.phase, TimePhase.dawn);
    });

    test('after midnight before fajr: PREVIOUS cycle completes at fajr', () {
      // Anchored on yesterday's fajr, so the night reads as the tail of the
      // cycle that started at 04:31 yesterday, not as a brand-new arc.
      final snap = computeSnapshot(schedule, t(1));
      expect(snap.nextId, PrayerId.fajr);
      expect(snap.phase, TimePhase.night);
      expect(snap.passedDots, 6);
      expect(snap.progress, greaterThan(5 / 6));
      expect(snap.progress, lessThan(1));
      // The next adhan is TODAY's fajr, not yesterday's.
      expect(snap.nextAdhanTime, DateTime(2026, 10, 5, 4, 31));
    });

    test('late evening after isha: last segment, creeping to tomorrow fajr',
        () {
      // Isha is the last DOT (5/6); the remaining sixth runs to today's fajr
      // of tomorrow, so the marker is near — but not at — the arc's end.
      final snap = computeSnapshot(schedule, t(20));
      expect(snap.nextId, PrayerId.fajr);
      expect(snap.nextAdhanTime, DateTime(2026, 10, 6, 4, 31));
      expect(snap.progress, greaterThan(5 / 6));
      expect(snap.progress, lessThan(1));
      expect(snap.passedDots, 6);
      expect(snap.phase, TimePhase.night);
    });

    test('between maghrib and isha: arc in segment 4', () {
      final snap = computeSnapshot(schedule, t(18));
      expect(snap.nextId, PrayerId.isha);
      expect(snap.progress, greaterThan(4 / 6));
      expect(snap.progress, lessThan(5 / 6));
      expect(snap.passedDots, 5); // fajr..maghrib
      expect(snap.phase, TimePhase.night);
    });

    test('sunrise is never the next prayer (no adhan)', () {
      final snap = computeSnapshot(schedule, t(5)); // fajr→sunrise gap
      expect(snap.nextId, PrayerId.dhuhr);
      expect(snap.phase, TimePhase.dawn);
    });

    test('positive iqamah offset no longer moves the countdown', () {
      // Regression: the number once equalled time-to-iqama («02:36») while
      // the label named the adhan 2h12m away. Now the countdown always
      // targets the adhan; the iqamah rides along as a separate field.
      final snap = computeSnapshot(
        schedule,
        t(16, 30),
        iqamahOffsets: {PrayerId.maghrib: 20},
      );
      expect(snap.nextId, PrayerId.maghrib);
      expect(snap.nextAdhanTime, DateTime(2026, 10, 5, 17, 38));
      expect(snap.iqamahTime, DateTime(2026, 10, 5, 17, 58));
      expect(
        snap.iqamahTime!.difference(t(16, 30)),
        const Duration(hours: 1, minutes: 28),
      );
      expect(
        snap.nextAdhanTime.difference(t(16, 30)),
        const Duration(hours: 1, minutes: 8),
      );
    });

    test('zero/negative iqamah offsets are ignored', () {
      final snap = computeSnapshot(
        schedule,
        t(16, 30),
        iqamahOffsets: const {PrayerId.maghrib: 0, PrayerId.isha: -5},
      );
      expect(snap.iqamahTime, isNull);
    });

    test('equality is quantized to 1/600 arc steps', () {
      final a = computeSnapshot(schedule, t(16, 30));
      final b = computeSnapshot(
        schedule,
        t(16, 30).add(const Duration(milliseconds: 400)),
      );
      expect(a, equals(b)); // sub-step drift must not rebuild listeners
      final c = computeSnapshot(
        schedule,
        t(16, 30).add(const Duration(minutes: 5)),
      );
      expect(a, isNot(equals(c)));
    });
  });

  group('computeArcState (ten-marker horizon arc)', () {
    // Design fractions: صبح 0 · طلوع 1/6 · ضحی 2/6 · ظهر 3/6 (midpoint) ·
    // عصر 7/12 · مغرب 8/12 · عشاء 9/12 · نیمه‌شب 10/12 · ثلث آخر 11/12 ·
    // صبح بعدی 1.

    test('mid-afternoon: ten markers at the design fractions, maghrib ringed',
        () {
      final arc = computeSnapshot(schedule, t(16, 30)).arc;
      expect(arc.markers.map((m) => m.label).toList(), [
        'صبح',
        'طلوع',
        'ضحی',
        'ظهر',
        'عصر',
        'مغرب',
        'عشاء',
        'نیمه‌شب',
        'ثلث آخر',
        'صبح (فردا)',
      ]);
      expect(arc.markers.map((m) => m.fraction).toList(), [
        0,
        1 / 6,
        2 / 6,
        3 / 6,
        7 / 12,
        8 / 12,
        9 / 12,
        10 / 12,
        11 / 12,
        1
      ]);
      // ظهر sits exactly at the path midpoint; طلوع is a diamond milestone.
      expect(arc.markers[3].fraction, closeTo(0.5, 1e-9));
      expect(arc.markers[3].kind, ArcMarkerKind.prayer);
      expect(arc.markers[1].kind, ArcMarkerKind.derived);
      // 16:30 is between asr (15:04) and maghrib (17:38).
      expect(
          arc.markers.where((m) => m.state == ArcMarkerState.passed).length, 5);
      final ringed =
          arc.markers.singleWhere((m) => m.state == ArcMarkerState.next);
      expect(ringed.label, 'مغرب');
      expect(
          arc.markers.where((m) => m.state == ArcMarkerState.upcoming).length,
          4);
      expect(arc.endTomorrow, isTrue);
    });

    test('the ring lands on the adhan the countdown names, all day long', () {
      // Bug #8 guard: the countdown number, the «بعدی» label and the ringed
      // marker all come from the ONE snapshot, so they cannot disagree.
      for (final h in [0, 1, 3, 4, 5, 7, 10, 12, 14, 16, 18, 19, 21, 23]) {
        for (final m in [0, 17, 31, 43, 49]) {
          final now = t(h, m);
          final snap = computeSnapshot(schedule, now);
          final ringed = snap.arc.markers
              .where((m) => m.state == ArcMarkerState.next)
              .toList();
          expect(ringed.length, 1, reason: 'now=$now');
          final String expected;
          if (snap.nextId == PrayerId.fajr) {
            expected = snap.arc.endTomorrow ? 'صبح (فردا)' : 'صبح';
          } else {
            expected = switch (snap.nextId) {
              PrayerId.dhuhr => 'ظهر',
              PrayerId.asr => 'عصر',
              PrayerId.maghrib => 'مغرب',
              PrayerId.isha => 'عشاء',
              PrayerId.fajr || PrayerId.sunrise => '',
            };
          }
          expect(ringed.single.label, expected, reason: 'now=$now');
        }
      }
    });

    test('before fajr: yesterday\'s cycle completes, end is TODAY\'s fajr', () {
      final arc = computeSnapshot(schedule, t(1)).arc;
      expect(arc.markers.length, 10);
      expect(arc.endTomorrow, isFalse);
      expect(arc.markers.last.label, 'صبح');
      expect(arc.markers.last.isEnd, isTrue);
      // Everything through ثلث آخر (00:53) is behind the marker; the ring
      // sits on the closing fajr — today's 04:31.
      expect(
          arc.markers.where((m) => m.state == ArcMarkerState.passed).length, 9);
      expect(arc.markers.last.state, ArcMarkerState.next);
      expect(arc.nowFraction, greaterThan(11 / 12));
      expect(arc.nowFraction, lessThan(1));
    });

    test('after isha the ring moves to the closing fajr of tomorrow', () {
      final snap = computeSnapshot(schedule, t(20));
      final ringed =
          snap.arc.markers.singleWhere((m) => m.state == ArcMarkerState.next);
      expect(ringed.label, 'صبح (فردا)');
      expect(ringed.isEnd, isTrue);
      expect(snap.nextAdhanTime, DateTime(2026, 10, 6, 4, 31));
    });

    test('exactly at an adhan the marker is passed and the segment starts', () {
      final atFajr = computeSnapshot(schedule, t(4, 31));
      expect(atFajr.arc.markers.first.state, ArcMarkerState.passed);
      expect(atFajr.arc.nowFraction, 0);
      final atDhuhr = computeSnapshot(schedule, t(11, 43));
      expect(atDhuhr.arc.markers[3].state, ArcMarkerState.passed);
      expect(atDhuhr.arc.nowFraction, closeTo(3 / 6, 1e-9));
      final atIsha = computeSnapshot(schedule, t(18, 49));
      expect(atIsha.arc.markers[6].state, ArcMarkerState.passed);
      expect(atIsha.arc.nowFraction, closeTo(9 / 12, 1e-9));
    });

    test('nowFraction is time-linear inside its segment', () {
      // Asr 15:04 → maghrib 17:38 spans 154 min; 16:30 is 86 min in.
      final arc = computeSnapshot(schedule, t(16, 30)).arc;
      expect(arc.nowFraction, closeTo(7 / 12 + (1 / 12) * (86 / 154), 1e-9));
    });

    test('undefined milestones drop out instead of crashing or going NaN', () {
      // Polar day: sunrise + 20 min lands past dhuhr, so ضحی cannot exist.
      DayTimes dt(DateTime d, int fh, int sh, int dh, int ah, int mh, int ih) =>
          DayTimes(
            fajr: DateTime(d.year, d.month, d.day, fh),
            sunrise: DateTime(d.year, d.month, d.day, sh),
            dhuhr: DateTime(d.year, d.month, d.day, dh),
            asr: DateTime(d.year, d.month, d.day, ah),
            maghrib: DateTime(d.year, d.month, d.day, mh),
            isha: DateTime(d.year, d.month, d.day, ih),
          );
      final polar = PrayerSchedule(
        yesterday: dt(DateTime(2026, 6, 20), 2, 10, 10, 12, 14, 15),
        today: dt(DateTime(2026, 6, 21), 2, 10, 10, 12, 14, 15),
        tomorrow: dt(DateTime(2026, 6, 22), 2, 10, 10, 12, 14, 15),
      );
      final arc = computeSnapshot(polar, DateTime(2026, 6, 21, 11)).arc;
      expect(arc.markers.where((m) => m.label == 'ضحی'), isEmpty);
      expect(arc.nowFraction.isFinite, isTrue);
      expect(
          arc.markers.map((m) => m.fraction).every((f) => f.isFinite), isTrue);

      // Broken schedule: tomorrow's fajr before today's maghrib kills the
      // midnight pair and the closing marker; still no crash, no NaN.
      final degenerate = PrayerSchedule(
        yesterday: dt(DateTime(2026, 6, 20), 2, 10, 10, 12, 14, 15),
        today: dt(DateTime(2026, 6, 21), 2, 10, 10, 12, 14, 15),
        tomorrow: DayTimes(
          fajr: DateTime(2026, 6, 21, 13),
          sunrise: DateTime(2026, 6, 22, 10),
          dhuhr: DateTime(2026, 6, 22, 10, 30),
          asr: DateTime(2026, 6, 22, 12),
          maghrib: DateTime(2026, 6, 22, 14),
          isha: DateTime(2026, 6, 22, 15),
        ),
      );
      final broken = computeSnapshot(degenerate, DateTime(2026, 6, 21, 16)).arc;
      expect(broken.markers.where((m) => m.label == 'نیمه‌شب'), isEmpty);
      expect(broken.markers.where((m) => m.label == 'ثلث آخر'), isEmpty);
      expect(broken.nowFraction.isFinite, isTrue);
    });

    test('arc equality is quantized like the snapshot\'s', () {
      final a = computeSnapshot(schedule, t(16, 30)).arc;
      final b = computeSnapshot(
        schedule,
        t(16, 30).add(const Duration(milliseconds: 400)),
      ).arc;
      expect(a, equals(b));
      final c = computeSnapshot(schedule, t(16, 35)).arc;
      expect(a, isNot(equals(c)));
    });
  });
}

// Pure tests for the past-due derivation the prayer tracker card uses
// (item 4 of the عبادات audit): a fardh counts as past its time only after the
// next adhan, a logged prayer is never past-due, and a hayz/nifas day is exempt.
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/prayer/domain/entities/prayer_tracker_entities.dart';
import 'package:tawheeed/features/prayer/domain/prayer_windows.dart';

void main() {
  final today = DateTime(2026, 10, 3);
  final ends = fardhWindowEnds(
    sunrise: DateTime(2026, 10, 3, 6),
    asr: DateTime(2026, 10, 3, 16, 30),
    maghrib: DateTime(2026, 10, 3, 19, 30),
    isha: DateTime(2026, 10, 3, 21),
    today: today,
  );

  Map<FardhPrayer, PrayerStatus> statuses([
    Map<FardhPrayer, PrayerStatus> overrides = const {},
  ]) =>
      {
        for (final p in FardhPrayer.values)
          p: overrides[p] ?? PrayerStatus.pending,
      };

  group('fardhWindowEnds', () {
    test('every window closes at the next adhan', () {
      expect(ends[FardhPrayer.fajr], DateTime(2026, 10, 3, 6));
      expect(ends[FardhPrayer.dhuhr], DateTime(2026, 10, 3, 16, 30));
      expect(ends[FardhPrayer.asr], DateTime(2026, 10, 3, 19, 30));
      expect(ends[FardhPrayer.maghrib], DateTime(2026, 10, 3, 21));
    });

    test('isha closes at the day rollover the tracker uses', () {
      expect(ends[FardhPrayer.isha], DateTime(2026, 10, 4));
    });
  });

  group('prayerWindowBounds', () {
    final bounds = prayerWindowBounds(
      fajr: DateTime(2026, 10, 3, 5),
      sunrise: DateTime(2026, 10, 3, 6),
      dhuhr: DateTime(2026, 10, 3, 12),
      asr: DateTime(2026, 10, 3, 16, 30),
      maghrib: DateTime(2026, 10, 3, 19, 30),
      isha: DateTime(2026, 10, 3, 21),
      today: today,
    );

    test('every window opens at its adhan and closes at the next', () {
      expect(bounds.starts['fajr'], DateTime(2026, 10, 3, 5));
      expect(bounds.ends['fajr'], DateTime(2026, 10, 3, 6));
      expect(bounds.ends['sunrise'], DateTime(2026, 10, 3, 12));
      expect(bounds.ends['dhuhr'], DateTime(2026, 10, 3, 16, 30));
      expect(bounds.ends['asr'], DateTime(2026, 10, 3, 19, 30));
      expect(bounds.ends['maghrib'], DateTime(2026, 10, 3, 21));
      expect(bounds.ends['isha'], DateTime(2026, 10, 4));
    });
  });

  group('relevantRawatib', () {
    test('each fardh window maps to its own rawatib', () {
      expect(relevantRawatib(FardhPrayer.fajr), {SunnahPrayer.fajrRawatib});
      expect(
        relevantRawatib(FardhPrayer.dhuhr),
        {SunnahPrayer.dhuhrRawatibBefore, SunnahPrayer.dhuhrRawatibAfter},
      );
      expect(
        relevantRawatib(FardhPrayer.maghrib),
        {SunnahPrayer.maghribRawatib},
      );
      expect(
        relevantRawatib(FardhPrayer.isha),
        {SunnahPrayer.ishaRawatib, SunnahPrayer.witr},
      );
    });

    test('asr window and unknown stretches map to nothing', () {
      expect(relevantRawatib(FardhPrayer.asr), isEmpty);
      expect(relevantRawatib(null), isEmpty);
    });
  });

  group('fardhPastTheirTime', () {
    test('nothing is past-due before the first boundary', () {
      expect(
        fardhPastTheirTime(
            statuses: statuses(),
            endsAt: ends,
            now: DateTime(2026, 10, 3, 5)),
        isEmpty,
      );
    });

    test('fajr joins the set the moment sunrise arrives, and nothing later',
        () {
      expect(
        fardhPastTheirTime(
            statuses: statuses(),
            endsAt: ends,
            now: DateTime(2026, 10, 3, 6)),
        {FardhPrayer.fajr},
      );
    });

    test('at night the whole day is past-due except isha', () {
      expect(
        fardhPastTheirTime(
            statuses: statuses(),
            endsAt: ends,
            now: DateTime(2026, 10, 3, 22)),
        {
          FardhPrayer.fajr,
          FardhPrayer.dhuhr,
          FardhPrayer.asr,
          FardhPrayer.maghrib,
        },
      );
    });

    test('a logged prayer is never past-due, in done or qada', () {
      expect(
        fardhPastTheirTime(
            statuses: statuses({
              FardhPrayer.fajr: PrayerStatus.done,
              FardhPrayer.dhuhr: PrayerStatus.qada,
            }),
            endsAt: ends,
            now: DateTime(2026, 10, 3, 22)),
        {FardhPrayer.asr, FardhPrayer.maghrib},
      );
    });

    test('a missing status entry is treated as pending', () {
      expect(
        fardhPastTheirTime(
            statuses: const {},
            endsAt: ends,
            now: DateTime(2026, 10, 3, 17)),
        {FardhPrayer.fajr, FardhPrayer.dhuhr},
      );
    });

    test('a stored missed row stays past-due', () {
      expect(
        fardhPastTheirTime(
            statuses: statuses({FardhPrayer.fajr: PrayerStatus.missed}),
            endsAt: ends,
            now: DateTime(2026, 10, 3, 7)),
        {FardhPrayer.fajr},
      );
    });

    test('exempt (hayz/nifas day) suppresses every mark', () {
      expect(
        fardhPastTheirTime(
            statuses: statuses(),
            endsAt: ends,
            now: DateTime(2026, 10, 3, 23),
            exempt: true),
        isEmpty,
      );
    });

    test('a missing boundary is skipped instead of throwing', () {
      expect(
        fardhPastTheirTime(
            statuses: statuses(),
            endsAt: const <FardhPrayer, DateTime>{},
            now: DateTime(2026, 10, 3, 23)),
        isEmpty,
      );
    });
  });

  group('fardhWidgetStatuses', () {
    test('every prayer is pending while its window is open', () {
      expect(
        fardhWidgetStatuses(
            statuses: statuses(),
            endsAt: ends,
            now: DateTime(2026, 10, 3, 5)),
        {for (final p in FardhPrayer.values) p: 'pending'},
      );
    });

    test('done and qada both read as done', () {
      final map = fardhWidgetStatuses(
          statuses: statuses({
            FardhPrayer.fajr: PrayerStatus.done,
            FardhPrayer.dhuhr: PrayerStatus.qada,
          }),
          endsAt: ends,
          now: DateTime(2026, 10, 3, 22));
      expect(map[FardhPrayer.fajr], 'done');
      expect(map[FardhPrayer.dhuhr], 'done');
      expect(map[FardhPrayer.asr], 'missed');
    });

    test('an unlogged closed window reads as missed, a stored missed too', () {
      final map = fardhWidgetStatuses(
          statuses: statuses({FardhPrayer.fajr: PrayerStatus.missed}),
          endsAt: ends,
          now: DateTime(2026, 10, 3, 17));
      expect(map[FardhPrayer.fajr], 'missed');
      expect(map[FardhPrayer.dhuhr], 'missed');
      expect(map[FardhPrayer.asr], 'pending');
      expect(map[FardhPrayer.maghrib], 'pending');
      expect(map[FardhPrayer.isha], 'pending');
    });

    test('exempt suppresses the missed mark but never hides a done one', () {
      final map = fardhWidgetStatuses(
          statuses: statuses({FardhPrayer.fajr: PrayerStatus.done}),
          endsAt: ends,
          now: DateTime(2026, 10, 3, 23),
          exempt: true);
      expect(map[FardhPrayer.fajr], 'done');
      expect(map[FardhPrayer.dhuhr], 'pending');
      expect(map[FardhPrayer.asr], 'pending');
      expect(map[FardhPrayer.maghrib], 'pending');
      expect(map[FardhPrayer.isha], 'pending');
    });

    test('a missing status entry and a missing boundary stay pending', () {
      expect(
        fardhWidgetStatuses(
            statuses: const {},
            endsAt: const <FardhPrayer, DateTime>{},
            now: DateTime(2026, 10, 3, 23)),
        {for (final p in FardhPrayer.values) p: 'pending'},
      );
    });

    test('the ramadan/isha edge: the window closes only at the rollover', () {
      final map = fardhWidgetStatuses(
          statuses: statuses(),
          endsAt: ends,
          now: DateTime(2026, 10, 3, 23, 59, 59));
      expect(map[FardhPrayer.isha], 'pending');
      final nextDay = fardhWidgetStatuses(
          statuses: statuses(),
          endsAt: ends,
          now: DateTime(2026, 10, 4));
      expect(nextDay[FardhPrayer.isha], 'missed');
    });
  });
}

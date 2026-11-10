import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/prayer/domain/entities/prayer_tracker_entities.dart';

void main() {
  group('FardhPrayer enum', () {
    test('has all five daily prayers', () {
      expect(FardhPrayer.values.length, 5);
      expect(
          FardhPrayer.values,
          containsAll([
            FardhPrayer.fajr,
            FardhPrayer.dhuhr,
            FardhPrayer.asr,
            FardhPrayer.maghrib,
            FardhPrayer.isha,
          ]));
    });
  });

  group('SunnahPrayer enum', () {
    test('has all sunnah prayers', () {
      expect(SunnahPrayer.values.length, 6);
      expect(
          SunnahPrayer.values,
          containsAll([
            SunnahPrayer.fajrRawatib,
            SunnahPrayer.dhuhrRawatibBefore,
            SunnahPrayer.dhuhrRawatibAfter,
            SunnahPrayer.maghribRawatib,
            SunnahPrayer.ishaRawatib,
            SunnahPrayer.witr,
          ]));
    });

    test('sunnahPrayerNames has correct length', () {
      expect(sunnahPrayerNames.length, 6);
    });

    test('sunnahPrayerNames contains specific labels', () {
      expect(sunnahPrayerNames[SunnahPrayer.witr], contains('وتر'));
    });
  });

  group('PrayerStatus enum', () {
    test('has all statuses', () {
      expect(PrayerStatus.values.length, 4);
      expect(
          PrayerStatus.values,
          containsAll([
            PrayerStatus.missed,
            PrayerStatus.done,
            PrayerStatus.qada,
            PrayerStatus.pending,
          ]));
    });
  });

  group('FardhRecord', () {
    test('constructor sets fields', () {
      const record = FardhRecord(date: '2026-07-10', status: PrayerStatus.done);
      expect(record.date, '2026-07-10');
      expect(record.status, PrayerStatus.done);
    });
  });
}

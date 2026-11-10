import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/adhkar/domain/entities/prayer_period.dart';

void main() {
  group('PrayerPeriod', () {
    test('has all values', () {
      expect(PrayerPeriod.values.length, 10);
      expect(
          PrayerPeriod.values,
          containsAll([
            PrayerPeriod.fajr,
            PrayerPeriod.shorouq,
            PrayerPeriod.morningAzkar,
            PrayerPeriod.duhr,
            PrayerPeriod.asr,
            PrayerPeriod.maghrib,
            PrayerPeriod.eveningAzkar,
            PrayerPeriod.isha,
            PrayerPeriod.night,
            PrayerPeriod.postPrayer,
          ]));
    });
  });

  group('PrayerPeriodExt', () {
    test('label returns non-empty string for each period', () {
      for (final period in PrayerPeriod.values) {
        expect(period.label, isNotEmpty);
      }
    });

    test('icon returns non-empty string for each period', () {
      for (final period in PrayerPeriod.values) {
        expect(period.icon, isNotEmpty);
      }
    });

    test('fajr label', () {
      expect(PrayerPeriod.fajr.label, contains('فجر'));
    });

    test('morningAzkar label', () {
      expect(PrayerPeriod.morningAzkar.label, contains('صبح'));
    });

    test('night label', () {
      expect(PrayerPeriod.night.label, contains('شب'));
    });

    test('postPrayer label', () {
      expect(PrayerPeriod.postPrayer.label, contains('نماز'));
    });
  });
}

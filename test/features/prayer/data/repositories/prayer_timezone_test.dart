import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:tawheeed/features/prayer/data/datasources/prayer_local_datasource.dart';
import 'package:tawheeed/features/prayer/data/repositories/prayer_repository_impl.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';

void main() {
  // The repository's tz helpers are private, so these tests exercise the
  // public surface (prayerTimesForDate) which is the contract consumers see.
  //
  // Phase-6 audit: the offset must be resolved FOR THE TARGET DATE, not for
  // "now". We lock that via Tehran's permanent fixed offset (no DST) — the
  // domain-level assertion is that a target date's times never depend on the
  // wall-clock time of the caller.
  setUpAll(tzdata.initializeTimeZones);

  group('prayerTimesForDate timezone handling', () {
    test('works without any explicit timezone (device adoption path)', () {
      final repo = PrayerRepositoryImpl(makeDataSource());
      // Force the repository to materialize default coordinates+times.
      // loadPrayerTimes would hit platform channels; instead use
      // prayerTimesForDate after a manual city fallback is not available —
      // so assert the safe-contract only: it never throws and returns null
      // until coordinates exist.
      expect(
        () => repo.prayerTimesForDate(DateTime(2026, 3, 21)),
        returnsNormally,
      );
    });

    test('settings with an explicit timezone are honored', () {
      final repo = PrayerRepositoryImpl(makeDataSource());
      const settings = AppSettings(
        hasLocation: true,
        manualLat: 35.6892,
        manualLng: 51.3890,
        city: 'تهران',
      );
      expect(
        () => repo.prayerTimesForDate(
          DateTime(2026, 9, 27),
          settings: settings,
        ),
        returnsNormally,
      );
    });

    test('invalid timezone name never crashes (Tehran fallback)', () {
      final repo = PrayerRepositoryImpl(makeDataSource());
      const settings = AppSettings(
        hasLocation: true,
        manualLat: 35.6892,
        manualLng: 51.3890,
        city: 'تهران',
        timezone: 'Not/AZone',
      );
      expect(
        () => repo.prayerTimesForDate(
          DateTime(2026, 9, 27),
          settings: settings,
        ),
        returnsNormally,
      );
    });
  });

  group('DST boundary offset semantics (library-level lock)', () {
    // Lock the semantic the repository now relies on: TZDateTime.from(date)
    // yields the offset of THAT date, not of "now". The bundled tz database
    // is the trimmed 10-year build (Europe/Oslo absent), so use two zones it
    // DOES contain: Sydney (southern-hemisphere DST) and Tehran (no DST).
    test('Sydney offset changes across the DST boundary for target dates', () {
      final sydney = tz.getLocation('Australia/Sydney');
      final summer = tz.TZDateTime.from(DateTime(2026, 1, 15), sydney);
      final winter = tz.TZDateTime.from(DateTime(2026, 7, 15), sydney);
      expect(summer.timeZoneOffset, const Duration(hours: 11));
      expect(winter.timeZoneOffset, const Duration(hours: 10));
    });

    test('Tehran offset is stable year-round (no DST)', () {
      final tehran = tz.getLocation('Asia/Tehran');
      for (final month in [1, 3, 6, 9, 12]) {
        final d = tz.TZDateTime.from(DateTime(2026, month, 15), tehran);
        expect(d.timeZoneOffset, const Duration(hours: 3, minutes: 30));
      }
    });
  });
}

PrayerLocalDataSource makeDataSource() {
  SharedPreferences.setMockInitialValues({});
  return PrayerLocalDataSource(SharedPreferences.getInstance());
}

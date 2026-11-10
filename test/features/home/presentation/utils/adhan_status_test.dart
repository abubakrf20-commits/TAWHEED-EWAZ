import 'package:adhan/adhan.dart' as adhan;
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/home/presentation/utils/adhan_status.dart';
import 'package:tawheeed/features/prayer/services/prayer_time_service.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_time_helpers.dart';

import '../../../../core/prayer/fake_prayer_repository.dart';

/// Service whose prayerTimes are computed once for today (Tehran
/// coordinates) so the iqamah windows are deterministic relative to the
/// pinned `now` passed to `currentIqamah`.
class _FakeTimesService extends PrayerTimeService {
  _FakeTimesService() : this._(_pt);

  _FakeTimesService.withTimes(adhan.PrayerTimes times) : this._(times);

  _FakeTimesService._(adhan.PrayerTimes times)
      : super(FakePrayerRepository(times));

  static final adhan.PrayerTimes _pt = () {
    final now = DateTime.now();
    return adhan.PrayerTimes(
      adhan.Coordinates(35.6892, 51.3890),
      adhan.DateComponents(now.year, now.month, now.day),
      adhan.CalculationMethod.muslim_world_league.getParameters(),
    );
  }();
}

void main() {
  // Same default offset the widget/app fall back to (10 minutes).
  const offsets = {
    'فجر': 10,
    'ظهر': 10,
    'عصر': 10,
    'مغرب': 10,
    'عشاء': 10,
  };

  late _FakeTimesService service;

  setUp(() {
    service = _FakeTimesService();
  });

  test('null before the fajr adhan', () {
    final fajr = service.prayerTimes!.fajr;
    expect(
      currentIqamah(
          service, offsets, fajr.subtract(const Duration(minutes: 1))),
      isNull,
    );
  });

  test('returns fajr while inside its iqamah window', () {
    final fajr = service.prayerTimes!.fajr;
    final result =
        currentIqamah(service, offsets, fajr.add(const Duration(minutes: 5)));
    expect(result?.name, 'فجر');
    expect(result?.adhan, fajr);
    expect(result?.iqamah, fajr.add(const Duration(minutes: 10)));
  });

  test('returns null exactly at the iqamah time (matches widget strictness)',
      () {
    final fajr = service.prayerTimes!.fajr;
    // The Android widget switches phase when iqamahMin > nowMin; at exactly
    // the iqamah minute the window is closed — the app must match.
    expect(
      currentIqamah(service, offsets, fajr.add(const Duration(minutes: 10))),
      isNull,
    );
  });

  test('returns null after the iqamah window closed', () {
    final fajr = service.prayerTimes!.fajr;
    expect(
      currentIqamah(service, offsets, fajr.add(const Duration(minutes: 11))),
      isNull,
    );
  });
  test('returns dhuhr inside its own window (later prayer)', () {
    final dhuhr = service.prayerTimes!.dhuhr;
    final result =
        currentIqamah(service, offsets, dhuhr.add(const Duration(minutes: 5)));
    expect(result?.name, 'ظهر');
  });

  test('does not keep Asr active after Maghrib', () {
    final raw = adhan.PrayerTimes(
      adhan.Coordinates(35.6892, 51.3890),
      adhan.DateComponents(2026, 7, 10),
      adhan.CalculationMethod.muslim_world_league.getParameters(),
      utcOffset: const Duration(hours: 3, minutes: 30),
    );
    final service = _FakeTimesService.withTimes(raw);
    final result = currentIqamah(
      service,
      {for (final name in prayerNameOrder) name: 240},
      wallClockTime(raw.maghrib).add(const Duration(minutes: 5)),
    );
    expect(result?.name, 'مغرب');
  });
}

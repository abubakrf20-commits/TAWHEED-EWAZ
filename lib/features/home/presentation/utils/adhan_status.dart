import 'package:tawheeed/features/prayer/services/prayer_time_service.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_time_helpers.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';

/// Pure, unit-testable prayer-status helpers for the home hero card.
///
/// Unlike the `PrayerTimesX` extension (which reads `DateTime.now()`), every
/// function here takes an explicit [now] so widgets can compute state from
/// their own clock and tests can pin exact instants.

/// Short names in iqamah lookup order (adhan time → iqamah window).
const prayerNameOrder = ['فجر', 'ظهر', 'عصر', 'مغرب', 'عشاء'];

/// The service reports names like "اذان صبح"; icon/color helpers expect the
/// short names ("فجر"), so normalize before lookup while keeping the
/// user-facing label untouched.
String normalizePrayerName(String name) => switch (name) {
      'اذان صبح' => 'فجر',
      'اذان ظهر' => 'ظهر',
      'اذان عصر' => 'عصر',
      'اذان مغرب' => 'مغرب',
      'اذان عشاء' => 'عشاء',
      _ => name,
    };

Map<String, int> computeIqamahOffsets(AppSettings settings) => {
      'فجر': settings.iqamahOffsetFajr,
      'ظهر': settings.iqamahOffsetDhuhr,
      'عصر': settings.iqamahOffsetAsr,
      'مغرب': settings.iqamahOffsetMaghrib,
      'عشاء': settings.iqamahOffsetIsha,
    };

DateTime? prayerTimeByName(PrayerTimeService service, String name) {
  final pt = service.prayerTimes;
  if (pt == null) return null;
  switch (name) {
    case 'فجر':
      return wallClockTime(pt.fajr);
    case 'ظهر':
      return wallClockTime(pt.dhuhr);
    case 'عصر':
      return wallClockTime(pt.asr);
    case 'مغرب':
      return wallClockTime(pt.maghrib);
    case 'عشاء':
      return wallClockTime(pt.isha);
    default:
      return null;
  }
}

/// Find the current prayer in its iqamah window [adhan, adhan + offset).
/// Returns (prayerName, adhanTime, iqamahTime) or null.
({String name, DateTime adhan, DateTime iqamah})? currentIqamah(
    PrayerTimeService service, Map<String, int> offsets, DateTime now) {
  for (var i = 0; i < prayerNameOrder.length; i++) {
    final name = prayerNameOrder[i];
    final t = prayerTimeByName(service, name);
    if (t == null) continue;
    final configuredIqamah = t.add(Duration(minutes: offsets[name] ?? 10));
    final nextAdhan = i + 1 < prayerNameOrder.length
        ? prayerTimeByName(service, prayerNameOrder[i + 1])
        : null;
    final iqamah = nextAdhan != null && configuredIqamah.isAfter(nextAdhan)
        ? nextAdhan
        : configuredIqamah;
    if (!now.isBefore(t) && now.isBefore(iqamah)) {
      return (name: name, adhan: t, iqamah: iqamah);
    }
  }
  return null;
}

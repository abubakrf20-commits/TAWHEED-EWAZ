import 'package:tawheeed/features/prayer/domain/entities/prayer_tracker_entities.dart';

/// When each fardh time window closes, from the day's own prayer times.
///
/// Every window ends with the next adhan (fajr → sunrise, dhuhr → asr,
/// asr → maghrib, maghrib → isha). Isha has no following adhan in the same
/// day, so it closes at the day rollover — the same instant the tracker's
/// `date` key moves on, which keeps «عشاء امروز» honest instead of letting an
/// unlogged isha stay pending forever.
Map<FardhPrayer, DateTime> fardhWindowEnds({
  required DateTime sunrise,
  required DateTime asr,
  required DateTime maghrib,
  required DateTime isha,
  required DateTime today,
}) =>
    {
      FardhPrayer.fajr: sunrise,
      FardhPrayer.dhuhr: asr,
      FardhPrayer.asr: maghrib,
      FardhPrayer.maghrib: isha,
      FardhPrayer.isha: DateTime(today.year, today.month, today.day)
          .add(const Duration(days: 1)),
    };

/// Fardh prayers whose time has passed while they were never logged.
///
/// Derived at read time and deliberately NOT written to the tracker table:
/// an unlogged row can mean «prayed, forgot to tick», and a stored `missed`
/// would contradict the user forever. `exempt` (hayz/nifas day) suppresses the
/// mark because prayer is not obligatory there.
Set<FardhPrayer> fardhPastTheirTime({
  required Map<FardhPrayer, PrayerStatus> statuses,
  required Map<FardhPrayer, DateTime> endsAt,
  required DateTime now,
  bool exempt = false,
}) {
  if (exempt) return const {};
  final past = <FardhPrayer>{};
  for (final prayer in FardhPrayer.values) {
    final end = endsAt[prayer];
    if (end == null || now.isBefore(end)) continue;
    final status = statuses[prayer] ?? PrayerStatus.pending;
    if (status == PrayerStatus.pending || status == PrayerStatus.missed) {
      past.add(prayer);
    }
  }
  return past;
}

/// Per-prayer status as the home-screen widgets print it: "done" when the
/// prayer was logged (done or qada), "missed" when its window closed with
/// nothing logged, "pending" otherwise.
///
/// Single source for the native prayer widget and its settings preview, so the
/// two can never mark the same day differently.
Map<FardhPrayer, String> fardhWidgetStatuses({
  required Map<FardhPrayer, PrayerStatus> statuses,
  required Map<FardhPrayer, DateTime> endsAt,
  required DateTime now,
  bool exempt = false,
}) {
  final missed = fardhPastTheirTime(
    statuses: statuses,
    endsAt: endsAt,
    now: now,
    exempt: exempt,
  );
  return {
    for (final prayer in FardhPrayer.values)
      prayer: missed.contains(prayer)
          ? 'missed'
          : switch (statuses[prayer]) {
              PrayerStatus.done || PrayerStatus.qada => 'done',
              _ => 'pending',
            },
  };
}

/// Window bounds per english key (`fajr`, `sunrise`, …) for the CURRENT-row
/// displays (progress line, «تا پایان وقت», rawatib «تا …»).
///
/// Same rule as [fardhWindowEnds]: every window opens at its adhan and
/// closes at the next adhan, with isha closing at the day rollover. One
/// function so the prayer card and the rawatib card can never disagree.
({Map<String, DateTime> starts, Map<String, DateTime> ends}) prayerWindowBounds({
  required DateTime fajr,
  required DateTime sunrise,
  required DateTime dhuhr,
  required DateTime asr,
  required DateTime maghrib,
  required DateTime isha,
  required DateTime today,
}) {
  final starts = {
    'fajr': fajr,
    'sunrise': sunrise,
    'dhuhr': dhuhr,
    'asr': asr,
    'maghrib': maghrib,
    'isha': isha,
  };
  final midnight =
      DateTime(today.year, today.month, today.day).add(const Duration(days: 1));
  final ends = {
    'fajr': sunrise,
    'sunrise': dhuhr,
    'dhuhr': asr,
    'asr': maghrib,
    'maghrib': isha,
    'isha': midnight,
  };
  return (starts: starts, ends: ends);
}

/// Rawatib whose window is open right now, from the currently-open fardh
/// window (null = sunrise/night stretch or unknown).
///
/// Single source for the rawatib card's gold highlighting. Note the asr
/// window maps to nothing — the tracked sunnahs attach to fajr, dhuhr,
/// maghrib and isha only.
Set<SunnahPrayer> relevantRawatib(FardhPrayer? current) => switch (current) {
      FardhPrayer.fajr => {SunnahPrayer.fajrRawatib},
      FardhPrayer.dhuhr => {
          SunnahPrayer.dhuhrRawatibBefore,
          SunnahPrayer.dhuhrRawatibAfter
        },
      FardhPrayer.maghrib => {SunnahPrayer.maghribRawatib},
      FardhPrayer.isha => {SunnahPrayer.ishaRawatib, SunnahPrayer.witr},
      _ => const {},
    };

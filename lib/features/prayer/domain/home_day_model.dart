import 'package:flutter/foundation.dart';

import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/prayer/domain/entities/prayer_tracker_entities.dart';
import 'package:tawheeed/features/prayer/domain/prayer_clock.dart';
import 'package:tawheeed/features/prayer/domain/prayer_windows.dart';

/// ═══════════════════════════════════════════════════════════════
/// Home day-state — the presentation-agnostic part of the redesigned
/// home page, next to [computeSnapshot] so every card reads the same
/// moment the same way.
///
/// What the snapshot already owns (next adhan, arc, phase) is consumed,
/// not recomputed: [homeDayState] takes the [PrayerSnapshot] so the
/// «بعدی» badge can never disagree with the hero countdown. What it adds
/// is the tracker-aware layer: which fardh window is open, which rows
/// are done/missed, the app's own period label, and the rawatib/adhkar
/// windows.
/// ═══════════════════════════════════════════════════════════════

/// Visual state of one row on the prayer-times card.
enum PrayerRowState {
  /// Its window is open right now (gold gradient + «اکنون»).
  now,

  /// The next adhan the countdown targets (dashed gold + «بعدی»).
  next,

  /// Logged done in the tracker (green filled + check).
  done,

  /// Window closed unlogged (dashed neutral). Never for sunrise.
  missed,

  /// Not yet due.
  upcoming,
}

@immutable
class PrayerRow {
  const PrayerRow({
    required this.id,
    required this.time,
    required this.state,
    required this.checked,
  });

  final PrayerId id;
  final DateTime time;
  final PrayerRowState state;

  /// Whether the row's checkbox is ticked (fardh done / duha done).
  final bool checked;
}

@immutable
class HomeDayState {
  const HomeDayState({
    required this.phase,
    required this.periodLabel,
    required this.nextId,
    required this.openWindow,
    required this.rows,
    required this.done,
    required this.missed,
    required this.doneFardhCount,
    required this.exempt,
  });

  final TimePhase phase;

  /// The app's own period label (شب/فجر/اشراق و صبح/ظهر/عصر/مغرب/عشاء) —
  /// the same strings the prayer screen's `currentPeriodLabel` extension
  /// produces, reproduced purely so the phase chip can show the period
  /// NAME in the sunrise→dhuhr stretch instead of a fake «اکنون».
  final String periodLabel;

  /// The prayer the hero countdown targets (from the snapshot).
  final PrayerId nextId;

  /// The fardh whose time window is open, or null in the sunrise→dhuhr
  /// stretch (sunrise is NOT a prayer window — bug #7) and after the
  /// day rollover.
  final FardhPrayer? openWindow;

  /// The six card rows, fajr…isha in display order.
  final List<PrayerRow> rows;

  final Set<FardhPrayer> done;
  final Set<FardhPrayer> missed;
  final int doneFardhCount;

  /// Prayer is not obligatory today (hayz/nifas) — the card shows the
  /// banner and no row can read «فاته».
  final bool exempt;

  PrayerRow rowOf(PrayerId id) => rows.firstWhere((r) => r.id == id);
}

/// Pure day-state for one moment. [snap] must come from the same
/// [computeSnapshot] call the hero uses (same schedule, same [now]).
HomeDayState homeDayState(
  PrayerSchedule s,
  DateTime now,
  PrayerSnapshot snap, {
  Map<FardhPrayer, PrayerStatus> fardStatuses = const {},
  bool sunriseDone = false,
  bool exempt = false,
}) {
  final day = s.today;
  final ends = fardhWindowEnds(
    sunrise: day.sunrise,
    asr: day.asr,
    maghrib: day.maghrib,
    isha: day.isha,
    today: now,
  );
  final open = _openWindow(day, now, ends);
  final missed = fardhPastTheirTime(
    statuses: fardStatuses,
    endsAt: ends,
    now: now,
    exempt: exempt,
  );
  // Qada counts as done: the tracker's toggle cycle is pending → done →
  // qada → pending, and the old card showed a qada-marked row ticked.
  final done = {
    for (final p in FardhPrayer.values)
      if (fardStatuses[p] == PrayerStatus.done ||
          fardStatuses[p] == PrayerStatus.qada)
        p,
  };

  PrayerRow buildRow(PrayerId id) {
    final fardh = _fardhOf(id);
    final time = day.of(id);
    final PrayerRowState state;
    final bool checked;
    if (fardh == null) {
      // Sunrise: not a prayer, never «اکنون»/«بعدی»/missed — only the
      // optional duha check mark.
      checked = sunriseDone;
      state = sunriseDone ? PrayerRowState.done : PrayerRowState.upcoming;
    } else {
      checked = done.contains(fardh);
      // «بعدی» targets the same ABSOLUTE instant as the hero countdown —
      // after isha (next adhan = tomorrow's fajr) today's rows earn no
      // badge, and a tomorrow-fajr never lights up today's fajr row.
      state = done.contains(fardh)
          ? PrayerRowState.done
          : missed.contains(fardh)
              ? PrayerRowState.missed
              : open == fardh
                  ? PrayerRowState.now
                  : snap.nextAdhanTime == time
                      ? PrayerRowState.next
                      : PrayerRowState.upcoming;
    }
    return PrayerRow(id: id, time: time, state: state, checked: checked);
  }

  final rows = [for (final id in PrayerId.values) buildRow(id)];

  return HomeDayState(
    phase: snap.phase,
    periodLabel: _periodLabel(day, now),
    nextId: snap.nextId,
    openWindow: open,
    rows: rows,
    done: done,
    missed: missed,
    doneFardhCount: done.length,
    exempt: exempt,
  );
}

/// Null for sunrise — it is not a fardh and has no tracker status.
FardhPrayer? _fardhOf(PrayerId id) => switch (id) {
      PrayerId.fajr => FardhPrayer.fajr,
      PrayerId.dhuhr => FardhPrayer.dhuhr,
      PrayerId.asr => FardhPrayer.asr,
      PrayerId.maghrib => FardhPrayer.maghrib,
      PrayerId.isha => FardhPrayer.isha,
      PrayerId.sunrise => null,
    };

FardhPrayer? _openWindow(
  DayTimes day,
  DateTime now,
  Map<FardhPrayer, DateTime> ends,
) {
  bool open(FardhPrayer p, DateTime start) {
    final end = ends[p];
    return end != null && !now.isBefore(start) && now.isBefore(end);
  }

  if (open(FardhPrayer.fajr, day.fajr)) return FardhPrayer.fajr;
  if (open(FardhPrayer.dhuhr, day.dhuhr)) return FardhPrayer.dhuhr;
  if (open(FardhPrayer.asr, day.asr)) return FardhPrayer.asr;
  if (open(FardhPrayer.maghrib, day.maghrib)) return FardhPrayer.maghrib;
  if (open(FardhPrayer.isha, day.isha)) return FardhPrayer.isha;
  return null;
}

/// The app's period labels, exactly as the prayer screen's
/// `currentPeriodLabel` extension produces them (prayer_time_helpers.dart),
/// but pure: schedule times in, label out.
String _periodLabel(DayTimes day, DateTime now) {
  if (now.isBefore(day.fajr)) return 'شب';
  if (now.isBefore(day.sunrise)) return 'فجر';
  if (now.isBefore(day.dhuhr)) return 'اشراق و صبح';
  if (now.isBefore(day.asr)) return 'ظهر';
  if (now.isBefore(day.maghrib)) return 'عصر';
  if (now.isBefore(day.isha)) return 'مغرب';
  return 'عشاء';
}

// ───────────────────────── rawatib windows ─────────────────────────

@immutable
class RawatibWindow {
  const RawatibWindow(
      {required this.id, required this.start, required this.end});

  final SunnahPrayer id;
  final DateTime start;
  final DateTime end;

  bool contains(DateTime now) => !now.isBefore(start) && now.isBefore(end);
}

/// The tracked sunnahs' time windows, one per [SunnahPrayer].
///
/// The rawatib windows reuse the app's fardh windows (every window opens
/// at its adhan and closes at the next): fajr-before runs fajr→sunrise,
/// both dhuhr rawatibs run dhuhr→asr, maghrib-after runs maghrib→isha.
/// Where the app has no stored definition the documented defaults are:
/// isha-after ends at the night's midpoint (the SunnahTimes midnight the
/// qiyam features use) and وتر stays available until the next fajr.
List<RawatibWindow> rawatibWindows(DayTimes day, DateTime nextFajr) {
  final midnight = midnightBetween(day.maghrib, nextFajr) ??
      DateTime(day.fajr.year, day.fajr.month, day.fajr.day)
          .add(const Duration(days: 1));
  return [
    RawatibWindow(
      id: SunnahPrayer.fajrRawatib,
      start: day.fajr,
      end: day.sunrise,
    ),
    RawatibWindow(
      id: SunnahPrayer.dhuhrRawatibBefore,
      start: day.dhuhr,
      end: day.asr,
    ),
    RawatibWindow(
      id: SunnahPrayer.dhuhrRawatibAfter,
      start: day.dhuhr,
      end: day.asr,
    ),
    RawatibWindow(
      id: SunnahPrayer.maghribRawatib,
      start: day.maghrib,
      end: day.isha,
    ),
    RawatibWindow(id: SunnahPrayer.ishaRawatib, start: day.isha, end: midnight),
    RawatibWindow(id: SunnahPrayer.witr, start: day.isha, end: nextFajr),
  ];
}

/// Duha (the 7th rawatib box, tracked separately from [SunnahPrayer]):
/// from 20 minutes after sunrise until dhuhr — the app's own duha
/// convention (quick_reminders.dart).
({DateTime start, DateTime end}) duhaWindow(DayTimes day) =>
    (start: duhaStart(day.sunrise), end: day.dhuhr);

// ───────────────────────── adhkar timeline ─────────────────────────

@immutable
class AzkarWindow {
  const AzkarWindow(
      {required this.index, required this.start, required this.end});

  /// The adhkar-category index (0..9) this window belongs to. Index 9
  /// (post-prayer) rides along with the prayer windows and has no window
  /// of its own, so it never appears here.
  final int index;
  final DateTime start;
  final DateTime end;

  bool contains(DateTime now) => !now.isBefore(start) && now.isBefore(end);
}

/// The nine adhkar windows in chronological order — the actions-timeline
/// card's events. A window whose end does not lie after its start (polar
/// day, broken schedule) is dropped, mirroring the arc's policy for
/// undefined milestones: hide it, never crash or go NaN.
List<AzkarWindow> azkarTimelineWindows({
  required DayTimes day,
  required DateTime nextFajr,
}) {
  final fajr = day.fajr;
  final sunrise = day.sunrise;
  final dhuhr = day.dhuhr;
  final asr = day.asr;
  final maghrib = day.maghrib;
  final isha = day.isha;
  const oneHour = Duration(hours: 1);
  const twoHours = Duration(hours: 2);
  final elevenAM = DateTime(fajr.year, fajr.month, fajr.day, 11);

  final windows = [
    (0, fajr.subtract(oneHour), fajr.add(oneHour)),
    (1, fajr, dhuhr),
    (2, sunrise, elevenAM),
    (3, dhuhr, dhuhr.add(twoHours)),
    (4, dhuhr.add(twoHours), asr.add(twoHours)),
    (5, asr.add(oneHour), maghrib.add(oneHour)),
    (6, maghrib.add(oneHour), isha),
    (7, isha, isha.add(oneHour)),
    (8, isha.add(oneHour), nextFajr.subtract(oneHour)),
  ];
  return [
    for (final (index, start, end) in windows)
      if (end.isAfter(start)) AzkarWindow(index: index, start: start, end: end),
  ];
}

/// Which adhkar categories are active at [now] — a pure port of the old
/// `DailyAdhkarBox._getActiveIndices` / `_fallbackByHour`, keeping their
/// exact boundaries (strict comparisons on both sides, the node-8
/// midnight wrap, the node-9 ride-along with {0,3,4,5,7} and the
/// always-something fallback) so behaviour cannot drift.
///
/// [fallbackHour] is the hour-of-day used when the prayer times are
/// unusable (the old widget's timer-cached `_currentHour`).
Set<int> azkarActiveIndices({
  required DayTimes day,
  required DateTime nextFajr,
  required DateTime now,
  int fallbackHour = 0,
}) {
  final fajr = day.fajr;
  final sunrise = day.sunrise;
  final dhuhr = day.dhuhr;
  final asr = day.asr;
  final maghrib = day.maghrib;
  final isha = day.isha;
  const oneHour = Duration(hours: 1);
  const twoHours = Duration(hours: 2);
  final elevenAM = DateTime(now.year, now.month, now.day, 11);

  if (fajr.isAfter(sunrise) ||
      sunrise.isAfter(dhuhr) ||
      dhuhr.isAfter(asr) ||
      asr.isAfter(maghrib) ||
      maghrib.isAfter(isha)) {
    return azkarFallbackIndices(fallbackHour);
  }

  final active = <int>{};
  if (now.isAfter(fajr.subtract(oneHour)) && now.isBefore(fajr.add(oneHour))) {
    active.add(0);
  }
  if (now.isAfter(fajr) && now.isBefore(dhuhr)) active.add(1);
  if (now.isAfter(sunrise) && now.isBefore(elevenAM)) active.add(2);
  if (now.isAfter(dhuhr) && now.isBefore(dhuhr.add(twoHours))) active.add(3);
  if (now.isAfter(dhuhr.add(twoHours)) && now.isBefore(asr.add(twoHours))) {
    active.add(4);
  }
  if (now.isAfter(asr.add(oneHour)) && now.isBefore(maghrib.add(oneHour))) {
    active.add(5);
  }
  if (now.isAfter(maghrib.add(oneHour)) && now.isBefore(isha)) active.add(6);
  if (now.isAfter(isha) && now.isBefore(isha.add(oneHour))) active.add(7);
  if (now.isAfter(isha.add(oneHour)) || now.isBefore(fajr.subtract(oneHour))) {
    active.add(8);
  }

  // Post-prayer is active alongside any prayer period.
  if (active.intersection({0, 3, 4, 5, 7}).isNotEmpty) active.add(9);

  if (active.isEmpty) active.add(8);
  return active;
}

Set<int> azkarFallbackIndices(int hour) {
  final active = <int>{};
  if (hour >= 3 && hour < 6) active.addAll({0, 9});
  if (hour >= 6 && hour < 9) active.add(1);
  if (hour >= 9 && hour < 12) active.add(2);
  if (hour >= 12 && hour < 14) active.addAll({3, 9});
  if (hour >= 14 && hour < 16) active.addAll({4, 9});
  if (hour >= 16 && hour < 18) active.addAll({5, 9});
  if (hour >= 18 && hour < 20) active.add(6);
  if (hour >= 20 && hour < 22) active.addAll({7, 9});
  if (active.isEmpty) active.add(8);
  return active;
}

import 'package:flutter/foundation.dart';

import 'package:tawheeed/core/services/clock_ticker.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/prayer/domain/entities/prayer_info.dart'
    as pi;
import 'package:tawheeed/shared/models/day_time.dart';

/// ═══════════════════════════════════════════════════════════════
/// Prayer-clock engine (2026 redesign) — pure logic, ported from the
/// design package and adapted to the app's [pi.PrayerTimes] data.
///
/// The arc runs from the most recent fajr adhan to the next one in six
/// equal segments (fajr→shorouq→dhuhr→asr→maghrib→isha→fajr, fajr being the
/// arc's first dot); sunrise never counts as the "next prayer" because it
/// has no adhan.
/// [computeSnapshot] is pure and unit-tested; [PrayerClock] only wraps
/// it on top of the shared [ClockTicker].
/// ═══════════════════════════════════════════════════════════════

enum PrayerId { fajr, sunrise, dhuhr, asr, maghrib, isha }

extension PrayerIdX on PrayerId {
  String get label => switch (this) {
        PrayerId.fajr => 'اذان صبح',
        PrayerId.sunrise => 'طلوع آفتاب',
        PrayerId.dhuhr => 'اذان ظهر',
        PrayerId.asr => 'اذان عصر',
        PrayerId.maghrib => 'اذان مغرب',
        PrayerId.isha => 'اذان عشاء',
      };

  /// Sunrise has no adhan and never counts as the next prayer.
  bool get isAdhan => this != PrayerId.sunrise;
}

/// One calendar day's times as full DateTimes.
@immutable
class DayTimes {
  const DayTimes({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });

  final DateTime fajr, sunrise, dhuhr, asr, maghrib, isha;

  DateTime of(PrayerId id) => switch (id) {
        PrayerId.fajr => fajr,
        PrayerId.sunrise => sunrise,
        PrayerId.dhuhr => dhuhr,
        PrayerId.asr => asr,
        PrayerId.maghrib => maghrib,
        PrayerId.isha => isha,
      };
}

/// Yesterday + today + tomorrow: the arc crosses midnight, so the engine
/// needs the surrounding days too. [PrayerSchedule.fromToday] reuses the
/// app's computed today for the neighbours (drift ≈ 1–2 min/day — far
/// below visual resolution on the arc; an exact per-day recompute can
/// slot into this factory later without touching the engine).
@immutable
class PrayerSchedule {
  const PrayerSchedule({
    required this.yesterday,
    required this.today,
    required this.tomorrow,
  });

  final DayTimes yesterday, today, tomorrow;

  factory PrayerSchedule.fromToday(pi.PrayerTimes t) {
    DayTimes dayOf(DateTime d) => DayTimes(
          fajr: _at(d, t.fajr.time),
          sunrise: _at(d, t.shorouq.time),
          dhuhr: _at(d, t.duhr.time),
          asr: _at(d, t.asr.time),
          maghrib: _at(d, t.maghrib.time),
          isha: _at(d, t.isha.time),
        );
    final d = DateTime(t.date.year, t.date.month, t.date.day);
    return PrayerSchedule(
      yesterday: dayOf(d.subtract(const Duration(days: 1))),
      today: dayOf(d),
      tomorrow: dayOf(d.add(const Duration(days: 1))),
    );
  }

  static DateTime _at(DateTime day, DayTime time) =>
      DateTime(day.year, day.month, day.day, time.hour, time.minute);
}

/// The moment's state. Deliberately quantized: [progress] is compared in
/// 1/600 steps so listeners do not rebuild every second — only when
/// something meaningful (next prayer, dot, phase, ~2.4 min of arc) changes.
@immutable
class PrayerSnapshot {
  const PrayerSnapshot({
    required this.nextId,
    required this.nextAdhanTime,
    required this.iqamahTime,
    required this.progress,
    required this.passedDots,
    required this.phase,
    required this.arc,
  });

  final PrayerId nextId;

  /// Raw adhan time of the next prayer (tomorrow's fajr after midnight).
  ///
  /// This is the ONLY countdown target: the hero number always shows the
  /// time remaining to the adhan named in the label, never to the iqamah
  /// (that was the old «02:36 while adhan is 2h12m away» bug).
  final DateTime nextAdhanTime;

  /// Absolute iqamah time when the user configured a positive offset for
  /// the next prayer, else null (iqamah pill hidden). Shown separately —
  /// it must never feed the countdown above.
  final DateTime? iqamahTime;

  /// 0..1 along the isha→isha arc (six equal segments).
  final double progress;

  /// How many of the arc's six dots are behind the marker — dots ordered
  /// fajr, shorouq, dhuhr, asr, maghrib, isha (0..6).
  final int passedDots;
  final TimePhase phase;

  /// The ten-marker horizon arc (صبح … صبح بعدی) derived from the same
  /// schedule and instant — the hero painter's single input. Living on the
  /// snapshot is what makes the countdown, the arc and every badge on the
  /// page agree by construction.
  final ArcState arc;

  int get _q => (progress * 600).round();

  @override
  bool operator ==(Object other) =>
      other is PrayerSnapshot &&
      other.nextId == nextId &&
      other.nextAdhanTime == nextAdhanTime &&
      other.iqamahTime == iqamahTime &&
      other.passedDots == passedDots &&
      other.phase == phase &&
      other.arc == arc &&
      other._q == _q;

  @override
  int get hashCode => Object.hash(
      nextId, nextAdhanTime, iqamahTime, passedDots, phase, arc, _q);
}

/// Pure snapshot computation for one moment in time.
PrayerSnapshot computeSnapshot(
  PrayerSchedule s,
  DateTime now, {
  Map<PrayerId, int> iqamahOffsets = const {},
}) {
  final ev = <({PrayerId id, DateTime t})>[
    for (final d in [s.yesterday, s.today, s.tomorrow])
      for (final id in PrayerId.values) (id: id, t: d.of(id)),
  ];

  // Last event already past.
  var last = 0;
  for (var i = 0; i < ev.length; i++) {
    if (!ev[i].t.isAfter(now)) last = i;
  }

  // Next prayer — sunrise is skipped (no adhan).
  var next = ev.length - 1;
  for (var i = last + 1; i < ev.length; i++) {
    if (ev[i].id.isAdhan) {
      next = i;
      break;
    }
  }

  // The arc runs from the MOST RECENT fajr adhan (its left anchor) to the
  // NEXT fajr adhan, in six equal segments fajr→sunrise→dhuhr→asr→maghrib→
  // isha→fajr, so the sweep reads like the sun itself: dawn at the left end,
  // night closing back on dawn. Before today's fajr the anchor is
  // YESTERDAY's fajr, so the previous cycle is shown completing rather than
  // resetting at midnight (the reset happens at the adhan, as it should).
  // Event layout: [0..5] yesterday, [6..11] today, [12..17] tomorrow, ids in
  // PrayerId order, so fajr sits at indices 0, 6 and 12.
  final arcStart = last >= 6 ? 6 : 0;
  final arcEnd = arcStart + 6;

  var progress = 0.0;
  var passed = 0;
  if (last >= arcEnd) {
    progress = 1.0;
    passed = 6;
  } else if (last >= arcStart) {
    final a = ev[last].t;
    final b = ev[last + 1].t;
    final span = b.difference(a).inSeconds;
    final frac =
        span <= 0 ? 0.0 : (now.difference(a).inSeconds / span).clamp(0.0, 1.0);
    progress = ((last - arcStart) + frac) / 6;
    // The dots already behind the sun, fajr included — it IS the arc's first
    // dot, so it lights up the moment its adhan has passed.
    passed = (last - arcStart + 1).clamp(0, 6);
  }

  final phase = switch (ev[last].id) {
    PrayerId.fajr => TimePhase.dawn,
    PrayerId.sunrise || PrayerId.dhuhr => TimePhase.day,
    PrayerId.asr => TimePhase.sunset,
    PrayerId.maghrib || PrayerId.isha => TimePhase.night,
  };

  final adhan = ev[next].t;
  final offset = iqamahOffsets[ev[next].id] ?? 0;
  final moon = phase == TimePhase.night || phase == TimePhase.dawn;
  return PrayerSnapshot(
    nextId: ev[next].id,
    nextAdhanTime: adhan,
    iqamahTime: offset > 0 ? adhan.add(Duration(minutes: offset)) : null,
    progress: progress,
    passedDots: passed,
    phase: phase,
    arc: computeArcState(s, now, nextAdhanTime: adhan, moon: moon),
  );
}

// ───────────────────── ten-marker horizon arc ─────────────────────

/// Duha starts 20 minutes after sunrise — the app's existing convention
/// (the home reminders card and the fiqh guides both use sunrise + 20).
DateTime duhaStart(DateTime sunrise) =>
    sunrise.add(const Duration(minutes: 20));

/// Midnight: the midpoint Maghrib → next Fajr (the adhan package's
/// SunnahTimes.middleOfTheNight formula, reproduced here so the arc needs
/// no repository access). Null when the span is degenerate.
DateTime? midnightBetween(DateTime maghrib, DateTime nextFajr) {
  final span = nextFajr.difference(maghrib);
  if (span <= Duration.zero) return null;
  return maghrib.add(span * 0.5);
}

/// Last third of the night: Maghrib + 2/3 of the way to the next Fajr
/// (SunnahTimes.lastThirdOfNight's formula).
DateTime? lastThirdBetween(DateTime maghrib, DateTime nextFajr) {
  final span = nextFajr.difference(maghrib);
  if (span <= Duration.zero) return null;
  return maghrib.add(span * (2 / 3));
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

enum ArcMarkerKind {
  /// One of the five adhan prayers (plus the closing fajr) — a circle.
  prayer,

  /// A non-prayer milestone (طلوع، ضحی، نیمه‌شب، ثلث آخر) — a diamond.
  derived,
}

enum ArcMarkerState { passed, next, upcoming }

@immutable
class ArcMarker {
  const ArcMarker({
    required this.label,
    required this.kind,
    required this.fraction,
    required this.state,
    this.time,
    this.isEnd = false,
  });

  final String label;
  final ArcMarkerKind kind;

  /// When this milestone happens. The arc's tagged style prints it under the
  /// name; the marker definitions themselves are unchanged by carrying it.
  final DateTime? time;

  /// Position as a fraction of the arc's PATH LENGTH (0..1). The painter
  /// resolves it through PathMetric — never as a Bezier parameter, so the
  /// ten markers sit at their design distances regardless of the curve.
  final double fraction;
  final ArcMarkerState state;

  /// The cycle's closing fajr — its label carries the «(فردا)» rule.
  final bool isEnd;

  @override
  bool operator ==(Object other) =>
      other is ArcMarker &&
      other.label == label &&
      other.kind == kind &&
      other.fraction == fraction &&
      other.state == state &&
      other.isEnd == isEnd &&
      other.time == time;

  @override
  int get hashCode => Object.hash(label, kind, fraction, state, isEnd, time);
}

@immutable
class ArcState {
  const ArcState({
    required this.markers,
    required this.nowFraction,
    required this.moon,
    required this.endTomorrow,
  });

  /// The defined markers, ordered by fraction. Undefined milestones (high
  /// latitude, degenerate spans) are simply absent — the painter hides
  /// what is not here and nothing can crash or go NaN.
  final List<ArcMarker> markers;

  /// The now marker's position, 0..1 of the path. Time moves the marker
  /// linearly INSIDE each segment (the left three segments each span 1/6 of
  /// the path, the right six each span 1/12), never along the raw Bezier.
  final double nowFraction;

  /// Crescent instead of sun (night and the fajr→sunrise stretch).
  final bool moon;
  final bool endTomorrow;

  String get endLabel => endTomorrow ? 'صبح (فردا)' : 'صبح';

  int get _q => (nowFraction * 600).round();

  @override
  bool operator ==(Object other) =>
      other is ArcState &&
      other.moon == moon &&
      other.endTomorrow == endTomorrow &&
      other._q == _q &&
      _listEquals(other.markers, markers);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(markers), moon, endTomorrow, _q);
}

bool _listEquals(List<ArcMarker> a, List<ArcMarker> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Path fractions of the ten design markers: the left half (صبح→ظهر) is
/// three equal segments, the right half (ظهر→صبح بعدی) six equal segments;
/// ظهر sits exactly at the path midpoint.
const double _fSunrise = 1 / 6;
const double _fDuha = 2 / 6;
const double _fDhuhr = 3 / 6;
const double _fAsr = 7 / 12;
const double _fMaghrib = 8 / 12;
const double _fIsha = 9 / 12;
const double _fMidnight = 10 / 12;
const double _fLastThird = 11 / 12;

/// The ten-marker arc for one moment. [nextAdhanTime] must be the snapshot's
/// countdown target — the ring lands on the marker whose time equals it, so
/// the number and the highlighted marker can never disagree. [moon] comes
/// from the snapshot's phase.
ArcState computeArcState(
  PrayerSchedule s,
  DateTime now, {
  required DateTime nextAdhanTime,
  required bool moon,
}) {
  final days = [s.yesterday, s.today, s.tomorrow];
  // The cycle containing now: the latest fajr at or before it. Before
  // today's fajr this is YESTERDAY's fajr, so the night completes the
  // previous cycle instead of resetting at midnight.
  var ci = 0;
  for (var i = 0; i < days.length; i++) {
    if (!days[i].fajr.isAfter(now)) ci = i;
  }
  final day = days[ci];
  final nextDay = days[(ci + 1).clamp(0, days.length - 1)];

  // Accepted points, strictly increasing in time. A milestone that is
  // undefined (high latitude) or lands outside its slot is dropped and the
  // neighbouring segments merge over the freed path span; a real adhan
  // event can only be dropped by an already-broken schedule, and then only
  // its marker hides.
  final times = <DateTime>[];
  final fractions = <double>[];
  final labels = <String>[];
  final kinds = <ArcMarkerKind>[];

  void add(
    DateTime t,
    double f,
    String label,
    ArcMarkerKind kind,
  ) {
    if (times.isNotEmpty && !t.isAfter(times.last)) return;
    times.add(t);
    fractions.add(f);
    labels.add(label);
    kinds.add(kind);
  }

  add(day.fajr, 0, 'صبح', ArcMarkerKind.prayer);
  add(day.sunrise, _fSunrise, 'طلوع', ArcMarkerKind.derived);
  final duha = duhaStart(day.sunrise);
  if (duha.isBefore(day.dhuhr)) {
    add(duha, _fDuha, 'ضحی', ArcMarkerKind.derived);
  }
  add(day.dhuhr, _fDhuhr, 'ظهر', ArcMarkerKind.prayer);
  add(day.asr, _fAsr, 'عصر', ArcMarkerKind.prayer);
  add(day.maghrib, _fMaghrib, 'مغرب', ArcMarkerKind.prayer);
  add(day.isha, _fIsha, 'عشاء', ArcMarkerKind.prayer);
  final midnight = midnightBetween(day.maghrib, nextDay.fajr);
  if (midnight != null && midnight.isAfter(day.isha)) {
    add(midnight, _fMidnight, 'نیمه‌شب', ArcMarkerKind.derived);
  }
  final lastThird = lastThirdBetween(day.maghrib, nextDay.fajr);
  if (lastThird != null) {
    add(lastThird, _fLastThird, 'ثلث آخر', ArcMarkerKind.derived);
  }
  final endTomorrow = !_isSameDay(nextDay.fajr, now);
  add(
    nextDay.fajr,
    1,
    endTomorrow ? 'صبح (فردا)' : 'صبح',
    ArcMarkerKind.prayer,
  );

  final markers = <ArcMarker>[
    for (var i = 0; i < times.length; i++)
      ArcMarker(
        label: labels[i],
        kind: kinds[i],
        fraction: fractions[i],
        time: times[i],
        state: times[i].isAfter(now)
            ? (times[i] == nextAdhanTime
                ? ArcMarkerState.next
                : ArcMarkerState.upcoming)
            : ArcMarkerState.passed,
        isEnd: i == times.length - 1,
      ),
  ];

  // Time-linear position inside the segment that contains now.
  var nowFraction = 0.0;
  if (!now.isBefore(times.last)) {
    nowFraction = 1;
  } else if (!now.isBefore(times.first)) {
    for (var i = 0; i < times.length - 1; i++) {
      if (!now.isBefore(times[i]) && now.isBefore(times[i + 1])) {
        final span = times[i + 1].difference(times[i]).inMicroseconds;
        final t =
            span <= 0 ? 0.0 : now.difference(times[i]).inMicroseconds / span;
        nowFraction = fractions[i] +
            (fractions[i + 1] - fractions[i]) * t.clamp(0.0, 1.0);
        break;
      }
    }
  }

  return ArcState(
    markers: markers,
    nowFraction: nowFraction.clamp(0.0, 1.0),
    moon: moon,
    endTomorrow: endTomorrow,
  );
}

/// Live notifier over [computeSnapshot] on the shared ticker. Call
/// [updateSchedule] after midnight rollovers or location changes.
class PrayerClock extends ValueNotifier<PrayerSnapshot> {
  PrayerClock(this._ticker, {required PrayerSchedule schedule})
      : _schedule = schedule,
        super(computeSnapshot(schedule, _ticker.second.value)) {
    _ticker.second.addListener(_onTick);
  }

  final ClockTicker _ticker;
  PrayerSchedule _schedule;

  /// After midnight (or a location change) hand in the new schedule.
  void updateSchedule(
    PrayerSchedule s, {
    Map<PrayerId, int> iqamahOffsets = const {},
  }) {
    _schedule = s;
    _offsets = iqamahOffsets;
    _onTick();
  }

  Map<PrayerId, int> _offsets = const {};

  /// Re-evaluate with new per-prayer iqamah offsets (settings change).
  void updateIqamahOffsets(Map<PrayerId, int> offsets) {
    _offsets = offsets;
    _onTick();
  }

  void _onTick() {
    value = computeSnapshot(
      _schedule,
      _ticker.second.value,
      iqamahOffsets: _offsets,
    );
  }

  @override
  void dispose() {
    _ticker.second.removeListener(_onTick);
    super.dispose();
  }
}

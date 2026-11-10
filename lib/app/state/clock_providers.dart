import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/core/services/clock_ticker.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/prayer/domain/entities/prayer_info.dart'
    as pi;
import 'package:tawheeed/features/prayer/domain/prayer_clock.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_time_provider.dart';
import 'package:tawheeed/features/settings/settings.dart';
import 'package:tawheeed/shared/models/day_time.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// App-lifetime ticker. The root widget watches [timePhaseProvider] which
/// watches this, so the ticker stays alive for the whole session and pauses
/// itself in the background (ClockTicker handles the lifecycle).
final clockTickerProvider = Provider<ClockTicker>((ref) {
  final ticker = ClockTicker();
  ref.onDispose(ticker.dispose);
  return ticker;
});

/// Lite mode for the redesign's heavy visuals (star field, glow). Reads the
/// persisted `lite_mode` preference (same direct-prefs pattern as the battery
/// banner). Deliberately off by default; a native RAM probe can flip the key
/// automatically later without touching this contract.
final liteModeProvider = FutureProvider<bool>((ref) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('lite_mode') ?? false;
  } catch (e) {
    AppLogger.warning('lite_mode', 'preference read failed: $e');
    return false;
  }
});

/// Live prayer clock for the redesign hero: arc progress, next prayer and
/// the (separate) iqamah time. Null while prayer times have not loaded yet
/// (the hero shows its loading skeleton then).
final prayerClockProvider = Provider<PrayerClock?>((ref) {
  final times = ref.watch(prayerTimesProvider).value;
  if (times == null) return null;
  final ticker = ref.watch(clockTickerProvider);
  final settings = ref.watch(settingsProvider).value;
  final clock = PrayerClock(
    ticker,
    schedule: PrayerSchedule.fromToday(times),
  );
  clock.updateIqamahOffsets(iqamahOffsetsFromSettings(settings));
  ref.onDispose(clock.dispose);
  return clock;
});

/// Per-prayer iqamah offsets (minutes after adhan) from settings; non-
/// positive offsets are dropped so the countdown counts to the adhan.
Map<PrayerId, int> iqamahOffsetsFromSettings(AppSettings? s) {
  if (s == null) return const {};
  final m = <PrayerId, int>{
    PrayerId.fajr: s.iqamahOffsetFajr,
    PrayerId.dhuhr: s.iqamahOffsetDhuhr,
    PrayerId.asr: s.iqamahOffsetAsr,
    PrayerId.maghrib: s.iqamahOffsetMaghrib,
    PrayerId.isha: s.iqamahOffsetIsha,
  };
  m.removeWhere((_, v) => v <= 0);
  return m;
}

/// The current time-of-day phase, derived from the shar'i schedule. Fires on
/// minute ticks (so phase changes land on the minute) and whenever the prayer
/// times are recalculated (location/method change). Drives the live theme.
final timePhaseProvider =
    NotifierProvider<TimePhaseNotifier, TimePhase>(TimePhaseNotifier.new);

class TimePhaseNotifier extends Notifier<TimePhase> {
  @override
  TimePhase build() {
    final ticker = ref.watch(clockTickerProvider);
    ref.onDispose(() => ticker.minute.removeListener(_onMinute));
    ticker.minute.addListener(_onMinute);
    ref.watch(prayerTimesProvider);
    return _compute();
  }

  void _onMinute() {
    final p = _compute();
    if (p != state) state = p;
  }

  TimePhase _compute() {
    final times = ref.read(prayerTimesProvider).value;
    final now = ref.read(clockTickerProvider).minute.value;
    if (times == null) return heuristicPhase(now);
    return phaseForSchedule(now, schedule: times);
  }
}

/// Phase mapping identical to the design's prayer-clock snapshot:
/// fajr→dawn, sunrise/dhuhr→day, asr→sunset, maghrib/isha→night, and the
/// stretch before fajr (after yesterday's isha) is night.
TimePhase phaseForSchedule(DateTime now, {required pi.PrayerTimes schedule}) {
  final day = schedule.date;
  DateTime at(DayTime t) =>
      DateTime(day.year, day.month, day.day, t.hour, t.minute);
  final events = <(DateTime, TimePhase)>[
    (at(schedule.fajr.time), TimePhase.dawn),
    (at(schedule.shorouq.time), TimePhase.day),
    (at(schedule.duhr.time), TimePhase.day),
    (at(schedule.asr.time), TimePhase.sunset),
    (at(schedule.maghrib.time), TimePhase.night),
    (at(schedule.isha.time), TimePhase.night),
  ];
  var phase = TimePhase.night; // before fajr → still night
  for (final (t, p) in events) {
    if (!t.isAfter(now)) phase = p;
  }
  return phase;
}

/// Coarse fallback used only while the prayer times have not loaded yet
/// (first frames after a cold start).
TimePhase heuristicPhase(DateTime now) {
  final h = now.hour + now.minute / 60.0;
  if (h < 4) return TimePhase.night;
  if (h < 6) return TimePhase.dawn;
  if (h < 15) return TimePhase.day;
  if (h < 18) return TimePhase.sunset;
  return TimePhase.night;
}

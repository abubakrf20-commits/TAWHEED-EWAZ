import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:adhan/adhan.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_time_helpers.dart';
import 'package:tawheeed/features/prayer/services/prayer_azan_sound_store.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';

class NativePrayerAlarmService {
  static const _channel = MethodChannel('com.tawheeed/prayer_scheduler');
  static const _alarmsChannel = MethodChannel('com.tawheeed/alarms');

  /// Audit P-11: the 8-day window can produce up to 40 `setAlarmClock` arms
  /// on every scheduling pass, and the logcat baseline recorded 548
  /// "not align this alarm" lines with only 502 distinct `origWhen` values —
  /// i.e. the exact same alarms were re-armed again and again. This
  /// fingerprint short-circuits a pass whose inputs and resulting alarm
  /// list are byte-for-byte identical to the last successful one.
  static String? _lastAlarmFingerprint;

  @visibleForTesting
  static void resetAlarmFingerprint() => _lastAlarmFingerprint = null;

  /// Visible for the instrumentation test: date + timezone + every setting
  /// that changes a baked alarm + every armed id/epoch/sound/volume.
  @visibleForTesting
  static String alarmFingerprint(
      List<Map<String, Object>> alarms, AppSettings settings, DateTime now) {
    final b = StringBuffer()
      ..write(now.timeZoneName)
      ..write('|${now.year}-${now.month}-${now.day}|')
      ..write(settings.timezone)
      ..write('|${settings.azanSound}|')
      ..write('${settings.customAzanPath ?? ''}|')
      ..write(settings.azanVolume);
    for (final a in alarms) {
      b
        ..write('|${a['id']}')
        ..write(':${a['timeMillis']}')
        ..write(':${a['sound']}')
        ..write(':${a['customPath']}')
        ..write(':${a['volume']}');
    }
    return b.toString();
  }

  /// Schedules native setAlarmClock alarms for TODAY and TOMORROW and persists
  /// them so `BootReceiver`/`RolloverReceiver` can restore them after a reboot.
  /// Also arms the self-healing daily rollover alarm. Today uses request-code
  /// base 2000, tomorrow base 2100 so the two days never overwrite each other.
  Future<void> scheduleAll(
      DateTime now, PrayerTimes times, AppSettings settings) async {
    final prayers = <String, (DateTime, int)>{
      'fajr': (times.fajr, 0),
      'dhuhr': (times.dhuhr, 1),
      'asr': (times.asr, 2),
      'maghrib': (times.maghrib, 3),
      'isha': (times.isha, 4),
    };

    final nameMap = <String, String>{
      'fajr': 'اذان صبح',
      'dhuhr': 'اذان ظهر',
      'asr': 'اذان عصر',
      'maghrib': 'اذان مغرب',
      'isha': 'اذان عشاء',
    };

    final enabledMap = {
      'fajr': settings.azanEnabledForFajr,
      'dhuhr': settings.azanEnabledForDhuhr,
      'asr': settings.azanEnabledForAsr,
      'maghrib': settings.azanEnabledForMaghrib,
      'isha': settings.azanEnabledForIsha,
    };

    // Per-prayer voice overrides (persisted in prefs by the «اذان و اقامه»
    // card): absent = the shared azanSound. Read once per schedule pass — a
    // disabled prayer is skipped below and keeps no audio anyway.
    Map<PrayerSlot, String> soundOverrides = const {};
    try {
      soundOverrides = await PrayerAzanSoundStore().readOverrides();
    } catch (_) {
      // No prefs (test env / isolate) — every prayer keeps the shared voice.
    }
    String soundFor(String prayerKey) => alarmSoundFor(
        prayerKey, soundOverrides, settings.azanSound);

    // Keep a full week of native alarms. The Flutter notification layer uses
    // the same horizon, while the native setAlarmClock path is authoritative
    // for adhan audio and remains available when the app has not been opened.
    final alarms = <Map<String, Object>>[];
    for (var dayOffset = 0; dayOffset <= 7; dayOffset++) {
      final day = now.add(Duration(days: dayOffset));
      final dayTimes = dayOffset == 0
          ? times
          : PrayerTimes(
              times.coordinates,
              DateComponents.from(day),
              times.calculationParameters,
              utcOffset: times.utcOffset,
            );
      for (final entry in prayers.entries) {
        if (!(enabledMap[entry.key] ?? true)) continue;
        final name = entry.key;
        final (time, index) = entry.value;
        final prayerTime = wallClockTime(
            dayOffset == 0 ? time : _timeForPrayer(dayTimes, name));
        if (prayerTime.isAfter(wallClockTime(now))) {
          alarms.add(_alarm(
            id: 2000 + dayOffset * 100 + index,
            prayer: nameMap[name] ?? name,
            timeMillis: wallClockEpochMillis(
              prayerTime,
              utcOffset: times.utcOffset,
            ),
            sound: soundFor(name),
            customPath: settings.customAzanPath ?? '',
            volume: settings.azanVolume,
          ));
        }
      }
    }

    final fingerprint = alarmFingerprint(alarms, settings, now);
    if (_lastAlarmFingerprint == fingerprint) {
      AppLogger.info('NativePrayerAlarm',
          'skipped, unchanged — ${alarms.length} alarms already armed');
      return;
    }

    try {
      if (alarms.isNotEmpty) {
        // Audit 4.1: the native side now returns the real scheduling result
        // ({scheduled, exactAllowed}) so a missing SCHEDULE_EXACT_ALARM grant
        // is logged loudly instead of the adhan silently not firing.
        final res = await _alarmsChannel.invokeMethod('scheduleExactAlarms', {
          'alarms': alarms,
        });
        if (res is Map && res['exactAllowed'] == false) {
          AppLogger.warning(
              'NativePrayerAlarm',
              'exact alarms NOT granted — adhan may be late under Doze '
                  '(${res['scheduled']} alarms armed inexact)');
        } else {
          AppLogger.info('NativePrayerAlarm',
              'Persisted & scheduled ${alarms.length} alarms (7-day window)');
          // Only a clean exact arm is worth deduplicating. If the grant is
          // missing, the next pass must be allowed to retry once the user
          // gives it (see the Home permission banner, audit P-08).
          _lastAlarmFingerprint = fingerprint;
        }
      } else {
        await _alarmsChannel.invokeMethod('cancelAllAlarms');
        _lastAlarmFingerprint = fingerprint;
      }
      await scheduleRollover();
    } catch (e) {
      AppLogger.warning('NativePrayerAlarm', 'Alarm scheduling failed: $e');
    }
  }

  /// Resolves ONE alarm's baked sound key: the prayer's own override when it
  /// has one, otherwise the shared voice. Visible for the test that pins the
  /// prayer-key → override mapping behind [scheduleAll].
  @visibleForTesting
  static String alarmSoundFor(
    String prayerKey,
    Map<PrayerSlot, String> overrides,
    String sharedSound,
  ) {
    final slot = PrayerSlot.values
        .firstWhere((e) => e.name == prayerKey, orElse: () => PrayerSlot.fajr);
    return PrayerAzanSoundStore.effectiveFor(slot, overrides, sharedSound);
  }

  /// Resolves the (sound, customPath) pair baked into a native alarm.
  ///
  /// A 'custom' sound whose file is missing (deleted backup, cleared
  /// storage, a legacy path from before the `custom_azans/` copy) can never
  /// play natively — the resolver only honours files inside
  /// `filesDir/custom_azans`, and the alarm would silently degrade to the
  /// bundled kamel at 5am. Bake the explicit kamel fallback instead, loudly,
  /// so the mystery "my file doesn't play" becomes a log line + the settings
  /// row's «بدون فایل» state rather than a surprise default.
  @visibleForTesting
  static ({String sound, String customPath}) bakeAlarmSound(
      String sound, String? customPath) {
    if (sound != 'custom') return (sound: sound, customPath: customPath ?? '');
    final path = customPath ?? '';
    if (path.isNotEmpty) {
      try {
        if (File(path).existsSync()) {
          return (sound: sound, customPath: path);
        }
      } catch (_) {
        // Fall through to the explicit fallback below.
      }
    }
    AppLogger.warning('NativePrayerAlarm',
        'custom azan unusable ($path) — baking kamel fallback; re-pick the file');
    return (sound: 'kamel', customPath: '');
  }

  Map<String, Object> _alarm({
    required int id,
    required String prayer,
    required int timeMillis,
    required String sound,
    required String customPath,
    double volume = 1.0,
  }) {
    final baked = bakeAlarmSound(sound, customPath);
    return {
      'id': id,
      'prayer': prayer,
      'timeMillis': timeMillis,
      'sound': baked.sound,
      'customPath': baked.customPath,
      'volume': volume,
    };
  }

  DateTime _timeForPrayer(PrayerTimes times, String prayer) {
    switch (prayer) {
      case 'fajr':
        return times.fajr;
      case 'dhuhr':
        return times.dhuhr;
      case 'asr':
        return times.asr;
      case 'maghrib':
        return times.maghrib;
      case 'isha':
        return times.isha;
      default:
        return times.maghrib;
    }
  }

  /// Arms the self-healing daily rollover alarm (fires ~00:00 each day).
  Future<void> scheduleRollover() async {
    try {
      await _channel.invokeMethod('scheduleRollover');
      AppLogger.info('NativePrayerAlarm', 'Daily rollover alarm armed');
    } catch (e) {
      AppLogger.warning('NativePrayerAlarm', 'Failed to arm rollover: $e');
    }
  }

  Future<void> cancelRollover() async {
    try {
      await _channel.invokeMethod('cancelRollover');
    } catch (e) {
      AppLogger.warning('NativePrayerAlarm', 'cancelRollover failed: $e');
    }
  }

  /// Diagnostic: schedules a native setAlarmClock alarm for a test adhan so the
  /// full prayer path (audio + foreground service) can be verified on demand.
  /// Uses the caller's current azan sound settings, unlike real alarms which
  /// are baked by [scheduleAll].
  Future<void> scheduleTestAlarm({
    required DateTime fireAt,
    String azanSound = 'kamel',
    String? customAzanPath,
  }) async {
    try {
      final baked = bakeAlarmSound(azanSound, customAzanPath);
      await _channel.invokeMethod('scheduleAdhan', {
        'prayer_name': 'تست اذان',
        'trigger_time': fireAt.millisecondsSinceEpoch,
        'sound_name': baked.sound,
        'custom_path': baked.customPath,
      });
      AppLogger.info('NativePrayerAlarm', 'Scheduled test adhan setAlarmClock');
    } catch (e) {
      AppLogger.warning(
          'NativePrayerAlarm', 'Test adhan scheduling failed: $e');
    }
  }

  Future<void> cancelAll() async {
    // A cancelled window must be re-armable the moment azan is switched back
    // on, even if the settings fingerprint is unchanged.
    _lastAlarmFingerprint = null;
    try {
      await _alarmsChannel.invokeMethod('cancelAllAlarms');
    } catch (e) {
      AppLogger.warning('NativePrayerAlarm', 'cancelAll (alarms) failed: $e');
    }
    try {
      await _channel.invokeMethod('cancelAllAlarms');
    } catch (e) {
      AppLogger.warning(
          'NativePrayerAlarm', 'cancelAll (scheduler) failed: $e');
    }
    await cancelRollover();
  }
}

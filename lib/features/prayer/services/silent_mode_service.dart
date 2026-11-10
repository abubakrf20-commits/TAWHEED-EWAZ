import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_time_helpers.dart';

/// Service to mute/unmute device sound before iqamah.
/// Uses MethodChannel to communicate with Android AudioManager.
class SilentModeService {
  static final SilentModeService _instance = SilentModeService._();
  factory SilentModeService() => _instance;
  static SilentModeService get instance => _instance;
  SilentModeService._();

  static const _channel = MethodChannel('com.tawheeed/silent');
  static const _schedulerChannel =
      MethodChannel('com.tawheeed/prayer_scheduler');

  /// Minutes the device stays silent AFTER the iqamah when «بی‌صدا قبل از
  /// اقامه» is on (0 = unmute exactly at iqamah). Stored in SharedPreferences
  /// (like the post-prayer azkar delay) so no Drift schema migration is needed.
  static const String afterIqamahMinutesKey = 'silent_after_iqamah_minutes';
  static const int defaultAfterIqamahMinutes = 0;

  /// Returns how many minutes after the iqamah the device should STAY silent.
  Future<int> afterIqamahMinutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getInt(afterIqamahMinutesKey) ?? defaultAfterIqamahMinutes)
          .clamp(0, 120)
          .toInt();
    } catch (e) {
      AppLogger.warning('SilentMode', 'minutes read failed: $e');
      return defaultAfterIqamahMinutes;
    }
  }

  /// Persists how many minutes after the iqamah the device stays silent.
  Future<void> setAfterIqamahMinutes(int minutes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(afterIqamahMinutesKey, minutes.clamp(0, 120).toInt());
    } catch (e) {
      // Best-effort persistence.
      AppLogger.warning('SilentMode', 'persist failed: $e');
    }
  }

  /// Each silent window gets its own pair of timers so scheduling
  /// for all 5 prayers works without overwriting previous ones.
  final Map<String, Timer> _muteTimers = {};
  final Map<String, Timer> _unmuteTimers = {};
  int _nextId = 0;

  /// Mute the device immediately.
  Future<bool> muteNow() async {
    try {
      final result = await _channel.invokeMethod<bool>('muteNow');
      return result ?? false;
    } catch (e) {
      AppLogger.error('SilentModeService.muteNow', e);
      return false;
    }
  }

  /// Unmute the device immediately (restores previous ringer mode).
  Future<bool> unmuteNow() async {
    try {
      final result = await _channel.invokeMethod<bool>('unmuteNow');
      return result ?? false;
    } catch (e) {
      AppLogger.error('SilentModeService.unmuteNow', e);
      return false;
    }
  }

  /// Schedule mute before iqamah, then auto-unmute at iqamah time
  /// (or [afterMinutes] minutes after it, when the device should STAY silent
  /// past the iqamah). Returns a unique id for this schedule (can be used for
  /// targeted cancellation).
  Future<int> scheduleSilent({
    required DateTime iqamahTime,
    required int minutesBefore,
    int afterMinutes = 0,
    Duration? utcOffset,
    int slot = 0,
  }) async {
    final id = _nextId++;
    final now = wallClockTime(DateTime.now());
    final wallIqamahTime = wallClockTime(iqamahTime);
    final muteTime = wallIqamahTime.subtract(Duration(minutes: minutesBefore));
    final unmuteTime = wallIqamahTime
        .add(Duration(minutes: afterMinutes.clamp(0, 120).toInt()));

    // Use native exact-alarm scheduling (survives app death) when DND granted.
    if (await isDndAccessGranted()) {
      await _scheduleSilentNative(
        muteTimeMillis: wallClockEpochMillis(muteTime, utcOffset: utcOffset),
        iqamahTimeMillis:
            wallClockEpochMillis(unmuteTime, utcOffset: utcOffset),
        slot: slot,
      );
    }

    if (muteTime.isAfter(now)) {
      final delay = muteTime.difference(now);
      AppLogger.info(
          'SilentModeService', 'scheduling mute in ${delay.inMinutes} minutes');
      _muteTimers['$id'] = Timer(delay, () async {
        await muteNow();
        _muteTimers.remove('$id');
        AppLogger.success('SilentModeService', 'device muted');
      });
    } else if (unmuteTime.isAfter(now)) {
      await muteNow();
      AppLogger.success(
          'SilentModeService', 'device muted now (within window)');
    }

    if (unmuteTime.isAfter(now)) {
      final unmuteDelay = unmuteTime.difference(now);
      _unmuteTimers['$id'] = Timer(unmuteDelay, () async {
        await unmuteNow();
        _unmuteTimers.remove('$id');
        AppLogger.success('SilentModeService', 'device unmuted');
      });
    }

    return id;
  }

  /// Schedule silent mode during prayer.
  /// Mutes at [prayerTime] and unmutes after [durationMinutes].
  /// Returns a unique id for this schedule (can be used for targeted cancellation).
  Future<int> scheduleSilentDuringPrayer({
    required DateTime prayerTime,
    required int durationMinutes,
    Duration? utcOffset,
    int slot = 0,
  }) async {
    final id = _nextId++;
    final now = wallClockTime(DateTime.now());
    final wallPrayerTime = wallClockTime(prayerTime);
    final unmuteTime = wallPrayerTime.add(Duration(minutes: durationMinutes));

    // Use native exact-alarm scheduling (survives app death) when DND granted.
    if (await isDndAccessGranted()) {
      await _scheduleSilentNative(
        muteTimeMillis:
            wallClockEpochMillis(wallPrayerTime, utcOffset: utcOffset),
        iqamahTimeMillis:
            wallClockEpochMillis(unmuteTime, utcOffset: utcOffset),
        slot: slot,
      );
    }

    if (wallPrayerTime.isAfter(now)) {
      final muteDelay = wallPrayerTime.difference(now);
      _muteTimers['p_$id'] = Timer(muteDelay, () async {
        await muteNow();
        _muteTimers.remove('p_$id');
        AppLogger.success('SilentModeService', 'device muted for prayer');
      });
    } else if (unmuteTime.isAfter(now)) {
      await muteNow();
      AppLogger.success(
          'SilentModeService', 'device muted now (prayer window)');
    }

    if (unmuteTime.isAfter(now)) {
      final unmuteDelay = unmuteTime.difference(now);
      _unmuteTimers['p_$id'] = Timer(unmuteDelay, () async {
        await unmuteNow();
        _unmuteTimers.remove('p_$id');
        AppLogger.success('SilentModeService', 'device unmuted after prayer');
      });
    }

    return id;
  }

  /// Schedule mute/unmute via native exact alarms so it survives app death.
  /// [slot] gives each prayer its own native request-code pair — without it every
  /// prayer overwrote the previous silent window while the app was closed.
  Future<void> _scheduleSilentNative({
    required int muteTimeMillis,
    required int iqamahTimeMillis,
    int slot = 0,
  }) async {
    try {
      await _schedulerChannel.invokeMethod('scheduleSilentMode', {
        'mute_time': muteTimeMillis,
        'iqamah_time': iqamahTimeMillis,
        'slot': slot,
      });
    } catch (e) {
      AppLogger.error('SilentModeService._scheduleSilentNative', e);
    }
  }

  /// Cancel ALL scheduled silent mode (both in-app and native).
  void cancelScheduled() {
    _cancelAllTimers();
    _cancelNativeSchedules();
  }

  void _cancelAllTimers() {
    for (final t in _muteTimers.values) {
      t.cancel();
    }
    for (final t in _unmuteTimers.values) {
      t.cancel();
    }
    _muteTimers.clear();
    _unmuteTimers.clear();
  }

  Future<void> _cancelNativeSchedules() async {
    try {
      await _schedulerChannel.invokeMethod('cancelAllSilent');
    } catch (e) {
      AppLogger.warning('SilentMode', 'native cancel failed: $e');
    }
  }

  /// Check if DND (Do Not Disturb) access is granted.
  Future<bool> isDndAccessGranted() async {
    try {
      final result = await _channel.invokeMethod<bool>('isDndAccessGranted');
      return result ?? false;
    } catch (e) {
      AppLogger.warning('silent_mode_service', 'error: $e');
      return false;
    }
  }

  /// Open DND settings to grant access.
  Future<void> openDndSettings() async {
    try {
      await _channel.invokeMethod('setDoNotDisturb', {'enabled': true});
    } catch (e) {
      AppLogger.warning('SilentModeService', 'Failed to open DND settings: $e');
    }
  }

  /// Request DND access. Opens the policy access settings screen if not granted.
  Future<void> requestDndAccess() async {
    try {
      await _channel.invokeMethod('setDoNotDisturb', {'enabled': true});
    } catch (e) {
      AppLogger.warning(
          'SilentModeService', 'Failed to request DND access: $e');
    }
  }
}

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/prayer/prayer.dart';
import 'package:tawheeed/shared/services/notification_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Boot/resume-time azan bookkeeping: tracks which prayers already fired
/// today (persisted), resets at day rollover, and cancels the redundant
/// silent reminder notification when the native alarm-clock azan window hits.
///
/// NOT a duplicate of `features/prayer/services/azan_playback_service.dart`'s
/// `AzanPlaybackService`: that class plays the azan audio (used by the settings
/// UI); this one never plays audio and only schedules/deduplicates. The two
/// intentionally keep separate APIs and are not merged.
class AzanService {
  final Set<String> _azanPlayedToday = {};
  static const String _azanPrefKey = 'azan_played_today';

  /// Maps prayer name → system notification ID so we can cancel it before the
  /// native adhan fires, preventing a redundant (now silent) reminder.
  static const _prayerNotifIds = {
    'fajr': 100,
    'dhuhr': 101,
    'asr': 102,
    'maghrib': 103,
    'isha': 104,
  };

  Timer? checkTimer;
  Timer? midnightTimer;

  void dispose() {
    checkTimer?.cancel();
    midnightTimer?.cancel();
  }

  Future<void> loadAzanPlayedToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_azanPrefKey);
      if (stored != null && stored.isNotEmpty) {
        final now = DateTime.now();
        final currentTag = '${now.day}_${now.month}_${now.year}';
        _azanPlayedToday.clear();
        for (final p in stored.split(',')) {
          if (p.isNotEmpty && p.contains(currentTag)) {
            _azanPlayedToday.add(p);
          }
        }
      }
    } catch (e) {
      AppLogger.warning('AzanService', 'Failed to load azan played today: $e');
    }
  }

  Future<void> _saveAzanPlayedToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_azanPrefKey, _azanPlayedToday.join(','));
    } catch (e) {
      AppLogger.warning('AzanService', 'Failed to save azan played today: $e');
    }
  }

  void maybeResetDay() {
    final now = DateTime.now();
    if (now.hour == 0 && now.minute < 30) {
      _azanPlayedToday.clear();
      _saveAzanPlayedToday();
    }
  }

  void checkAndPlayAzan(WidgetRef ref) {
    maybeResetDay();
    try {
      final prayerState = ref.read(prayerTimesProvider);
      final pt = prayerState.value;
      if (pt == null) return;

      final now = DateTime.now();
      final dayTag = '${now.day}_${now.month}_${now.year}';

      final prayers = [
        ('fajr', pt.fajr),
        ('dhuhr', pt.duhr),
        ('asr', pt.asr),
        ('maghrib', pt.maghrib),
        ('isha', pt.isha),
      ];

      for (final (name, info) in prayers) {
        final key = '${name}_$dayTag';
        if (_azanPlayedToday.contains(key)) continue;

        final pTime = DateTime(
            now.year, now.month, now.day, info.time.hour, info.time.minute);
        final diff = now.difference(pTime).inSeconds.abs();
        if (diff <= 90 &&
            now.isAfter(pTime.subtract(const Duration(seconds: 30)))) {
          _azanPlayedToday.add(key);
          _saveAzanPlayedToday();
          // The native setAlarmClock alarm is the authoritative azan (plays via
          // the foreground service). Just clear the redundant silent reminder;
          // do NOT trigger a second playback here.
          final notifId = _prayerNotifIds[name];
          if (notifId != null) {
            NotificationService().plugin.cancel(id: notifId);
          }
          break;
        }
      }
    } catch (e) {
      AppLogger.error('AzanService.checkAndPlayAzan', e);
    }
  }
}

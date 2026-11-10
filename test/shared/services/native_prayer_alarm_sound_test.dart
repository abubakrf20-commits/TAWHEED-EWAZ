import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/prayer/services/prayer_azan_sound_store.dart';
import 'package:tawheeed/shared/services/native_prayer_alarm_service.dart';

/// Guards the sound baked into native adhan alarms.
///
/// A 'custom' sound whose file cannot play natively must never be baked as
/// ('custom', bad-path): the alarm would silently degrade to the bundled
/// kamel at 5am — the reported "my file doesn't play, the default does".
/// The bake resolves to an explicit kamel fallback instead, loudly.
void main() {
  group('NativePrayerAlarmService.bakeAlarmSound', () {
    test('non-custom sounds pass through untouched', () {
      expect(
        NativePrayerAlarmService.bakeAlarmSound('kamel', null),
        (sound: 'kamel', customPath: ''),
      );
      expect(
        NativePrayerAlarmService.bakeAlarmSound('takbir', ''),
        (sound: 'takbir', customPath: ''),
      );
    });

    test('a custom sound with an existing file is kept', () async {
      final dir = await Directory.systemTemp.createTemp('azan_bake');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/azan_custom.mp3')
        ..writeAsBytesSync(List.filled(200, 0));
      expect(
        NativePrayerAlarmService.bakeAlarmSound('custom', file.path),
        (sound: 'custom', customPath: file.path),
      );
    });

    test('a custom sound with a missing file falls back to kamel', () {
      final baked = NativePrayerAlarmService.bakeAlarmSound(
          'custom', '/no/such/dir/azan_custom.mp3');
      expect(baked.sound, 'kamel');
      expect(baked.customPath, isEmpty);
    });

    test('a custom sound with an empty path falls back to kamel', () {
      expect(
        NativePrayerAlarmService.bakeAlarmSound('custom', ''),
        (sound: 'kamel', customPath: ''),
      );
      expect(
        NativePrayerAlarmService.bakeAlarmSound('custom', null),
        (sound: 'kamel', customPath: ''),
      );
    });
  });

  group('NativePrayerAlarmService.alarmSoundFor (per-prayer voices)', () {
    test('a prayer with no override inherits the shared voice', () {
      expect(
        NativePrayerAlarmService.alarmSoundFor(
            'fajr', const {}, 'takbir'),
        'takbir',
      );
      expect(
        NativePrayerAlarmService.alarmSoundFor(
            'isha', const {}, 'kamel'),
        'kamel',
      );
    });

    test('an explicit override wins for its own prayer only', () {
      final overrides = {
        PrayerSlot.fajr: 'kamel',
        PrayerSlot.maghrib: 'custom',
      };
      expect(
        NativePrayerAlarmService.alarmSoundFor('fajr', overrides, 'takbir'),
        'kamel',
      );
      expect(
        NativePrayerAlarmService.alarmSoundFor('maghrib', overrides, 'takbir'),
        'custom',
      );
      expect(
        NativePrayerAlarmService.alarmSoundFor('dhuhr', overrides, 'takbir'),
        'takbir',
      );
      expect(
        NativePrayerAlarmService.alarmSoundFor('asr', overrides, 'takbir'),
        'takbir',
      );
      expect(
        NativePrayerAlarmService.alarmSoundFor('isha', overrides, 'takbir'),
        'takbir',
      );
    });
  });
}

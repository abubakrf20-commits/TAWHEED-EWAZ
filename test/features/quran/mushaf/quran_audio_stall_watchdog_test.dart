import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/quran/mushaf/quran_audio_stall_watchdog.dart';

/// This repo checks out CRLF on Windows; normalize before `contains`.
String readSource(String path) =>
    File('lib/features/quran/mushaf/$path').readAsStringSync().replaceAll(
          '\r\n',
          '\n',
        );

class _Clock {
  DateTime value = DateTime(2026, 10, 17, 12);
}

void main() {
  group('AudioStallWatchdog', () {
    test('advancing positions never stall', () {
      final clock = _Clock();
      final fired = <bool>[];
      final wd = AudioStallWatchdog(
        now: () => clock.value,
        onStalled: fired.add,
      );
      wd.setPlaying(true);
      for (var s = 0; s < 30; s++) {
        clock.value = clock.value.add(const Duration(seconds: 2));
        wd.onPosition(Duration(seconds: s));
        wd.checkNow();
      }
      expect(fired, isEmpty);
      expect(wd.isStalled, isFalse);
      wd.dispose();
    });

    test('fires stalled once after the frozen threshold', () {
      final clock = _Clock();
      final fired = <bool>[];
      final wd = AudioStallWatchdog(
        now: () => clock.value,
        onStalled: fired.add,
      );
      wd.setPlaying(true);
      wd.onPosition(const Duration(seconds: 6));
      clock.value = clock.value.add(const Duration(seconds: 7));
      wd.checkNow();
      expect(fired, isEmpty);
      clock.value = clock.value.add(const Duration(seconds: 2));
      wd.checkNow();
      expect(fired, [true]);
      expect(wd.isStalled, isTrue);
      // Repeated checks do not re-fire while still frozen.
      clock.value = clock.value.add(const Duration(seconds: 10));
      wd.checkNow();
      expect(fired, [true]);
      wd.dispose();
    });

    test('an advance clears the stall', () {
      final clock = _Clock();
      final fired = <bool>[];
      final wd = AudioStallWatchdog(
        now: () => clock.value,
        onStalled: fired.add,
      );
      wd.setPlaying(true);
      wd.onPosition(const Duration(seconds: 6));
      clock.value = clock.value.add(const Duration(seconds: 9));
      wd.checkNow();
      expect(wd.isStalled, isTrue);
      clock.value = clock.value.add(const Duration(seconds: 1));
      wd.onPosition(const Duration(seconds: 7));
      expect(fired, [true, false]);
      expect(wd.isStalled, isFalse);
      wd.dispose();
    });

    test('pausing clears the stall and disarms the check', () {
      final clock = _Clock();
      final fired = <bool>[];
      final wd = AudioStallWatchdog(
        now: () => clock.value,
        onStalled: fired.add,
      );
      wd.setPlaying(true);
      wd.onPosition(const Duration(seconds: 6));
      clock.value = clock.value.add(const Duration(seconds: 9));
      wd.checkNow();
      expect(wd.isStalled, isTrue);
      wd.setPlaying(false);
      expect(fired, [true, false]);
      expect(wd.isStalled, isFalse);
      // Disarmed: a frozen position while paused never fires again.
      clock.value = clock.value.add(const Duration(minutes: 5));
      wd.checkNow();
      expect(fired, [true, false]);
      // Resuming re-arms from a fresh baseline.
      wd.setPlaying(true);
      clock.value = clock.value.add(const Duration(seconds: 3));
      wd.checkNow();
      expect(fired, [true, false]);
      clock.value = clock.value.add(const Duration(seconds: 6));
      wd.checkNow();
      expect(fired, [true, false, true]);
      wd.dispose();
    });

    test('identical position values do not reset the baseline', () {
      final clock = _Clock();
      final wd = AudioStallWatchdog(now: () => clock.value);
      wd.setPlaying(true);
      wd.onPosition(const Duration(seconds: 6));
      clock.value = clock.value.add(const Duration(seconds: 4));
      wd.onPosition(const Duration(seconds: 6));
      clock.value = clock.value.add(const Duration(seconds: 5));
      wd.checkNow();
      expect(wd.isStalled, isTrue);
      wd.dispose();
    });

    test('a new verse position (0:00) counts as an advance', () {
      final clock = _Clock();
      final fired = <bool>[];
      final wd = AudioStallWatchdog(
        now: () => clock.value,
        onStalled: fired.add,
      );
      wd.setPlaying(true);
      wd.onPosition(const Duration(seconds: 30));
      clock.value = clock.value.add(const Duration(seconds: 9));
      wd.checkNow();
      expect(wd.isStalled, isTrue);
      wd.onPosition(Duration.zero);
      expect(fired, [true, false]);
      wd.dispose();
    });
  });

  group('stall wiring (source guards)', () {
    test('controller arms, feeds, exposes and disposes the watchdog', () {
      final src = readSource('quran_audio_controller.dart');
      expect(src, contains('late final AudioStallWatchdog _stallWatchdog'));
      expect(src, contains('bool get isStalled => _stallWatchdog.isStalled'));
      expect(src, contains('_stallWatchdog.onPosition(pos);'));
      expect(src, contains('_stallWatchdog.setPlaying(value);'));
      expect(src, contains('_stallWatchdog.dispose();'));
    });

    test('the base routes engine state through setPlaying', () {
      final src = readSource('quran_audio_player_base.dart');
      expect(src, contains('setPlaying(s == PlayerState.playing)'));
    });

    test('the mini player prefers loading, then the stall note', () {
      final src = readSource('quran_reader_player.dart');
      final loadIdx = src.indexOf('audio.isLoading');
      final stallIdx = src.indexOf('audio.isStalled');
      expect(loadIdx, greaterThanOrEqualTo(0));
      expect(stallIdx, greaterThan(loadIdx));
      expect(src, contains("'اتصال ضعیف…'"));
    });
  });
}

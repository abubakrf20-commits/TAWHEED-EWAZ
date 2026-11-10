import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/ruqyah/services/ruqyah_audio_service.dart';

void main() {
  group('RuqyahAudioTrack', () {
    test('hosts exactly the two recitations with unique ASCII keys', () {
      expect(RuqyahAudioService.tracks.length, 2);
      final keys = RuqyahAudioService.tracks.map((t) => t.key).toSet();
      expect(keys.length, 2);
      for (final t in RuqyahAudioService.tracks) {
        expect(RegExp(r'^[a-z0-9-]+$').hasMatch(t.key), isTrue,
            reason: 'key must be filesystem-safe: ${t.key}');
      }
    });

    test('remote URLs point at the hosted roqya catalog', () {
      for (final t in RuqyahAudioService.tracks) {
        expect(
          t.url,
          'https://raw.githubusercontent.com/abubakrf20-commits/TAWHEED-EWAZ/'
          'main/roqya/${t.remoteFile}',
        );
      }
    });
  });

  group('RuqyahAudioTrackState', () {
    test('progress is clamped and null when total is unknown', () {
      const unknown = RuqyahAudioTrackState(received: 10);
      expect(unknown.progress, isNull);

      const half = RuqyahAudioTrackState(received: 5, total: 10);
      expect(half.progress, 0.5);

      const overflow = RuqyahAudioTrackState(received: 99, total: 10);
      expect(overflow.progress, 1.0);
    });

    test('copyWith only overrides given fields (error sentinel)', () {
      const s = RuqyahAudioTrackState(
          downloading: true, error: 'خطا', received: 1, total: 2);
      final cleared = s.copyWith(downloading: false, error: null);
      expect(cleared.downloading, isFalse);
      expect(cleared.error, isNull);
      expect(cleared.received, 1);
      expect(cleared.total, 2);

      final kept = s.copyWith(downloading: false);
      expect(kept.error, 'خطا');
    });

    test('service exposes an independent state per track by default', () {
      final service = RuqyahAudioService.instance;
      for (final t in RuqyahAudioService.tracks) {
        final st = service.stateOf(t);
        expect(st.downloaded, anyOf(isTrue, isFalse));
        expect(st.playing, isFalse);
        expect(st.downloading, isFalse);
      }
    });
  });

  group('RuqyahAudioService.formatDuration', () {
    test('formats minutes:seconds below one hour', () {
      expect(RuqyahAudioService.formatDuration(Duration.zero), '0:00');
      expect(RuqyahAudioService.formatDuration(const Duration(seconds: 5)),
          '0:05');
      expect(
          RuqyahAudioService.formatDuration(
              const Duration(minutes: 2, seconds: 7)),
          '2:07');
    });

    test('formats hours:minutes:seconds at and above one hour', () {
      expect(RuqyahAudioService.formatDuration(const Duration(hours: 1)),
          '1:00:00');
      expect(
          RuqyahAudioService.formatDuration(
              const Duration(hours: 1, minutes: 5, seconds: 3)),
          '1:05:03');
      expect(
          RuqyahAudioService.formatDuration(
              const Duration(hours: 2, minutes: 59, seconds: 59)),
          '2:59:59');
    });
  });

  group('RuqyahAudioTrackState position/duration', () {
    test('hasDuration is false until a real duration arrives', () {
      const empty = RuqyahAudioTrackState();
      expect(empty.hasDuration, isFalse);

      final withDuration = const RuqyahAudioTrackState()
          .copyWith(duration: const Duration(minutes: 75));
      expect(withDuration.hasDuration, isTrue);
      expect(withDuration.position, Duration.zero);
    });

    test('copyWith preserves position/duration unless overridden', () {
      const base = RuqyahAudioTrackState(
        position: Duration(seconds: 30),
        duration: Duration(minutes: 80),
      );
      final paused = base.copyWith(playing: false);
      expect(paused.position, const Duration(seconds: 30));
      expect(paused.duration, const Duration(minutes: 80));
    });
  });
}

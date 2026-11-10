import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/audio_library/audio_library_player.dart';

void main() {
  group('AudioLibraryTrackState', () {
    test('progress is null when the total size is unknown', () {
      const unknown = AudioLibraryTrackState(received: 10);
      expect(unknown.progress, isNull);
    });

    test('progress is clamped to 0..1', () {
      const half = AudioLibraryTrackState(received: 5, total: 10);
      expect(half.progress, 0.5);

      const overflow = AudioLibraryTrackState(received: 99, total: 10);
      expect(overflow.progress, 1.0);
    });

    test('hasDuration is false until a real duration arrives', () {
      const empty = AudioLibraryTrackState();
      expect(empty.hasDuration, isFalse);

      final withDuration = const AudioLibraryTrackState()
          .copyWith(duration: const Duration(minutes: 75));
      expect(withDuration.hasDuration, isTrue);
      expect(withDuration.position, Duration.zero);
    });

    test('copyWith only overrides given fields (error sentinel)', () {
      const s = AudioLibraryTrackState(
          downloading: true, error: 'خطا', received: 1, total: 2);
      final cleared = s.copyWith(downloading: false, error: null);
      expect(cleared.downloading, isFalse);
      expect(cleared.error, isNull);
      expect(cleared.received, 1);
      expect(cleared.total, 2);

      final kept = s.copyWith(downloading: false);
      expect(kept.error, 'خطا');
      expect(kept.playing, isFalse);
    });

    test('copyWith preserves position/duration unless overridden', () {
      const base = AudioLibraryTrackState(
        position: Duration(seconds: 30),
        duration: Duration(minutes: 80),
      );
      final paused = base.copyWith(playing: false);
      expect(paused.position, const Duration(seconds: 30));
      expect(paused.duration, const Duration(minutes: 80));
    });
  });

  group('AudioLibraryPlayer.formatDuration', () {
    test('formats minutes:seconds below one hour', () {
      expect(AudioLibraryPlayer.formatDuration(Duration.zero), '0:00');
      expect(AudioLibraryPlayer.formatDuration(const Duration(seconds: 5)),
          '0:05');
      expect(
          AudioLibraryPlayer.formatDuration(
              const Duration(minutes: 2, seconds: 7)),
          '2:07');
    });

    test('formats hours:minutes:seconds at and above one hour', () {
      expect(AudioLibraryPlayer.formatDuration(const Duration(hours: 1)),
          '1:00:00');
      expect(
          AudioLibraryPlayer.formatDuration(
              const Duration(hours: 1, minutes: 5, seconds: 3)),
          '1:05:03');
    });
  });

  test('audio library has no plugin side-effects in tests', () {
    expect(AudioLibraryPlayer.instance.toString(), isNotEmpty);
  });
}

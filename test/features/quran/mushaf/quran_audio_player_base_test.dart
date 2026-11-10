import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the shared audio engine: the talaawah and translation controllers
/// used to carry identical machinery (operation queue, session tokens,
/// subscriptions, wakelock, pause/rate) in parallel. That machinery lives
/// in [QuranAudioPlayerBase] now; both controllers must extend it and carry
/// none of it themselves, or a fix in one player silently stops applying to
/// the other.
///
/// The audioplayers platform channels cannot run in a plain Dart test, so
/// these are source guards in the repo's established style.
Future<String> readSource(String path) async =>
    (await File(path).readAsString()).replaceAll('\r\n', '\n');

const _controllers = [
  'lib/features/quran/mushaf/quran_audio_controller.dart',
  'lib/features/quran/mushaf/quran_translation_audio_controller.dart',
];

void main() {
  group('QuranAudioPlayerBase — the single shared engine', () {
    test('both controllers extend the base', () async {
      for (final path in _controllers) {
        final source = await readSource(path);
        expect(
          source.contains('extends QuranAudioPlayerBase'),
          isTrue,
          reason: '$path must share the base engine',
        );
      }
    });

    test('no controller carries its own queue, tokens or subscriptions',
        () async {
      for (final path in _controllers) {
        final source = await readSource(path);
        for (final token in [
          '_playerQueue',
          'StreamSubscription<',
          'AudioPlayer _player',
        ]) {
          expect(source.contains(token), isFalse,
              reason: '$path must not duplicate the base ($token)');
        }
      }
    });

    test('wakelock, pause and rate go through the base', () async {
      for (final path in _controllers) {
        final source = await readSource(path);
        expect(source.contains('AppWakelock.'), isFalse,
            reason: '$path must use acquire/releaseWakelock');
        expect(source.contains('Future<void> pause()'), isFalse,
            reason: '$path must inherit pause() from the base');
        expect(source.contains('setPlaybackRate(double rate)'), isFalse,
            reason: '$path must inherit setPlaybackRate() from the base');
      }
    });

    test('the base owns the canonical implementations', () async {
      final source = await readSource(
          'lib/features/quran/mushaf/quran_audio_player_base.dart');
      for (final token in [
        'Future<void> enqueuePlayer(',
        'int beginSession()',
        'bool sessionAlive(',
        'void invalidateSession()',
        'void attachPlayerListeners(',
        'Future<void> disposePlayer()',
        'Future<void> pause()',
        'Future<void> setPlaybackRate(',
        'Future<void> acquireWakelock(',
        'Future<void> releaseWakelock(',
      ]) {
        expect(source.contains(token), isTrue,
            reason: 'the base must define $token');
      }
    });
  });
}

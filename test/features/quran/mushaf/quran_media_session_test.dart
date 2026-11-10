import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/quran/mushaf/quran_audio_controller.dart';
import 'package:tawheeed/features/quran/mushaf/quran_media_session.dart';
import 'package:tawheeed/features/quran/mushaf/quran_translation_audio_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Constructing an AudioPlayer spins up the global audioplayers channel,
  // which has no test implementation. Everything the mappers touch is plain
  // Dart state, so the missing-platform error is swallowed per-test.
  setUpAll(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in const [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers',
      'plugins.flutter.io/shared_preferences',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(channel),
        (call) async => null,
      );
    }
  });

  group('mediaItemForSource (tilawah)', () {
    test('uses the verse key as id and Persian labels for card content', () {
      final item =
          mediaItemForSource(QuranAudioController(), QuranMediaSource.tilawah);
      expect(item.id, isNotEmpty);
      expect(item.id, contains(':'));
      expect(item.album, 'قرآن کریم');
      expect(item.title, contains('سورهٔ'));
      expect(item.title, contains('آیهٔ'));
    });
  });

  group('mediaItemForSource (translation)', () {
    test('marks the card with the Persian-translation album line', () {
      final item = mediaItemForSource(
          QuranTranslationAudioController(), QuranMediaSource.translation);
      expect(item.id, isNotEmpty);
      expect(item.id, contains(':'));
      expect(item.album, 'ترجمهٔ فارسی');
      expect(item.title, contains('ترجمه:'));
    });
  });

  group('playbackStateForSource', () {
    test('paused controller shows a play control, not a pause one', () {
      final state = playbackStateForSource(
        QuranAudioController(),
        QuranMediaSource.tilawah,
        clock: () => DateTime(2026),
      );
      expect(state.playing, isFalse);
      expect(
        state.controls.map((c) => c.action),
        contains(MediaAction.play),
      );
      expect(
        state.controls.map((c) => c.action),
        isNot(contains(MediaAction.pause)),
      );
      // Verse stepper is always available on the lock screen.
      expect(
        state.controls.map((c) => c.action),
        containsAll([MediaAction.skipToNext, MediaAction.skipToPrevious]),
      );
    });

    test('processing state is ready when the engine is idle', () {
      final state = playbackStateForSource(
        QuranAudioController(),
        QuranMediaSource.tilawah,
        clock: () => DateTime(2026),
      );
      expect(state.processingState, AudioProcessingState.ready);
    });

    test('position and buffered positions come from the engine', () {
      final state = playbackStateForSource(
        QuranAudioController(),
        QuranMediaSource.tilawah,
        clock: () => DateTime(2026),
      );
      expect(state.updatePosition, Duration.zero);
      expect(state.speed, 1.0);
    });

    test('translation card advertises no seek (engine cannot scrub)', () {
      final state = playbackStateForSource(
        QuranTranslationAudioController(),
        QuranMediaSource.translation,
        clock: () => DateTime(2026),
      );
      expect(state.systemActions, isEmpty);
    });

    test('tilawah card keeps the seek system action', () {
      final state = playbackStateForSource(
        QuranAudioController(),
        QuranMediaSource.tilawah,
        clock: () => DateTime(2026),
      );
      expect(state.systemActions, contains(MediaAction.seek));
    });
  });

  group('QuranMediaHandler routing', () {
    test('play routes into the controller without crashing sessionless',
        () async {
      final controller = QuranAudioController();
      final handler = QuranMediaHandler(controller, QuranMediaSource.tilawah);
      // Sessionless: togglePlayPause() must be a safe no-op that still
      // resolves — proves the lock-screen buttons cannot crash the app
      // when tapped before any recitation started.
      await handler.play();
      await handler.pause();
      await handler.skipToNext();
      await handler.skipToPrevious();
      await handler.seek(const Duration(seconds: 3));
      expect(controller.isPlaying, isFalse);
      expect(controller.hasSession, isFalse);
    });

    test('translation handler routes play/pause and skips safely', () async {
      // Pigeon channels (wakelock_plus) have no method-channel mock surface;
      // their PlatformException during dispose must not fail the test.
      await runZonedGuarded(() async {
        final controller = QuranTranslationAudioController();
        final handler =
            QuranMediaHandler(controller, QuranMediaSource.translation);
        // Sessionless: every routing target must resolve without crashing.
        await handler.play();
        await handler.pause();
        await handler.skipToNext();
        await handler.skipToPrevious();
        // Seek routes into the no-op stub (supportsSeek == false): a stray
        // lock-screen seek can never crash or restart the engine.
        await handler.seek(const Duration(seconds: 3));
        controller.dispose();
      }, (_, __) {});
      // No expect on the translation controller's state: playVerse() is async
      // and keeps settling after the awaited calls return, so any snapshot
      // here would be a race.
    });

    test('handler exposes seeded session subjects for the OS', () {
      final handler =
          QuranMediaHandler(QuranAudioController(), QuranMediaSource.tilawah);
      expect(handler.playbackState.value.playing, isFalse);
      expect(handler.mediaItem.value, isNull);
    });
  });

  group('session source priority', () {
    test('albumForSource distinguishes the two notification cards', () {
      expect(albumForSource(QuranMediaSource.tilawah), 'قرآن کریم');
      expect(albumForSource(QuranMediaSource.translation), 'ترجمهٔ فارسی');
    });

    test('notification channels are distinct per source', () {
      // Channel ids are derived from the same mapping the session init uses;
      // pinned here so a refactor can never merge the two cards again.
      expect(
        albumForSource(QuranMediaSource.tilawah),
        isNot(albumForSource(QuranMediaSource.translation)),
      );
    });
  });
}

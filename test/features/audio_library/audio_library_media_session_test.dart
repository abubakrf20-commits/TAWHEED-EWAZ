import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/audio_library/audio_library_manifest.dart';
import 'package:tawheeed/features/audio_library/audio_library_media_session.dart';
import 'package:tawheeed/features/audio_library/audio_library_player.dart';

/// Background playback for the audio library: a lecture keeps playing when
/// the section closes, the lock-screen card mirrors the player, and the card's
/// stop silences it. The session only ever talks to the
/// [AudioLibraryMediaPlayback] surface, so the fakes below need no engine.
const AudioTrack _track = AudioTrack(
  id: 'tafsir-01',
  title: 'درس تفسیر',
  file: 'tafsir/01.opus',
  sizeBytes: 1024,
);

/// A recording stand-in for the player.
class _FakePlayback extends ChangeNotifier
    implements AudioLibraryMediaPlayback {
  _FakePlayback({AudioTrack? track}) : _track = track;

  final AudioTrack? _track;
  bool playing = false;
  bool loading = false;
  Duration currentPosition = Duration.zero;
  Duration currentDuration = const Duration(minutes: 42);
  double rate = 1.0;
  String? byline;
  int resumeCalls = 0;
  int pauseCalls = 0;
  int stopCalls = 0;
  final List<Duration> seeks = [];

  @override
  AudioTrack? get activeTrack => _track;

  @override
  String? get activeByline => byline;

  @override
  bool get isPlaying => playing;

  @override
  bool get isLoading => loading;

  @override
  Duration get position => currentPosition;

  @override
  Duration get duration => currentDuration;

  @override
  double get speed => rate;

  @override
  Future<void> resumeActive() async {
    resumeCalls++;
    playing = true;
    notifyListeners();
  }

  @override
  Future<void> pauseActive() async {
    pauseCalls++;
    playing = false;
    notifyListeners();
  }

  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
    currentPosition = position;
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    playing = false;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final configureCalls = <String>[];
  late final Directory cacheDir;

  setUpAll(() async {
    // `AudioService.init` reaches the platform through two method channels.
    // Answering both with null lets the session start here the same way it
    // starts on a phone — one init per process, then the handler is reused
    // (pinned by the lifecycle test below).
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.audio_service.client.methods'),
      (call) async {
        if (call.method == 'configure') configureCalls.add(call.method);
        return null;
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.audio_service.handler.methods'),
      (call) async => null,
    );
    // Init also builds its (unused — the library ships no artwork) cache
    // manager through path_provider before it touches the service channel;
    // a real temp directory keeps the production init path exercised.
    cacheDir = Directory.systemTemp.createTempSync('audio_lib_media_test');
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => cacheDir.path,
    );
    // Prime the shared handler once: every later session start reuses it,
    // and SeekHandler reads its ±15 s from the config this init ships.
    await AudioLibraryMediaSession.instance.start(
      _FakePlayback(track: _track),
    );
    await AudioLibraryMediaSession.instance.stop();
  });

  tearDownAll(() {
    try {
      cacheDir.deleteSync(recursive: true);
    } catch (_) {
      // Best-effort hygiene; a locked cache file must not fail the suite.
    }
  });

  tearDown(() async {
    await AudioLibraryMediaSession.instance.stop();
  });

  group('media card mapping', () {
    test('names the lecture, its teacher and the album', () {
      final fake = _FakePlayback(track: _track)..byline = 'شیخ ضیایی';
      final item = mediaItemForSource(fake);
      expect(item.id, 'tafsir-01');
      expect(item.title, 'درس تفسیر');
      expect(item.artist, 'شیخ ضیایی');
      expect(item.album, kAudioLibraryAlbum);
      expect(item.duration, const Duration(minutes: 42));
    });

    test('a teacher-less category shows no artist line', () {
      final fake = _FakePlayback(track: _track);
      expect(mediaItemForSource(fake).artist, isNull);
    });

    test('duration stays null until the seek bar has a length', () {
      final fake = _FakePlayback(track: _track)
        ..currentDuration = Duration.zero;
      expect(mediaItemForSource(fake).duration, isNull);
    });

    test('paused card shows play (never pause) and both ±15 s buttons', () {
      final state = playbackStateForSource(_FakePlayback(track: _track));
      expect(state.playing, isFalse);
      expect(state.controls.map((c) => c.action), [
        MediaAction.rewind,
        MediaAction.play,
        MediaAction.fastForward,
      ]);
      expect(state.systemActions, contains(MediaAction.seek));
      expect(state.updatePosition, Duration.zero);
      expect(state.bufferedPosition, const Duration(minutes: 42));
      expect(state.speed, 1.0);
    });

    test('playing card swaps in the pause control', () {
      final state =
          playbackStateForSource(_FakePlayback(track: _track)..playing = true);
      expect(state.playing, isTrue);
      expect(state.controls.map((c) => c.action), contains(MediaAction.pause));
      expect(
        state.controls.map((c) => c.action),
        isNot(contains(MediaAction.play)),
      );
    });

    test('a buffering track reports buffering to the OS', () {
      final state =
          playbackStateForSource(_FakePlayback(track: _track)..loading = true);
      expect(state.processingState, AudioProcessingState.buffering);
    });
  });

  group('lock-screen routing', () {
    test('play/pause/seek route into the source', () async {
      final fake = _FakePlayback(track: _track);
      final handler = AudioLibraryMediaHandler(fake);
      await handler.play();
      expect(fake.resumeCalls, 1);
      await handler.pause();
      expect(fake.pauseCalls, 1);
      await handler.seek(const Duration(minutes: 3));
      expect(fake.seeks, [const Duration(minutes: 3)]);
    });

    test('rewind and forward jump ±15 s from the live position', () async {
      final fake = _FakePlayback(track: _track)
        ..currentPosition = const Duration(minutes: 1);
      final handler = AudioLibraryMediaHandler(fake);
      await handler.rewind();
      expect(fake.seeks.last, const Duration(seconds: 45));
      // The second press measures from where the first landed — the card
      // mirrors the mini player, not a stale published position.
      await handler.fastForward();
      expect(fake.seeks.last, const Duration(minutes: 1));
      expect(fake.seeks, hasLength(2));
    });

    test('a card stop silences the source and ends the card', () async {
      final fake = _FakePlayback(track: _track)..playing = true;
      final handler = AudioLibraryMediaHandler(fake);
      await handler.stop();
      expect(fake.stopCalls, 1);
      expect(
        handler.playbackState.value.processingState,
        AudioProcessingState.idle,
      );
    });

    test('ending a card after playback already stopped cannot re-enter',
        () async {
      final fake = _FakePlayback(track: _track);
      final handler = AudioLibraryMediaHandler(fake);
      await handler.stopCard();
      expect(fake.stopCalls, 0);
      expect(
        handler.playbackState.value.processingState,
        AudioProcessingState.idle,
      );
      // A late OS stop after our own teardown must not touch the source.
      await handler.stop();
      expect(fake.stopCalls, 0);
    });
  });

  group('session lifecycle', () {
    test('binds on start, mirrors the track, and reuses the handler', () async {
      final session = AudioLibraryMediaSession.instance;
      final fake = _FakePlayback(track: _track)..byline = 'شیخ ضیایی';
      await session.start(fake);
      expect(session.isActive, isTrue);
      final handler = session.debugHandler;
      expect(handler, isNotNull);
      expect(handler!.mediaItem.value?.id, 'tafsir-01');
      expect(handler.mediaItem.value?.title, 'درس تفسیر');
      expect(handler.mediaItem.value?.album, kAudioLibraryAlbum);
      expect(handler.mediaItem.value?.artist, 'شیخ ضیایی');
      expect(
        handler.playbackState.value.controls.map((c) => c.action),
        contains(MediaAction.play),
      );

      // A state flip repaints the card immediately — no tick wait.
      fake.playing = true;
      fake.notifyListeners();
      expect(handler.playbackState.value.playing, isTrue);
      expect(
        handler.playbackState.value.controls.map((c) => c.action),
        contains(MediaAction.pause),
      );

      // Buffering follows the player's loading flag.
      fake.loading = true;
      fake.notifyListeners();
      expect(
        handler.playbackState.value.processingState,
        AudioProcessingState.buffering,
      );

      final configureBefore = configureCalls.length;
      await session.stop();
      expect(session.isActive, isFalse);
      expect(
        handler.playbackState.value.processingState,
        AudioProcessingState.idle,
      );

      // The next session reuses the handler: a second AudioService.init
      // would swap a live mushaf session out from under it.
      await session.start(fake);
      expect(session.isActive, isTrue);
      expect(identical(session.debugHandler, handler), isTrue);
      expect(configureCalls.length, configureBefore);
    });
  });

  group('player card surface', () {
    test('the player is the session\'s playback surface', () {
      expect(AudioLibraryPlayer.instance, isA<AudioLibraryMediaPlayback>());
    });

    test('the card surface is inert before any playback', () {
      final player = AudioLibraryPlayer.instance;
      expect(player.activeTrack, isNull);
      expect(player.isPlaying, isFalse);
      expect(player.isLoading, isFalse);
      expect(player.duration, Duration.zero);
      expect(player.activeByline, isNull);
    });

    test('the card transport is a safe no-op before any playback', () async {
      final player = AudioLibraryPlayer.instance;
      await player.resumeActive();
      await player.pauseActive();
    });
  });

  group('background-playback wiring (source guards)', () {
    final screenFile = File(
      'lib/features/audio_library/presentation/screens/'
      'audio_library_screen.dart',
    );
    final playerFile =
        File('lib/features/audio_library/audio_library_player.dart');
    final sessionFile =
        File('lib/features/audio_library/audio_library_media_session.dart');

    test('leaving the library screen no longer stops playback', () {
      expect(screenFile.existsSync(), isTrue,
          reason: 'run from the project root so the sources resolve');
      final source = screenFile.readAsStringSync();
      final disposeStart = source.indexOf('void dispose()');
      final nextMethod = source.indexOf('void _onChanged()');
      expect(disposeStart, greaterThan(0));
      expect(nextMethod, greaterThan(disposeStart));
      final disposeBody = source.substring(disposeStart, nextMethod);
      expect(disposeBody, contains('_player.removeListener(_onChanged)'));
      expect(disposeBody, isNot(contains('.stop(')),
          reason: 'dispose() stopping the player is exactly the '
              'leave-the-section-stops-audio bug');
    });

    test('the player starts the session on play and ends it on stop', () {
      final source = playerFile.readAsStringSync();
      expect(source, contains('implements AudioLibraryMediaPlayback'));
      expect(source, contains('AudioLibraryMediaSession.instance.start(this)'));
      expect(source, contains('AudioLibraryMediaSession.instance.stop()'));
    });

    test('the session ships the library channel and the ±15 s card', () {
      final source = sessionFile.readAsStringSync();
      expect(source, contains("'com.islamic.tawheeed.audio_library.playback'"));
      expect(source, contains('androidNotificationOngoing: true'));
      expect(
        source,
        contains('static const Duration skipStep = Duration(seconds: 15)'),
      );
      expect(source, contains('rewindInterval: skipStep'));
      expect(source, contains('fastForwardInterval: skipStep'));
    });
  });
}

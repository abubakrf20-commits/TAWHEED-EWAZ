import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';

import 'package:tawheeed/features/audio_library/audio_library_manifest.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Everything the media-session layer needs from the audio-library player.
///
/// [AudioLibraryPlayer] implements this directly, so the lock-screen
/// plumbing never reaches into the download/queue machinery — and a test
/// fake can stand in for the player without an audio engine.
abstract interface class AudioLibraryMediaPlayback {
  /// Track loaded into the session (null when nothing is loaded).
  AudioTrack? get activeTrack;

  /// Teacher/speaker line shown under the active track's title (null for
  /// categories that have no common teacher, e.g. اناشید).
  String? get activeByline;

  /// Whether the loaded track is producing sound right now.
  bool get isPlaying;

  /// Whether the loaded track is buffering (stream start / source switch).
  bool get isLoading;

  /// Live playhead of the active track.
  Duration get position;

  /// Seek-bar length: the reported duration, or the persisted fallback while
  /// a streamed track has not reported one yet.
  Duration get duration;

  /// Playback rate (the mini player's speed control).
  double get speed;

  /// Resumes the active (paused) track. No-op when nothing is loaded.
  Future<void> resumeActive();

  /// Pauses the active track (persisting the position). No-op when nothing
  /// is loaded.
  Future<void> pauseActive();

  /// Seeks the active track (the player clamps to a known duration).
  Future<void> seek(Duration position);

  /// Stops the active track entirely; the persisted position is kept.
  Future<void> stop();
}

/// Album line the OS card shows under the title.
const String kAudioLibraryAlbum = 'کتابخانه صوتی';

/// Maps the loaded track onto the media card the OS shows: the lecture
/// title, its teacher line and the seek-bar length the mini player uses.
@visibleForTesting
MediaItem mediaItemForSource(AudioLibraryMediaPlayback source) {
  final track = source.activeTrack;
  return MediaItem(
    id: track?.id ?? '',
    album: kAudioLibraryAlbum,
    title: track?.title ?? '',
    artist: source.activeByline,
    duration: source.duration > Duration.zero ? source.duration : null,
    // No artwork: the library ships no covers, so the default (app icon)
    // beats one network fetch per track.
  );
}

/// Maps the source onto the playbackState the OS media controls read:
/// rewind / play-pause / forward — ±15 s, the mini player's own skip
/// buttons — plus a seek action for the slider. Buffering follows the
/// player's loading flag, so the card dims exactly while a stream starts.
@visibleForTesting
PlaybackState playbackStateForSource(AudioLibraryMediaPlayback source) {
  final playing = source.isPlaying;
  return PlaybackState(
    processingState: source.isLoading
        ? AudioProcessingState.buffering
        : AudioProcessingState.ready,
    controls: [
      MediaControl.rewind,
      playing ? MediaControl.pause : MediaControl.play,
      MediaControl.fastForward,
    ],
    systemActions: const {MediaAction.seek},
    updatePosition: source.position,
    bufferedPosition: source.duration,
    speed: source.speed,
    playing: playing,
  );
}

/// Binds the audio-library player to an `audio_service` handler so a lecture
/// keeps playing when the section closes and when the app leaves the
/// foreground — with play/pause, ±15 s and a seek bar on the lock screen and
/// in the notification.
///
/// Lifecycle: started on every track play (idempotent), kept alive across
/// pause so the card can resume, and ended when the player stops (queue end,
/// sleep timer, or the card's own stop). The handler instance is then reused
/// by the next session — only the first playback in a process runs
/// `AudioService.init`, because the service callbacks are process-global and
/// a second init would swap a live mushaf session out from under it.
///
/// Publishing rule: the card is refreshed the moment something displayable
/// changes (track, play/pause, buffering, duration) and once per second
/// while playing so the slider moves. Sub-second position ticks are dropped
/// — the lock screen must not be repainted at tick rate.
class AudioLibraryMediaSession {
  AudioLibraryMediaSession._();

  static final AudioLibraryMediaSession instance = AudioLibraryMediaSession._();

  AudioLibraryMediaHandler? _handler;
  AudioLibraryMediaPlayback? _source;
  Listenable? _sourceListenable;
  StreamSubscription<void>? _tickSub;
  DateTime _lastPublish = DateTime.fromMillisecondsSinceEpoch(0);
  String? _lastMediaId;
  bool _lastPlaying = false;
  bool _lastLoading = false;
  Duration _lastDuration = Duration.zero;

  /// Whether a card is currently bound to a live playback session.
  bool get isActive => _source != null;

  /// Test seam: the shared handler (null until the first successful init).
  @visibleForTesting
  AudioLibraryMediaHandler? get debugHandler => _handler;

  /// The card's skip step — single-sourced with the config's
  /// `rewindInterval`/`fastForwardInterval` and the mini player's own ±15 s
  /// buttons.
  static const Duration skipStep = Duration(seconds: 15);

  /// The library's own Android channel, so its card can never be conflated
  /// with the mushaf's tilawah/translation cards.
  static const AudioServiceConfig _config = AudioServiceConfig(
    androidNotificationChannelId: 'com.islamic.tawheeed.audio_library.playback',
    androidNotificationChannelName: 'پخش کتابخانه صوتی',
    androidNotificationChannelDescription:
        'کنترل پخش درس‌ها از قفل صفحه و نوار اعلان',
    androidNotificationOngoing: true,
    // The card's ±15 s matches the mini player's own skip buttons.
    rewindInterval: skipStep,
    fastForwardInterval: skipStep,
  );

  /// Starts (or re-binds) the media session for [source].
  ///
  /// Idempotent for the same live source; the first playback of a process
  /// runs `AudioService.init` once, every later session reuses the handler.
  /// Never throws: a platform without the service channel (tests, some
  /// shims) must not crash the library — playback then simply runs without a
  /// lock-screen card.
  Future<void> start(AudioLibraryMediaPlayback source) async {
    if (identical(_source, source) && _handler != null) return;
    _detach();
    _source = source;
    final listenable = source is Listenable ? source as Listenable : null;
    if (listenable != null) {
      _sourceListenable = listenable;
      listenable.addListener(_onSourceChanged);
    }

    var handler = _handler;
    if (handler == null) {
      try {
        handler = await AudioService.init(
          builder: () => AudioLibraryMediaHandler(source),
          config: _config,
        );
        _handler = handler;
      } catch (e) {
        AppLogger.warning(
          'AudioLibraryMediaSession',
          'lock-screen card unavailable: $e',
        );
        _detach();
        return;
      }
    }
    if (!identical(_source, source)) {
      // stop() raced the init: the card is already unwanted, but the handler
      // is kept for the next session.
      return;
    }
    handler._source = source;
    _tickSub = Stream<void>.periodic(
      const Duration(seconds: 1),
    ).listen((_) => _publish());
    _publish(force: true);
    AppLogger.info('AudioLibraryMediaSession', 'media session started');
  }

  /// Ends the session and its card. Playback itself is the player's concern:
  /// it stops first, then this closes the card.
  Future<void> stop() async {
    _detach();
    _lastMediaId = null;
    _lastPlaying = false;
    _lastLoading = false;
    _lastDuration = Duration.zero;
    final handler = _handler;
    if (handler == null) return;
    try {
      await handler.stopCard();
    } catch (e) {
      AppLogger.warning('AudioLibraryMediaSession', 'card stop failed: $e');
    }
  }

  /// Cancels the tick and unbinds the source, keeping the handler for reuse.
  void _detach() {
    _tickSub?.cancel();
    _tickSub = null;
    _sourceListenable?.removeListener(_onSourceChanged);
    _sourceListenable = null;
    _source = null;
  }

  /// The player notifies on every display-relevant change (track, play/pause,
  /// buffering, duration, download progress); the publish gate below keeps
  /// the card from being repainted for the irrelevant ones.
  void _onSourceChanged() => _publish();

  void _publish({bool force = false}) {
    final source = _source;
    final handler = _handler;
    if (source == null || handler == null) return;
    final track = source.activeTrack;
    if (track == null) return;

    final playing = source.isPlaying;
    final loading = source.isLoading;
    final duration = source.duration;

    final now = DateTime.now();
    // Repaint only on display changes: a new track, a play/pause flip, a
    // buffering flip, a duration change, or one second of position progress
    // while playing.
    final secondPassed =
        playing && now.difference(_lastPublish).inMilliseconds >= 900;
    if (!force &&
        track.id == _lastMediaId &&
        playing == _lastPlaying &&
        loading == _lastLoading &&
        duration == _lastDuration &&
        !secondPassed) {
      return;
    }
    _lastPublish = now;
    _lastMediaId = track.id;
    _lastPlaying = playing;
    _lastLoading = loading;
    _lastDuration = duration;

    try {
      handler.mediaItem.add(mediaItemForSource(source));
      handler.playbackState.add(playbackStateForSource(source));
    } catch (e) {
      AppLogger.warning('AudioLibraryMediaSession', 'publish failed: $e');
    }
  }
}

/// The `audio_service` handler: routes lock-screen button presses back into
/// the bound source's own public API, so the queue logic, resume positions
/// and the mini player stay the single source of truth. Public so tests can
/// construct it directly and verify the routing contract.
///
/// The ±15 s buttons deliberately do not use `SeekHandler`: its relative
/// seek clamps against `MediaItem.duration`, which would snap BOTH buttons
/// to 0:00 whenever a streamed track has not reported a duration yet. They
/// measure from the player's live position instead — exactly what the mini
/// player's own skip buttons do.
@visibleForTesting
class AudioLibraryMediaHandler extends BaseAudioHandler {
  AudioLibraryMediaHandler(this._source);

  AudioLibraryMediaPlayback? _source;

  /// Ends the card without touching playback — the path used when the player
  /// already stopped (queue end / in-app stop). Clears the source so the
  /// card's own stop cannot re-enter the player.
  Future<void> stopCard() async {
    _source = null;
    await super.stop();
  }

  @override
  Future<void> play() async {
    await _source?.resumeActive();
    await super.play();
  }

  @override
  Future<void> pause() async {
    await _source?.pauseActive();
    await super.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    await _source?.seek(position);
    await super.seek(position);
  }

  /// The card's ±15 s buttons, measured from the player's live position and
  /// routed through the player's own clamp — matching the mini player.
  @override
  Future<void> fastForward() => _skipBy(AudioLibraryMediaSession.skipStep);

  @override
  Future<void> rewind() =>
      _skipBy(Duration.zero - AudioLibraryMediaSession.skipStep);

  Future<void> _skipBy(Duration delta) async {
    final source = _source;
    if (source == null) return;
    await source.seek(source.position + delta);
  }

  @override
  Future<void> stop() async {
    final source = _source;
    if (source != null) {
      // A card stop must silence the lecture: the X would otherwise leave
      // audio running with no controls anywhere. Clearing the source first
      // breaks the re-entry chain (player.stop() → session.stop() → here).
      _source = null;
      await source.stop();
    }
    await super.stop();
  }
}

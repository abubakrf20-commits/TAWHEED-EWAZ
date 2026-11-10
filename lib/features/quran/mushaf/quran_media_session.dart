import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';

import 'package:tawheeed/shared/utils/app_logger.dart';

/// Which playback the lock-screen card currently mirrors. The mushaf hosts
/// two mutually-exclusive players (recitation and Persian translation);
/// exactly one media session exists and it follows the active one.
enum QuranMediaSource { tilawah, translation }

/// Album line the OS card shows for each source — also pinned by tests.
String albumForSource(QuranMediaSource kind) =>
    kind == QuranMediaSource.tilawah ? 'قرآن کریم' : 'ترجمهٔ فارسی';

/// Everything the media-session layer needs from a playback source.
///
/// Both mushaf controllers (recitation + Persian translation) implement this
/// directly, so the session never needs to know which concrete controller it
/// is mirroring — and a future third source plugs in without touching the
/// audio_service plumbing.
abstract interface class QuranMediaPlayback {
  /// Stable per-verse identifier published as the MediaItem id ("2:255").
  String get activeVerseKey;

  /// Human title for the lock-screen card.
  String get verseLabel;

  bool get isPlaying;
  bool get isLoading;
  Duration get position;
  Duration get duration;
  double get playbackRate;

  Future<void> togglePlayPause();
  Future<void> pause();
  Future<void> nextVerse();
  Future<void> prevVerse();

  /// Whether [seekTo] actually moves the engine. The translation engine
  /// streams one file per verse without seek support, so its card hides the
  /// seek bar instead of advertising a control that does nothing.
  bool get supportsSeek;

  /// Seek inside the current verse; no-op sources implement it as a safe
  /// empty future.
  Future<void> seekTo(Duration position);
}

/// Maps a source onto a [MediaItem] (lock-screen card content).
///
/// Pure so the IDs/titles the session publishes stay pinned by tests: the
/// id is the verse key ("2:255"), the album distinguishes recitation from
/// translation, and the title carries the surah/ayah — the OS surfaces these
/// strings verbatim.
@visibleForTesting
MediaItem mediaItemForSource(
  QuranMediaPlayback source,
  QuranMediaSource kind,
) {
  return MediaItem(
    id: source.activeVerseKey,
    album: albumForSource(kind),
    title: source.verseLabel,
    // No remote artwork: the per-verse CDN path would be another network
    // request per track; the app icon comes from the package by default.
  );
}

/// Maps a source onto the playbackState the OS media controls read:
/// play/pause button state, seek position, and the system action set
/// (skip-to-next/previous drive the verse stepper; seek is only advertised
/// for sources that implement it).
@visibleForTesting
PlaybackState playbackStateForSource(
  QuranMediaPlayback source,
  QuranMediaSource kind, {
  required DateTime Function() clock,
}) {
  final playing = source.isPlaying;
  return PlaybackState(
    // The audio engines report buffering via isLoading; the OS "playing"
    // silhouette follows the real playing flag either way.
    processingState: source.isLoading
        ? AudioProcessingState.buffering
        : AudioProcessingState.ready,
    controls: [
      MediaControl.skipToPrevious,
      playing ? MediaControl.pause : MediaControl.play,
      MediaControl.skipToNext,
    ],
    systemActions: source.supportsSeek && kind == QuranMediaSource.tilawah
        ? const {MediaAction.seek}
        : const {},
    // audioplayers positions are absolute file offsets; position 0 is the
    // ayah start, which is exactly what the lock screen seeks within.
    updatePosition: source.position,
    bufferedPosition: source.duration,
    speed: source.playbackRate,
    playing: playing,
  );
}

/// Binds the active mushaf playback (recitation or Persian translation) to an
/// `audio_service` handler so it keeps playing with full lock-screen /
/// notification controls: play-pause, next/previous *verse*, and a session
/// card naming the surah, ayah and which of the two players is live — without
/// touching the per-ayah audioplayers engines, the queue logic, or the
/// highlight machinery.
///
/// Priority rule: the mushaf view stops the other player before starting one,
/// then re-binds the session with [start]; the session therefore always
/// mirrors exactly the player the user last chose. Re-binding re-runs
/// `AudioService.init`, which swaps the underlying handler — the old card is
/// replaced by the new one on the same notification slot, never duplicated,
/// because each source kind uses its own Android channel id.
///
/// Publishing rule: the session is only refreshed when something the card can
/// *display* changes (verse key, play/pause, buffering flip, duration, or a
/// whole second of position progress). Sub-second position ticks are dropped
/// — the lock screen must not be repainted at tick rate.
class QuranMediaSession {
  QuranMediaSession._();

  static final QuranMediaSession instance = QuranMediaSession._();

  BaseAudioHandler? _handler;
  QuranMediaPlayback? _source;
  QuranMediaSource _kind = QuranMediaSource.tilawah;
  StreamSubscription<void>? _tickSub;
  DateTime _lastPublish = DateTime.fromMillisecondsSinceEpoch(0);
  String _lastMediaKey = '';
  bool _lastPlaying = false;
  bool _lastLoading = false;
  Duration _lastDuration = Duration.zero;

  /// Whether the lock-screen session is currently active.
  bool get isActive => _handler != null;

  /// Which source the session currently mirrors.
  QuranMediaSource get currentSource => _kind;

  static String _channelIdFor(QuranMediaSource kind) =>
      kind == QuranMediaSource.tilawah
          ? 'com.islamic.tawheeed.playback'
          : 'com.islamic.tawheeed.translation.playback';

  static String _channelNameFor(QuranMediaSource kind) =>
      kind == QuranMediaSource.tilawah ? 'پخش قرآن' : 'پخش ترجمهٔ قرآن';

  /// Starts (or re-binds) the media session for the given source.
  ///
  /// Idempotent for the same live source+kind; a *different* source or kind
  /// re-inits the handler so the card follows the newly active player.
  Future<void> start(
    QuranMediaPlayback source, {
    QuranMediaSource kind = QuranMediaSource.tilawah,
  }) async {
    if (identical(_source, source) && _handler != null && _kind == kind) {
      return;
    }
    await _teardownHandler();
    _source = source;
    _kind = kind;

    // Never throws: a platform without the service channel (tests, some
    // shims) must not crash the reader — playback simply runs without the
    // lock-screen card in that case.
    try {
      _handler = await AudioService.init(
        builder: () => QuranMediaHandler(source, kind),
        config: AudioServiceConfig(
          androidNotificationChannelId: _channelIdFor(kind),
          androidNotificationChannelName: _channelNameFor(kind),
          androidNotificationChannelDescription:
              'کنترل پخش از قفل صفحه و نوار اعلان',
          androidNotificationOngoing: true,
        ),
      );
    } catch (e) {
      _handler = null;
      AppLogger.warning('QuranMediaSession', 'init unavailable: $e');
      return;
    }

    _tickSub = Stream<void>.periodic(
      const Duration(seconds: 1),
    ).listen((_) => _publish());
    _publish();
    AppLogger.info('QuranMediaSession', 'media session started ($kind)');
  }

  /// Detaches the source and stops the lock-screen session.
  Future<void> stop() async {
    _tickSub?.cancel();
    _tickSub = null;
    _source = null;
    await _teardownHandler();
  }

  Future<void> _teardownHandler() async {
    _tickSub?.cancel();
    _tickSub = null;
    final handler = _handler;
    _handler = null;
    if (handler != null) {
      try {
        await handler.stop();
      } catch (e) {
        AppLogger.warning('QuranMediaSession', 'handler stop failed: $e');
      }
    }
  }

  void _publish() {
    final source = _source;
    final handler = _handler;
    if (source == null || handler == null) return;

    final key = source.activeVerseKey;
    final playing = source.isPlaying;
    final loading = source.isLoading;
    final duration = source.duration;

    final now = DateTime.now();
    // Repaint the card only on second-level display changes: a new verse, a
    // play/pause flip, a buffering flip, a duration change, or one second of
    // position progress while playing.
    final secondPassed =
        playing && now.difference(_lastPublish).inMilliseconds >= 900;
    if (key == _lastMediaKey &&
        playing == _lastPlaying &&
        loading == _lastLoading &&
        duration == _lastDuration &&
        !secondPassed) {
      return;
    }
    _lastPublish = now;
    _lastMediaKey = key;
    _lastPlaying = playing;
    _lastLoading = loading;
    _lastDuration = duration;

    try {
      handler.mediaItem.add(mediaItemForSource(source, _kind));
      handler.playbackState.add(playbackStateForSource(
        source,
        _kind,
        clock: () => now,
      ));
    } catch (e) {
      AppLogger.warning('QuranMediaSession', 'publish failed: $e');
    }
  }
}

/// The `audio_service` handler: routes lock-screen button presses back into
/// the bound source's own public API. Nothing here talks to the audio engines
/// directly, so rapid-tap guards, per-ayah queueing, highlight ticks and
/// audio-focus behaviour keep their single source of truth. Public + marked
/// visibleForTesting because tests may construct it directly to verify the
/// publishing contract stays pinned.
@visibleForTesting
class QuranMediaHandler extends BaseAudioHandler with SeekHandler {
  QuranMediaHandler(this._source, this._kind);

  final QuranMediaPlayback _source;
  final QuranMediaSource _kind;

  @override
  Future<void> play() async {
    await _source.togglePlayPause();
    await super.play();
  }

  @override
  Future<void> pause() async {
    await _source.pause();
    await super.pause();
  }

  @override
  Future<void> skipToNext() async {
    await _source.nextVerse();
    await super.skipToNext();
  }

  @override
  Future<void> skipToPrevious() async {
    await _source.prevVerse();
    await super.skipToPrevious();
  }

  @override
  Future<void> seek(Duration position) async {
    // Only the per-ayah recitation engine supports scrubbing inside the
    // current ayah; sources without seeking (translation) no-op safely.
    if (_kind == QuranMediaSource.tilawah && _source.supportsSeek) {
      await _source.seekTo(position);
    }
    await super.seek(position);
  }

  @override
  Future<void> stop() async {
    // A session stop (notification dismissed, task removed) only ends the
    // media card; whether the playback continues is the source's call.
    await super.stop();
  }
}

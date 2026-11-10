import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:tawheeed/core/services/app_wakelock.dart';
import 'package:tawheeed/features/quran/mushaf/quran_media_session.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Shared engine under the two per-ayah controllers ([QuranAudioController]
/// for talaawah, [QuranTranslationAudioController] for the Persian
/// translation): one `AudioPlayer`, one serialized native-operation queue,
/// the monotonic session/completion tokens, the playing/rate state, the
/// player subscriptions and the wakelock helpers.
///
/// The two sessions differ (verse repeats and word timings vs the
/// recitation-then-translation phase machine), so everything behavioural —
/// play flows, completion, seeking, stopping — stays in the subclasses.
/// This base owns only the identical machinery, so a fix here (queue
/// discipline, token races, listener leaks) lands in both players at once.
///
/// Subclass state that stays local on purpose: playback position/duration
/// (different tick handling), the loading flag and the last error.
abstract class QuranAudioPlayerBase extends ChangeNotifier
    implements QuranMediaPlayback {
  /// The single native player. Never re-created: both controllers used to
  /// build a fresh `AudioPlayer` per play path, which is what made rapid
  /// session switches race a released player.
  final AudioPlayer player = AudioPlayer();

  Future<void> _playerQueue = Future<void>.value();
  bool _disposed = false;

  int _sessionToken = 0;
  int _completionToken = 0;

  bool _playing = false;
  double _playbackRate = 1.0;

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<void>? _completeSub;
  StreamSubscription<PlayerState>? _stateSub;

  /// True after [markDisposed]; every queued operation re-checks it.
  bool get isDisposed => _disposed;

  int get sessionToken => _sessionToken;

  int get completionToken => _completionToken;

  @override
  bool get isPlaying => _playing;

  @override
  double get playbackRate => _playbackRate;

  /// Serializes native player calls behind the previous one: a `stop`
  /// issued while a `setSource` is still in flight no longer hits the
  /// platform player concurrently with it.
  Future<void> enqueuePlayer(Future<void> Function() operation) {
    final next = _playerQueue.then<void>((_) async {
      if (_disposed) return;
      await operation();
    });
    _playerQueue = next.catchError((_) {});
    return next;
  }

  /// Starts a new playback session, invalidating in-flight work. The caller
  /// captures the returned token and bails out whenever [sessionAlive]
  /// stops holding it, so rapid taps never interleave stop/setSource.
  int beginSession() => ++_sessionToken;

  /// Whether [token] is still the current session of a live controller.
  bool sessionAlive(int token) => !_disposed && token == _sessionToken;

  /// Ends the session (stop paths): completions from the old session are
  /// ignored from here on.
  void invalidateSession() {
    _sessionToken++;
    _completionToken = 0;
  }

  void setCompletionToken(int token) => _completionToken = token;

  void setPlaying(bool value) {
    _playing = value;
  }

  /// Attaches the player listeners (idempotent). Position ticks are
  /// subclass-specific (word timings, highlight clocks), so only the
  /// completion callback is parameterized here; duration and player-state
  /// handling are identical in both controllers.
  void attachPlayerListeners({
    required void Function(Duration position) onPosition,
    required void Function() onComplete,
  }) {
    _posSub ??= player.onPositionChanged.listen(onPosition);
    _durSub ??= player.onDurationChanged.listen((d) {
      if (_disposed) return;
      _duration = d;
      _notify();
    });
    _completeSub ??= player.onPlayerComplete.listen((_) => onComplete());
    _stateSub ??= player.onPlayerStateChanged.listen((s) {
      if (_disposed) return;
      // Through setPlaying so subclass overrides observe engine transitions.
      setPlaying(s == PlayerState.playing);
      _notify();
    });
  }

  Duration _duration = Duration.zero;

  @override
  Duration get duration => _duration;

  /// Clears the last known media duration (verse switches show no duration
  /// until the new source reports its own).
  void resetDuration() {
    _duration = Duration.zero;
  }

  void cancelPlayerListeners() {
    _posSub?.cancel();
    _durSub?.cancel();
    _completeSub?.cancel();
    _stateSub?.cancel();
    _posSub = null;
    _durSub = null;
    _completeSub = null;
    _stateSub = null;
  }

  /// Pauses playback when playing (audio-focus interruptions, headset
  /// unplug). Resumable — session state is untouched.
  @override
  Future<void> pause() async {
    if (_disposed || !_playing) return;
    try {
      await enqueuePlayer(player.pause);
    } catch (e) {
      AppLogger.warning('quran_audio_player_base', 'pause failed: $e');
    }
  }

  /// Sets the playback speed (0.5×–2×).
  Future<void> setPlaybackRate(double rate) async {
    if (_disposed) return;
    _playbackRate = rate.clamp(0.5, 2.0);
    try {
      await enqueuePlayer(() => player.setPlaybackRate(_playbackRate));
    } catch (e) {
      AppLogger.warning(
          'quran_audio_player_base', 'set playback rate failed: $e');
    }
    _notify();
  }

  Future<void> acquireWakelock(String tag) async {
    try {
      await AppWakelock.acquire(tag);
    } catch (e) {
      AppLogger.warning(
          'quran_audio_player_base', 'wakelock enable failed: $e');
    }
  }

  Future<void> releaseWakelock(String tag) async {
    try {
      await AppWakelock.release(tag);
    } catch (e) {
      AppLogger.warning(
          'quran_audio_player_base', 'wakelock release failed: $e');
    }
  }

  /// Marks the controller disposed and stops the native player behind any
  /// in-flight operation (disposing mid-setSource crashes some Android
  /// players). Subclasses run their own teardown first, then call this,
  /// then `super.dispose()`.
  Future<void> disposePlayer() {
    _disposed = true;
    invalidateSession();
    cancelPlayerListeners();
    final cleanup = _playerQueue.then<void>((_) async {
      try {
        await player.stop();
      } catch (e) {
        AppLogger.warning(
            'quran_audio_player_base', 'player stop on dispose failed: $e');
      }
      try {
        await player.dispose();
      } catch (e) {
        AppLogger.warning(
            'quran_audio_player_base', 'player dispose failed: $e');
      }
    });
    _playerQueue = cleanup.catchError((_) {});
    return cleanup;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}

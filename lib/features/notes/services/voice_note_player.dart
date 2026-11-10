import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/features/quran/mushaf/quran_audio_focus.dart';

/// Single-file voice-note playback for the notes list.
///
/// One player is shared app-wide so tapping a second note stops the first
/// instead of mixing two clips. Callers listen for changes and read
/// [playingPath] to know which row shows the "stop" icon.
class VoiceNotePlayer extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  /// Detaches the platform audio-focus subscriptions.
  void Function()? _detachAudioFocus;

  /// Serializes every native player operation (Audit 9-C): interleaved
  /// stop/play on rapid taps used to hit the native player concurrently.
  Future<void> _playerQueue = Future<void>.value();

  Future<void> _enqueuePlayer(Future<void> Function() operation) {
    final next = _playerQueue.then<void>((_) async {
      if (_disposed) return;
      await operation();
    });
    _playerQueue = next.catchError((_) {});
    return next;
  }

  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<void>? _doneSub;

  String _playingPath = '';
  bool _playing = false;
  bool _loading = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _error;

  /// Absolute path of the clip currently loaded, '' when idle.
  String get playingPath => _playingPath;
  bool get isPlaying => _playing;
  bool get isLoading => _loading;
  Duration get position => _position;
  Duration get duration => _duration;
  String? get error => _error;

  /// Position for [path] — live while it plays, 0 for any other note.
  Duration positionOf(String path) =>
      path.isNotEmpty && path == _playingPath ? _position : Duration.zero;

  /// Duration for [path]; falls back to the note's stored duration when the
  /// file is not loaded yet.
  Duration durationOf(String path, Duration fallback) {
    if (path.isEmpty || path != _playingPath) return fallback;
    return _duration > Duration.zero ? _duration : fallback;
  }

  bool isActive(String path) => path.isNotEmpty && path == _playingPath;

  void _bind() {
    _stateSub ??= _player.onPlayerStateChanged.listen((state) {
      _playing = state == PlayerState.playing;
      if (state == PlayerState.completed) {
        _playing = false;
        _position = Duration.zero;
      }
      _notify();
    });
    _posSub ??= _player.onPositionChanged.listen((pos) {
      if (!_disposed) {
        _position = pos;
        _notify();
      }
    });
    _durSub ??= _player.onDurationChanged.listen((dur) {
      if (!_disposed) {
        _duration = dur;
        _notify();
      }
    });
    _doneSub ??= _player.onPlayerComplete.listen((_) {
      if (_disposed) return;
      _playing = false;
      _position = Duration.zero;
      _notify();
    });
  }

  bool _disposed = false;

  /// Attaches platform focus handling (headset-unplug, calls) once.
  void _attachAudioFocus() {
    if (_detachAudioFocus != null || _disposed) return;
    unawaited(attachVoiceNoteAudioFocus(
      onPause: stop,
      isPlaying: () => _playing && !_disposed,
    ).then((detach) => _detachAudioFocus = detach));
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Toggles [path]; tapping the playing note stops it.
  Future<void> toggle(String path) async {
    if (path.isEmpty) return;
    if (path == _playingPath && (_playing || _loading)) {
      await stop();
      return;
    }
    await play(path);
  }

  Future<void> play(String path) async {
    if (path.isEmpty) return;
    final file = File(path);
    if (!await file.exists()) {
      _error = 'فایل صوتی یافت نشد';
      _notify();
      return;
    }
    _bind();
    _attachAudioFocus();
    _error = null;
    _loading = true;
    _playingPath = path;
    _position = Duration.zero;
    _duration = Duration.zero;
    _notify();
    try {
      await _enqueuePlayer(() async {
        await _player.stop();
        await _player.play(DeviceFileSource(path));
      });
    } catch (e) {
      AppLogger.error('voice_note_player', e);
      _error = 'پخش صدا ممکن نشد';
      _loading = false;
      _playing = false;
      // Audit 9-C: a failed load left _playingPath pointing at the note
      // forever — the row kept the stop icon and [toggle] then hit its
      // same-path branch instead of retrying on the next tap.
      _playingPath = '';
    }
    _loading = false;
    _notify();
  }

  Future<void> stop() async {
    try {
      await _enqueuePlayer(_player.stop);
    } catch (e) {
      AppLogger.warning('voice_note_player', 'stop failed: $e');
    }
    _playing = false;
    _loading = false;
    _position = Duration.zero;
    _playingPath = '';
    _notify();
  }

  Future<void> seek(Duration to) async {
    if (!isActive(_playingPath)) return;
    try {
      await _player.seek(to);
      _position = to;
    } catch (e) {
      AppLogger.warning('voice_note_player', 'seek failed: $e');
    }
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _stateSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _doneSub?.cancel();
    try {
      _detachAudioFocus?.call();
    } catch (e) {
      AppLogger.warning('voice_note_player', 'focus detach failed: $e');
    }
    _detachAudioFocus = null;
    // Stop before dispose — same native-safety rule as the Quran
    // controllers (disposing a MediaPlayer mid-playback can crash).
    unawaited(() async {
      try {
        await _player.stop();
      } catch (e) {
        AppLogger.warning('voice_note_player', 'dispose stop failed: $e');
      }
      try {
        await _player.dispose();
      } catch (e) {
        AppLogger.warning('voice_note_player', 'dispose failed: $e');
      }
    }());
    super.dispose();
  }
}

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tawheeed/shared/utils/alert_volume.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// One preview player for every sound picker in the app.
///
/// The reminder editor used to build a throw-away [AudioPlayer] per tap and
/// dispose it in a `finally` right after `play()` returned — `play()` only
/// means "started", so the dispose raced the first audio buffer: sometimes the
/// tone was audible, sometimes it was cut before it began, and there was never
/// a way to stop a long clip once it did start.
///
/// This service keeps ONE player alive, stops the previous preview before
/// starting the next, and exposes [playingKey] so a row can show play/stop.
/// Phone tones (`content://` URIs) are delegated to the native preview player
/// because they are not file paths audioplayers can open reliably.
class SoundPreviewService extends ChangeNotifier {
  SoundPreviewService._();

  static final SoundPreviewService instance = SoundPreviewService._();

  static const MethodChannel _channel = MethodChannel('com.tawheeed/azan');

  AudioPlayer? _player;
  StreamSubscription<void>? _doneSub;
  String? _playingKey;
  bool _disposed = false;

  /// Native previews have no completion callback on the Dart side, so the
  /// service polls until the MediaPlayer reports idle. [_nativeObserved] keeps
  /// a not-yet-prepared player from being mistaken for a finished one.
  Timer? _nativeWatch;
  bool _nativeObserved = false;
  int _nativeMisses = 0;

  /// Serializes start/stop so rapid taps cannot interleave native calls.
  Future<void> _queue = Future<void>.value();

  /// The key of the sound currently previewing, or null.
  String? get playingKey => _playingKey;

  bool isPlaying(String key) => _playingKey == key;

  Future<void> _enqueue(Future<void> Function() work) {
    final next = _queue.then<void>((_) async {
      if (_disposed) return;
      await work();
    });
    _queue = next.catchError((_) {});
    return next;
  }

  /// Plays [key], or stops it when it is already the active preview.
  ///
  /// Exactly one of [asset] (bundled, e.g. `sounds/notif.ogg`), [file]
  /// (absolute path) or [systemUri] (a phone tone) should be given.
  Future<bool> toggle({
    required String key,
    String? asset,
    String? file,
    String? systemUri,
    bool alarm = false,
  }) async {
    if (_playingKey == key) {
      await stop();
      return false;
    }
    var ok = false;
    await _enqueue(() async {
      await _stopLocked();
      try {
        if (systemUri != null) {
          final result = await _channel.invokeMethod<bool>(
            'previewSystemSound',
            {'uri': systemUri, 'alarm': alarm},
          );
          if (result == false) {
            throw StateError('پخش این صدا ممکن نشد');
          }
          _startNativeWatch(key);
        } else {
          final player = _player ??= AudioPlayer();
          await player.setVolume(await AlertVolume.get());
          if (asset != null) {
            await player.play(AssetSource(asset));
          } else if (file != null) {
            await player.play(DeviceFileSource(file));
          } else {
            throw StateError('منبع صدا مشخص نیست');
          }
          _doneSub ??= player.onPlayerComplete.listen((_) {
            _playingKey = null;
            _safeNotify();
          });
        }
        _playingKey = key;
        ok = true;
      } catch (e) {
        AppLogger.warning('SoundPreview', 'preview $key failed: $e');
        _playingKey = null;
        ok = false;
      }
    });
    _safeNotify();
    return ok;
  }

  /// Stops whichever preview is running (in-app or native).
  Future<void> stop() async {
    await _enqueue(_stopLocked);
    _safeNotify();
  }

  Future<void> _stopLocked() async {
    _nativeWatch?.cancel();
    _nativeWatch = null;
    final player = _player;
    if (player != null) {
      try {
        await player.stop();
      } catch (e) {
        AppLogger.warning('SoundPreview', 'stop player failed: $e');
      }
    }
    try {
      await _channel.invokeMethod('stopPreviewSound');
    } catch (_) {
      // No native player attached, or a test/platform without the channel.
    }
    _playingKey = null;
  }

  /// Watches a native preview until it finishes (or never starts). A short
  /// ringtone ends without telling Dart, so without this the row would keep
  /// its stop icon forever.
  void _startNativeWatch(String key) {
    _nativeWatch?.cancel();
    _nativeObserved = false;
    _nativeMisses = 0;
    _nativeWatch = Timer.periodic(const Duration(milliseconds: 700), (_) async {
      if (_disposed || _playingKey != key) {
        _nativeWatch?.cancel();
        _nativeWatch = null;
        return;
      }
      try {
        final playing = await _channel.invokeMethod<bool>(
              'isPreviewSoundPlaying',
            ) ??
            false;
        if (playing) {
          _nativeObserved = true;
          _nativeMisses = 0;
          return;
        }
        _nativeMisses++;
        // Give a slow MediaPlayer preparation a few seconds before calling a
        // preview that never started "finished".
        if (!_nativeObserved && _nativeMisses < 4) return;
        _nativeWatch?.cancel();
        _nativeWatch = null;
        if (_playingKey == key) {
          _playingKey = null;
          _safeNotify();
        }
      } catch (_) {
        // No native preview channel (tests) — stop watching and leave idle.
        _nativeWatch?.cancel();
        _nativeWatch = null;
      }
    });
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  /// Releases the preview player. The app keeps the singleton for its whole
  /// lifetime, so this is only for tests.
  void disposePlayer() {
    _disposed = true;
    _nativeWatch?.cancel();
    _nativeWatch = null;
    _doneSub?.cancel();
    _doneSub = null;
    final player = _player;
    _player = null;
    unawaited(() async {
      try {
        await player?.stop();
        await player?.dispose();
      } catch (_) {
        // Best-effort teardown of a test-only player.
      }
    }());
  }

  @override
  void dispose() {
    disposePlayer();
    super.dispose();
  }
}

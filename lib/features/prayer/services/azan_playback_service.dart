import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Plays the azan audio (in-app MediaPlayer path: raw asset → system player,
/// volume-key stop, operation queue).
///
/// NOT the bookkeeping service: `shared/services/azan_service.dart` only
/// tracks which prayers already fired today and cancels the redundant silent
/// reminder; it never plays audio.
class AzanPlaybackService {
  static final AzanPlaybackService instance = AzanPlaybackService._();

  AzanPlaybackService._();

  factory AzanPlaybackService() => instance;

  static const _platform = MethodChannel('com.tawheeed/azan');
  AudioPlayer? _player;
  Future<void> _operationQueue = Future<void>.value();
  int _playToken = 0;
  bool _disposed = false;
  bool _volumeKeyListenerInstalled = false;
  bool Function(KeyEvent)? _volumeKeyHandler;

  /// Resolves a bundled adhan through the native side, which copies the
  /// `res/raw` file into the cache once. The Flutter asset copies were deleted:
  /// the same two MP3s ship only as Android resources (2.3 MB saved).
  Future<String> _bundledAzanPath(String sound) async {
    final path =
        await _platform.invokeMethod<String>('bundledAzanPath', {'sound': sound});
    if (path == null || path.isEmpty) {
      throw StateError('صدای اذان داخلی در دسترس نیست.');
    }
    return path;
  }

  /// Installs a one-shot hardware keyboard listener that stops Dart-side
  /// azan playback on ANY volume key press.  Only installed once and auto-
  /// removes itself after the first trigger or when the player stops.
  void _installVolumeKeyListener() {
    if (_volumeKeyListenerInstalled || _disposed) return;
    _volumeKeyListenerInstalled = true;
    _volumeKeyHandler = (KeyEvent event) {
      if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
      if (event.logicalKey == LogicalKeyboardKey.audioVolumeUp ||
          event.logicalKey == LogicalKeyboardKey.audioVolumeDown ||
          event.logicalKey == LogicalKeyboardKey.audioVolumeMute) {
        _removeVolumeKeyListener();
        AppLogger.info('AzanPlaybackService',
            'Volume key detected (Dart path), stopping azan');
        unawaited(stop());
        return true;
      }
      return false;
    };
    HardwareKeyboard.instance.addHandler(_volumeKeyHandler!);
  }

  void _removeVolumeKeyListener() {
    if (!_volumeKeyListenerInstalled) return;
    _volumeKeyListenerInstalled = false;
    final h = _volumeKeyHandler;
    _volumeKeyHandler = null;
    if (h != null) HardwareKeyboard.instance.removeHandler(h);
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final next = _operationQueue.then<void>((_) async {
      if (_disposed) return;
      await operation();
    });
    _operationQueue = next.catchError((_) {});
    return next;
  }

  Future<bool> _supportsForegroundService() async {
    try {
      await _platform.invokeMethod('isPlaying');
      return true;
    } catch (e) {
      AppLogger.warning(
          'AzanPlaybackService', 'Foreground service not available: $e');
      return false;
    }
  }

  Future<void> playAzan(AppSettings settings) async {
    if (_disposed) return;
    final token = ++_playToken;
    try {
      await _enqueue(() async {
        if (token != _playToken) return;
        final supportsFg = await _supportsForegroundService();
        if (token != _playToken) return;
        final isCustom = settings.azanSound == 'custom';
        if (supportsFg) {
          final customPath = settings.customAzanPath;
          if (isCustom && (customPath == null || customPath.isEmpty)) {
            throw StateError(
                'فایل اذان شخصی یافت نشد؛ لطفاً دوباره انتخاب کنید.');
          }
          await _platform.invokeMethod('playAzan', {
            if (isCustom) 'source': customPath,
            'isAsset': !isCustom,
            'sound': settings.azanSound,
            'volume': settings.azanVolume,
          });
          return;
        }

        final previous = _player;
        _player = null;
        if (previous != null) {
          try {
            await previous.stop();
          } catch (e) {
            AppLogger.warning(
                'AzanPlaybackService', 'stop previous failed: $e');
          }
          try {
            await previous.dispose();
          } catch (e) {
            AppLogger.warning(
                'AzanPlaybackService', 'dispose previous failed: $e');
          }
        }
        if (token != _playToken || _disposed) return;

        final player = AudioPlayer();
        _player = player;
        _installVolumeKeyListener();
        try {
          await player.setAudioContext(AudioContext(
            android: const AudioContextAndroid(
              usageType: AndroidUsageType.alarm,
              contentType: AndroidContentType.sonification,
              stayAwake: true,
            ),
          ));
          // The adhan volume governs a custom file too; previously only the
          // asset branch honoured it, so a custom adhan always played at 100 %.
          await player.setVolume(settings.azanVolume);
          if (isCustom) {
            final customPath = settings.customAzanPath;
            if (customPath == null || !await File(customPath).exists()) {
              throw StateError(
                  'فایل اذان شخصی یافت نشد؛ لطفاً دوباره انتخاب کنید.');
            }
            await player.play(DeviceFileSource(customPath));
          } else {
            final path = await _bundledAzanPath(settings.azanSound);
            await player.play(DeviceFileSource(path));
          }
        } catch (_) {
          AppLogger.warning('azan_playback', 'operation failed');
          if (identical(_player, player)) _player = null;
          try {
            await player.dispose();
          } catch (e) {
            AppLogger.warning('AzanPlaybackService', 'dispose failed: $e');
          }
          rethrow;
        }
      });
    } catch (e) {
      AppLogger.warning(
          'azan_playback', 'AzanPlaybackService.playAzan error: $e');
    }
  }

  Future<void> stop() async {
    if (_disposed) return;
    _playToken++;
    _removeVolumeKeyListener();
    try {
      await _enqueue(() async {
        try {
          await _platform.invokeMethod('stopAzan');
        } catch (e) {
          AppLogger.error('AzanPlaybackService.stop', e);
        }
        final player = _player;
        _player = null;
        if (player != null) {
          try {
            await player.stop();
          } catch (e) {
            AppLogger.warning('AzanPlaybackService', 'stop failed: $e');
          }
        }
      });
    } catch (e) {
      AppLogger.warning('AzanPlaybackService', 'azan stream setup failed: $e');
    }
  }

  Future<void> testSound(AppSettings settings, BuildContext context) async {
    final player = AudioPlayer();
    // Local volume-key listener: stop the test preview on any volume button.
    bool keyListenerActive = true;
    bool handler(KeyEvent event) {
      if (!keyListenerActive) return false;
      if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
      if (event.logicalKey == LogicalKeyboardKey.audioVolumeUp ||
          event.logicalKey == LogicalKeyboardKey.audioVolumeDown ||
          event.logicalKey == LogicalKeyboardKey.audioVolumeMute) {
        keyListenerActive = false;
        HardwareKeyboard.instance.removeHandler(handler);
        unawaited(player.stop());
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('پخش اذان متوقف شد'),
              duration: Duration(milliseconds: 600),
            ),
          );
        }
        return true;
      }
      return false;
    }

    HardwareKeyboard.instance.addHandler(handler);
    try {
      await player.setVolume(settings.azanVolume);
      if (settings.azanSound == 'custom') {
        final customPath = settings.customAzanPath;
        if (customPath == null || !await File(customPath).exists()) {
          throw StateError(
              'فایل اذان شخصی یافت نشد؛ لطفاً دوباره انتخاب کنید.');
        }
        await player.play(DeviceFileSource(customPath));
      } else {
        final path = await _bundledAzanPath(settings.azanSound);
        await player.play(DeviceFileSource(path));
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('در حال پخش اذان...'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      unawaited(player.onPlayerComplete.first.then((_) async {
        keyListenerActive = false;
        HardwareKeyboard.instance.removeHandler(handler);
        try {
          await player.dispose();
        } catch (e) {
          AppLogger.warning(
              'AzanPlaybackService', 'complete-dispose failed: $e');
        }
      }));
    } catch (e) {
      AppLogger.warning('azan_playback', 'error: $e');
      keyListenerActive = false;
      HardwareKeyboard.instance.removeHandler(handler);
      try {
        await player.dispose();
      } catch (e2) {
        AppLogger.warning('AzanPlaybackService', 'error-dispose failed: $e2');
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('پخش صدای اذان ممکن نشد؛ دوباره تلاش کنید.')),
        );
      }
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _playToken++;
    unawaited(() async {
      await _operationQueue;
      final player = _player;
      _player = null;
      if (player != null) {
        try {
          await player.stop();
        } catch (e) {
          AppLogger.warning('AzanPlaybackService', 'stop failed: $e');
        }
        try {
          await player.dispose();
        } catch (e) {
          AppLogger.warning('AzanPlaybackService', 'dispose failed: $e');
        }
      }
    }());
  }
}

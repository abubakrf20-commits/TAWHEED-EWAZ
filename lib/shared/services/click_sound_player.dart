import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Reliable short UI click sound for tasbih.
///
/// Steady-state design: ONE [AudioPool] of preloaded SoundPool players is
/// built at warm-up and never touched again. A tap only reserves a player,
/// sets the volume and resumes — three cheap calls, zero object creation,
/// zero file I/O, zero load/unload churn. A short timer returns the player
/// to the pool after the click has finished (upstream [AudioPool] only
/// recycles through the stop callback it hands out, and in low-latency mode
/// there is no completion event, so without the timer every tap would leak
/// a platform player).
///
/// This replaces the previous rotate-and-replace pool, whose per-tap
/// create/dispose cycle (half a dozen platform calls plus SoundPool
/// load/unload churn on EVERY tap) congested the method channel on bursts —
/// the lag and the eventual silence users reported. The SoundPool sound
/// itself stays loaded for the whole session now, so the
/// load-while-playing race is gone too.
///
/// Volume is applied per tap (setVolume→resume): in lowLatency mode a
/// setVolume before the first play is a no-op on the native side, but the
/// play call itself carries the requested level, so the proven order stays.
class ClickSoundPlayer {
  ClickSoundPlayer(this._assetPath, {int poolSize = 8})
      : _poolSize = poolSize.clamp(1, 8) {
    // Fire-and-forget warm-up so the first audible tap isn't silent.
    _creating = _create();
  }

  final String _assetPath;
  final int _poolSize;

  /// The ready pool, or null while it is being built / when the last build
  /// failed. A play that finds no pool retries the build at most once per
  /// [retryCooldown], so a transient failure at app start heals instead of
  /// silencing the click for the whole session.
  Future<AudioPool?>? _creating;
  DateTime? _lastBuildAttempt;
  static const retryCooldown = Duration(seconds: 5);

  /// The click is ~60 ms; the player goes back to the pool comfortably
  /// after it has finished, keeping up to poolSize/0.12 ≈ 60 taps/sec —
  /// far beyond human tapping — with zero steady-state allocation.
  static const _recycleAfter = Duration(milliseconds: 120);

  bool _disposed = false;

  Future<AudioPool?> _create() async {
    _lastBuildAttempt = DateTime.now();
    try {
      return await AudioPool.create(
        source: AssetSource(_assetPath),
        minPlayers: _poolSize,
        maxPlayers: _poolSize,
        playerMode: PlayerMode.lowLatency,
        audioContext: _audioContext,
      );
    } catch (e) {
      AppLogger.warning('ClickSound', 'pool create failed: $e');
      return null;
    }
  }

  /// Preloads the asset and fills the pool so the first audible tap is not
  /// silent. Failures are non-fatal: play() retries the build on cooldown.
  Future<void> warmUp() async {
    try {
      await (_creating ?? Future<void>.value());
    } catch (_) {
      // _create already logged any failure; warmUp only awaits priming.
    }
  }

  Future<void> play([double volume = 1.0]) async {
    if (_disposed) return;
    final creating = _creating;
    if (creating == null) return;
    AudioPool? pool;
    try {
      pool = await creating;
    } catch (_) {
      // _create already logged; fall through to the cooldown retry below.
    }
    if (_disposed) return;
    if (pool == null) {
      final last = _lastBuildAttempt;
      if (last == null ||
          DateTime.now().difference(last) >= retryCooldown) {
        _creating = _create();
      }
      return;
    }

    try {
      final stop = await pool.start(volume: volume.clamp(0.0, 1.0));
      Timer(_recycleAfter, () {
        _recycle(stop);
      });
    } catch (e) {
      AppLogger.warning('ClickSound', 'play failed: $e');
    }
  }

  Future<void> _recycle(StopFunction stop) async {
    if (_disposed) return;
    try {
      await stop();
    } catch (_) {
      // A recycle racing dispose() tears down an already-dead player —
      // harmless by design, never worth a log line per tap.
    }
  }

  AudioContext get _audioContext => AudioContext(
        android: const AudioContextAndroid(
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.assistanceSonification,
          audioFocus: AndroidAudioFocus.none,
        ),
        iOS: AudioContextIOS(
          options: {AVAudioSessionOptions.mixWithOthers},
        ),
      );

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final creating = _creating;
    _creating = null;
    if (creating == null) return;
    try {
      final pool = await creating;
      await pool?.dispose();
    } catch (e) {
      AppLogger.warning('ClickSound', 'pool dispose failed: $e');
    }
  }
}

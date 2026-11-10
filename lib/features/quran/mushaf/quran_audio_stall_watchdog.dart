import 'dart:async';

/// Surfaces a frozen playback position while the player claims to be
/// playing — the streamed-verse stall the device pass caught: the mini
/// player kept an honest «playing» face over a clock frozen at 00:06 with
/// no engine error, because the failure was the network, not the player.
///
/// Surfacing only: the watchdog never touches the player. While
/// [setPlaying] holds true and [onPosition] has not reported an advance
/// for [stallAfter], [isStalled] turns true and [onStalled] fires once;
/// any advance (including a seek or a new verse's 0:00) or any pause
/// clears it. Identical position values do not count as progress — the
/// platform keeps ticking a starved buffer at the same millisecond.
class AudioStallWatchdog {
  AudioStallWatchdog({
    DateTime Function()? now,
    this.onStalled,
    this.stallAfter = const Duration(seconds: 8),
    Duration tick = const Duration(seconds: 2),
  })  : _now = now ?? DateTime.now,
        _tick = tick;

  final DateTime Function() _now;
  final void Function(bool stalled)? onStalled;
  final Duration stallAfter;
  final Duration _tick;

  Timer? _timer;
  bool _playing = false;
  bool _stalled = false;
  Duration? _lastPosition;
  DateTime _lastAdvance = DateTime.fromMillisecondsSinceEpoch(0);

  /// True while playing but frozen past [stallAfter].
  bool get isStalled => _stalled;

  void setPlaying(bool playing) {
    if (_playing == playing) return;
    _playing = playing;
    if (playing) {
      _lastPosition = null;
      _lastAdvance = _now();
      _clearStall();
      _timer ??= Timer.periodic(_tick, (_) => checkNow());
    } else {
      _timer?.cancel();
      _timer = null;
      _clearStall();
    }
  }

  /// Feeds one position tick. A changed value is progress; an unchanged
  /// value is deliberately ignored so the periodic check can fire.
  void onPosition(Duration position) {
    if (!_playing) return;
    if (_lastPosition != null && position == _lastPosition) return;
    _lastPosition = position;
    _lastAdvance = _now();
    _clearStall();
  }

  /// One stall evaluation — driven by the periodic timer in production;
  /// tests call it directly with the injected clock.
  void checkNow() {
    if (!_playing || _stalled) return;
    if (_now().difference(_lastAdvance) >= stallAfter) {
      _stalled = true;
      onStalled?.call(true);
    }
  }

  void _clearStall() {
    if (_stalled) {
      _stalled = false;
      onStalled?.call(false);
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

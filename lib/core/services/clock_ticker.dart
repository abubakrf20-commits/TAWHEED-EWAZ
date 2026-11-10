import 'dart:async';

import 'package:flutter/widgets.dart';

/// One shared ticker for the whole app: fires on every second boundary and
/// stops entirely while the app is in the background.
///
/// - [second] drives per-second UI (countdowns).
/// - [minute] only notifies when the minute changed (clock tiles, phase
///   re-evaluation) so per-minute consumers never rebuild per second.
class ClockTicker with WidgetsBindingObserver {
  /// [autoStart] = false builds an idle ticker that never schedules — for
  /// widget tests and previews, where a recurring second-boundary timer
  /// would outlive the tree and fail the test framework's pending-timer
  /// invariant.
  ClockTicker({bool autoStart = true}) : _autoStart = autoStart {
    if (_autoStart) {
      WidgetsBinding.instance.addObserver(this);
      _start();
    }
  }

  /// Never schedules. Its notifiers still accept manual writes.
  ClockTicker.idle() : this(autoStart: false);

  final bool _autoStart;

  final ValueNotifier<DateTime> second = ValueNotifier(DateTime.now());

  /// Only notifies when the minute (or hour/day) changed.
  final ValueNotifier<DateTime> minute = ValueNotifier(DateTime.now());

  Timer? _timer;

  void _start() {
    _timer?.cancel();
    _tick();
    _scheduleNext();
  }

  void _scheduleNext() {
    final ms = 1000 - DateTime.now().millisecond;
    _timer = Timer(Duration(milliseconds: ms), () {
      _tick();
      _scheduleNext();
    });
  }

  void _tick() {
    final n = DateTime.now();
    second.value = n;
    final m = minute.value;
    if (n.minute != m.minute || n.hour != m.hour || n.day != m.day) {
      minute.value = n;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_autoStart) return;
    if (state == AppLifecycleState.resumed) {
      _start();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    second.dispose();
    minute.dispose();
  }
}

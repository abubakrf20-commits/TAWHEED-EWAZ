import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the «دورهٔ ماهانه» PIN has been entered during this app session.
///
/// The lock itself is a preference (`period_locked`, surfaced as
/// `PeriodState.isLocked`); this remembers only that it was passed, so
/// re-entering the tool does not ask twice. It exists beside
/// [vaultSessionProvider] rather than reusing it because the two tools have
/// separate codes.
///
/// Before this existed the proof of unlock lived in the screen's own
/// `StatefulWidget`, so backgrounding the app — or the recents switcher — left
/// every record, date and note on screen: the code protected the door, not the
/// room. Going to the background now costs a re-entry.
class PeriodSessionNotifier extends Notifier<bool> with WidgetsBindingObserver {
  @override
  bool build() {
    // `inactive` (an incoming call, the notification shade) is deliberately not
    // a trigger: it must not lock a form the user is halfway through.
    WidgetsBinding.instance.removeObserver(this);
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() => WidgetsBinding.instance.removeObserver(this));
    return false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      lock();
    }
  }

  void unlock() => state = true;

  void lock() {
    if (state) state = false;
  }
}

final periodSessionProvider =
    NotifierProvider<PeriodSessionNotifier, bool>(PeriodSessionNotifier.new);

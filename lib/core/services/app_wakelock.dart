import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:wakelock_plus/wakelock_plus.dart';

/// Ref-counted wrapper around the global screen wakelock.
///
/// WakelockPlus owns ONE system-wide flag: a bare `disable()` from any screen
/// (e.g. leaving قبله‌نما) used to kill the wake lock held by audio playback
/// or the pomodoro timer. Every owner must acquire/release through here with a
/// stable key; the native lock is only dropped when the last owner lets go.
class AppWakelock {
  AppWakelock._();

  static final Set<String> _owners = {};

  /// Test-only view of the currently held owners.
  ///
  /// A release that never runs is invisible on a phone until the screen simply
  /// stops sleeping — hours later, with no error anywhere. Every owner's
  /// acquire/release pairing must therefore be observable in a test; the
  /// guards are:
  /// - test/features/tools/pomodoro/pomodoro_screen_test.dart (mode switch +
  ///   dispose), which caught the guard that made a release unreachable.
  @visibleForTesting
  static Set<String> debugOwners() => Set.unmodifiable(_owners);

  static Future<void> acquire(String owner) async {
    if (_owners.add(owner)) {
      await WakelockPlus.enable();
    }
  }

  static Future<void> release(String owner) async {
    if (_owners.remove(owner) && _owners.isEmpty) {
      await WakelockPlus.disable();
    }
  }
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/shared/utils/app_logger.dart';

/// Cold-start initialisation, kept off the `runApp` path.
///
/// Splash redesign: `main()` used to await Firebase, the notification stack,
/// the 2.5 MB Quran decode and the Dorar database copy *before* calling
/// `runApp`, so the first frame could not exist until the slowest of them
/// finished — on a weak phone that is a blank window, not a splash. Now
/// `runApp` runs first and [start] fires on the first frame, while the splash
/// waits on [ready].
///
/// The gate stays the SAME set of stages it always was: Home is never shown
/// over a half-loaded app, because a provider that reads the Quran corpus at
/// its first build would cache the empty result until the next invalidation.
/// What moved is only *when* the clock starts, which is what the user sees.
class AppBootstrap {
  AppBootstrap({this.phases = const []});

  /// A batch that is already finished — the provider default, so a test or
  /// any path outside a cold start never waits on phases that were never
  /// made.
  AppBootstrap.immediate() : phases = const [] {
    _started = true;
    if (!_done.isCompleted) _done.complete();
  }

  /// Each phase is expected to guard itself with `runStartupPhase`; the
  /// bootstrap adds its own net so a phase that escapes cannot reject
  /// [ready] and leave the splash with no way forward.
  final List<Future<void> Function()> phases;

  final Completer<void> _done = Completer<void>();
  bool _started = false;

  bool get started => _started;

  /// Completes when every phase has settled, successfully or not.
  Future<void> get ready => _done.future;

  /// Kicks the batch off in parallel. Idempotent, and never throws.
  void start() {
    if (_started) return;
    _started = true;
    unawaited(() async {
      try {
        await Future.wait(phases.map((phase) => phase()));
      } catch (e, st) {
        AppLogger.error(
            'AppBootstrap', 'a startup phase escaped its own guard: $e', st);
      } finally {
        if (!_done.isCompleted) _done.complete();
      }
    }());
  }
}

/// The cold-start batch. `main()` overrides this with the real, unstarted
/// instance and calls [AppBootstrap.start] on the first frame; the splash
/// reads [AppBootstrap.ready] as its leave condition.
final appBootstrapProvider =
    Provider<AppBootstrap>((ref) => AppBootstrap.immediate());

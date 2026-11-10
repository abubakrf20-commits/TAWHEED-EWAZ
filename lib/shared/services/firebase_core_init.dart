import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kReleaseMode;
import 'package:tawheeed/firebase_options.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Lazily initializes Firebase, memoized across the process.
///
/// Cold-start history: `Firebase.initializeApp` used to be a splash-gate
/// phase, and on slow/sanctioned networks it held the gate (and the user)
/// for seconds. It now starts unawaited in `main()` and is awaited wherever
/// Firebase is actually needed (push init, Firestore streams), so nothing on
/// the launch path ever waits for the network.
///
/// Never throws: a failure is logged and the memoized slot is cleared so the
/// next call retries. Callers keep their existing `isAvailable`/`apps.isEmpty`
/// degradation, identical to the old gate-phase failure mode.
Future<void> ensureFirebaseInitialized() {
  _init ??= _doInit();
  return _init!;
}

Future<void>? _init;

Future<void> _doInit() async {
  if (Firebase.apps.isNotEmpty) return;
  final stopwatch = Stopwatch()..start();
  try {
    // Bounded: on a dead network `initializeApp` can stall far past any
    // splash gate, and in widget tests it never completes at all — without
    // this timeout every awaiting stream would hang with it.
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 8));
    await _activateAppCheck();
    AppLogger.info(
        'Firebase', 'initialized lazily in ${stopwatch.elapsedMilliseconds}ms');
  } catch (e, st) {
    AppLogger.error('Firebase', 'lazy init failed — will retry: $e', st);
    // Let the next caller try again instead of caching the failure.
    _init = null;
  }
}

/// Audit unit 8: Firestore rules shipped without App Check attestation, so
/// the anonymous suggestion write accepted scripted traffic (unit-8 open
/// item). Activating App Check here attests every Firebase call — Play
/// Integrity on release devices, the debug provider in dev — without
/// breaking anything: server-side enforcement is a separate, gradual
/// rollout in the console (`firestore.rules` documents the exact step).
Future<void> _activateAppCheck() async {
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      // Apple platforms default to DeviceCheck/debug; no web build ships.
    );
    AppLogger.info('Firebase',
        'App Check activated (${kReleaseMode ? 'playIntegrity' : 'debug'})');
  } catch (e) {
    // Best-effort: an attestation failure must not fail Firebase init —
    // enforcement is off until the console rollout, so calls still pass.
    AppLogger.warning('Firebase', 'App Check activation skipped: $e');
  }
}

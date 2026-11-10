import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/shared/services/firebase_core_init.dart';

/// Startup-lag fix (2026-10-15): Firebase core init moved off the splash
/// gate into this memoized lazy helper. It must never throw — a failure is
/// logged and retried on the next call, and callers keep their existing
/// `isAvailable` degradation. The bare test environment has no Firebase
/// platform, so calling it here exercises exactly the failure path.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ensureFirebaseInitialized never throws without a Firebase platform',
      () async {
    await expectLater(ensureFirebaseInitialized(), completes);
    // A second call reuses the memoized slot (or retries after a failure).
    await expectLater(ensureFirebaseInitialized(), completes);
  });
}

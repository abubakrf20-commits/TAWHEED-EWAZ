import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/utils/startup_guard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a throwing phase never propagates and siblings keep running', () async {
    // Mirrors main.dart: independent stages awaited inside one Future.wait.
    // Before the Phase-1 fix an exception in any stage escaped before
    // runApp and left a permanent black screen.
    var siblingRan = false;
    await Future.wait([
      runStartupPhase('notifications', () async {
        throw StateError('plugin dead');
      }),
      runStartupPhase('quran', () async {
        siblingRan = true;
      }),
    ]);
    expect(siblingRan, isTrue,
        reason: 'one failed stage must not cancel the others');
  });

  test('a successful phase runs its body to completion', () async {
    var ran = false;
    await runStartupPhase('firebase', () async {
      ran = true;
    });
    expect(ran, isTrue);
  });

  test('an async failure (delayed throw) is still absorbed', () async {
    await expectLater(
      runStartupPhase('late failure', () async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        throw Exception('boom');
      }),
      completes,
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/shared/services/click_sound_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('rapid click requests and disposal never throw', () async {
    final player = ClickSoundPlayer('sounds/tick.wav');

    // A hard burst: with the steady-state pool design no tap allocates a
    // player, so even 100 concurrent requests must just complete.
    await Future.wait([
      for (var i = 0; i < 100; i++) player.play(0.7),
    ]);

    await expectLater(player.dispose(), completes);
    await expectLater(player.dispose(), completes);
  });

  test('play after disposal is a safe no-op', () async {
    final player = ClickSoundPlayer('sounds/tick.wav');
    await player.dispose();

    await expectLater(player.play(), completes);
  });

  test('sequential taps over time and mid-warmup disposal never hang',
      () async {
    // The counter taps come in human-paced bursts; the pool must recycle
    // members off the tap path and stay consistent when disposal races the
    // warm-up/replacement futures.
    final player = ClickSoundPlayer('sounds/tick.wav');
    for (var i = 0; i < 12; i++) {
      await player.play(0.5);
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await player.warmUp();

    await expectLater(player.dispose(), completes);
    await expectLater(player.play(), completes);
  });
}

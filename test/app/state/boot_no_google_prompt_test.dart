import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Google account sheet must never open on its own at app start.
///
/// `BootCoordinator.run()` used to call `GoogleAuthService.restoreSession()`
/// ten seconds after the first frame; the plugin's "lightweight" restore falls
/// back to the interactive account picker, so it popped on every cold start
/// (user report, 2026-10-19). The automatic path is removed — the Drive/cloud
/// session is restored only from the explicit «ورود با حساب گوگل» button in
/// the account hub. This is a source scan, the repo's idiom for a "must not
/// come back" invariant.
String _stripComments(String source) => source.split('\n').map((line) {
      final i = line.indexOf('//');
      return i < 0 ? line : line.substring(0, i);
    }).join('\n');

void main() {
  test('boot never restores the Google session automatically', () {
    final boot = File('lib/app/state/boot_coordinator.dart');
    expect(boot.existsSync(), isTrue);
    final src = _stripComments(boot.readAsStringSync());
    expect(src, isNot(contains('restoreSession')));
    expect(src, isNot(contains('GoogleAuthService')));
  });

  test('the explicit sign-in door still exists in the account hub', () {
    final hub = File(
        'lib/features/account/presentation/screens/account_screen.dart');
    expect(hub.existsSync(), isTrue);
    final src = _stripComments(hub.readAsStringSync());
    expect(src, contains('GoogleAuthService.instance.signIn()'));
    expect(src, contains("Text('ورود با حساب گوگل')"));
  });
}

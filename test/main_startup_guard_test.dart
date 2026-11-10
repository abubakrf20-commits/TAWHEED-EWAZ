import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/main.dart' show initNotificationsGuarded;
import 'package:tawheeed/shared/services/notification_service.dart';

/// Phase-1 regression (critical): `NotificationService().init()` used to be
/// awaited in `main()` with no guard — a plugin failure escaped before
/// `runApp` and the app showed a permanent black screen. The guarded entry
/// point must complete no matter what the plugin stack does.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('startup guard absorbs NotificationService.init failure', () async {
    // Precondition: in the bare test environment the raw init fails — this
    // is exactly the scenario the guard exists for. If this ever stops
    // failing, revisit whether the guard scenario is still reachable.
    Object? rawError;
    try {
      await NotificationService().init().timeout(const Duration(seconds: 5));
    } catch (e) {
      rawError = e;
    }
    expect(rawError, isNotNull,
        reason: 'test env must exercise the failure path for this guard '
            'to prove anything');

    // The guarded startup entry point never throws: the app launches anyway.
    await expectLater(initNotificationsGuarded(), completes);
  });
}

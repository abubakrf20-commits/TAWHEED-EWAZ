import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/prayer/services/magnetic_declination_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.tawheeed/magnetic_declination');
  final service = MagneticDeclinationService();

  void mock(Future<Object?> Function(MethodCall) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handler);
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<double?> call() => service.calculateDeclination(
        latitude: 35.7,
        longitude: 51.4,
        date: DateTime(2025, 6),
      );

  test('returns the declination the native side provides', () async {
    mock((call) async {
      expect(call.method, 'calculateDeclination');
      return 3.5;
    });
    expect(await call(), 3.5);
  });

  test('a genuine 0° declination is reported as 0, not null', () async {
    mock((call) async => 0.0);
    expect(await call(), 0.0);
  });

  test('PlatformException surfaces as null (not a silent 0°)', () async {
    mock((call) async {
      throw PlatformException(code: 'unavailable');
    });
    expect(await call(), isNull);
  });

  test('a null native result surfaces as null', () async {
    mock((call) async => null);
    expect(await call(), isNull);
  });

  test('missing plugin surfaces as null', () async {
    // No handler installed -> the channel raises MissingPluginException,
    // which the service must translate to null so the UI shows the
    // approximate-direction banner instead of trusting a 0° value.
    expect(await call(), isNull);
  });
}

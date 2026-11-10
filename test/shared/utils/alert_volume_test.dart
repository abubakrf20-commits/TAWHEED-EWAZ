import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/shared/utils/alert_volume.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('default alert volume is 1.0 when unset', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await AlertVolume.get(), 1.0);
  });

  test('set then get roundtrips', () async {
    SharedPreferences.setMockInitialValues({});
    await AlertVolume.set(0.35);
    expect(await AlertVolume.get(), 0.35);
  });

  test('clamps to 0..1', () async {
    SharedPreferences.setMockInitialValues({});
    await AlertVolume.set(1.7);
    expect(await AlertVolume.get(), 1.0);
    await AlertVolume.set(-0.2);
    expect(await AlertVolume.get(), 0.0);
  });
}

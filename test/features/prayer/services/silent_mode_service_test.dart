import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/prayer/services/silent_mode_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('afterIqamahMinutes defaults to 0 (unmute at iqamah)', () async {
    expect(await SilentModeService.instance.afterIqamahMinutes(), 0);
  });

  test('setAfterIqamahMinutes persists the value', () async {
    await SilentModeService.instance.setAfterIqamahMinutes(10);
    expect(await SilentModeService.instance.afterIqamahMinutes(), 10);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(SilentModeService.afterIqamahMinutesKey), 10);
  });

  test('setAfterIqamahMinutes clamps to 0..120', () async {
    await SilentModeService.instance.setAfterIqamahMinutes(-5);
    expect(await SilentModeService.instance.afterIqamahMinutes(), 0);

    await SilentModeService.instance.setAfterIqamahMinutes(999);
    expect(await SilentModeService.instance.afterIqamahMinutes(), 120);
  });
}

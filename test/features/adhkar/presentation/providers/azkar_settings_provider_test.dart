import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/adhkar/presentation/providers/azkar_settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  test('loads tasbihVolume from prefs (default 1.0)', () async {
    SharedPreferences.setMockInitialValues({'azkar_sound_volume': 0.5});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // اولین خواندن، build را صدا می‌زند و _load را شروع می‌کند
    container.read(azkarSettingsProvider);
    await settle();
    expect(container.read(azkarSettingsProvider).tasbihVolume, 0.5);
  });

  test('setTasbihVolume updates state and persists', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(azkarSettingsProvider);
    await settle();
    await container.read(azkarSettingsProvider.notifier).setTasbihVolume(0.25);
    expect(container.read(azkarSettingsProvider).tasbihVolume, 0.25);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('azkar_sound_volume'), 0.25);
  });

  test('a change made before the prefs load lands is not reverted by it',
      () async {
    // build() returns the defaults while the stored values are still being
    // read. A setter called in that window used to write into a state the
    // load then replaced, and persist nothing because `_prefs` was null.
    SharedPreferences.setMockInitialValues({'azkar_haptic': true});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(azkarSettingsProvider);
    final pending =
        container.read(azkarSettingsProvider.notifier).setTasbihVolume(0.25);
    await settle();
    await pending;
    expect(container.read(azkarSettingsProvider).tasbihVolume, 0.25);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('azkar_sound_volume'), 0.25);
  });
}

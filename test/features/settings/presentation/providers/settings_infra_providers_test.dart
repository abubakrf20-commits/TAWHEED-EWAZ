import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_infra_providers.dart';
import 'package:tawheeed/shared/utils/alert_volume.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  test('loads the stored alert volume', () async {
    SharedPreferences.setMockInitialValues({'sound_alert_volume': 0.4});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(alertVolumeProvider);
    await settle();

    expect(container.read(alertVolumeProvider), 0.4);
  });

  test('a set made before the load lands is not reverted by it', () async {
    // build() returns 1.0 while the stored value is still being read; a drag
    // made in that window used to snap back to the old volume when the load
    // assigned it.
    SharedPreferences.setMockInitialValues({'sound_alert_volume': 0.8});
    // Warm the prefs singleton first (the app loads it at boot), so the
    // load's continuation resolves in the same turn as the drag. A cold
    // singleton would let the drag's own read finish the population and
    // mask the revert.
    await SharedPreferences.getInstance();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(alertVolumeProvider);
    final pending = container.read(alertVolumeProvider.notifier).set(0.25);
    await settle();
    await pending;

    expect(container.read(alertVolumeProvider), 0.25);
    expect(await AlertVolume.get(), 0.25);
  });

  test('clamps out-of-range input', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(alertVolumeProvider);
    await settle();
    await container.read(alertVolumeProvider.notifier).set(1.7);

    expect(container.read(alertVolumeProvider), 1.0);
    expect(await AlertVolume.get(), 1.0);
  });
}

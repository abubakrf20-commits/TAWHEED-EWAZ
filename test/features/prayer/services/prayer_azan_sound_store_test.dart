import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/prayer/services/prayer_azan_sound_store.dart';

/// The per-prayer azan voice overrides (Design-A «اذان و اقامه» card).
///
/// Contract: an ABSENT key inherits the shared azanSound — fresh installs and
/// never-touched prayers keep today's behaviour, and no default is ever
/// written over a stored value. Values are the shared sound keys
/// (kamel/takbir/custom); the «custom» file stays the shared customAzanPath.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('a fresh store has no overrides', () async {
    expect(await PrayerAzanSoundStore().readOverrides(), isEmpty);
    expect(await PrayerAzanSoundStore().get(PrayerSlot.fajr), isNull);
    expect(await PrayerAzanSoundStore().get(PrayerSlot.isha), isNull);
  });

  test('set/get per slot, other slots untouched', () async {
    final store = PrayerAzanSoundStore();
    await store.set(PrayerSlot.fajr, 'kamel');
    await store.set(PrayerSlot.maghrib, 'custom');

    expect(await store.get(PrayerSlot.fajr), 'kamel');
    expect(await store.get(PrayerSlot.maghrib), 'custom');
    expect(await store.get(PrayerSlot.dhuhr), isNull);

    final overrides = await store.readOverrides();
    expect(overrides, {PrayerSlot.fajr: 'kamel', PrayerSlot.maghrib: 'custom'});
  });

  test('clear returns one prayer to the inherited voice', () async {
    final store = PrayerAzanSoundStore();
    await store.set(PrayerSlot.dhuhr, 'takbir');
    await store.clear(PrayerSlot.dhuhr);

    expect(await store.get(PrayerSlot.dhuhr), isNull);
    expect(await store.readOverrides(), isEmpty);
  });

  test('clearAll removes every override', () async {
    final store = PrayerAzanSoundStore();
    for (final slot in PrayerSlot.values) {
      await store.set(slot, 'kamel');
    }
    await store.clearAll();

    expect(await store.readOverrides(), isEmpty);
  });

  group('effectiveFor', () {
    test('absent override inherits the shared voice', () {
      expect(
        PrayerAzanSoundStore.effectiveFor(
            PrayerSlot.asr, const {}, 'takbir'),
        'takbir',
      );
    });

    test('an explicit override wins', () {
      expect(
        PrayerAzanSoundStore.effectiveFor(
            PrayerSlot.asr, const {PrayerSlot.asr: 'custom'}, 'takbir'),
        'custom',
      );
    });
  });

  test('keys are distinct per slot and stable', () {
    final keys = PrayerSlot.values.map(PrayerAzanSoundStore.keyFor).toSet();
    expect(keys.length, PrayerSlot.values.length);
    expect(PrayerAzanSoundStore.keyFor(PrayerSlot.fajr), 'azan_sound_fajr');
    expect(PrayerAzanSoundStore.keyFor(PrayerSlot.isha), 'azan_sound_isha');
  });
}

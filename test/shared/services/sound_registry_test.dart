import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/shared/services/sound_registry.dart';

/// The registry replaced six hard-coded copies of two file names; these tests
/// are what keeps it a single source instead of a seventh copy.
void main() {
  test('every registered sound has a unique key and a real asset on disk', () {
    final keys = <String>{};
    for (final sound in SoundRegistry.all) {
      expect(keys.add(sound.key), isTrue,
          reason: 'duplicate key ${sound.key}: a preview would toggle the '
              'wrong row and a settings write would land on the wrong sound');
      expect(sound.key.trim(), isNotEmpty);
      expect(sound.label.trim(), isNotEmpty);
      expect(sound.asset.trim(), isNotEmpty);
      // The registry stores the path the way `AssetSource` reads it, so the
      // file lives under `assets/`. A typo here is silent on device (the tone
      // simply never plays), which is exactly why it is asserted here.
      final file = File('assets/${sound.asset}');
      expect(file.existsSync(), isTrue,
          reason: '${sound.key} points at assets/${sound.asset}, which does not '
              'exist');
    }
  });

  test('a sound can be looked up by the key the preview player toggles', () {
    expect(SoundRegistry.byKey(SoundRegistry.tick.key), SoundRegistry.tick);
    expect(SoundRegistry.byKey('alert.notif'), SoundRegistry.reminder);
    expect(SoundRegistry.byKey('nothing.here'), isNull);
  });

  test('the settings cards can list their own sounds without the page', () {
    expect(SoundRegistry.inGroup(SoundGroup.interactive),
        [SoundRegistry.tick]);
    expect(SoundRegistry.inGroup(SoundGroup.alert),
        [SoundRegistry.reminder, SoundRegistry.raceStart]);
    // Every sound belongs to exactly one card, so none can vanish from the
    // settings page by being registered under a group nothing renders.
    expect(
      SoundRegistry.inGroup(SoundGroup.interactive).length +
          SoundRegistry.inGroup(SoundGroup.alert).length,
      SoundRegistry.all.length,
    );
  });
}

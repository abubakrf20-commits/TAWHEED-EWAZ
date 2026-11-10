import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/settings/data/settings_migrations.dart';

/// The stamp exists for one reason: the legacy `eval_*` import must run once.
/// These tests pin that, and pin the direction the version points — a row from
/// before versioning is upgraded, a row already at the current version is never
/// touched again.
void main() {
  test('a row with no stamp is upgraded exactly once', () {
    expect(SettingsMigrations.needsUpgrade(0), isTrue);

    final first = SettingsMigrations.upgrade(
      const {'adhkarPoint': 5, 'tasbihPoint': 3},
      fromVersion: 0,
      legacyEvalPrefs: const {'adhkarPoint': 9},
    );
    expect(first.version, SettingsMigrations.currentVersion);
    expect(first.json['adhkarPoint'], 9, reason: 'the legacy value wins once');
    expect(first.json['tasbihPoint'], 3, reason: 'keys the legacy set lacks '
        'must keep the value the row already carries');

    // The stamp is what stops the second run: the same stale legacy map is
    // still lying around (clearing it may have failed) and must be ignored.
    expect(SettingsMigrations.needsUpgrade(first.version), isFalse);
    final second = SettingsMigrations.upgrade(
      {'adhkarPoint': 12},
      fromVersion: first.version,
      legacyEvalPrefs: const {'adhkarPoint': 9},
    );
    expect(second.json['adhkarPoint'], 12);
    expect(second.version, SettingsMigrations.currentVersion);
  });

  test('a fresh install has nothing to import and reaches the version anyway',
      () {
    final fresh = SettingsMigrations.upgrade(
      const {'fardhPoint': 10},
      fromVersion: 0,
    );
    expect(fresh.version, SettingsMigrations.currentVersion);
    expect(fresh.json, const {'fardhPoint': 10});
  });

  test('an upgrade never mutates the map it was handed', () {
    final original = <String, dynamic>{'adhkarPoint': 5};
    SettingsMigrations.upgrade(
      original,
      fromVersion: 0,
      legacyEvalPrefs: const {'adhkarPoint': 9},
    );
    expect(original, {'adhkarPoint': 5},
        reason: 'the caller keeps its loaded row until the save succeeds');
  });

  test('a row from a newer build is left alone', () {
    // A newer app may have written fields this build does not know; running
    // unknown steps backwards is how a downgrade eats data.
    final newer = SettingsMigrations.upgrade(
      const {'someFutureKey': 1},
      fromVersion: SettingsMigrations.currentVersion + 3,
      legacyEvalPrefs: const {'adhkarPoint': 9},
    );
    expect(newer.version, SettingsMigrations.currentVersion + 3);
    expect(newer.json, const {'someFutureKey': 1});
  });
}

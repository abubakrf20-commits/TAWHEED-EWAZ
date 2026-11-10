import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/personal_info/services/pin_lock_service.dart';
import 'package:tawheeed/shared/services/app_secure_storage.dart';

/// The plugin's default (`resetOnError: true`) DELETES a value whose read
/// fails — including a transient Keystore error — and the next write would mint
/// a fresh key over data sealed with the lost one. These tests pin the option
/// and make sure no call site builds its own plugin instance with the default.
void main() {
  test('a failed read surfaces instead of deleting the stored key', () {
    final options = appSecureStorage.aOptions.toMap();
    expect(options['resetOnError'], 'false');
    // An older cipher must still migrate automatically.
    expect(options['migrateOnAlgorithmChange'], 'true');
  });

  test('the vault reads through the shared instance', () {
    expect(PinLockService.storage, same(appSecureStorage));
  });

  test('every secret site uses the shared instance', () {
    const sites = [
      'lib/features/personal_info/services/pin_lock_service.dart',
      'lib/features/prayer/data/datasources/prayer_local_datasource.dart',
      'lib/features/settings/services/backup_service.dart',
    ];
    for (final path in sites) {
      final src = File(path).readAsStringSync();
      expect(src, contains('app_secure_storage.dart'), reason: path);
      expect(src, isNot(contains('FlutterSecureStorage()')),
          reason: '$path must not build its own plugin instance');
    }
  });
}

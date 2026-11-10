import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/features/settings/services/backup_service.dart';

/// Restore hardening (audit SEC M2/M3): archive limits and the preference key
/// policy that keeps vault and credential state on the device.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('archive limits', () {
    Archive archiveOf(List<(String, int)> entries) {
      final archive = Archive();
      for (final (name, size) in entries) {
        archive.addFile(ArchiveFile(name, size, List<int>.filled(size, 0)));
      }
      return archive;
    }

    test('a normal backup passes', () {
      expect(
        () => BackupService.assertArchiveWithinLimits(archiveOf([
          ('app.sqlite', 8 << 20),
          ('preferences.json', 4096),
          ('custom_azans/azan.mp3', 512 << 10),
        ])),
        returnsNormally,
      );
    });

    test('too many entries is rejected', () {
      final many = List.generate(
          BackupService.maxArchiveEntries + 1, (i) => ('app_data/f$i', 1));
      expect(
        () => BackupService.assertArchiveWithinLimits(archiveOf(many)),
        throwsA(isA<BackupTooLargeException>()),
      );
    });

    test('one oversized entry is rejected before it is expanded', () {
      expect(
        () => BackupService.assertArchiveWithinLimits(archiveOf(
            [('app_data/huge.bin', BackupService.maxArchiveEntryBytes + 1)])),
        throwsA(isA<BackupTooLargeException>()),
      );
    });

    test('many small entries that together exceed the total are rejected', () {
      final entries = <(String, int)>[];
      const each = BackupService.maxArchiveEntryBytes - 1024;
      for (var i = 0; i < 4; i++) {
        entries.add(('app_data/f$i', each));
      }
      expect(
        () => BackupService.assertArchiveWithinLimits(archiveOf(entries)),
        throwsA(isA<BackupTooLargeException>()),
      );
    });
  });

  group('preflight from the central directory', () {
    /// Encodes a real zip whose headers *declare* [declaredSize] but whose
    /// content is a few bytes — the shape of a hand-crafted bomb.
    List<int> zipDeclaring(String name, int declaredSize) {
      final archive = Archive()
        ..addFile(ArchiveFile(name, declaredSize, [1, 2, 3, 4]));
      return ZipEncoder().encode(archive);
    }

    test('an entry that declares more than the per-entry cap is refused', () {
      final zip = zipDeclaring(
          'app_data/huge.bin', BackupService.maxArchiveEntryBytes + 1);
      // The zip itself is tiny: nothing was expanded to reach this verdict.
      expect(zip.length, lessThan(4096));
      expect(() => BackupService.preflightArchiveBytes(zip),
          throwsA(isA<BackupTooLargeException>()));
    });

    test('an honest backup passes the preflight', () {
      final archive = Archive()
        ..addFile(ArchiveFile('backup_meta.json', 12, utf8.encode('{"a":1}')))
        ..addFile(ArchiveFile('app.sqlite', 2048, List<int>.filled(2048, 0)));
      expect(
          () =>
              BackupService.preflightArchiveBytes(ZipEncoder().encode(archive)),
          returnsNormally);
    });

    test('an entry count over the cap is refused', () {
      final archive = Archive();
      for (var i = 0; i <= BackupService.maxArchiveEntries; i++) {
        archive.addFile(ArchiveFile('app_data/f$i', 1, [0]));
      }
      expect(
          () =>
              BackupService.preflightArchiveBytes(ZipEncoder().encode(archive)),
          throwsA(isA<BackupTooLargeException>()));
    });

    test('garbage yields an empty archive, which the meta check rejects', () {
      // The preflight is a size gate, not a validator. Bytes with no EOCD
      // record have nothing to measure, so they pass through and decode to an
      // empty archive; `restoreBackup` then rejects them for lacking
      // `backup_meta.json` instead of crashing.
      final garbage = List<int>.filled(64, 7);
      expect(
          () => BackupService.preflightArchiveBytes(garbage), returnsNormally);
      expect(ZipDecoder().decodeBytes(garbage), isEmpty);
    });
  });

  group('preference key policy', () {
    test('ordinary settings are restorable', () {
      expect(BackupService.isRestorablePreferenceKey('theme_mode'), isTrue);
      expect(BackupService.isRestorablePreferenceKey('font_scale'), isTrue);
      expect(BackupService.isRestorablePreferenceKey('prayer_notifications'),
          isTrue);
      expect(BackupService.isRestorablePreferenceKey('saved_lat_fallback'),
          isTrue);
    });

    test('vault keys never leave the device', () {
      // A salted SHA-256 of a 4-6 digit PIN is brute-forceable offline, and
      // the AES key is device-bound, so these are worthless off-device and
      // dangerous in a file.
      expect(BackupService.isRestorablePreferenceKey('personal_info.pin_hash'),
          isFalse);
      expect(BackupService.isRestorablePreferenceKey('personal_info.pin_salt'),
          isFalse);
      expect(
          BackupService.isRestorablePreferenceKey('personal_info.vault_key_id'),
          isFalse);
    });

    test('credential-shaped keys are rejected', () {
      expect(BackupService.isRestorablePreferenceKey('google_refresh_token'),
          isFalse);
      expect(BackupService.isRestorablePreferenceKey('user_api_key'), isFalse);
      expect(BackupService.isRestorablePreferenceKey('some_secret'), isFalse);
      expect(BackupService.isRestorablePreferenceKey('my_password'), isFalse);
      expect(BackupService.isRestorablePreferenceKey('session_id'), isFalse);
      expect(
          BackupService.isRestorablePreferenceKey('fcm_device_token'), isFalse);
    });

    test('plugin-owned namespaces are rejected', () {
      expect(BackupService.isRestorablePreferenceKey('flutter.'), isFalse);
      expect(BackupService.isRestorablePreferenceKey('FlutterSecureStorage'),
          isFalse);
    });

    test('degenerate keys are rejected', () {
      expect(BackupService.isRestorablePreferenceKey(''), isFalse);
      expect(BackupService.isRestorablePreferenceKey('a' * 200), isFalse);
    });
  });

  group('preference value policy', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('ordinary values are accepted', () {
      expect(BackupService.isRestorablePreferenceValue('dark'), isTrue);
      expect(BackupService.isRestorablePreferenceValue(42), isTrue);
      expect(BackupService.isRestorablePreferenceValue(1.5), isTrue);
      expect(BackupService.isRestorablePreferenceValue(true), isTrue);
      expect(BackupService.isRestorablePreferenceValue(<String>['a', 'b']),
          isTrue);
    });

    test('oversized strings are rejected', () {
      expect(
        BackupService.isRestorablePreferenceValue(
            'x' * (BackupService.maxPreferenceValueBytes + 1)),
        isFalse,
      );
    });

    test('oversized and non-string lists are rejected', () {
      expect(
        BackupService.isRestorablePreferenceValue(
            List.filled(BackupService.maxPreferenceListLength + 1, 'a')),
        isFalse,
      );
      expect(
          BackupService.isRestorablePreferenceValue(<Object>[1, 2]), isFalse);
      expect(
          BackupService.isRestorablePreferenceValue(<Object>['a', 2]), isFalse);
      // An empty list is harmless, so it is accepted.
      expect(BackupService.isRestorablePreferenceValue(<Object>[]), isTrue);
    });

    test('unsupported types are rejected', () {
      expect(BackupService.isRestorablePreferenceValue(null), isFalse);
      expect(BackupService.isRestorablePreferenceValue(<String, String>{}),
          isFalse);
    });
  });
}

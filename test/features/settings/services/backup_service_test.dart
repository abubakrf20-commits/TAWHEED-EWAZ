import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/settings/services/backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  const pkgChannel = MethodChannel('dev.fluttercommunity.plus/package_info');
  late Directory tempDir;

  Future<List<int>> makeZip({
    Map<String, dynamic>? meta,
    bool includeMeta = true,
    bool includeManifest = true,
    bool includeDb = true,
    Map<String, dynamic>? manifestFiles,
    Map<String, dynamic>? prefs,
    List<int>? dbContent,
  }) async {
    final dbBytes = dbContent ?? utf8.encode('fake sqlite content');
    final archive = Archive();
    if (includeMeta) {
      final metaBytes = utf8.encode(jsonEncode(meta ??
          {
            'format_version': 2,
            'version': '1.0.0',
            'buildNumber': '1',
            'date': '2026-01-01',
            'app': 'tawheeed',
            'schema_version': AppDatabase.currentSchemaVersion
          }));
      archive.addFile(
          ArchiveFile('backup_meta.json', metaBytes.length, metaBytes));
    }
    if (includeDb) {
      archive.addFile(ArchiveFile('app.sqlite', dbBytes.length, dbBytes));
    }
    final files = Map<String, dynamic>.from(manifestFiles ??
        {
          'app.sqlite': sha256.convert(dbBytes).toString(),
        });
    if (prefs != null) {
      final prefsBytes = utf8.encode(jsonEncode(prefs));
      archive.addFile(
          ArchiveFile('preferences.json', prefsBytes.length, prefsBytes));
      files['preferences.json'] = sha256.convert(prefsBytes).toString();
    }
    if (includeManifest) {
      final manifestBytes =
          utf8.encode(jsonEncode({'format_version': 2, 'files': files}));
      archive.addFile(ArchiveFile(
          'backup_manifest.json', manifestBytes.length, manifestBytes));
    }
    return ZipEncoder().encode(archive);
  }

  Future<File> writeZip(String name, List<int> bytes) async {
    final file = File(p.join(tempDir.path, name));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tawheeed_backup');
    // Every case starts with an empty Keystore so device-key tests can mint a
    // key and the "another device" case can clear it deliberately.
    FlutterSecureStorage.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return tempDir.path;
      }
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pkgChannel, (call) async {
      if (call.method == 'getAll') {
        return <String, dynamic>{
          'appName': 'توحید',
          'packageName': 'com.tawheeed',
          'version': '1.2.3',
          'buildNumber': '45',
          'buildSignature': '',
        };
      }
      return null;
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pkgChannel, null);
    // Windows can hold a freshly-written sqlite/attachment file open for a
    // while (Defender scan, handle release lag); a failed cleanup must never
    // fail an already-green test — retry briefly, then leave the temp dir
    // for the OS to clean up.
    for (var attempt = 0; attempt < 8; attempt++) {
      try {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
        break;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
  });

  group('autoBackupDue', () {
    test('is due when no backup was recorded', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await BackupService().autoBackupDue(), isTrue);
    });

    test('is not due when a backup was recorded today', () async {
      final now = DateTime.now();
      final key =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      SharedPreferences.setMockInitialValues({'last_auto_backup_date': key});
      expect(await BackupService().autoBackupDue(), isFalse);
    });

    test('is due when the recorded backup is from yesterday', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final key =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
      SharedPreferences.setMockInitialValues({'last_auto_backup_date': key});
      expect(await BackupService().autoBackupDue(), isTrue);
    });
  });

  group('exportBackup', () {
    test('builds a zip with preferences, db, meta and manifest', () async {
      await File(p.join(tempDir.path, 'app.sqlite')).writeAsString('db-bytes');
      SharedPreferences.setMockInitialValues({
        'theme_mode': 'dark',
        'qf_access_token': 'secret',
        'shellTabIndex': 3,
      });

      final file = await BackupService().exportBackup(directory: tempDir.path);

      final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
      final names = archive.map((f) => f.name).toSet();
      expect(
          names,
          containsAll([
            'preferences.json',
            'app.sqlite',
            'backup_meta.json',
            'backup_manifest.json',
          ]));

      final prefs = jsonDecode(utf8.decode(archive
          .firstWhere((f) => f.name == 'preferences.json')
          .content as List<int>)) as Map<String, dynamic>;
      expect(prefs, contains('theme_mode'));
      // Volatile/session keys must never be exported.
      expect(prefs.containsKey('qf_access_token'), isFalse);
      expect(prefs.containsKey('shellTabIndex'), isFalse);

      final meta = jsonDecode(utf8.decode(archive
          .firstWhere((f) => f.name == 'backup_meta.json')
          .content as List<int>)) as Map<String, dynamic>;
      expect(meta['app'], 'tawheeed');
      expect(meta['schema_version'], AppDatabase.currentSchemaVersion);
      expect(meta['version'], '1.2.3');
    });

    test('never exports the personal-info PIN verifier', () async {
      await File(p.join(tempDir.path, 'app.sqlite')).writeAsString('db-bytes');
      // Legacy plaintext verifier left over from an older install.
      SharedPreferences.setMockInitialValues({
        'personal_info.pin_hash': 'aGFzaA==',
        'personal_info.pin_salt': 'c2FsdA==',
        'personal_info.vault_key_id': 'v1',
      });

      final file = await BackupService().exportBackup(directory: tempDir.path);
      final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
      final prefs = jsonDecode(utf8.decode(archive
          .firstWhere((f) => f.name == 'preferences.json')
          .content as List<int>)) as Map<String, dynamic>;

      expect(prefs.containsKey('personal_info.pin_hash'), isFalse);
      expect(prefs.containsKey('personal_info.pin_salt'), isFalse);
      expect(prefs.containsKey('personal_info.vault_key_id'), isFalse);
    });

    test('qibla/prayer coordinates survive export', () async {
      await File(p.join(tempDir.path, 'app.sqlite')).writeAsString('db-bytes');
      SharedPreferences.setMockInitialValues({
        'saved_lat_fallback': 35.6892,
        'saved_lng_fallback': 51.3890,
        'saved_city': 'تهران',
        'saved_altitude': 1189.0,
      });

      final file = await BackupService().exportBackup(directory: tempDir.path);
      final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
      final prefs = jsonDecode(utf8.decode(archive
          .firstWhere((f) => f.name == 'preferences.json')
          .content as List<int>)) as Map<String, dynamic>;
      // Location coordinates must NOT be excluded: the user's qibla and
      // prayer times depend on them after a restore.
      expect(prefs['saved_lat_fallback'], 35.6892);
      expect(prefs['saved_lng_fallback'], 51.3890);
      expect(prefs['saved_city'], 'تهران');
    });
  });

  group('readBackupMeta', () {
    test('returns the meta map from a valid zip', () async {
      final file = await writeZip(
          'meta.zip', await makeZip(meta: {'app': 'tawheeed', 'x': 1}));
      final meta = await BackupService().readBackupMeta(file.path);
      expect(meta, isNotNull);
      expect(meta!['app'], 'tawheeed');
      expect(meta['x'], 1);
    });

    test('returns null for a zip without meta', () async {
      final file = await writeZip('nometa.zip',
          await makeZip(includeMeta: false, includeManifest: false));
      expect(await BackupService().readBackupMeta(file.path), isNull);
    });
  });

  group('restoreBackup validation', () {
    test('rejects a backup without meta', () async {
      final file = await writeZip('bad1.zip',
          await makeZip(includeMeta: false, includeManifest: false));
      expect(() => BackupService().restoreBackup(file.path),
          throwsA(isA<Exception>()));
    });

    test('rejects a backup from another app', () async {
      final file =
          await writeZip('bad2.zip', await makeZip(meta: {'app': 'other_app'}));
      expect(() => BackupService().restoreBackup(file.path),
          throwsA(isA<Exception>()));
    });

    test('rejects a backup from a newer app version', () async {
      final file = await writeZip(
          'bad3.zip',
          await makeZip(meta: {
            'app': 'tawheeed',
            'schema_version': AppDatabase.currentSchemaVersion + 1,
          }));
      expect(() => BackupService().restoreBackup(file.path),
          throwsA(isA<Exception>()));
    });

    test('rejects a tampered manifest', () async {
      final file = await writeZip(
          'bad4.zip', await makeZip(manifestFiles: {'app.sqlite': 'deadbeef'}));
      expect(() => BackupService().restoreBackup(file.path),
          throwsA(isA<Exception>()));
    });

    test('requires a database argument once validation passes', () async {
      final file = await writeZip('valid.zip', await makeZip());
      expect(
          () => BackupService().restoreBackup(file.path), throwsArgumentError);
    });
  });

  group('backup encryption (AES-256-GCM, legacy CBC compatible)', () {
    test('plain zips are not detected as encrypted', () async {
      final zip = await makeZip();
      expect(BackupService.isEncryptedBackup(zip), isFalse);
      expect(BackupService.isEncryptedBackup([]), isFalse);
      expect(BackupService.isEncryptedBackup([1, 2, 3]), isFalse);
    });

    test('encrypt/decrypt round-trips the exact bytes', () async {
      final zip = utf8.encode('fake zip payload fairly long ' * 40);
      final enc = await BackupService.encryptBackupBytes(zip, 'رمز-قوی-123');
      expect(BackupService.isEncryptedBackup(enc), isTrue);
      // Ciphertext must not leak plaintext.
      expect(String.fromCharCodes(enc).contains('fake zip'), isFalse);
      final dec = await BackupService.decryptBackupBytes(enc, 'رمز-قوی-123');
      expect(dec, zip);
    });

    test('same password encrypts non-deterministically (random salt+nonce)',
        () async {
      final zip = utf8.encode('same payload');
      final a = await BackupService.encryptBackupBytes(zip, 'pw');
      final b = await BackupService.encryptBackupBytes(zip, 'pw');
      expect(a, isNot(b));
      expect(await BackupService.decryptBackupBytes(a, 'pw'), zip);
      expect(await BackupService.decryptBackupBytes(b, 'pw'), zip);
    });

    test('wrong password is rejected with a clear error', () async {
      final enc = await BackupService.encryptBackupBytes(
          utf8.encode('secret'), 'correct');
      await expectLater(BackupService.decryptBackupBytes(enc, 'wrong'),
          throwsA(isA<Exception>()));
    });

    test('flipping one ciphertext byte fails GCM authentication', () async {
      final enc = await BackupService.encryptBackupBytes(
          utf8.encode('tamper target'), 'pw');
      final tampered = List<int>.of(enc)..[enc.length - 1] ^= 0x01;
      await expectLater(BackupService.decryptBackupBytes(tampered, 'pw'),
          throwsA(isA<Exception>()));
    });

    test('restore of an encrypted backup without password asks for it',
        () async {
      final enc =
          await BackupService.encryptBackupBytes(await makeZip(), '1234');
      final file = await writeZip('enc.zip', enc);
      expect(() => BackupService().restoreBackup(file.path),
          throwsA(isA<BackupPasswordRequiredException>()));
    });

    test('restore decrypts with the right password, rejects the wrong one',
        () async {
      final enc =
          await BackupService.encryptBackupBytes(await makeZip(), '1234');
      final file = await writeZip('enc2.zip', enc);
      // Passes decryption, then fails later for lack of a database argument —
      // proving the password step succeeded.
      expect(() => BackupService().restoreBackup(file.path, password: '1234'),
          throwsArgumentError);
      expect(() => BackupService().restoreBackup(file.path, password: 'wrong'),
          throwsA(isA<Exception>()));
    });
  });

  group('device-key auto-backup encryption', () {
    test('plain and password archives are not device-key files', () async {
      final zip = await makeZip();
      expect(BackupService.isDeviceKeyBackup(zip), isFalse);
      expect(BackupService.isDeviceKeyBackup([]), isFalse);
      final password = await BackupService.encryptBackupBytes(zip, 'pw');
      expect(BackupService.isEncryptedBackup(password), isTrue);
      expect(BackupService.isDeviceKeyBackup(password), isFalse);
    });

    test('round-trips with the sealed key and is non-deterministic', () async {
      final zip = utf8.encode('device-key payload ' * 20);
      final a = await BackupService.encryptBackupBytesWithDeviceKey(zip);
      final b = await BackupService.encryptBackupBytesWithDeviceKey(zip);
      expect(BackupService.isDeviceKeyBackup(a), isTrue);
      expect(a, isNot(b));
      expect(String.fromCharCodes(a).contains('device-key'), isFalse);
      expect(await BackupService.decryptBackupBytesWithDeviceKey(a), zip);
      expect(await BackupService.decryptBackupBytesWithDeviceKey(b), zip);
      // The key lives in secure storage, never in the archive.
      final stored =
          await const FlutterSecureStorage().read(key: 'backup.auto_key');
      expect(stored, isNotNull);
    });

    test('a file from another device reports the missing key, not a password',
        () async {
      final enc =
          await BackupService.encryptBackupBytesWithDeviceKey(await makeZip());
      // Simulate a fresh install / another phone: the Keystore entry is gone.
      FlutterSecureStorage.setMockInitialValues({});
      final file = await writeZip('device.zip', enc);
      expect(() => BackupService().restoreBackup(file.path),
          throwsA(isA<BackupDeviceKeyMissingException>()));
    });

    test('restore decrypts an auto-backup without a password prompt', () async {
      final enc =
          await BackupService.encryptBackupBytesWithDeviceKey(await makeZip());
      final file = await writeZip('device2.zip', enc);
      // No password: it gets past decryption and stops only because the test
      // supplied no database.
      expect(() => BackupService().restoreBackup(file.path),
          throwsArgumentError);
    });

    test('createAutoBackup writes a sealed file with device-key meta',
        () async {
      SharedPreferences.setMockInitialValues({});
      await File(p.join(tempDir.path, 'app.sqlite')).writeAsString('db-bytes');

      final file = await BackupService().createAutoBackup();
      expect(file, isNotNull);
      final bytes = await file!.readAsBytes();
      expect(BackupService.isEncryptedBackup(bytes), isTrue);
      expect(BackupService.isDeviceKeyBackup(bytes), isTrue);
      // The file starts with the envelope itself, not a ZIP local header — the
      // archive package would silently decode garbage to an empty Archive, so
      // the magic/version bytes are the proof that matter.
      expect(bytes.take(5).toList(), [0x54, 0x45, 0x4E, 0x43, 0x31]);
      expect(bytes[5], 0x34);

      final zip = await BackupService.decryptBackupBytesWithDeviceKey(bytes);
      final archive = ZipDecoder().decodeBytes(zip);
      final meta = jsonDecode(utf8.decode(archive
          .firstWhere((f) => f.name == 'backup_meta.json')
          .content as List<int>)) as Map<String, dynamic>;
      expect(meta['encrypted'], isTrue);
      expect(meta['encryption'], 'AES-GCM-256/DEVICE-KEY');

      // A second daily run reuses the same sealed key.
      final second = await BackupService().createAutoBackup();
      expect(second, isNotNull);
      final secondZip = await BackupService.decryptBackupBytesWithDeviceKey(
          await second!.readAsBytes());
      expect(ZipDecoder().decodeBytes(secondZip), isNotEmpty);
    });
  });

  // ── The path that actually touches user data ──────────────────────
  // Every other group here asserts that a bad backup is *rejected*; these two
  // lock the happy path (audit H1): a valid backup must replace the live rows
  // and a rejected one must leave them untouched.
  group('restoreBackup data round-trip', () {
    /// Live database with a probe table holding exactly one row.
    Future<AppDatabase> openLiveDb() async {
      final db = AppDatabase.withConnection(
          NativeDatabase(File(p.join(tempDir.path, 'app.sqlite'))));
      await db.customStatement('CREATE TABLE IF NOT EXISTS restore_probe ('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, v TEXT)');
      await db.customStatement('DELETE FROM restore_probe');
      await db.customStatement(
          "INSERT INTO restore_probe (v) VALUES ('live-only')");
      return db;
    }

    Future<List<String>> probeValues(AppDatabase db) async =>
        (await db.customSelect('SELECT v FROM restore_probe ORDER BY id').get())
            .map((row) => row.read<String>('v'))
            .toList();

    test('a valid backup replaces the live rows and reports what it restored',
        () async {
      SharedPreferences.setMockInitialValues({});
      final db = await openLiveDb();

      // A real SQLite file carrying the same table with different content.
      final sourcePath = p.join(tempDir.path, 'backup_source.sqlite');
      final source = sqlite3.open(sourcePath);
      source.execute('CREATE TABLE restore_probe ('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, v TEXT)');
      source.execute("INSERT INTO restore_probe (v) VALUES ('from-backup-1')");
      source.execute("INSERT INTO restore_probe (v) VALUES ('from-backup-2')");
      source.execute('VACUUM');
      source.close();

      final file = await writeZip('roundtrip.zip',
          await makeZip(dbContent: await File(sourcePath).readAsBytes()));

      final restored =
          await BackupService().restoreBackup(file.path, database: db);

      // Only the table present in BOTH sides is restored — exactly one.
      expect(restored.restoredTables, 1);
      // A restore replaces everything, so it must leave a way back.
      expect(restored.safetyCopyPath, isNotNull);
      expect(File(restored.safetyCopyPath!).existsSync(), isTrue,
          reason: 'the pre-restore copy has to be a real file on disk');
      expect(await probeValues(db), ['from-backup-1', 'from-backup-2']);
      await db.close();
    });

    test('an older archive cannot re-plant a plaintext PIN verifier', () async {
      // Live state: a legacy verifier that must survive untouched, plus a
      // normal preference that the restore is expected to import.
      SharedPreferences.setMockInitialValues({
        'personal_info.pin_hash': 'live-hash',
        'personal_info.pin_salt': 'live-salt',
      });
      final db = await openLiveDb();

      final file = await writeZip(
        'legacy-pin.zip',
        await makeZip(
          prefs: {
            'theme_mode': 'dark',
            'personal_info.pin_hash': 'from-backup',
            'personal_info.pin_salt': 'from-backup',
            'personal_info.vault_key_id': 'v1',
          },
          dbContent:
              await File(p.join(tempDir.path, 'app.sqlite')).readAsBytes(),
        ),
      );

      await BackupService().restoreBackup(file.path, database: db);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'dark',
          reason: 'ordinary settings must still be restored');
      expect(prefs.getString('personal_info.pin_hash'), 'live-hash');
      expect(prefs.getString('personal_info.pin_salt'), 'live-salt');
      expect(prefs.getString('personal_info.vault_key_id'), isNull);
      await db.close();
    });

    test('a tampered backup is rejected before any live row is touched',
        () async {
      SharedPreferences.setMockInitialValues({});
      final db = await openLiveDb();

      final file = await writeZip(
          'tampered-data.zip',
          await makeZip(manifestFiles: {
            'app.sqlite': '0' * 64,
          }));

      await expectLater(BackupService().restoreBackup(file.path, database: db),
          throwsA(isA<Exception>()));
      expect(await probeValues(db), ['live-only'],
          reason: 'a rejected backup must not delete or replace live rows');
      await db.close();
    });
  });
  // ── Attachment sync (the documents-vault photos) ────────────────────
  // The portable backup must carry the `app_data/` attachment FILES and the
  // restore must repoint the DB rows at this device's documents dir — that is
  // what makes a document photo actually visible after a cross-device
  // restore. Pins three real bugs found here: Dart-side table/column names
  // (drift's SQL names differ), a LIKE pattern with a doubled separator, and
  // a REPLACE that welded `app_data` onto the new dir without a separator.
  group('attachment sync (app_data files + path remap)', () {
    /// Zip builder with arbitrary entries and an auto-computed manifest.
    Future<List<int>> buildAttachmentZip(Map<String, List<int>> files) async {
      final archive = Archive();
      final metaBytes = utf8.encode(jsonEncode({
        'format_version': 2,
        'version': '1.0.0',
        'buildNumber': '1',
        'date': '2026-01-01',
        'app': 'tawheeed',
        'schema_version': AppDatabase.currentSchemaVersion,
      }));
      archive.addFile(
          ArchiveFile('backup_meta.json', metaBytes.length, metaBytes));
      final checksums = <String, String>{};
      for (final entry in files.entries) {
        archive
            .addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
        checksums[entry.key] = sha256.convert(entry.value).toString();
      }
      final manifest =
          utf8.encode(jsonEncode({'format_version': 2, 'files': checksums}));
      archive.addFile(
          ArchiveFile('backup_manifest.json', manifest.length, manifest));
      return ZipEncoder().encode(archive);
    }

    test('remap table/column pairs exist in the live schema', () async {
      final db = AppDatabase.withConnection(NativeDatabase.memory());
      for (final (table, column, _) in BackupService.appDataPathColumns) {
        final cols =
            (await db.customSelect('PRAGMA table_info("$table")').get())
                .map((r) => r.read<String>('name'))
                .toList();
        expect(cols, contains(column),
            reason: 'BackupService.appDataPathColumns lists "$table"."$column" '
                'but the live schema has [${cols.join(', ')}]. Drift SQL names '
                'are snake_case on *_table tables — use those.');
      }
      await db.close();
    });

    test('document photos ride along and paths repoint after restore',
        () async {
      SharedPreferences.setMockInitialValues({});
      // The "source device": its own docs dir, database and attachment file.
      final sourceDocs = Directory(p.join(tempDir.path, 'other_device'))
        ..createSync(recursive: true);
      const photoRel = 'app_data/attachments/document/scan1.jpg';
      final photoBytes = utf8.encode('jpeg-bytes-for-test');
      File(p.join(sourceDocs.path, photoRel))
        ..createSync(recursive: true)
        ..writeAsBytesSync(photoBytes);

      final sourceDb = AppDatabase.withConnection(
          NativeDatabase(File(p.join(sourceDocs.path, 'app.sqlite'))));
      final now = DateTime.now();
      await sourceDb.into(sourceDb.identityDocumentTable).insert(
            IdentityDocumentTableCompanion.insert(
              id: 'doc1',
              profileId: 'p1',
              title: 'کارت ملی',
              imagesJson:
                  Value(jsonEncode([p.join(sourceDocs.path, photoRel)])),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await sourceDb.into(sourceDb.assetTable).insert(
            AssetTableCompanion.insert(
              id: 'asset1',
              title: 'خودرو',
              attachmentsJson:
                  Value(jsonEncode([p.join(sourceDocs.path, photoRel)])),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await sourceDb.close();
      final dbBytes =
          await File(p.join(sourceDocs.path, 'app.sqlite')).readAsBytes();

      final file = await writeZip(
          'with-attachments.zip',
          await buildAttachmentZip({
            'app.sqlite': dbBytes,
            photoRel: photoBytes,
          }));

      final db = AppDatabase.withConnection(
          NativeDatabase(File(p.join(tempDir.path, 'app.sqlite'))));
      try {
        final restored =
            await BackupService().restoreBackup(file.path, database: db);
        expect(restored.restoredTables, greaterThanOrEqualTo(2));

        // The attachment file landed under THIS device's documents dir…
        final restoredFile = File(p.join(
            tempDir.path, 'app_data', 'attachments', 'document', 'scan1.jpg'));
        expect(restoredFile.existsSync(), isTrue);
        expect(restoredFile.readAsBytesSync(), photoBytes);

        // …and both rows point at this device, not the source device.
        final docs = await db
            .customSelect('SELECT images_json FROM identity_document_table')
            .get();
        final images =
            (jsonDecode(docs.single.read<String>('images_json')) as List)
                .cast<String>();
        expect(p.normalize(images.single), p.normalize(restoredFile.path),
            reason: 'the document row must reference the restored file');

        final assets = await db
            .customSelect('SELECT attachments_json FROM asset_table')
            .get();
        final attachments =
            (jsonDecode(assets.single.read<String>('attachments_json')) as List)
                .cast<String>();
        expect(p.normalize(attachments.single), p.normalize(restoredFile.path),
            reason: 'the asset row must reference the restored file');
      } finally {
        await db.close();
      }
    });

    test('exportBackup carries app_data attachment files', () async {
      await File(p.join(tempDir.path, 'app.sqlite')).writeAsString('db-bytes');
      final attachment = File(
          p.join(tempDir.path, 'app_data', 'attachments', 'document', 'x.jpg'))
        ..createSync(recursive: true)
        ..writeAsBytesSync([1, 2, 3, 4]);

      final zip = await BackupService().exportBackup(directory: tempDir.path);
      final archive = ZipDecoder().decodeBytes(await zip.readAsBytes());
      final entry = archive
          .firstWhere((f) => f.name == 'app_data/attachments/document/x.jpg');
      expect(entry.content as List<int>, [1, 2, 3, 4]);
      expect(attachment.existsSync(), isTrue);
    });
  });
}

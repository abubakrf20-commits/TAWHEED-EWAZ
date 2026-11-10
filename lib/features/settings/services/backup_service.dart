import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/personal_info/services/pin_lock_service.dart';
import 'package:tawheeed/shared/services/app_secure_storage.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/date_key.dart';

/// Thrown when a restore target is password-encrypted but no [password] was
/// supplied, so the UI can prompt for it and retry.
class BackupPasswordRequiredException implements Exception {
  const BackupPasswordRequiredException();
}

/// Thrown when an archive needs this device's auto-backup key and the key is
/// gone (copied to another phone, Keystore cleared). Asking for a password
/// would be misleading: the file never had one.
class BackupDeviceKeyMissingException implements Exception {
  const BackupDeviceKeyMissingException();
  @override
  String toString() =>
      'این پشتیبان با کلید امن همین گوشی رمز شده است و روی این دستگاه قابل بازگشایی نیست.';
}

/// Thrown when an archive exceeds the restore limits, so a hostile or
/// accidentally huge file is rejected instead of exhausting memory or disk.
class BackupTooLargeException implements Exception {
  final String message;
  const BackupTooLargeException(this.message);
  @override
  String toString() => message;
}

/// Result of [BackupService.createConsistentSnapshot].
class DatabaseSnapshot {
  /// The database file content, safe to archive as `app.sqlite`.
  final List<int> bytes;

  /// False when the SQLite build lacked `VACUUM INTO` and the caller has to
  /// include `app.sqlite-wal` for the copy to be complete.
  final bool wasVacuumed;

  const DatabaseSnapshot(this.bytes, {required this.wasVacuumed});
}

/// Outcome of [BackupService.restoreBackup].
///
/// Carries the safety copy's location as well as the table count: a restore
/// replaces every table, so the copy taken beforehand is the only way back and
/// the user has to be able to find it.
class RestoreOutcome {
  const RestoreOutcome({
    required this.restoredTables,
    this.safetyCopyPath,
  });

  /// Tables whose rows were replaced from the archive.
  final int restoredTables;

  /// Where this device's data was archived before the restore replaced it.
  /// Null when the copy could not be written — in which case the restore was
  /// still attempted, but there is no undo.
  final String? safetyCopyPath;
}

/// Outcome of [wipeAllLocalData]: counts the UI reports honestly instead of
/// claiming a wipe it did not finish.
class LocalWipeResult {
  const LocalWipeResult({
    required this.tablesEmptied,
    required this.preferencesCleared,
    required this.filesDeleted,
  });

  /// Drift tables emptied (every table the database declares).
  final int tablesEmptied;

  /// SharedPreferences keys removed (the store is cleared wholesale).
  final int preferencesCleared;

  /// Files removed under `app_data/` + `custom_azans/`.
  final int filesDeleted;
}

class BackupService {
  static final BackupService _instance = BackupService._();
  factory BackupService() => _instance;
  BackupService._();

  /// Maximum number of automatic daily backups kept on the device.
  static const int maxAutoBackups = 10;

  static const String _lastAutoBackupDateKey = 'last_auto_backup_date';

  /// Device/session credentials and scheduler internals never belong in a
  /// portable backup. User settings and progress remain exportable.
  ///
  /// NOTE: `saved_lat`/`saved_lng` (secure storage) are intentionally NOT in
  /// this list — the on-disk fallbacks live in SharedPreferences under
  /// `saved_lat_fallback`/`saved_lng_fallback`, and an exact/prefix match on
  /// `saved_lat` would wipe the user's saved qibla/prayer coordinates on
  /// restore. They must survive a backup/restore cycle.
  ///
  /// The `personal_info.pin_*`/`vault_key_id` keys are covered by
  /// [_sensitivePreferencePrefixes] below rather than listed here, so that the
  /// export and the restore path cannot drift apart.
  static const Set<String> _excludedPreferenceKeys = {
    'qf_access_token',
    'qf_access_token_expiry',
    'qf_proxy_key',
    'notification_perm_shown',
    'exact_alarm_skipped',
    'last_auto_backup_date',
    'widget_shortcut',
    'shellTabIndex',
    'shellSubTab',
    // «دورهٔ ماهانه» keeps its own code. `period_pin` is a salted hash of four
    // digits — brute-forceable offline, and on a record of the legacy format
    // the literal PIN — and the recovery pair is a second secret in plaintext.
    // `period_locked` goes with them: a flag restored without its PIN would
    // leave the section locked against a code that no longer exists, with the
    // recovery question excluded too — an unlockable lock is the one state
    // worse than an absent one.
    'period_pin',
    'period_recovery_question',
    'period_recovery_answer',
    'period_locked',
  };

  /// Preference keys that must never leave the device, and must never be
  /// accepted from one.
  ///
  /// `personal_info.*` covers the vault: `pin_hash`/`pin_salt` are a salted
  /// SHA-256 of a 4-6 digit PIN, which is trivially brute-forced offline once
  /// it is in a backup file, and restoring them would silently roll the user
  /// back to the PIN that was current when the backup was taken. The AES key
  /// never travels (it is sealed by the device Keystore), so these keys are
  /// useless on any other device anyway.
  static const List<String> _sensitivePreferencePrefixes = [
    'personal_info.',
    'google_',
    'firebase',
    'fcm_',
    'session_',
  ];

  static const List<String> _sensitivePreferenceFragments = [
    'token',
    'secret',
    'password',
    'passwd',
    'pin_hash',
    '_apikey',
    'api_key',
    'credential',
    'session_id',
  ];

  /// Largest preference value accepted from an archive. SharedPreferences has
  /// no practical size limit of its own, so an unbounded string would let a
  /// hostile file bloat the prefs XML until every read pays for it.
  static const int maxPreferenceValueBytes = 1 << 20; // 1 MiB

  /// Largest number of entries in a restored `StringList` preference.
  static const int maxPreferenceListLength = 10000;

  /// Whether a value read from `preferences.json` is a type and size the
  /// restore path is willing to write.
  static bool isRestorablePreferenceValue(Object? value) {
    if (value is List) {
      if (value.length > maxPreferenceListLength) return false;
      for (final element in value) {
        if (element is! String) return false;
        if (element.length > maxPreferenceValueBytes) return false;
      }
      return true;
    }
    if (value is String) return value.length <= maxPreferenceValueBytes;
    return value is bool || value is int || value is double;
  }

  /// Restore limits. A real backup is a SQLite database plus a few hundred KB
  /// of documents; these caps sit far above that but stop a zip bomb (or a
  /// hand-crafted archive) from being expanded into gigabytes.
  static const int maxArchiveEntries = 5000;
  static const int maxArchiveEntryBytes = 192 << 20; // 192 MiB
  static const int maxArchiveTotalBytes = 512 << 20; // 512 MiB

  /// Whether [key] may be written to SharedPreferences by a restore.
  /// Used by both the exporter and the restore path.
  static bool isRestorablePreferenceKey(String key) {
    if (key.isEmpty || key.length > 128) return false;
    // Android prefixes nothing, but the plugin stores the key verbatim; reject
    // anything that could collide with a framework or plugin-owned name.
    if (key.startsWith('flutter.') || key.startsWith('Flutter')) return false;
    for (final prefix in _sensitivePreferencePrefixes) {
      if (key == prefix || key.startsWith(prefix)) return false;
    }
    final lower = key.toLowerCase();
    for (final fragment in _sensitivePreferenceFragments) {
      if (lower.contains(fragment)) return false;
    }
    return true;
  }

  /// Rejects an archive from its ZIP central directory alone, before a single
  /// entry is inflated.
  ///
  /// [ZipDecoder.decodeBytes] decompresses every entry eagerly, so validating
  /// the decoded [Archive] is already too late: a bomb has been expanded by the
  /// time it is counted. Reading the central directory costs one pass over the
  /// file headers and allocates nothing.
  ///
  /// A zip is allowed to understate its sizes, so this is a cheap first gate
  /// rather than the only one — [assertArchiveWithinLimits] still re-checks the
  /// decoded archive.
  static void preflightArchiveBytes(List<int> zipBytes) {
    final directory = ZipDirectory()..read(InputMemoryStream(zipBytes));
    final entries = directory.fileHeaders.length;
    if (entries > maxArchiveEntries) {
      throw BackupTooLargeException(
          'Backup has $entries entries, the limit is $maxArchiveEntries.');
    }
    var total = 0;
    for (final header in directory.fileHeaders) {
      final file = header.file;
      if (file == null) continue;
      final size = file.uncompressedSize;
      if (size > maxArchiveEntryBytes) {
        throw BackupTooLargeException(
            'Backup entry "${file.filename}" declares $size bytes, the limit is $maxArchiveEntryBytes.');
      }
      total += size;
      if (total > maxArchiveTotalBytes) {
        throw const BackupTooLargeException(
            'Backup declares more than $maxArchiveTotalBytes bytes in total.');
      }
    }
  }

  /// Re-checks a decoded [Archive] against the restore limits. Pair with
  /// [preflightArchiveBytes], which runs before the decode.
  static void assertArchiveWithinLimits(Archive archive) {
    if (archive.length > maxArchiveEntries) {
      throw BackupTooLargeException(
          'Backup has ${archive.length} entries, the limit is $maxArchiveEntries.');
    }
    var total = 0;
    for (final file in archive) {
      final size = file.size;
      if (size > maxArchiveEntryBytes) {
        throw BackupTooLargeException(
            'Backup entry "${file.name}" is $size bytes, the limit is $maxArchiveEntryBytes.');
      }
      total += size;
      if (total > maxArchiveTotalBytes) {
        throw const BackupTooLargeException(
            'Backup expands to more than $maxArchiveTotalBytes bytes.');
      }
    }
  }

  /// Reads `app.sqlite` in [documentsDir] as a single consistent point in time.
  ///
  /// `VACUUM INTO` runs inside an implicit read transaction, so the result is
  /// always a real state of the database even while other writes are landing.
  /// On failure (a build without `VACUUM INTO`, a locked file) the caller gets
  /// the plain file plus `wasVacuumed == false` and adds the log itself, which
  /// is the pre-existing behaviour and at worst a torn snapshot rather than no
  /// backup at all. Never throws.
  static Future<DatabaseSnapshot> createConsistentSnapshot(
    String documentsDir,
  ) async {
    final dbFile = File(p.join(documentsDir, 'app.sqlite'));
    final temp = File(p.join(documentsDir,
        'app.sqlite.snapshot.${DateTime.now().millisecondsSinceEpoch}'));
    try {
      final db = sqlite3.open(dbFile.path);
      try {
        // A concurrent writer must not abort the backup outright.
        db.execute('PRAGMA busy_timeout = 5000');
        if (await temp.exists()) await temp.delete();
        db.execute('VACUUM INTO ?', [temp.path]);
        final bytes = await temp.readAsBytes();
        if (bytes.isNotEmpty) {
          return DatabaseSnapshot(bytes, wasVacuumed: true);
        }
      } finally {
        db.close();
      }
    } catch (e) {
      AppLogger.warning('BackupService', 'consistent snapshot unavailable: $e');
    } finally {
      try {
        if (await temp.exists()) await temp.delete();
      } catch (e) {
        AppLogger.warning('BackupService', 'snapshot temp delete failed: $e');
      }
    }
    return DatabaseSnapshot(await dbFile.readAsBytes(), wasVacuumed: false);
  }

  Future<File> exportBackup(
      {String? directory,
      String? password,
      bool deviceKey = false,
      String prefix = 'tawheeed_backup'}) async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final outputDir = directory ?? documentsDir.path;
    await Directory(outputDir).create(recursive: true);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final zipName = '${prefix}_$timestamp.zip';
    final zipPath = p.join(outputDir, zipName);
    final archive = Archive();

    // 1. User preferences only. Tokens, permission flags and device/session
    // state are intentionally excluded from portable backups.
    final prefs = await SharedPreferences.getInstance();
    final prefsData = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      if (_excludedPreferenceKeys.contains(key) ||
          key.startsWith('qf_') ||
          key.startsWith('lastScheduled')) {
        continue;
      }
      // Audit 8.16: «دفتر روز» (کار/یادداشت تقویم) used to be the
      // one user dataset living ONLY in SharedPreferences with no
      // SQLite table — excluded keys and scheduler prefixes never
      // matched it, so it actually flowed through this generic
      // prefs export. Verify explicitly so a future prefix rule
      // cannot silently drop it from backups.
      assert(!key.startsWith('day_journal_') || isRestorablePreferenceKey(key));
      // Vault state, tokens and other device-bound secrets stay local.
      if (!isRestorablePreferenceKey(key)) continue;
      final value = prefs.get(key);
      if (value != null) prefsData[key] = value;
    }
    final prefsBytes = utf8.encode(jsonEncode(prefsData));
    archive.addFile(
        ArchiveFile('preferences.json', prefsBytes.length, prefsBytes));

    // 2. دیتابیس اصلی + WAL + SHM
    final dbPath = p.join(documentsDir.path, 'app.sqlite');
    final dbFile = File(dbPath);
    if (!await dbFile.exists()) {
      throw StateError('فایل دیتابیس برای پشتیبان‌گیری یافت نشد.');
    }
    // A consistent snapshot, not a byte copy. The database runs in WAL mode,
    // so reading `app.sqlite`, `-wal` and `-shm` one after another samples
    // three different points in time: a write landing between the copies
    // produces a pair that never existed, which restores as missing or
    // resurrected rows. `VACUUM INTO` snapshots in a single statement and
    // writes a self-contained file, so no log has to travel with it.
    final snapshot = await createConsistentSnapshot(documentsDir.path);
    archive.addFile(
        ArchiveFile('app.sqlite', snapshot.bytes.length, snapshot.bytes));
    if (!snapshot.wasVacuumed) {
      // Fallback for a SQLite build without VACUUM INTO: the log is required
      // for the copied database to be complete.
      final walFile = File(p.join(documentsDir.path, 'app.sqlite-wal'));
      if (await walFile.exists()) {
        final walBytes = await walFile.readAsBytes();
        archive
            .addFile(ArchiveFile('app.sqlite-wal', walBytes.length, walBytes));
      }
      final shmFile = File(p.join(documentsDir.path, 'app.sqlite-shm'));
      if (await shmFile.exists()) {
        final shmBytes = await shmFile.readAsBytes();
        archive
            .addFile(ArchiveFile('app.sqlite-shm', shmBytes.length, shmBytes));
      }
    }

    // 3. فایل اذان شخصی — بدون آن ردیف custom_azan_path در دیتابیس بعد از
    // بازگردانی روی دستگاه دیگر به مسیری ناموجود اشاره می‌کند.
    final azanDir = Directory(p.join(documentsDir.path, 'custom_azans'));
    if (await azanDir.exists()) {
      await for (final f in azanDir.list()) {
        if (f is! File) continue;
        final bytes = await f.readAsBytes();
        archive.addFile(ArchiveFile(
            'custom_azans/${p.basename(f.path)}', bytes.length, bytes));
      }
    }

    // 3. فایل‌های داده جانبی اپ — تصاویر مدارک، آواتارها، پیوست اموال و
    // یادداشت‌های صوتی. بدون آن‌ها ردیف‌های دیتابیس بعد از بازگردانی به مسیر
    // ناموجودِ دستگاه مبدأ اشاره می‌کنند.
    final appDataDir = Directory(p.join(documentsDir.path, 'app_data'));
    if (await appDataDir.exists()) {
      await for (final entity in appDataDir.list(recursive: true)) {
        if (entity is! File) continue;
        final rel = p.relative(entity.path, from: documentsDir.path);
        // ZIP entry names are always POSIX: on Windows `p.relative` +
        // `p.joinAll` would yield `app_data\...`, which restore (and any other
        // tool) would not recognise as the `app_data/` prefix.
        final name = rel.split(p.separator).join('/');
        try {
          final bytes = await entity.readAsBytes();
          archive.addFile(ArchiveFile(name, bytes.length, bytes));
        } catch (e) {
          // One unreadable attachment (deleted mid-listing, permission) must
          // not abort the whole backup - skip it and keep the rest.
          AppLogger.warning(
              'BackupService', 'skipped unreadable attachment $name: $e');
        }
      }
    }

    // 3. متادیتا با نسخه اپلیکیشن
    final info = await PackageInfo.fromPlatform();
    final usePassword = password != null && password.isNotEmpty;
    // A user password always wins: it is the only form that can be restored
    // on a different device. The device key is for auto-backups, which never
    // leave this phone.
    final useDeviceKey = deviceKey && !usePassword;
    final meta = {
      'format_version': 2,
      'version': info.version,
      'buildNumber': info.buildNumber,
      'date': DateTime.now().toIso8601String(),
      'app': 'tawheeed',
      'schema_version': AppDatabase.currentSchemaVersion,
      if (usePassword || useDeviceKey) 'encrypted': true,
      if (usePassword) 'encryption': _encryptionLabel,
      if (useDeviceKey) 'encryption': _deviceKeyEncryptionLabel,
    };
    final metaBytes = utf8.encode(jsonEncode(meta));
    archive
        .addFile(ArchiveFile('backup_meta.json', metaBytes.length, metaBytes));

    // A manifest makes every entry verifiable before restore and gives future
    // versions a stable place for migrations/allowlists.
    final checksums = <String, String>{};
    for (final file in archive) {
      checksums[file.name] =
          sha256.convert(file.content as List<int>).toString();
    }
    final manifest = utf8.encode(jsonEncode({
      'format_version': 2,
      'files': checksums,
    }));
    archive.addFile(
        ArchiveFile('backup_manifest.json', manifest.length, manifest));

    final zipBytes = ZipEncoder().encode(archive);
    final backupFile = File(zipPath);
    final tempFile = File('$zipPath.part');

    /// Optional password: the whole ZIP (DB + prefs + azans) is AES-encrypted
    // so a shared/off-device backup file is opaque without the password.
    /// Auto-backups use the device-sealed key instead: they contain private
    // data at rest and are never meant to leave this phone.
    final payload = usePassword
        ? await encryptBackupBytes(zipBytes, password)
        : useDeviceKey
            ? await encryptBackupBytesWithDeviceKey(zipBytes)
            : zipBytes;
    await tempFile.writeAsBytes(payload, flush: true);
    if (await backupFile.exists()) await backupFile.delete();
    await tempFile.rename(zipPath);
    return backupFile;
  }

  /// Whether [name] is a safe `app_data/...` archive entry. Exposed for tests.
  @visibleForTesting
  static bool isSafeArchiveEntry(String name) =>
      _safeArchiveRelativePath(name) != null;

  /// Validates a ZIP entry name and returns it as path segments relative to the
  /// documents dir, or null when the entry is unsafe.
  ///
  /// Rejects absolute paths, drive letters, `..` traversal, empty segments and
  /// anything that normalizes to a location outside `app_data/`. Guards against
  /// a tampered backup writing to arbitrary filesystem locations.
  static List<String>? _safeArchiveRelativePath(String name) {
    if (name.contains(String.fromCharCode(0))) return null;
    // ZIP spec mandates `/`, but a Windows-produced archive may use `\`; treat
    // both as separators so `..\..\` cannot sneak past the check.
    final raw = name.split(RegExp(r'[/\\]'));
    final segments = <String>[];
    for (final segment in raw) {
      if (segment.isEmpty || segment == '.') continue;
      if (segment == '..') return null;
      segments.add(segment);
    }
    if (segments.length < 2) return null;
    if (segments.first != 'app_data') return null;
    // Belt and braces: the joined result must still sit under the prefix.
    final normalized = p.normalize(p.joinAll(segments));
    if (!p.isWithin('app_data', normalized) &&
        !p.equals(normalized, 'app_data')) {
      return null;
    }
    return segments;
  }

  /// Table/column/isJsonList triples that can hold an `app_data` path. JSON
  /// array columns (document/asset/insurance photo lists) are remapped by
  /// decoding the JSON and rewriting each path in Dart; plain path columns are
  /// rewritten as single strings.
  ///
  /// Table names MUST be the raw SQLite identifiers drift generates —
  /// snake_case columns on `*_table` tables (`identity_document_table`
  /// .`images_json`), NOT the Dart-side names (`IdentityDocumentTable`
  /// .`imagesJson`). An earlier draft used the Dart names: every remap query
  /// died on "no such table", the catch swallowed it, and after a cross-device
  /// restore every document photo/attachment kept pointing at the source
  /// device's documents dir. Public (read-only) so the regression test can
  /// enumerate the triples against the live schema.
  @visibleForTesting
  static const List<(String, String, bool)> appDataPathColumns = [
    ('note_table', 'audio_path', false),
    ('personal_profile_table', 'avatar_path', false),
    ('identity_document_table', 'images_json', true),
    ('asset_table', 'attachments_json', true),
    ('insurance_table', 'attachments_json', true),
  ];

  /// Rewrites stored `app_data` paths from the source device's documents dir
  /// to this device's, so attachments/voice notes still resolve after a
  /// cross-device restore (the documents dir differs per device).
  ///
  /// Runs inside the restore transaction, right after the table copy, so the
  /// rows being fixed are the freshly-restored ones. Each distinct stored
  /// value is fixed in Dart — a plain `<docs>/app_data/…` path or a JSON
  /// array of them — instead of a SQL REPLACE on the raw text: JSON string
  /// escaping (Windows backslashes double up inside the JSON) and the `["…"]`
  /// wrapper must never leak into the rewritten prefix, or the column is
  /// silently corrupted.
  static Future<void> _remapAppDataPaths(AppDatabase database,
      {required String newDocsDir}) async {
    for (final (table, column, isJsonList) in appDataPathColumns) {
      try {
        // `customSelect` (not `executor.runSelect`): this runs inside the
        // restore transaction, and touching the base executor while a
        // transaction holds the connection deadlocks the whole restore.
        // DISTINCT: many rows often share one value; one rewrite per distinct
        // value covers every row holding it.
        // The LIKE pattern is a constant — no user text is interpolated, so
        // no parameter binding is needed (customSelect takes none inline).
        final values = (await database
                .customSelect(
                  'SELECT DISTINCT "$column" AS v FROM "$table" '
                  'WHERE "$column" LIKE \'%app_data%\'',
                )
                .get())
            .map((r) => r.read<String>('v'))
            .toList();
        for (final raw in values) {
          final fixed = (isJsonList && raw.trimLeft().startsWith('['))
              ? _remapJsonPathList(raw, newDocsDir)
              : _remapSinglePath(raw, newDocsDir);
          if (fixed == null || fixed == raw) continue;
          await database.customStatement(
            'UPDATE "$table" SET "$column" = ? WHERE "$column" = ?',
            [fixed, raw],
          );
        }
      } catch (e) {
        // Older backups may lack the table/column — skip it silently.
        AppLogger.info('BackupService', 'remap skipped for $table.$column: $e');
      }
    }
  }

  /// Rewrites every path of a JSON-array column value. Returns null when the
  /// value is not the expected shape or nothing changed — the caller keeps
  /// the original rather than corrupting a column it does not understand.
  static String? _remapJsonPathList(String raw, String newDocsDir) {
    try {
      final list = (jsonDecode(raw) as List<dynamic>).cast<String>();
      var changed = false;
      final fixed = list.map((path) {
        final mapped = _remapSinglePath(path, newDocsDir);
        if (mapped == null) return path;
        changed = true;
        return mapped;
      }).toList();
      return changed ? jsonEncode(fixed) : null;
    } catch (e) {
      // Not a JSON array of strings (vault blob, plain column, legacy shape):
      // return null so the caller keeps the value untouched instead of
      // rewriting data it does not understand.
      return null;
    }
  }

  /// Moves a staged tree into its final place, overwriting what is there.
  ///
  /// Called only after the restore transaction has committed, so the device
  /// never holds the archive's files beside the old database. Returns how many
  /// files actually landed, which the caller compares against what was staged:
  /// a shortfall means the restored rows now point at missing files and must be
  /// reported, not swallowed.
  static Future<int> _promoteStagedTree(
      Directory staged, Directory target) async {
    if (!await staged.exists()) return 0;
    await target.create(recursive: true);
    var moved = 0;
    await for (final entity in staged.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final rel = p.relative(entity.path, from: staged.path);
      final dest = File(p.join(target.path, rel));
      try {
        await dest.parent.create(recursive: true);
        await entity.rename(dest.path);
        moved++;
      } on FileSystemException catch (e) {
        // A rename across volumes fails; fall back to copy + delete rather than
        // leaving the file behind in staging.
        try {
          await entity.copy(dest.path);
          await entity.delete();
          moved++;
        } catch (copyErr) {
          AppLogger.warning('BackupService',
              'could not promote "$rel" (rename: $e, copy: $copyErr)');
        }
      }
    }
    return moved;
  }

  /// Rewrites one plain path, or null when it already points at [newDocsDir]
  /// (or carries no `app_data` segment at all).
  static String? _remapSinglePath(String path, String newDocsDir) {    final idx = path.indexOf('app_data');
    if (idx <= 0) return null;
    // p.join+normalize, never string concatenation: the stored docs prefix
    // keeps its trailing separator, and a naive concat would double it
    // (`<docs>//app_data`) so the equality check against the new prefix
    // misfires; the replacement below must carry exactly one separator.
    final oldPrefix = p.normalize(p.join(path.substring(0, idx), 'app_data'));
    final newPrefix = p.normalize(p.join(newDocsDir, 'app_data'));
    if (p.equals(oldPrefix, newPrefix)) return null;
    // Rebuild with normalize(): the tail after `app_data` may use the other
    // separator style than the fresh prefix (archives always store `/`, the
    // docs dir may not), and normalize folds them into one canonical form.
    return p.normalize(newPrefix + path.substring(idx + 'app_data'.length));
  }

  Future<XFile> shareBackup({String? password}) async {
    final file = await exportBackup(password: password);
    return XFile(file.path);
  }

  // ─── رمزنگاری اختیاری بکاپ (AES-256-CBC) ─────────────────────
  //
  // File layout: magic `TENC1` (5 bytes) + salt (16) + IV (16) + ciphertext.
  // Key = 20k-round HMAC-SHA256(password, salt) — slow enough to blunt
  // offline guessing, fast enough (<100ms) for interactive use.

  static const String _encryptionLabel = 'AES-GCM-256/PBKDF2-SHA256x200000';
  static const List<int> _magic = [0x54, 0x45, 0x4E, 0x43, 0x31]; // TENC1
  /// Legacy TENC1 header: magic(5) + salt(16) + IV(16). New GCM files carry a
  /// version byte after the magic instead of the legacy salt/IV layout.
  static const int _legacyHeaderLen = 5 + 16 + 16;
  static const int _gcmVersionByte = 0x32; // '2' — second TENC1 generation
  /// Phase-3 audit fix: version '3' upgrades the hand-rolled 20k HMAC chain
  /// to a real PBKDF2-HMAC-SHA256 with 200k iterations (the OWASP floor for
  /// password storage grade KDFs). v2 and legacy v1 files remain readable.
  static const int _pbkdf2VersionByte = 0x33; // '3' — third TENC1 generation
  static const int _pbkdf2Iterations = 200000;

  /// True when [bytes] start with the encrypted-backup magic header.
  static bool isEncryptedBackup(List<int> bytes) {
    if (bytes.length < _magic.length) return false;
    for (var i = 0; i < _magic.length; i++) {
      if (bytes[i] != _magic[i]) return false;
    }
    return true;
  }

  /// PBKDF2-HMAC-SHA256 (single-block dkLen=32) implemented over package:crypto
  /// primitives. [iterations] comes from the format version: v3 files use
  /// 200k; the legacy chain is kept only for decrypting old backups.
  static List<int> _pbkdf2Key(List<int> salt, String password, int iterations) {
    final hmac = Hmac(sha256, utf8.encode(password));
    // U1 = PRF(P, salt || INT(i)) — one block, so no need for the full
    // block-splitting loop of the RFC.
    var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final acc = List<int>.from(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < acc.length; j++) {
        acc[j] ^= u[j];
      }
    }
    return acc;
  }

  static List<int> _deriveKey(List<int> salt, String password) {
    final hmac = Hmac(sha256, utf8.encode(password));
    var block =
        hmac.convert([...salt, ...utf8.encode('tawheeed-backup-v1')]).bytes;
    for (var i = 1; i < 20000; i++) {
      block = hmac.convert(block).bytes;
    }
    return block;
  }

  static List<int> _randomBytes(int count) {
    final rnd = Random.secure();
    return List<int>.generate(count, (_) => rnd.nextInt(256));
  }

  /// AES-encrypts raw ZIP [zipBytes] with [password].
  ///
  /// Format: `TENC1` magic + version byte `2` + 16-byte salt + 12-byte nonce
  /// + AES-256-GCM ciphertext (auth tag appended by the cipher). GCM's built-in
  /// authentication rejects tampering deterministically — the old CBC format
  /// could only be detected indirectly via padding/ZIP parse failures.
  /// Runs in a background isolate so the 20k-round key derivation never janks
  /// the UI on long passwords or slow devices.
  static Future<List<int>> encryptBackupBytes(
      List<int> zipBytes, String password) async {
    return Isolate.run(() => _encryptSync(zipBytes, password));
  }

  static List<int> _encryptSync(List<int> zipBytes, String password) {
    final salt = _randomBytes(16);
    final nonceBytes = _randomBytes(12);
    // v3: real PBKDF2 with 200k iterations.
    final key = enc.Key(
        Uint8List.fromList(_pbkdf2Key(salt, password, _pbkdf2Iterations)));
    final nonce = enc.IV(Uint8List.fromList(nonceBytes));
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    final cipher = encrypter.encryptBytes(zipBytes, iv: nonce);
    return [
      ..._magic,
      _pbkdf2VersionByte,
      ...salt,
      ...nonceBytes,
      ...cipher.bytes,
    ];
  }

  /// Reverses [encryptBackupBytes]. Throws a Persian [Exception] when the
  /// password is wrong or the file was tampered with (GCM auth failure),
  /// and still decrypts legacy CBC files written by older app versions.
  static Future<List<int>> decryptBackupBytes(
      List<int> fileBytes, String password) async {
    // Heavy path (20k HMAC rounds) off the UI isolate; the small legacy-format
    // check stays synchronous so callers get deterministic errors.
    return Isolate.run(() => _decryptSync(fileBytes, password));
  }

  static List<int> _decryptSync(List<int> fileBytes, String password) {
    final versionByte =
        fileBytes.length > _magic.length ? fileBytes[_magic.length] : null;
    if (versionByte == _pbkdf2VersionByte || versionByte == _gcmVersionByte) {
      // GCM formats: magic(5) + ver(1) + salt(16) + nonce(12) + ciphertext.
      // v3 (0x33) keys via PBKDF2-200k; v2 (0x32) keeps the legacy chain so
      // old backups stay readable.
      if (fileBytes.length <= 5 + 1 + 16 + 12) {
        throw Exception('فایل پشتیبان آسیب‌دیده است.');
      }
      final salt = fileBytes.sublist(6, 22);
      final nonceBytes = fileBytes.sublist(22, 34);
      final cipherBytes = fileBytes.sublist(34);
      try {
        final derived = versionByte == _pbkdf2VersionByte
            ? _pbkdf2Key(salt, password, _pbkdf2Iterations)
            : _deriveKey(salt, password);
        final key = enc.Key(Uint8List.fromList(derived));
        final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
        return encrypter
            .decryptBytes(enc.Encrypted(Uint8List.fromList(cipherBytes)),
                iv: enc.IV(Uint8List.fromList(nonceBytes)))
            .toList();
      } catch (e) {
        AppLogger.warning('BackupService', 'decrypt failed: $e');
        throw Exception('رمز پشتیبان نادرست است یا فایل دستکاری شده است.');
      }
    }
    // Legacy TENC1 (v1, CBC): magic(5) + salt(16) + IV(16) + ciphertext.
    if (fileBytes.length <= _legacyHeaderLen) {
      throw Exception('فایل پشتیبان آسیب‌دیده است.');
    }
    final salt = fileBytes.sublist(5, 21);
    final ivBytes = fileBytes.sublist(21, 37);
    final cipherBytes = fileBytes.sublist(37);
    try {
      final key = enc.Key(Uint8List.fromList(_deriveKey(salt, password)));
      final iv = enc.IV(Uint8List.fromList(ivBytes));
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      return encrypter
          .decryptBytes(enc.Encrypted(Uint8List.fromList(cipherBytes)), iv: iv);
    } catch (e) {
      AppLogger.warning('BackupService', 'decrypt failed: $e');
      throw Exception('رمز پشتیبان نادرست است.');
    }
  }

  // ─── دستگاه‌کلید پشتیبان خودکار (AES-256-GCM) ────────────────
  //
  // Daily auto-backups contain the whole database and every private
  // attachment, and they sit on disk without a user password. They are
  // therefore sealed with a random key kept in the device Keystore:
  // `TENC1` + version `4` + nonce(12) + AES-256-GCM ciphertext. The key never
  // travels in the archive, so such a file cannot be read on another phone —
  // that is intentional, and manual/cloud backups keep using a real password.

  static const String _deviceKeyStorageKey = 'backup.auto_key';
  static const int _deviceKeyVersionByte = 0x34; // '4' — device-key AES-GCM
  static const String _deviceKeyEncryptionLabel = 'AES-GCM-256/DEVICE-KEY';

  /// True when [bytes] are a device-key envelope (auto-backup format).
  static bool isDeviceKeyBackup(List<int> bytes) =>
      isEncryptedBackup(bytes) &&
      bytes.length > _magic.length &&
      bytes[_magic.length] == _deviceKeyVersionByte;

  /// Reads the device auto-backup key, creating and sealing it on first use.
  /// [create] = false is the restore path: never mint a new key there, or the
  /// exception would dissolve into a confusing decryption failure.
  static Future<List<int>> _deviceBackupKey({bool create = true}) async {
    final existing = await appSecureStorage.read(key: _deviceKeyStorageKey);
    if (existing != null && existing.isNotEmpty) {
      final decoded = base64Decode(existing);
      if (decoded.length == 32) return decoded;
      // Never overwrite a malformed value: older files were sealed with the
      // bytes it held before, so silently replacing it would strand them.
      throw const BackupDeviceKeyMissingException();
    }
    if (!create) throw const BackupDeviceKeyMissingException();
    final key = _randomBytes(32);
    await appSecureStorage.write(
        key: _deviceKeyStorageKey, value: base64Encode(key));
    return key;
  }

  /// AES-256-GCM-encrypts raw ZIP [zipBytes] with this device's backup key.
  static Future<List<int>> encryptBackupBytesWithDeviceKey(
      List<int> zipBytes) async {
    final key = await _deviceBackupKey();
    return Isolate.run(() => _encryptWithDeviceKeySync(zipBytes, key));
  }

  static List<int> _encryptWithDeviceKeySync(
      List<int> zipBytes, List<int> keyBytes) {
    final nonceBytes = _randomBytes(12);
    final encrypter = enc.Encrypter(
        enc.AES(enc.Key(Uint8List.fromList(keyBytes)), mode: enc.AESMode.gcm));
    final cipher = encrypter.encryptBytes(zipBytes,
        iv: enc.IV(Uint8List.fromList(nonceBytes)));
    return [..._magic, _deviceKeyVersionByte, ...nonceBytes, ...cipher.bytes];
  }

  /// Reverses [encryptBackupBytesWithDeviceKey]. Throws
  /// [BackupDeviceKeyMissingException] when this device holds no key and a
  /// Persian [Exception] when the archive was tampered with.
  static Future<List<int>> decryptBackupBytesWithDeviceKey(
      List<int> fileBytes) async {
    final key = await _deviceBackupKey(create: false);
    return Isolate.run(() => _decryptWithDeviceKeySync(fileBytes, key));
  }

  static List<int> _decryptWithDeviceKeySync(
      List<int> fileBytes, List<int> keyBytes) {
    if (fileBytes.length <= _magic.length + 1 + 12) {
      throw Exception('فایل پشتیبان آسیب‌دیده است.');
    }
    final nonceBytes = fileBytes.sublist(6, 18);
    final cipherBytes = fileBytes.sublist(18);
    try {
      final encrypter = enc.Encrypter(
          enc.AES(enc.Key(Uint8List.fromList(keyBytes)),
              mode: enc.AESMode.gcm));
      return encrypter
          .decryptBytes(enc.Encrypted(Uint8List.fromList(cipherBytes)),
              iv: enc.IV(Uint8List.fromList(nonceBytes)))
          .toList();
    } catch (e) {
      AppLogger.warning('BackupService', 'device-key decrypt failed: $e');
      throw Exception('فایل پشتیبان آسیب‌دیده یا دستکاری‌شده است.');
    }
  }

  // ─── پشتیبان‌گیری خودکار روزانه ──────────────────────────────

  /// پوشه نگهداری نسخه‌های پشتیبان خودکار. این پوشه داخل حافظه برنامه است و
  /// هنگام به‌روزرسانی برنامه پاک نمی‌شود، بنابراین آمارها در برابر از دست رفتن
  /// پس از آپدیت محافظت می‌شوند.
  Future<Directory> autoBackupDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final backups = Directory(p.join(dir.path, 'backups'));
    if (!await backups.exists()) {
      await backups.create(recursive: true);
    }
    return backups;
  }

  /// آیا امروز هنوز پشتیبان خودکار ساخته نشده است؟
  Future<bool> autoBackupDue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getString(_lastAutoBackupDateKey);
      return last != dateKeyOf(DateTime.now());
    } catch (e) {
      AppLogger.warning('AutoBackup', 'autoBackupDue failed: $e');
      return false;
    }
  }

  /// ساخت نسخه پشتیبان خودکار امروز (فقط یک‌بار در روز)، پاک‌سازی نسخه‌های
  /// قدیمی و ثبت تاریخ. همه آمارها (تسبیح، ارزیابی، ختم، مطالعه، نماز، روزه و…)
  /// داخل app.sqlite هستند و در این فایل ZIP ذخیره می‌شوند.
  Future<File?> createAutoBackup() async {
    try {
      final dir = await autoBackupDirectory();
      // Device-key sealed: the daily file holds the whole database and every
      // private attachment, so it must not sit on disk in plaintext. If the
      // Keystore refuses the key the export throws and this returns null —
      // never fall back to writing an unencrypted copy.
      final file = await exportBackup(directory: dir.path, deviceKey: true);
      await _pruneAutoBackups();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastAutoBackupDateKey, dateKeyOf(DateTime.now()));
      AppLogger.info('AutoBackup', 'Daily backup created: ${file.path}');
      return file;
    } catch (e, st) {
      AppLogger.error('AutoBackup', 'createAutoBackup failed: $e', st);
      return null;
    }
  }

  /// اجرای امن در هر بار اجرای برنامه: اگر امروز پشتیبان ساخته نشده باشد،
  /// می‌سازد. خطاها هرگز مانع شروع برنامه نمی‌شوند.
  Future<void> runDailyAutoBackup() async {
    try {
      if (await autoBackupDue()) {
        await createAutoBackup();
      }
    } catch (e, st) {
      AppLogger.error('AutoBackup', 'runDailyAutoBackup failed: $e', st);
    }
  }

  /// لیست نسخه‌های پشتیبان خودکار، جدیدترین در ابتدا.
  Future<List<File>> listAutoBackups() async {
    try {
      final dir = await autoBackupDirectory();
      final files = await dir
          .list()
          .where((e) =>
              e is File &&
              e.path.contains('tawheeed_backup_') &&
              e.path.endsWith('.zip'))
          .cast<File>()
          .toList();
      files.sort((a, b) => b.path.compareTo(a.path));
      return files;
    } catch (e) {
      AppLogger.warning('AutoBackup', 'listAutoBackups failed: $e');
      return const [];
    }
  }

  /// آخرین نسخه پشتیبان خودکار (یا null اگر هنوز ساخته نشده).
  Future<File?> findLatestAutoBackup() async {
    final backups = await listAutoBackups();
    if (backups.isEmpty) return null;
    return backups.first;
  }

  /// زمان ساخت آخرین پشتیبان خودکار (برای نمایش در تنظیمات).
  Future<DateTime?> lastAutoBackupTime() async {
    final file = await findLatestAutoBackup();
    if (file == null) return null;
    try {
      return await file.lastModified();
    } catch (e) {
      AppLogger.warning('AutoBackup', 'lastAutoBackupTime failed: $e');
      return null;
    }
  }

  /// Keeps at most [maxAutoBackups] files AND at most ~50MB total.
  Future<void> _pruneAutoBackups() async {
    // یک بار لیست کن و بر اساس زمان واقعی تغییر مرتب کن (مقایسه نام فایل
    // به فرمت timestamp در نام وابسته است و شکننده). mtime هم در جابجایی
    // بین فایل‌منیجر/کپی دستی قابل‌اعتمادتر است.
    final files = await listAutoBackups();
    if (files.length > 1) {
      final mtimes = <File, DateTime>{};
      for (final f in files) {
        try {
          mtimes[f] = await f.lastModified();
        } catch (e) {
          AppLogger.warning(
              'BackupService', 'auto-backup mtime read failed: $e');
          mtimes[f] = DateTime.fromMillisecondsSinceEpoch(0);
        }
      }
      final epoch = DateTime.fromMillisecondsSinceEpoch(0);
      files.sort((a, b) => (mtimes[b] ?? epoch).compareTo(mtimes[a] ?? epoch));
    }
    // Prune by count
    if (files.length > maxAutoBackups) {
      for (final f in files.skip(maxAutoBackups)) {
        try {
          await f.delete();
        } catch (e) {
          AppLogger.warning('BackupService', 'auto-backup prune failed: $e');
        }
      }
    }
    // Prune by total size (~50MB cap) — oldest (largest mtime age) first.
    const maxTotalBytes = 50 * 1024 * 1024;
    var total = 0;
    for (final f in files) {
      try {
        total += await f.length();
      } catch (e) {
        AppLogger.warning('BackupService', 'auto-backup size read failed: $e');
      }
    }
    if (total > maxTotalBytes) {
      for (final f in files.reversed) {
        if (total <= maxTotalBytes) break;
        try {
          final len = await f.length();
          await f.delete();
          total -= len;
        } catch (e) {
          AppLogger.warning(
              'BackupService', 'auto-backup cap delete failed: $e');
        }
      }
    }
  }

  Future<Map<String, dynamic>?> readBackupMeta(String zipPath) async {
    try {
      final zipBytes = await File(zipPath).readAsBytes();
      // Even reading the metadata decodes every entry, so gate it first.
      preflightArchiveBytes(zipBytes);
      final archive = ZipDecoder().decodeBytes(zipBytes);
      for (final file in archive) {
        if (file.name == 'backup_meta.json') {
          final content = utf8.decode(file.content as List<int>);
          return jsonDecode(content) as Map<String, dynamic>;
        }
      }
    } catch (e) {
      AppLogger.warning('Backup meta read error', e.toString());
    }
    return null;
  }

  /// Restoring a backup brings the «اطلاعات من» rows as `enc:` ciphertext, but
  /// the AES key that opens them is sealed in the *old* device's Keystore and
  /// deliberately never travels in the archive (`personal_info.*` is filtered
  /// out). On a device that has no vault key of its own those fields come back
  /// blank with no error anywhere, so every restore confirmation says so.
  ///
  /// Returns '' when this device already holds a key (a same-device restore,
  /// which decrypts fine) or the Keystore cannot be answered quickly — this
  /// text gates a confirmation dialog, so a slow Keystore must not make the
  /// restore button look dead. Fail-open: the note is informational.
  static Future<String> vaultRestoreCaveat() async {
    try {
      final hasKey = await PinLockService.vaultExists()
          .timeout(const Duration(milliseconds: 800));
      if (hasKey) return '';
    } catch (e) {
      AppLogger.warning('BackupService', 'vault key check failed: $e');
      return '';
    }
    return '\n\nنکته: اگر در گوشی قبلی بخش «اطلاعات من» را رمزگذاری کرده باشید، '
        'محتوای آن در این گوشی خالی می‌ماند؛ کلید رمزگشایی در حافظهٔ امن همان '
        'گوشی می‌ماند و در فایل پشتیبان نمی‌آید.';
  }

  /// بازیابی با روش ATTACH DATABASE:
  /// فایل پشتیبان SQLite را به‌عنوان دیتابیس مجازی متصل می‌کند و داده‌ها را
  /// از طریق SQL روی دیتابیس فعلی import می‌کند — بدون نیاز به بستن دیتابیس یا ریستارت.
  Future<RestoreOutcome> restoreBackup(String zipPath,
      {AppDatabase? database, List<int>? zipBytes, String? password}) async {
    zipBytes ??= await File(zipPath).readAsBytes();
    // Encrypted archives are opaque ZIPs: decrypt first. A missing password
    // surfaces as [BackupPasswordRequiredException] so the UI can prompt and
    // retry; an auto-backup sealed with this device's key needs no prompt, and
    // its missing-key case is a distinct, honest explanation.
    if (isEncryptedBackup(zipBytes)) {
      if (isDeviceKeyBackup(zipBytes)) {
        zipBytes = await decryptBackupBytesWithDeviceKey(zipBytes);
      } else {
        if (password == null || password.isEmpty) {
          throw const BackupPasswordRequiredException();
        }
        zipBytes = await decryptBackupBytes(zipBytes, password);
      }
    }
    // Refuse an over-large archive from the central directory, before any
    // entry is expanded into memory.
    preflightArchiveBytes(zipBytes);
    final archive = ZipDecoder().decodeBytes(zipBytes);
    assertArchiveWithinLimits(archive);
    final dir = await getApplicationDocumentsDirectory();

    // اعتبارسنجی متادیتا
    Map<String, dynamic>? meta;
    for (final file in archive) {
      if (file.name == 'backup_meta.json') {
        try {
          final content = utf8.decode(file.content as List<int>);
          meta = jsonDecode(content) as Map<String, dynamic>;
        } catch (e) {
          AppLogger.warning('Backup meta error', e.toString());
        }
        break;
      }
    }
    if (meta == null || meta['app'] != 'tawheeed') {
      throw Exception(
          'فایل پشتیبان نامعتبر است. لطفاً یک فایل پشتیبان معتبر انتخاب کنید.');
    }
    final backupSchemaVersion = meta['schema_version'] as int? ?? 0;
    if (backupSchemaVersion > AppDatabase.currentSchemaVersion) {
      throw Exception(
          'فایل پشتیبان از نسخه جدیدتر برنامه است. لطفاً ابتدا برنامه را به‌روز کنید.');
    }

    // Verify the manifest before touching the live database. Older backups may
    // not have one and remain readable for backwards compatibility.
    final manifestFile =
        archive.where((f) => f.name == 'backup_manifest.json').firstOrNull;
    if (manifestFile != null) {
      final manifest =
          jsonDecode(utf8.decode(manifestFile.content as List<int>));
      if (manifest is! Map || manifest['files'] is! Map) {
        throw Exception('فهرست صحت فایل پشتیبان نامعتبر است.');
      }
      final entries = (manifest['files'] as Map).cast<String, dynamic>();
      for (final entry in entries.entries) {
        final file = archive.where((f) => f.name == entry.key).firstOrNull;
        final expected = entry.value as String?;
        if (file == null ||
            expected == null ||
            sha256.convert(file.content as List<int>).toString() != expected) {
          throw Exception('فایل پشتیبان آسیب‌دیده یا دستکاری‌شده است.');
        }
      }
    }

    // استخراج فایل SQLite پشتیبان به یک فایل موقت
    List<int>? dbBytes;
    List<int>? walBytes;
    for (final file in archive) {
      if (file.name == 'app.sqlite') {
        dbBytes = file.content as List<int>;
      } else if (file.name == 'app.sqlite-wal') {
        walBytes = file.content as List<int>;
      }
    }
    if (dbBytes == null) {
      throw Exception('فایل پشتیبان حاوی دیتابیس نیست.');
    }
    if (database == null) {
      throw ArgumentError('database برای بازگردانی پشتیبان الزامی است.');
    }

    // ── یک نسخهٔ ایمنی از وضعیت فعلی، پیش از هر چیز مخرب ────────────────
    //
    // A restore REPLACES every table (DELETE + INSERT per table below), so
    // restoring the wrong file is otherwise final — the confirmation dialog
    // can only ask, not undo. Take a real, restorable archive of what is here
    // first. Device-key sealed like the daily auto-backup, and named with the
    // same prefix so it appears in the backup list the user already knows.
    String? safetyCopyPath;
    try {
      final backupsDir = await autoBackupDirectory();
      final copy = await exportBackup(
        directory: backupsDir.path,
        deviceKey: true,
        prefix: 'tawheeed_backup_pre_restore',
      );
      safetyCopyPath = copy.path;
      AppLogger.info(
          'BackupService', 'pre-restore safety copy written: $safetyCopyPath');
    } catch (e, st) {
      // Never block the restore on this, but never pretend either: the user is
      // about to overwrite the only copy of what is on the device.
      AppLogger.error('BackupService', 'pre-restore safety copy failed: $e', st);
    }

    // فایل‌های اذان شخصی — چون نام فایل ثابت است، مسیر ذخیره‌شده در دیتابیس
    // پس از بازگردانی روی هر دستگاهی معتبر می‌ماند.
    //
    // WHY a staging folder: these used to be written straight into
    // `custom_azans/` and `app_data/` *before* the transaction. When the
    // transaction then failed (corrupt table, schema mismatch, disk full) the
    // database rolled back but the files had already been replaced — the
    // device kept the backup's attachments beside the old database, pointing
    // at rows that no longer matched them.
    final stagingRoot = Directory(p.join(
        dir.path, 'restore_staging_${DateTime.now().millisecondsSinceEpoch}'));
    final stagedAzan = Directory(p.join(stagingRoot.path, 'custom_azans'));
    final stagedAppData = Directory(p.join(stagingRoot.path, 'app_data'));
    var stagedAzanFiles = 0;
    for (final file in archive) {
      if (!file.name.startsWith('custom_azans/')) continue;
      final dest = File(p.join(stagedAzan.path, p.basename(file.name)));
      await dest.parent.create(recursive: true);
      await dest.writeAsBytes(file.content as List<int>);
      stagedAzanFiles++;
    }

    // فایل‌های داده جانبی اپ (تصاویر مدارک/آواتار/پیوست‌ها و یادداشت‌های صوتی).
    var stagedAppDataFiles = 0;
    for (final file in archive) {
      if (!file.name.startsWith('app_data/')) continue;
      // نام‌های داخل آرشیو ورودی نامعتبرند (کاربر یا فایل دستکاری‌شده): هر
      // مسیر مطلق، «..» یا سگمنت خالی می‌تواند از پوشه مقصد بیرون بزند یا
      // فایل‌های موجود را بازنویسی کند، پس نادیده گرفته می‌شود.
      final rel = _safeArchiveRelativePath(file.name);
      if (rel == null) {
        AppLogger.warning(
            'BackupService', 'rejected unsafe archive entry ${file.name}');
        continue;
      }
      final dest = File(p.joinAll([stagingRoot.path, ...rel]));
      await dest.parent.create(recursive: true);
      await dest.writeAsBytes(file.content as List<int>);
      stagedAppDataFiles++;
    }

    final tempPath =
        '${dir.path}/restore_temp_${DateTime.now().millisecondsSinceEpoch}.sqlite';
    await File(tempPath).writeAsBytes(dbBytes);

    // اگر نسخه‌ای از WAL در پشتیبان وجود دارد، کنار فایل دیتابیس موقت بنویسیم
    // تا SQLite هنگام باز کردن/متصل‌کردن، تراکنش‌های commit‌شده در WAL را خودکار
    // replay کند و داده‌ها از بین نروند. (فایل SHM هرگز بازگردانی نمی‌شود؛ خودکار ساخته می‌شود.)
    if (walBytes != null && walBytes.isNotEmpty) {
      await File('$tempPath-wal').writeAsBytes(walBytes);
    }

    int restoredCount = 0;
    try {
      // متصل کردن دیتابیس پشتیبان به‌عنوان "backup_db"
      await database
          .customStatement('ATTACH DATABASE ? AS backup_db', [tempPath]);

      // گرفتن لیست جدول‌های اصلی (غیر از sqlite_*)
      // نکتهٔ حیاتی: داخلِ transaction فقط از متدهای خودِ دیتابیس
      // (customSelect/customStatement) استفاده کن، نه `database.executor`.
      // executor پایه هنگام فعال بودن تراکنش قفل والد را تا پایان آن نگه می‌دارد؛
      // هر statement مستقیم روی آن برای همیشه منتظر می‌ماند (دِدلاک restore).
      final tableRows = (await database
              .customSelect(
                  "SELECT name FROM backup_db.sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")
              .get())
          .map((r) => r.read<String>('name'))
          .where((name) => RegExp(r'^[A-Za-z0-9_]+$').hasMatch(name))
          .toSet();
      final sourceNames = tableRows;
      final currentRows = (await database
              .customSelect(
                  "SELECT name FROM main.sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")
              .get())
          .map((r) => r.read<String>('name'))
          .toSet();
      final currentNames = currentRows;
      final tableNames = sourceNames.intersection(currentNames).toList();

      // غیرفعال کردن موقت foreign keys (Drift آن را فعال نمی‌کند، اما برای اطمینان)
      await database.customStatement('PRAGMA foreign_keys = OFF');
      try {
        await database.transaction(() async {
          for (final tableName in tableNames) {
            // کپی ستون‌محور: بکاپ قدیمی‌تر (اسکیمای پایین‌تر) ستون‌های جدید
            // اپ را ندارد و `SELECT *` موقعی با خطای تعداد ستون کل restore را
            // می‌شکند. تقاطع ستون‌ها بر اساس نام، همه ستون‌های مشترک را کپی
            // می‌کند؛ ستون‌های جدید اپ به DEFAULT/NULL خودشان برمی‌گردند و
            // ستون‌های حذف/تغییرنام‌یافته بی‌صدا رد می‌شوند.
            //
            // نکتهٔ حیاتی: داخلِ transaction فقط از متدهای خودِ دیتابیس
            // (customSelect/customStatement) استفاده کن، نه `database.executor`.
            // executor پایه هنگام فعال بودن تراکنش قفل والد را تا پایان آن
            // نگه می‌دارد؛ هر statement مستقیم روی آن برای همیشه منتظر
            // می‌ماند (دِدلاک و freeze کامل بازیابی پشتیبان).
            final sourceCols = (await database
                    .customSelect('PRAGMA backup_db.table_info("$tableName")')
                    .get())
                .map((r) => r.read<String>('name'))
                .toSet();
            final sharedCols = (await database
                    .customSelect('PRAGMA main.table_info("$tableName")')
                    .get())
                .map((r) => r.read<String>('name'))
                .where(sourceCols.contains)
                .toList();
            if (sharedCols.isEmpty) continue; // هیچ ستون مشترکی نیست — رد شود
            final colList = sharedCols.map((c) => '"$c"').join(', ');
            await database.customStatement('DELETE FROM "$tableName"');
            await database.customStatement(
              'INSERT INTO "$tableName" ($colList) '
              'SELECT $colList FROM backup_db."$tableName"',
            );
            restoredCount++;
          }

          // The documents dir differs per device, so the app_data paths the
          // backup carried are repointed at this device's dir. Done inside the
          // transaction so a failure rolls back with the copy.
          await _remapAppDataPaths(database, newDocsDir: dir.path);
        });

        // بازگردانی sqlite_sequence برای جدول‌های autoIncrement
        try {
          await database.executor
              .runDelete('DELETE FROM main.sqlite_sequence', []);
          await database.executor.runInsert(
            'INSERT INTO main.sqlite_sequence SELECT * FROM backup_db.sqlite_sequence',
            [],
          );
        } catch (e) {
          AppLogger.warning(
              'BackupService', 'sqlite_sequence restore failed: $e');
        }
      } finally {
        await database.customStatement('PRAGMA foreign_keys = ON');
      }
      await database.customStatement('DETACH DATABASE backup_db');

      // Only now — after the rows are committed — do the staged files land.
      final restoredAzanFiles = await _promoteStagedTree(
          stagedAzan, Directory(p.join(dir.path, 'custom_azans')));
      if (restoredAzanFiles > 0) {
        AppLogger.info(
            'BackupService', 'restored $restoredAzanFiles custom azan files');
      }
      final restoredAppDataFiles = await _promoteStagedTree(stagedAppData,
          Directory(p.join(dir.path, 'app_data')));
      if (restoredAppDataFiles > 0) {
        AppLogger.info(
            'BackupService', 'restored $restoredAppDataFiles app_data files');
      }
      if (stagedAzanFiles != restoredAzanFiles ||
          stagedAppDataFiles != restoredAppDataFiles) {
        // The database is restored but some files did not land. Say it loudly:
        // the affected rows now point at files that are not there.
        AppLogger.error(
            'BackupService',
            'restore file promotion incomplete — staged '
            '$stagedAzanFiles azan / $stagedAppDataFiles app_data, '
            'moved $restoredAzanFiles / $restoredAppDataFiles');
      }
    } catch (e) {
      // در صورت خطا، حتماً جدا کن
      try {
        await database.customStatement('DETACH DATABASE backup_db');
      } catch (detachErr) {
        AppLogger.warning('BackupService',
            'backup_db detach after failure failed: $detachErr');
      }
      rethrow;
    } finally {
      // پاک‌سازی فایل‌های موقت (دیتابیس + WAL + SHM + استیج)
      try {
        await File(tempPath).delete();
      } catch (e) {
        AppLogger.warning('BackupService', 'restore temp delete failed: $e');
      }
      try {
        await File('$tempPath-wal').delete();
      } catch (e) {
        AppLogger.warning(
            'BackupService', 'restore temp WAL delete failed: $e');
      }
      try {
        await File('$tempPath-shm').delete();
      } catch (e) {
        AppLogger.warning(
            'BackupService', 'restore temp SHM delete failed: $e');
      }
      try {
        if (await stagingRoot.exists()) {
          await stagingRoot.delete(recursive: true);
        }
      } catch (e) {
        AppLogger.warning(
            'BackupService', 'restore staging cleanup failed: $e');
      }
    }

    // بازیابی SharedPreferences از بکاپ (کلیدهای موقتی/ماشین-خاص بازگردانی
    // نمی‌شوند تا با وضعیت فعلی برنامه تداخل نکنند).
    final volatileKeys = <String>{
      ..._excludedPreferenceKeys,
      'last_bg_check',
      'home_reminders_',
    };
    for (final file in archive) {
      if (file.name == 'preferences.json') {
        try {
          final content = utf8.decode(file.content as List<int>);
          final prefsData = jsonDecode(content) as Map<String, dynamic>;
          final prefs = await SharedPreferences.getInstance();
          for (final entry in prefsData.entries) {
            if (volatileKeys
                .any((k) => entry.key == k || entry.key.startsWith(k))) {
              continue;
            }
            // Only keys the exporter is allowed to write, so a hostile archive
            // cannot inject arbitrary preferences (vault PIN, tokens, ...).
            if (!isRestorablePreferenceKey(entry.key)) {
              AppLogger.warning('BackupService',
                  'rejected preference "${entry.key}" on restore');
              continue;
            }
            final v = entry.value;
            if (v is List) {
              if (!isRestorablePreferenceValue(v)) continue;
              await prefs.setStringList(entry.key, v.cast<String>());
            } else if (!isRestorablePreferenceValue(v)) {
              continue;
            } else if (v is String) {
              await prefs.setString(entry.key, v);
            } else if (v is bool) {
              await prefs.setBool(entry.key, v);
            } else if (v is int) {
              await prefs.setInt(entry.key, v);
            } else if (v is double) {
              await prefs.setDouble(entry.key, v);
            }
          }
          restoredCount++;
        } catch (e) {
          AppLogger.warning('Backup prefs error', e.toString());
        }
        break;
      }
    }

    return RestoreOutcome(
      restoredTables: restoredCount,
      safetyCopyPath: safetyCopyPath,
    );
  }

  /// Erases every user datum on this device: all Drift rows, all
  /// SharedPreferences, the secure-storage items (prayer coordinates, vault
  /// key) and the `app_data` + `custom_azans` + `backups` folders. The user
  /// explicitly asked for a true factory state, so stored backup archives
  /// (manual zips and sealed auto-backups) go with everything else.
  /// Deliberately kept: downloaded content (recitation audio, books) —
  /// expensive to re-fetch and not personal data.
  ///
  /// Order is load-bearing: the database transaction runs FIRST so a failure
  /// rolls everything back instead of leaving a half-wiped device; anything
  /// that throws afterwards aborts the wipe loudly (logged + rethrown, never
  /// a success claim). The open connection stays valid throughout — no file
  /// is deleted while held, so there is no close/delete race and no
  /// double-close on the provider's `onDispose`.
  Future<LocalWipeResult> wipeAllLocalData(AppDatabase database) async {
    var tablesEmptied = 0;
    try {
      await database.transaction(() async {
        // FKs are enforced (PRAGMA foreign_keys = ON in `_openConnection`);
        // deferring them to the commit — where every table is empty — keeps
        // this future-proof when a new table with a foreign key arrives.
        // sqlite_master (not the compiled schema) is the source of truth so
        // a table drift does not know about is still wiped.
        await database.customStatement('PRAGMA defer_foreign_keys = ON');
        final tables = await database
            .customSelect(
              'SELECT name FROM sqlite_master '
              "WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
            )
            .get();
        for (final row in tables) {
          final name = row.read<String>('name');
          // Table names are app-created identifiers, but a hostile file
          // could carry a crafted sqlite_master entry — never interpolate
          // a quote into SQL.
          if (name.contains('"')) continue;
          await database.customStatement('DELETE FROM "$name"');
          tablesEmptied++;
        }
      });
      await database.customStatement('VACUUM');
    } catch (e) {
      AppLogger.error('BackupService', 'local wipe: database wipe failed: $e');
      rethrow;
    }

    final dir = await getApplicationDocumentsDirectory();
    var filesDeleted = 0;
    for (final name in const ['app_data', 'custom_azans', 'backups']) {
      try {
        final folder = Directory(p.join(dir.path, name));
        if (await folder.exists()) {
          await for (final _ in folder.list(recursive: true)) {
            filesDeleted++;
          }
          await folder.delete(recursive: true);
        }
      } catch (e) {
        AppLogger.error(
            'BackupService', 'local wipe: $name delete failed: $e');
        rethrow;
      }
    }

    try {
      await appSecureStorage.deleteAll();
    } catch (e) {
      AppLogger.error(
          'BackupService', 'local wipe: secure storage failed: $e');
      rethrow;
    }

    final prefs = await SharedPreferences.getInstance();
    final preferencesCleared = prefs.getKeys().length;
    try {
      final cleared = await prefs.clear();
      if (!cleared) throw StateError('SharedPreferences.clear() refused');
    } catch (e) {
      AppLogger.error('BackupService', 'local wipe: prefs clear failed: $e');
      rethrow;
    }
    return LocalWipeResult(
      tablesEmptied: tablesEmptied,
      preferencesCleared: preferencesCleared,
      filesDeleted: filesDeleted,
    );
  }

  Future<void> restartApp() async {
    await Future.delayed(const Duration(milliseconds: 200));
    try {
      SystemNavigator.pop();
    } catch (e) {
      AppLogger.warning(
          'BackupService', 'graceful restart failed, exiting: $e');
      exit(0);
    }
  }
}

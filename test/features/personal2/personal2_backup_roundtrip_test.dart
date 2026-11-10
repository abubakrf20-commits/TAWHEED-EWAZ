import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/personal2/data/personal2_tables.dart';
import 'package:tawheeed/features/settings/services/backup_service.dart';

/// Backup/restore round trip for the personal-tools set 2 data.
///
/// The brief's privacy rules are what these tests pin:
///  • a child's and a student's rows travel in the (encrypted-at-rest) app
///    backup, so a new phone does not lose a year of star history;
///  • the parent-lock throttle state does NOT travel — it is security state,
///    and a lockout belonging to someone else's brute-force attempt must not
///    greet the owner of a restored device;
///  • restore brings the rows back intact, including Persian text.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  const pkgChannel = MethodChannel('dev.fluttercommunity.plus/package_info');
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('personal2_backup');
    // Mirrors backup_service_test.dart: per-method mocks (a bare String return
    // breaks the package-info channel's Map contract) and an empty Keystore so
    // the export path has no device key to play with.
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
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pkgChannel, null);
    // Windows keeps the sqlite file handle briefly after drift closes; a
    // locked temp dir is the OS's to reclaim, and failing the tearDown for it
    // would bury the real assertion failures.
    for (var attempt = 0; attempt < 8; attempt++) {
      try {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
        break;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
  });

  /// A real database with one child, one log, one ledger row and one student
  /// lesson — enough to prove the round trip carries actual content.
  Future<File> seedDatabase(String fileName) async {
    final file = File(p.join(tempDir.path, fileName));
    if (file.existsSync()) file.deleteSync();
    final db = AppDatabase.withConnection(NativeDatabase(file));
    try {
      await db.customStatement('SELECT 1'); // runs onCreate incl. v46 tables

      await db.customStatement(
        'INSERT INTO ${Personal2Tables.kid} '
        '(id, name, birth_year, color_key, created_at, archived) '
        "VALUES ('k1', 'سارا', 1397, 'orange', 1700000000000, 0)",
      );
      await db.customStatement(
        'INSERT INTO ${Personal2Tables.kidHabit} '
        '(id, kid_id, title, icon_key, stars, schedule_type, weekday_mask, '
        'requires_approval, active, sort) '
        "VALUES ('h1', 'k1', 'مسواک زدن', 'brush', 1, 'daily', 127, 0, 1, 0)",
      );
      await db.customStatement(
        'INSERT INTO ${Personal2Tables.kidLog} '
        '(id, kid_id, day_key, date, habit_id, dedupe_key, status, stars, '
        'late, created_at) '
        "VALUES ('l1', 'k1', '1404-07-03', 1700000000000, 'h1', "
        "'k1|1404-07-03|h1|', 'approved', 1, 0, 1700000000000)",
      );
      await db.customStatement(
        'INSERT INTO ${Personal2Tables.classGroup} '
        '(id, name, place, weekdays_mask, archived, created_at) '
        "VALUES ('c1', 'کلاس الف', 'مسجد', 127, 0, 1700000000000)",
      );
      await db.customStatement(
        'INSERT INTO ${Personal2Tables.student} '
        '(id, class_id, name, parent_name, parent_phone, note, active, '
        'joined_at) '
        "VALUES ('s1', 'c1', 'علی', 'محمدی', '0912', '', 1, 1700000000000)",
      );
      await db.customStatement(
        'INSERT INTO ${Personal2Tables.lessonRecord} '
        '(id, session_id, student_id, day_key, date, type, page_start, '
        'page_end, grade_key, mistake_count, tajweed_tags, note, created_at) '
        "VALUES ('r1', 'ses1', 's1', '1404-07-03', 1700000000000, "
        "'recitation', 3, 5, 'good', 2, '[\"madd\"]', '', 1700000000000)",
      );
    } finally {
      await db.close();
    }
    return file;
  }

  test('export carries the personal2 rows, restore brings them back',
      () async {
    final dbFile = await seedDatabase('app.sqlite');

    final archiveFile =
        await BackupService().exportBackup(directory: tempDir.path);
    expect(archiveFile.existsSync(), isTrue);

    // The zip's database really contains the personal2 tables.
    final archive = ZipDecoder().decodeBytes(await archiveFile.readAsBytes());
    final dbEntry = archive.firstWhere((f) => f.name == 'app.sqlite');
    final restored = File(p.join(tempDir.path, 'unzipped.sqlite'))
      ..writeAsBytesSync(dbEntry.content as List<int>);
    final check = AppDatabase.withConnection(NativeDatabase(restored));
    try {
      await check.customStatement('SELECT 1');
      final kids = await check.customSelect(
        'SELECT name FROM ${Personal2Tables.kid} WHERE id = ?',
        variables: [const Variable<String>('k1')],
      ).get();
      expect(kids.single.read<String>('name'), 'سارا');
      final lessons = await check.customSelect(
        'SELECT page_start, page_end FROM ${Personal2Tables.lessonRecord} '
        'WHERE id = ?',
        variables: [const Variable<String>('r1')],
      ).get();
      expect(lessons.single.read<int>('page_start'), 3);
    } finally {
      await check.close();
    }

    // Now the restore path: a fresh database, the archive on top.
    final target = File(p.join(tempDir.path, 'target.sqlite'));
    final fresh = AppDatabase.withConnection(NativeDatabase(target));
    try {
      await fresh.customStatement('SELECT 1');
      // Sanity: the fresh database has the tables but no rows.
      final before = await fresh
          .customSelect('SELECT COUNT(*) AS n FROM ${Personal2Tables.kid}')
          .get();
      expect(before.single.read<int>('n'), 0);

      final outcome = await BackupService().restoreBackup(
        archiveFile.path,
        database: fresh,
      );
      expect(outcome.restoredTables, greaterThan(0));

      final kids = await fresh.customSelect(
        'SELECT name, color_key FROM ${Personal2Tables.kid} WHERE id = ?',
        variables: [const Variable<String>('k1')],
      ).get();
      expect(kids.single.read<String>('name'), 'سارا');

      final habits = await fresh.customSelect(
        'SELECT title FROM ${Personal2Tables.kidHabit} WHERE kid_id = ?',
        variables: [const Variable<String>('k1')],
      ).get();
      expect(habits.single.read<String>('title'), 'مسواک زدن');

      final students = await fresh.customSelect(
        'SELECT name FROM ${Personal2Tables.student} WHERE class_id = ?',
        variables: [const Variable<String>('c1')],
      ).get();
      expect(students.single.read<String>('name'), 'علی');
    } finally {
      await fresh.close();
      // Unused but keeps the analyzer honest about the seed file's role.
      expect(dbFile.existsSync(), isTrue);
    }
  });

  test('the parent-lock throttle state never leaves the device', () async {
    SharedPreferences.setMockInitialValues({
      'personal_info.parent_lock_failures': 3,
      'personal_info.parent_lock_until_ms': 1799999999999,
      'personal_info.parent_lock_burst': 2,
      'personal_info.pin_verifier_would_be_here': 'not-a-real-key',
      'theme_mode': 'dark',
    });
    await File(p.join(tempDir.path, 'app.sqlite')).writeAsString('db-bytes');

    final file = await BackupService().exportBackup(directory: tempDir.path);
    final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
    final prefs = jsonDecode(utf8.decode(archive
        .firstWhere((f) => f.name == 'preferences.json')
        .content as List<int>)) as Map<String, dynamic>;

    expect(prefs.containsKey('personal_info.parent_lock_failures'), isFalse);
    expect(prefs.containsKey('personal_info.parent_lock_until_ms'), isFalse);
    expect(prefs.containsKey('personal_info.parent_lock_burst'), isFalse);
    // Sanity: ordinary preferences still travel.
    expect(prefs, contains('theme_mode'));
  });

  test('every personal2 table name survives the backup name filter', () {
    // BackupService restores tables it finds in sqlite_master, filtered by
    // this regex — a table whose name fell outside it would silently never be
    // backed up, which is exactly the bug class the `allTables` list exists to
    // catch.
    for (final table in Personal2Tables.allTables) {
      expect(RegExp(r'^[A-Za-z0-9_]+$').hasMatch(table), isTrue,
          reason: '$table would be skipped by the restore name filter');
    }
  });
}

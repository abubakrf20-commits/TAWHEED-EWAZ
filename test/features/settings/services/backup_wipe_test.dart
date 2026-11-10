import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/settings/data/daos/settings_dao.dart';
import 'package:tawheeed/features/settings/data/datasources/settings_drift_datasource.dart';
import 'package:tawheeed/features/settings/services/backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;
  late AppDatabase db;

  Future<int> rowCount(String tableName) async {
    final rows =
        await db.customSelect('SELECT COUNT(*) AS c FROM "$tableName"').get();
    return rows.first.read<int>('c');
  }

  /// Every user table by sqlite_master (not the compiled schema), so a table
  /// drift does not declare is still counted.
  Future<List<String>> userTables() async {
    final rows = await db
        .customSelect('SELECT name FROM sqlite_master '
            "WHERE type = 'table' AND name NOT LIKE 'sqlite_%'")
        .get();
    return [for (final row in rows) row.read<String>('name')];
  }

  Future<int> totalRows() async {
    var total = 0;
    for (final name in await userTables()) {
      total += await rowCount(name);
    }
    return total;
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tawheeed_wipe');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return tempDir.path;
      }
      return null;
    });
    SharedPreferences.setMockInitialValues({
      'themeMode': 'dark',
      'onboarding_completed': true,
      'personal_info.pin_hash': 'deadbeef',
    });
    FlutterSecureStorage.setMockInitialValues({
      'saved_lat': '35.7',
      'saved_lng': '51.4',
    });
    db = AppDatabase.withConnection(NativeDatabase.memory());

    // Seed content across stores: two notes, a goal with a child progress
    // row (exercises the FK-deferred wipe), prefs, secure items and files.
    final now = DateTime.now();
    await db.into(db.noteTable).insert(NoteTableCompanion.insert(
          id: 'n1',
          title: 't',
          content: 'c',
          createdAt: now,
          updatedAt: now,
          tags: '',
          isDone: false,
          colorIndex: 0,
          isPinned: false,
        ));
    await db.into(db.goalTable).insert(GoalTableCompanion.insert(
          id: 'g1',
          title: 'g',
          createdAt: now,
          updatedAt: now,
        ));
    await db.into(db.goalProgressTable).insert(
          GoalProgressTableCompanion.insert(
            id: 'p1',
            goalId: 'g1',
            date: '2026-10-15',
            createdAt: now,
          ),
        );
    for (final name in ['app_data', 'custom_azans', 'backups']) {
      final dir = Directory(p.join(tempDir.path, name));
      await dir.create(recursive: true);
      await File(p.join(dir.path, 'keep.txt')).writeAsString('x');
    }
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    await db.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('wipeAllLocalData', () {
    test('empties every table, prefs, secure storage and app dirs',
        () async {
      expect(await totalRows(), greaterThan(0));

      final result = await BackupService().wipeAllLocalData(db);

      expect(await totalRows(), 0);
      expect(result.tablesEmptied, (await userTables()).length);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
      expect(result.preferencesCleared, 3);

      const storage = FlutterSecureStorage();
      expect(await storage.read(key: 'saved_lat'), isNull);
      expect(await storage.read(key: 'saved_lng'), isNull);

      expect(Directory(p.join(tempDir.path, 'app_data')).existsSync(),
          isFalse);
      expect(Directory(p.join(tempDir.path, 'custom_azans')).existsSync(),
          isFalse);
      // Decision 1: the wipe reaches the factory state, backup archives too.
      expect(Directory(p.join(tempDir.path, 'backups')).existsSync(), isFalse);
      expect(result.filesDeleted, 3);
    });

    test('settings read back as factory defaults after a wipe', () async {
      await BackupService().wipeAllLocalData(db);

      final dto = await SettingsDriftDataSource(SettingsDao(db)).load();
      expect(dto.id, 'default');
    });

    test('a second wipe on an empty store still succeeds', () async {
      await BackupService().wipeAllLocalData(db);
      final again = await BackupService().wipeAllLocalData(db);
      expect(await totalRows(), 0);
      expect(again.tablesEmptied, (await userTables()).length);
    });
  });
}

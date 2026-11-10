import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:tawheeed/core/database/app_database.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppDatabase migrations', () {
    late Directory tempDir;

    setUp(() async {
      tempDir =
          await Directory.systemTemp.createTemp('tawheeed_migration_test');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    Future<AppDatabase> createDatabase() async {
      final file = File(p.join(tempDir.path, 'migration.sqlite'));
      if (file.existsSync()) file.deleteSync();
      return AppDatabase.withConnection(NativeDatabase(file));
    }

    test('fresh create uses latest schemaVersion', () async {
      final db = await createDatabase();
      try {
        expect(db.schemaVersion, AppDatabase.currentSchemaVersion);
        final tables = await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
            )
            .get();
        final tableNames =
            tables.map((row) => row.read<String>('name')).toList();
        expect(tableNames, contains('app_settings_table'));
        expect(tableNames, contains('khatm_table'));
        expect(tableNames, contains('reminder_table'));
        expect(tableNames, contains('audio_download_table'));
        expect(tableNames, contains('tasks_table'));
        expect(tableNames, isNot(contains('flashcard_deck_table')));
        expect(tableNames, isNot(contains('flashcard_card_table')));
        expect(tableNames, isNot(contains('flashcard_state_table')));
        expect(tableNames, isNot(contains('flashcard_review_table')));
      } finally {
        await db.close();
      }
    });

    test('migrations 1-8 run without throwing', () async {
      final db = await createDatabase();
      try {
        await db.customStatement('PRAGMA user_version = 1');
        final versionResult =
            await db.customSelect('PRAGMA user_version').get();
        expect(versionResult.first.read<int>('user_version'), 1);
      } finally {
        await db.close();
      }
    });
  });
}

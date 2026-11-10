import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:tawheeed/features/settings/data/daos/settings_dao.dart';
import 'package:tawheeed/features/settings/data/datasources/settings_drift_datasource.dart';
import 'package:tawheeed/features/settings/data/datasources/settings_local_datasource.dart';
import 'package:tawheeed/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/shared/models/day_time.dart';

import 'package:tawheeed/core/database/app_database.dart';

/// Schema v44 — the two settings columns that entered the table definition and
/// never got a migration step: `friday_prayer_time` (added by `55cc89e` with
/// `currentSchemaVersion` unchanged, so `onUpgrade` never ran for it) and
/// `quran_theme_mode` (added by `4f0cd47`, the commit that introduced the
/// migration strategy, which never ALTERed the settings table either).
///
/// On a FRESH install `onCreate` builds the table from the current definition,
/// so the columns exist and everything works — which is why no existing test
/// ever caught this. On an install whose database predates those commits the
/// columns are absent, and because Drift's generated SELECT lists every column
/// by name, **every settings read and write throws** ("no such column"). The
/// user then sees the factory defaults and no control responds — the reported
/// «ظاهر برنامه / تم برنامه / اندازه فونت / صدای اذان قفل است».
///
/// These tests recreate exactly that database (the current schema minus the two
/// columns) and require the v44 step to repair it, so the settings row becomes
/// readable and writable again without losing anything.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tawheeed_v44_test');
  });

  tearDown(() async {
    // Windows can hold a just-closed sqlite file open for a while; never let
    // cleanup fail an already-green test.
    for (var attempt = 0; attempt < 8; attempt++) {
      try {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
        break;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
  });

  /// A database in the shape an upgraded install actually has: every current
  /// column except the two no migration ever added.
  Future<File> legacySettingsDb(String name) async {
    final file = File(p.join(tempDir.path, name));
    final build = AppDatabase.withConnection(NativeDatabase(file));
    // Drift opens lazily: touch the table so onCreate actually builds it.
    await build.select(build.appSettingsTable).get();
    await build.close();
    final raw = sqlite3.open(file.path);
    raw.execute(
        'ALTER TABLE app_settings_table DROP COLUMN friday_prayer_time');
    raw.execute('ALTER TABLE app_settings_table DROP COLUMN quran_theme_mode');
    raw.execute('PRAGMA user_version = 43');
    raw.close();
    return file;
  }

  Future<Set<String>> columnsOf(AppDatabase db, String table) async {
    final rows = await db.customSelect('PRAGMA table_info($table)').get();
    return rows.map((r) => r.read<String>('name')).toSet();
  }

  group('schema v44 (the two never-migrated settings columns)', () {
    test('a pre-v44 database gains both columns on upgrade', () async {
      final file = await legacySettingsDb('v43_missing_columns.sqlite');

      final db = AppDatabase.withConnection(NativeDatabase(file));
      try {
        final columns = await columnsOf(db, 'app_settings_table');
        expect(columns, contains('friday_prayer_time'),
            reason: 'the column exists in the definition, so SELECT names it');
        expect(columns, contains('quran_theme_mode'),
            reason: 'the column exists in the definition, so SELECT names it');

        final v = await db
            .customSelect('PRAGMA user_version')
            .getSingle()
            .then((r) => r.read<int>('user_version'));
        expect(v, AppDatabase.currentSchemaVersion);
      } finally {
        await db.close();
      }
    });

    test('the repaired database reads and writes the settings row again',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final file = await legacySettingsDb('v43_roundtrip.sqlite');

      final db = AppDatabase.withConnection(NativeDatabase(file));
      try {
        final repo = SettingsRepositoryImpl(
          driftDataSource: SettingsDriftDataSource(SettingsDao(db)),
          localDataSource: SettingsLocalDataSource(prefs),
        );

        // Before the repair these two calls are what every screen does: a
        // generated SELECT over the whole row (throws while a column is
        // missing) and the settings write behind every Settings toggle.
        final loaded = await repo.getSettings();
        expect(loaded.id, 'default');

        await repo.updateSettings(const AppSettings().copyWith(
          themeMode: ThemeModeOption.dark,
          accentPreset: 'dawn',
          appFontSize: 21,
          fontScale: 21 / 15.0,
          azanVolume: 0.4,
          quranThemeMode: QuranThemeMode.followApp,
          fridayPrayerTime: const DayTime(hour: 12, minute: 45),
        ));
        final reloaded = await repo.getSettings();
        expect(reloaded.themeMode, ThemeModeOption.dark);
        expect(reloaded.accentPreset, 'dawn');
        expect(reloaded.appFontSize, 21);
        expect(reloaded.azanVolume, 0.4);
        expect(reloaded.quranThemeMode, QuranThemeMode.followApp);
        expect(reloaded.fridayPrayerTime?.hour, 12);
      } finally {
        await db.close();
      }
    });

    test('repair is a no-op on a database that already has both columns',
        () async {
      final file = File(p.join(tempDir.path, 'already_repaired.sqlite'));
      final first = AppDatabase.withConnection(NativeDatabase(file));
      await first.select(first.appSettingsTable).get();
      await first.close();

      // Second open of the same file: user_version is current, so onUpgrade
      // does not run at all. A database still on v43 that was repaired by hand
      // must also survive the step without a "duplicate column" failure.
      final raw = sqlite3.open(file.path);
      raw.execute('PRAGMA user_version = 43');
      raw.close();

      final db = AppDatabase.withConnection(NativeDatabase(file));
      try {
        final columns = await columnsOf(db, 'app_settings_table');
        expect(columns, contains('friday_prayer_time'));
        expect(columns, contains('quran_theme_mode'));
      } finally {
        await db.close();
      }
    });

    test('a fresh install carries both columns and the default row works',
        () async {
      final db = AppDatabase.withConnection(NativeDatabase.memory());
      try {
        final columns = await columnsOf(db, 'app_settings_table');
        expect(columns, contains('friday_prayer_time'));
        expect(columns, contains('quran_theme_mode'));

        final row = await db.select(db.appSettingsTable).getSingleOrNull();
        expect(row, isNull, reason: 'a fresh database has no settings row yet');
      } finally {
        await db.close();
      }
    });
  });
}

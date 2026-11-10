import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'package:tawheeed/core/database/app_database.dart';

/// Simulates a real device upgrade: a database created by the RELEASE build
/// (schema 15, with real user data) opened by the CURRENT build.
///
/// The release schema is recreated from raw SQL that mirrors the tables as
/// they existed at schema 15 (see the git history of app_database.dart).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tawheeed_upgrade');
  });

  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Creates a database with the schema-15 table layout (subset sufficient
  /// to test the 15→16 migration) plus real user data, then closes it.
  File createSchema15DbWithData() {
    final file = File(p.join(tempDir.path, 'old.sqlite'));
    final db = sqlite3.open(file.path);

    // Minimal schema-15 layout for the tables touched by the migration.
    db.execute('''
      CREATE TABLE khatm_table (
        id TEXT NOT NULL PRIMARY KEY,
        title TEXT NOT NULL,
        start_date INTEGER NOT NULL,
        end_date INTEGER,
        target_days INTEGER NOT NULL,
        pages_read TEXT NOT NULL,
        is_completed INTEGER NOT NULL,
        participant_names TEXT NOT NULL,
        participant_assigned_juzs TEXT NOT NULL
      );
      CREATE TABLE app_settings_table (
        id TEXT NOT NULL PRIMARY KEY,
        calculation_method INTEGER NOT NULL,
        asr_method INTEGER NOT NULL,
        use_location INTEGER NOT NULL,
        city TEXT,
        manual_lat REAL,
        manual_lng REAL,
        has_location INTEGER NOT NULL,
        custom_fajr_angle REAL NOT NULL,
        custom_isha_angle REAL NOT NULL,
        fajr_offset INTEGER NOT NULL,
        sunrise_offset INTEGER NOT NULL,
        dhuhr_offset INTEGER NOT NULL,
        asr_offset INTEGER NOT NULL,
        maghrib_offset INTEGER NOT NULL,
        isha_offset INTEGER NOT NULL,
        iqamah_offset_fajr INTEGER NOT NULL,
        iqamah_offset_dhuhr INTEGER NOT NULL,
        iqamah_offset_asr INTEGER NOT NULL,
        iqamah_offset_maghrib INTEGER NOT NULL,
        iqamah_offset_isha INTEGER NOT NULL,
        prayer_notifications INTEGER NOT NULL,
        prayer_notif_minutes INTEGER NOT NULL,
        morning_azkar_notification INTEGER NOT NULL,
        morning_azkar_time_hour INTEGER NOT NULL,
        morning_azkar_time_minute INTEGER NOT NULL,
        evening_azkar_notification INTEGER NOT NULL,
        evening_azkar_time_hour INTEGER NOT NULL,
        evening_azkar_time_minute INTEGER NOT NULL,
        quran_reminder INTEGER NOT NULL,
        quran_reminder_time_hour INTEGER NOT NULL,
        quran_reminder_time_minute INTEGER NOT NULL,
        silent_during_prayer INTEGER NOT NULL,
        silent_duration INTEGER NOT NULL,
        silent_before_iqamah INTEGER NOT NULL,
        silent_before_iqamah_minutes INTEGER NOT NULL,
        daily_verse INTEGER NOT NULL,
        daily_verse_time_hour INTEGER NOT NULL,
        daily_verse_time_minute INTEGER NOT NULL,
        daily_hadith INTEGER NOT NULL,
        daily_hadith_time_hour INTEGER NOT NULL,
        daily_hadith_time_minute INTEGER NOT NULL,
        daily_dua INTEGER NOT NULL,
        daily_dua_time_hour INTEGER NOT NULL,
        daily_dua_time_minute INTEGER NOT NULL,
        daily_word_enabled INTEGER NOT NULL,
        daily_word_hour INTEGER NOT NULL,
        daily_word_minute INTEGER NOT NULL,
        theme_mode TEXT NOT NULL,
        quran_theme_mode TEXT NOT NULL,
        font_family TEXT NOT NULL,
        font_scale REAL NOT NULL,
        show_arabic_text INTEGER NOT NULL,
        show_daleel INTEGER NOT NULL,
        large_arabic_font INTEGER NOT NULL,
        show_english_translation INTEGER NOT NULL,
        quran_font_size REAL NOT NULL,
        app_font_size REAL NOT NULL,
        accent_preset TEXT NOT NULL,
        is_premium INTEGER NOT NULL,
        use_12_hour INTEGER NOT NULL,
        azan_sound TEXT NOT NULL,
        custom_azan_path TEXT,
        azan_volume REAL NOT NULL,
        azan_enabled_for_fajr INTEGER NOT NULL,
        azan_enabled_for_dhuhr INTEGER NOT NULL,
        azan_enabled_for_asr INTEGER NOT NULL,
        azan_enabled_for_maghrib INTEGER NOT NULL,
        azan_enabled_for_isha INTEGER NOT NULL,
        widget_refresh_minutes INTEGER NOT NULL,
        tafsir_id INTEGER NOT NULL,
        first_launch INTEGER NOT NULL,
        onboarding_completed INTEGER NOT NULL,
        hijri_offset INTEGER NOT NULL,
        quick_actions TEXT NOT NULL,
        tasbih_dhikr_source TEXT NOT NULL,
        timezone TEXT NOT NULL
      );
      -- Tables that already existed at schema 15 (created by earlier
      -- migrations) must be present or later addColumn steps fail with
      -- "no such table". Minimal shape is enough: the test only asserts
      -- khatm/settings survival, these just need to exist.
      CREATE TABLE tasks_table (
        id TEXT NOT NULL PRIMARY KEY
      );
      CREATE TABLE note_table (
        id TEXT NOT NULL PRIMARY KEY
      );
      CREATE TABLE expense_table (
        id TEXT NOT NULL PRIMARY KEY
      );
      -- Period table: existed long before schema 11 (which already ALTERs it)
      -- and schema 34 ADD COLUMNs record_type/flow/istihadha_type onto it.
      CREATE TABLE period_record_table (
        id INTEGER NOT NULL PRIMARY KEY,
        start_date INTEGER NOT NULL,
        end_date INTEGER,
        period_length INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        symptoms TEXT,
        notes TEXT
      );
    ''');

    // User data that must survive the upgrade.
    db.execute('''
      INSERT INTO khatm_table VALUES (
        'k1', 'ختم کامل', 1720000000000, 1723000000000, 90,
        '1,2,3', 0, '', ''
      );
      INSERT INTO app_settings_table (
        id, calculation_method, asr_method, use_location, city,
        manual_lat, manual_lng, has_location, custom_fajr_angle,
        custom_isha_angle, fajr_offset, sunrise_offset, dhuhr_offset,
        asr_offset, maghrib_offset, isha_offset, iqamah_offset_fajr,
        iqamah_offset_dhuhr, iqamah_offset_asr, iqamah_offset_maghrib,
        iqamah_offset_isha, prayer_notifications, prayer_notif_minutes,
        morning_azkar_notification, morning_azkar_time_hour,
        morning_azkar_time_minute, evening_azkar_notification,
        evening_azkar_time_hour, evening_azkar_time_minute,
        quran_reminder, quran_reminder_time_hour,
        quran_reminder_time_minute, silent_during_prayer, silent_duration,
        silent_before_iqamah, silent_before_iqamah_minutes, daily_verse,
        daily_verse_time_hour, daily_verse_time_minute, daily_hadith,
        daily_hadith_time_hour, daily_hadith_time_minute, daily_dua,
        daily_dua_time_hour, daily_dua_time_minute, daily_word_enabled,
        daily_word_hour, daily_word_minute, theme_mode, quran_theme_mode,
        font_family, font_scale, show_arabic_text, show_daleel,
        large_arabic_font, show_english_translation, quran_font_size,
        app_font_size, accent_preset, is_premium, use_12_hour, azan_sound,
        custom_azan_path, azan_volume, azan_enabled_for_fajr,
        azan_enabled_for_dhuhr, azan_enabled_for_asr,
        azan_enabled_for_maghrib, azan_enabled_for_isha,
        widget_refresh_minutes, tafsir_id, first_launch,
        onboarding_completed, hijri_offset, quick_actions,
        tasbih_dhikr_source, timezone
      ) VALUES (
        'default', 0, 0, 1, 'تهران', 35.6892, 51.3890, 1, 18.0, 18.0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 20, 1, 6, 30, 1, 17, 30,
        0, 21, 0, 0, 30, 0, 10, 0, 12, 0, 0, 12, 0, 0, 12, 0, 0, 9,
        0, 'system', 'light', 'calibri', 1.0, 1, 1, 0, 1, 22.0, 15.0,
        'green', 0, 1, 'kamel', NULL, 1.0, 1, 1, 1, 1, 1, 30, 1,
        0, 0, 0, 'prayer,quran', 'default', ''
      );
    ''');

    db.execute('PRAGMA user_version = 15');
    db.close();
    return file;
  }

  test('schema-15 DB with data upgrades cleanly to 20 and keeps data',
      () async {
    final file = createSchema15DbWithData();

    // Re-open with the CURRENT AppDatabase (schema 20) — this is the exact
    // code path that runs on the user's device after installing the update.
    final db = AppDatabase.withConnection(NativeDatabase(file));
    try {
      // The migration should have run without wiping anything.
      final khatms = await db.customSelect('SELECT * FROM khatm_table').get();
      expect(khatms, hasLength(1),
          reason: 'Khatm data must survive the 15→16 migration');

      final settings =
          await db.customSelect('SELECT * FROM app_settings_table').get();
      expect(settings, hasLength(1),
          reason: 'Settings row must survive the 15→16 migration');
      expect(settings.first.read<String>('city'), 'تهران');

      final version = await db.customSelect('PRAGMA user_version').get();
      expect(version.first.read<int>('user_version'),
          AppDatabase.currentSchemaVersion);
    } finally {
      await db.close();
    }
  });

  test('schema-30 DB upgrades to latest adding high_latitude_rule default 0',
      () async {
    final file = File(p.join(tempDir.path, 'v30.sqlite'));
    final setup = sqlite3.open(file.path);
    // Minimal v30 layout: real v30 databases always contain the expense
    // tables (created back at schema 18), so the v33 migration's addColumn
    // to dangi_expense_table targets an existing table.
    setup.execute(
        'CREATE TABLE app_settings_table (id TEXT NOT NULL PRIMARY KEY, city TEXT)');
    setup.execute(
        'CREATE TABLE dangi_expense_table (id TEXT NOT NULL PRIMARY KEY)');
    // Real v30 databases always contain the notes table (it predates schema 30
    // by a long way), and the v37 voice-note migration ALTERs it to add the
    // audio columns, so the fixture must too.
    setup.execute('CREATE TABLE note_table (id TEXT NOT NULL PRIMARY KEY)');
    // Real v30 databases always contain the period table (schema ≤ 11); the
    // schema-34 migration ALTERs it, so the fixture must too.
    setup.execute('''
      CREATE TABLE period_record_table (
        id INTEGER NOT NULL PRIMARY KEY,
        start_date INTEGER NOT NULL,
        end_date INTEGER,
        period_length INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        symptoms TEXT,
        notes TEXT
      )
    ''');
    setup.execute(
        "INSERT INTO app_settings_table (id, city) VALUES ('default', 'تهران')");
    setup.execute('PRAGMA user_version = 30');
    setup.close();

    final db = AppDatabase.withConnection(NativeDatabase(file));
    try {
      final rows = await db
          .customSelect(
              'SELECT id, city, high_latitude_rule FROM app_settings_table')
          .get();
      expect(rows, hasLength(1));
      expect(rows.first.read<String>('city'), 'تهران');
      expect(rows.first.read<int>('high_latitude_rule'), 0);

      final version = await db.customSelect('PRAGMA user_version').get();
      expect(version.first.read<int>('user_version'),
          AppDatabase.currentSchemaVersion);
    } finally {
      await db.close();
    }
  });
}

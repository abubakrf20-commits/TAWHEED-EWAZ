import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/settings/data/daos/settings_dao.dart';
import 'package:tawheeed/features/settings/data/datasources/settings_drift_datasource.dart';
import 'package:tawheeed/features/settings/data/datasources/settings_local_datasource.dart';
import 'package:tawheeed/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/shared/models/day_time.dart';

/// Proves the real persistence chain (Drift row + repository) survives a full
/// save → reload cycle, which is exactly what the settings screens rely on.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AppDatabase db;
  late SettingsRepositoryImpl repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tawheeed_settings_rt');
    final file = File(p.join(tempDir.path, 'settings.sqlite'));
    db = AppDatabase.withConnection(NativeDatabase(file));
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    repo = SettingsRepositoryImpl(
      driftDataSource: SettingsDriftDataSource(SettingsDao(db)),
      localDataSource: SettingsLocalDataSource(prefs),
    );
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('save then reload keeps every changed field', () async {
    // 1) Start from defaults, apply a broad set of changes (every category).
    final defaults = await repo.getSettings();
    expect(defaults.themeMode, ThemeModeOption.light);

    final updated = defaults.copyWith(
      themeMode: ThemeModeOption.dark,
      asrMethod: AsrMethod.hanafi,
      // جابجایی کلی — persisted outside the Drift row (see repository
      // [SettingsRepositoryImpl.globalOffsetKey]); a restart must keep it.
      globalPrayerOffset: 60,
      prayerNotifications: false,
      morningAzkarNotification: false,
      morningAzkarTime: const DayTime(hour: 7, minute: 30),
      eveningAzkarTime: const DayTime(hour: 21, minute: 15),
      quranReminder: true,
      quranReminderTime: const DayTime(hour: 9, minute: 45),
      azanSound: 'kamel',
      azanVolume: 0.6,
      hijriOffset: -1,
      tafsirId: 191,
      use12Hour: false,
      accentPreset: 'teal',
      dailyVerse: false,
      dailyHadith: false,
      widgetRefreshMinutes: 60,
      quranThemeMode: QuranThemeMode.followApp,
      fardhPoint: 12,
      sunnahPoint: 6,
      duhaPoint: 7,
      adhkarPoint: 15,
      tasbihPoint: 20,
      worshipMultiplier: 1.5,
      excludedWorship: const ['quran', 'sadaqa'],
      customWorshipItems: const [
        {
          'id': 'custom_1',
          'label': 'قرائت ۱ جزء',
          'iconName': 'star',
          'points': 30
        },
      ],
      hiddenWorshipItems: const ['good_deeds'],
    );

    await repo.updateSettings(updated);

    // 2) Reload from a brand-new repository instance (simulates app restart).
    final freshRepo = SettingsRepositoryImpl(
      driftDataSource: SettingsDriftDataSource(SettingsDao(db)),
      localDataSource:
          SettingsLocalDataSource(await SharedPreferences.getInstance()),
    );
    final reloaded = await freshRepo.getSettings();

    expect(reloaded.globalPrayerOffset, 60);
    expect(reloaded.themeMode, ThemeModeOption.dark);
    expect(reloaded.quranThemeMode, QuranThemeMode.followApp);
    expect(reloaded.asrMethod, AsrMethod.hanafi);
    expect(reloaded.prayerNotifications, isFalse);
    expect(reloaded.morningAzkarNotification, isFalse);
    expect(reloaded.morningAzkarTime.hour, 7);
    expect(reloaded.morningAzkarTime.minute, 30);
    expect(reloaded.eveningAzkarTime.hour, 21);
    expect(reloaded.eveningAzkarTime.minute, 15);
    expect(reloaded.quranReminder, isTrue);
    expect(reloaded.quranReminderTime.hour, 9);
    expect(reloaded.quranReminderTime.minute, 45);
    expect(reloaded.azanSound, 'kamel');
    expect(reloaded.azanVolume, closeTo(0.6, 0.001));
    expect(reloaded.hijriOffset, -1);
    expect(reloaded.tafsirId, 191);
    expect(reloaded.use12Hour, isFalse);
    expect(reloaded.accentPreset, 'teal');
    expect(reloaded.dailyVerse, isFalse);
    expect(reloaded.dailyHadith, isFalse);
    expect(reloaded.widgetRefreshMinutes, 60);
    expect(reloaded.fardhPoint, 12);
    expect(reloaded.sunnahPoint, 6);
    expect(reloaded.duhaPoint, 7);
    expect(reloaded.adhkarPoint, 15);
    expect(reloaded.tasbihPoint, 20);
    expect(reloaded.worshipMultiplier, closeTo(1.5, 0.001));
    expect(reloaded.excludedWorship, ['quran', 'sadaqa']);
    expect(reloaded.customWorshipItems, hasLength(1));
    expect(reloaded.customWorshipItems.first['id'], 'custom_1');
    expect(reloaded.customWorshipItems.first['points'], 30);
    expect(reloaded.hiddenWorshipItems, ['good_deeds']);
  });

  test('custom adhan file path can be cleared', () async {
    final defaults = await repo.getSettings();
    await repo
        .updateSettings(defaults.copyWith(customAzanPath: '/tmp/azan.mp3'));
    await repo.updateSettings((await repo.getSettings()).copyWith(
      customAzanPath: null,
      azanSound: 'takbir',
    ));

    final reloaded = await repo.getSettings();
    expect(reloaded.customAzanPath, isNull);
    expect(reloaded.azanSound, 'takbir');
  });

  test('legacy eval_* prefs are imported into the settings row once', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('eval_adhkar_point', 18);
    await prefs.setInt('eval_tasbih_point', 9);
    await prefs.setString('eval_excluded_worship', '["fasting"]');
    await prefs.setString('eval_custom_worship_items',
        '[{"id":"c1","label":"قرائت","iconName":"star","points":25}]');
    await prefs.setString('eval_hidden_defaults', 'tahajjud,sadaqa');

    final imported = await repo.getSettings();

    expect(imported.adhkarPoint, 18);
    expect(imported.tasbihPoint, 9);
    expect(imported.excludedWorship, ['fasting']);
    expect(imported.customWorshipItems, hasLength(1));
    expect(imported.customWorshipItems.first['points'], 25);
    expect(imported.hiddenWorshipItems, ['tahajjud', 'sadaqa']);

    // The keys must be cleared so a second load does not re-import.
    expect(prefs.containsKey('eval_adhkar_point'), isFalse);
    expect(prefs.containsKey('eval_hidden_defaults'), isFalse);

    // A fresh repository must see the same values straight from the DB.
    final freshRepo = SettingsRepositoryImpl(
      driftDataSource: SettingsDriftDataSource(SettingsDao(db)),
      localDataSource:
          SettingsLocalDataSource(await SharedPreferences.getInstance()),
    );
    final reloaded = await freshRepo.getSettings();
    expect(reloaded.adhkarPoint, 18);
    expect(reloaded.hiddenWorshipItems, ['tahajjud', 'sadaqa']);
  });

  test('unrelated fields survive a partial update', () async {
    final defaults = await repo.getSettings();
    await repo.updateSettings(
        defaults.copyWith(hijriOffset: 3, timezone: 'Europe/Berlin'));

    final reloaded = await repo.getSettings();
    expect(reloaded.hijriOffset, 3);
    expect(reloaded.timezone, 'Europe/Berlin');
    // Everything else untouched.
    expect(reloaded.calculationMethod, CalculationMethodOption.auto);
    expect(reloaded.azanSound, 'takbir');
    expect(reloaded.themeMode, ThemeModeOption.light);
  });
}

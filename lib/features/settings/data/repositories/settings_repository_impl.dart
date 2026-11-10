import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/settings/data/datasources/settings_drift_datasource.dart';
import 'package:tawheeed/features/settings/data/datasources/settings_local_datasource.dart';
import 'package:tawheeed/features/settings/data/settings_migrations.dart';
import 'package:tawheeed/features/settings/data/models/app_settings_model.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/domain/repositories/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  /// The «جابجایی کلی» offset previously never survived a restart: the field
  /// has no column in the settings row (and the Drift schema is frozen under
  /// an in-flight WIP migration), so `_toRow`/`_fromRow` silently dropped it
  /// and every reload reset it to 0. Until the next schema bump adds a real
  /// column, it persists beside the app-level flags in SharedPreferences —
  /// the same house pattern as onboarding/isPremium.
  static const String globalOffsetKey = 'settings_global_prayer_offset';

  SharedPreferences? _prefsForOffsets;

  Future<SharedPreferences> _prefs() async =>
      _prefsForOffsets ??= await SharedPreferences.getInstance();
  final SettingsDriftDataSource driftDataSource;
  final SettingsLocalDataSource localDataSource;

  SettingsRepositoryImpl({
    required this.driftDataSource,
    required this.localDataSource,
  });

  @override
  Future<AppSettings> getSettings() async {
    var dto = await driftDataSource.load();
    dto = await _applyMigrations(dto);
    dto = await _applyStoredGlobalOffset(dto);
    final onboardingDone = await localDataSource.isOnboardingCompleted();
    final premium = await localDataSource.isPremium();
    return dto.toEntity().copyWith(
          onboardingCompleted: onboardingDone,
          isPremium: premium,
        );
  }

  /// Layers the globally stored «جابجایی کلی» value over the loaded DTO.
  /// Missing key → the DTO value stays (0 until the first change is saved).
  Future<AppSettingsDto> _applyStoredGlobalOffset(AppSettingsDto dto) async {
    try {
      final raw = (await _prefs()).getString(globalOffsetKey);
      if (raw == null) return dto;
      final v = int.tryParse(raw);
      if (v == null) return dto;
      return AppSettingsDto.fromJson(
          {...dto.toJson(), 'globalPrayerOffset': v});
    } catch (e) {
      // Never let a broken prefs value kill the whole settings load.
      return dto;
    }
  }

  /// Runs the settings row's content migrations exactly once and stamps the
  /// version that was reached.
  ///
  /// The import of the pre-schema-23 `eval_*` keys used to run on every load
  /// whose clearing attempt had failed, so a point value the reader had
  /// changed since could be written back from a stale preference. The stamp
  /// (`SettingsMigrations.versionKey`) is what closes that door; a failed
  /// migration leaves it unwritten so the next launch retries rather than
  /// skipping the step for good.
  Future<AppSettingsDto> _applyMigrations(AppSettingsDto dto) async {
    try {
      final prefs = await _prefs();
      final stored = prefs.getInt(SettingsMigrations.versionKey) ?? 0;
      if (!SettingsMigrations.needsUpgrade(stored)) return dto;
      // The legacy reader is only consulted by the step that consumes it.
      final legacy = stored < 1 ? localDataSource.readLegacyEvalPrefs() : null;
      final result = SettingsMigrations.upgrade(
        dto.toJson(),
        fromVersion: stored,
        legacyEvalPrefs: legacy,
      );
      final migrated = AppSettingsDto.fromJson(result.json);
      await driftDataSource.save(migrated);
      if (legacy != null) await localDataSource.clearLegacyEvalPrefs();
      await prefs.setInt(SettingsMigrations.versionKey, result.version);
      return migrated;
    } catch (e) {
      // A failed migration must never cost the reader their settings: the row
      // loads as it is and the stamp stays unwritten, so the next launch
      // retries instead of skipping the step forever.
      return dto;
    }
  }

  @override
  Future<void> updateSettings(AppSettings settings) async {
    final dto = AppSettingsDto.fromEntity(settings);
    await driftDataSource.save(dto);
    // Drift has no column for this field yet (see [globalOffsetKey]).
    await (await _prefs())
        .setString(globalOffsetKey, '${settings.globalPrayerOffset}');
    await localDataSource.setOnboardingCompleted(settings.onboardingCompleted);
  }

  @override
  Future<void> resetSettings() async {
    final prefs = await _prefs();
    await prefs.remove(globalOffsetKey);
    // A reset row is at the current format: leaving the stamp behind would let
    // a stale legacy `eval_*` map be imported into the freshly reset values.
    await prefs.setInt(
        SettingsMigrations.versionKey, SettingsMigrations.currentVersion);
    await driftDataSource.save(const AppSettingsDto());
    await localDataSource.setOnboardingCompleted(false);
    await localDataSource.setPremiumStatus(false);
  }

  @override
  Future<void> setOnboardingCompleted(bool completed) async {
    await localDataSource.setOnboardingCompleted(completed);
  }

  @override
  Future<bool> isOnboardingCompleted() async {
    return await localDataSource.isOnboardingCompleted();
  }

  @override
  Future<void> setPremiumStatus(bool isPremium) async {
    await localDataSource.setPremiumStatus(isPremium);
  }

  @override
  Future<bool> isPremium() async {
    return await localDataSource.isPremium();
  }

  @override
  Stream<AppSettings> watchSettings() async* {
    yield await getSettings();
  }
}

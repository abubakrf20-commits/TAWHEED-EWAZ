import 'package:tawheeed/shared/utils/app_logger.dart';

/// Upgrades of the settings ROW's own content, kept apart from the Drift schema
/// (which versions the table) and from the app-level flags.
///
/// Version 1 records the one-time import of the pre-schema-23 `eval_*` scoring
/// keys from SharedPreferences. Before this stamp existed the repository re-ran
/// that import on EVERY load whose attempt at clearing the legacy keys had
/// failed — so a point value the reader had changed since would be written back
/// from a stale preference without a word. The stamp is what makes «exactly
/// once» a fact instead of a hope.
abstract final class SettingsMigrations {
  const SettingsMigrations._();

  /// Bump when a step is added to [upgrade].
  static const int currentVersion = 1;

  /// Where the version lives. Beside `settings_global_prayer_offset` in the
  /// same prefs store: this number describes the row's CONTENT, and the Drift
  /// schema is frozen under an in-flight WIP migration.
  static const String versionKey = 'settings_schema_version';

  /// True when a row stamped [storedVersion] still needs at least one step.
  ///
  /// A row with no stamp at all reports 0 and is therefore upgraded once, which
  /// is the safe direction: the only step reachable from 0 is idempotent.
  static bool needsUpgrade(int storedVersion) => storedVersion < currentVersion;

  /// Applies every step above [fromVersion] to [json] and reports the version
  /// reached.
  ///
  /// Pure on purpose: the caller decides whether to persist, so a failed save
  /// leaves the stamp unwritten and the next launch retries instead of
  /// skipping the step forever.
  static ({Map<String, dynamic> json, int version}) upgrade(
    Map<String, dynamic> json, {
    required int fromVersion,
    Map<String, dynamic>? legacyEvalPrefs,
  }) {
    if (fromVersion >= currentVersion) {
      return (json: json, version: fromVersion);
    }
    var next = Map<String, dynamic>.of(json);
    var version = fromVersion;
    if (version < 1) {
      next = _importLegacyScoring(next, legacyEvalPrefs);
      version = 1;
    }
    return (json: next, version: version);
  }

  /// Step 1 — move the pre-schema-23 `eval_*` values into the row.
  ///
  /// Only the keys the legacy reader actually found are written, so a partial
  /// legacy set never blanks a value the row already carries.
  static Map<String, dynamic> _importLegacyScoring(
    Map<String, dynamic> json,
    Map<String, dynamic>? legacy,
  ) {
    if (legacy == null || legacy.isEmpty) return json;
    for (final entry in legacy.entries) {
      final value = entry.value;
      if (value == null) continue;
      json[entry.key] = value;
    }
    AppLogger.info('settings_migrations',
        'step 1: imported ${legacy.length} legacy scoring value(s)');
    return json;
  }
}

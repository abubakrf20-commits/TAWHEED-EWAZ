/// Preferences for the stage-3 tools that are settings rather than data.
///
/// Same reasoning as `CareSettingsStore` / `FinanceSettingsStore`: these are
/// read by one feature only, so they do not earn columns in
/// `app_settings_table`. Anything the user would be upset to lose in a backup
/// (relatives, goals, deposits, counters, logs) lives in the database instead.
library;

import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/features/personal/family_faith/relatives/relative_reminder_planner.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

class FamilySettingsStore {
  FamilySettingsStore._();

  static const _enabledKey = 'personal.family.reminders_enabled';
  static const _hourKey = 'personal.family.reminder_hour';
  static const _quietStartKey = 'personal.family.quiet_start';
  static const _quietEndKey = 'personal.family.quiet_end';
  static const _weeklyKey = 'personal.family.weekly_nudge';
  static const _maxNudgesKey = 'personal.family.max_nudges';

  static Future<FamilyReminderSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return FamilyReminderSettings(
        enabled: prefs.getBool(_enabledKey) ?? true,
        hour: (prefs.getInt(_hourKey) ?? 9).clamp(0, 23),
        quietStart: (prefs.getInt(_quietStartKey) ?? 22).clamp(0, 23),
        quietEnd: (prefs.getInt(_quietEndKey) ?? 7).clamp(0, 23),
        weeklyNudge: prefs.getBool(_weeklyKey) ?? true,
        maxNudges: (prefs.getInt(_maxNudgesKey) ?? 3).clamp(1, 8),
      );
    } catch (e) {
      AppLogger.warning('FamilySettings', 'load failed, using defaults: $e');
      return const FamilyReminderSettings();
    }
  }

  static Future<void> save(FamilyReminderSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, settings.enabled);
      await prefs.setInt(_hourKey, settings.hour);
      await prefs.setInt(_quietStartKey, settings.quietStart);
      await prefs.setInt(_quietEndKey, settings.quietEnd);
      await prefs.setBool(_weeklyKey, settings.weeklyNudge);
      await prefs.setInt(_maxNudgesKey, settings.maxNudges);
    } catch (e) {
      AppLogger.warning('FamilySettings', 'save failed: $e');
    }
  }
}

/// The debug-only switch that reveals draft (unreviewed) kaffara rules.
///
/// Deliberately stored in preferences but **only honoured in a debug build**:
/// a release APK must never show an unreviewed ruling because a flag was left
/// on.
class KaffaraDebugStore {
  KaffaraDebugStore._();

  static const _key = 'personal.kaffara.show_drafts';

  static Future<bool> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key) ?? false;
    } catch (e) {
      AppLogger.warning('KaffaraDebug', 'load failed: $e');
      return false;
    }
  }

  static Future<void> save(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, value);
    } catch (e) {
      AppLogger.warning('KaffaraDebug', 'save failed: $e');
    }
  }
}

/// Quick-deposit amounts for «قلک». Three numbers the user edits; they are a
/// convenience, not data, so a lost preset is harmless.
class SavingsPresetStore {
  SavingsPresetStore._();

  static const _key = 'personal.savings.presets';
  static const List<double> defaults = [100000, 500000, 1000000];

  static Future<List<double>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key);
      if (raw == null || raw.isEmpty) return defaults;
      final values = [
        for (final item in raw)
          if (double.tryParse(item) != null && double.parse(item) > 0)
            double.parse(item),
      ];
      return values.isEmpty ? defaults : values;
    } catch (e) {
      AppLogger.warning('SavingsPresets', 'load failed: $e');
      return defaults;
    }
  }

  static Future<void> save(List<double> values) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          _key, [for (final value in values) value.toStringAsFixed(0)]);
    } catch (e) {
      AppLogger.warning('SavingsPresets', 'save failed: $e');
    }
  }
}

/// Reminder settings for «قلک» (savings goals).
class SavingsReminderSettings {
  const SavingsReminderSettings({
    this.enabled = true,
    this.hour = 10,
    this.remindMonthly = true,
  });

  final bool enabled;
  final int hour; // 0–23
  final bool remindMonthly; // once-per-month deposit nudge

  SavingsReminderSettings copyWith({
    bool? enabled,
    int? hour,
    bool? remindMonthly,
  }) =>
      SavingsReminderSettings(
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        remindMonthly: remindMonthly ?? this.remindMonthly,
      );
}

/// Persists [SavingsReminderSettings] beside the stage-1 care preferences.
class SavingsReminderStore {
  SavingsReminderStore._();

  static const _enabledKey = 'personal.savings.reminders_enabled';
  static const _hourKey = 'personal.savings.reminder_hour';
  static const _monthlyKey = 'personal.savings.remind_monthly';

  static Future<SavingsReminderSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return SavingsReminderSettings(
        enabled: prefs.getBool(_enabledKey) ?? true,
        hour: (prefs.getInt(_hourKey) ?? 10).clamp(0, 23),
        remindMonthly: prefs.getBool(_monthlyKey) ?? true,
      );
    } catch (e) {
      AppLogger.warning('SavingsReminder', 'load failed, using defaults: $e');
      return const SavingsReminderSettings();
    }
  }

  static Future<void> save(SavingsReminderSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, settings.enabled);
      await prefs.setInt(_hourKey, settings.hour);
      await prefs.setBool(_monthlyKey, settings.remindMonthly);
    } catch (e) {
      AppLogger.warning('SavingsReminder', 'save failed: $e');
    }
  }
}

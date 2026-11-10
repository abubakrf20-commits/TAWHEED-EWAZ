import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/features/personal/finance/finance_reminder_planner.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Persists [FinanceReminderSettings] beside the stage-1 care preferences.
///
/// Same reasoning as `CareSettingsStore`: these are read by one feature only,
/// so they do not earn columns in `app_settings_table`. A load failure falls
/// back to the defaults — preferences are a convenience, not user data.
class FinanceSettingsStore {
  FinanceSettingsStore._();

  static const _enabledKey = 'personal.finance.reminders_enabled';
  static const _hourKey = 'personal.finance.reminder_hour';
  static const _quietStartKey = 'personal.finance.quiet_start';
  static const _quietEndKey = 'personal.finance.quiet_end';
  static const _overdueKey = 'personal.finance.overdue_reminder_enabled';

  static Future<FinanceReminderSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return FinanceReminderSettings(
        enabled: prefs.getBool(_enabledKey) ?? true,
        hour: (prefs.getInt(_hourKey) ?? 9).clamp(0, 23),
        quietStart: (prefs.getInt(_quietStartKey) ?? 22).clamp(0, 23),
        quietEnd: (prefs.getInt(_quietEndKey) ?? 7).clamp(0, 23),
        overdueReminderEnabled: prefs.getBool(_overdueKey) ?? true,
      );
    } catch (e) {
      AppLogger.warning('FinanceSettings', 'load failed, using defaults: $e');
      return const FinanceReminderSettings();
    }
  }

  static Future<void> save(FinanceReminderSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, settings.enabled);
      await prefs.setInt(_hourKey, settings.hour);
      await prefs.setInt(_quietStartKey, settings.quietStart);
      await prefs.setInt(_quietEndKey, settings.quietEnd);
      await prefs.setBool(_overdueKey, settings.overdueReminderEnabled);
    } catch (e) {
      AppLogger.warning('FinanceSettings', 'save failed: $e');
    }
  }
}

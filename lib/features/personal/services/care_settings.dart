import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/shared/utils/app_logger.dart';

/// User-tunable reminder behaviour for the personal tools.
///
/// Lives in SharedPreferences (not `AppSettings`) on purpose: adding columns to
/// the settings table is a schema change for values that only these two tools
/// read, and the project already keeps per-feature preferences this way.
class CareReminderSettings {
  const CareReminderSettings({
    this.enabled = true,
    this.hour = 9,
    this.quietStart = 22,
    this.quietEnd = 7,
    this.dailyCap = 3,
    this.horizonDays = 30,
    this.disabledCategories = const {},
    this.categoryHours = const {},
  });

  final bool enabled;

  /// Preferred hour of day (0–23) for every care reminder, used as the
  /// fallback when a category has no entry in [categoryHours].
  final int hour;

  /// Quiet hours (inclusive start, exclusive end, may wrap midnight).
  final int quietStart;
  final int quietEnd;

  /// Maximum number of care notifications per day.
  final int dailyCap;

  /// Only this many days ahead are scheduled.
  final int horizonDays;

  /// Category keys switched off by the user (`service`, `bills`,
  /// `warranty`, `subscriptions`).
  final Set<String> disabledCategories;

  /// Per-category preferred hour (categoryKey -> hour 0–23). Falls back to
  /// [hour] when a category has no entry.
  final Map<String, int> categoryHours;

  bool isQuietAt(int hourOfDay) {
    if (quietStart == quietEnd) return false;
    if (quietStart < quietEnd) {
      return hourOfDay >= quietStart && hourOfDay < quietEnd;
    }
    return hourOfDay >= quietStart || hourOfDay < quietEnd;
  }

  bool allowsCategory(String category) =>
      !disabledCategories.contains(category);

  CareReminderSettings copyWith({
    bool? enabled,
    int? hour,
    int? quietStart,
    int? quietEnd,
    int? dailyCap,
    int? horizonDays,
    Set<String>? disabledCategories,
    Map<String, int>? categoryHours,
  }) =>
      CareReminderSettings(
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        quietStart: quietStart ?? this.quietStart,
        quietEnd: quietEnd ?? this.quietEnd,
        dailyCap: dailyCap ?? this.dailyCap,
        horizonDays: horizonDays ?? this.horizonDays,
        disabledCategories: disabledCategories ?? this.disabledCategories,
        categoryHours: categoryHours ?? this.categoryHours,
      );
}

/// Persists [CareReminderSettings]. Every failure falls back to the default
/// rather than throwing: preferences are a convenience, not data.
class CareSettingsStore {
  CareSettingsStore._();

  static const _enabledKey = 'personal.care.reminders_enabled';
  static const _hourKey = 'personal.care.reminder_hour';
  static const _quietStartKey = 'personal.care.quiet_start';
  static const _quietEndKey = 'personal.care.quiet_end';
  static const _capKey = 'personal.care.daily_cap';
  static const _disabledKey = 'personal.care.disabled_categories';
  static const _categoryHourKey = 'personal.care.category_hours';

  static Future<CareReminderSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final categoryHours = <String, int>{};
      final raw = prefs.getString(_categoryHourKey);
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          decoded.forEach((key, value) {
            if (value is num) categoryHours[key] = value.toInt();
          });
        } catch (_) {
          AppLogger.warning(
              'CareSettings', 'category hours parse failed, ignoring');
        }
      }
      return CareReminderSettings(
        enabled: prefs.getBool(_enabledKey) ?? true,
        hour: (prefs.getInt(_hourKey) ?? 9).clamp(0, 23),
        quietStart: (prefs.getInt(_quietStartKey) ?? 22).clamp(0, 23),
        quietEnd: (prefs.getInt(_quietEndKey) ?? 7).clamp(0, 23),
        dailyCap: (prefs.getInt(_capKey) ?? 3).clamp(1, 10),
        disabledCategories:
            (prefs.getStringList(_disabledKey) ?? const []).toSet(),
        categoryHours: categoryHours,
      );
    } catch (e) {
      AppLogger.warning('CareSettings', 'load failed, using defaults: $e');
      return const CareReminderSettings();
    }
  }

  static Future<void> save(CareReminderSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, settings.enabled);
      await prefs.setInt(_hourKey, settings.hour);
      await prefs.setInt(_quietStartKey, settings.quietStart);
      await prefs.setInt(_quietEndKey, settings.quietEnd);
      await prefs.setInt(_capKey, settings.dailyCap);
      await prefs.setStringList(
          _disabledKey, settings.disabledCategories.toList());
      await prefs.setString(
          _categoryHourKey, jsonEncode(settings.categoryHours));
    } catch (e) {
      AppLogger.warning('CareSettings', 'save failed: $e');
    }
  }
}

import 'dart:convert';

import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/features/settings/data/models/app_settings_model.dart';
import 'package:tawheeed/shared/models/day_time.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/data/daos/settings_dao.dart';

class SettingsDriftDataSource {
  final SettingsDao _dao;

  SettingsDriftDataSource(this._dao);

  Future<AppSettingsDto> load() async {
    final row = await _dao.getSettings('default');
    if (row == null) return const AppSettingsDto();
    return _fromRow(row);
  }

  Future<void> save(AppSettingsDto settings) async {
    await _dao.upsertSettings(_toRow(settings));
  }

  AppSettingsDto _fromRow(AppSettingsTableData row) {
    return AppSettingsDto(
      id: row.id,
      calculationMethod: _safeEnum(
        CalculationMethodOption.values,
        row.calculationMethod,
        CalculationMethodOption.muslimWorldLeague,
      ),
      asrMethod: _safeEnum(
        AsrMethod.values,
        row.asrMethod,
        AsrMethod.shafi,
      ),
      highLatitudeRule: _safeEnum(
        HighLatitudeRuleOption.values,
        row.highLatitudeRule,
        HighLatitudeRuleOption.middleOfTheNight,
      ),
      useLocation: row.useLocation,
      city: row.city,
      manualLat: row.manualLat,
      manualLng: row.manualLng,
      hasLocation: row.hasLocation,
      customFajrAngle: row.customFajrAngle,
      customIshaAngle: row.customIshaAngle,
      fajrOffset: row.fajrOffset,
      sunriseOffset: row.sunriseOffset,
      dhuhrOffset: row.dhuhrOffset,
      asrOffset: row.asrOffset,
      maghribOffset: row.maghribOffset,
      ishaOffset: row.ishaOffset,
      iqamahOffsetFajr: row.iqamahOffsetFajr,
      iqamahOffsetDhuhr: row.iqamahOffsetDhuhr,
      iqamahOffsetAsr: row.iqamahOffsetAsr,
      iqamahOffsetMaghrib: row.iqamahOffsetMaghrib,
      iqamahOffsetIsha: row.iqamahOffsetIsha,
      fridayPrayerTime: row.fridayPrayerTime == null
          ? null
          : _parseDayTime(row.fridayPrayerTime!),
      prayerNotifications: row.prayerNotifications,
      prayerNotifMinutes: row.prayerNotifMinutes,
      morningAzkarNotification: row.morningAzkarNotification,
      morningAzkarTime: DayTime(
          hour: row.morningAzkarTimeHour, minute: row.morningAzkarTimeMinute),
      eveningAzkarNotification: row.eveningAzkarNotification,
      eveningAzkarTime: DayTime(
          hour: row.eveningAzkarTimeHour, minute: row.eveningAzkarTimeMinute),
      quranReminder: row.quranReminder,
      quranReminderTime: DayTime(
          hour: row.quranReminderTimeHour, minute: row.quranReminderTimeMinute),
      silentDuringPrayer: row.silentDuringPrayer,
      silentDuration: row.silentDuration,
      silentBeforeIqamah: row.silentBeforeIqamah,
      silentBeforeIqamahMinutes: row.silentBeforeIqamahMinutes,
      dailyVerse: row.dailyVerse,
      dailyVerseTime: DayTime(
          hour: row.dailyVerseTimeHour, minute: row.dailyVerseTimeMinute),
      dailyHadith: row.dailyHadith,
      dailyHadithTime: DayTime(
          hour: row.dailyHadithTimeHour, minute: row.dailyHadithTimeMinute),
      dailyDua: row.dailyDua,
      dailyDuaTime:
          DayTime(hour: row.dailyDuaTimeHour, minute: row.dailyDuaTimeMinute),
      dailyWordEnabled: row.dailyWordEnabled,
      dailyWordHour: row.dailyWordHour,
      dailyWordMinute: row.dailyWordMinute,
      themeMode: _themeModeFromString(row.themeMode),
      quranThemeMode: _quranThemeModeFromString(row.quranThemeMode),
      fontFamily: FontFamilyOption.values.firstWhere(
        (e) => e.name == row.fontFamily,
        orElse: () => FontFamilyOption.calibri,
      ),
      fontScale: row.fontScale,
      showArabicText: row.showArabicText,
      showDaleel: row.showDaleel,
      largeArabicFont: row.largeArabicFont,
      showEnglishTranslation: row.showEnglishTranslation,
      quranFontSize: row.quranFontSize,
      appFontSize: row.appFontSize,
      accentPreset: row.accentPreset,
      isPremium: row.isPremium,
      use12Hour: row.use12Hour,
      azanSound: row.azanSound,
      customAzanPath: row.customAzanPath,
      azanVolume: row.azanVolume,
      azanEnabledForFajr: row.azanEnabledForFajr,
      azanEnabledForDhuhr: row.azanEnabledForDhuhr,
      azanEnabledForAsr: row.azanEnabledForAsr,
      azanEnabledForMaghrib: row.azanEnabledForMaghrib,
      azanEnabledForIsha: row.azanEnabledForIsha,
      widgetRefreshMinutes: row.widgetRefreshMinutes,
      tafsirId: row.tafsirId,
      elevationCorrection: row.elevationCorrection,
      fardhPoint: row.fardhPoint,
      sunnahPoint: row.sunnahPoint,
      duhaPoint: row.duhaPoint,
      adhkarPoint: row.adhkarPoint,
      tasbihPoint: row.tasbihPoint,
      worshipMultiplier: row.worshipMultiplier,
      excludedWorship: _decodeStringList(row.excludedWorship),
      customWorshipItems: _decodeCustomItems(row.customWorshipItems),
      hiddenWorshipItems: _decodeStringList(row.hiddenWorshipItems),
      firstLaunch: row.firstLaunch,
      onboardingCompleted: row.onboardingCompleted,
      hijriOffset: row.hijriOffset,
      quickActions:
          row.quickActions.split(',').where((s) => s.isNotEmpty).toList(),
      tasbihDhikrSource: row.tasbihDhikrSource,
      timezone: row.timezone,
    );
  }

  AppSettingsTableData _toRow(AppSettingsDto s) {
    return AppSettingsTableData(
      id: s.id,
      calculationMethod: s.calculationMethod.index,
      asrMethod: s.asrMethod.index,
      highLatitudeRule: s.highLatitudeRule.index,
      useLocation: s.useLocation,
      city: s.city,
      manualLat: s.manualLat,
      manualLng: s.manualLng,
      hasLocation: s.hasLocation,
      customFajrAngle: s.customFajrAngle,
      customIshaAngle: s.customIshaAngle,
      fajrOffset: s.fajrOffset,
      sunriseOffset: s.sunriseOffset,
      dhuhrOffset: s.dhuhrOffset,
      asrOffset: s.asrOffset,
      maghribOffset: s.maghribOffset,
      ishaOffset: s.ishaOffset,
      iqamahOffsetFajr: s.iqamahOffsetFajr,
      iqamahOffsetDhuhr: s.iqamahOffsetDhuhr,
      iqamahOffsetAsr: s.iqamahOffsetAsr,
      iqamahOffsetMaghrib: s.iqamahOffsetMaghrib,
      iqamahOffsetIsha: s.iqamahOffsetIsha,
      fridayPrayerTime: s.fridayPrayerTime == null
          ? null
          : '${s.fridayPrayerTime!.hour}:${s.fridayPrayerTime!.minute}',
      prayerNotifications: s.prayerNotifications,
      prayerNotifMinutes: s.prayerNotifMinutes,
      morningAzkarNotification: s.morningAzkarNotification,
      morningAzkarTimeHour: s.morningAzkarTime.hour,
      morningAzkarTimeMinute: s.morningAzkarTime.minute,
      eveningAzkarNotification: s.eveningAzkarNotification,
      eveningAzkarTimeHour: s.eveningAzkarTime.hour,
      eveningAzkarTimeMinute: s.eveningAzkarTime.minute,
      quranReminder: s.quranReminder,
      quranReminderTimeHour: s.quranReminderTime.hour,
      quranReminderTimeMinute: s.quranReminderTime.minute,
      silentDuringPrayer: s.silentDuringPrayer,
      silentDuration: s.silentDuration,
      silentBeforeIqamah: s.silentBeforeIqamah,
      silentBeforeIqamahMinutes: s.silentBeforeIqamahMinutes,
      dailyVerse: s.dailyVerse,
      dailyVerseTimeHour: s.dailyVerseTime.hour,
      dailyVerseTimeMinute: s.dailyVerseTime.minute,
      dailyHadith: s.dailyHadith,
      dailyHadithTimeHour: s.dailyHadithTime.hour,
      dailyHadithTimeMinute: s.dailyHadithTime.minute,
      dailyDua: s.dailyDua,
      dailyDuaTimeHour: s.dailyDuaTime.hour,
      dailyDuaTimeMinute: s.dailyDuaTime.minute,
      dailyWordEnabled: s.dailyWordEnabled,
      dailyWordHour: s.dailyWordHour,
      dailyWordMinute: s.dailyWordMinute,
      themeMode: _themeModeToString(s.themeMode),
      quranThemeMode: _quranThemeModeToString(s.quranThemeMode),
      fontFamily: s.fontFamily.name,
      fontScale: s.fontScale,
      showArabicText: s.showArabicText,
      showDaleel: s.showDaleel,
      largeArabicFont: s.largeArabicFont,
      showEnglishTranslation: s.showEnglishTranslation,
      quranFontSize: s.quranFontSize,
      appFontSize: s.appFontSize,
      accentPreset: s.accentPreset,
      isPremium: s.isPremium,
      use12Hour: s.use12Hour,
      azanSound: s.azanSound,
      customAzanPath: s.customAzanPath,
      azanVolume: s.azanVolume,
      azanEnabledForFajr: s.azanEnabledForFajr,
      azanEnabledForDhuhr: s.azanEnabledForDhuhr,
      azanEnabledForAsr: s.azanEnabledForAsr,
      azanEnabledForMaghrib: s.azanEnabledForMaghrib,
      azanEnabledForIsha: s.azanEnabledForIsha,
      widgetRefreshMinutes: s.widgetRefreshMinutes,
      tafsirId: s.tafsirId,
      elevationCorrection: s.elevationCorrection,
      fardhPoint: s.fardhPoint,
      sunnahPoint: s.sunnahPoint,
      duhaPoint: s.duhaPoint,
      adhkarPoint: s.adhkarPoint,
      tasbihPoint: s.tasbihPoint,
      worshipMultiplier: s.worshipMultiplier,
      excludedWorship: jsonEncode(s.excludedWorship),
      customWorshipItems: jsonEncode(s.customWorshipItems),
      hiddenWorshipItems: jsonEncode(s.hiddenWorshipItems),
      firstLaunch: s.firstLaunch,
      onboardingCompleted: s.onboardingCompleted,
      hijriOffset: s.hijriOffset,
      quickActions: s.quickActions.join(','),
      tasbihDhikrSource: s.tasbihDhikrSource,
      timezone: s.timezone,
    );
  }

  static T _safeEnum<T>(List<T> values, int index, T fallback) {
    if (index < 0 || index >= values.length) return fallback;
    return values[index];
  }

  /// Parses a wall-clock "H:m" string. Returns null for absent/blank so the
  /// Friday/Jumu'ah time can follow the calculated Dhuhr by default.
  static DayTime? _parseDayTime(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return null;
    final parts = timeStr.split(':');
    final hour = int.tryParse(parts.isNotEmpty ? parts[0].trim() : '') ?? 0;
    final minute = int.tryParse(parts.length > 1 ? parts[1].trim() : '') ?? 0;
    return DayTime(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
  }

  /// Decodes a JSON-array string into a string list (empty when absent).
  static List<String> _decodeStringList(String raw) {
    if (raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().toList();
      }
    } catch (e) {
      AppLogger.warning('SettingsDrift', 'read failed: $e');
    }
    return const [];
  }

  /// Decodes a JSON-array string into custom worship item maps.
  static List<Map<String, dynamic>> _decodeCustomItems(String raw) {
    if (raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<Map>().map(Map<String, dynamic>.from).toList();
      }
    } catch (e) {
      AppLogger.warning('SettingsDrift', 'read failed: $e');
    }
    return const [];
  }

  static ThemeModeOption _themeModeFromString(String s) {
    switch (s) {
      case 'light':
        return ThemeModeOption.light;
      case 'dark':
        return ThemeModeOption.dark;
      default:
        return ThemeModeOption.system;
    }
  }

  static String _themeModeToString(ThemeModeOption m) {
    switch (m) {
      case ThemeModeOption.light:
        return 'light';
      case ThemeModeOption.dark:
        return 'dark';
      default:
        return 'system';
    }
  }

  static QuranThemeMode _quranThemeModeFromString(String s) {
    switch (s) {
      case 'light':
        return QuranThemeMode.light;
      case 'dark':
        return QuranThemeMode.dark;
      case 'followApp':
        return QuranThemeMode.followApp;
      default:
        return QuranThemeMode.light;
    }
  }

  static String _quranThemeModeToString(QuranThemeMode m) {
    switch (m) {
      case QuranThemeMode.light:
        return 'light';
      case QuranThemeMode.dark:
        return 'dark';
      default:
        return 'followApp';
    }
  }
}

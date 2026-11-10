import 'dart:convert';

import 'package:tawheeed/shared/models/day_time.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';

class AppSettingsDto {
  final String id;

  final CalculationMethodOption calculationMethod;
  final AsrMethod asrMethod;
  final HighLatitudeRuleOption highLatitudeRule;
  final bool useLocation;
  final String? city;
  final double? manualLat;
  final double? manualLng;
  final bool hasLocation;
  final double customFajrAngle;
  final double customIshaAngle;
  final int fajrOffset;
  final int sunriseOffset;
  final int dhuhrOffset;
  final int asrOffset;
  final int maghribOffset;
  final int ishaOffset;
  final int globalPrayerOffset;
  final int iqamahOffsetFajr;
  final int iqamahOffsetDhuhr;
  final int iqamahOffsetAsr;
  final int iqamahOffsetMaghrib;
  final int iqamahOffsetIsha;

  /// Optional custom Friday (Jumu'ah) prayer time; null = follow Dhuhr.
  final DayTime? fridayPrayerTime;

  final bool prayerNotifications;
  final int prayerNotifMinutes;
  final bool morningAzkarNotification;
  final DayTime morningAzkarTime;
  final bool eveningAzkarNotification;
  final DayTime eveningAzkarTime;
  final bool quranReminder;
  final DayTime quranReminderTime;

  final bool silentDuringPrayer;
  final int silentDuration;
  final bool silentBeforeIqamah;
  final int silentBeforeIqamahMinutes;

  final bool dailyVerse;
  final DayTime dailyVerseTime;
  final bool dailyHadith;
  final DayTime dailyHadithTime;
  final bool dailyDua;
  final DayTime dailyDuaTime;
  final bool dailyWordEnabled;
  final int dailyWordHour;
  final int dailyWordMinute;

  final ThemeModeOption themeMode;
  final QuranThemeMode quranThemeMode;
  final FontFamilyOption fontFamily;
  final double fontScale;
  final bool showArabicText;
  final bool showDaleel;
  final bool largeArabicFont;
  final bool showEnglishTranslation;
  final double quranFontSize;
  final double appFontSize;
  final String accentPreset;
  final bool isPremium;

  final bool use12Hour;
  final String azanSound;
  final String? customAzanPath;
  final double azanVolume;
  final bool azanEnabledForFajr;
  final bool azanEnabledForDhuhr;
  final bool azanEnabledForAsr;
  final bool azanEnabledForMaghrib;
  final bool azanEnabledForIsha;

  final int widgetRefreshMinutes;
  final int tafsirId;
  final bool elevationCorrection;
  final int fardhPoint;
  final int sunnahPoint;
  final int duhaPoint;
  final int adhkarPoint;
  final int tasbihPoint;
  final double worshipMultiplier;
  final List<String> excludedWorship;
  final List<Map<String, dynamic>> customWorshipItems;
  final List<String> hiddenWorshipItems;
  final bool firstLaunch;
  final bool onboardingCompleted;
  final int hijriOffset;
  final List<String> quickActions;
  final String tasbihDhikrSource;
  final String timezone;

  const AppSettingsDto({
    this.id = 'default',
    this.calculationMethod = CalculationMethodOption.auto,
    this.asrMethod = AsrMethod.shafi,
    this.highLatitudeRule = HighLatitudeRuleOption.middleOfTheNight,
    this.useLocation = true,
    this.city,
    this.manualLat,
    this.manualLng,
    this.hasLocation = false,
    this.customFajrAngle = 18.0,
    this.customIshaAngle = 17.0,
    this.fajrOffset = 0,
    this.sunriseOffset = 0,
    this.dhuhrOffset = 0,
    this.asrOffset = 0,
    this.maghribOffset = 0,
    this.ishaOffset = 0,
    this.globalPrayerOffset = 0,
    this.iqamahOffsetFajr = 30,
    this.iqamahOffsetDhuhr = 25,
    this.iqamahOffsetAsr = 25,
    this.iqamahOffsetMaghrib = 10,
    this.iqamahOffsetIsha = 25,
    this.fridayPrayerTime,
    this.prayerNotifications = true,
    this.prayerNotifMinutes = 5,
    this.morningAzkarNotification = true,
    this.morningAzkarTime = const DayTime(hour: 6, minute: 0),
    this.eveningAzkarNotification = true,
    this.eveningAzkarTime = const DayTime(hour: 20, minute: 0),
    this.quranReminder = false,
    this.quranReminderTime = const DayTime(hour: 8, minute: 0),
    this.silentDuringPrayer = false,
    this.silentDuration = 10,
    this.silentBeforeIqamah = false,
    this.silentBeforeIqamahMinutes = 15,
    this.dailyVerse = true,
    this.dailyVerseTime = const DayTime(hour: 7, minute: 0),
    this.dailyHadith = true,
    this.dailyHadithTime = const DayTime(hour: 18, minute: 0),
    this.dailyDua = false,
    this.dailyDuaTime = const DayTime(hour: 12, minute: 0),
    this.dailyWordEnabled = false,
    this.dailyWordHour = 8,
    this.dailyWordMinute = 0,
    this.themeMode = ThemeModeOption.light,
    this.quranThemeMode = QuranThemeMode.light,
    this.fontFamily = FontFamilyOption.calibri,
    this.fontScale = 1.0,
    this.showArabicText = true,
    this.showDaleel = true,
    this.largeArabicFont = false,
    this.showEnglishTranslation = false,
    this.quranFontSize = 22.0,
    this.appFontSize = 15.0,
    this.accentPreset = 'night',
    this.isPremium = false,
    this.use12Hour = true,
    this.azanSound = 'takbir',
    this.customAzanPath,
    this.azanVolume = 1.0,
    this.azanEnabledForFajr = false,
    this.azanEnabledForDhuhr = false,
    this.azanEnabledForAsr = false,
    this.azanEnabledForMaghrib = false,
    this.azanEnabledForIsha = false,
    this.widgetRefreshMinutes = 30,
    this.tafsirId = 169,
    this.elevationCorrection = false,
    this.fardhPoint = 10,
    this.sunnahPoint = 5,
    this.duhaPoint = 5,
    this.adhkarPoint = 10,
    this.tasbihPoint = 10,
    this.worshipMultiplier = 1.0,
    this.excludedWorship = const [],
    this.customWorshipItems = const [],
    this.hiddenWorshipItems = const [],
    this.firstLaunch = true,
    this.onboardingCompleted = false,
    this.hijriOffset = 2,
    this.quickActions = const ['qibla', 'khatm'],
    this.tasbihDhikrSource = 'own',
    this.timezone = 'Asia/Tehran',
  });

  factory AppSettingsDto.fromJson(Map<String, dynamic> json) {
    return AppSettingsDto(
      id: json['id'] as String? ?? 'default',
      calculationMethod: CalculationMethodOption.values.firstWhere(
        (e) => e.name == json['calculationMethod'],
        orElse: () => CalculationMethodOption.muslimWorldLeague,
      ),
      asrMethod: AsrMethod.values.firstWhere(
        (e) => e.name == json['asrMethod'],
        orElse: () => AsrMethod.shafi,
      ),
      highLatitudeRule: HighLatitudeRuleOption.values.firstWhere(
        (e) => e.name == json['highLatitudeRule'],
        orElse: () => HighLatitudeRuleOption.middleOfTheNight,
      ),
      useLocation: json['useLocation'] as bool? ?? true,
      city: json['city'] as String?,
      manualLat: (json['manualLat'] as num?)?.toDouble(),
      manualLng: (json['manualLng'] as num?)?.toDouble(),
      hasLocation: json['hasLocation'] as bool? ?? false,
      customFajrAngle: (json['customFajrAngle'] as num?)?.toDouble() ?? 18.0,
      customIshaAngle: (json['customIshaAngle'] as num?)?.toDouble() ?? 17.0,
      fajrOffset: json['fajrOffset'] as int? ?? 0,
      sunriseOffset: json['sunriseOffset'] as int? ?? 0,
      dhuhrOffset: json['dhuhrOffset'] as int? ?? 0,
      asrOffset: json['asrOffset'] as int? ?? 0,
      maghribOffset: json['maghribOffset'] as int? ?? 0,
      ishaOffset: json['ishaOffset'] as int? ?? 0,
      globalPrayerOffset: json['globalPrayerOffset'] as int? ?? 0,
      iqamahOffsetFajr: json['iqamahOffsetFajr'] as int? ?? 30,
      iqamahOffsetDhuhr: json['iqamahOffsetDhuhr'] as int? ?? 25,
      iqamahOffsetAsr: json['iqamahOffsetAsr'] as int? ?? 25,
      iqamahOffsetMaghrib: json['iqamahOffsetMaghrib'] as int? ?? 10,
      iqamahOffsetIsha: json['iqamahOffsetIsha'] as int? ?? 25,
      fridayPrayerTime:
          _parseNullableDayTime(json['fridayPrayerTime'] as String?),
      prayerNotifications: json['prayerNotifications'] as bool? ?? true,
      prayerNotifMinutes: json['prayerNotifMinutes'] as int? ?? 5,
      morningAzkarNotification:
          json['morningAzkarNotification'] as bool? ?? true,
      morningAzkarTime:
          _parseDayTime(json['morningAzkarTime'] as String? ?? '06:00'),
      eveningAzkarNotification:
          json['eveningAzkarNotification'] as bool? ?? true,
      eveningAzkarTime:
          _parseDayTime(json['eveningAzkarTime'] as String? ?? '20:00'),
      quranReminder: json['quranReminder'] as bool? ?? false,
      quranReminderTime:
          _parseDayTime(json['quranReminderTime'] as String? ?? '08:00'),
      silentDuringPrayer: json['silentDuringPrayer'] as bool? ?? false,
      silentDuration: json['silentDuration'] as int? ?? 10,
      silentBeforeIqamah: json['silentBeforeIqamah'] as bool? ?? false,
      silentBeforeIqamahMinutes:
          json['silentBeforeIqamahMinutes'] as int? ?? 15,
      dailyVerse: json['dailyVerse'] as bool? ?? true,
      dailyVerseTime:
          _parseDayTime(json['dailyVerseTime'] as String? ?? '07:00'),
      dailyHadith: json['dailyHadith'] as bool? ?? true,
      dailyHadithTime:
          _parseDayTime(json['dailyHadithTime'] as String? ?? '18:00'),
      dailyDua: json['dailyDua'] as bool? ?? false,
      dailyDuaTime: _parseDayTime(json['dailyDuaTime'] as String? ?? '12:00'),
      dailyWordEnabled: json['dailyWordEnabled'] as bool? ?? false,
      dailyWordHour: json['dailyWordHour'] as int? ?? 8,
      dailyWordMinute: json['dailyWordMinute'] as int? ?? 0,
      themeMode: ThemeModeOption.values.firstWhere(
        (e) => e.name == json['themeMode'],
        orElse: () => ThemeModeOption.light,
      ),
      quranThemeMode: QuranThemeMode.values.firstWhere(
        (e) => e.name == json['quranThemeMode'],
        orElse: () => QuranThemeMode.light,
      ),
      fontFamily: FontFamilyOption.values.firstWhere(
        (e) => e.name == json['fontFamily'],
        orElse: () => FontFamilyOption.calibri,
      ),
      fontScale: (json['fontScale'] as num?)?.toDouble() ?? 1.0,
      showArabicText: json['showArabicText'] as bool? ?? true,
      showDaleel: json['showDaleel'] as bool? ?? true,
      largeArabicFont: json['largeArabicFont'] as bool? ?? false,
      showEnglishTranslation: json['showEnglishTranslation'] as bool? ?? false,
      quranFontSize: (json['quranFontSize'] as num?)?.toDouble() ?? 22.0,
      appFontSize: (json['appFontSize'] as num?)?.toDouble() ?? 15.0,
      accentPreset: json['accentPreset'] as String? ?? 'night',
      isPremium: json['isPremium'] as bool? ?? false,
      use12Hour: json['use12Hour'] as bool? ?? true,
      azanSound: json['azanSound'] as String? ?? 'takbir',
      customAzanPath: json['customAzanPath'] as String?,
      azanVolume: (json['azanVolume'] as num?)?.toDouble() ?? 1.0,
      azanEnabledForFajr: json['azanEnabledForFajr'] as bool? ?? false,
      azanEnabledForDhuhr: json['azanEnabledForDhuhr'] as bool? ?? false,
      azanEnabledForAsr: json['azanEnabledForAsr'] as bool? ?? false,
      azanEnabledForMaghrib: json['azanEnabledForMaghrib'] as bool? ?? false,
      azanEnabledForIsha: json['azanEnabledForIsha'] as bool? ?? false,
      widgetRefreshMinutes: json['widgetRefreshMinutes'] as int? ?? 30,
      tafsirId: json['tafsirId'] as int? ?? 169,
      elevationCorrection: json['elevationCorrection'] as bool? ?? false,
      fardhPoint: json['fardhPoint'] as int? ?? 10,
      sunnahPoint: json['sunnahPoint'] as int? ?? 5,
      duhaPoint: json['duhaPoint'] as int? ?? 5,
      adhkarPoint: json['adhkarPoint'] as int? ?? 10,
      tasbihPoint: json['tasbihPoint'] as int? ?? 10,
      worshipMultiplier: (json['worshipMultiplier'] as num?)?.toDouble() ?? 1.0,
      excludedWorship: _parseListOrEmpty(json['excludedWorship']),
      customWorshipItems: _parseCustomItems(json['customWorshipItems']),
      hiddenWorshipItems: _parseListOrEmpty(json['hiddenWorshipItems']),
      firstLaunch: json['firstLaunch'] as bool? ?? true,
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
      hijriOffset: json['hijriOffset'] as int? ?? 2,
      quickActions: _parseStringList(json['quickActions']),
      tasbihDhikrSource: json['tasbihDhikrSource'] as String? ?? 'own',
      timezone: json['timezone'] as String? ?? 'Asia/Tehran',
    );
  }

  factory AppSettingsDto.fromEntity(AppSettings entity) {
    return AppSettingsDto(
      id: entity.id,
      calculationMethod: entity.calculationMethod,
      asrMethod: entity.asrMethod,
      highLatitudeRule: entity.highLatitudeRule,
      useLocation: entity.useLocation,
      city: entity.city,
      manualLat: entity.manualLat,
      manualLng: entity.manualLng,
      hasLocation: entity.hasLocation,
      customFajrAngle: entity.customFajrAngle,
      customIshaAngle: entity.customIshaAngle,
      fajrOffset: entity.fajrOffset,
      sunriseOffset: entity.sunriseOffset,
      dhuhrOffset: entity.dhuhrOffset,
      asrOffset: entity.asrOffset,
      maghribOffset: entity.maghribOffset,
      ishaOffset: entity.ishaOffset,
      globalPrayerOffset: entity.globalPrayerOffset,
      iqamahOffsetFajr: entity.iqamahOffsetFajr,
      iqamahOffsetDhuhr: entity.iqamahOffsetDhuhr,
      iqamahOffsetAsr: entity.iqamahOffsetAsr,
      iqamahOffsetMaghrib: entity.iqamahOffsetMaghrib,
      iqamahOffsetIsha: entity.iqamahOffsetIsha,
      fridayPrayerTime: entity.fridayPrayerTime,
      prayerNotifications: entity.prayerNotifications,
      prayerNotifMinutes: entity.prayerNotifMinutes,
      morningAzkarNotification: entity.morningAzkarNotification,
      morningAzkarTime: entity.morningAzkarTime,
      eveningAzkarNotification: entity.eveningAzkarNotification,
      eveningAzkarTime: entity.eveningAzkarTime,
      quranReminder: entity.quranReminder,
      quranReminderTime: entity.quranReminderTime,
      silentDuringPrayer: entity.silentDuringPrayer,
      silentDuration: entity.silentDuration,
      silentBeforeIqamah: entity.silentBeforeIqamah,
      silentBeforeIqamahMinutes: entity.silentBeforeIqamahMinutes,
      dailyVerse: entity.dailyVerse,
      dailyVerseTime: entity.dailyVerseTime,
      dailyHadith: entity.dailyHadith,
      dailyHadithTime: entity.dailyHadithTime,
      dailyDua: entity.dailyDua,
      dailyDuaTime: entity.dailyDuaTime,
      dailyWordEnabled: entity.dailyWordEnabled,
      dailyWordHour: entity.dailyWordHour,
      dailyWordMinute: entity.dailyWordMinute,
      themeMode: entity.themeMode,
      quranThemeMode: entity.quranThemeMode,
      fontFamily: entity.fontFamily,
      fontScale: entity.fontScale,
      showArabicText: entity.showArabicText,
      showDaleel: entity.showDaleel,
      largeArabicFont: entity.largeArabicFont,
      showEnglishTranslation: entity.showEnglishTranslation,
      quranFontSize: entity.quranFontSize,
      appFontSize: entity.appFontSize,
      accentPreset: entity.accentPreset,
      isPremium: entity.isPremium,
      use12Hour: entity.use12Hour,
      azanSound: entity.azanSound,
      customAzanPath: entity.customAzanPath,
      azanVolume: entity.azanVolume,
      azanEnabledForFajr: entity.azanEnabledForFajr,
      azanEnabledForDhuhr: entity.azanEnabledForDhuhr,
      azanEnabledForAsr: entity.azanEnabledForAsr,
      azanEnabledForMaghrib: entity.azanEnabledForMaghrib,
      azanEnabledForIsha: entity.azanEnabledForIsha,
      widgetRefreshMinutes: entity.widgetRefreshMinutes,
      tafsirId: entity.tafsirId,
      elevationCorrection: entity.elevationCorrection,
      fardhPoint: entity.fardhPoint,
      sunnahPoint: entity.sunnahPoint,
      duhaPoint: entity.duhaPoint,
      adhkarPoint: entity.adhkarPoint,
      tasbihPoint: entity.tasbihPoint,
      worshipMultiplier: entity.worshipMultiplier,
      excludedWorship: List<String>.from(entity.excludedWorship),
      customWorshipItems:
          List<Map<String, dynamic>>.from(entity.customWorshipItems),
      hiddenWorshipItems: List<String>.from(entity.hiddenWorshipItems),
      firstLaunch: entity.firstLaunch,
      onboardingCompleted: entity.onboardingCompleted,
      hijriOffset: entity.hijriOffset,
      quickActions: List<String>.from(entity.quickActions),
      tasbihDhikrSource: entity.tasbihDhikrSource,
      timezone: entity.timezone,
    );
  }

  AppSettings toEntity() {
    return AppSettings(
      id: id,
      calculationMethod: calculationMethod,
      asrMethod: asrMethod,
      highLatitudeRule: highLatitudeRule,
      useLocation: useLocation,
      city: city,
      manualLat: manualLat,
      manualLng: manualLng,
      hasLocation: hasLocation,
      customFajrAngle: customFajrAngle,
      customIshaAngle: customIshaAngle,
      fajrOffset: fajrOffset,
      sunriseOffset: sunriseOffset,
      dhuhrOffset: dhuhrOffset,
      asrOffset: asrOffset,
      maghribOffset: maghribOffset,
      ishaOffset: ishaOffset,
      globalPrayerOffset: globalPrayerOffset,
      iqamahOffsetFajr: iqamahOffsetFajr,
      iqamahOffsetDhuhr: iqamahOffsetDhuhr,
      iqamahOffsetAsr: iqamahOffsetAsr,
      iqamahOffsetMaghrib: iqamahOffsetMaghrib,
      iqamahOffsetIsha: iqamahOffsetIsha,
      fridayPrayerTime: fridayPrayerTime,
      prayerNotifications: prayerNotifications,
      prayerNotifMinutes: prayerNotifMinutes,
      morningAzkarNotification: morningAzkarNotification,
      morningAzkarTime: morningAzkarTime,
      eveningAzkarNotification: eveningAzkarNotification,
      eveningAzkarTime: eveningAzkarTime,
      quranReminder: quranReminder,
      quranReminderTime: quranReminderTime,
      silentDuringPrayer: silentDuringPrayer,
      silentDuration: silentDuration,
      silentBeforeIqamah: silentBeforeIqamah,
      silentBeforeIqamahMinutes: silentBeforeIqamahMinutes,
      dailyVerse: dailyVerse,
      dailyVerseTime: dailyVerseTime,
      dailyHadith: dailyHadith,
      dailyHadithTime: dailyHadithTime,
      dailyDua: dailyDua,
      dailyDuaTime: dailyDuaTime,
      dailyWordEnabled: dailyWordEnabled,
      dailyWordHour: dailyWordHour,
      dailyWordMinute: dailyWordMinute,
      themeMode: themeMode,
      quranThemeMode: quranThemeMode,
      fontFamily: fontFamily,
      fontScale: fontScale,
      showArabicText: showArabicText,
      showDaleel: showDaleel,
      largeArabicFont: largeArabicFont,
      showEnglishTranslation: showEnglishTranslation,
      quranFontSize: quranFontSize,
      appFontSize: appFontSize,
      accentPreset: accentPreset,
      isPremium: isPremium,
      use12Hour: use12Hour,
      azanSound: azanSound,
      customAzanPath: customAzanPath,
      azanVolume: azanVolume,
      azanEnabledForFajr: azanEnabledForFajr,
      azanEnabledForDhuhr: azanEnabledForDhuhr,
      azanEnabledForAsr: azanEnabledForAsr,
      azanEnabledForMaghrib: azanEnabledForMaghrib,
      azanEnabledForIsha: azanEnabledForIsha,
      widgetRefreshMinutes: widgetRefreshMinutes,
      tafsirId: tafsirId,
      elevationCorrection: elevationCorrection,
      fardhPoint: fardhPoint,
      sunnahPoint: sunnahPoint,
      duhaPoint: duhaPoint,
      adhkarPoint: adhkarPoint,
      tasbihPoint: tasbihPoint,
      worshipMultiplier: worshipMultiplier,
      excludedWorship: List<String>.from(excludedWorship),
      customWorshipItems: List<Map<String, dynamic>>.from(customWorshipItems),
      hiddenWorshipItems: List<String>.from(hiddenWorshipItems),
      firstLaunch: firstLaunch,
      onboardingCompleted: onboardingCompleted,
      hijriOffset: hijriOffset,
      quickActions: List<String>.from(quickActions),
      tasbihDhikrSource: tasbihDhikrSource,
      timezone: timezone,
    );
  }

  static DayTime _parseDayTime(String timeStr) {
    final parts = timeStr.split(':');
    final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    return DayTime(
      hour: hour.clamp(0, 23),
      minute: minute.clamp(0, 59),
    );
  }

  static DayTime? _parseNullableDayTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) {
      return null;
    }
    return _parseDayTime(timeStr);
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is List) {
      return value.cast<String>();
    }
    return ['qibla', 'khatm'];
  }

  /// Parses a JSON-encoded string (or raw list) into a string list; returns
  /// an empty list when absent — used for exclusion/hidden id lists.
  static List<String> _parseListOrEmpty(dynamic value) {
    if (value is List) {
      return value.whereType<String>().toList();
    }
    if (value is String && value.isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded.whereType<String>().toList();
        }
      } catch (e) {
        AppLogger.warning('AppSettings', 'custom item parse failed: $e');
      }
    }
    return const [];
  }

  /// Parses the custom worship items stored as a JSON-encoded string (or raw
  /// list). Falls back to the legacy `key:value;...` prefs format so old
  /// backups restore cleanly.
  static List<Map<String, dynamic>> _parseCustomItems(dynamic value) {
    if (value is List) {
      return value.whereType<Map>().map(Map<String, dynamic>.from).toList();
    }
    if (value is String && value.isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map(Map<String, dynamic>.from)
              .toList();
        }
      } catch (e) {
        AppLogger.warning(
            'AppSettings', 'json parse failed, trying legacy: $e');
        return _legacyParseCustomItems(value);
      }
    }
    return const [];
  }

  static List<Map<String, dynamic>> _legacyParseCustomItems(String s) {
    if (s.isEmpty) return const [];
    return s.split(';').map((part) {
      final map = <String, dynamic>{};
      for (final entry in part.split(',')) {
        final colon = entry.indexOf(':');
        if (colon > 0) {
          map[entry.substring(0, colon)] = entry.substring(colon + 1);
        }
      }
      return map;
    }).toList();
  }

  static String _dayTimeToString(DayTime t) {
    return '${t.hour}:${t.minute}';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'calculationMethod': calculationMethod.name,
      'asrMethod': asrMethod.name,
      'highLatitudeRule': highLatitudeRule.name,
      'useLocation': useLocation,
      'city': city,
      'manualLat': manualLat,
      'manualLng': manualLng,
      'hasLocation': hasLocation,
      'customFajrAngle': customFajrAngle,
      'customIshaAngle': customIshaAngle,
      'fajrOffset': fajrOffset,
      'sunriseOffset': sunriseOffset,
      'dhuhrOffset': dhuhrOffset,
      'asrOffset': asrOffset,
      'maghribOffset': maghribOffset,
      'ishaOffset': ishaOffset,
      'globalPrayerOffset': globalPrayerOffset,
      'iqamahOffsetFajr': iqamahOffsetFajr,
      'iqamahOffsetDhuhr': iqamahOffsetDhuhr,
      'iqamahOffsetAsr': iqamahOffsetAsr,
      'iqamahOffsetMaghrib': iqamahOffsetMaghrib,
      'iqamahOffsetIsha': iqamahOffsetIsha,
      'fridayPrayerTime': fridayPrayerTime == null
          ? null
          : _dayTimeToString(fridayPrayerTime!),
      'prayerNotifications': prayerNotifications,
      'prayerNotifMinutes': prayerNotifMinutes,
      'morningAzkarNotification': morningAzkarNotification,
      'morningAzkarTime': _dayTimeToString(morningAzkarTime),
      'eveningAzkarNotification': eveningAzkarNotification,
      'eveningAzkarTime': _dayTimeToString(eveningAzkarTime),
      'quranReminder': quranReminder,
      'quranReminderTime': _dayTimeToString(quranReminderTime),
      'silentDuringPrayer': silentDuringPrayer,
      'silentDuration': silentDuration,
      'silentBeforeIqamah': silentBeforeIqamah,
      'silentBeforeIqamahMinutes': silentBeforeIqamahMinutes,
      'dailyVerse': dailyVerse,
      'dailyVerseTime': _dayTimeToString(dailyVerseTime),
      'dailyHadith': dailyHadith,
      'dailyHadithTime': _dayTimeToString(dailyHadithTime),
      'dailyDua': dailyDua,
      'dailyDuaTime': _dayTimeToString(dailyDuaTime),
      'dailyWordEnabled': dailyWordEnabled,
      'dailyWordHour': dailyWordHour,
      'dailyWordMinute': dailyWordMinute,
      'themeMode': themeMode.name,
      'quranThemeMode': quranThemeMode.name,
      'fontFamily': fontFamily.name,
      'fontScale': fontScale,
      'showArabicText': showArabicText,
      'showDaleel': showDaleel,
      'largeArabicFont': largeArabicFont,
      'showEnglishTranslation': showEnglishTranslation,
      'quranFontSize': quranFontSize,
      'appFontSize': appFontSize,
      'accentPreset': accentPreset,
      'isPremium': isPremium,
      'use12Hour': use12Hour,
      'azanSound': azanSound,
      'customAzanPath': customAzanPath,
      'azanVolume': azanVolume,
      'azanEnabledForFajr': azanEnabledForFajr,
      'azanEnabledForDhuhr': azanEnabledForDhuhr,
      'azanEnabledForAsr': azanEnabledForAsr,
      'azanEnabledForMaghrib': azanEnabledForMaghrib,
      'azanEnabledForIsha': azanEnabledForIsha,
      'widgetRefreshMinutes': widgetRefreshMinutes,
      'tafsirId': tafsirId,
      'elevationCorrection': elevationCorrection,
      'fardhPoint': fardhPoint,
      'sunnahPoint': sunnahPoint,
      'duhaPoint': duhaPoint,
      'adhkarPoint': adhkarPoint,
      'tasbihPoint': tasbihPoint,
      'worshipMultiplier': worshipMultiplier,
      'excludedWorship': jsonEncode(excludedWorship),
      'customWorshipItems': jsonEncode(customWorshipItems),
      'hiddenWorshipItems': jsonEncode(hiddenWorshipItems),
      'firstLaunch': firstLaunch,
      'onboardingCompleted': onboardingCompleted,
      'hijriOffset': hijriOffset,
      'quickActions': quickActions,
      'tasbihDhikrSource': tasbihDhikrSource,
      'timezone': timezone,
    };
  }
}

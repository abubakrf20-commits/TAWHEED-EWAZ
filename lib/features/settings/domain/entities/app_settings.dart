import 'package:tawheeed/shared/models/day_time.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings_options.dart';

export 'package:tawheeed/features/settings/domain/entities/app_settings_options.dart';

const _unsetSettingValue = Object();

class AppSettings {
  final String id;

  // Prayer
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

  /// Optional custom Friday (Jumu'ah) prayer time. Null means "follow the
  /// calculated Dhuhr time" (the default). Set from the اذان & اقامه
  /// settings screen; shown on Fridays in the prayer-times displays.
  final DayTime? fridayPrayerTime;

  // Notifications
  final bool prayerNotifications;
  final int prayerNotifMinutes;
  final bool morningAzkarNotification;
  final DayTime morningAzkarTime;
  final bool eveningAzkarNotification;
  final DayTime eveningAzkarTime;
  final bool quranReminder;
  final DayTime quranReminderTime;

  // Silent Mode
  final bool silentDuringPrayer;
  final int silentDuration;
  final bool silentBeforeIqamah;
  final int silentBeforeIqamahMinutes;

  // Daily Reminders
  final bool dailyVerse;
  final DayTime dailyVerseTime;
  final bool dailyHadith;
  final DayTime dailyHadithTime;
  final bool dailyDua;
  final DayTime dailyDuaTime;
  final bool dailyWordEnabled;
  final int dailyWordHour;
  final int dailyWordMinute;

  // UI
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

  // Azan / Audio
  final bool use12Hour;
  final String azanSound;
  final String? customAzanPath;
  final double azanVolume;
  final bool azanEnabledForFajr;
  final bool azanEnabledForDhuhr;
  final bool azanEnabledForAsr;
  final bool azanEnabledForMaghrib;
  final bool azanEnabledForIsha;

  // Widget
  final int widgetRefreshMinutes;

  // Quran
  final int tafsirId;

  /// Elevation (horizon-dip) correction for sunrise/maghrib times.
  final bool elevationCorrection;

  // Evaluation (امتیازدهی عبادات — قابل تنظیم توسط کاربر)
  final int fardhPoint;
  final int sunnahPoint;
  final int duhaPoint;
  final int adhkarPoint;
  final int tasbihPoint;
  final double worshipMultiplier;
  final List<String> excludedWorship;

  /// User-created worship checklist items — each map holds
  /// `{id, label, iconName, points}`.
  final List<Map<String, dynamic>> customWorshipItems;

  /// Ids of the default worship items the user chose to hide.
  final List<String> hiddenWorshipItems;

  // Other
  final bool firstLaunch;
  final bool onboardingCompleted;
  final int hijriOffset;
  final List<String> quickActions;
  final String tasbihDhikrSource;
  final String timezone;

  const AppSettings({
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
    this.fardhPoint = 10,
    this.sunnahPoint = 5,
    this.duhaPoint = 5,
    this.adhkarPoint = 10,
    this.tasbihPoint = 10,
    this.worshipMultiplier = 1.0,
    this.excludedWorship = const [],
    this.customWorshipItems = const [],
    this.hiddenWorshipItems = const [],
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
    this.firstLaunch = true,
    this.onboardingCompleted = false,
    this.hijriOffset = 2,
    this.quickActions = const ['qibla', 'khatm'],
    this.tasbihDhikrSource = 'own',
    this.timezone = 'Asia/Tehran',
  });

  AppSettings copyWith({
    String? id,
    CalculationMethodOption? calculationMethod,
    AsrMethod? asrMethod,
    HighLatitudeRuleOption? highLatitudeRule,
    bool? useLocation,
    String? city,
    double? manualLat,
    double? manualLng,
    bool? hasLocation,
    double? customFajrAngle,
    double? customIshaAngle,
    int? fajrOffset,
    int? sunriseOffset,
    int? dhuhrOffset,
    int? asrOffset,
    int? maghribOffset,
    int? ishaOffset,
    int? globalPrayerOffset,
    int? iqamahOffsetFajr,
    int? iqamahOffsetDhuhr,
    int? iqamahOffsetAsr,
    int? iqamahOffsetMaghrib,
    int? iqamahOffsetIsha,
    Object? fridayPrayerTime = _unsetSettingValue,
    bool? prayerNotifications,
    int? prayerNotifMinutes,
    bool? morningAzkarNotification,
    DayTime? morningAzkarTime,
    bool? eveningAzkarNotification,
    DayTime? eveningAzkarTime,
    bool? quranReminder,
    DayTime? quranReminderTime,
    bool? silentDuringPrayer,
    int? silentDuration,
    bool? silentBeforeIqamah,
    int? silentBeforeIqamahMinutes,
    bool? dailyVerse,
    DayTime? dailyVerseTime,
    bool? dailyHadith,
    DayTime? dailyHadithTime,
    bool? dailyDua,
    DayTime? dailyDuaTime,
    bool? dailyWordEnabled,
    int? dailyWordHour,
    int? dailyWordMinute,
    ThemeModeOption? themeMode,
    FontFamilyOption? fontFamily,
    double? fontScale,
    bool? showArabicText,
    bool? showDaleel,
    bool? largeArabicFont,
    bool? showEnglishTranslation,
    double? quranFontSize,
    double? appFontSize,
    String? accentPreset,
    bool? isPremium,
    bool? use12Hour,
    String? azanSound,
    Object? customAzanPath = _unsetSettingValue,
    double? azanVolume,
    bool? azanEnabledForFajr,
    bool? azanEnabledForDhuhr,
    bool? azanEnabledForAsr,
    bool? azanEnabledForMaghrib,
    bool? azanEnabledForIsha,
    int? widgetRefreshMinutes,
    int? tafsirId,
    bool? elevationCorrection,
    bool? firstLaunch,
    bool? onboardingCompleted,
    int? hijriOffset,
    List<String>? quickActions,
    String? tasbihDhikrSource,
    String? timezone,
    QuranThemeMode? quranThemeMode,
    int? fardhPoint,
    int? sunnahPoint,
    int? duhaPoint,
    int? adhkarPoint,
    int? tasbihPoint,
    double? worshipMultiplier,
    List<String>? excludedWorship,
    List<Map<String, dynamic>>? customWorshipItems,
    List<String>? hiddenWorshipItems,
  }) {
    return AppSettings(
      id: id ?? this.id,
      calculationMethod: calculationMethod ?? this.calculationMethod,
      asrMethod: asrMethod ?? this.asrMethod,
      highLatitudeRule: highLatitudeRule ?? this.highLatitudeRule,
      useLocation: useLocation ?? this.useLocation,
      city: city ?? this.city,
      manualLat: manualLat ?? this.manualLat,
      manualLng: manualLng ?? this.manualLng,
      hasLocation: hasLocation ?? this.hasLocation,
      customFajrAngle: customFajrAngle ?? this.customFajrAngle,
      customIshaAngle: customIshaAngle ?? this.customIshaAngle,
      fajrOffset: fajrOffset ?? this.fajrOffset,
      sunriseOffset: sunriseOffset ?? this.sunriseOffset,
      dhuhrOffset: dhuhrOffset ?? this.dhuhrOffset,
      asrOffset: asrOffset ?? this.asrOffset,
      maghribOffset: maghribOffset ?? this.maghribOffset,
      ishaOffset: ishaOffset ?? this.ishaOffset,
      globalPrayerOffset: globalPrayerOffset ?? this.globalPrayerOffset,
      iqamahOffsetFajr: iqamahOffsetFajr ?? this.iqamahOffsetFajr,
      iqamahOffsetDhuhr: iqamahOffsetDhuhr ?? this.iqamahOffsetDhuhr,
      iqamahOffsetAsr: iqamahOffsetAsr ?? this.iqamahOffsetAsr,
      iqamahOffsetMaghrib: iqamahOffsetMaghrib ?? this.iqamahOffsetMaghrib,
      iqamahOffsetIsha: iqamahOffsetIsha ?? this.iqamahOffsetIsha,
      fridayPrayerTime: identical(fridayPrayerTime, _unsetSettingValue)
          ? this.fridayPrayerTime
          : fridayPrayerTime as DayTime?,
      prayerNotifications: prayerNotifications ?? this.prayerNotifications,
      prayerNotifMinutes: prayerNotifMinutes ?? this.prayerNotifMinutes,
      morningAzkarNotification:
          morningAzkarNotification ?? this.morningAzkarNotification,
      morningAzkarTime: morningAzkarTime ?? this.morningAzkarTime,
      eveningAzkarNotification:
          eveningAzkarNotification ?? this.eveningAzkarNotification,
      eveningAzkarTime: eveningAzkarTime ?? this.eveningAzkarTime,
      quranReminder: quranReminder ?? this.quranReminder,
      quranReminderTime: quranReminderTime ?? this.quranReminderTime,
      silentDuringPrayer: silentDuringPrayer ?? this.silentDuringPrayer,
      silentDuration: silentDuration ?? this.silentDuration,
      silentBeforeIqamah: silentBeforeIqamah ?? this.silentBeforeIqamah,
      silentBeforeIqamahMinutes:
          silentBeforeIqamahMinutes ?? this.silentBeforeIqamahMinutes,
      dailyVerse: dailyVerse ?? this.dailyVerse,
      dailyVerseTime: dailyVerseTime ?? this.dailyVerseTime,
      dailyHadith: dailyHadith ?? this.dailyHadith,
      dailyHadithTime: dailyHadithTime ?? this.dailyHadithTime,
      dailyDua: dailyDua ?? this.dailyDua,
      dailyDuaTime: dailyDuaTime ?? this.dailyDuaTime,
      dailyWordEnabled: dailyWordEnabled ?? this.dailyWordEnabled,
      dailyWordHour: dailyWordHour ?? this.dailyWordHour,
      dailyWordMinute: dailyWordMinute ?? this.dailyWordMinute,
      themeMode: themeMode ?? this.themeMode,
      quranThemeMode: quranThemeMode ?? this.quranThemeMode,
      fontFamily: fontFamily ?? this.fontFamily,
      fontScale: fontScale ?? this.fontScale,
      showArabicText: showArabicText ?? this.showArabicText,
      showDaleel: showDaleel ?? this.showDaleel,
      largeArabicFont: largeArabicFont ?? this.largeArabicFont,
      showEnglishTranslation:
          showEnglishTranslation ?? this.showEnglishTranslation,
      quranFontSize: quranFontSize ?? this.quranFontSize,
      appFontSize: appFontSize ?? this.appFontSize,
      accentPreset: accentPreset ?? this.accentPreset,
      isPremium: isPremium ?? this.isPremium,
      use12Hour: use12Hour ?? this.use12Hour,
      azanSound: azanSound ?? this.azanSound,
      customAzanPath: identical(customAzanPath, _unsetSettingValue)
          ? this.customAzanPath
          : customAzanPath as String?,
      azanVolume: azanVolume ?? this.azanVolume,
      azanEnabledForFajr: azanEnabledForFajr ?? this.azanEnabledForFajr,
      azanEnabledForDhuhr: azanEnabledForDhuhr ?? this.azanEnabledForDhuhr,
      azanEnabledForAsr: azanEnabledForAsr ?? this.azanEnabledForAsr,
      azanEnabledForMaghrib:
          azanEnabledForMaghrib ?? this.azanEnabledForMaghrib,
      azanEnabledForIsha: azanEnabledForIsha ?? this.azanEnabledForIsha,
      widgetRefreshMinutes: widgetRefreshMinutes ?? this.widgetRefreshMinutes,
      tafsirId: tafsirId ?? this.tafsirId,
      elevationCorrection: elevationCorrection ?? this.elevationCorrection,
      firstLaunch: firstLaunch ?? this.firstLaunch,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      hijriOffset: hijriOffset ?? this.hijriOffset,
      quickActions: quickActions ?? this.quickActions,
      tasbihDhikrSource: tasbihDhikrSource ?? this.tasbihDhikrSource,
      timezone: timezone ?? this.timezone,
      fardhPoint: fardhPoint ?? this.fardhPoint,
      sunnahPoint: sunnahPoint ?? this.sunnahPoint,
      duhaPoint: duhaPoint ?? this.duhaPoint,
      adhkarPoint: adhkarPoint ?? this.adhkarPoint,
      tasbihPoint: tasbihPoint ?? this.tasbihPoint,
      worshipMultiplier: worshipMultiplier ?? this.worshipMultiplier,
      excludedWorship: excludedWorship ?? this.excludedWorship,
      customWorshipItems: customWorshipItems ?? this.customWorshipItems,
      hiddenWorshipItems: hiddenWorshipItems ?? this.hiddenWorshipItems,
    );
  }

  /// Whether the audible azan is enabled for at least one prayer. Used to gate
  /// the native setAlarmClock alarms independently of the prayer-reminder
  /// toggle: the azan sound must fire when any per-prayer azan is on even if
  /// «یادآوری اوقات نماز» is off.
  bool get anyAzanEnabled =>
      azanEnabledForFajr ||
      azanEnabledForDhuhr ||
      azanEnabledForAsr ||
      azanEnabledForMaghrib ||
      azanEnabledForIsha;

  /// Whether the user expects at least one scheduled notification. Background
  /// alarms only matter for such users, so the Home battery warning and
  /// similar prompts can stay hidden for everyone else.
  bool get anyNotificationEnabled =>
      prayerNotifications ||
      morningAzkarNotification ||
      eveningAzkarNotification ||
      quranReminder ||
      dailyVerse ||
      dailyHadith ||
      dailyDua ||
      dailyWordEnabled ||
      anyAzanEnabled;
}

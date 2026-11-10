import 'package:drift/drift.dart';

class AppSettingsTable extends Table {
  TextColumn get id => text()();
  IntColumn get calculationMethod => integer()();
  IntColumn get asrMethod => integer()();

  /// High-latitude rule for Fajr/Isha (see [HighLatitudeRuleOption]):
  /// 0 = middle of the night (default), 1 = seventh, 2 = twilight angle.
  IntColumn get highLatitudeRule => integer().withDefault(const Constant(0))();
  BoolColumn get useLocation => boolean()();
  TextColumn get city => text().nullable()();
  RealColumn get manualLat => real().nullable()();
  RealColumn get manualLng => real().nullable()();
  BoolColumn get hasLocation => boolean()();
  RealColumn get customFajrAngle => real()();
  RealColumn get customIshaAngle => real()();
  IntColumn get fajrOffset => integer()();
  IntColumn get sunriseOffset => integer()();
  IntColumn get dhuhrOffset => integer()();
  IntColumn get asrOffset => integer()();
  IntColumn get maghribOffset => integer()();
  IntColumn get ishaOffset => integer()();
  IntColumn get iqamahOffsetFajr => integer()();
  IntColumn get iqamahOffsetDhuhr => integer()();
  IntColumn get iqamahOffsetAsr => integer()();
  IntColumn get iqamahOffsetMaghrib => integer()();
  IntColumn get iqamahOffsetIsha => integer()();
  TextColumn get fridayPrayerTime => text().nullable()();
  BoolColumn get prayerNotifications => boolean()();
  IntColumn get prayerNotifMinutes => integer()();
  BoolColumn get morningAzkarNotification => boolean()();
  IntColumn get morningAzkarTimeHour => integer()();
  IntColumn get morningAzkarTimeMinute => integer()();
  BoolColumn get eveningAzkarNotification => boolean()();
  IntColumn get eveningAzkarTimeHour => integer()();
  IntColumn get eveningAzkarTimeMinute => integer()();
  BoolColumn get quranReminder => boolean()();
  IntColumn get quranReminderTimeHour => integer()();
  IntColumn get quranReminderTimeMinute => integer()();
  BoolColumn get silentDuringPrayer => boolean()();
  IntColumn get silentDuration => integer()();
  BoolColumn get silentBeforeIqamah => boolean()();
  IntColumn get silentBeforeIqamahMinutes => integer()();
  BoolColumn get dailyVerse => boolean()();
  IntColumn get dailyVerseTimeHour => integer()();
  IntColumn get dailyVerseTimeMinute => integer()();
  BoolColumn get dailyHadith => boolean()();
  IntColumn get dailyHadithTimeHour => integer()();
  IntColumn get dailyHadithTimeMinute => integer()();
  BoolColumn get dailyDua => boolean()();
  IntColumn get dailyDuaTimeHour => integer()();
  IntColumn get dailyDuaTimeMinute => integer()();
  BoolColumn get dailyWordEnabled => boolean()();
  IntColumn get dailyWordHour => integer()();
  IntColumn get dailyWordMinute => integer()();
  TextColumn get themeMode => text()();
  TextColumn get quranThemeMode => text()();
  TextColumn get fontFamily => text()();
  RealColumn get fontScale => real()();
  BoolColumn get showArabicText => boolean()();
  BoolColumn get showDaleel => boolean()();
  BoolColumn get largeArabicFont => boolean()();
  BoolColumn get showEnglishTranslation => boolean()();
  RealColumn get quranFontSize => real()();
  RealColumn get appFontSize => real()();
  TextColumn get accentPreset => text()();
  BoolColumn get isPremium => boolean()();
  BoolColumn get use12Hour => boolean()();
  TextColumn get azanSound => text()();
  TextColumn get customAzanPath => text().nullable()();
  RealColumn get azanVolume => real()();
  BoolColumn get azanEnabledForFajr => boolean()();
  BoolColumn get azanEnabledForDhuhr => boolean()();
  BoolColumn get azanEnabledForAsr => boolean()();
  BoolColumn get azanEnabledForMaghrib => boolean()();
  BoolColumn get azanEnabledForIsha => boolean()();
  IntColumn get widgetRefreshMinutes => integer()();
  IntColumn get tafsirId => integer()();

  /// Elevation (horizon-dip) correction for sunrise/maghrib — OFF by default;
  /// the user opts in from prayer settings.
  BoolColumn get elevationCorrection =>
      boolean().withDefault(const Constant(false))();

  // Evaluation (امتیازدهی عبادات) — persisted in the settings row since v23.
  IntColumn get fardhPoint => integer().withDefault(const Constant(10))();
  IntColumn get sunnahPoint => integer().withDefault(const Constant(5))();
  IntColumn get duhaPoint => integer().withDefault(const Constant(5))();
  IntColumn get adhkarPoint => integer().withDefault(const Constant(10))();
  IntColumn get tasbihPoint => integer().withDefault(const Constant(10))();
  RealColumn get worshipMultiplier => real().withDefault(const Constant(1.0))();
  TextColumn get excludedWorship => text().withDefault(const Constant(''))();
  TextColumn get customWorshipItems => text().withDefault(const Constant(''))();
  TextColumn get hiddenWorshipItems => text().withDefault(const Constant(''))();

  BoolColumn get firstLaunch => boolean()();
  BoolColumn get onboardingCompleted => boolean()();
  IntColumn get hijriOffset => integer()();
  TextColumn get quickActions => text()();
  TextColumn get tasbihDhikrSource => text()();
  TextColumn get timezone => text()();

  @override
  Set<Column> get primaryKey => {id};
}

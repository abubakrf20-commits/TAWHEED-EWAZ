import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';

export 'settings_notifier.dart'
    show settingsProvider, settingsRepositoryProvider;

/// Convenience providers reading from the async SettingsNotifier. Watching these
/// (instead of the whole [settingsProvider]) means a widget only rebuilds when
/// the single field it depends on changes — avoiding whole-tree rebuild storms.

/// Composite key of all settings fields that affect prayer time calculation.
/// The PrayerTimes provider watches this instead of the full settingsProvider
/// to avoid recalculating prayer times on unrelated setting changes (fonts, theme, etc.).
class PrayerSettingsKey {
  final CalculationMethodOption calcMethod;
  final AsrMethod asrMethod;
  final HighLatitudeRuleOption highLatitudeRule;
  final bool useLocation;
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
  final String timezone;
  final bool elevationCorrection;

  const PrayerSettingsKey({
    required this.calcMethod,
    required this.asrMethod,
    required this.highLatitudeRule,
    required this.useLocation,
    this.manualLat,
    this.manualLng,
    required this.hasLocation,
    required this.customFajrAngle,
    required this.customIshaAngle,
    required this.fajrOffset,
    required this.sunriseOffset,
    required this.dhuhrOffset,
    required this.asrOffset,
    required this.maghribOffset,
    required this.ishaOffset,
    required this.globalPrayerOffset,
    required this.timezone,
    required this.elevationCorrection,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrayerSettingsKey &&
          calcMethod == other.calcMethod &&
          asrMethod == other.asrMethod &&
          highLatitudeRule == other.highLatitudeRule &&
          useLocation == other.useLocation &&
          manualLat == other.manualLat &&
          manualLng == other.manualLng &&
          hasLocation == other.hasLocation &&
          customFajrAngle == other.customFajrAngle &&
          customIshaAngle == other.customIshaAngle &&
          fajrOffset == other.fajrOffset &&
          sunriseOffset == other.sunriseOffset &&
          dhuhrOffset == other.dhuhrOffset &&
          asrOffset == other.asrOffset &&
          maghribOffset == other.maghribOffset &&
          ishaOffset == other.ishaOffset &&
          globalPrayerOffset == other.globalPrayerOffset &&
          timezone == other.timezone &&
          elevationCorrection == other.elevationCorrection;

  @override
  int get hashCode => Object.hash(
        calcMethod,
        asrMethod,
        highLatitudeRule,
        useLocation,
        manualLat,
        manualLng,
        hasLocation,
        customFajrAngle,
        customIshaAngle,
        fajrOffset,
        sunriseOffset,
        dhuhrOffset,
        asrOffset,
        maghribOffset,
        ishaOffset,
        globalPrayerOffset,
        timezone,
        elevationCorrection,
      );
}

/// Watches only the prayer-relevant settings fields.
final prayerRelevantSettingsProvider = Provider<PrayerSettingsKey?>((ref) {
  final s = ref.watch(settingsProvider.select((a) => a.value));
  if (s == null) return null;
  return PrayerSettingsKey(
    calcMethod: s.calculationMethod,
    asrMethod: s.asrMethod,
    highLatitudeRule: s.highLatitudeRule,
    useLocation: s.useLocation,
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
    globalPrayerOffset: s.globalPrayerOffset,
    timezone: s.timezone,
    elevationCorrection: s.elevationCorrection,
  );
});

final hijriOffsetProvider = Provider<int>((ref) {
  return ref.watch(settingsProvider.select((a) => a.value?.hijriOffset ?? 2));
});

final use12HourProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider.select((a) => a.value?.use12Hour ?? true));
});

final showArabicTextProvider = Provider<bool>((ref) {
  return ref
      .watch(settingsProvider.select((a) => a.value?.showArabicText ?? true));
});

final showDaleelProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider.select((a) => a.value?.showDaleel ?? true));
});

final largeArabicFontProvider = Provider<bool>((ref) {
  return ref
      .watch(settingsProvider.select((a) => a.value?.largeArabicFont ?? false));
});

final showEnglishTranslationProvider = Provider<bool>((ref) {
  return ref.watch(
      settingsProvider.select((a) => a.value?.showEnglishTranslation ?? false));
});

final tasbihDhikrSourceProvider = Provider<String>((ref) {
  return ref.watch(
      settingsProvider.select((a) => a.value?.tasbihDhikrSource ?? 'own'));
});

final calcMethodProvider = Provider<CalculationMethodOption>((ref) {
  return ref.watch(settingsProvider.select((a) =>
      a.value?.calculationMethod ?? CalculationMethodOption.muslimWorldLeague));
});

final asrMethodProvider = Provider<AsrMethod>((ref) {
  return ref.watch(
      settingsProvider.select((a) => a.value?.asrMethod ?? AsrMethod.shafi));
});

final highLatitudeRuleProvider = Provider<HighLatitudeRuleOption>((ref) {
  return ref.watch(settingsProvider.select((a) =>
      a.value?.highLatitudeRule ?? HighLatitudeRuleOption.middleOfTheNight));
});

final useLocationProvider = Provider<bool>((ref) {
  return ref
      .watch(settingsProvider.select((a) => a.value?.useLocation ?? true));
});

final manualCoordsProvider = Provider<({double lat, double lng})>((ref) {
  final s = ref.watch(settingsProvider.select((a) => a.value));
  return (lat: s?.manualLat ?? 0.0, lng: s?.manualLng ?? 0.0);
});

final cityProvider = Provider<String?>((ref) {
  return ref.watch(settingsProvider.select((a) => a.value?.city));
});

final quickActionsProvider = Provider<List<String>>((ref) {
  return ref.watch(settingsProvider
      .select((a) => a.value?.quickActions ?? const ['qibla', 'khatm']));
});

/// Save quick actions through the settings store (Drift) — the single
/// quick-actions home; the legacy SharedPreferences key is lifted at boot.
Future<void> saveQuickActions(List<String> actions, WidgetRef ref) {
  return ref.read(settingsProvider.notifier).setQuickActions(actions);
}

/// One-shot boot migration: chips saved before the Drift store existed live
/// under the legacy 'quick_actions' key — apply them to settings once, then
/// drop the key. The key is removed only after a successful write, so a
/// failure retries on the next boot; re-applying the same list is idempotent.
Future<void> migrateQuickActionsFromPrefs(WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getStringList('quick_actions');
  if (saved == null) return;
  await ref.read(settingsProvider.future);
  await ref.read(settingsProvider.notifier).setQuickActions(saved);
  await prefs.remove('quick_actions');
}

final prayerNotificationsProvider = Provider<bool>((ref) {
  return ref.watch(
      settingsProvider.select((a) => a.value?.prayerNotifications ?? true));
});

final themeModeProvider = Provider<ThemeMode>((ref) {
  final v = ref.watch(settingsProvider
      .select((a) => a.value?.themeMode ?? ThemeModeOption.light));
  switch (v) {
    case ThemeModeOption.light:
      return ThemeMode.light;
    case ThemeModeOption.dark:
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
});

final quranThemeModeProvider = Provider<QuranThemeMode>((ref) {
  return ref.watch(settingsProvider
      .select((a) => a.value?.quranThemeMode ?? QuranThemeMode.light));
});

final azanSoundProvider = Provider<String>((ref) {
  return ref
      .watch(settingsProvider.select((a) => a.value?.azanSound ?? 'takbir'));
});

final azanVolumeProvider = Provider<double>((ref) {
  return ref.watch(settingsProvider.select((a) => a.value?.azanVolume ?? 1.0));
});

final timezoneProvider = Provider<String>((ref) {
  return ref.watch(
      settingsProvider.select((a) => a.value?.timezone ?? 'Asia/Tehran'));
});

final silentDuringPrayerProvider = Provider<bool>((ref) {
  return ref.watch(
      settingsProvider.select((a) => a.value?.silentDuringPrayer ?? false));
});

final customFajrAngleProvider = Provider<double>((ref) {
  return ref
      .watch(settingsProvider.select((a) => a.value?.customFajrAngle ?? 18.0));
});

final customIshaAngleProvider = Provider<double>((ref) {
  return ref
      .watch(settingsProvider.select((a) => a.value?.customIshaAngle ?? 17.0));
});

final quranFontSizeProvider = Provider<double>((ref) {
  return ref
      .watch(settingsProvider.select((a) => a.value?.quranFontSize ?? 22.0));
});

final appFontSizeProvider = Provider<double>((ref) {
  return ref
      .watch(settingsProvider.select((a) => a.value?.appFontSize ?? 15.0));
});

final fontFamilyProvider = Provider<FontFamilyOption>((ref) {
  return ref.watch(settingsProvider
      .select((a) => a.value?.fontFamily ?? FontFamilyOption.calibri));
});

final accentPresetProvider = Provider<String>((ref) {
  return ref.watch(
      settingsProvider.select((a) => a.value?.accentPreset ?? 'night'));
});

final tafsirIdProvider = Provider<int>((ref) {
  return ref.watch(settingsProvider.select((a) => a.value?.tafsirId ?? 169));
});

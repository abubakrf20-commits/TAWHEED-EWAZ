import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:tawheeed/core/services/permission_service.dart';
import 'package:tawheeed/features/settings/data/datasources/settings_drift_datasource.dart';
import 'package:tawheeed/features/settings/data/datasources/settings_local_datasource.dart';
import 'package:tawheeed/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:tawheeed/shared/models/day_time.dart';
import 'package:tawheeed/shared/providers/shared_prefs_provider.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_infra_providers.dart';
import 'package:tawheeed/shared/utils/alert_volume.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/domain/repositories/settings_repository.dart';
import 'package:tawheeed/features/settings/domain/repositories/settings_writer.dart';
import 'package:tawheeed/features/settings/data/daos/settings_dao.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_time_provider.dart';
import 'package:tawheeed/features/prayer/services/azan_playback_service.dart';
import 'package:tawheeed/features/prayer/services/prayer_azan_sound_store.dart';

part 'settings_notifier.g.dart';

@Riverpod(keepAlive: true)
Future<SettingsRepository> settingsRepository(Ref ref) async {
  final prefs = await ref.read(sharedPrefsProvider.future);
  final dao = ref.read(settingsDaoProvider);
  return SettingsRepositoryImpl(
    driftDataSource: SettingsDriftDataSource(dao),
    localDataSource: SettingsLocalDataSource(prefs),
  );
}

/// True when the last write to the settings row did not reach disk.
///
/// WHY: [_save] is optimistic — it publishes the new value, then rolls back if
/// the repository throws. With nothing else to say so, the rollback is
/// indistinguishable from a switch that simply refuses to move: the user taps
/// «روشن», it snaps back, and nothing explains why. Screens watch this and
/// show [SettingsSaveFailureBanner] so the revert has a reason attached.
final settingsSaveFailedProvider =
    NotifierProvider<SettingsSaveFailedNotifier, bool>(
        SettingsSaveFailedNotifier.new);

class SettingsSaveFailedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) {
    if (state != value) state = value;
  }
}

@Riverpod(keepAlive: true)
class Settings extends _$Settings implements SettingsWriter {
  @override
  Future<AppSettings> build() async {
    final repo = await ref.read(settingsRepositoryProvider.future);
    final settings = await repo.getSettings();
    // Reconcile the stored timezone with the device's real zone OFF the
    // critical path: the native channel can be slow and is absent in tests and
    // background isolates, so awaiting it here would stall the entire settings
    // load (and every screen behind it). Firing it loose lets the first render
    // go ahead on the stored value and self-heals a moment later. Skipped under
    // `flutter test` (FLUTTER_TEST env) so the fake-async binding is not left
    // with the channel's 2s timeout timer and tests stay deterministic on the
    // stored zone.
    if (Platform.environment['FLUTTER_TEST'] != 'true') {
      unawaited(_reconcileTimezone(settings));
    }
    ref.onDispose(_cancelReschedule);
    return settings;
  }

  /// The persisted `timezone` used to stay frozen at the factory default
  /// `Asia/Tehran` because no screen ever writes it, so prayer times, the home
  /// widget, notifications and the offline cache all rendered on Tehran's
  /// clock — 30 min / 1 h off for users in the Gulf, Afghanistan, etc. There is
  /// still no timezone UI, so the device's own Olson zone is the source of
  /// truth: adopt it whenever it differs from what is stored (this also follows
  /// the user across travel on the next launch). The native channel returns
  /// null in tests/background isolates, so those paths keep the stored value and
  /// stay deterministic.
  ///
  /// Manual mode is exempt: a picked city owns the zone (the city picker
  /// writes the city's own IANA id), and device adoption would clobber it on
  /// every launch.
  Future<void> _reconcileTimezone(AppSettings stored) async {
    if (!stored.useLocation) return;
    String? device;
    try {
      device = await PermissionService().deviceTimezoneName();
    } catch (e) {
      AppLogger.warning('SettingsNotifier',
          'device timezone unavailable, keeping stored "${stored.timezone}": $e');
      return;
    }
    if (device == null || device == stored.timezone) return;
    try {
      tzdata.initializeTimeZones();
      tz.getLocation(device); // only trust a real Olson id
    } catch (e) {
      AppLogger.warning('SettingsNotifier',
          'device timezone "$device" is not a known Olson id, ignoring: $e');
      return;
    }
    // Only write if the stored zone is still the one we compared against, so a
    // user edit made while this ran is never clobbered.
    await patch((s) =>
        s.timezone == stored.timezone ? s.copyWith(timezone: device) : s);
    AppLogger.info('SettingsNotifier', 'timezone adopted from device: $device');
  }

  AppSettings get _current => state.value ?? const AppSettings();

  Timer? _rescheduleDebounce;

  /// Mutates the PERSISTED settings, never the factory defaults.
  ///
  /// During startup the prayer repository writes through this notifier
  /// (`setCity`, `setManualCoords`, `setHasLocation`) while [build] may still be
  /// in flight, so `state.value` can be null. Building a full object from
  /// `const AppSettings()` and saving it blanked every stored field — theme,
  /// notification times, point settings, everything. Awaiting the load first
  /// makes the write a read-modify-write on the real row.
  Future<void> _saveWith(AppSettings Function(AppSettings) updater) async {
    final current = state.value ?? await future;
    await _save(updater(current));
  }

  /// Writes [updated], reporting whether it reached disk.
  ///
  /// The optimistic publish is what every switch binds to, so a rollback on
  /// failure is invisible unless it is announced — [settingsSaveFailedProvider]
  /// carries that, and the return value lets a one-shot action (reset, import)
  /// avoid claiming success it did not have.
  Future<bool> _save(AppSettings updated) async {
    final previous = state;
    state = AsyncValue.data(updated);
    try {
      final repo = await ref.read(settingsRepositoryProvider.future);
      await repo.updateSettings(updated);
      if (ref.mounted && ref.read(settingsSaveFailedProvider)) {
        ref.read(settingsSaveFailedProvider.notifier).set(false);
      }
      return true;
    } catch (e, st) {
      AppLogger.error('SettingsNotifier._save', e, st);
      if (ref.mounted) {
        state = previous;
        ref.read(settingsSaveFailedProvider.notifier).set(true);
      }
      return false;
    }
  }

  /// Apply a partial update via an updater function.
  /// New code should prefer this over adding individual setters.
  Future<void> patch(AppSettings Function(AppSettings) updater) async {
    await _saveWith(updater);
  }

  /// Restore every user-facing preference to its factory default while keeping
  /// the two fields that are not preferences — `onboardingCompleted` and
  /// `isPremium`. The repository's `resetSettings()` also clears those two, so
  /// it is deliberately not used here.
  ///
  /// The dialog behind this promises «همهٔ تنظیمات», so the preferences that
  /// live outside the [AppSettings] row are cleared too: the per-prayer adhan
  /// voices, the alert volume and the Islamic-events notification toggle. They
  /// used to survive, which meant a reset restored the shared voice for four
  /// prayers and silently kept the fifth one's override.
  ///
  /// Returns false when the write failed; the caller must not then claim that
  /// the settings were reset.
  Future<bool> resetPreferences() async {
    final current = state.value ?? await future;
    final ok = await _save(const AppSettings().copyWith(
      onboardingCompleted: current.onboardingCompleted,
      isPremium: current.isPremium,
    ));
    if (!ok) return false;
    await _clearPrefsBackedPreferences();
    // A reset can flip azan toggles/voices, offsets and silent windows; the
    // alarms armed before it keep yesterday's values until re-armed.
    _rescheduleAlarms();
    return true;
  }

  /// The settings-shaped values that live in SharedPreferences rather than in
  /// the [AppSettings] row. Kept in one place so reset and import cannot drift
  /// apart.
  Future<void> _clearPrefsBackedPreferences() async {
    try {
      await PrayerAzanSoundStore().clearAll();
    } catch (e, st) {
      AppLogger.error('SettingsNotifier', 'could not clear adhan voices: $e', st);
    }
    try {
      await AlertVolume.set(1.0);
    } catch (e, st) {
      AppLogger.error('SettingsNotifier', 'could not reset alert volume: $e', st);
    }
    try {
      final prefs = await ref.read(sharedPrefsProvider.future);
      await prefs.remove(islamicEventsEnabledKey);
    } catch (e, st) {
      AppLogger.error(
          'SettingsNotifier', 'could not reset the events toggle: $e', st);
    }
  }

  /// Apply settings imported from a transfer file («انتقال تنظیمات»).
  ///
  /// Mirrors [resetPreferences]: the incoming `onboardingCompleted` and
  /// `isPremium` are deliberately ignored, because the target device's own
  /// values for those two are already correct (a fresh install must stay on
  /// onboarding, an existing account must keep its premium grant).
  ///
  /// The file carries the [AppSettings] row only, so the per-prayer voice
  /// overrides are cleared: keeping the target device's overrides would leave
  /// prayers pointing at a voice the imported `azanSound` no longer agrees
  /// with. Returns false when the write failed.
  Future<bool> importPreferences(AppSettings next) async {
    final current = state.value ?? await future;
    final ok = await _save(next.copyWith(
      onboardingCompleted: current.onboardingCompleted,
      isPremium: current.isPremium,
    ));
    if (!ok) return false;
    try {
      await PrayerAzanSoundStore().clearAll();
    } catch (e, st) {
      AppLogger.error(
          'SettingsNotifier', 'could not clear adhan voices on import: $e', st);
    }
    // Same staleness rule as [resetPreferences]: the imported row can carry
    // different azan voices, offsets and silent windows than the armed alarms.
    _rescheduleAlarms();
    return true;
  }

  // Prayer
  Future<void> setCalcMethod(CalculationMethodOption v) async {
    await _saveWith((s) => s.copyWith(calculationMethod: v));
  }

  Future<void> setAsrMethod(AsrMethod v) async {
    await _saveWith((s) => s.copyWith(asrMethod: v));
  }

  /// زمان نماز ظهر فقط در روزهای جمعه را تغییر می‌دهد.
  /// برای بازگشت به «خودکار» مقدار `null` ارسال شود.
  Future<void> setFridayPrayerTime(DayTime? v) async {
    // _saveWith (not _save on a _current fallback): a fast tap while the row
    // is still loading must not blank every other stored field.
    await _saveWith((s) => s.copyWith(fridayPrayerTime: v));
  }

  Future<void> setHighLatitudeRule(HighLatitudeRuleOption v) async {
    await _saveWith((s) => s.copyWith(highLatitudeRule: v));
  }

  Future<void> setUseLocation(bool v) async {
    await _saveWith((s) => s.copyWith(useLocation: v));
  }

  @override
  Future<void> setManualCoords(double lat, double lng) async {
    await _saveWith(
        (s) => s.copyWith(manualLat: lat, manualLng: lng, hasLocation: true));
  }

  Future<void> setCustomFajrAngle(double v) async {
    await _saveWith((s) => s.copyWith(customFajrAngle: v));
  }

  Future<void> setCustomIshaAngle(double v) async {
    await _saveWith((s) => s.copyWith(customIshaAngle: v));
  }

  // Offsets. Every per-prayer adhan-time shift feeds reminders, the native
  // adhan alarms, the silent-before-iqama windows and the home-widget
  // payload, so each setter ends with the same debounced reschedule the
  // global offset uses (last write wins — see [_rescheduleAlarms]).
  // Sunrise counts: the sunrise window is surfaced on the home card and in
  // the widget payload, and the scheduler fingerprint covers it.
  Future<void> setFajrOffset(int v) async {
    await _saveWith((s) => s.copyWith(fajrOffset: v));
    _rescheduleAlarms();
  }

  Future<void> setSunriseOffset(int v) async {
    await _saveWith((s) => s.copyWith(sunriseOffset: v));
    _rescheduleAlarms();
  }

  Future<void> setDhuhrOffset(int v) async {
    await _saveWith((s) => s.copyWith(dhuhrOffset: v));
    _rescheduleAlarms();
  }

  Future<void> setAsrOffset(int v) async {
    await _saveWith((s) => s.copyWith(asrOffset: v));
    _rescheduleAlarms();
  }

  Future<void> setMaghribOffset(int v) async {
    await _saveWith((s) => s.copyWith(maghribOffset: v));
    _rescheduleAlarms();
  }

  Future<void> setIshaOffset(int v) async {
    await _saveWith((s) => s.copyWith(ishaOffset: v));
    _rescheduleAlarms();
  }

  Future<void> setGlobalPrayerOffset(int v) async {
    await _saveWith((s) => s.copyWith(globalPrayerOffset: v));
    _rescheduleAlarms();
  }

  /// Elevation (horizon-dip) correction for sunrise/maghrib. The PrayerTimes
  /// provider rebuilds automatically because [PrayerSettingsKey] includes it.
  Future<void> setElevationCorrection(bool v) async {
    await _saveWith((s) => s.copyWith(elevationCorrection: v));
  }

  // Notifications
  Future<void> setPrayerNotifications(bool v) async {
    await _saveWith((s) => s.copyWith(prayerNotifications: v));
  }

  Future<void> setPrayerNotifMinutes(int v) async {
    await _saveWith((s) => s.copyWith(prayerNotifMinutes: v));
  }

  Future<void> setMorningAzkarNotification(bool v) async {
    await _saveWith((s) => s.copyWith(morningAzkarNotification: v));
  }

  Future<void> setMorningAzkarTime(DayTime v) async {
    await _saveWith((s) => s.copyWith(morningAzkarTime: v));
  }

  Future<void> setEveningAzkarNotification(bool v) async {
    await _saveWith((s) => s.copyWith(eveningAzkarNotification: v));
  }

  Future<void> setEveningAzkarTime(DayTime v) async {
    await _saveWith((s) => s.copyWith(eveningAzkarTime: v));
  }

  Future<void> setQuranReminder(bool v) async {
    await _saveWith((s) => s.copyWith(quranReminder: v));
  }

  Future<void> setQuranReminderTime(DayTime v) async {
    await _saveWith((s) => s.copyWith(quranReminderTime: v));
  }

  // Silent
  Future<void> setSilentDuringPrayer(bool v) async {
    await _saveWith((s) => s.copyWith(silentDuringPrayer: v));
    _rescheduleAlarms();
  }

  Future<void> setSilentDuration(int v) async {
    await _saveWith((s) => s.copyWith(silentDuration: v));
    _rescheduleAlarms();
  }

  Future<void> setSilentBeforeIqamah(bool v) async {
    await _saveWith((s) => s.copyWith(silentBeforeIqamah: v));
    _rescheduleAlarms();
  }

  Future<void> setSilentBeforeIqamahMinutes(int v) async {
    await _saveWith((s) => s.copyWith(silentBeforeIqamahMinutes: v));
    _rescheduleAlarms();
  }

  // Daily Reminders
  Future<void> setDailyVerse(bool v) async {
    await _saveWith((s) => s.copyWith(dailyVerse: v));
  }

  Future<void> setDailyVerseTime(DayTime v) async {
    await _saveWith((s) => s.copyWith(dailyVerseTime: v));
  }

  Future<void> setDailyHadith(bool v) async {
    await _saveWith((s) => s.copyWith(dailyHadith: v));
  }

  Future<void> setDailyHadithTime(DayTime v) async {
    await _saveWith((s) => s.copyWith(dailyHadithTime: v));
  }

  Future<void> setDailyDua(bool v) async {
    await _saveWith((s) => s.copyWith(dailyDua: v));
  }

  Future<void> setDailyDuaTime(DayTime v) async {
    await _saveWith((s) => s.copyWith(dailyDuaTime: v));
  }

  // UI
  Future<void> setThemeMode(ThemeModeOption v) async {
    await _saveWith((s) => s.copyWith(themeMode: v));
  }

  Future<void> setShowArabicText(bool v) async {
    await _saveWith((s) => s.copyWith(showArabicText: v));
  }

  Future<void> setShowDaleel(bool v) async {
    await _saveWith((s) => s.copyWith(showDaleel: v));
  }

  Future<void> setLargeArabicFont(bool v) async {
    await _saveWith((s) => s.copyWith(largeArabicFont: v));
  }

  Future<void> setUse12Hour(bool v) async {
    await _saveWith((s) => s.copyWith(use12Hour: v));
  }

  // Azan
  Future<void> setAzanSound(String v) async {
    await _saveWith((s) => s.copyWith(azanSound: v));
    // Native setAlarmClock alarms bake the sound resource in at schedule time;
    // re-schedule so a sound change applies from the next adhan, not tomorrow.
    _rescheduleAlarms();
  }

  Future<void> setAzanVolume(double v) async {
    await _saveWith((s) => s.copyWith(azanVolume: v));
    // The volume is baked into the native alarm intent at schedule time;
    // re-schedule so the slider takes effect from the next adhan.
    _rescheduleAlarms();
  }

  // Hijri
  Future<void> setHijriOffset(int v) async {
    await _saveWith((s) => s.copyWith(hijriOffset: v));
  }

  // Widget

  // SettingsWriter implementation
  @override
  Future<void> setCity(String city) async {
    await _saveWith((s) => s.copyWith(city: city));
  }

  @override
  Future<void> setHasLocation(bool v) async {
    await _saveWith((s) => s.copyWith(hasLocation: v));
  }

  // Quick Actions
  Future<void> setQuickActions(List<String> v) async {
    // Reorder is only meaningful once the row exists; the write itself goes
    // through [_save] so a failure raises the same signal as every other edit
    // (this used to have its own copy of the optimistic-then-revert dance, and
    // its revert was silent).
    final current = state.value;
    if (current == null) return;
    await _save(current.copyWith(quickActions: v));
  }

  // Tafsir
  Future<void> setTafsirId(int v) async {
    await _saveWith((s) => s.copyWith(tafsirId: v));
  }

  Future<void> setFontFamily(FontFamilyOption v) async {
    await _saveWith((s) => s.copyWith(fontFamily: v));
  }

  Future<void> setFontScale(double v) async {
    // Keep both representations in sync: the theme scales via [fontScale]
    // (15px = 1.0) while the settings UI shows the absolute size [appFontSize].
    await _saveWith((s) => s.copyWith(appFontSize: v, fontScale: v / 15.0));
  }

  // Azan per prayer — reschedule native alarms so disabled prayers are
  // immediately cancelled and enabled ones are freshly scheduled.
  Future<void> setAzanEnabledForFajr(bool v) =>
      _setAzanEnabled((s) => s.copyWith(azanEnabledForFajr: v), v);

  Future<void> setAzanEnabledForDhuhr(bool v) =>
      _setAzanEnabled((s) => s.copyWith(azanEnabledForDhuhr: v), v);

  Future<void> setAzanEnabledForAsr(bool v) =>
      _setAzanEnabled((s) => s.copyWith(azanEnabledForAsr: v), v);

  Future<void> setAzanEnabledForMaghrib(bool v) =>
      _setAzanEnabled((s) => s.copyWith(azanEnabledForMaghrib: v), v);

  Future<void> setAzanEnabledForIsha(bool v) =>
      _setAzanEnabled((s) => s.copyWith(azanEnabledForIsha: v), v);

  Future<void> _setAzanEnabled(
      AppSettings Function(AppSettings) update, bool enabled) async {
    await _saveWith(update);
    if (!enabled) await AzanPlaybackService().stop();
    _rescheduleAlarms();
  }

  /// «لغو همه»: the five per-prayer adhan switches off in one write.
  ///
  /// Without this the next reschedule (fingerprint, boot, a settings edit)
  /// re-armed adhans the user had just cancelled — the master
  /// `prayerNotifications` flag alone does not reach these five.
  Future<void> disableAllAzan() async {
    await _saveWith((s) => s.copyWith(
          azanEnabledForFajr: false,
          azanEnabledForDhuhr: false,
          azanEnabledForAsr: false,
          azanEnabledForMaghrib: false,
          azanEnabledForIsha: false,
        ));
    // Never await the audio teardown: the azan channel can be slow or silent
    // (no native player, widget-test binding), and «لغو همه» must not hang on
    // it — the reminder cancellation that follows is not ordered after it.
    unawaited(AzanPlaybackService().stop());
    _rescheduleAlarms();
  }

  // Per-prayer azan voice overrides (Design-A card). The voices live in
  // SharedPreferences — see [PrayerAzanSoundStore]; an absent key inherits the
  // shared azanSound, and a change still reschedules so the native adhan
  // alarms and the scheduler fingerprint pick the new voice immediately.
  Future<void> setAzanSoundFor(PrayerSlot slot, String sound) async {
    await PrayerAzanSoundStore().set(slot, sound);
    _rescheduleAlarms();
  }

  /// Back to "inherit the shared azan voice" for one prayer.
  Future<void> clearAzanSoundFor(PrayerSlot slot) async {
    await PrayerAzanSoundStore().clear(slot);
    _rescheduleAlarms();
  }

  /// «اقامه یکسان»: one iqamah interval for all five prayers, in one settings
  /// write so the row never shows a half-applied state.
  Future<void> setIqamahOffsetsUniform(int v) async {
    await _saveWith((s) => s.copyWith(
          iqamahOffsetFajr: v,
          iqamahOffsetDhuhr: v,
          iqamahOffsetAsr: v,
          iqamahOffsetMaghrib: v,
          iqamahOffsetIsha: v,
        ));
    _rescheduleAlarms();
  }

  /// «بازنشانی» of the «اذان و اقامه» section: every adhan-time shift back to
  /// 0, every iqamah interval back to its default value, and every per-prayer
  /// voice override removed (the prayers return to the shared azanSound).
  /// The adhan ON/OFF toggles and the shared «صوت اذان» row are NOT touched.
  Future<void> resetPrayerAdhanSection() async {
    const defaults = AppSettings();
    await _saveWith((s) => s.copyWith(
          fajrOffset: 0,
          dhuhrOffset: 0,
          asrOffset: 0,
          maghribOffset: 0,
          ishaOffset: 0,
          iqamahOffsetFajr: defaults.iqamahOffsetFajr,
          iqamahOffsetDhuhr: defaults.iqamahOffsetDhuhr,
          iqamahOffsetAsr: defaults.iqamahOffsetAsr,
          iqamahOffsetMaghrib: defaults.iqamahOffsetMaghrib,
          iqamahOffsetIsha: defaults.iqamahOffsetIsha,
        ));
    await PrayerAzanSoundStore().clearAll();
    _rescheduleAlarms();
  }

  /// A burst of stepper taps (iqamah offset, silent minutes, global offset)
  /// would otherwise enqueue one full notification reconciliation per tap. Every
  /// write resets this timer, so only the LAST value in a burst reaches the
  /// scheduler; [_rescheduleAlarmsNow] reads `_current` at fire time, so the
  /// last value wins even if an earlier reconciliation is still queued.
  static const Duration _rescheduleDebounceDelay = Duration(milliseconds: 350);

  void _rescheduleAlarms() {
    _rescheduleDebounce?.cancel();
    _rescheduleDebounce = Timer(_rescheduleDebounceDelay, () {
      unawaited(_rescheduleAlarmsNow());
    });
  }

  void _cancelReschedule() => _rescheduleDebounce?.cancel();

  Future<void> _rescheduleAlarmsNow() async {
    try {
      final settings = _current;
      final prayerService = ref.read(prayerTimeServiceProvider);
      await ref.read(dailyNotificationSchedulerProvider).scheduleIfNeeded(
        prayerService: prayerService,
        settings: settings,
      );
    } catch (e) {
      AppLogger.warning('Settings', 'Native alarm reschedule failed: $e');
    }
  }

  // Custom azan path
  Future<void> setCustomAzanPath(String? v) async {
    await _saveWith((s) => s.copyWith(customAzanPath: v));
    _rescheduleAlarms();
  }

  // Accent

  /// Theme kind — stored in the accentPreset field ('gold' | 'live'). The
  /// 2026 redesign replaced accent presets with whole-app palettes; legacy
  /// stored values ('classic', 'green', …) normalize to the app default
  /// (the blue «شب» theme) on read.
  Future<void> setThemeKind(String v) async {
    await _saveWith((s) => s.copyWith(accentPreset: v));
  }

  // Iqamah offsets — re-schedule so the widget countdown, silent-mode windows
  // and post-prayer azkar use the new iqamah times immediately.
  Future<void> setIqamahOffsetFajr(int v) async {
    await _saveWith((s) => s.copyWith(iqamahOffsetFajr: v));
    _rescheduleAlarms();
  }

  Future<void> setIqamahOffsetDhuhr(int v) async {
    await _saveWith((s) => s.copyWith(iqamahOffsetDhuhr: v));
    _rescheduleAlarms();
  }

  Future<void> setIqamahOffsetAsr(int v) async {
    await _saveWith((s) => s.copyWith(iqamahOffsetAsr: v));
    _rescheduleAlarms();
  }

  Future<void> setIqamahOffsetMaghrib(int v) async {
    await _saveWith((s) => s.copyWith(iqamahOffsetMaghrib: v));
    _rescheduleAlarms();
  }

  Future<void> setIqamahOffsetIsha(int v) async {
    await _saveWith((s) => s.copyWith(iqamahOffsetIsha: v));
    _rescheduleAlarms();
  }
}

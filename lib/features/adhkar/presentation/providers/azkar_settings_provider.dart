import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/adhkar/tasbih/domain/entities/tasbih_model.dart';
import 'package:tawheeed/features/adhkar/utils/azkar_day_boundary.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

part 'azkar_settings_provider.g.dart';

/// Azkar/Tasbih user preferences: haptic feedback, sound, auto-rotate, auto-reset.
///
/// Replaces direct `SharedPreferences.getInstance()` calls in widgets so that
/// settings changes propagate reactively through the Riverpod tree.
class AzkarSettingsData {
  final bool hapticEnabled;
  final bool soundEnabled;

  /// Volume (0..1) of the tasbih click sound, independent of the device
  /// media volume.
  final double tasbihVolume;
  final bool autoRotate;
  final bool autoReset;
  final int resetHour;
  final int resetMinute;

  /// Quick tasbih mode: holding the counter counts continuously.
  final bool quickCount;

  /// How fast the counter repeats in quick mode.
  final QuickCountSpeed quickSpeed;

  const AzkarSettingsData({
    this.hapticEnabled = true,
    this.soundEnabled = true,
    this.tasbihVolume = 1.0,
    this.autoRotate = false,
    this.autoReset = true,
    this.resetHour = 0,
    this.resetMinute = 0,
    this.quickCount = false,
    this.quickSpeed = QuickCountSpeed.normal,
  });

  AzkarSettingsData copyWith({
    bool? hapticEnabled,
    bool? soundEnabled,
    double? tasbihVolume,
    bool? autoRotate,
    bool? autoReset,
    int? resetHour,
    int? resetMinute,
    bool? quickCount,
    QuickCountSpeed? quickSpeed,
  }) {
    return AzkarSettingsData(
      hapticEnabled: hapticEnabled ?? this.hapticEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      tasbihVolume: tasbihVolume ?? this.tasbihVolume,
      autoRotate: autoRotate ?? this.autoRotate,
      autoReset: autoReset ?? this.autoReset,
      resetHour: resetHour ?? this.resetHour,
      resetMinute: resetMinute ?? this.resetMinute,
      quickCount: quickCount ?? this.quickCount,
      quickSpeed: quickSpeed ?? this.quickSpeed,
    );
  }
}

@Riverpod(keepAlive: true)
class AzkarSettings extends _$AzkarSettings {
  SharedPreferences? _prefs;

  /// Resolved when the prefs load finishes. Setters await it: a toggle made
  /// while the load was in flight was both dropped (`_prefs` was still null)
  /// and reverted (the load assigns `state` wholesale).
  Completer<void> _ready = Completer<void>();

  @override
  AzkarSettingsData build() {
    _ready = Completer<void>();
    _load();
    return const AzkarSettingsData();
  }

  Future<void> _awaitReady() async {
    if (!_ready.isCompleted) await _ready.future;
  }

  Future<void> _load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      state = AzkarSettingsData(
        hapticEnabled: _prefs!.getBool('azkar_haptic') ?? true,
        soundEnabled: _prefs!.getBool('azkar_sound') ?? true,
        tasbihVolume: _prefs!.getDouble('azkar_sound_volume') ?? 1.0,
        autoRotate: _prefs!.getBool('azkar_autoRotate') ?? false,
        autoReset: _prefs!.getBool('azkar_autoReset') ?? true,
        resetHour: _prefs!.getInt('azkar_resetHour') ?? 0,
        resetMinute: _prefs!.getInt('azkar_resetMinute') ?? 0,
        quickCount: _prefs!.getBool('azkar_quickCount') ?? false,
        quickSpeed: _speedFromName(_prefs!.getString('azkar_quickSpeed')),
      );
      AzkarDayBoundary.set(state.resetHour, state.resetMinute);
    } catch (e) {
      AppLogger.warning('AzkarSettings', 'prefs load failed: $e');
    } finally {
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  Future<void> setHaptic(bool value) async {
    await _awaitReady();
    if (!ref.mounted) return;
    state = state.copyWith(hapticEnabled: value);
    await _prefs?.setBool('azkar_haptic', value);
  }

  Future<void> setSound(bool value) async {
    await _awaitReady();
    if (!ref.mounted) return;
    state = state.copyWith(soundEnabled: value);
    await _prefs?.setBool('azkar_sound', value);
  }

  Future<void> setTasbihVolume(double value) async {
    await _awaitReady();
    if (!ref.mounted) return;
    state = state.copyWith(tasbihVolume: value);
    await _prefs?.setDouble('azkar_sound_volume', value);
  }

  Future<void> setAutoRotate(bool value) async {
    await _awaitReady();
    if (!ref.mounted) return;
    state = state.copyWith(autoRotate: value);
    await _prefs?.setBool('azkar_autoRotate', value);
  }

  Future<void> setAutoReset(bool value) async {
    await _awaitReady();
    if (!ref.mounted) return;
    state = state.copyWith(autoReset: value);
    await _prefs?.setBool('azkar_autoReset', value);
  }

  Future<void> setResetTime(int hour, int minute) async {
    await _awaitReady();
    if (!ref.mounted) return;
    state = state.copyWith(resetHour: hour, resetMinute: minute);
    await _prefs?.setInt('azkar_resetHour', hour);
    await _prefs?.setInt('azkar_resetMinute', minute);
    AzkarDayBoundary.set(hour, minute);
  }

  Future<void> setQuickCount(bool value) async {
    await _awaitReady();
    if (!ref.mounted) return;
    state = state.copyWith(quickCount: value);
    await _prefs?.setBool('azkar_quickCount', value);
  }

  Future<void> setQuickSpeed(QuickCountSpeed value) async {
    await _awaitReady();
    if (!ref.mounted) return;
    state = state.copyWith(quickSpeed: value);
    await _prefs?.setString('azkar_quickSpeed', value.name);
  }

  static QuickCountSpeed _speedFromName(String? name) {
    return QuickCountSpeed.values.firstWhere(
      (s) => s.name == name,
      orElse: () => QuickCountSpeed.normal,
    );
  }
}

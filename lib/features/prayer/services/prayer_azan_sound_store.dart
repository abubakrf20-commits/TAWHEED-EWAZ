import 'package:shared_preferences/shared_preferences.dart';

/// Per-prayer azan sound overrides (Design-A «اذان و اقامه» card).
///
/// Each of the five prayers may carry its OWN azan voice; a prayer with no
/// override INHERITS the shared «صوت اذان» row (`AppSettings.azanSound`), so
/// fresh installs and never-touched prayers behave exactly as before and no
/// stored value is ever overwritten by a default.
///
/// Stored in SharedPreferences — like `silent_after_iqamah_minutes` —
/// deliberately NOT in Drift: a new settings column would require a schema
/// migration plus generated-code regen, while these keys ride the backup's
/// `preferences.json` unharmed. Keys are `azan_sound_<slot>`; values are the
/// shared sound keys (`kamel` / `takbir` / `custom`) so the native resolver
/// and [AzanPlaybackService] need no new token. The «custom» FILE stays the
/// shared `customAzanPath` (one picked file, selectable per prayer).
enum PrayerSlot { fajr, dhuhr, asr, maghrib, isha }

class PrayerAzanSoundStore {
  PrayerAzanSoundStore._();

  static final PrayerAzanSoundStore instance = PrayerAzanSoundStore._();

  factory PrayerAzanSoundStore() => instance;

  static const _prefix = 'azan_sound_';

  static String keyFor(PrayerSlot slot) => '$_prefix${slot.name}';

  /// The raw override, or null when the prayer inherits the shared voice.
  Future<String?> get(PrayerSlot slot) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyFor(slot));
  }

  /// Every slot that carries an explicit override (absent keys = inherit).
  Future<Map<PrayerSlot, String>> readOverrides() async {
    final prefs = await SharedPreferences.getInstance();
    final out = <PrayerSlot, String>{};
    for (final slot in PrayerSlot.values) {
      final v = prefs.getString(keyFor(slot));
      if (v != null && v.isNotEmpty) out[slot] = v;
    }
    return out;
  }

  /// The voice a native adhan alarm for [slot] should bake: the prayer's own
  /// override when present, otherwise the shared voice.
  static String effectiveFor(
    PrayerSlot slot,
    Map<PrayerSlot, String> overrides,
    String sharedSound,
  ) =>
      overrides[slot] ?? sharedSound;

  Future<void> set(PrayerSlot slot, String soundKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyFor(slot), soundKey);
  }

  /// Back to "inherit the shared azan voice".
  Future<void> clear(PrayerSlot slot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyFor(slot));
  }

  /// Removes every override (the «بازنشانی» bulk action's sound part).
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final slot in PrayerSlot.values) {
      await prefs.remove(keyFor(slot));
    }
  }
}

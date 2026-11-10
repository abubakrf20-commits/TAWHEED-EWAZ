import 'package:flutter/foundation.dart';

/// What a sound is FOR. The settings page groups its controls by this, so a
/// new sound lands in the right card without the page learning about it.
enum SoundGroup { interactive, alert }

/// One sound the app ships, named once.
///
/// Before this file the same two files were spelled out in six places
/// (`sounds/tick.wav` in the tasbih counter, the azkar tab and the settings
/// preview; `sounds/notif.ogg` in the reminder editor, the sound picker, the
/// pomodoro beeper and the settings preview), each with its own preview key.
/// Renaming an asset or adding a third tone meant finding every copy, and a
/// preview key that drifted from the asset it plays is invisible until someone
/// taps it.
///
/// [key] is the stable identity: it is what `SoundPreviewService` toggles on
/// and what a settings row addresses, so it must never be derived from a file
/// path (a file can be re-encoded; a key cannot move).
@immutable
class AppSound {
  const AppSound({
    required this.key,
    required this.label,
    required this.group,
    required this.asset,
  }) : assert(asset != '', 'a sound without an asset cannot be played');

  /// Stable identity, namespaced (`tasbih.tick`). Used as the preview key.
  final String key;

  /// Persian name shown wherever the sound can be heard or chosen.
  final String label;

  /// The card this sound belongs to on the settings page.
  final SoundGroup group;

  /// Bundled path in the form `AssetSource` wants it: relative to `assets/`,
  /// i.e. `sounds/tick.wav` for `assets/sounds/tick.wav`.
  final String asset;

  @override
  bool operator ==(Object other) => other is AppSound && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'AppSound($key → $asset)';
}

/// The app's bundled sounds, in one place.
///
/// The adhan voices are deliberately absent: they are not assets. They ship as
/// Android `res/raw` files that the native player resolves by name
/// (`AzanPlaybackService._bundledAzanPath`), so they have no `AssetSource` and
/// registering them here would invite a preview that can only fail. The
/// voice list stays with the page that owns the adhan.
abstract final class SoundRegistry {
  /// The keys as plain constants: a `const` field of an object is not a
  /// constant expression, so a screen that needs its preview key in a
  /// `static const` would otherwise have to repeat the literal.
  static const String tickKey = 'tasbih.tick';
  static const String reminderKey = 'alert.notif';
  static const String raceStartKey = 'alert.raceStart';

  /// The tasbih/adhkar click. Short, low-latency, played from an [AudioPool]
  /// by `ClickSoundPlayer` — never by the shared preview player.
  static const AppSound tick = AppSound(
    key: tickKey,
    label: 'کلیک تسبیح',
    group: SoundGroup.interactive,
    asset: 'sounds/tick.wav',
  );

  /// The reminder, pomodoro and in-app notification tone.
  static const AppSound reminder = AppSound(
    key: reminderKey,
    label: 'صدای اعلان و یادآور',
    group: SoundGroup.alert,
    asset: 'sounds/notif.ogg',
  );

  /// The double beep that marks the start of a countdown (race) round.
  static const AppSound raceStart = AppSound(
    key: raceStartKey,
    label: 'شروع دور شمارش',
    group: SoundGroup.alert,
    asset: 'sounds/race_start.wav',
  );

  /// Every registered sound. Adding a tone is one entry here.
  static const List<AppSound> all = <AppSound>[tick, reminder, raceStart];

  /// The sound registered under [key], or null for an unregistered preview.
  static AppSound? byKey(String key) {
    for (final sound in all) {
      if (sound.key == key) return sound;
    }
    return null;
  }

  /// The sounds of one settings card, in registry order.
  static List<AppSound> inGroup(SoundGroup group) =>
      all.where((sound) => sound.group == group).toList(growable: false);
}

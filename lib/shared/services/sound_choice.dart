/// Wire format for a notification/reminder sound choice.
///
/// One string travels through Drift, SharedPreferences, backups and the native
/// alarm JSON, so the encoding is deliberately boring:
///
/// * `silent` — no sound at all
/// * `default` — the system default notification tone
/// * a raw-resource name (`notif`, `ios17`, …) — a bundled app tone
/// * `custom:<absolute path>` — a file the user picked from the phone
/// * `system:<kind>:<uri>` — one of the phone's own tones, where `kind` is
///   `notification`, `alarm` or `ringtone` and `<uri>` is a `content://` URI.
///
/// The URI always contains its own colons, so parsing splits on the FIRST
/// colon after `system:` only.
class SoundChoice {
  SoundChoice._();

  static const String silent = 'silent';
  static const String systemDefault = 'default';
  static const String appNotification = 'notif';

  static const String kindNotification = 'notification';
  static const String kindAlarm = 'alarm';
  static const String kindRingtone = 'ringtone';

  static bool isSystem(String wire) => wire.startsWith('system:');

  static bool isCustom(String wire) => wire.startsWith('custom:');

  /// The saved path of a `custom:` choice, or null for anything else.
  static String? customPath(String wire) =>
      isCustom(wire) && wire.length > 7 ? wire.substring(7) : null;

  /// `notification` / `alarm` / `ringtone` for a `system:` choice.
  static String? systemKind(String wire) {
    if (!isSystem(wire)) return null;
    final rest = wire.substring(7);
    final split = rest.indexOf(':');
    if (split <= 0) return null;
    return rest.substring(0, split);
  }

  /// The `content://` URI of a `system:` choice.
  static String? systemUri(String wire) {
    if (!isSystem(wire)) return null;
    final rest = wire.substring(7);
    final split = rest.indexOf(':');
    if (split <= 0 || split + 1 >= rest.length) return null;
    return rest.substring(split + 1);
  }

  static bool isAlarm(String wire) => systemKind(wire) == kindAlarm;

  static String system(String kind, String uri) => 'system:$kind:$uri';

  /// A human label that needs no catalog lookup (used before the phone's tone
  /// list has loaded).
  static String roughLabel(String wire) {
    if (wire == silent) return 'بی‌صدا';
    if (wire == systemDefault) return 'صدای پیش‌فرض سیستم';
    if (isCustom(wire)) return 'فایل شخصی از گوشی';
    switch (systemKind(wire)) {
      case kindAlarm:
        return 'آلارم گوشی';
      case kindRingtone:
        return 'زنگ گوشی';
      case kindNotification:
        return 'زنگ اعلان گوشی';
    }
    return wire;
  }
}

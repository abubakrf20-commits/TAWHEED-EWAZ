import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Wraps the native `com.tawheeed/settings` MethodChannel plus the
/// `flutter_local_notifications` permission API so the rest of the app can
/// request runtime permissions and create notification channels in one place.
///
/// These calls are required before any scheduling works on Android 12+:
///   - notifications permission (Android 13+)
///   - SCHEDULE_EXACT_ALARM permission (Android 12+)
///   - battery-optimization exemption
///   - the Android notification channels themselves
class PermissionService {
  PermissionService._();
  static final _instance = PermissionService._();
  factory PermissionService() => _instance;

  static const _channel = MethodChannel('com.tawheeed/settings');

  Future<bool> _check(String permission) async {
    try {
      final result = await _channel.invokeMethod('checkPermission', {
        'permission': permission,
      });
      return result == true;
    } catch (e) {
      AppLogger.warning('PermissionService', 'check $permission failed: $e');
      return false;
    }
  }

  Future<void> _request(String permission) async {
    try {
      await _channel.invokeMethod('requestPermission', {
        'permission': permission,
      });
    } catch (e) {
      AppLogger.warning('PermissionService', 'request $permission failed: $e');
    }
  }

  /// Creates the Android notification channels referenced by [NotificationService].
  /// Must run before any [zonedSchedule]/[show] call.
  Future<void> createNotificationChannels() async {
    try {
      await _channel.invokeMethod('createNotificationChannels');
    } catch (e) {
      AppLogger.warning(
          'PermissionService', 'createNotificationChannels failed: $e');
    }
  }

  Future<bool> isNotificationGranted() => _check('notifications');
  Future<bool> isExactAlarmGranted() => _check('exactAlarm');
  Future<bool> isLocationGranted() => _check('location');

  /// Whether the app is exempt from Android's battery optimization (Doze)
  /// restrictions. When false, background alarms can be delayed or dropped.
  Future<bool> isBatteryOptimizationIgnored() async =>
      (await batteryOptimizationStatus()) ?? false;

  /// Tri-state variant for UI that must not claim «restricted» when the
  /// channel could not answer (tests, early boot, non-Android targets).
  Future<bool?> batteryOptimizationStatus() async {
    try {
      final result = await _channel.invokeMethod('checkPermission', {
        'permission': 'batteryOptimization',
      });
      return result == true;
    } catch (e) {
      AppLogger.warning(
          'PermissionService', 'check batteryOptimization failed: $e');
      return null;
    }
  }

  /// Device manufacturer (lowercase, e.g. 'xiaomi', 'samsung', 'huawei') —
  /// Audit 4.7: the diagnostics page uses it to put the matching OEM
  /// battery-autostart guide first. Empty string when unavailable.
  Future<String> deviceManufacturer() async {
    try {
      final m = await _channel.invokeMethod<String>('deviceManufacturer');
      return (m ?? '').toLowerCase();
    } catch (e) {
      AppLogger.warning('PermissionService', 'deviceManufacturer failed: $e');
      return '';
    }
  }

  /// Whether the app may override the Do-Not-Disturb policy (needed for
  /// adhan/reminder sounds to play while DND is active).
  Future<bool> isDndAccessGranted() => _check('dnd');

  /// Opens the system's battery-optimization list so the user can pick
  /// «توحید» and allow unrestricted background activity.
  Future<void> openBatteryOptimizationSettings() =>
      _request('batteryOptimization');

  /// Opens the system screen for granting notification-policy (DND) access.
  Future<void> openDndSettings() => _request('dnd');

  /// Requests the Android 13+ notifications permission via the in-app dialog.
  /// Returns the resulting grant state.
  Future<bool> requestNotificationPermission() async {
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      final android = plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return false;
      return await android.requestNotificationsPermission() ?? false;
    } catch (e) {
      AppLogger.warning(
          'PermissionService', 'requestNotificationPermission failed: $e');
      return false;
    }
  }

  Future<void> requestExactAlarm() => _request('exactAlarm');

  /// Olson zone id of the device (e.g. Asia/Tehran) from the native settings
  /// channel. Null when the channel is unavailable (tests, background
  /// isolate without the activity) — callers must fall back.
  Future<String?> deviceTimezoneName() async {
    try {
      final result = await _channel
          .invokeMethod<String>('getDeviceTimezone')
          .timeout(const Duration(seconds: 2));
      final name = result?.trim();
      return (name == null || name.isEmpty) ? null : name;
    } catch (e) {
      AppLogger.warning('PermissionService', 'getDeviceTimezone failed: $e');
      return null;
    }
  }

  /// Reads-and-clears the native `needs_reschedule` flag set by BootReceiver
  /// after boot/update/clock/timezone changes. False when unavailable.
  Future<bool> consumeNeedsReschedule() async {
    try {
      final result = await _channel
          .invokeMethod<bool>('consumeNeedsReschedule')
          .timeout(const Duration(seconds: 2));
      return result == true;
    } catch (e) {
      AppLogger.warning(
          'PermissionService', 'consumeNeedsReschedule failed: $e');
      return false;
    }
  }

  /// Ensures SCHEDULE_EXACT_ALARM permission is granted. Uses the plugin's
  /// official request API as well as the native settings channel so Android
  /// 12–14 devices refresh the permission state correctly after returning.
  ///
  /// When [force] is false (passive calls like app-resume), the system dialog
  /// is shown at most once per 24h so a denying user is not spammed on every
  /// resume; explicit user taps (diagnostics fix button, enabling a reminder)
  /// must pass force: true. Always refreshes the cached grant state.
  Future<bool> ensureExactAlarmPermission({bool force = false}) async {
    try {
      if (await isExactAlarmGranted()) return true;

      if (!force) {
        final prefs = await SharedPreferences.getInstance();
        final lastPrompt = prefs.getInt('exact_alarm_last_prompt_ms') ?? 0;
        final elapsed = DateTime.now().millisecondsSinceEpoch - lastPrompt;
        if (elapsed < const Duration(hours: 24).inMilliseconds) {
          AppLogger.info('PermissionService',
              'Exact alarm prompt on cooldown — skipping auto-request.');
          return false;
        }
      }

      final plugin = FlutterLocalNotificationsPlugin();
      final android = plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        await android.requestExactAlarmsPermission();
      } else {
        await requestExactAlarm();
      }

      final granted = await isExactAlarmGranted();
      // Phase-1 audit fix: the cooldown stamp used to be written BEFORE
      // reading the result, so a denial (or a user who closed the dialog)
      // locked out the next prompt for 24h — including a user who changed
      // their mind minutes later. Stamp only on a GRANT or on an explicit
      // retry-worthy interaction; a denial leaves the cooldown open so a
      // later passive call can ask again.
      if (granted) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('exact_alarm_last_prompt_ms',
              DateTime.now().millisecondsSinceEpoch);
        } catch (e) {
          AppLogger.warning(
              'PermissionService', 'exact-alarm stamp failed: $e');
        }
      }
      if (!granted) {
        AppLogger.warning('PermissionService',
            'Exact alarm permission not granted - notifications may be delayed.');
      }
      return granted;
    } catch (e, st) {
      AppLogger.error(
          'PermissionService', 'ensureExactAlarmPermission failed: $e', st);
      return false;
    }
  }

  /// Check if GPS/location services are enabled on the device.
  Future<bool> isGpsEnabled() async {
    try {
      final result = await _channel.invokeMethod('checkGpsEnabled');
      return result == true;
    } catch (e) {
      AppLogger.warning('PermissionService', 'checkGpsEnabled failed: $e');
      return false;
    }
  }

  /// Open the device's location settings screen.
  Future<void> openLocationSettings() async {
    try {
      await _channel.invokeMethod('openLocationSettings');
    } catch (e) {
      AppLogger.warning('PermissionService', 'openLocationSettings failed: $e');
    }
  }

  /// Opens the app's system permission settings so the user can grant
  /// location access from there.
  Future<void> requestLocationPermission() => _request('location');

  /// Runs the first-launch permission flow. Non-blocking and guarded: it only
  /// prompts for the OS settings pages once per install (tracked in
  /// SharedPreferences) so we never spam the user with redirects.
  Future<void> requestRuntimePermissions() async {
    final prefs = await SharedPreferences.getInstance();

    await createNotificationChannels();

    final granted = await isNotificationGranted();
    final notifShown = prefs.getBool('notification_perm_shown') ?? false;
    // PHASE-1 FIX: the flag was read but never gated the request — a user
    // who denied (in onboarding or earlier) was re-prompted on every cold
    // start, and onboarding's own prompt double-fired on the first shell
    // boot. Prompt exactly once per install; later revokes are recovered
    // only through the explicit paths (settings/diagnostics screens).
    if (!granted && !notifShown) {
      await requestNotificationPermission();
      await prefs.setBool('notification_perm_shown', true);
    } else if (granted && !notifShown) {
      // Granted without a recorded prompt (pre-existing grant) — just record
      // it so the branch above never fires for this install.
      await prefs.setBool('notification_perm_shown', true);
    }

    // Exact-alarm goes through the 24h-cooldown flow (no once-per-install
    // skip flag anymore): a denying user is re-prompted at most daily, and
    // the grant state is refreshed every launch for the diagnostics screen.
    await ensureExactAlarmPermission();

    // Battery-optimization exemption is intentionally NOT auto-prompted: the
    // REQUEST_IGNORE_BATTERY_OPTIMIZATIONS permission is Play-Store restricted.
    // Users are guided to the system settings via the in-app battery screen.
  }
}

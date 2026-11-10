import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// In-app alert volume (0..1) stored in SharedPreferences, applied to app
/// sounds (pomodoro beep, reminder previews) so their loudness is controlled
/// from inside the app instead of following the device media volume alone.
class AlertVolume {
  AlertVolume._();

  static const _key = 'sound_alert_volume';

  static Future<double> get() async {
    try {
      final p = await SharedPreferences.getInstance();
      return (p.getDouble(_key) ?? 1.0).clamp(0.0, 1.0);
    } catch (_) {
      AppLogger.warning('alert_volume', 'operation failed');
      return 1.0;
    }
  }

  static Future<void> set(double value) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setDouble(_key, value.clamp(0.0, 1.0));
    } catch (_) {
      AppLogger.warning('alert_volume', 'operation failed');
    }
  }
}

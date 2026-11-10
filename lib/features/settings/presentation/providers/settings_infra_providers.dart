import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/shared/services/daily_notification_scheduler.dart';
import 'package:tawheeed/shared/services/notification_service.dart';
import 'package:tawheeed/shared/utils/alert_volume.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Infrastructure singletons exposed as plain providers so tests can inject a
/// fake. In production they return the existing app singletons.
///
/// Kept in their own library (not inside the notification notifier) because the
/// canonical [Settings] notifier also needs the scheduler for its debounced
/// reschedule side effect, and a cross-import between the two notifiers would
/// be a needless cycle.
final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());

final dailyNotificationSchedulerProvider =
    Provider<DailyNotificationScheduler>((ref) => DailyNotificationScheduler());

/// SharedPreferences key backing the Islamic-events reminder toggle. Stored
/// outside [AppSettings] to avoid a Drift schema migration for this flag.
/// Public so the daily schedule fingerprint can observe it.
///
/// Declared here, not in the notification notifier, because the canonical
/// [Settings] notifier has to clear it on reset — and that would be the
/// notifier-to-notifier cycle this library exists to avoid.
const String islamicEventsEnabledKey = 'notif_islamic_events_enabled';

/// In-app alert volume (0..1) as a Riverpod value instead of a widget-local
/// `setState`, so the settings slider, the pomodoro beep and the reminder
/// previews can all observe one number and tests can drive it directly.
///
/// Persistence still lives in [AlertVolume]; this only fronts it.
class AlertVolumeNotifier extends Notifier<double> {
  /// Resolved when the stored value has been read. [set] awaits it: the load
  /// assigns `state` wholesale, so a drag made while the read was in flight
  /// snapped back to the old volume while the new value was persisted.
  Completer<void> _ready = Completer<void>();

  @override
  double build() {
    _ready = Completer<void>();
    _load();
    return 1.0;
  }

  Future<void> _awaitReady() async {
    if (!_ready.isCompleted) await _ready.future;
  }

  Future<void> _load() async {
    try {
      final v = await AlertVolume.get();
      if (ref.mounted) state = v;
    } catch (e) {
      AppLogger.warning('AlertVolume', 'load failed: $e');
    } finally {
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  Future<void> set(double value) async {
    await _awaitReady();
    if (!ref.mounted) return;
    final v = value.clamp(0.0, 1.0);
    state = v;
    await AlertVolume.set(v);
  }
}

final alertVolumeProvider =
    NotifierProvider<AlertVolumeNotifier, double>(AlertVolumeNotifier.new);

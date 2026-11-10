import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/settings/data/daos/settings_dao.dart';
import 'package:tawheeed/features/settings/data/datasources/settings_drift_datasource.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/prayer/services/prayer_time_service.dart';
import 'package:tawheeed/features/prayer/services/islamic_events_service.dart';
import 'package:tawheeed/features/prayer/data/datasources/prayer_local_datasource.dart';
import 'package:tawheeed/features/prayer/data/repositories/prayer_repository_impl.dart';
import 'package:tawheeed/shared/services/daily_notification_scheduler.dart';
import 'package:tawheeed/shared/services/notification_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

const _prayerSyncTask = 'prayerSync';
const _dailyRefreshTask = 'dailyRefresh';
const _azanCheckTask = 'azanCheck';
const _hourlyNotifCheckTask = 'hourlyNotifCheck';
const _nativeBackgroundChannel =
    MethodChannel('com.tawheeed/native_background');

@pragma('vm:entry-point')
Future<void> nativeBackgroundCallbackDispatcher() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  // Audit 7.6: the background isolate has NO root-zone error handler, so
  // an uncaught async error (timer, microtask) would crash the isolate
  // before 'completed' is reported and WorkManager would retry blindly.
  // Route those errors to the same log file the UI isolate uses.
  PlatformDispatcher.instance.onError = (e, st) {
    AppLogger.error('BackgroundScheduler', 'uncaught isolate error: $e', st);
    return true;
  };

  const channel = MethodChannel('com.tawheeed/native_background');
  channel.setMethodCallHandler((call) async {
    if (call.method == 'runTask') {
      final task = call.arguments as String;
      final success = await BackgroundScheduler.executeTask(task);
      await channel.invokeMethod('completed', {'success': success});
    }
    return null;
  });
  await channel.invokeMethod('ready');
}

class BackgroundScheduler {
  BackgroundScheduler._();
  static final _instance = BackgroundScheduler._();
  factory BackgroundScheduler() => _instance;

  static bool _isRescheduling = false;

  static Future<void> initialize() async {
    final callback = PluginUtilities.getCallbackHandle(
      nativeBackgroundCallbackDispatcher,
    );
    if (callback == null) {
      throw StateError('Native background callback handle is unavailable');
    }
    await _nativeBackgroundChannel.invokeMethod('registerCallback', {
      'callbackHandle': callback.toRawHandle(),
    });
  }

  static Future<bool> executeTask(String task) async {
    try {
      switch (task) {
        case _prayerSyncTask:
          await _handlePrayerSync();
        case _dailyRefreshTask:
          await _handleDailyRefresh();
        case _azanCheckTask:
          await _handleAzanCheck();
        case _hourlyNotifCheckTask:
          await _handleHourlyNotifCheck();
        default:
          AppLogger.warning('BackgroundScheduler', 'Unknown task "$task"');
      }
      return true;
    } catch (e, st) {
      AppLogger.error('BackgroundScheduler', e, st);
      return false;
    }
  }

  static Future<void> _handlePrayerSync() async {
    AppLogger.info('BackgroundScheduler', 'Prayer sync started');
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCalc = prefs.getString('last_calculation_time');
      if (lastCalc != null) {
        final calcTime = DateTime.tryParse(lastCalc);
        if (calcTime != null) {
          final now = DateTime.now();
          if (now.difference(calcTime).inHours > 24) {
            await prefs.setBool('needs_refresh', true);
          }
        }
      }
      await _rescheduleNotificationsInBackground();
    } catch (e) {
      AppLogger.error('BackgroundScheduler._handlePrayerSync', e);
    }
  }

  static Future<void> _handleDailyRefresh() async {
    AppLogger.info('BackgroundScheduler', 'Daily refresh started');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('daily_content_stale', true);
      await _rescheduleNotificationsInBackground();
    } catch (e) {
      AppLogger.error('BackgroundScheduler._handleDailyRefresh', e);
    }
  }

  /// Loads settings + prayer times directly from storage (no Riverpod, since
  /// this runs in a background isolate) and re-schedules every notification
  /// category. Uses its own DB connection to avoid conflicts with the main isolate.
  ///
  /// Guards the whole operation behind [DailyNotificationScheduler]'s daily
  /// fingerprint, so the 6-hour / 24-hour periodic tasks only perform a full
  /// re-schedule when the date, timezone or notification settings changed —
  /// otherwise they exit early and save battery.
  static Future<void> _rescheduleNotificationsInBackground() async {
    if (_isRescheduling) return;
    _isRescheduling = true;
    AppDatabase? db;
    try {
      db = AppDatabase();
      final dataSource = SettingsDriftDataSource(SettingsDao(db));
      final AppSettings settings = (await dataSource.load()).toEntity();

      final scheduler = DailyNotificationScheduler();
      await scheduler.init();

      await NotificationService().init();

      // Always call through to scheduleIfNeeded: on the daily-fingerprint
      // short-circuit path it still reconciles the daily آیه/حدیث/دعا/قرآن,
      // adhkar and today's prayer/post-prayer/pre-adhan reminders, so a
      // time-sensitive change is applied even when the schedule fingerprint
      // itself did not change. Without this the 7-day daily-content window can
      // silently expire when the app is not opened for a while.
      await scheduler.scheduleIfNeeded(
        prayerService: PrayerTimeService(
          PrayerRepositoryImpl(
              PrayerLocalDataSource(SharedPreferences.getInstance())),
        ),
        settings: settings,
      );

      // ختم قرآن: یادآوری مستقل که از صفحه ختم تنظیم می‌شود.
      await NotificationService().syncKhatmReminder();

      // مناسبت‌های اسلامی: فقط اگر سوییچ اعلان مناسبت‌ها فعال باشد.
      final prefs = await SharedPreferences.getInstance();
      final eventsEnabled =
          prefs.getBool('notif_islamic_events_enabled') ?? true;
      if (eventsEnabled) {
        await NotificationService().scheduleMonthlyIslamicEvents(
          IslamicEventsService.upcomingWithDates(offset: settings.hijriOffset),
        );
      } else {
        await NotificationService().cancelIslamicEventNotifications();
      }
      AppLogger.success(
          'BackgroundScheduler', 'Notifications re-scheduled successfully');
    } catch (e, st) {
      AppLogger.error(
          'BackgroundScheduler._rescheduleNotificationsInBackground', e, st);
    } finally {
      await db?.close();
      _isRescheduling = false;
    }
  }

  static Future<void> _handleAzanCheck() async {
    AppLogger.info('BackgroundScheduler', 'Azan check started');
    try {
      await _rescheduleNotificationsInBackground();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_bg_check', DateTime.now().toIso8601String());
    } catch (e) {
      AppLogger.error('BackgroundScheduler._handleAzanCheck', e);
    }
  }

  static Future<void> _handleHourlyNotifCheck() async {
    AppLogger.info('BackgroundScheduler', 'Hourly notification check started');
    try {
      await _rescheduleNotificationsInBackground();
      AppLogger.success(
          'BackgroundScheduler', 'Hourly notification check completed');
    } catch (e) {
      AppLogger.error('BackgroundScheduler._handleHourlyNotifCheck', e);
    }
  }

  Future<void> enqueuePrayerSync() async {
    await _nativeBackgroundChannel.invokeMethod('enqueueOneOff', {
      'task': _prayerSyncTask,
      'delayMillis': 0,
      'replace': true,
    });
  }

  Future<void> enqueueHourlyNotifCheck() async {
    await _nativeBackgroundChannel.invokeMethod('enqueuePeriodic', {
      'task': _hourlyNotifCheckTask,
      'frequencyHours': 6,
      'initialDelayMillis': 0,
      'keep': false,
    });
  }

  Future<void> scheduleDailyRefresh({required Duration initialDelay}) async {
    await _nativeBackgroundChannel.invokeMethod('enqueuePeriodic', {
      'task': _dailyRefreshTask,
      'frequencyHours': 24,
      'initialDelayMillis': initialDelay.inMilliseconds,
      'keep': true,
    });
  }

  Future<void> enqueueAzanCheck() async {
    await _nativeBackgroundChannel.invokeMethod('enqueueOneOff', {
      'task': _azanCheckTask,
      'delayMillis': const Duration(seconds: 30).inMilliseconds,
      'replace': true,
    });
  }

  Future<void> cancelAll() async {
    await _nativeBackgroundChannel.invokeMethod('cancelAll');
  }
}

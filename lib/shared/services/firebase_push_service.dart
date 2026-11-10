import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:tawheeed/core/services/permission_service.dart';
import 'package:tawheeed/shared/services/notification_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// FCM (Firebase Cloud Messaging) wrapper:
/// - subscribes every install to the `all` broadcast topic,
/// - surfaces foreground push messages as local notifications.
///
/// Always safe to call: when Firebase is not configured the app simply skips
/// push without ever throwing into the boot sequence.
class FirebasePushService {
  static final FirebasePushService _instance = FirebasePushService._();
  factory FirebasePushService() => _instance;
  FirebasePushService._();

  static const String broadcastTopic = 'all';
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    if (Firebase.apps.isEmpty) {
      AppLogger.info('Push', 'Firebase not configured — push disabled');
      return;
    }
    _initialized = true;
    try {
      final messaging = FirebaseMessaging.instance;

      if (!kIsWeb) {
        // PHASE-1 FIX: the system POST_NOTIFICATIONS dialog must never be
        // raised from here — this init runs on a timer shortly after launch
        // with no UI rationale (the onboarding step + PermissionService own
        // the request). Only proceed to token fetch when already granted;
        // the token itself is harmless to fetch either way, but subscribing
        // is pointless without display permission.
        final granted = await PermissionService().isNotificationGranted();
        if (!granted) {
          AppLogger.info(
              'Push', 'Notifications not granted — skipping FCM permission.');
          return;
        }
      }
      // PHASE-1 FIX: both calls are network-bound and used to run on the
      // startup critical path — timeout so a dead network can never hang
      // this (now deferred) init chain.
      final token =
          await messaging.getToken().timeout(const Duration(seconds: 10));
      final preview = token == null
          ? 'null'
          : token.substring(0, token.length > 12 ? 12 : token.length);
      // Phase-1 audit: a credential fragment must never reach the persisted
      // (shareable) log file — debug console only.
      AppLogger.debug('Push', 'FCM token: $preview…');

      await messaging
          .subscribeToTopic(broadcastTopic)
          .timeout(const Duration(seconds: 10));

      // Foreground messages: the OS already shows background ones.
      FirebaseMessaging.onMessage.listen((message) {
        final title =
            message.notification?.title ?? message.data['title'] ?? 'توحید';
        final body = message.notification?.body ?? message.data['body'] ?? '';
        NotificationService().showLocalNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: title,
          body: body,
          bigText: body,
          sound: true,
        );
      });

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        AppLogger.info(
            'Push', 'Opened via notification: ${message.notification?.title}');
      });

      messaging.onTokenRefresh.listen((refreshed) async {
        try {
          await messaging.subscribeToTopic(broadcastTopic);
          AppLogger.info('Push', 'FCM token refreshed');
        } catch (e, st) {
          AppLogger.error('Push', 're-subscribe failed: $e', st);
        }
      });
    } catch (e, st) {
      AppLogger.error('Push', 'init failed: $e', st);
    }
  }
}

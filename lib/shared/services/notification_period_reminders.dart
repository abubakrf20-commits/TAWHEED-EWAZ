part of 'notification_service.dart';

/// Period (دوره ماهانه) reminders: an upcoming-period notice a fixed number of
/// days before the predicted start, and a ghusl reminder the day after the
/// predicted end. Scheduling logic lives in the period provider (it owns the
/// prediction); this mixin only owns delivery through the shared exact path.
mixin _NotificationPeriodReminders {
  NotificationService get service;

  AndroidNotificationDetails get _periodChannel =>
      const AndroidNotificationDetails(
        'period_reminders_v1',
        'یادآوری دوره ماهانه',
        channelDescription: 'یادآوری نزدیک شدن پریود و غسل پس از پاکی',
        importance: Importance.high,
        icon: '@drawable/ic_notification',
        largeIcon: DrawableResourceAndroidBitmap('ic_notification_logo'),
        sound: RawResourceAndroidNotificationSound('notif'),
        color: NotificationService._brandColor,
        visibility: NotificationService._visible,
      );

  /// Arms the period reminders. Every fire date must be in the future —
  /// dates already past are silently skipped by [_scheduleNotification].
  Future<void> schedulePeriodReminders({
    required DateTime upcomingAt,
    required String upcomingBody,
    DateTime? ghuslAt,
    String? ghuslBody,
    DateTime? startAt,
    String? startBody,
    DateTime? fertileAt,
    String? fertileBody,
  }) async {
    try {
      await service._scheduleNotification(
        NotificationIds.periodUpcoming,
        'یادآوری دوره',
        upcomingBody,
        upcomingAt,
        _periodChannel,
        payload: 'period_upcoming',
      );
      if (ghuslAt != null && ghuslBody != null) {
        await service._scheduleNotification(
          NotificationIds.periodGhusl,
          'یادآوری غسل',
          ghuslBody,
          ghuslAt,
          _periodChannel,
          payload: 'period_ghusl',
        );
      } else {
        // No active-bleeding ghusl yet — cancel any stale reminder.
        await service.cancel(NotificationIds.periodGhusl);
      }
      if (startAt != null && startBody != null) {
        await service._scheduleNotification(
          NotificationIds.periodStart,
          'شروع دوره',
          startBody,
          startAt,
          _periodChannel,
          payload: 'period_start',
        );
      }
      if (fertileAt != null && fertileBody != null) {
        await service._scheduleNotification(
          NotificationIds.periodFertile,
          'پنجرهٔ باروری',
          fertileBody,
          fertileAt,
          _periodChannel,
          payload: 'period_fertile',
        );
      }
    } catch (e, st) {
      AppLogger.error(
          'NotificationService', 'Failed to schedule period reminders: $e', st);
    }
  }

  /// Cancels the period reminders (used when notifications are disabled).
  Future<void> cancelPeriodReminders() async {
    await service.cancel(NotificationIds.periodUpcoming);
    await service.cancel(NotificationIds.periodGhusl);
    await service.cancel(NotificationIds.periodStart);
    await service.cancel(NotificationIds.periodFertile);
  }
}

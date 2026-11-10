part of 'notification_service.dart';

extension _NotificationDayScheduling on NotificationService {
  /// Shared logic for a single future day's prayer notifications.
  /// Prayer IDs are [prayerBase]..[prayerBase]+4, duha [duhaId],
  /// post-prayer azkar [postBase]..[postBase]+4, morning/evening azkar ids.
  ///
  /// When [includePrayer] is false only the post-prayer window is rebuilt —
  /// used when prayer reminders are off but the independent post-prayer
  /// toggle is on. The post-prayer window additionally honors
  /// [postPrayerEnabled] itself.
  Future<void> _scheduleDayNotifications({
    required int prayerBase,
    required int duhaId,
    required int postBase,
    required PrayerTimes times,
    required AppSettings? settings,
    bool includePrayer = true,
  }) async {
    final scheduleTimezone = settings?.timezone;
    // Determine exact/inexact mode before scheduling pre-adhan reminders.
    // This must precede the loop below; asking afterwards leaves the already
    // queued reminders in inexact mode until the next reschedule.
    await _ensureExactForPostPrayer();

    final now = _wallNow(scheduleTimezone);
    await _cancelDayNotificationWindow(
      prayerBase: prayerBase,
      duhaId: duhaId,
      postBase: postBase,
    );
    final sound = settings != null
        ? _azanSoundResource(settings.azanSound)
        : 'azan_takbir';
    AndroidNotificationDetails azan(bool enabled, String body) =>
        _channelForPrayer(enabled, sound, bigText: body);

    if (includePrayer) {
      final prayers = <int, (String, String, DateTime, bool)>{
        prayerBase + 0: (
          'اذان فجر',
          _prayerBody('fajr'),
          times.fajr,
          settings?.azanEnabledForFajr ?? false
        ),
        prayerBase + 1: (
          'اذان ظهر',
          _prayerBody('dhuhr'),
          times.dhuhr,
          settings?.azanEnabledForDhuhr ?? false
        ),
        prayerBase + 2: (
          'اذان عصر',
          _prayerBody('asr'),
          times.asr,
          settings?.azanEnabledForAsr ?? false
        ),
        prayerBase + 3: (
          'اذان مغرب',
          _prayerBody('maghrib'),
          times.maghrib,
          settings?.azanEnabledForMaghrib ?? false
        ),
        prayerBase + 4: (
          'اذان عشاء',
          _prayerBody('isha'),
          times.isha,
          settings?.azanEnabledForIsha ?? false
        ),
      };

      for (final entry in prayers.entries) {
        final (title, body, rawTime, azanEnabled) = entry.value;
        final time = wallClockTime(rawTime);
        if (time.isAfter(now)) {
          await _scheduleNotification(
              entry.key, title, body, time, azan(azanEnabled, body),
              timezone: scheduleTimezone);
        }
        // Silent pre-adhan reminder for this day's window (same minutesBefore
        // setting as today — prayerNotifMinutes).
        final reminderId = _preAdhanIdFor(entry.key);
        if (reminderId != null &&
            settings?.prayerNotifMinutes != null &&
            settings!.prayerNotifMinutes > 0) {
          await _schedulePreAdhanReminder(
            id: reminderId,
            prayerName: _prayerShortName(title),
            prayerTime: time,
            minutesBefore: settings.prayerNotifMinutes,
            timezone: scheduleTimezone,
          );
        }
      }

      // نماز ضحی
      final duha =
          wallClockTime(times.sunrise).add(const Duration(minutes: 15));
      if (duha.isAfter(now)) {
        await _scheduleNotification(
          duhaId,
          'نماز ضحی',
          'خورشید برآمد؛ فرصتِ دو رکعت بندگی',
          duha,
          _azkarChannel,
        );
      }
    } // includePrayer

    // اذکار بعد از نماز — 10 دقیقه پس از اقامه — با mode دقیقِ تعیین‌شده
    // پیش از زمان‌بندی pre-adhan. Independent master toggle: also fires when
    // the prayer-reminder toggle is off.
    if (await postPrayerEnabled()) {
      final postPrayerDelay = await postPrayerDelayMinutes();
      final postPrayer = <int, (String, String, DateTime)>{
        postBase + 0: (
          'اذکار بعد از نماز صبح',
          'نمازت قبول؛ کام جان را با اذکار شیرین کن.',
          wallClockTime(times.fajr).add(Duration(
              minutes: (settings?.iqamahOffsetFajr ?? 30) + postPrayerDelay))
        ),
        postBase + 1: (
          'اذکار بعد از نماز ظهر',
          'لحظات پس از نماز، فرصتی برای پرواز.',
          wallClockTime(times.dhuhr).add(Duration(
              minutes: (settings?.iqamahOffsetDhuhr ?? 25) + postPrayerDelay))
        ),
        postBase + 2: (
          'اذکار بعد از نماز عصر',
          'ذکر بعد از نماز؛ همراهِ آرامشِ عصر.',
          wallClockTime(times.asr).add(Duration(
              minutes: (settings?.iqamahOffsetAsr ?? 25) + postPrayerDelay))
        ),
        postBase + 3: (
          'اذکار بعد از نماز مغرب',
          'در این ساعتِ نورانی، ذکر حق را فراموش نکن.',
          wallClockTime(times.maghrib).add(Duration(
              minutes: (settings?.iqamahOffsetMaghrib ?? 7) + postPrayerDelay))
        ),
        postBase + 4: (
          'اذکار بعد از نماز عشاء',
          'خاتمه‌بخشِ نمازت، با زمزمهٔ اذکار شبانه.',
          wallClockTime(times.isha).add(Duration(
              minutes: (settings?.iqamahOffsetIsha ?? 25) + postPrayerDelay))
        ),
      };
      for (final entry in postPrayer.entries) {
        final (title, body, rawTime) = entry.value;
        final time = wallClockTime(rawTime);
        if (time.isAfter(now)) {
          await _scheduleNotification(
              entry.key, title, body, time, _azkarChannel);
        }
      }
    } // postPrayerEnabled
  }

  Future<void> _cancelDayNotificationWindow({
    required int prayerBase,
    required int duhaId,
    required int postBase,
  }) async {
    for (var id = prayerBase; id <= prayerBase + 4; id++) {
      await _cancelBoth(id: id);
    }
    await _cancelBoth(id: duhaId);
    for (var id = postBase; id <= postBase + 4; id++) {
      await _cancelBoth(id: id);
    }
    for (var id = prayerBase; id <= prayerBase + 4; id++) {
      final preAdhanId = _preAdhanIdFor(id);
      if (preAdhanId != null) {
        await _cancelBoth(id: preAdhanId);
      }
    }
  }

  /// Schedules the silent «N دقیقه دیگر وقت نماز …» reminder ahead of the
  /// adhan. No-op when the reminder time has already passed.
  Future<void> _schedulePreAdhanReminder({
    required int id,
    required String prayerName,
    required DateTime prayerTime,
    required int minutesBefore,
    String? timezone,
  }) async {
    final notifyTime =
        wallClockTime(prayerTime).subtract(Duration(minutes: minutesBefore));
    if (!_asLocalTzDateTime(notifyTime, timezone: timezone)
        .isAfter(tz.TZDateTime.now(_locationForScheduling(timezone)))) {
      return;
    }
    await _scheduleNotification(
      id,
      'یادآوری نماز $prayerName',
      '$minutesBefore دقیقه دیگر وقت نماز $prayerName فرا می‌رسد',
      notifyTime,
      _prayerChannelNoSound(),
      timezone: timezone,
    );
  }
}

/// Maps an adhan notification id to its pre-adhan reminder id (same day
/// window), or null when [id] is not a prayer notification.
///
/// Top-level (not a member of the extension above) so both the scheduling
/// helpers in this file and `NotificationService` itself can call it.
int? _preAdhanIdFor(int id) {
  const map = <int, int>{
    100: NotificationIds.preAdhanFajr,
    101: NotificationIds.preAdhanDhuhr,
    102: NotificationIds.preAdhanAsr,
    103: NotificationIds.preAdhanMaghrib,
    104: NotificationIds.preAdhanIsha,
    110: NotificationIds.tomorrowPreAdhanFajr,
    111: NotificationIds.tomorrowPreAdhanDhuhr,
    112: NotificationIds.tomorrowPreAdhanAsr,
    113: NotificationIds.tomorrowPreAdhanMaghrib,
    114: NotificationIds.tomorrowPreAdhanIsha,
    210: NotificationIds.dayAfterTomorrowPreAdhanFajr,
    211: NotificationIds.dayAfterTomorrowPreAdhanDhuhr,
    212: NotificationIds.dayAfterTomorrowPreAdhanAsr,
    213: NotificationIds.dayAfterTomorrowPreAdhanMaghrib,
    214: NotificationIds.dayAfterTomorrowPreAdhanIsha,
  };
  final direct = map[id];
  if (direct != null) return direct;
  // Extended windows use 3060..3144 for prayer notifications and
  // 6060..6144 for their pre-adhan reminders.
  final dayOffset = (id - 3000) ~/ 20;
  final prayerIndex = (id - 3000) % 20;
  if (dayOffset >= 3 && dayOffset <= 7 && prayerIndex >= 0 && prayerIndex < 5) {
    return 6000 + dayOffset * 20 + prayerIndex;
  }
  return null;
}

/// Strips the «اذان» prefix so the reminder reads «یادآوری نماز فجر».
String _prayerShortName(String adhanTitle) =>
    adhanTitle.replaceFirst('اذان', '').trim();

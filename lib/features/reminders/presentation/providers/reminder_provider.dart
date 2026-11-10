import 'dart:async';
import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:tawheeed/shared/models/day_time.dart';
import 'package:tawheeed/features/prayer/domain/entities/prayer_info.dart'
    as pi;
import 'package:tawheeed/features/prayer/presentation/providers/prayer_time_provider.dart';
import 'package:tawheeed/features/reminders/data/models/reminder_model.dart';
import 'package:tawheeed/features/reminders/domain/entities/reminder_model.dart'
    show prayerNamesFa;
import 'package:tawheeed/shared/services/notification_service.dart';
import 'package:tawheeed/shared/services/sound_choice.dart';

import 'package:tawheeed/features/reminders/data/repositories/reminder_repository_impl.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/entity_ids.dart';

part 'reminder_provider.g.dart';

@riverpod
class Reminder extends _$Reminder {
  Timer? _scheduleTimer;
  final _notifService = NotificationService();

  List<ReminderModel> get reminders => state.value ?? [];
  List<ReminderModel> get enabledReminders =>
      reminders.where((r) => r.isEnabled).toList();

  @override
  Future<List<ReminderModel>> build() async {
    final list = await _loadFromDb();
    ref.onDispose(() {
      _scheduleTimer?.cancel();
    });
    return list;
  }

  List<String> _prayerRefsList(ReminderModel r) {
    if (r.prayerRef == null) return [];
    return r.prayerRef!
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  void _resolvePrayerTimes() {
    final times = ref.read(prayerTimesProvider).value;
    if (times == null) return;
    final list = state.value ?? [];
    // Copy-on-write: [list] IS the exposed state — mutating elements in
    // place changes the list listeners already hold, so widgets comparing
    // old vs new identity see no difference and skip the rebuild.
    List<ReminderModel>? next;
    for (int i = 0; i < list.length; i++) {
      final r = list[i];
      final refs = _prayerRefsList(r);
      if (refs.isEmpty) continue;
      final t = _getPrayerTime(times, refs.first);
      if (t == null) continue;
      if (r.hour != t.hour || r.minute != t.minute) {
        (next ??= List.of(list))[i] =
            r.copyWith(hour: t.hour, minute: t.minute);
      }
    }
    if (next != null) state = AsyncValue.data(next);
  }

  int _effectiveMin(ReminderModel r) {
    final refs = _prayerRefsList(r);
    if (refs.isNotEmpty) {
      final times = ref.read(prayerTimesProvider).value;
      if (times == null) return r.hour * 60 + r.minute;
      int earliest = 1440;
      for (final ref in refs) {
        final t = _getPrayerTime(times, ref);
        if (t == null) continue;
        final total = t.hour * 60 + t.minute + r.prayerOffsetMinutes;
        if (total < earliest) earliest = total;
      }
      if (earliest < 1440) return earliest;
      return r.hour * 60 + r.minute;
    }
    return r.hour * 60 + r.minute;
  }

  DayTime? _getPrayerTime(pi.PrayerTimes times, String ref) {
    switch (ref) {
      case 'fajr':
        return times.fajr.time;
      case 'dhuhr':
        return times.duhr.time;
      case 'asr':
        return times.asr.time;
      case 'maghrib':
        return times.maghrib.time;
      case 'isha':
        return times.isha.time;
      default:
        return null;
    }
  }

  Future<List<ReminderModel>> _loadFromDb() async {
    final repo = ref.read(reminderRepositoryProvider);
    final list = await repo.getAllReminders();
    // Resolve prayer times immediately and persist so the stored hour/minute
    // always reflects the current prayer schedule.
    final times = ref.read(prayerTimesProvider).value;
    if (times != null) {
      for (int i = 0; i < list.length; i++) {
        final r = list[i];
        final refs = _prayerRefsList(r);
        if (refs.isEmpty) continue;
        final t = _getPrayerTime(times, refs.first);
        if (t == null) continue;
        if (r.hour != t.hour || r.minute != t.minute) {
          list[i] = r.copyWith(hour: t.hour, minute: t.minute);
          repo.upsertReminder(list[i]); // persist resolved time
        }
      }
    }
    list.sort((a, b) => _effectiveMin(a).compareTo(_effectiveMin(b)));
    _scheduleReminderNotifications(list).catchError(
      (e) => AppLogger.warning('Reminder', 'Schedule notifications failed: $e'),
    );
    return list;
  }

  void _scheduleRemindersDebounced() {
    _scheduleTimer?.cancel();
    _scheduleTimer = Timer(const Duration(milliseconds: 600), () {
      _resolvePrayerTimes();
      final current = state.value ?? [];
      _scheduleReminderNotifications(current).catchError(
        (e) => AppLogger.warning('Reminder', 'schedule: $e'),
      );
    });
  }

  void _patchList(List<ReminderModel> next) {
    state = AsyncValue.data(next);
  }

  static AndroidNotificationSound? _notificationSound(String soundName) {
    if (soundName == 'silent') return null;
    if (soundName == 'default') return null;
    final systemUri = SoundChoice.systemUri(soundName);
    if (systemUri != null) {
      // A phone tone is a readable content:// URI, which a notification sound
      // can reference directly. (The primary Android path is still the native
      // in-process player, because the reminder channel's sound is immutable
      // once created; this covers the plugin fallback and immediate shows.)
      return UriAndroidNotificationSound(systemUri);
    }
    if (soundName.startsWith('custom:')) {
      // A file:// URI can never sound here: the system process that plays
      // notification-channel sounds cannot read app-private files, so the
      // old UriAndroidNotificationSound(file://…) always degraded to the
      // channel default anyway. The picked file plays in-process on the
      // native exact-alarm path instead (ReminderReceiver); this plugin
      // fallback — reached only when exact alarms are denied — honestly
      // reports the default. A deleted/moved file behaves the same.
      if (soundName.length > 7) {
        final path = soundName.substring(7);
        if (path.isEmpty || !File(path).existsSync()) {
          AppLogger.warning(
              'Reminder', 'Custom sound missing, using default: $path');
        }
      }
      return null;
    }
    return RawResourceAndroidNotificationSound(soundName);
  }

  /// Cancels all pending OS notifications that belong to a specific reminder.
  Future<void> _cancelReminderNotifications(String reminderId) async {
    final plugin = _notifService.plugin;
    try {
      final pending = await plugin.pendingNotificationRequests();
      for (final p in pending) {
        final payload = p.payload;
        if (payload != null &&
            (payload == 'reminder_$reminderId' ||
                payload.startsWith('reminder_${reminderId}_'))) {
          await plugin.cancel(id: p.id);
        }
      }
    } catch (e) {
      AppLogger.warning('Reminder', 'cancel $reminderId failed: $e');
    }
  }

  /// Cancels every pending reminder notification (payload-based, not a blind sweep).
  Future<void> _cancelAllReminderNotifications() async {
    final plugin = _notifService.plugin;
    try {
      final pending = await plugin.pendingNotificationRequests();
      for (final p in pending) {
        final payload = p.payload;
        if (payload != null && payload.startsWith('reminder_')) {
          await plugin.cancel(id: p.id);
        }
      }
    } catch (e) {
      AppLogger.warning('Reminder', 'cancel all failed: $e');
    }

    // The sweep above only sees plugin-scheduled work, but every reminder is
    // armed natively (setAlarmClock) and ids are positional: deleting a
    // reminder leaves the highest id armed, so it kept firing as a ghost with
    // its stale title/body. Clear the whole reserved 1000-1999 native window
    // — the batch below re-arms exactly the reminders that are still enabled.
    try {
      await _notifService.cancelNativeReminderRange(
        NotificationIds.customReminderBase,
        NotificationIds.customReminderMax,
      );
    } catch (e) {
      AppLogger.warning('Reminder', 'cancel native range failed: $e');
    }
  }

  /// One guarded schedule: a single failing reminder (revoked exact-alarm,
  /// bad date, bad sound) must never abort the whole batch. Routes through the
  /// native exact-reminder bridge so personal reminders fire on time even when
  /// SCHEDULE_EXACT_ALARM is not granted (never silently inexact).
  ///
  /// The id comes from [_notifSlot], not a positional counter: with
  /// `notifId++` a reminder could only be re-scheduled into whatever slot the
  /// batch happened to hand it, and once the counter passed the window the
  /// rest of the list was silently dropped.
  Future<void> _safeSchedule({
    required Set<int> taken,
    required String key,
    required String title,
    required String body,
    required tz.TZDateTime when,
    required AndroidNotificationDetails android,
    required String payload,
    DateTimeComponents? match,
    // The reminder's own sound for the native exact alarm. Only a custom
    // file differs from the channel default, so only that is forwarded —
    // every other sound keeps the exact behaviour it always had.
    String? nativeSound,
  }) async {
    final id = _notifSlot(taken, key);
    if (id == null) {
      AppLogger.warning(
          'Reminder', 'Notification-id window full, skipped: $title');
      return;
    }
    try {
      await _notifService.scheduleExactReminder(
        id: id,
        title: title,
        body: body,
        scheduledTime: when,
        details: android,
        matchDateTimeComponents: match,
        payload: payload,
        nativeSound: nativeSound,
      );
    } catch (e) {
      AppLogger.warning('Reminder', 'schedule $id ($title) failed: $e');
    }
  }

  /// The native alarm's sound for [soundName]: a custom file and a phone tone
  /// travel as-is (ReminderReceiver plays both in-process, with a stop action);
  /// anything else stays null so the channel default applies as before.
  static String? _nativeSound(String soundName) {
    if (soundName.startsWith('custom:')) return soundName;
    if (SoundChoice.isSystem(soundName)) return soundName;
    return null;
  }

  /// A stable id in the reserved 1000-1999 window for [key], with linear
  /// probing so two reminders never share a slot within one batch.
  ///
  /// Derived from the reminder id (via [NotificationIds.stableSlot]) instead
  /// of list position, so a notification keeps its id across re-schedules —
  /// a rescheduled reminder overwrites its own old notification instead of
  /// stacking. Returns null only when all 1000 slots are taken.
  int? _notifSlot(Set<int> taken, String key) {
    const space = NotificationIds.customReminderMax -
        NotificationIds.customReminderBase +
        1;
    final start = NotificationIds.stableSlot(key, space);
    for (int probe = 0; probe < space; probe++) {
      final slot = (start + probe) % space;
      if (taken.add(slot)) {
        return NotificationIds.customReminderBase + slot;
      }
    }
    return null;
  }

  Future<void> _scheduleReminderNotifications(List<ReminderModel> all) async {
    await _cancelAllReminderNotifications();

    final taken = <int>{};
    final now = tz.TZDateTime.now(tz.local);

    for (final r in all) {
      if (!r.isEnabled) continue;

      if (r.specificDate != null) {
        final targetDate = r.specificDate!;
        if (_dateOnly(targetDate).isBefore(_dateOnly(DateTime.now()))) continue;

        final scheduled = tz.TZDateTime(
          tz.local,
          targetDate.year,
          targetDate.month,
          targetDate.day,
          r.hour,
          r.minute,
        );

        if (scheduled.isBefore(now)) continue;

        final mainTitle = 'یادآوری: ${r.title}';
        final mainBody =
            r.note.isNotEmpty ? r.note : 'زمان ${r.title} فرا رسید';
        final isSilent = r.soundName == 'silent';
        await _safeSchedule(
          taken: taken,
          key: r.id,
          title: mainTitle,
          body: mainBody,
          when: scheduled,
          android: AndroidNotificationDetails(
            'custom_reminders_v2',
            'یادآورها',
            channelDescription: 'یادآوری‌های شخصی',
            importance: Importance.high,
            category: AndroidNotificationCategory.alarm,
            sound: _notificationSound(r.soundName),
            silent: isSilent,
          ),
          payload: 'reminder_${r.id}',
          nativeSound: _nativeSound(r.soundName),
        );

        if (r.advanceMinutes > 0) {
          final earlyTime =
              scheduled.subtract(Duration(minutes: r.advanceMinutes));
          if (earlyTime.isAfter(now)) {
            final earlyTitle =
                'یادآوری: ${r.title} (${r.advanceMinutes} دقیقه مانده)';
            final earlyBody =
                r.note.isNotEmpty ? r.note : 'زمان ${r.title} نزدیک است';
            final isSilent = r.soundName == 'silent';
            await _safeSchedule(
              taken: taken,
              key: '${r.id}#early',
              title: earlyTitle,
              body: earlyBody,
              when: earlyTime,
              android: AndroidNotificationDetails(
                'custom_reminders_v2',
                'یادآورها',
                channelDescription: 'یادآوری‌های شخصی',
                importance: Importance.high,
                category: AndroidNotificationCategory.alarm,
                sound: _notificationSound(r.soundName),
                silent: isSilent,
              ),
              payload: 'reminder_${r.id}',
              nativeSound: _nativeSound(r.soundName),
            );
          }
        }

        continue;
      }

      final refs = _prayerRefsList(r);
      // Every prayer-based reminder (one prayer or several) goes through the
      // offset-aware path below: a single prayer used to fall through to the
      // plain clock-time branch, silently ignoring prayerOffsetMinutes, so
      // «15 دقیقه قبل از اذان» fired exactly at the adhan instead.
      if (refs.isNotEmpty) {
        final times = ref.read(prayerTimesProvider).value;
        for (final ref in refs) {
          // `ref` is a persisted English code ('fajr'); a notification body is
          // read by the user, so it always carries the Persian name. Never
          // interpolate the raw code into user-facing text again.
          final refFa = prayerNamesFa(ref);
          final pt = times == null ? null : _getPrayerTime(times, ref);
          // Times not resolved yet (or an unknown ref): r.hour/r.minute are
          // kept in sync with the prayer time by _resolvePrayerTimes, so the
          // stored clock time is the best approximation available.
          final minutes = prayerFireMinutes(
            hour: pt?.hour ?? r.hour,
            minute: pt?.minute ?? r.minute,
            offsetMinutes: r.prayerOffsetMinutes,
          );
          // Minutes counted from local midnight, added as one Duration so
          // hour/day boundaries roll exactly (the old
          // `hour + (minute + offset) ~/ 60` truncated toward zero and landed
          // a FULL HOUR late whenever minute + offset went negative).
          var fireTime = tz.TZDateTime(tz.local, now.year, now.month, now.day)
              .add(Duration(minutes: minutes));
          // A past wall-clock time with a daily match would otherwise fire
          // immediately (or be dropped) — roll it to tomorrow's occurrence.
          if (!fireTime.isAfter(now)) {
            fireTime = fireTime.add(const Duration(days: 1));
          }

          if (r.advanceMinutes > 0) {
            final early =
                fireTime.subtract(Duration(minutes: r.advanceMinutes));
            if (early.isAfter(now)) {
              final isSilent = r.soundName == 'silent';
              await _safeSchedule(
                taken: taken,
                key: '${r.id}@$ref#early',
                title: '${r.title} (${r.advanceMinutes} دقیقه مانده)',
                body: r.note.isNotEmpty ? r.note : 'زمان اذان $refFa نزدیک است',
                when: early,
                android: AndroidNotificationDetails(
                  'custom_reminders_v2',
                  'یادآورها',
                  channelDescription: 'یادآوری‌های شخصی',
                  importance: Importance.high,
                  category: AndroidNotificationCategory.alarm,
                  sound: _notificationSound(r.soundName),
                  silent: isSilent,
                ),
                // Same daily match as the main reminder so the pre-reminder
                // repeats every day instead of firing only once.
                match: DateTimeComponents.time,
                payload: 'reminder_${r.id}_$ref',
                nativeSound: _nativeSound(r.soundName),
              );
            }
          }

          final isSilent = r.soundName == 'silent';
          await _safeSchedule(
            taken: taken,
            key: '${r.id}@$ref',
            title: 'یادآوری: ${r.title}',
            body: r.note.isNotEmpty ? r.note : 'زمان اذان $refFa فرا رسید',
            when: fireTime,
            android: AndroidNotificationDetails(
              'custom_reminders_v2',
              'یادآورها',
              channelDescription: 'یادآوری‌های شخصی',
              importance: Importance.high,
              category: AndroidNotificationCategory.alarm,
              sound: _notificationSound(r.soundName),
              silent: isSilent,
            ),
            match: DateTimeComponents.time,
            payload: 'reminder_${r.id}_$ref',
            nativeSound: _nativeSound(r.soundName),
          );
        }
        continue;
      }

      final scheduledForToday = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        r.hour,
        r.minute,
      );

      var fireTime = scheduledForToday;
      if (fireTime.isBefore(now)) {
        fireTime = fireTime.add(const Duration(days: 1));
      }
      if (r.daysOfWeek.isNotEmpty) {
        fireTime = _nextMatchingDay(fireTime, r.daysOfWeek);
      }

      if (r.advanceMinutes > 0) {
        final earlyFireTime =
            fireTime.subtract(Duration(minutes: r.advanceMinutes));
        if (earlyFireTime.isAfter(now)) {
          final earlyTitle =
              'یادآوری: ${r.title} (${r.advanceMinutes} دقیقه مانده)';
          final earlyBody =
              r.note.isNotEmpty ? r.note : 'زمان ${r.title} نزدیک است';
          final isSilent = r.soundName == 'silent';
          await _safeSchedule(
            taken: taken,
            key: '${r.id}#early',
            title: earlyTitle,
            body: earlyBody,
            when: earlyFireTime,
            android: AndroidNotificationDetails(
              'custom_reminders_v2',
              'یادآورها',
              channelDescription: 'یادآوری‌های شخصی',
              importance: Importance.high,
              category: AndroidNotificationCategory.alarm,
              sound: _notificationSound(r.soundName),
              silent: isSilent,
            ),
            // Same repeat rule as the main reminder so the pre-reminder
            // repeats instead of firing only once.
            match: r.daysOfWeek.isNotEmpty
                ? DateTimeComponents.dayOfWeekAndTime
                : DateTimeComponents.time,
            payload: 'reminder_${r.id}',
            nativeSound: _nativeSound(r.soundName),
          );
        }
      }

      final mainTitle = 'یادآوری: ${r.title}';
      final mainBody = r.note.isNotEmpty ? r.note : 'زمان ${r.title} فرا رسید';

      final isSilent = r.soundName == 'silent';
      await _safeSchedule(
        taken: taken,
        key: r.id,
        title: mainTitle,
        body: mainBody,
        when: fireTime,
        android: AndroidNotificationDetails(
          'custom_reminders_v2',
          'یادآورها',
          channelDescription: 'یادآوری‌های شخصی',
          importance: Importance.high,
          category: AndroidNotificationCategory.alarm,
          sound: _notificationSound(r.soundName),
          silent: isSilent,
        ),
        match: r.daysOfWeek.isNotEmpty
            ? DateTimeComponents.dayOfWeekAndTime
            : DateTimeComponents.time,
        payload: 'reminder_${r.id}',
        nativeSound: _nativeSound(r.soundName),
      );
    }
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  tz.TZDateTime _nextMatchingDay(tz.TZDateTime from, List<int> daysOfWeek) {
    var candidate = from;
    for (int i = 0; i < 7; i++) {
      // Dart weekday: 1=Mon..7=Sun
      // Persian index: 0=Sat, 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri
      if (daysOfWeek.contains((candidate.weekday + 1) % 7)) return candidate;
      candidate = tz.TZDateTime.from(
        candidate.add(const Duration(days: 1)),
        tz.local,
      );
    }
    return candidate;
  }

  Future<void> addReminder({
    required String title,
    String note = '',
    required int hour,
    required int minute,
    List<int> daysOfWeek = const [],
    int advanceMinutes = 0,
    bool useSound = false,
    String soundName = 'default',
    DateTime? specificDate,
    String? prayerRef,
    int prayerOffsetMinutes = 0,
  }) async {
    final reminder = ReminderModel(
      id: newEntityId(),
      title: title,
      note: note,
      hour: hour,
      minute: minute,
      daysOfWeek: daysOfWeek,
      createdAt: DateTime.now(),
      advanceMinutes: advanceMinutes,
      useSound: useSound,
      soundName: soundName,
      specificDate: specificDate,
      prayerRef: prayerRef,
      prayerOffsetMinutes: prayerOffsetMinutes,
    );
    final list = state.value ?? [];
    _patchList([...list, reminder]);
    try {
      await ref.read(reminderRepositoryProvider).upsertReminder(reminder);
      _scheduleRemindersDebounced();
    } catch (e) {
      AppLogger.warning('reminder_provider', 'error: $e');
      _patchList(list);
    }
  }

  Future<void> updateReminder(ReminderModel reminder) async {
    final list = state.value ?? [];
    final idx = list.indexWhere((r) => r.id == reminder.id);
    if (idx < 0) return;
    final updated = reminder.copyWith(updatedAt: DateTime.now());
    _patchList([...list]..[idx] = updated);
    try {
      await ref.read(reminderRepositoryProvider).upsertReminder(updated);
      _scheduleRemindersDebounced();
    } catch (e) {
      AppLogger.warning('reminder_provider', 'error: $e');
      _patchList(list);
    }
  }

  /// Removed by the last [deleteReminder], kept in memory so the editor's
  /// undo snackbar can restore it (re-inserted with its original id).
  ReminderModel? _lastDeleted;

  Future<void> deleteReminder(String id) async {
    final list = state.value ?? [];
    final idx = list.indexWhere((r) => r.id == id);
    if (idx < 0) return;
    _lastDeleted = list[idx];
    final snapshot = list;
    _patchList(list.where((r) => r.id != id).toList());
    try {
      await ref.read(reminderRepositoryProvider).deleteReminder(id);
      await _cancelReminderNotifications(id);
      _scheduleRemindersDebounced();
    } catch (e) {
      AppLogger.warning('reminder_provider', 'error: $e');
      _lastDeleted = null;
      _patchList(snapshot);
    }
  }

  /// Restores the reminder removed by the last [deleteReminder] (undo
  /// snackbar) and re-arms its notifications.
  Future<void> undoLastDelete() async {
    final reminder = _lastDeleted;
    if (reminder == null) return;
    _lastDeleted = null;
    final list = state.value ?? [];
    if (list.any((r) => r.id == reminder.id)) return;
    final restored = [...list, reminder]
      ..sort((a, b) => _effectiveMin(a).compareTo(_effectiveMin(b)));
    _patchList(restored);
    try {
      await ref.read(reminderRepositoryProvider).upsertReminder(reminder);
      _scheduleRemindersDebounced();
    } catch (e) {
      AppLogger.warning('reminder_provider', 'undo-persist failed: $e');
      _patchList(list);
    }
  }

  Future<void> toggleEnabled(String id) async {
    final list = state.value ?? [];
    final idx = list.indexWhere((r) => r.id == id);
    if (idx < 0) return;
    final enabling = !list[idx].isEnabled;
    final updated = list[idx].copyWith(isEnabled: enabling);
    _patchList([...list]..[idx] = updated);
    try {
      await ref.read(reminderRepositoryProvider).upsertReminder(updated);
      if (!enabling) {
        // Cancel the OS notifications for this reminder immediately so a
        // disabled reminder can never fire again (no debounce, no reliance
        // on a later full re-schedule).
        await _cancelReminderNotifications(id);
      } else {
        _scheduleRemindersDebounced();
      }
    } catch (e) {
      AppLogger.warning('reminder_provider', 'error: $e');
      _patchList(list);
    }
  }

  Future<void> clearAll() async {
    final snapshot = state.value ?? [];
    _patchList([]);
    try {
      await ref.read(reminderRepositoryProvider).clearAll();
      await _cancelAllReminderNotifications();
      _scheduleRemindersDebounced();
    } catch (e) {
      AppLogger.warning('reminder_provider', 'error: $e');
      _patchList(snapshot);
    }
  }
}

/// Minutes after local midnight at which a prayer reminder fires: the prayer
/// time plus the user's offset (negative = before the adhan).
///
/// The result is intentionally allowed to be negative or larger than 1440 —
/// callers anchor it to local midnight and add it as a single [Duration], so
/// hour and day boundaries roll exactly. Doing the arithmetic as
/// `hour + (minute + offset) ~/ 60` truncates toward zero instead, which
/// pushed any negative `minute + offset` a full hour late (fajr 05:10 − 15
/// fired at 05:50 instead of 04:55).
int prayerFireMinutes({
  required int hour,
  required int minute,
  required int offsetMinutes,
}) =>
    hour * 60 + minute + offsetMinutes;

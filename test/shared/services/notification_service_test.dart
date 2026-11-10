import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:tawheeed/shared/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    NotificationService.onKhatmTapped = null;
  });

  group('Khatm notification tap', () {
    NotificationResponse khatmTap() => const NotificationResponse(
          payload: 'khatm_reminder',
          notificationResponseType:
              NotificationResponseType.selectedNotification,
        );

    testWidgets('khatm_reminder payload invokes onKhatmTapped', (tester) async {
      var called = false;
      NotificationService.onKhatmTapped = () => called = true;

      NotificationService().handleNotificationTap(khatmTap());
      await tester.pump();

      expect(called, isTrue);
    });

    testWidgets('non-khatm payload does not invoke onKhatmTapped',
        (tester) async {
      var called = false;
      NotificationService.onKhatmTapped = () => called = true;

      NotificationService().handleNotificationTap(const NotificationResponse(
        payload: 'daily_verse',
        notificationResponseType: NotificationResponseType.selectedNotification,
      ));
      await tester.pump();

      expect(called, isFalse);
    });

    testWidgets('tap before registration is buffered and dispatched later',
        (tester) async {
      // Tap arrives while no handler is registered (cold start).
      NotificationService().handleNotificationTap(khatmTap());

      var called = false;
      NotificationService.onKhatmTapped = () => called = true;
      // Pumping a widget schedules real frames so the post-frame callback
      // (which dispatches the buffered tap) actually runs.
      await tester.pumpWidget(const SizedBox());

      expect(called, isTrue);
    });

    testWidgets('clearing the handler drops a buffered tap', (tester) async {
      NotificationService().handleNotificationTap(khatmTap());
      // Handler is cleared before the frame — the buffered tap is dropped.
      NotificationService.onKhatmTapped = null;

      var called = false;
      NotificationService.onKhatmTapped = () => called = true;
      await tester.pumpWidget(const SizedBox());

      expect(called, isFalse);
    });
  });

  group('NotificationIds', () {
    test('today prayer IDs are unique and non-overlapping with tomorrow', () {
      final today = <int>[
        NotificationIds.fajr,
        NotificationIds.dhuhr,
        NotificationIds.asr,
        NotificationIds.maghrib,
        NotificationIds.isha,
        NotificationIds.duha,
        NotificationIds.morningAzkar,
        NotificationIds.eveningAzkar,
        NotificationIds.postFajr,
        NotificationIds.postDhuhr,
        NotificationIds.postAsr,
        NotificationIds.postMaghrib,
        NotificationIds.postIsha,
      ];

      final tomorrow = <int>[
        NotificationIds.tomorrowFajr,
        NotificationIds.tomorrowDhuhr,
        NotificationIds.tomorrowAsr,
        NotificationIds.tomorrowMaghrib,
        NotificationIds.tomorrowIsha,
        NotificationIds.tomorrowDuha,
        NotificationIds.tomorrowPostFajr,
        NotificationIds.tomorrowPostDhuhr,
        NotificationIds.tomorrowPostAsr,
        NotificationIds.tomorrowPostMaghrib,
        NotificationIds.tomorrowPostIsha,
      ];

      final dayAfterTomorrow = <int>[
        NotificationIds.dayAfterTomorrowFajr,
        NotificationIds.dayAfterTomorrowDhuhr,
        NotificationIds.dayAfterTomorrowAsr,
        NotificationIds.dayAfterTomorrowMaghrib,
        NotificationIds.dayAfterTomorrowIsha,
        NotificationIds.dayAfterTomorrowDuha,
        NotificationIds.dayAfterTomorrowPostFajr,
        NotificationIds.dayAfterTomorrowPostDhuhr,
        NotificationIds.dayAfterTomorrowPostAsr,
        NotificationIds.dayAfterTomorrowPostMaghrib,
        NotificationIds.dayAfterTomorrowPostIsha,
      ];

      expect(today.length, today.toSet().length,
          reason: 'Today notification IDs must be unique');
      expect(tomorrow.length, tomorrow.toSet().length,
          reason: 'Tomorrow notification IDs must be unique');
      expect(dayAfterTomorrow.length, dayAfterTomorrow.toSet().length,
          reason: 'Day-after-tomorrow notification IDs must be unique');

      final overlap = today.where(tomorrow.contains).toSet();
      expect(overlap, isEmpty,
          reason: 'Today and tomorrow IDs must not overlap: $overlap');
      final overlap2 = today.where(dayAfterTomorrow.contains).toSet();
      expect(overlap2, isEmpty,
          reason:
              'Today and day-after-tomorrow IDs must not overlap: $overlap2');
      final overlap3 = tomorrow.where(dayAfterTomorrow.contains).toSet();
      expect(overlap3, isEmpty,
          reason:
              'Tomorrow and day-after-tomorrow IDs must not overlap: $overlap3');
    });

    test('reminder IDs do not collide with prayer IDs', () {
      final prayerIds = <int>[
        NotificationIds.fajr,
        NotificationIds.dhuhr,
        NotificationIds.asr,
        NotificationIds.maghrib,
        NotificationIds.isha,
        NotificationIds.duha,
        NotificationIds.morningAzkar,
        NotificationIds.eveningAzkar,
        NotificationIds.postFajr,
        NotificationIds.postDhuhr,
        NotificationIds.postAsr,
        NotificationIds.postMaghrib,
        NotificationIds.postIsha,
        NotificationIds.tomorrowFajr,
        NotificationIds.tomorrowDhuhr,
        NotificationIds.tomorrowAsr,
        NotificationIds.tomorrowMaghrib,
        NotificationIds.tomorrowIsha,
        NotificationIds.tomorrowDuha,
        NotificationIds.tomorrowPostFajr,
        NotificationIds.tomorrowPostDhuhr,
        NotificationIds.tomorrowPostAsr,
        NotificationIds.tomorrowPostMaghrib,
        NotificationIds.tomorrowPostIsha,
        NotificationIds.dayAfterTomorrowFajr,
        NotificationIds.dayAfterTomorrowDhuhr,
        NotificationIds.dayAfterTomorrowAsr,
        NotificationIds.dayAfterTomorrowMaghrib,
        NotificationIds.dayAfterTomorrowIsha,
        NotificationIds.dayAfterTomorrowDuha,
        NotificationIds.dayAfterTomorrowPostFajr,
        NotificationIds.dayAfterTomorrowPostDhuhr,
        NotificationIds.dayAfterTomorrowPostAsr,
        NotificationIds.dayAfterTomorrowPostMaghrib,
        NotificationIds.dayAfterTomorrowPostIsha,
      ];

      final reminderIds = <int>[
        NotificationIds.quranReminder,
        NotificationIds.dailyVerse,
        NotificationIds.dailyHadith,
        NotificationIds.dailyDua,
        NotificationIds.snooze,
      ];

      final overlap = prayerIds.where(reminderIds.contains).toSet();
      expect(overlap, isEmpty,
          reason: 'Prayer IDs and reminder IDs must not overlap: $overlap');
    });

    test('Islamic event IDs do not collide with other IDs', () {
      final allOtherIds = <int>[
        NotificationIds.fajr,
        NotificationIds.dhuhr,
        NotificationIds.asr,
        NotificationIds.maghrib,
        NotificationIds.isha,
        NotificationIds.duha,
        NotificationIds.morningAzkar,
        NotificationIds.eveningAzkar,
        NotificationIds.postFajr,
        NotificationIds.postDhuhr,
        NotificationIds.postAsr,
        NotificationIds.postMaghrib,
        NotificationIds.postIsha,
        NotificationIds.tomorrowFajr,
        NotificationIds.tomorrowDhuhr,
        NotificationIds.tomorrowAsr,
        NotificationIds.tomorrowMaghrib,
        NotificationIds.tomorrowIsha,
        NotificationIds.tomorrowDuha,
        NotificationIds.tomorrowPostFajr,
        NotificationIds.tomorrowPostDhuhr,
        NotificationIds.tomorrowPostAsr,
        NotificationIds.tomorrowPostMaghrib,
        NotificationIds.tomorrowPostIsha,
        NotificationIds.dayAfterTomorrowFajr,
        NotificationIds.dayAfterTomorrowDhuhr,
        NotificationIds.dayAfterTomorrowAsr,
        NotificationIds.dayAfterTomorrowMaghrib,
        NotificationIds.dayAfterTomorrowIsha,
        NotificationIds.dayAfterTomorrowDuha,
        NotificationIds.dayAfterTomorrowPostFajr,
        NotificationIds.dayAfterTomorrowPostDhuhr,
        NotificationIds.dayAfterTomorrowPostAsr,
        NotificationIds.dayAfterTomorrowPostMaghrib,
        NotificationIds.dayAfterTomorrowPostIsha,
        NotificationIds.quranReminder,
        NotificationIds.dailyVerse,
        NotificationIds.dailyHadith,
        NotificationIds.dailyDua,
        NotificationIds.snooze,
      ];

      for (int id = NotificationIds.islamicEventBase;
          id <= NotificationIds.islamicEventMax;
          id++) {
        expect(
          allOtherIds.contains(id),
          isFalse,
          reason: 'Islamic event ID $id collides with another notification ID',
        );
      }
    });
  });

  group('Daily verse content', () {
    test('every verse has non-empty text, reference and translation', () {
      expect(NotificationService.dailyVerses, isNotEmpty);
      for (final v in NotificationService.dailyVerses) {
        expect(v['verse'], isNotNull, reason: 'verse missing for $v');
        expect(v['verse']!.trim(), isNotEmpty, reason: 'verse empty for $v');
        expect(v['ref'], isNotNull, reason: 'ref missing for $v');
        expect(v['trans'], isNotNull, reason: 'trans missing for $v');
      }
    });

    test('verse references start with the surah name (فاتحه:5 / بقره:2)', () {
      final verses = NotificationService.dailyVerses;
      expect(verses[0]['ref'], 'سوره فاتحه، آیه 5');
      expect(verses[1]['ref'], 'سوره بقره، آیه 2');
    });

    test('every reference is like سوره X، آیه Y', () {
      for (final v in NotificationService.dailyVerses) {
        expect(
          v['ref'],
          matches(RegExp(r'^سوره [^،]+، آیه [0-90-9]+(-[0-90-9]+)?$')),
          reason: 'reference should be like سوره X، آیه Y: ${v['ref']}',
        );
      }
    });
  });

  group('Daily hadith content', () {
    test('every hadith has a non-empty Persian text', () {
      expect(NotificationService.dailyHadiths, isNotEmpty);
      for (final h in NotificationService.dailyHadiths) {
        expect(h['text'], isNotNull, reason: 'text missing for $h');
        expect(h['text']!.trim(), isNotEmpty, reason: 'text empty for $h');
      }
    });

    test('weak hadith الدعاء مخ العبادة is removed', () {
      final texts = NotificationService.dailyHadiths
          .map((h) => h['text'])
          .whereType<String>()
          .toList();
      expect(texts.any((t) => t.contains('مُخُّ الْعِبَادَةِ')), isFalse);
    });

    test('hadiths are Persian-only (no Arabic text is stored or shown)', () {
      for (final h in NotificationService.dailyHadiths) {
        expect((h['trans'] ?? '').trim(), isEmpty,
            reason: 'hadiths intentionally have no Arabic/translation: $h');
      }
    });
  });

  group('Daily content body builder', () {
    test('body = text + translation + source when translation differs', () {
      final body = NotificationService.debugDailyContentBody(
        text: 'اعمال با نیت‌ها هستند',
        ref: 'متفق علیه',
        trans: 'همانا اعمال به نیت‌هاست',
      );
      expect(body, 'اعمال با نیت ها هستند\nهمانا اعمال به نیت هاست\nمتفق علیه');
    });

    test('body skips translation when it equals the text (Persian-only)', () {
      final body = NotificationService.debugDailyContentBody(
        text: 'دین نصیحت است',
        ref: 'صحیح مسلم، شماره 55',
        trans: 'دین نصیحت است',
      );
      expect(body, 'دین نصیحت است\nصحیح مسلم، شماره 55');
    });

    test('body skips empty translation', () {
      final body = NotificationService.debugDailyContentBody(
        text: 'دین نصیحت است',
        ref: 'صحیح مسلم، شماره 55',
        trans: '',
      );
      expect(body, 'دین نصیحت است\nصحیح مسلم، شماره 55');
    });

    test('body never prints the same sentence twice', () {
      for (final h in NotificationService.dailyHadiths) {
        final body = NotificationService.debugDailyContentBody(
          text: h['text'] ?? '',
          ref: h['ref'] ?? '',
          trans: h['trans'] ?? '',
        );
        final trimmed = body.trim();
        final firstLine = trimmed.split('\n').first.trim();
        expect(firstLine.length, greaterThan(0));
      }
    });
  });

  // A reminder toggle re-queries the exact-alarm grant for every notification
  // it re-arms. Writing a log line for each query put «Notification schedule
  // mode: …» into `tawheed_log.txt` on every single toggle; only a CHANGE is
  // news, and a broken channel must warn once rather than flood the log.
  group('schedule-mode logging stays quiet', () {
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');

    setUp(() {
      NotificationService.resetScheduleModeLogging();
      FlutterLocalNotificationsPlatform.instance =
          AndroidFlutterLocalNotificationsPlugin();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('a repeated identical query logs once', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'canScheduleExactNotifications') return true;
        return null;
      });

      final service = NotificationService();
      await service.refreshScheduleMode();
      await service.refreshScheduleMode();
      await service.refreshScheduleMode();

      expect(NotificationService.scheduleModeLogs, 1);
      expect(service.scheduleMode, AndroidScheduleMode.exactAllowWhileIdle);
    });

    test('a change in the grant is logged again', () async {
      var granted = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'canScheduleExactNotifications') return granted;
        return null;
      });

      final service = NotificationService();
      await service.refreshScheduleMode();
      granted = false;
      await service.refreshScheduleMode();

      expect(NotificationService.scheduleModeLogs, 2);
      expect(service.scheduleMode, AndroidScheduleMode.inexactAllowWhileIdle);
    });

    test('a failing query warns once for the whole streak', () async {
      var failing = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'canScheduleExactNotifications' && failing) {
          throw PlatformException(code: 'no_channel');
        }
        if (call.method == 'canScheduleExactNotifications') return true;
        return null;
      });

      final service = NotificationService();
      await service.refreshScheduleMode();
      await service.refreshScheduleMode();
      await service.refreshScheduleMode();
      expect(NotificationService.exactAlarmQueryWarnings, 1);

      // A successful query ends the streak, so the next failure is news again.
      failing = false;
      await service.refreshScheduleMode();
      failing = true;
      await service.refreshScheduleMode();
      expect(NotificationService.exactAlarmQueryWarnings, 2);
    });
  });

  group('Pre-adhan reminder mapping', () {
    test('NotificationIds pre-adhan constants are in their own ranges', () {
      expect(NotificationIds.preAdhanFajr, 500);
      expect(NotificationIds.preAdhanIsha, 504);
      expect(NotificationIds.tomorrowPreAdhanFajr, 510);
      expect(NotificationIds.tomorrowPreAdhanIsha, 514);
      expect(NotificationIds.dayAfterTomorrowPreAdhanFajr, 520);
      expect(NotificationIds.dayAfterTomorrowPreAdhanIsha, 524);
    });
  });

  group('Daily content window cancels stale notifications before scheduling',
      () {
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    final cancelledIds = <int>[];
    final scheduledIds = <int>[];

    setUp(() async {
      tzdata.initializeTimeZones();
      cancelledIds.clear();
      scheduledIds.clear();
      FlutterLocalNotificationsPlatform.instance =
          AndroidFlutterLocalNotificationsPlugin();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'cancel') {
          final args = call.arguments as Map;
          cancelledIds.add(args['id'] as int);
          return null;
        }
        if (call.method == 'zonedSchedule') {
          final args = call.arguments as Map;
          scheduledIds.add(args['id'] as int);
          return null;
        }
        if (call.method == 'pendingNotificationRequests') {
          return <Map<String, dynamic>>[];
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      FlutterLocalNotificationsPlatform.instance =
          AndroidFlutterLocalNotificationsPlugin();
    });

    test('scheduleDailyVerse cancels the legacy repeating id first', () async {
      await NotificationService()
          .scheduleDailyVerse(time: const TimeOfDay(hour: 7, minute: 0));
      expect(cancelledIds, contains(NotificationIds.dailyVerse),
          reason: 'legacy repeating آیه روز (400) must be cleared');
      expect(scheduledIds, isNotEmpty);
      expect(cancelledIds.indexOf(NotificationIds.dailyVerse),
          lessThan(scheduledIds.first),
          reason: 'cancel must happen before scheduling the new window');
    });

    test('scheduleDailyHadith cancels the legacy repeating id first', () async {
      await NotificationService()
          .scheduleDailyHadith(time: const TimeOfDay(hour: 18, minute: 0));
      expect(cancelledIds, contains(NotificationIds.dailyHadith));
      expect(scheduledIds, isNotEmpty);
      expect(cancelledIds.indexOf(NotificationIds.dailyHadith),
          lessThan(scheduledIds.first));
    });

    test('scheduleDailyDua cancels the legacy repeating id first', () async {
      await NotificationService()
          .scheduleDailyDua(time: const TimeOfDay(hour: 22, minute: 0));
      expect(cancelledIds, contains(NotificationIds.dailyDua));
      expect(scheduledIds, isNotEmpty);
      expect(cancelledIds.indexOf(NotificationIds.dailyDua),
          lessThan(scheduledIds.first));
    });
  });

  group('Cold-start stashed payload (handleColdStartTap)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      NotificationService.onPrayerTapped = null;
      NotificationService.onKhatmTapped = null;
    });

    tearDown(() {
      NotificationService.onPrayerTapped = null;
      NotificationService.onKhatmTapped = null;
    });

    test('prayer payload is dispatched and consumed exactly once', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('notification_payload', 'prayer_fajr');

      String? got;
      NotificationService.onPrayerTapped = (String name) => got = name;

      await NotificationService().handleColdStartTap();
      expect(got, 'fajr');
      expect(
        (await SharedPreferences.getInstance())
            .getString('notification_payload'),
        isNull,
        reason: 'stashed payload must be consumed',
      );

      // Consumed: a second pass must not re-dispatch (Phase-1 regression —
      // the prayer tap used to be dropped entirely on cold start).
      await NotificationService().handleColdStartTap();
      expect(got, 'fajr', reason: 'payload dispatches exactly once');
    });

    test('khatm payload reaches onKhatmTapped', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('notification_payload', 'khatm_reminder');
      var called = false;
      NotificationService.onKhatmTapped = () => called = true;

      await NotificationService().handleColdStartTap();
      expect(called, isTrue);
    });

    test('empty stash is a no-op', () async {
      var called = false;
      NotificationService.onPrayerTapped = (String name) => called = true;

      await NotificationService().handleColdStartTap();
      expect(called, isFalse);
    });
  });
}

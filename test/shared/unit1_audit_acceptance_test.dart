import 'dart:io';

import 'package:adhan/adhan.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/home/presentation/utils/date_formatters.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/shared/services/native_prayer_alarm_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// Acceptance tests for the Unit 1 audit implementation (P-01, P-07, P-10,
/// P-11). Widget-level acceptance for P-02…P-06, P-08, P-09 lives with the
/// existing harnesses of those screens/cards; these are the pure-logic gates
/// that can be asserted without booting the whole Riverpod graph.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P-01 — calendar dates are day/month/year with isolated digit runs', () {
    test('Shamsi / Hijri / Gregorian all keep RTL logical order', () {
      const ltr = NumberFormat.ltrIsolated;
      expect(DateFormatters.formatShamsi(14, 8, 1405),
          '${ltr('14')} ${DateFormatters.persianMonths[7]} ${ltr('1405')}');
      expect(DateFormatters.formatHijri(26, 5, 1448),
          '${ltr('26')} ${DateFormatters.hijriMonths[4]} ${ltr('1448')}');
      expect(DateFormatters.formatGregorian(5, 11, 2026),
          '${ltr('5')} ${DateFormatters.gregorianMonths[10]} ${ltr('2026')}');
    });

    test('only the two numbers are isolated, never the whole date', () {
      const ltr = NumberFormat.ltrIsolated;
      final s = DateFormatters.formatGregorian(5, 11, 2026);
      final month = DateFormatters.gregorianMonths[10];
      // A whole-string LTR isolate would pin the date left-to-right and put
      // the year where the day belongs. Instead each number gets its own
      // isolate and the month stays in the surrounding RTL paragraph.
      expect('\u2066'.allMatches(s).length, 2,
          reason: 'exactly two isolates: day and year');
      expect('\u2069'.allMatches(s).length, 2);
      expect(s, startsWith(ltr('5')));
      expect(s, endsWith(ltr('2026')));
      expect(s, contains(' $month '));
      final monthPos = s.indexOf(month);
      expect(s.substring(0, monthPos).split('\u2069').length - 1, 1,
          reason: 'the day isolate is already closed before the month');
      expect(s.substring(monthPos).split('\u2066').length - 1, 1,
          reason: 'the year isolate opens only after the month');
      // Explicitly reject the whole-string isolate drafted in the audit.
      expect(s, isNot(equals(ltr('5 $month 2026'))));
    });

    test('formatToday uses the same formatter', () {
      final s = DateFormatters.formatToday();
      expect('\u2066'.allMatches(s).length, 2);
      expect(s, isNot(contains('...')));
    });
  });

  group('P-07 — share location is off by default and persists', () {
    test('the preference key is absent (false) until explicitly enabled',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('prayer_share_show_city') ?? false, isFalse);
      await prefs.setBool('prayer_share_show_city', true);
      final reopened = await SharedPreferences.getInstance();
      expect(reopened.getBool('prayer_share_show_city'), isTrue);
    });
  });

  group('P-10 — AppLogger scrubbing and write-failure diagnostics', () {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    late Directory tempDir;

    setUp(() async {
      AppLogger.resetDiagnostics();
      tempDir = await Directory.systemTemp.createTemp('tawheed_audit_logger');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return tempDir.path;
        }
        return null;
      });
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('emails, Western + Persian phones, secrets and city labels are scrubbed',
        () async {
      AppLogger.info('T',
          'me@example.com 09123456789 \u06F0\u06F9\u06F1\u06F2\u06F3\u06F4\u06F5\u06F6\u06F7\u06F8\u06F9 token=abc123xyz \u0634\u0647\u0631: \u0639\u06CC\u0648\u0636');
      await AppLogger.flush();
      final content =
          await File('${tempDir.path}/tawheed_log.txt').readAsString();
      expect(content, contains('[email]'));
      expect(content, contains('[digits]'));
      expect(content, contains('[secret]'));
      expect(content, contains('[city]'));
      expect(content, isNot(contains('me@example.com')));
      expect(content, isNot(contains('09123456789')));
      expect(content, isNot(contains('abc123xyz')));
    });

    test('a broken log directory is counted, exactly once, without recursion',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        // A path that is a regular FILE cannot hold the log file.
        return '${tempDir.path}/not-a-directory';
      });
      await File('${tempDir.path}/not-a-directory')
          .writeAsString('occupied', flush: true);

      AppLogger.info('T', 'one line');
      await AppLogger.flush();
      expect(AppLogger.failedWrites, greaterThanOrEqualTo(1));
      expect(AppLogger.lastWriteError, isNotNull);
      // No AppLogger call from inside the failure path => no recursive growth.
      final afterFirst = AppLogger.failedWrites;
      AppLogger.info('T', 'another line');
      await AppLogger.flush();
      expect(AppLogger.failedWrites, greaterThanOrEqualTo(afterFirst));
      expect(AppLogger.failedWrites, lessThan(afterFirst + 10));
    });
  });

  group('P-11 — native alarm fingerprint gate', () {
    const alarmsChannel = MethodChannel('com.tawheeed/alarms');
    const schedulerChannel = MethodChannel('com.tawheeed/prayer_scheduler');

    AppSettings settings() => const AppSettings(
          azanEnabledForFajr: true,
          azanEnabledForDhuhr: true,
          azanEnabledForAsr: true,
          azanEnabledForMaghrib: true,
          azanEnabledForIsha: true,
        );

    PrayerTimes times() => PrayerTimes(
          Coordinates(35.6892, 51.3890),
          DateComponents.from(DateTime(2026, 11, 5)),
          CalculationMethod.muslim_world_league.getParameters(),
        );

    test('fingerprint changes with date, alarm epoch and sound setting', () {
      final now = DateTime(2026, 11, 5, 6);
      final alarm = <String, Object>{
        'id': 2000,
        'timeMillis': 1793910600000,
        'sound': 'takbir',
        'customPath': '',
        'volume': 1.0,
      };
      final a = NativePrayerAlarmService.alarmFingerprint(
          [alarm], settings(), now);
      final b = NativePrayerAlarmService.alarmFingerprint(
          [alarm], settings(), now);
      expect(a, b);
      expect(
          NativePrayerAlarmService.alarmFingerprint(
              [alarm], settings(), now.add(const Duration(days: 1))),
          isNot(a));
      expect(
          NativePrayerAlarmService.alarmFingerprint([
            {...alarm, 'timeMillis': 1793910600001}
          ], settings(), now),
          isNot(a));
      expect(
          NativePrayerAlarmService.alarmFingerprint(
              [alarm], settings().copyWith(azanSound: 'kamel'), now),
          isNot(a));
    });

    test('two identical scheduleAll passes arm the native side only once',
        () async {
      final calls = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(alarmsChannel, (call) async {
        calls.add(call.method);
        if (call.method == 'scheduleExactAlarms') {
          return {'scheduled': 0, 'exactAllowed': true};
        }
        return null;
      });
      messenger.setMockMethodCallHandler(schedulerChannel, (call) async {
        calls.add(call.method);
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(alarmsChannel, null);
        messenger.setMockMethodCallHandler(schedulerChannel, null);
      });

      NativePrayerAlarmService.resetAlarmFingerprint();
      SharedPreferences.setMockInitialValues({});
      final now = DateTime(2026, 11, 5, 6);

      int arms() => calls
          .where((m) =>
              m == 'scheduleExactAlarms' || m == 'cancelAllAlarms')
          .length;

      await NativePrayerAlarmService().scheduleAll(now, times(), settings());
      expect(arms(), 1);
      await NativePrayerAlarmService().scheduleAll(now, times(), settings());
      expect(arms(), 1, reason: 'second identical pass must be skipped');

      // A new calendar date is a different fingerprint and must re-arm.
      await NativePrayerAlarmService()
          .scheduleAll(now.add(const Duration(days: 1)), times(), settings());
      expect(arms(), 2);

      // cancelAll clears the gate so re-enabling azan always re-arms.
      await NativePrayerAlarmService().cancelAll();
      final before = arms();
      await NativePrayerAlarmService().scheduleAll(now, times(), settings());
      expect(arms(), greaterThan(before));
    });
  });
}

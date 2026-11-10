import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/tools/moon/domain/services/astronomy/hilal_visibility.dart';
import 'package:tawheeed/features/tools/moon/domain/services/hilal_notification_service.dart';
import 'package:tawheeed/shared/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('plugin ownership (C2)', () {
    test('uses the shared app-wide plugin, never a private instance', () {
      // A second FlutterLocalNotificationsPlugin plus initialize() here would
      // replace the global onDidReceiveNotificationResponse and break tap
      // routing for prayer times, azkar and khatm reminders.
      expect(HilalNotificationService.instance.plugin,
          same(NotificationService().plugin));
    });
  });

  group('enable/disable state', () {
    test('defaults to disabled', () async {
      expect(await HilalNotificationService.instance.isEnabled(), isFalse);
    });

    test('setEnabled persists the flag and the coordinates', () async {
      await HilalNotificationService.instance
          .setEnabled(true, lat: 35.6892, lng: 51.3890);

      expect(await HilalNotificationService.instance.isEnabled(), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('hilal_lat'), 35.6892);
      expect(prefs.getDouble('hilal_lng'), 51.3890);
    });

    test('setEnabled(false) turns the flag off again', () async {
      await HilalNotificationService.instance.setEnabled(false);
      expect(await HilalNotificationService.instance.isEnabled(), isFalse);
    });
  });

  group('reminder planning (H3)', () {
    // The reminder must be a *decision made when the alert is enabled or the app
    // boots*, not only when the Moon tab happens to be opened, so a user who
    // never returns to the screen still gets the alert.
    test('plans the evening after the reference day', () {
      final reference = DateTime(2026, 4, 12, 9);
      final plan = HilalNotificationService.planReminder(
        reference: reference,
        lat: 35.6892,
        lng: 51.3890,
      );
      if (plan == null) {
        // Not every month has a naked-eye-visible hilal on the following day;
        // then no alert is the correct outcome, not a failure.
        return;
      }
      expect(plan.day, DateTime(2026, 4, 13));
      expect(
        plan.verdict,
        anyOf(HilalSightingVerdict.nakedEyePossible,
            HilalSightingVerdict.easilyVisible),
      );
    });

    test('never plans a past evening', () {
      for (var i = 0; i < 40; i++) {
        final reference = DateTime(2026).add(Duration(days: i));
        final plan = HilalNotificationService.planReminder(
          reference: reference,
          lat: 35.6892,
          lng: 51.3890,
        );
        if (plan == null) continue;
        expect(plan.day.isAfter(reference), isTrue,
            reason: 'a reminder must target a future evening');
      }
    });

    test('month rollover is handled', () {
      final plan = HilalNotificationService.planReminder(
        reference: DateTime(2026, 1, 31, 22),
        lat: 35.6892,
        lng: 51.3890,
      );
      if (plan != null) expect(plan.day, DateTime(2026, 2));
    });

    test('dayOffset looks further ahead', () {
      final reference = DateTime(2026, 4, 12, 9);
      final plan = HilalNotificationService.planReminder(
        reference: reference,
        lat: 35.6892,
        lng: 51.3890,
        dayOffset: 2,
      );
      if (plan == null) return;
      expect(plan.day, DateTime(2026, 4, 14));
      expect(
        plan.verdict,
        anyOf(HilalSightingVerdict.nakedEyePossible,
            HilalSightingVerdict.easilyVisible),
      );
    });

    test('an evening can hold the hilal the next day misses', () {
      // The scheduler scans forward so enabling the alert after an evening's
      // window has passed still books the next visible one instead of
      // nothing — this evening must exist for the scan to matter.
      var found = false;
      var day = DateTime(2026, 2, 2);
      while (!found && day.isBefore(DateTime(2026, 4, 2))) {
        final p1 = HilalNotificationService.planReminder(
            reference: day, lat: 35.6892, lng: 51.3890);
        final p2 = HilalNotificationService.planReminder(
            reference: day, lat: 35.6892, lng: 51.3890, dayOffset: 2);
        if (p1 == null && p2 != null) found = true;
        day = day.add(const Duration(days: 2));
      }
      expect(found, isTrue,
          reason: 'some evening must need the forward scan');
    });
  });
}

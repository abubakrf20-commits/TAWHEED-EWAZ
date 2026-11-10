import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/shared/models/scheduled_notification.dart';

void main() {
  final now = DateTime(2026, 7, 10, 14);

  group('ScheduledNotification', () {
    test('constructor sets all fields', () {
      final notification = ScheduledNotification(
        id: 1,
        type: 'prayer',
        title: 'Fajr Time',
        body: 'Time for Fajr prayer',
        scheduledTime: now,
        payload: 'fajr',
      );
      expect(notification.id, 1);
      expect(notification.type, 'prayer');
      expect(notification.title, 'Fajr Time');
      expect(notification.body, 'Time for Fajr prayer');
      expect(notification.scheduledTime, now);
      expect(notification.payload, 'fajr');
    });

    test('payload can be null', () {
      final notification = ScheduledNotification(
        id: 2,
        type: 'azkar',
        title: 'Morning Azkar',
        body: 'Time for morning azkar',
        scheduledTime: now,
      );
      expect(notification.payload, isNull);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/home/domain/entities/calendar_event.dart';

void main() {
  group('CalendarEvent', () {
    test('constructor sets all fields', () {
      const event = CalendarEvent(
        title: 'Eid al-Fitr',
        date: '2026-04-20',
      );
      expect(event.title, 'Eid al-Fitr');
      expect(event.date, '2026-04-20');
    });
  });
}

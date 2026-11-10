import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/shared/models/day_time.dart';

void main() {
  group('DayTime', () {
    group('constructor', () {
      test('creates instance with hour and minute', () {
        const dt = DayTime(hour: 10, minute: 30);
        expect(dt.hour, 10);
        expect(dt.minute, 30);
      });
    });

    group('fromString', () {
      test('parses HH:MM correctly', () {
        final dt = DayTime.fromString('14:05');
        expect(dt.hour, 14);
        expect(dt.minute, 5);
      });

      test('parses 00:00 correctly', () {
        final dt = DayTime.fromString('00:00');
        expect(dt.hour, 0);
        expect(dt.minute, 0);
      });

      test('parses 23:59 correctly', () {
        final dt = DayTime.fromString('23:59');
        expect(dt.hour, 23);
        expect(dt.minute, 59);
      });
    });

    group('equality', () {
      test('equal instances have same hashCode', () {
        const a = DayTime(hour: 8, minute: 15);
        const b = DayTime(hour: 8, minute: 15);
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different minutes are not equal', () {
        const a = DayTime(hour: 8, minute: 15);
        const b = DayTime(hour: 8, minute: 20);
        expect(a, isNot(equals(b)));
      });

      test('different hours are not equal', () {
        const a = DayTime(hour: 8, minute: 15);
        const b = DayTime(hour: 9, minute: 15);
        expect(a, isNot(equals(b)));
      });
    });

    group('toHHmm', () {
      test('formats correctly with zero padding', () {
        expect(const DayTime(hour: 6, minute: 5).toHHmm(), '06:05');
      });

      test('formats correctly without padding needed', () {
        expect(const DayTime(hour: 12, minute: 30).toHHmm(), '12:30');
      });

      test('formats midnight correctly', () {
        expect(const DayTime(hour: 0, minute: 0).toHHmm(), '00:00');
      });
    });

    group('toString', () {
      test('returns HH:MM format', () {
        expect(const DayTime(hour: 7, minute: 3).toString(), '07:03');
      });
    });

    group('add', () {
      test('adds minutes correctly', () {
        final dt = const DayTime(hour: 10, minute: 0).add(minutes: 45);
        expect(dt.hour, 10);
        expect(dt.minute, 45);
      });

      test('adds hours correctly', () {
        final dt = const DayTime(hour: 10, minute: 0).add(hours: 3);
        expect(dt.hour, 13);
        expect(dt.minute, 0);
      });

      test('wraps around midnight', () {
        final dt = const DayTime(hour: 23, minute: 30).add(minutes: 45);
        expect(dt.hour, 0);
        expect(dt.minute, 15);
      });

      test('wraps around multiple days', () {
        final dt = const DayTime(hour: 22, minute: 0).add(hours: 5);
        expect(dt.hour, 3);
        expect(dt.minute, 0);
      });

      test('adds both hours and minutes', () {
        final dt =
            const DayTime(hour: 9, minute: 30).add(hours: 2, minutes: 15);
        expect(dt.hour, 11);
        expect(dt.minute, 45);
      });

      test('adds zero by default', () {
        final dt = const DayTime(hour: 5, minute: 30).add();
        expect(dt.hour, 5);
        expect(dt.minute, 30);
      });
    });

    group('hashCode', () {
      test('is consistent for equal instances', () {
        const a = DayTime(hour: 12, minute: 0);
        const b = DayTime(hour: 12, minute: 0);
        expect(a.hashCode, b.hashCode);
      });

      test('differs when minutes differ', () {
        const a = DayTime(hour: 12, minute: 0);
        const b = DayTime(hour: 12, minute: 1);
        expect(a.hashCode, isNot(b.hashCode));
      });
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/shared/models/day_time.dart';
import 'package:tawheeed/features/prayer/domain/entities/prayer_info.dart';

void main() {
  group('PrayerInfo', () {
    const time = DayTime(hour: 12, minute: 0);

    test('constructor sets all fields', () {
      const pi = PrayerInfo(
        name: 'fajr',
        arabicName: 'فجر',
        time: DayTime(hour: 5, minute: 0),
        isCompleted: true,
        notificationMinutesBefore: 10,
      );
      expect(pi.name, 'fajr');
      expect(pi.arabicName, 'فجر');
      expect(pi.time, const DayTime(hour: 5, minute: 0));
      expect(pi.isCompleted, true);
      expect(pi.notificationMinutesBefore, 10);
    });

    test('default values', () {
      const pi = PrayerInfo(name: 'fajr', arabicName: 'فجر', time: time);
      expect(pi.isCompleted, false);
      expect(pi.notificationMinutesBefore, 5);
    });

    group('copyWith', () {
      test('creates new object with same field values when no args', () {
        const pi = PrayerInfo(name: 'fajr', arabicName: 'فجر', time: time);
        final copy = pi.copyWith();
        expect(copy.name, pi.name);
        expect(copy.arabicName, pi.arabicName);
        expect(copy.time, pi.time);
      });

      test('replaces single field', () {
        const pi = PrayerInfo(name: 'fajr', arabicName: 'فجر', time: time);
        final copy = pi.copyWith(isCompleted: true);
        expect(copy.isCompleted, true);
        expect(copy.name, 'fajr');
      });

      test('replaces all fields', () {
        const pi = PrayerInfo(name: 'fajr', arabicName: 'فجر', time: time);
        final copy = pi.copyWith(
          name: 'maghrib',
          arabicName: 'مغرب',
          time: const DayTime(hour: 18, minute: 0),
          isCompleted: true,
          notificationMinutesBefore: 15,
        );
        expect(copy.name, 'maghrib');
        expect(copy.arabicName, 'مغرب');
        expect(copy.time, const DayTime(hour: 18, minute: 0));
        expect(copy.isCompleted, true);
        expect(copy.notificationMinutesBefore, 15);
      });
    });
  });

  group('PrayerTimes', () {
    final date = DateTime(2026, 7, 10);
    PrayerInfo makeInfo(String name) => PrayerInfo(
          name: name,
          arabicName: name,
          time: const DayTime(hour: 12, minute: 0),
        );

    test('constructor sets all fields', () {
      final pt = PrayerTimes(
        date: date,
        fajr: makeInfo('fajr'),
        shorouq: makeInfo('shorouq'),
        duhr: makeInfo('duhr'),
        asr: makeInfo('asr'),
        maghrib: makeInfo('maghrib'),
        isha: makeInfo('isha'),
        locationCity: 'Tehran',
        latitude: 35.7,
        longitude: 51.4,
      );
      expect(pt.date, date);
      expect(pt.fajr.name, 'fajr');
      expect(pt.locationCity, 'Tehran');
      expect(pt.latitude, 35.7);
      expect(pt.longitude, 51.4);
    });

    test('optional fields default to null', () {
      final pt = PrayerTimes(
        date: date,
        fajr: makeInfo('fajr'),
        shorouq: makeInfo('shorouq'),
        duhr: makeInfo('duhr'),
        asr: makeInfo('asr'),
        maghrib: makeInfo('maghrib'),
        isha: makeInfo('isha'),
      );
      expect(pt.locationCity, isNull);
      expect(pt.latitude, isNull);
      expect(pt.longitude, isNull);
    });

    group('copyWith', () {
      test('replaces single field', () {
        final pt = PrayerTimes(
          date: date,
          fajr: makeInfo('fajr'),
          shorouq: makeInfo('shorouq'),
          duhr: makeInfo('duhr'),
          asr: makeInfo('asr'),
          maghrib: makeInfo('maghrib'),
          isha: makeInfo('isha'),
        );
        final copy = pt.copyWith(locationCity: 'Qom');
        expect(copy.locationCity, 'Qom');
        expect(copy.date, date);
      });
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/home/domain/entities/widget_snapshot.dart';

void main() {
  group('WidgetSnapshot', () {
    test('constructor sets all fields', () {
      const snapshot = WidgetSnapshot(
        nextPrayerName: 'ظهر',
        nextPrayerMinutes: 45,
        nextPrayerTime: '12:30',
        shamsiDate: '19 تیر 1405',
        gregorianDate: '2026-07-10',
        hijriDate: '24 محرم 1448',
        cityName: 'Tehran',
        prayers: {
          'فجر': '05:00',
          'ظهر': '12:30',
          'عصر': '16:00',
          'مغرب': '19:45',
          'عشاء': '21:15',
        },
        sunrise: '06:15',
        sunset: '19:45',
        azanSound: 'kamel',
        tasbihDhikr: 'سبحان الله',
        tasbihCount: 33,
        tasbihTarget: 100,
        tasbihActive: true,
        tasbihZikrIndex: 0,
        tasbihZikrList: ['سبحان الله', 'الحمد لله', 'الله أكبر'],
        tasbihZikrTargets: [100, 33, 33],
        syncTimestamp: 1712345678,
        khatmActive: true,
        khatmPagesToday: 3,
        khatmDailyTarget: 8,
        calcLatitude: 35.6892,
        calcLongitude: 51.3890,
        calcMethod: 'tehran',
        calcFajrAngle: 17.7,
        calcIshaAngle: 14.0,
        calcMaghribAngle: 4.5,
        calcMadhab: 1,
        calcHighLatitude: 2,
        calcMethodAdjustments: [0, 0, 1, 0, 0, 0],
        calcUserAdjustments: [0, 0, 1, 0, 2, 0],
        calcHijriOffset: 0,
      );
      expect(snapshot.nextPrayerName, 'ظهر');
      expect(snapshot.nextPrayerMinutes, 45);
      expect(snapshot.nextPrayerTime, '12:30');
      expect(snapshot.shamsiDate, '19 تیر 1405');
      expect(snapshot.gregorianDate, '2026-07-10');
      expect(snapshot.hijriDate, '24 محرم 1448');
      expect(snapshot.cityName, 'Tehran');
      expect(snapshot.prayers['فجر'], '05:00');
      expect(snapshot.sunrise, '06:15');
      expect(snapshot.sunset, '19:45');
      expect(snapshot.azanSound, 'kamel');
      expect(snapshot.tasbihDhikr, 'سبحان الله');
      expect(snapshot.tasbihCount, 33);
      expect(snapshot.tasbihTarget, 100);
      expect(snapshot.tasbihActive, true);
      expect(snapshot.tasbihZikrIndex, 0);
      expect(snapshot.tasbihZikrList, ['سبحان الله', 'الحمد لله', 'الله أكبر']);
      expect(snapshot.tasbihZikrTargets, [100, 33, 33]);
      expect(snapshot.syncTimestamp, 1712345678);
      expect(snapshot.khatmActive, true);
      expect(snapshot.khatmPagesToday, 3);
      expect(snapshot.khatmDailyTarget, 8);
      expect(snapshot.calcLatitude, 35.6892);
      expect(snapshot.calcLongitude, 51.3890);
      expect(snapshot.calcMethod, 'tehran');
      expect(snapshot.calcFajrAngle, 17.7);
      expect(snapshot.calcIshaAngle, 14.0);
      expect(snapshot.calcMaghribAngle, 4.5);
      expect(snapshot.calcIshaInterval, 0);
      expect(snapshot.calcMadhab, 1);
      expect(snapshot.calcHighLatitude, 2);
      expect(snapshot.calcMethodAdjustments, [0, 0, 1, 0, 0, 0]);
      expect(snapshot.calcUserAdjustments, [0, 0, 1, 0, 2, 0]);
      expect(snapshot.calcHijriOffset, 0);
      expect(snapshot.azkarHaptic, true);
    });

    test('azkarHaptic carries the app haptic toggle to the widget payload', () {
      const snapshot = WidgetSnapshot(
        nextPrayerName: '',
        nextPrayerMinutes: 0,
        nextPrayerTime: '',
        shamsiDate: '',
        gregorianDate: '',
        hijriDate: '',
        cityName: '',
        prayers: {},
        sunrise: '',
        sunset: '',
        azanSound: '',
        tasbihDhikr: '',
        tasbihCount: 0,
        tasbihTarget: 33,
        tasbihActive: false,
        tasbihZikrIndex: 0,
        tasbihZikrList: [],
        azkarHaptic: false,
      );
      expect(snapshot.azkarHaptic, false);
      expect(snapshot.toMethodChannel()['azkarHaptic'], false);
    });

    test('syncTimestamp is null by default', () {
      const snapshot = WidgetSnapshot(
        nextPrayerName: 'ظهر',
        nextPrayerMinutes: 45,
        nextPrayerTime: '12:30',
        shamsiDate: '19 تیر 1405',
        gregorianDate: '2026-07-10',
        hijriDate: '24 محرم 1448',
        cityName: 'Tehran',
        prayers: {},
        sunrise: '06:00',
        sunset: '18:00',
        azanSound: 'default',
        tasbihDhikr: '',
        tasbihCount: 0,
        tasbihTarget: 0,
        tasbihActive: false,
        tasbihZikrIndex: 0,
        tasbihZikrList: [],
      );
      expect(snapshot.syncTimestamp, isNull);
    });

    group('prayerOrder', () {
      test('is in correct order', () {
        expect(
            WidgetSnapshot.prayerOrder, ['فجر', 'ظهر', 'عصر', 'مغرب', 'عشاء']);
      });
    });

    group('toMethodChannel', () {
      test('returns map with all keys', () {
        const snapshot = WidgetSnapshot(
          nextPrayerName: 'ظهر',
          nextPrayerMinutes: 45,
          nextPrayerTime: '12:30',
          shamsiDate: '19 تیر 1405',
          gregorianDate: '2026-07-10',
          hijriDate: '24 محرم 1448',
          cityName: 'Tehran',
          prayers: {'فجر': '05:00', 'ظهر': '12:30'},
          sunrise: '06:15',
          sunset: '19:45',
          azanSound: 'kamel',
          tasbihDhikr: 'سبحان الله',
          tasbihCount: 33,
          tasbihTarget: 100,
          tasbihActive: true,
          tasbihZikrIndex: 0,
          tasbihZikrList: ['سبحان الله'],
          tasbihZikrTargets: [100],
          syncTimestamp: 1712345678,
        );
        final map = snapshot.toMethodChannel();
        expect(map['nextPrayerName'], 'ظهر');
        expect(map['prayer1'], contains('فجر'));
        expect(map['sunrise'], '06:15');
        expect(map['azanSound'], 'kamel');
        expect(map['tasbihCount'], 33);
        expect(map['tasbihActive'], true);
        expect(map['tasbihDhikr'], 'سبحان الله');
        expect(map['tasbihTarget'], 100);
        expect(map['tasbihZikrList'], isA<List>());
        expect(map['tasbihZikrTargets'], [100]);
        expect(map['khatmActive'], false);
        expect(map['khatmPagesToday'], 0);
        expect(map['khatmDailyTarget'], 0);
        // Native self-refresh inputs are serialized for the Kotlin side.
        expect(map['calcLatitude'], isNull);
        expect(map['calcLongitude'], isNull);
        expect(map['calcMethod'], 'muslimWorldLeague');
        expect(map['calcFajrAngle'], 18.0);
        expect(map['calcIshaAngle'], 17.0);
        expect(map['calcMaghribAngle'], 0);
        expect(map['calcIshaInterval'], 0);
        expect(map['calcMadhab'], 0);
        expect(map['calcHighLatitude'], 0);
        expect(map['calcMethodAdjustments'], [0, 0, 0, 0, 0, 0]);
        expect(map['calcUserAdjustments'], [0, 0, 0, 0, 0, 0]);
        expect(map['calcHijriOffset'], 2);
        // Widget paint contract: the four ARGB channels are always sent so a
        // switch back to an «خودکار» palette can clear a stale override, while
        // the times payload is omitted (not null) when it was never built —
        // `persistSnapshot` only writes the keys it receives.
        expect(map['accentArgb'], 0);
        expect(map['textArgb'], 0);
        expect(map['bgArgb'], 0);
        expect(map['bgEndArgb'], 0);
        expect(map.containsKey('prayerTimesJson'), isFalse);
      });

      test('sends the times payload when one was built', () {
        const snapshot = WidgetSnapshot(
          nextPrayerName: 'ظهر',
          nextPrayerMinutes: 45,
          nextPrayerTime: '12:30',
          shamsiDate: '19 تیر 1405',
          gregorianDate: '2026-07-10',
          hijriDate: '24 محرم 1448',
          cityName: 'Tehran',
          prayers: {},
          sunrise: '06:00',
          sunset: '18:00',
          azanSound: 'default',
          tasbihDhikr: '',
          tasbihCount: 0,
          tasbihTarget: 0,
          tasbihActive: false,
          tasbihZikrIndex: 0,
          tasbihZikrList: [],
          accentArgb: 0xFFC9A94E,
          prayerTimesJson: '{"date":"2026-10-26"}',
        );
        final map = snapshot.toMethodChannel();
        expect(map['accentArgb'], 0xFFC9A94E);
        expect(map['prayerTimesJson'], '{"date":"2026-10-26"}');
      });
    });
  });
}

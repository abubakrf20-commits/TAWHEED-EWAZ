import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/adhkar/domain/entities/zikr_item.dart';

void main() {
  group('ZikrItem', () {
    const item = ZikrItem(
      id: '1',
      title: 'SubhanAllah',
      arabicText: 'سبحان الله',
      translation: 'Glory be to Allah',
      source: 'Quran',
      period: PrayerPeriod.morningAzkar,
      count: 33,
      daleel: 'Surah Al-Ikhlas',
      repeatCount: 3,
      virtue: 'Great virtue',
    );

    test('constructor sets all fields', () {
      expect(item.id, '1');
      expect(item.title, 'SubhanAllah');
      expect(item.arabicText, 'سبحان الله');
      expect(item.translation, 'Glory be to Allah');
      expect(item.source, 'Quran');
      expect(item.period, PrayerPeriod.morningAzkar);
      expect(item.count, 33);
      expect(item.isCompleted, false);
      expect(item.daleel, 'Surah Al-Ikhlas');
      expect(item.repeatCount, 3);
      expect(item.virtue, 'Great virtue');
    });

    test('default values', () {
      const item = ZikrItem(
        id: '2',
        title: 'Alhamdulillah',
        arabicText: 'الحمد لله',
        translation: 'Praise be to Allah',
        source: 'Quran',
        period: PrayerPeriod.fajr,
      );
      expect(item.count, isNull);
      expect(item.isCompleted, false);
      expect(item.daleel, '');
      expect(item.repeatCount, 1);
      expect(item.virtue, '');
    });

    group('copyWith', () {
      test('creates new object with same field values when no args', () {
        final copy = item.copyWith();
        expect(copy.id, item.id);
        expect(copy.title, item.title);
        expect(copy.arabicText, item.arabicText);
        expect(copy.period, item.period);
      });

      test('replaces single field', () {
        final copy = item.copyWith(isCompleted: true);
        expect(copy.isCompleted, true);
        expect(copy.title, 'SubhanAllah');
      });

      test('replaces period', () {
        final copy = item.copyWith(period: PrayerPeriod.isha);
        expect(copy.period, PrayerPeriod.isha);
      });

      test('sets count from null', () {
        const minimal = ZikrItem(
          id: '3',
          title: 'Allahu Akbar',
          arabicText: 'الله أكبر',
          translation: 'Allah is Great',
          source: 'Quran',
          period: PrayerPeriod.night,
        );
        final copy = minimal.copyWith(count: 100);
        expect(copy.count, 100);
      });
    });
  });
}

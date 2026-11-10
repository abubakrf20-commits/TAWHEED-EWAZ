import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/shared/services/friday_content.dart';
import 'package:tawheeed/shared/utils/friday_prayer_label.dart';

/// 2026-09-25 یک جمعه است (جمعه‌ها هر ۷ روز تکرار می‌شوند).
final _friday = DateTime(2026, 9, 25, 10, 30);
final _saturday = DateTime(2026, 9, 26, 10, 30);
final _thursday = DateTime(2026, 9, 24, 10, 30);

void main() {
  group('fridayPrayerLabel', () {
    test('روزهای غیرجمعه دست‌نخورده می‌مانند', () {
      for (final day in [_saturday, _thursday]) {
        expect(fridayPrayerLabel('ظهر', day), 'ظهر');
        expect(fridayPrayerLabel('اذان ظهر', day), 'اذان ظهر');
        expect(fridayPrayerLabel('عصر', day), 'عصر');
      }
    });

    test('در جمعه «ظهر» به «جمعه» تبدیل می‌شود', () {
      expect(fridayPrayerLabel('ظهر', _friday), 'جمعه');
      expect(fridayPrayerLabel('duhr', _friday), 'جمعه');
      expect(fridayPrayerLabel('dhuhr', _friday), 'جمعه');
    });

    test('در جمعه نسبت «اذان» حفظ می‌شود', () {
      expect(fridayPrayerLabel('اذان ظهر', _friday), 'اذان جمعه');
      expect(fridayPrayerLabel('نماز ظهر', _friday), 'نماز جمعه');
    });

    test('نام بقیه نمازها در جمعه هم تغییر نمی‌کند', () {
      for (final label in [
        'اذان صبح',
        'فجر',
        'طلوع',
        'عصر',
        'اذان عصر',
        'مغرب',
        'عشاء',
      ]) {
        expect(fridayPrayerLabel(label, _friday), label, reason: label);
      }
    });

    test('جمعه بر اساس تقویم میلادیِ هفته تشخیص داده می‌شود', () {
      expect(isJumuahDay(_friday), isTrue);
      expect(isJumuahDay(_saturday), isFalse);
      expect(isJumuahDay(_thursday), isFalse);
    });

    test('نیمه‌شب جمعه هم جمعه است', () {
      expect(fridayPrayerLabel('ظهر', DateTime(2026, 9, 25)), 'جمعه');
      expect(fridayPrayerLabel('ظهر', DateTime(2026, 9, 25, 23, 59)), 'جمعه');
    });

    test('isDhuhrLabel فقط نام ظهر را تشخیص می‌دهد', () {
      expect(isDhuhrLabel('ظهر'), isTrue);
      expect(isDhuhrLabel('اذان ظهر'), isTrue);
      expect(isDhuhrLabel('عصر'), isFalse);
      expect(isDhuhrLabel('طلوع'), isFalse);
    });
  });

  group('FridayContent', () {
    test('جمعه را درست تشخیص می‌دهد', () {
      expect(FridayContent.isFriday(_friday), isTrue);
      expect(FridayContent.isFriday(_saturday), isFalse);
    });

    test('حداقل یک آداب و یک حدیث دارد', () {
      expect(FridayContent.adabs, isNotEmpty);
      expect(FridayContent.hadiths, isNotEmpty);
    });

    test('حدیث، زیر همان آداب خودش می‌آید و منبع دارد', () {
      expect(FridayContent.adabs.first.hadith, isNotNull);
      for (final a in FridayContent.adabs) {
        final h = a.hadith;
        if (h != null) {
          expect(h.arabic.trim(), isNotEmpty, reason: a.title);
          expect(h.translation.trim(), isNotEmpty, reason: a.title);
          expect(h.source.trim(), isNotEmpty, reason: a.title);
        }
      }
    });

    test('روایت‌های ضعیف و ساختگی حذف شده‌اند', () {
      final allText = [
        for (final a in FridayContent.adabs) '${a.title} ${a.detail}',
        for (final h in FridayContent.hadiths)
          '${h.arabic} ${h.translation} ${h.source}',
      ].join(' ');
      expect(allText, isNot(contains('سبعین')));
      expect(allText, isNot(contains('بدء النهار')));
      expect(allText, isNot(contains('أفضل ما قلنا')));
      expect(allText, isNot(contains('صَامَ')));
      expect(allText, isNot(contains('دختر آفتاب')));
      expect(allText, isNot(contains('زیارت')));
    });

    test('همهٔ آداب‌ها عنوان و توضیح پر دارند', () {
      for (final a in FridayContent.adabs) {
        expect(a.title.trim(), isNotEmpty);
        expect(a.detail.trim(), isNotEmpty);
      }
    });

    test('همهٔ احادیث سه بخش دارند', () {
      for (final h in FridayContent.hadiths) {
        expect(h.arabic.trim(), isNotEmpty, reason: h.arabic);
        expect(h.translation.trim(), isNotEmpty, reason: h.arabic);
        expect(h.source.trim(), isNotEmpty, reason: h.arabic);
      }
    });

    test('متن اعلان ساخته می‌شود و خالی نیست', () {
      final body = FridayContent.notificationBody;
      expect(body.trim(), isNotEmpty);
      expect(body, contains(FridayContent.hadiths.first.arabic));
    });

    test('متن اعلان پایدار است (بین دو فراخوانی یکسان)', () {
      expect(FridayContent.notificationBody, FridayContent.notificationBody);
    });
  });
}

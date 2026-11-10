import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/ruqyah/data/ruqyah_content.dart';
import 'package:tawheeed/features/ruqyah/data/ruqyah_practical_content.dart';

void main() {
  group('RuqyahPracticalContent', () {
    test('has all four practical sections in order', () {
      const sections = RuqyahPracticalContent.sections;
      expect(sections, hasLength(4));
      expect(sections[0].title, 'بخش اول: آیات قرآن کریم در رقیه شرعی');
      expect(sections[1].title, 'بخش دوم: دعاهای مأثور در رقیه شرعی');
      expect(
          sections[2].title, 'بخش سوم: دستورالعمل کامل رقیه شرعی (صفة الرقیة)');
      expect(sections[3].title, 'بخش چهارم: اذکار و دعاهای حفاظتی روزانه');
    });

    test('hadiths were moved to the study chapters, not duplicated', () {
      // No hadiths section in the practical content anymore.
      final titles =
          RuqyahPracticalContent.sections.map((s) => s.title).join(' | ');
      expect(titles, isNot(contains('احادیث')));
      // The full hadiths now live under فصل اول of the study chapters.
      final sunnaItems = RuqyahContent.chapters.first.items
          .where((i) =>
              (i.title ?? '').contains('جواز رقیه') ||
              (i.title ?? '').contains('چشم زخم حق') ||
              (i.title ?? '').contains('نفث و دعا بر بیمار'))
          .toList();
      expect(sunnaItems.length, greaterThanOrEqualTo(3));
    });

    test('verses section contains the full ruqyah verse set', () {
      final verses = RuqyahPracticalContent.sections[0].items;
      expect(verses.length, greaterThanOrEqualTo(18));
      expect(verses.first.title, 'سوره فاتحه (7 آیه)');
      // Full Arabic text of Al-Fatiha with all 7 ayah markers.
      expect(verses.first.arabic, contains('﴿١﴾'));
      expect(verses.first.arabic, contains('﴿٧﴾'));
      // Key verses present.
      final titles = verses.map((v) => v.title).join(' | ');
      expect(titles, contains('آیه الکرسی'));
      expect(titles, contains('آیه 102 (آیه سحر)'));
      expect(titles, contains('سوره اخلاص (4 آیه)'));
      expect(titles, contains('سوره فلق (5 آیه)'));
      expect(titles, contains('سوره ناس (6 آیه)'));
    });

    test('every Arabic block has content and translations are present', () {
      for (final section in RuqyahPracticalContent.sections) {
        expect(section.items, isNotEmpty,
            reason: '${section.title} must not be empty');
        for (final item in section.items) {
          if (item.arabic != null) {
            expect(item.arabic!.trim(), isNotEmpty);
          }
          if (item.translation != null) {
            expect(item.translation!.trim(), isNotEmpty);
          }
        }
      }
    });

    test('study chapters no longer duplicate the practical verses/duas', () {
      final chapterTitles =
          RuqyahContent.chapters.map((c) => c.title).join(' | ');
      expect(chapterTitles, isNot(contains('فصل نهم')));
      expect(chapterTitles, isNot(contains('فصل دهم')));
      // The last study chapter is correctly numbered هشتم (not jumping 7 → 10).
      expect(chapterTitles, contains('فصل هشتم'));
    });
  });
}

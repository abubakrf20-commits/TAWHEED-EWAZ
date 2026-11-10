import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/shared/services/daily_content_format.dart';
import 'package:tawheeed/shared/services/daily_hadith_source.dart';
import 'package:tawheeed/shared/services/daily_verse_source.dart';
import 'package:tawheeed/shared/utils/persian_text.dart';

void main() {
  group('dailyContentBody', () {
    test('text + translation + source when translation differs', () {
      final body = dailyContentBody(
        text: 'اعمال با نیت‌ها هستند',
        ref: 'متفق علیه',
        trans: 'همانا اعمال به نیت‌هاست',
      );
      expect(body, 'اعمال با نیت ها هستند\nهمانا اعمال به نیت هاست\nمتفق علیه');
    });

    test('skips translation when it equals the text (Persian-only)', () {
      final body = dailyContentBody(
        text: 'دین نصیحت است',
        ref: 'صحیح مسلم، شماره ۵۵',
        trans: 'دین نصیحت است',
      );
      expect(body, 'دین نصیحت است\nصحیح مسلم، شماره 55');
    });

    test('skips empty translation', () {
      final body = dailyContentBody(
        text: 'دین نصیحت است',
        ref: 'صحیح مسلم، شماره ۵۵',
        trans: '',
      );
      expect(body, 'دین نصیحت است\nصحیح مسلم، شماره 55');
    });

    test('replaces نیم‌فاصله with a space so words render separately', () {
      final body = dailyContentBody(
        text: 'خوش\u200Cاخلاق\u200Cترین',
        ref: 'منبع',
        trans: '',
      );
      expect(body, 'خوش اخلاق ترین\nمنبع');
      expect(body.contains('\u200C'), isFalse);
    });
  });

  group('dailyContentTail', () {
    test('translation then source, when translation differs', () {
      expect(
        dailyContentTail(text: 'نص', ref: 'منبع', trans: 'ترجمه'),
        'ترجمه\nمنبع',
      );
    });

    test('skips translation when it equals the text', () {
      expect(
        dailyContentTail(text: 'نص', ref: 'منبع', trans: 'نص'),
        'منبع',
      );
    });

    test('skips empty translation', () {
      expect(
        dailyContentTail(text: 'نص', ref: 'منبع', trans: ''),
        'منبع',
      );
    });
  });

  group('daily content sources', () {
    test('verse tail keeps translation then source; hadiths are text-only', () {
      for (final v in DailyVerseSource.dailyVerses) {
        final tail = dailyContentTail(
          text: v['verse'] ?? '',
          ref: v['ref'] ?? '',
          trans: v['trans'] ?? '',
        );
        expect(tail, isNotEmpty);
        expect(tail.contains(spacedZwnj(v['trans'] ?? '')),
            v['trans']?.isNotEmpty ?? false,
            reason: 'translation missing for $v');
        expect(tail.contains(spacedZwnj(v['ref'] ?? '')), isTrue,
            reason: 'source missing for $v');
      }
      for (final h in DailyHadithSource.dailyHadiths) {
        final tail = dailyContentTail(
          text: h['text'] ?? '',
          ref: h['ref'] ?? '',
          trans: h['trans'] ?? '',
        );
        // Hadiths are Persian-only: no translation, no source line.
        expect(tail, isEmpty, reason: 'hadith should have no tail: $h');
      }
    });

    test('verseForDate is deterministic for a fixed date', () {
      final date = DateTime(2026, 8, 15);
      final a = DailyVerseSource.verseForDate(date);
      final b = DailyVerseSource.verseForDate(date);
      expect(a['verse'], b['verse']);
    });

    test(
        'verse/hadith rotate across consecutive days (not the same item daily)',
        () {
      final start = DateTime(2026, 8, 15);
      final verseRefs = <String>[];
      final hadithTexts = <String>[];
      for (var i = 0; i < 30; i++) {
        final day = start.add(Duration(days: i));
        verseRefs.add(DailyVerseSource.verseForDate(day)['ref'] ?? '');
        hadithTexts.add(DailyHadithSource.hadithForDate(day)['text'] ?? '');
      }
      // Within a month, several different verses/hadiths must appear.
      expect(verseRefs.toSet().length, greaterThan(1),
          reason: 'daily verse should rotate, not repeat: $verseRefs');
      expect(hadithTexts.toSet().length, greaterThan(1),
          reason: 'daily hadith should rotate, not repeat: $hadithTexts');
      // And consecutive days must differ at least somewhere.
      var consecutiveChanges = 0;
      for (var i = 1; i < verseRefs.length; i++) {
        if (verseRefs[i] != verseRefs[i - 1]) consecutiveChanges++;
      }
      expect(consecutiveChanges, greaterThan(0));
    });
  });
}

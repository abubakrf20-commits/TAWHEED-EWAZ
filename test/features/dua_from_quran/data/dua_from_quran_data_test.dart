import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/dua_from_quran/data/dua_from_quran_data.dart';

void main() {
  group('DuaFromQuranData integrity', () {
    test('lists are not empty', () {
      expect(DuaFromQuranData.quranDuas, isNotEmpty);
      expect(DuaFromQuranData.sunnahDuas, isNotEmpty);
    });

    test('every dua has Arabic and Persian text', () {
      for (final dua in [
        ...DuaFromQuranData.quranDuas,
        ...DuaFromQuranData.sunnahDuas,
      ]) {
        expect(dua.arabic.trim(), isNotEmpty);
        expect(dua.persian.trim(), isNotEmpty);
      }
    });

    test('every quran dua cites a verse source', () {
      for (final dua in DuaFromQuranData.quranDuas) {
        expect(dua.source.trim(), isNotEmpty,
            reason:
                'missing source for dua #${DuaFromQuranData.quranDuas.indexOf(dua) + 1}');
      }
    });

    test('completed hadith duas include their full wording', () {
      const sunnah = DuaFromQuranData.sunnahDuas;
      expect(
          sunnah.any((d) => d.arabic.contains('وَمِن شَرِّ مَنِيِّ')), isTrue,
          reason: 'dua of senses must include «ومن شر منی»');
      expect(sunnah.any((d) => d.arabic.contains('وَحُبَّ عَمَلٍ يُقَرِّبُ')),
          isTrue,
          reason: 'dua of «فعل الخيرات» must include «وحب عمل يقرب إلى حبك»');
    });
  });
}

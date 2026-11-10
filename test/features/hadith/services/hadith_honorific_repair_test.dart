import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/hadith/services/hadith_db_service.dart';

/// The repair mapping of the publisher's legacy «islam» symbol-font glyphs.
/// The codes: F0C9/F072/F092 = «صلى الله عليه وسلم» calligraphy (F092 empty
/// outline), F0B8 = «رضي الله عنهما» (dual), F0C3 = «رضي الله عنه»,
/// F0CF = «رضي الله عنها», F05D = crescent ornament (deleted), read off the
/// embedded font itself.
void main() {
  group('repairLegacyHonorifics', () {
    test('replaces the صلوات glyphs with the full phrase', () {
      expect(repairLegacyHonorifics('قَالَ رَسُولُ اللهِ \uF0C9 قَالَ'),
          'قَالَ رَسُولُ اللهِ صلى الله عليه وسلم قَالَ');
      expect(repairLegacyHonorifics('عَنِ النَّبِيِّ \uF072 قَالَ'),
          'عَنِ النَّبِيِّ صلى الله عليه وسلم قَالَ');
      // F092: the font left the outline empty; its one position follows
      // «رسول الله».
      expect(repairLegacyHonorifics('أَنَّ رَسُولَ اللهِ \uF092 قَالَ'),
          'أَنَّ رَسُولَ اللهِ صلى الله عليه وسلم قَالَ');
    });

    test('replaces the dual (F0B8) with رضي الله عنهما', () {
      expect(repairLegacyHonorifics('از ابن عباس \uF0B8 روایت است'),
          'از ابن عباس رضي الله عنهما روایت است');
    });

    test('replaces the masculine (F0C3) with رضي الله عنه', () {
      expect(repairLegacyHonorifics('از ابوهریره \uF0C3 به صورت مختصر'),
          'از ابوهریره رضي الله عنه به صورت مختصر');
    });

    test('replaces the feminine (F0CF) with رضي الله عنها', () {
      expect(repairLegacyHonorifics('از عایشه \uF0CF روایت است'),
          'از عایشه رضي الله عنها روایت است');
    });

    test('deletes the crescent ornament (F05D) without inventing text', () {
      expect(repairLegacyHonorifics('قَالَ: «\uF05Dيَوْمَ الْقِيَامَةِ»'),
          'قَالَ: «يَوْمَ الْقِيَامَةِ»');
    });

    test('pads a glyph glued to its neighbours', () {
      // «ابوهریره [F0C3]به» — glued after.
      expect(repairLegacyHonorifics('أَبُو هُرَيْرَةَ \uF0C3بِهِ'),
          'أَبُو هُرَيْرَةَ رضي الله عنه بِهِ');
      // «العاص[F0B8] روایت» — glued before.
      expect(repairLegacyHonorifics('عَنِ ابْنِ عُمَرَ\uF0B8 عَنِ النَّبِيِّ'),
          'عَنِ ابْنِ عُمَرَ رضي الله عنهما عَنِ النَّبِيِّ');
      // «رسولالله[F072]» — glued after only.
      expect(repairLegacyHonorifics('قَالَ \uF072قَالَ'),
          'قَالَ صلى الله عليه وسلم قَالَ');
    });

    test('collapses a duplicated صلوات glyph pair', () {
      expect(repairLegacyHonorifics('قَالَ \uF0C9\uF0C9 قَالَ'),
          'قَالَ صلى الله عليه وسلم قَالَ');
    });

    test('the ابن عمر typo carries the dual form, as the book prints it', () {
      expect(repairLegacyHonorifics('از ابن عمر \uF0CF روایت شده'),
          'از ابن عمر رضي الله عنهما روایت شده');
    });

    test('leaves clean text byte-identical and is idempotent', () {
      const clean =
          'إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ وَإِنَّمَا لِكُلِّ امْرِئٍ مَا نَوَى';
      expect(repairLegacyHonorifics(clean), same(clean));
      final once = repairLegacyHonorifics('از ابن عباس \uF0B8 روایت');
      expect(repairLegacyHonorifics(once), same(once));
    });
  });
}

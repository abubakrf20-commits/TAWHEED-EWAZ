import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/quran/services/quran_content_service.dart';

void main() {
  group('QuranContentFile', () {
    test('fromJson parses a manifest entry', () {
      final f = QuranContentFile.fromJson({
        'id': 'tafsir_noor',
        'type': 'tafsir',
        'name': 'تفسیر نور',
        'fileName': 'noor.db',
        'sizeMB': 1.5,
        'compressed': true,
      });
      expect(f.id, 'tafsir_noor');
      expect(f.isTafsir, isTrue);
      expect(f.isTranslation, isFalse);
      expect(f.remoteName, 'noor.db.gz');
    });

    test('fromJson localizes the Persian translation author', () {
      final f = QuranContentFile.fromJson({
        'id': 'persian_translation',
        'type': 'translation',
        'name': 'Old English label',
        'fileName': 'persian_translation.json',
      });
      expect(f.name, 'ترجمهٔ فارسی — سایت اسلام هاوس');
    });

    test('fromJson localizes English tafsir ids', () {
      final f = QuranContentFile.fromJson({
        'id': 'tasheel',
        'type': 'tafsir',
        'name': 'tasheel',
        'fileName': 'tasheel.db',
      });
      expect(f.name, contains('التسهيل'));
      expect(f.name, isNot(contains('tasheel')));
    });

    test('fromJson tolerates missing optional fields', () {
      final f = QuranContentFile.fromJson({'id': 'x'});
      expect(f.type, isEmpty);
      expect(f.fileName, isEmpty);
      expect(f.compressed, isFalse);
    });
  });

  group('builtinCatalog', () {
    test('contains the Persian, Arabic and Kurdish tafsirs plus the three '
        'translations', () {
      final tafsirs =
          QuranContentService.builtinCatalog.where((f) => f.isTafsir).toList();
      final translations = QuranContentService.builtinCatalog
          .where((f) => f.isTranslation)
          .toList();
      final arabic = tafsirs.where((f) => f.lang == 'ar').toList();
      // 13 Arabic + 4 Persian + 2 Kurdish tafsirs; Persian + 2 Kurdish
      // translations. The Kurdish files are staged in the content repo
      // (TAWHEED-EWAZ/tafsir) — the catalog is written for them, and the
      // online manifest catches up when that repo is published.
      expect(tafsirs, hasLength(19));
      expect(arabic, hasLength(13));
      expect(translations, hasLength(3));
      expect(
          tafsirs.map((f) => f.id),
          containsAll([
            'mokhtasar_fa',
            'tafsir_noor',
            'tafsir_anwar',
            'tafsir_rastin',
            'safwa_tafasir',
            'fath_qadir',
            'mokhtasar_ibn_kathir',
            'baghawi',
            'asbab_nuzul',
            'adwa_albayan',
            'baydawi',
            'irab_alquran',
            'tasheel',
            'tahrir_ashur',
            'jalalain',
            'ibn_kathir',
            'tabari',
            'kurd_tafsir_rebar',
            'kurdish_mokhtasar',
          ]));
      expect(
          translations.map((f) => f.id),
          unorderedEquals([
            'persian_translation',
            'ku_burhan_muhammad_simple',
            'muhammad_saleh_bamoki_simple',
          ]));
      expect(
          translations.firstWhere((f) => f.id == 'persian_translation')
              .fileName,
          'persian_translation.json');
    });

    test('all hosted tafsir files are compressed gzip', () {
      for (final f in QuranContentService.builtinCatalog) {
        expect(f.compressed, isTrue, reason: f.id);
        expect(f.remoteName.endsWith('.gz'), isTrue, reason: f.id);
      }
    });
  });

  group('QuranContentService catalog caching', () {
    test(
        'fetchCatalog caches its result so the tafsir sheet never re-hits '
        'the network on every open', () async {
      // The manifest is static — the first call may hit the network (and in
      // a test falls back to builtinCatalog), every later call must return
      // the cached list without any HTTP. Opening the tafsir sheet calls
      // refreshDownloaded repeatedly; this is what made it slow.
      final first = await QuranContentService.fetchCatalog();
      expect(first, isNotEmpty);
      expect(QuranContentService.cachedCatalogOrNull, isNotNull);

      final second = await QuranContentService.fetchCatalog();
      expect(identical(first, second), isTrue,
          reason: 'second fetch must return the cached instance');
      expect(identical(first, QuranContentService.cachedCatalogOrNull), isTrue);
    });
  });
}

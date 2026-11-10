import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/features/quran/data/quran_helpers.dart';
import 'package:tawheeed/features/quran/services/mp3quran_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Mp3QuranReciter', () {
    test('builds URLs for the current EveryAyah catalog', () {
      const reciter = Mp3QuranReciter(
        identifier: 'everyayah:Alafasy_128kbps',
        name: 'مشاری العفاسی',
      );
      expect(reciter.verseUrl(2, 6),
          'https://everyayah.com/data/Alafasy_128kbps/002006.mp3');
      expect(reciter.verseUrl(114, 6),
          'https://everyayah.com/data/Alafasy_128kbps/114006.mp3');
    });

    test('keeps the global ayah counter contiguous at boundaries', () {
      expect(globalAyahNumber(1, 1), 1);
      expect(globalAyahNumber(2, 1), 8);
      expect(globalAyahNumber(114, getVerseCount(114)), 6236);
    });

    test('catalog is unique, usable, and contains key reciters', () {
      const catalog = Mp3QuranService.fallbackReciters;
      final ids = catalog.map((r) => r.identifier).toSet();
      expect(catalog.length, greaterThan(10));
      expect(ids.length, catalog.length);
      expect(
          ids,
          containsAll([
            'everyayah:Alafasy_128kbps',
            'everyayah:Husary_Mujawwad_64kbps',
            'everyayah:Minshawy_Murattal_128kbps',
          ]));
      for (final reciter in catalog) {
        expect(reciter.identifier, isNotEmpty);
        expect(reciter.name, isNotEmpty);
        expect(reciter.identifier.contains(' '), isFalse);
      }
    });
  });

  group('offline-forever marks', () {
    const reciter = 'everyayah:Alafasy_128kbps';
    const other = 'everyayah:Husary_128kbps';

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('mark/unmark round-trip per surah', () async {
      expect(await Mp3QuranService.isMarkedOffline(reciter, 2), isFalse);
      await Mp3QuranService.markSurahOffline(reciter, 2);
      expect(await Mp3QuranService.isMarkedOffline(reciter, 2), isTrue);
      // Other surahs and reciters are unaffected.
      expect(await Mp3QuranService.isMarkedOffline(reciter, 3), isFalse);
      expect(await Mp3QuranService.isMarkedOffline(other, 2), isFalse);
      await Mp3QuranService.unmarkSurahOffline(reciter, 2);
      expect(await Mp3QuranService.isMarkedOffline(reciter, 2), isFalse);
    });

    test('unmarkAllOffline clears only that reciter', () async {
      await Mp3QuranService.markSurahOffline(reciter, 1);
      await Mp3QuranService.markSurahOffline(reciter, 2);
      await Mp3QuranService.markSurahOffline(other, 1);
      await Mp3QuranService.unmarkAllOffline(reciter);
      expect(await Mp3QuranService.isMarkedOffline(reciter, 1), isFalse);
      expect(await Mp3QuranService.isMarkedOffline(reciter, 2), isFalse);
      expect(await Mp3QuranService.isMarkedOffline(other, 1), isTrue);
    });
  });
}

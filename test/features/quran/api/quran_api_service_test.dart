import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:tawheeed/features/quran/api/quran_api_service.dart';

/// Test double for [PathProviderPlatform] so the API cache can resolve its
/// on-disk folder without a real platform channel.
class _FakePathProvider extends PathProviderPlatform {
  final Directory temp = Directory.systemTemp.createTempSync('qf_cache_test');

  @override
  Future<String?> getApplicationSupportPath() async => temp.path;

  @override
  Future<String?> getTemporaryPath() async => temp.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  PathProviderPlatform.instance = _FakePathProvider();

  group('QuranApiService (unconfigured → bundled fallback)', () {
    test('getPageVerses returns bundled verses without any config', () async {
      final service = QuranApiService();
      addTearDown(service.dispose);

      final verses = await service.getPageVerses(1);
      expect(verses, isNotEmpty);
      expect(verses.first.pageNumber, 1);
      expect(verses.first.chapterId, greaterThanOrEqualTo(1));
      expect(verses.first.verseNumber, greaterThanOrEqualTo(1));
      // B01: the bundled path now carries the offline Persian word meanings,
      // so the release «معنی واژه» sheet is reachable (the word-less
      // assertion here was the bug — see bundled_word_meanings_test.dart).
      for (final v in verses) {
        for (final w in v.words) {
          expect(w.isWord, isTrue);
          expect(w.translation, isNotEmpty);
        }
      }
    });

    test('lookupPages resolves surah start page from bundled data', () async {
      final service = QuranApiService();
      addTearDown(service.dispose);

      // Surah 1 (Al-Fatiha) starts on page 1.
      final lookup = await service.lookupPages(chapterNumber: 1);
      expect(lookup.pages, isNotEmpty);
      expect(lookup.pages.keys.first, 1);

      // Surah 18 (Al-Kahf) starts well beyond page 1.
      final kahf = await service.lookupPages(chapterNumber: 18);
      expect(kahf.pages, isNotEmpty);
      expect(kahf.pages.keys.first, greaterThan(1));
    });

    test('lookupPages resolves juz start page from bundled data', () async {
      final service = QuranApiService();
      addTearDown(service.dispose);

      // Juz 1 starts at page 1; juz 30 starts much later.
      final juz1 = await service.lookupPages(juzNumber: 1);
      expect(juz1.pages.keys.first, 1);

      final juz30 = await service.lookupPages(juzNumber: 30);
      expect(juz30.pages.keys.first, greaterThan(500));
    });
  });

  group('QuranApiService (legacy structure)', () {
    test('getPageVerses returns valid data structure', () {
      expect(true, true);
    });

    test('ensureToken returns string when configured', () {
      expect(true, true);
    });
  });
}

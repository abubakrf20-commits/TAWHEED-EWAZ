import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/quran/data/quran_data.dart';
import 'package:tawheeed/features/quran/services/quran_search_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // متن قرآن از asset بارگذاری می‌شود (flutter_test asset‌های واقعی
    // پکیج را ارائه می‌دهد).
    await loadQuranData();
  });

  tearDownAll(QuranSearchService.resetForTest);

  group('QuranSearchService.search (fallback scan, no DB)', () {
    test('returns empty for blank or too-short queries', () {
      expect(QuranSearchService.search(''), isEmpty);
      expect(QuranSearchService.search('   '), isEmpty);
      expect(QuranSearchService.search('م'), isEmpty);
    });

    test('finds the first ayah for a word of Surah Al-Fatiha', () {
      final results = QuranSearchService.search('الرحمن');
      expect(results, isNotEmpty);
      final first = results.first;
      expect(first.surah, 1);
      expect(first.verse, 1);
      expect(first.page, 1);
      expect(first.textOriginal, isNotEmpty);
    });

    test('normalizes wasla/hamza alef forms in the query', () {
      // «ٱلذين» (wasla alef) normalizes to bare «الذين», so a wasla-typed
      // query must return the same verses as the bare-alef query.
      final withWasla = QuranSearchService.search('ٱلذين');
      final bare = QuranSearchService.search('الذين');
      expect(withWasla, isNotEmpty);
      expect(
        withWasla.map((r) => (r.surah, r.verse)),
        containsAll(bare.map((r) => (r.surah, r.verse))),
      );
    });

    test('surahFilter narrows every result to that surah', () {
      final results = QuranSearchService.search('الرحمن', surahFilter: 55);
      expect(results, isNotEmpty);
      expect(results.every((r) => r.surah == 55), isTrue);
    });

    test('limit caps the number of results', () {
      final all = QuranSearchService.search('الله');
      final limited = QuranSearchService.search('الله', limit: 5);
      expect(limited.length, lessThanOrEqualTo(5));
      expect(limited.length, greaterThan(0));
      expect(all.length, greaterThan(limited.length));
    });

    test('multi-word query requires all words in a verse', () {
      // Both «الله» and «الصمد» appear together only in Surah Al-Ikhlas.
      final results = QuranSearchService.search('الله الصمد');
      expect(results, isNotEmpty);
      expect(results.every((r) => r.surah == 112), isTrue);
    });

    test('mid-word «عرش» finds «العرش» verses even with no DB', () {
      // Regression: جستجوی «عرش» باید «العرش» را (وسط کلمه) بیابد؛ جستجوی
      // پیشوندی FTS به‌تنهایی هرگز این را نمی‌تواند. اسکن درون‌حافظه‌ای باید
      // آن را پوشش دهد.
      final results = QuranSearchService.search('عرش');
      expect(results, isNotEmpty);
      expect(
        results.map((r) => (r.surah, r.verse)),
        contains((7, 54)),
      );
    });

    test('«العرش» finds the Throne verses even with no DB', () {
      // Regression: جستجوی دقیق نباید با خطای ساخت ایندکس/FTS از بین برود —
      // جستجو نباید throw کند و نباید خالی برگردد.
      final results = QuranSearchService.search('العرش');
      expect(results, isNotEmpty);
      expect(
        results.map((r) => (r.surah, r.verse)),
        contains((7, 54)),
        reason: 'should include 7:54 (ثُمَّ اسْتَوَى عَلَى الْعَرْشِ)',
      );
      // No duplicate (surah, verse) — the merge layers must be deduplicated.
      final keys = results.map((r) => (r.surah, r.verse)).toSet();
      expect(keys.length, results.length);
    });
  });

  group('QuranSearchService.search (with DB)', () {
    late Directory tempDir;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('tawheeed_quran_search');
      QuranSearchService.debugDatabasePathOverride =
          '${tempDir.path}/quran_search.db';
      // Real init (SQLite + optional FTS5 + LIKE table + normalized cache).
      await QuranSearchService.prepare();
    });

    tearDownAll(() async {
      QuranSearchService.debugDatabasePathOverride = null;
      QuranSearchService.resetForTest();
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    });

    test('عرش matches the العرش verses through the DB layers', () async {
      final results = QuranSearchService.search('عرش');
      expect(results.length, greaterThanOrEqualTo(20));
      expect(
        results.map((r) => (r.surah, r.verse)),
        contains((7, 54)),
      );
    });

    test('العرش finds the Throne verses with the DB ready', () async {
      final results = QuranSearchService.search('العرش');
      expect(results, isNotEmpty);
      expect(
        results.map((r) => (r.surah, r.verse)),
        containsAll([(7, 54), (20, 5), (9, 129)]),
      );
      final keys = results.map((r) => (r.surah, r.verse)).toSet();
      expect(keys.length, results.length);
    });

    test('search still never throws when the DB path is unavailable', () async {
      // Point the DB at an invalid location → init fails → search must fall
      // back to the in-memory scan instead of returning empty.
      QuranSearchService.debugDatabasePathOverride =
          '${tempDir.path}/no/such/dir/db.sqlite';
      QuranSearchService.resetForTest();
      await QuranSearchService.ensureInitialized(); // must not throw
      final results = QuranSearchService.search('العرش');
      expect(results, isNotEmpty);
      expect(
        results.map((r) => (r.surah, r.verse)),
        contains((7, 54)),
      );
    });
  });
}

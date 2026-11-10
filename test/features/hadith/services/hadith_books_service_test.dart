import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/hadith/services/hadith_books_service.dart';

void main() {
  group('HadithBooksService registry', () {
    test('categories partition the registry with the expected counts', () {
      final all = HadithBooksService.getAllMeta();
      final the9 = HadithBooksService.getAllMeta(category: 'the_9_books');
      final other = HadithBooksService.getAllMeta(category: 'other_books');
      final forties = HadithBooksService.getAllMeta(category: 'forties');
      expect(the9.length, 9);
      expect(other.length, 5);
      expect(forties.length, 3);
      expect(all.length, 17);
      expect(all.length, the9.length + other.length + forties.length);
    });

    test('every category is one of the three known values', () {
      for (final meta in HadithBooksService.getAllMeta()) {
        expect(
          {'the_9_books', 'other_books', 'forties'},
          contains(meta.category),
        );
      }
    });

    test('keys are unique and every book has positive counts', () {
      final keys = <String>[];
      for (final meta in HadithBooksService.getAllMeta()) {
        expect(keys, isNot(contains(meta.key)));
        keys.add(meta.key);
        expect(meta.hadithCount, greaterThan(0));
        expect(meta.chapterCount, greaterThan(0));
      }
    });

    test('getMeta returns the registry entry for every key, null otherwise',
        () {
      for (final meta in HadithBooksService.getAllMeta()) {
        expect(HadithBooksService.getMeta(meta.key), same(meta));
      }
      expect(HadithBooksService.getMeta('nonexistent_book'), isNull);
    });

    test('getAllMeta with a category only returns that category', () {
      final forties = HadithBooksService.getAllMeta(category: 'forties');
      expect(forties.every((m) => m.category == 'forties'), isTrue);
      expect(HadithBooksService.getAllMeta(category: 'bogus'), isEmpty);
    });

    test('categories getter lists the three keys in display order', () {
      final cats = HadithBooksService.categories;
      expect(cats.map((c) => c.key).toList(),
          ['the_9_books', 'other_books', 'forties']);
    });

    test('every registry key maps to a unique DB id (1..17)', () {
      final ids = <int>[];
      for (final meta in HadithBooksService.getAllMeta()) {
        final id = HadithBooksService.dbIdFor(meta.key);
        expect(id, isNotNull, reason: 'missing DB id for ${meta.key}');
        expect(id, greaterThan(0));
        expect(ids, isNot(contains(id)));
        ids.add(id!);
      }
      // The shipped hadith.db holds books 1..17 contiguously (id 12 is
      // «الأربعون للشاه ولي الله»); a gap here means a book is unreachable.
      expect(ids.toSet(), {for (var i = 1; i <= 17; i++) i});
      expect(HadithBooksService.dbIdFor('nonexistent_book'), isNull);
    });
  });

  group('HadithBooksService.loadBook', () {
    test('rejects an unknown key before touching the database', () {
      expect(() => HadithBooksService().loadBook('bogus'), throwsArgumentError);
    });
  });

  group('normalizeArabic', () {
    test('strips tashkeel and normalizes letter variants', () {
      expect(normalizeArabic('بِسْمِ اللهِ'), 'بسم الله');
      expect(normalizeArabic('أحمد'), 'احمد');
      expect(normalizeArabic('مَـكَّة'), 'مكه');
    });
  });
}

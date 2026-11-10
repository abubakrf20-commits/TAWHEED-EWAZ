import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/dorar_hadith/data/datasources/dorar_remote_datasource.dart';

/// dorar.net در ۲۰۲۶ مارکاپ صفحهٔ نتایج جستجو را از `.hadith-info` به ردیف‌های
/// `.border-bottom` با شناسهٔ هَش (مثل `j0j8uiR3`) تغییر داد؛ این تست روی یک
/// نمونهٔ واقعیِ HTMLِ ذخیره‌شده، پارسرِ جایگزین را در برابر همان ساختار جدید
/// می‌آزماید و مطمئن می‌شود شناسهٔ حدیث هم استخراج می‌شود (تا صفحهٔ جزئیات
/// از کار نیفتد).
void main() {
  group('DorarRemoteDataSource.parseSiteResults', () {
    late String html;

    setUpAll(() {
      html = File('test/fixtures/dorar_search_results.html').readAsStringSync();
    });

    test('parses real rows and de-duplicates each hadith by id', () {
      final items = DorarRemoteDataSource.parseSiteResults(html);

      expect(items, isNotEmpty);
      final ids = items.map((e) => e.hadithId).toList();
      expect(ids, everyElement(isNotNull));
      expect(ids.toSet().length, ids.length, reason: 'no duplicate ids');
    });

    test('every item carries text, narrator, source and grade', () {
      for (final item in DorarRemoteDataSource.parseSiteResults(html)) {
        expect(item.hadithText.trim(), isNotEmpty);
        expect(item.narrator.trim(), isNotEmpty, reason: 'rawi missing');
        expect(item.mohdith.trim(), isNotEmpty, reason: 'mohdith missing');
        expect(item.book.trim(), isNotEmpty, reason: 'book missing');
        expect(item.degree.trim(), isNotEmpty, reason: 'grade missing');
      }
    });

    test('strips the leading hadith number from the text', () {
      final items = DorarRemoteDataSource.parseSiteResults(html);
      for (final item in items) {
        expect(
          item.hadithText,
          isNot(matches(RegExp(r'^\s*[0-9٠-٩]+\s*[-–]'))),
          reason: 'leading "1 - " numbering should be removed',
        );
      }
    });

    test('empty/foreign markup yields no items (safe fallback trigger)', () {
      expect(DorarRemoteDataSource.parseSiteResults(''), isEmpty);
      expect(
        DorarRemoteDataSource.parseSiteResults('<div>no results here</div>'),
        isEmpty,
      );
    });
  });
}

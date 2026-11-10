import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A downloaded content database is deleted through its own section AND from
/// «مدیریت فضا», and both doors go through the same confirm dialog + service
/// delete. Every step of that path is a source-scan guard: the sections need a
/// real sqlite file on disk to exercise for real, which a widget test cannot
/// provide.
String _withoutComments(String source) => source.split('\n').map((line) {
      final comment = line.indexOf('//');
      return comment < 0 ? line : line.substring(0, comment);
    }).join('\n');

String _read(String path) => _withoutComments(File(path).readAsStringSync());

const _screens = {
  'lib/features/riyad/presentation/screens/riyad_screen.dart':
      'دادهٔ ریاض الصالحین',
  'lib/features/taraghib/presentation/screens/taraghib_screen.dart':
      'دادهٔ صحیح الترغیب',
  'lib/features/hadith/presentation/screens/hadith_books_screen.dart':
      'دادهٔ کتب حدیث',
  'lib/features/hadeeth_enc/presentation/screens/hadeeth_enc_screen.dart':
      'دادهٔ موسوعه احادیث',
  'lib/features/fatwa/presentation/screens/fatwa_screen.dart':
      'دادهٔ فتاوای شرعی',
};

const _contentIds = [
  'hadith.books',
  'hadith.riyad',
  'hadith.taraghib',
  'hadith.fatwa',
  'hadith.encyclopedia',
];

void main() {
  group('owning sections', () {
    for (final entry in _screens.entries) {
      test('${entry.key} can delete its downloaded database', () {
        final source = _read(entry.key);
        expect(source, contains('confirmContentDatabaseDelete('),
            reason: '${entry.key} must confirm before deleting');
        expect(source, contains('deleteDownloaded('),
            reason: '${entry.key} must delete through its service');
        expect(source, contains('Icons.delete_outline_rounded'),
            reason: '${entry.key} must offer the delete action');
        expect(source, contains('حذف داده‌های دانلودشده'),
            reason: '${entry.key} delete action must be named');
        expect(source, contains(entry.value),
            reason: '${entry.key} must name what was removed');
      });
    }

    test('a delete falls back to the download prompt, never a blank page', () {
      for (final entry in {
        'lib/features/riyad/presentation/screens/riyad_screen.dart':
            '_dbMissing = true',
        'lib/features/taraghib/presentation/screens/taraghib_screen.dart':
            '_dbMissing = true',
        'lib/features/hadith/presentation/screens/hadith_books_screen.dart':
            '_dbMissing = true',
        'lib/features/hadeeth_enc/presentation/screens/hadeeth_enc_screen.dart':
            '_missing = true',
        'lib/features/fatwa/presentation/screens/fatwa_screen.dart':
            '_missing = true',
      }.entries) {
        expect(_read(entry.key), contains(entry.value),
            reason: '${entry.key} must show its download prompt after delete');
      }
    });
  });

  group('services', () {
    test('every downloaded content database exposes a delete', () {
      for (final path in const [
        'lib/features/riyad/services/riyad_service.dart',
        'lib/features/taraghib/services/taraghib_service.dart',
        'lib/features/hadeeth_enc/services/hadeeth_enc_db_service.dart',
      ]) {
        expect(_read(path), contains('Future<void> deleteDownloaded()'),
            reason: '$path must expose deleteDownloaded()');
      }
    });

    test('the taraghib delete drops every cache built from the file', () {
      final source = _read(
          'lib/features/taraghib/services/taraghib_service.dart');
      final start = source.indexOf('Future<void> deleteDownloaded()');
      expect(start, greaterThanOrEqualTo(0));
      final body = source.substring(
          start, source.indexOf('deleteDownloadedFile()', start));
      for (final cache in const [
        '_books = null',
        '_allChapters = null',
        '_hadithCounts = null',
        '_chapterCounts = null',
        '_chapterLocations = null',
        '_numberedIndex = null',
      ]) {
        expect(body, contains(cache),
            reason: 'a stale $cache would outlive the deleted file');
      }
    });
  });

  group('storage page', () {
    final source =
        _read('lib/features/settings/services/storage_insights_service.dart');

    test('every database has its own measured, clearable row', () {
      for (final id in _contentIds) {
        expect(source, contains("id: '$id'"), reason: id);
      }
      expect(source, contains('clearable: true'));
      // The old aggregate row pointed at a per-section delete that did not
      // exist; it must never come back.
      expect(source, isNot(contains('hadith.databases')));
    });

    test('a storage clear routes through the owning service', () {
      final start = source.indexOf('_defaultContentDeletes');
      expect(start, greaterThanOrEqualTo(0));
      final body = source.substring(
          start, source.indexOf('};', start));
      for (final id in _contentIds) {
        expect(body, contains("'$id'"), reason: id);
      }
      // A bare File.delete would leave the sqlite handle and the stored
      // content revision behind.
      expect(body, contains('deleteDownloaded'));
    });
  });
}

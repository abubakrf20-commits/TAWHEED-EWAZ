import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tawheeed/features/settings/services/storage_insights_service.dart';

/// A throw-away directory tree shaped like the app's real storage roots.
class _Tree {
  _Tree(this.root)
      : documents = p.join(root.path, 'documents'),
        support = p.join(root.path, 'support'),
        quranContent = p.join(root.path, 'quran_content');

  final Directory root;
  final String documents;
  final String support;
  final String quranContent;

  late final StoragePaths paths = StoragePaths(
    documents: documents,
    support: support,
    quranContent: quranContent,
  );

  void make() {
    Directory(documents).createSync(recursive: true);
    Directory(support).createSync(recursive: true);
    Directory(quranContent).createSync(recursive: true);
  }

  void file(String path, int bytes) {
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(List.filled(bytes, 0));
  }
}

/// `measure()` is async through an isolate; tests await it once per tree.
Future<StorageReport> _measure(_Tree tree) =>
    StorageInsightsService(pathsResolver: () async => tree.paths).measure();

void main() {
  late Directory temp;
  late _Tree tree;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('storage_insights_test');
    tree = _Tree(temp);
    tree.make();
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  group('measure', () {
    test('reports the known layout with the right sizes', () async {
      tree
        ..file(p.join(tree.paths.recitationAudio, 'a.mp3'), 100)
        ..file(p.join(tree.paths.recitationAudio, 'nested', 'b.mp3'), 50)
        ..file(p.join(tree.paths.translationAudio, 'fa', '1.mp3'), 70)
        ..file(p.join(tree.quranContent, 'page.db'), 30)
        ..file(p.join(tree.paths.booksData, 'book.pdf'), 200)
        ..file(tree.paths.hadithDatabase, 40)
        ..file(tree.paths.ryadDatabase, 41)
        ..file(tree.paths.taraghibDatabase, 42)
        ..file(tree.paths.fatwaDatabase, 43)
        ..file(tree.paths.hadeethEncDatabase, 44)
        ..file(p.join(tree.paths.audioLibrary, 'lecture.mp3'), 300)
        ..file(p.join(tree.paths.ruqyahAudio, 'r.mp3'), 60)
        ..file(p.join(tree.paths.attachments, 'photo.jpg'), 400)
        ..file(p.join(tree.paths.backups, 'b.zip'), 500)
        ..file(p.join(tree.paths.customAzans, 'azan.mp3'), 80)
        ..file(tree.paths.logFile, 11)
        ..file(tree.paths.legacyLogFile, 13)
        ..file(p.join(tree.paths.diagnostics, 'snap.sqlite'), 90)
        ..file(p.join(tree.paths.quranCache, 'c.json'), 20)
        ..file(tree.paths.dorarCache, 25);

      final report = await _measure(tree);
      final byId = {
        for (final group in report.groups)
          for (final item in group.items) item.id: item,
      };

      expect(byId['quran.recitation']!.bytes, 150);
      expect(byId['quran.translation']!.bytes, 70);
      // The content row excludes both audio trees, so only page.db counts.
      expect(byId['quran.content']!.bytes, 30);
      expect(byId['books.data']!.bytes, 200);
      expect(byId['hadith.books']!.bytes, 40);
      expect(byId['hadith.riyad']!.bytes, 41);
      expect(byId['hadith.taraghib']!.bytes, 42);
      expect(byId['hadith.fatwa']!.bytes, 43);
      expect(byId['hadith.encyclopedia']!.bytes, 44);
      expect(byId['media.audioLibrary']!.bytes, 300);
      expect(byId['media.ruqyah']!.bytes, 60);
      expect(byId['personal.attachments']!.bytes, 400);
      expect(byId['personal.backups']!.bytes, 500);
      expect(byId['personal.azans']!.bytes, 80);
      expect(byId['caches.logs']!.bytes, 24);
      expect(byId['caches.diagnostics']!.bytes, 90);
      expect(byId['caches.quran']!.bytes, 20);
      expect(byId['caches.dorar']!.bytes, 25);

      const expectedTotal = 150 +
          70 +
          30 +
          200 +
          40 +
          41 +
          42 +
          43 +
          44 +
          300 +
          60 +
          400 +
          500 +
          80 +
          24 +
          90 +
          20 +
          25;
      expect(report.totalBytes, expectedTotal);
      expect(
        report.groups.map((group) => group.title),
        [
          'قرآن و تلاوت',
          'کتاب‌ها و حدیث',
          'رسانه',
          'داده‌های شخصی',
          'کش و گزارش‌ها'
        ],
      );
    });

    test('missing roots measure as zero instead of failing', () async {
      final report = await _measure(tree);
      expect(report.totalBytes, 0);
      expect(report.groups, isNotEmpty);
    });

    test('only re-downloadable rows are clearable', () async {
      final report = await _measure(tree);
      final clearable = {
        for (final group in report.groups)
          for (final item in group.items)
            if (item.clearable) item.id,
      };
      expect(clearable, {
        'quran.recitation',
        'quran.translation',
        'books.data',
        'hadith.books',
        'hadith.riyad',
        'hadith.taraghib',
        'hadith.fatwa',
        'hadith.encyclopedia',
        'media.audioLibrary',
        'media.ruqyah',
        'caches.quran',
        'caches.diagnostics',
        'caches.logs',
      });
      // Personal data stays listed, never clearable.
      for (final id in [
        'personal.attachments',
        'personal.backups',
        'personal.azans',
        'caches.dorar',
        'quran.content',
      ]) {
        final item = report.groups
            .expand((group) => group.items)
            .firstWhere((item) => item.id == id);
        expect(item.clearable, isFalse, reason: id);
      }
    });
  });

  group('clear', () {
    test('deletes only the requested directory and leaves the rest', () async {
      tree
        ..file(p.join(tree.paths.recitationAudio, 'a.mp3'), 10)
        ..file(p.join(tree.paths.translationAudio, 'b.mp3'), 10)
        ..file(p.join(tree.paths.booksData, 'book.pdf'), 10);

      final service =
          StorageInsightsService(pathsResolver: () async => tree.paths);
      expect(await service.clear('quran.recitation'), isTrue);

      expect(Directory(tree.paths.recitationAudio).existsSync(), isFalse);
      expect(Directory(tree.paths.translationAudio).existsSync(), isTrue);
      expect(Directory(tree.paths.booksData).existsSync(), isTrue);
    });

    test('logs files clear both spellings of the log', () async {
      tree
        ..file(tree.paths.logFile, 5)
        ..file(tree.paths.legacyLogFile, 5);

      final service =
          StorageInsightsService(pathsResolver: () async => tree.paths);
      expect(await service.clear('caches.logs'), isTrue);

      expect(File(tree.paths.logFile).existsSync(), isFalse);
      expect(File(tree.paths.legacyLogFile).existsSync(), isFalse);
    });

    test('refuses unknown and non-clearable ids without touching disk',
        () async {
      tree.file(p.join(tree.paths.attachments, 'photo.jpg'), 10);
      final service =
          StorageInsightsService(pathsResolver: () async => tree.paths);

      expect(await service.clear('personal.attachments'), isFalse);
      expect(await service.clear('not.a.row'), isFalse);
      expect(File(p.join(tree.paths.attachments, 'photo.jpg')).existsSync(),
          isTrue);
    });

    test('a missing directory is a successful no-op', () async {
      final service =
          StorageInsightsService(pathsResolver: () async => tree.paths);
      expect(await service.clear('media.ruqyah'), isTrue);
    });

    test('a database row clears through the service that owns it', () async {
      tree
        ..file(tree.paths.ryadDatabase, 40)
        ..file('${tree.paths.ryadDatabase}.gz', 5);
      var calls = 0;
      final service = StorageInsightsService(
        pathsResolver: () async => tree.paths,
        contentDeletes: {
          'hadith.riyad': () async {
            calls++;
            // The real service closes its handle and deletes both files.
            File(tree.paths.ryadDatabase).deleteSync();
            File('${tree.paths.ryadDatabase}.gz').deleteSync();
          },
        },
      );

      expect(await service.clear('hadith.riyad'), isTrue);
      expect(calls, 1);
      expect(File(tree.paths.ryadDatabase).existsSync(), isFalse);
      expect(File('${tree.paths.ryadDatabase}.gz').existsSync(), isFalse);
    });

    test('a delete that leaves bytes behind is reported as a failure', () async {
      tree.file(tree.paths.hadithDatabase, 40);
      final service = StorageInsightsService(
        pathsResolver: () async => tree.paths,
        // The content services log and swallow their own delete failures.
        contentDeletes: {'hadith.books': () async {}},
      );

      expect(await service.clear('hadith.books'), isFalse);
      expect(File(tree.paths.hadithDatabase).existsSync(), isTrue);
    });

    test('an injected map never reaches a row it does not name', () async {
      tree
        ..file(tree.paths.hadithDatabase, 40)
        ..file(tree.paths.ryadDatabase, 40);
      final service = StorageInsightsService(
        pathsResolver: () async => tree.paths,
        contentDeletes: {'hadith.riyad': () async {}},
      );

      expect(await service.clear('hadith.books'), isFalse);
      expect(File(tree.paths.hadithDatabase).existsSync(), isTrue);
    });
  });
}

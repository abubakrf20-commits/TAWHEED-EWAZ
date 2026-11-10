import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:tawheeed/features/hadith/services/hadith_db_service.dart';
import 'package:tawheeed/features/riyad/services/riyad_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  /// The shape the six-volume build writes: one `books` row, the edition's
  /// «کتاب» chain in `chapters.part`, the پانوشت of each line in `footnotes`
  /// and the باب's opening verses in `preambles`.
  /// [fillerChapters] pads the chapter table to the length of the hosted
  /// edition, for the tests that exercise the shape guard in `needsUpdate`.
  Future<void> createTestDatabase(File file, {int fillerChapters = 0}) async {
    final db = sqlite3.open(file.path);
    try {
      db.execute('''
        CREATE TABLE books (
          id INTEGER PRIMARY KEY,
          title_arabic TEXT
        );
        CREATE TABLE chapters (
          id INTEGER PRIMARY KEY,
          book_id INTEGER,
          chapter_index REAL,
          printed_number INTEGER,
          name_arabic TEXT,
          name_persian TEXT,
          part TEXT,
          is_bab INTEGER
        );
        CREATE TABLE hadiths (
          id INTEGER PRIMARY KEY,
          book_id INTEGER,
          chapter_id INTEGER,
          hadith_number INTEGER,
          arabic TEXT
        );
        CREATE TABLE footnotes (
          id INTEGER PRIMARY KEY,
          footnote_no TEXT,
          text TEXT,
          anchor_kind TEXT,
          book_id INTEGER,
          chapter_id INTEGER,
          hadith_id INTEGER,
          section_id INTEGER,
          preamble_id INTEGER,
          anchor_line INTEGER,
          sort_order INTEGER
        );
        CREATE TABLE preambles (
          id INTEGER PRIMARY KEY,
          book_id INTEGER,
          chapter_id INTEGER,
          kind TEXT,
          para_order INTEGER,
          arabic TEXT
        );
        CREATE TABLE matter_sections (
          id INTEGER PRIMARY KEY,
          key TEXT,
          kind TEXT,
          title TEXT,
          sort_order INTEGER
        );
        CREATE TABLE matter_paragraphs (
          id INTEGER PRIMARY KEY,
          section_id INTEGER,
          para_order INTEGER,
          arabic TEXT
        );
        INSERT INTO books (id, title_arabic) VALUES (1, 'شرح ریاض الصالحین');
        INSERT INTO chapters
          (id, book_id, chapter_index, printed_number, name_arabic, part, is_bab)
        VALUES
          (101, 1, 1.0, 1, 'باب الإخلاص', NULL, 1),
          (102, 1, 2.0, 84, 'باب الحياء', 'کتاب 1: ادب', 1);
        INSERT INTO hadiths (id, book_id, chapter_id, hadith_number, arabic)
        VALUES
          (1, 1, 101, 1, 'إنَّمَا الأَعْمَالُ بِالنِّيَّاتِ\\nترجمه: همانا اعمال به نیت‌هاست'),
          (2, 1, 102, 2, 'الحَيَاءُ شُعْبَةٌ مِنَ الإِيمَانِ');
        INSERT INTO footnotes
          (id, footnote_no, text, anchor_kind, book_id, chapter_id, hadith_id,
           preamble_id, anchor_line, sort_order)
        VALUES
          (1, '9', 'صحیح بخاری، ش:1', 'hadith', 1, 101, 1, NULL, 0, 1),
          (2, '12', 'صحیح مسلم، ش: 2560', 'hadith', 1, 101, 1, NULL, 1, 2),
          (3, '3', 'یادداشت آغاز باب', 'chapter_preamble', 1, 101, NULL, 301, NULL, 3);
        INSERT INTO preambles (id, book_id, chapter_id, kind, para_order, arabic)
          VALUES (301, 1, 101, 'chapter_preamble', 1, 'الله می‌فرماید:');
        INSERT INTO matter_sections (id, key, kind, title, sort_order)
          VALUES (1, 'intro_1', 'intro', 'درآمدی بر کتاب', 10);
        INSERT INTO matter_paragraphs (id, section_id, para_order, arabic)
          VALUES (1, 1, 1, 'کتاب «ریاض الصالحین» ...');
      ''');
      if (fillerChapters > 0) {
        final fill = db.prepare(
            'INSERT INTO chapters (id, book_id, chapter_index, printed_number, '
            'name_arabic, part, is_bab) VALUES (?, 1, ?, ?, ?, NULL, 1)');
        for (var i = 0; i < fillerChapters; i++) {
          fill.execute([1000 + i, 100.0 + i, 1000 + i, 'باب تکمیلی ${i + 1}']);
        }
        fill.dispose();
      }
    } finally {
      db.close();
    }
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tawheeed_riyad_db');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return tempDir.path;
      }
      return null;
    });
    SharedPreferences.setMockInitialValues({});
    await createTestDatabase(File(p.join(tempDir.path, 'ryadalsalihin.db')));
  });

  tearDown(() async {
    HadithDbService.riyad.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows can still hold the just-closed DB handle — retry once.
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      }
    }
  });

  group('riyad availability', () {
    test('isAvailable sees the standalone downloaded database', () async {
      final service = RiyadService();
      expect(await service.isAvailable(), isTrue);
    });

    test('isAvailable is false when only the shared hadith.db exists',
        () async {
      // The riyad section must not depend on کتب حدیث's download.
      File(p.join(tempDir.path, 'ryadalsalihin.db')).deleteSync();
      final file = File(p.join(tempDir.path, 'hadith.db'))
        ..writeAsBytesSync(List.filled(16, 0));
      final service = RiyadService();
      expect(await service.isAvailable(), isFalse);
      file.deleteSync();
    });

    test('a copy without a recorded revision, or an older one, is stale',
        () async {
      // `HadithDbService.riyad.minChapters` refuses a payload shorter than the
      // edition's own باب count, so this test needs a full-length copy before
      // its revision numbers can decide anything.
      final file = File(p.join(tempDir.path, 'ryadalsalihin.db'));
      file.deleteSync();
      await createTestDatabase(file, fillerChapters: 370);
      expect(await RiyadService().needsUpdate(), isTrue);
      // Key and value come from the spec, so republishing the payload cannot
      // leave this test asserting the number it replaced.
      final spec = HadithDbService.riyad;
      SharedPreferences.setMockInitialValues({
        'content_rev_${spec.dbFileName}': spec.contentRevision,
      });
      expect(await RiyadService().needsUpdate(), isFalse);
      SharedPreferences.setMockInitialValues({
        'content_rev_${spec.dbFileName}': spec.contentRevision - 1,
      });
      expect(await RiyadService().needsUpdate(), isTrue);
    });
  });

  group('chapter headings', () {
    test('a payload that printed the heading only in name_persian is readable',
        () async {
      // The published six-volume build wrote its single printed heading to
      // `name_persian` and left `name_arabic` empty; the reader reads
      // `name_arabic`, so every باب listed a blank line. An empty column must
      // borrow the other, not paint nothing.
      final db = sqlite3.open(p.join(tempDir.path, 'ryadalsalihin.db'));
      db.execute("UPDATE chapters SET name_arabic = '', "
          "name_persian = 'باب الإخلاص (فارسی)' WHERE id = 101");
      db.close();
      HadithDbService.riyad.close();

      final service = RiyadService();
      await service.ensureReady();
      final chapters = await service.chapters();
      final first = chapters.firstWhere((c) => c['id'] == 101);
      expect(first['name_arabic'], 'باب الإخلاص (فارسی)');
      // A row that does carry its own heading keeps it.
      final second = chapters.firstWhere((c) => c['id'] == 102);
      expect(second['name_arabic'], 'باب الحياء');
    });
  });

  group('riyad book queries (one book row)', () {
    test('chapters returns this book in index order, with its kitab chain',
        () async {
      final service = RiyadService();
      await service.ensureReady();
      final chapters = await service.chapters();
      expect(chapters.map((c) => c['chapter_index']).toList(), [1.0, 2.0]);
      expect(chapters.first['name_arabic'], 'باب الإخلاص');
      // ببs printed before the edition's first «کتاب» heading carry no part.
      expect(chapters.first['part'], isNull);
      expect(chapters.last['part'], 'کتاب 1: ادب');
    });

    test('chapterOf finds the row the reader needs for its notes', () async {
      final service = RiyadService();
      await service.ensureReady();
      final chapter = await service.chapterOf(2.0);
      expect(chapter, isNotNull);
      expect(chapter!['id'], 102);
      expect(await service.chapterOf(99.0), isNull);
    });

    test('totalEntries counts only this book', () async {
      final service = RiyadService();
      await service.ensureReady();
      expect(await service.totalEntries(), 2);
    });

    test('hadithCountsPerChapter maps chapter_index to hadith count', () async {
      final service = RiyadService();
      await service.ensureReady();
      final counts = await service.hadithCountsPerChapter();
      expect(counts[1.0], 1);
      expect(counts[2.0], 1);
    });

    test('entriesOfChapter returns entries ordered by hadith_number', () async {
      final service = RiyadService();
      await service.ensureReady();
      final rows = await service.entriesOfChapter(1.0);
      expect(rows.single['hadith_number'], 1);
      expect(rows.single['arabic'], contains('ترجمه:'));
    });
  });

  group('riyad footnotes and notices', () {
    test('footnotesOfChapter keeps each note with its own line', () async {
      final service = RiyadService();
      await service.ensureReady();
      // The chapter query returns every note of the باب — the two under its
      // hadith and the one on its opening — so the reader can group them.
      final notes = await service.footnotesOfChapter(101);
      expect(notes.length, 3);
      final onHadith = notes.where((n) => n['hadith_id'] != null).toList();
      expect(onHadith.map((n) => n['anchor_line']).toList(), [0, 1]);
      expect(onHadith.first['text'], contains('صحیح بخاری'));
      expect(notes.where((n) => n['preamble_id'] != null).single['id'], 3);
    });

    test('preamblesOfChapter returns the باب opening in order', () async {
      final service = RiyadService();
      await service.ensureReady();
      final preambles = await service.preamblesOfChapter(101);
      expect(preambles.single['arabic'], 'الله می‌فرماید:');
    });

    test('a database from before revision 2 reads as «nothing to show»',
        () async {
      // Drop the two tables the old payload never had.
      final file = File(p.join(tempDir.path, 'ryadalsalihin.db'));
      final db = sqlite3.open(file.path);
      try {
        db.execute('DROP TABLE footnotes');
        db.execute('DROP TABLE preambles');
      } finally {
        db.close();
      }
      final service = RiyadService();
      await service.ensureReady();
      expect(await service.footnotesOfChapter(101), isEmpty);
      expect(await service.preamblesOfChapter(101), isEmpty);
    });
  });

  group('riyad matter sections', () {
    test('the first volume front matter is readable', () async {
      final service = RiyadService();
      await service.ensureReady();
      final sections = await service.matterSections();
      expect(sections.single['title'], 'درآمدی بر کتاب');
      final paragraphs = await service.matterParagraphs(1);
      expect(paragraphs.single['arabic'], contains('ریاض الصالحین'));
    });
  });

  group('riyad search and jump', () {
    test('search finds entries in the standalone database', () async {
      final service = RiyadService();
      await service.ensureReady();
      final rows = await service.search('الاعمال بالنيات');
      expect(rows.single['book_id'], RiyadService.bookId);
    });

    test('the badge number is the row number, so the jump is exact', () async {
      final service = RiyadService();
      await service.ensureReady();
      expect(await service.maxHadithNumber(), 2);
      final loc = await service.locateHadithNumber(2);
      expect(loc, isNotNull);
      expect(loc!.$1, 2.0);
      expect(loc.$2, 2);
      expect(await service.locateHadithNumber(0), isNull);
      expect(await service.locateHadithNumber(9999), isNull);
    });
  });
}

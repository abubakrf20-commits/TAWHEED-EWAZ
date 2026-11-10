import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:tawheeed/features/hadith/services/hadith_db_service.dart';
import 'package:tawheeed/features/maalim/services/maalim_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  Future<void> createTestDatabase(File file) async {
    final db = sqlite3.open(file.path);
    try {
      db.execute('''
        CREATE TABLE books (
          id INTEGER PRIMARY KEY,
          title_arabic TEXT,
          title_english TEXT,
          hadith_count INTEGER
        );
        CREATE TABLE chapters (
          id INTEGER PRIMARY KEY,
          book_id INTEGER,
          chapter_index REAL,
          name_arabic TEXT,
          name_english TEXT,
          part TEXT
        );
        CREATE TABLE hadiths (
          id INTEGER PRIMARY KEY,
          book_id INTEGER,
          chapter_id INTEGER,
          hadith_number INTEGER,
          arabic TEXT
        );
        INSERT INTO books (id, title_arabic, hadith_count)
          VALUES (1, 'معالم السنه النبویه — ترجمه و تعلیق شاکر الذهبي', 3);
        INSERT INTO chapters (id, book_id, chapter_index, name_arabic, part)
          VALUES
          (201, 1, 1.0, 'ذکر آدم علیه السلام',
              'مقصد هفتم: تاریخ، سیرت ومناقب · کتاب اول: أنبیاء'),
          (202, 1, 2.0, 'عبادت سنگ ها',
              'کتاب دوم: سیرت نبوی شریف · فصل اول: جاهلیت');
        INSERT INTO hadiths
          (id, book_id, chapter_id, hadith_number, arabic) VALUES
          (1, 1, 1, 1, 'کتاب دیگر'),
          (2, 1, 201, 1, 'وَالْأَرْوَاحُ جُنُودٌ مُجَنَّدَةٌ'),
          (3, 1, 202, 2, 'عَبْدُ اللَّهِ بْنُ عُمَرَ قَالَ'),
          (4, 1, 202, 3, 'النَّاسُ مَعَادِنُ'),
          (5, 1, 202, 0, '- [ببین حدیث (1068) وپس از آن را.]');
        CREATE TABLE footnotes (
          id INTEGER PRIMARY KEY,
          book_id INTEGER,
          chapter_id INTEGER,
          hadith_id INTEGER,
          preamble_id INTEGER,
          anchor_line INTEGER,
          text TEXT,
          sort_order INTEGER
        );
        CREATE TABLE preambles (
          id INTEGER PRIMARY KEY,
          book_id INTEGER,
          chapter_id INTEGER,
          arabic TEXT
        );
        INSERT INTO preambles (id, book_id, chapter_id, arabic)
          VALUES (9, 1, 201, 'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ');
        INSERT INTO footnotes
          (id, book_id, chapter_id, hadith_id, preamble_id, anchor_line, text,
           sort_order) VALUES
          (1, 1, 201, NULL, NULL, NULL, 'پانوشت عنوان باب', 1),
          (2, 1, 201, NULL, 9, NULL, 'پانوشت بندِ آغاز باب', 2),
          (3, 1, 201, 2, NULL, 0, 'پانوشت خود حدیث', 3);
      ''');
    } finally {
      db.close();
    }
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tawheeed_maalim_db');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return tempDir.path;
      }
      return null;
    });
    await createTestDatabase(File(p.join(tempDir.path, 'maalim.db')));
  });

  tearDown(() async {
    HadithDbService.maalim.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      }
    }
  });

  group('maalim availability', () {
    test('isAvailable sees the standalone downloaded database', () async {
      final service = MaalimService();
      expect(await service.isAvailable(), isTrue);
    });

    test('isAvailable is false when only the shared hadith.db exists',
        () async {
      File(p.join(tempDir.path, 'maalim.db')).deleteSync();
      File(p.join(tempDir.path, 'hadith.db'))
          .writeAsBytesSync(List.filled(16, 0));
      final service = MaalimService();
      expect(await service.isAvailable(), isFalse);
    });
  });

  group('maalim book queries (book id 20)', () {
    test('chapters returns only maalim babs, in index order, with their part',
        () async {
      final service = MaalimService();
      await service.ensureReady();
      final chapters = await service.chapters();
      expect(chapters.map((c) => c['chapter_index']).toList(), [1.0, 2.0]);
      expect(chapters.first['name_arabic'], 'ذکر آدم علیه السلام');
      expect(
          chapters.first['part'],
          'مقصد هفتم: تاریخ، سیرت ومناقب · کتاب اول: أنبیاء');
    });

    test('totalEntries counts this book\'s narrations, not rows', () async {
      final service = MaalimService();
      await service.ensureReady();
      // Book 20 holds four rows (three narrations + the unnumbered
      // cross-reference note) and book 1 holds one more: neither leaks in.
      expect(await service.totalEntries(), 3);
    });

    test('countsPerChapter counts narrations per bab', () async {
      final service = MaalimService();
      await service.ensureReady();
      final counts = await service.countsPerChapter();
      expect(counts[1.0], 1);
      // Chapter 202 has three rows but only two narrations — the note in it
      // is a pointer, so it never pads a bab\'s badge.
      expect(counts[2.0], 2);
    });

    test('hadithCountsPerChapter skips the unnumbered cross-reference row',
        () async {
      final service = MaalimService();
      await service.ensureReady();
      final counts = await service.hadithCountsPerChapter();
      expect(counts[1.0], 1);
      expect(counts[2.0], 2);
      expect(counts[2.0], isNot(3));
    });

    test('entriesOfChapter keeps narrations in number order, note last',
        () async {
      final service = MaalimService();
      await service.ensureReady();
      final rows = await service.entriesOfChapter(2.0);
      expect(rows.map((r) => r['hadith_number'] as int), [2, 3, 0]);
      expect(rows.first['arabic'], 'عَبْدُ اللَّهِ بْنُ عُمَرَ قَالَ');
      expect(rows.last['hadith_number'], 0,
          reason: 'the cross-reference note must not open the bab');
    });
  });

  group('maalim content revision (republished database)', () {
    test('a copy without an applied revision needs the update', () async {
      SharedPreferences.setMockInitialValues({});
      final service = MaalimService();
      expect(await service.isAvailable(), isTrue);
      expect(await service.needsUpdate(), isTrue,
          reason: 'the hosted database was corrected — the stale copy '
              'must be replaced, not kept');
    });

    test('a matching revision over a shorter copy is still replaced', () async {
      // A revision number can be recorded over the wrong bytes — that is how
      // the one-volume parse outlived two republishes. The fixture holds 2
      // بab, not the 1,929 the hosted file carries, so it is not current even
      // though its stored revision matches.
      final spec = HadithDbService.maalim;
      SharedPreferences.setMockInitialValues(
          {'content_rev_${spec.dbFileName}': spec.contentRevision});
      final service = MaalimService();
      expect(await service.needsUpdate(), isTrue);
    });

    test('a copy of the shipped shape at the current revision is current',
        () async {
      final spec = HadithDbService.maalim;
      SharedPreferences.setMockInitialValues(
          {'content_rev_${spec.dbFileName}': spec.contentRevision});
      // Replace the stub with a file that is as long as the hosted one — the
      // shape the floor asks for, without downloading it.
      final file = File(p.join(tempDir.path, 'maalim.db'))..deleteSync();
      final db = sqlite3.open(file.path);
      db.execute('CREATE TABLE chapters ('
          'id INTEGER PRIMARY KEY, book_id INTEGER, chapter_index REAL, '
          'name_arabic TEXT, part TEXT)');
      db.execute('BEGIN');
      for (var i = 1; i <= spec.minChapters; i++) {
        db.execute("INSERT INTO chapters (book_id, chapter_index, name_arabic) "
            "VALUES (1, $i.0, 'باب')");
      }
      db.execute('COMMIT');
      db.close();

      final service = MaalimService();
      expect(await service.isAvailable(), isTrue);
      expect(await service.needsUpdate(), isFalse);
    });
  });

  group('maalim footnotes (پانوشتهای نسخهٔ چاپی)', () {
    test('chapterOf hands the reader its row, so it can ask for the notes',
        () async {
      final service = MaalimService();
      await service.ensureReady();
      expect((await service.chapterOf(2.0))?['id'], 202);
      expect(await service.chapterOf(99.0), isNull);
    });

    test('one باب brings its heading, its notice and its own notes',
        () async {
      final service = MaalimService();
      await service.ensureReady();
      final notes = await service.footnotesOfChapter(201);
      // The three shapes the reader groups by: no ids (the heading), a
      // `preamble_id` (the printing’s opening paragraph) and a `hadith_id`
      // with the line it is anchored to.
      expect(notes.map((n) => n['id']).toList(), [1, 2, 3]);
      expect(notes[1]['preamble_id'], 9);
      expect(notes[2]['hadith_id'], 2);
      expect(notes[2]['anchor_line'], 0);
    });

    test('the verses a باب opens with come back for that باب', () async {
      final service = MaalimService();
      await service.ensureReady();
      final preambles = await service.preamblesOfChapter(201);
      expect(preambles.single['arabic'], 'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ');
      expect(await service.preamblesOfChapter(202), isEmpty);
    });

    test('a bab without notes answers nothing, not an error', () async {
      final service = MaalimService();
      await service.ensureReady();
      expect(await service.footnotesOfChapter(202), isEmpty);
    });

    test('a copy from before the notes tables degrades to nothing', () async {
      final db = sqlite3.open(p.join(tempDir.path, 'maalim.db'));
      db.execute('DROP TABLE footnotes; DROP TABLE preambles;');
      db.close();

      final service = MaalimService();
      await service.ensureReady();
      // The reader must still open the book: a build without these tables has
      // no notes to print, which is not a reason to fail the screen.
      expect(await service.footnotesOfChapter(201), isEmpty);
      expect(await service.preamblesOfChapter(201), isEmpty);
    });
  });

  group('maalim search', () {
    test('search finds entries in the standalone database', () async {
      final service = MaalimService();
      await service.ensureReady();
      final rows = await service.search('الارواح');
      expect(rows.single['book_id'], MaalimService.bookId);
    });
  });

  group('maalim locateHadithNumber (پرش به شماره حدیث)', () {
    test('maxHadithNumber comes from the data, not a constant', () async {
      final service = MaalimService();
      await service.ensureReady();
      expect(await service.maxHadithNumber(), 3);
    });

    test('maps a sequential number to its chapter', () async {
      final service = MaalimService();
      await service.ensureReady();
      final loc = await service.locateHadithNumber(2);
      expect(loc, isNotNull);
      expect(loc!.$1, 2.0);
      expect(loc.$2, 2);
    });

    test('returns null for numbers this edition does not carry',
        () async {
      final service = MaalimService();
      await service.ensureReady();
      expect(await service.locateHadithNumber(99), isNull);
    });
  });
}

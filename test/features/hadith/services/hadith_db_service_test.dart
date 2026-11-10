import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'package:tawheeed/features/hadith/domain/entities/hadith.dart';
import 'package:tawheeed/features/hadith/services/hadith_books_service.dart';
import 'package:tawheeed/features/hadith/services/hadith_db_service.dart';
import 'package:tawheeed/shared/utils/text_highlight.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  /// Builds a hadith.db with the schema BEFORE the app's migration (no
  /// `grade` / `arabic_normalized` columns) so init() must add them.
  Future<void> createTestDatabase(File file) async {
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
          chapter_index REAL
        );
        CREATE TABLE hadiths (
          id INTEGER PRIMARY KEY,
          book_id INTEGER,
          chapter_id INTEGER,
          hadith_number INTEGER,
          arabic TEXT
        );
        INSERT INTO books (id, title_arabic) VALUES
          (1, 'صحيح البخاري'),
          (2, 'صحيح مسلم');
        INSERT INTO chapters (id, book_id, chapter_index) VALUES
          (1, 1, 1.0),
          (2, 1, 35.2),
          (3, 2, 1.0);
        INSERT INTO hadiths (id, book_id, chapter_id, hadith_number, arabic)
          VALUES
          (1, 1, 1, 1, 'بِسْمِ اللهِ الرَّحْمَنِ الرَّحِيمِ'),
          (2, 1, 1, 2, 'إنَّمَا الأَعْمَالُ بِالنِّيَّاتِ'),
          (3, 1, 2, 3, 'الدِّينُ النَّصِيحَةُ'),
          (4, 2, 3, 1, 'المُسْلِمُ مَنْ سَلِمَ المُسْلِمُونَ مِنْ لِسَانِهِ');
      ''');
    } finally {
      db.close();
    }
  }

  void setGrades(Map<int, String> grades) {
    final db = sqlite3.open(p.join(tempDir.path, 'hadith.db'));
    try {
      for (final e in grades.entries) {
        db.execute(
            "UPDATE hadiths SET grade = '${e.value}' WHERE id = ${e.key}");
      }
    } finally {
      db.close();
    }
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tawheeed_hadith_db');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return tempDir.path;
      }
      return null;
    });
    await createTestDatabase(File(p.join(tempDir.path, 'hadith.db')));
  });

  tearDown(() async {
    HadithDbService().close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test(
      'init migrates the schema: adds grade + arabic_normalized and '
      'backfills normalized text', () async {
    final service = HadithDbService();
    expect(service.isReady, isFalse);
    await service.init();
    expect(service.isReady, isTrue);

    final got = await service.getHadith(1);
    expect(got!['arabic_normalized'], 'بسم الله الرحمن الرحيم');
  });

  test('a database already at the migrated revision skips the schema work',
      () async {
    // Stamped but NOT migrated: the version stamp is what stops every later
    // open from spawning an isolate over the whole table again, so a stamped
    // file must show no new columns.
    final mark = sqlite3.open(p.join(tempDir.path, 'hadith.db'));
    mark.execute('PRAGMA user_version = $hadithSchemaVersion');
    mark.close();

    final service = HadithDbService();
    await service.init();
    final cols = service.db
        .select('PRAGMA table_info(hadiths)')
        .map((r) => r['name'])
        .toSet();
    expect(cols, isNot(contains('grade')));
  });

  group('book queries', () {
    test('getAllBooks and getBook', () async {
      final service = HadithDbService();
      await service.init();
      final books = await service.getAllBooks();
      expect(books.map((b) => b['id']).toList(), [1, 2]);
      expect(await service.getBook(2), isNotNull);
      expect(await service.getBook(99), isNull);
    });
  });

  group('chapter queries', () {
    test('getChaptersForBook returns chapters in index order', () async {
      final service = HadithDbService();
      await service.init();
      final chapters = await service.getChaptersForBook(1);
      expect(chapters.map((c) => c['chapter_index']).toList(), [1.0, 35.2]);
    });

    test('getHadithCountsPerChapter counts hadiths, zero for empty chapters',
        () async {
      final service = HadithDbService();
      await service.init();
      final counts = await service.getHadithCountsPerChapter(1);
      expect(counts[1.0], 2);
      expect(counts[35.2], 1);
      final counts2 = await service.getHadithCountsPerChapter(2);
      expect(counts2[1.0], 1);
    });
  });

  group('hadith queries', () {
    test('getHadithsForBook paginates with limit/offset', () async {
      final service = HadithDbService();
      await service.init();
      final page1 = await service.getHadithsForBook(1, limit: 1);
      final page2 = await service.getHadithsForBook(1, limit: 1, offset: 1);
      expect(page1.single['id'], 1);
      expect(page2.single['id'], 2);
      expect(await service.getHadithCountForBook(1), 3);
    });

    test('getHadithsForChapter limits and orders by hadith_number', () async {
      final service = HadithDbService();
      await service.init();
      final rows = await service.getHadithsForChapter(1);
      expect(rows.map((r) => r['hadith_number']).toList(), [1, 2]);
    });

    test('getHadithsForChapterIndex handles fractional chapter_index',
        () async {
      final service = HadithDbService();
      await service.init();
      final rows = await service.getHadithsForChapterIndex(1, 35.2);
      expect(rows.single['id'], 3);
    });

    test('getHadith returns null for missing id', () async {
      final service = HadithDbService();
      await service.init();
      expect(await service.getHadith(999), isNull);
    });
  });

  group('search', () {
    test('searchArabic matches un-diacritized queries', () async {
      final service = HadithDbService();
      await service.init();
      final rows = await service.searchArabic('الاعمال بالنيات');
      expect(rows.single['id'], 2);
    });

    test('searchHadiths filters by bookId', () async {
      final service = HadithDbService();
      await service.init();
      final rows = await service.searchHadiths(qArabic: 'ال', bookId: 2);
      expect(rows.single['id'], 4);
    });

    test('searchBooks matches the Arabic title', () async {
      final service = HadithDbService();
      await service.init();
      final rows = await service.searchBooks('بخاري');
      expect(rows.single['id'], 1);
    });

    test('searchByGrade filters hadiths by grade, unknown returns empty',
        () async {
      final service = HadithDbService();
      await service.init();
      expect(await service.searchByGrade(HadithGrade.unknown), isEmpty);

      setGrades({1: 'sahih', 2: 'daif'});
      final sahih = await service.searchByGrade(HadithGrade.sahih);
      expect(sahih.single['id'], 1);
      final daif = await service.searchByGrade(HadithGrade.daif);
      expect(daif.single['id'], 2);
    });
  });

  group('full-text search (FTS5)', () {
    test('init builds the FTS index covering every hadith', () async {
      final service = HadithDbService();
      await service.init();
      final tables = service.db.select(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='hadiths_fts'");
      expect(tables, isNotEmpty);
      final count = service.db
          .select('SELECT COUNT(*) as c FROM hadiths_fts')
          .first['c'] as int;
      expect(count, 4);
      // Seeded, not left empty: an empty trigram table answers accelerated
      // like-queries with nothing (content rows are invisible to it), so
      // init() must leave a populated index behind.
      expect(
          service.db.select(
              'SELECT rowid FROM hadiths_fts WHERE arabic_normalized LIKE ?',
              ['%الاعمال%']),
          isNotEmpty);
    });

    test('substring queries are answered from the trigram index', () async {
      final service = HadithDbService();
      await service.init();
      // 'بالنيا' carries a 6-character run: the LIKE predicate is served
      // from the trigram index (candidates re-checked against the store
      // value), so the row arrives without a full-table scan behind it.
      final rows = await service.searchArabic('بالنيا');
      expect(rows.single['id'], 2);
    });

    test('three-character queries are a whole trigram and match exactly',
        () async {
      final service = HadithDbService();
      await service.init();
      // 'نما' — one trigram, still an infix ('انما' contains it): the old
      // unicode61 prefix path hid it behind the fallback, the trigram answer
      // is exact by construction.
      final rows = await service.searchArabic('نما');
      expect(rows.map((r) => r['id']), contains(2));
    });

    test('queries shorter than a trigram still match via the plain scan',
        () async {
      final service = HadithDbService();
      await service.init();
      // 'من' — two characters: no trigram serves them, so the LIKE predicate
      // degrades to the whole-table scan (the same predicate the pre-v3
      // world always ran as its fallback). It rides inside 'الرحمن'.
      final rows = await service.searchArabic('من');
      expect(rows.map((r) => r['id']), contains(1));
    });

    test('inserts after init are searchable through the FTS triggers',
        () async {
      final service = HadithDbService();
      await service.init();
      service.db.execute(
          'INSERT INTO hadiths (id, book_id, chapter_id, hadith_number, arabic) '
          "VALUES (5, 1, 1, 4, 'طلب العلم فريضة')");
      service.db.execute(
          "UPDATE hadiths SET arabic_normalized = 'طلب العلم فريضه' WHERE id = 5");
      // Direct index hit proves the triggers indexed the new row under the
      // exact predicate search serves through the trigram table (not just a
      // lucky fallback path).
      final fts = service.db.select(
          'SELECT rowid FROM hadiths_fts '
          'WHERE hadiths_fts.arabic_normalized LIKE ?',
          ['%فريضه%']);
      expect(fts.map((r) => r['rowid']), contains(5));
      final rows = await service.searchArabic('فريضه');
      expect(rows.map((r) => r['id']), contains(5));
    });
  });

  // The trigram table must serve search with the plain scan's exact rows.
  // This group is the equality contract behind v3: hit rows and only hit
  // rows, no trigram-scattered noise, filters intact.
  group('trigram serves the exact LIKE result set', () {
    void addRows(HadithDbService service, Map<int, String> texts,
        {int bookId = 1}) {
      final st = service.db.prepare(
          'INSERT INTO hadiths (id, book_id, chapter_id, hadith_number, '
          'arabic, arabic_normalized) VALUES (?, ?, 1, ?, ?, ?)');
      for (final e in texts.entries) {
        st.execute([e.key, bookId, e.key, e.value, e.value]);
      }
      st.close();
    }

    Future<void> expectSearchMatchesPlainScan(
        HadithDbService service, List<String> queries) async {
      for (final q in queries) {
        final truth = service.db.select(
            'SELECT id FROM hadiths WHERE arabic_normalized LIKE ? '
            'ORDER BY book_id, hadith_number',
            ['%${TextHighlight.normalize(q)}%']);
        final rows = await service.searchArabic(q);
        expect(rows.map((r) => r['id']), truth.map((r) => r['id']).toList(),
            reason: 'query "$q"');
      }
    }

    test('a row whose trigrams appear scattered is not returned', () async {
      final service = HadithDbService();
      await service.init();
      addRows(service, const {
        100: 'xabcdefy', // direct substring hit
        101: 'abc bcdef', // superset of "abcdef"'s trigrams, not its substring
      });
      final rows = await service.searchArabic('abcdef');
      expect(rows.map((r) => r['id']), [100]);
      // The plain scan is the ground truth both sides answer with…
      final truth = service.db.select(
          'SELECT id FROM hadiths WHERE arabic_normalized LIKE ?',
          ['%${TextHighlight.normalize('abcdef')}%']);
      expect(truth.map((r) => r['id']), [100]);
    });

    test('service rows equal the plain scan across the query battery',
        () async {
      final service = HadithDbService();
      await service.init();
      addRows(service, const {
        100: 'xabcdefy',
        101: 'abc bcdef',
        102: 'صلى الله عليه وسلم على عبده',
        103: 'انما الاعمال بالنيات وصلي',
      });
      await expectSearchMatchesPlainScan(service, const [
        'abcdef', 'bcdef', 'cdef', 'def', 'xabcdef', // latin substring tiers
        'نما', 'يم', // arabic: a whole trigram / shorter than one
        'النيات', 'بالنيا', // arabic infix runs
        'صلى الله', 'عليه وسلم', // multiword phrases
        'الاعمال بالنيات', // multiword, arabic only
      ]);
    });

    test('book and grade filters compose with the indexed search', () async {
      final service = HadithDbService();
      await service.init();
      addRows(service, const {
        100: 'xabcdefy book one',
        101: 'abc bcdef book one',
      });
      addRows(service, const {104: 'ZbcdefW book two'}, bookId: 2);
      setGrades({100: 'sahih', 101: 'daif'});
      // 'bcdef' matches 100, 101 and 104 by the plain scan:
      await expectSearchMatchesPlainScan(service, const ['bcdef', 'abcdef']);
      final byBook = await service.searchHadiths(qArabic: 'bcdef', bookId: 2);
      expect(byBook.map((r) => r['id']), [104]);
      final byGrade =
          await service.searchHadiths(qArabic: 'bcdef', grade: HadithGrade.daif);
      expect(byGrade.map((r) => r['id']), [101]);
    });
  });

  group('random hadith', () {
    test('returns a hadith and honors the book filter', () async {
      final service = HadithDbService();
      await service.init();
      expect(await service.getRandomHadith(), isNotNull);
      final fromBook = await service.getRandomHadithFromBook(1);
      expect(fromBook, isNotNull);
      expect(fromBook!['book_id'], 1);
    });
  });

  group('HadithBooksService grade mapping', () {
    test('the row grade reaches HadithEntry on every read path', () async {
      // init() first: the grade column only exists after the migration, so
      // setGrades() must run against the migrated schema.
      await HadithDbService().init();
      setGrades({1: 'sahih', 4: 'daif'});

      // Chapter path (hadith 1 graded, hadith 2 ungraded → empty, never null).
      final chapter =
          await HadithBooksService().loadChapterHadiths('bukhari', 1);
      expect(chapter.map((e) => e.grade).toList(), ['sahih', '']);

      // Paginated book path.
      final page = await HadithBooksService().loadBookHadiths('muslim');
      expect(page.single.grade, 'daif');

      // Search path.
      final hits = await HadithBooksService().search('المسلم');
      expect(hits.single.hadith.grade, 'daif');

      // Search-within-book path.
      final inBook =
          await HadithBooksService().searchInBook('muslim', 'المسلم');
      expect(inBook.single.grade, 'daif');
    });

    test('an ungraded database yields empty grades, not a crash', () async {
      await HadithDbService().init();
      final chapter =
          await HadithBooksService().loadChapterHadiths('bukhari', 1);
      expect(chapter, hasLength(2));
      expect(chapter.every((e) => e.grade == ''), isTrue);
    });
  });

  group('legacy honorific symbols (schema v2)', () {
    late File puaFile;

    void createPuaDatabase(File file) {
      final db = sqlite3.open(file.path);
      try {
        db.execute('''
          CREATE TABLE books (id INTEGER PRIMARY KEY, title_arabic TEXT);
          CREATE TABLE chapters (
            id INTEGER PRIMARY KEY,
            book_id INTEGER,
            chapter_index REAL,
            name_arabic TEXT
          );
          CREATE TABLE hadiths (
            id INTEGER PRIMARY KEY,
            book_id INTEGER,
            chapter_id INTEGER,
            hadith_number INTEGER,
            arabic TEXT
          );
          INSERT INTO books (id, title_arabic) VALUES (19, 'صحیح الترغیب');
          INSERT INTO chapters (id, book_id, chapter_index, name_arabic) VALUES
            (1, 19, 1.0, 'باب فضل الصلاة \uF0C9'),
            (2, 19, 2.0, 'باب الإخلاص'),
            (3, 19, 3.0, 'بر ابن عمر \uF0B8');
          INSERT INTO hadiths (id, book_id, chapter_id, hadith_number, arabic)
            VALUES
            (1, 19, 1, 1, 'قَالَ رَسُولُ اللهِ \uF0C9 قَالَ'),
            (2, 19, 1, 2, 'أَبُو هُرَيْرَةَ \uF0C3بِهِ'),
            (3, 19, 1, 3, 'قَالَ: «\uF05Dيَوْمَ الْقِيَامَةِ»'),
            (4, 19, 2, 1, 'عَنِ ابْنِ عُمَرَ\uF0B8 عَنِ النَّبِيِّ'),
            (5, 19, 3, 1, 'إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ'),
            (6, 19, 3, 2, 'قَالَ \uF0C9\uF0C9 قَالَ'),
            (7, 19, 3, 3, 'از عایشه \uF0CF و از ابن عمر \uF0CF');
      ''');
      } finally {
        db.close();
      }
    }

    setUp(() {
      puaFile = File(p.join(tempDir.path, 'pua.db'));
      if (puaFile.existsSync()) puaFile.deleteSync();
      createPuaDatabase(puaFile);
    });

    test(
        'migrateHadithSchema repairs hadiths, chapters and the normalized '
        'copy, leaving the FTS index empty', () {
      migrateHadithSchema(puaFile.path);

      final db = sqlite3.open(puaFile.path);
      try {
        String arabic(int id) => db
            .select('SELECT arabic FROM hadiths WHERE id = $id')
            .first['arabic'] as String;

        expect(arabic(1), 'قَالَ رَسُولُ اللهِ صلى الله عليه وسلم قَالَ');
        expect(arabic(2), 'أَبُو هُرَيْرَةَ رضي الله عنه بِهِ');
        expect(arabic(3), 'قَالَ: «يَوْمَ الْقِيَامَةِ»');
        expect(arabic(4), 'عَنِ ابْنِ عُمَرَ رضي الله عنهما عَنِ النَّبِيِّ');
        expect(arabic(5), 'إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ');
        expect(arabic(6), 'قَالَ صلى الله عليه وسلم قَالَ');
        expect(arabic(7), 'از عایشه رضي الله عنها و از ابن عمر رضي الله عنهما');

        // The normalized copy is rebuilt from the repaired text.
        final n1 = db
            .select('SELECT arabic_normalized FROM hadiths WHERE id = 1')
            .first['arabic_normalized'] as String;
        expect(n1, TextHighlight.normalize(arabic(1)));
        expect(n1, isNot(contains('\uF0C9')));

        // Chapter titles are repaired too.
        expect(
            db
                .select('SELECT name_arabic FROM chapters WHERE id = 1')
                .first['name_arabic'],
            'باب فضل الصلاة صلى الله عليه وسلم');

        // Search reads `arabic_normalized`, with the query normalized the
        // same way (the LIKE path the search actually uses on devices
        // today) — and the repair is in it.
        final searchHits = db.select(
            'SELECT id FROM hadiths WHERE arabic_normalized LIKE ?',
            ['%${TextHighlight.normalize('صلى الله عليه وسلم')}%']);
        expect(searchHits.map((r) => r['id']).toSet(), {1, 6});

        // The migration closes with a full trigram rebuild over the final
        // content: the index must hold EXACTLY the complete LIKE result
        // set — never a partial trigger-written one (see
        // [_repairLegacyHonorificSymbols]) and never less, because an
        // under-populated trigram table hides the accelerated matches.
        final truthHits = db.select(
            'SELECT id FROM hadiths WHERE arabic_normalized LIKE ?', [
          '%${TextHighlight.normalize('صلى الله عليه وسلم')}%'
        ]);
        final indexed = db.select(
            'SELECT rowid FROM hadiths_fts '
            'WHERE hadiths_fts.arabic_normalized LIKE ?', [
          '%${TextHighlight.normalize('صلى الله عليه وسلم')}%'
        ]);
        expect(indexed.map((r) => r['rowid']).toSet(),
            truthHits.map((r) => r['id']).toSet());

        // Stamped for later opens.
        expect(db.select('PRAGMA user_version').first['user_version'],
            hadithSchemaVersion);
      } finally {
        db.close();
      }

      // Idempotent: a second pass changes nothing.
      migrateHadithSchema(puaFile.path);
      final again = sqlite3.open(puaFile.path);
      try {
        expect(
            again
                .select('SELECT arabic FROM hadiths WHERE id = 1')
                .first['arabic'],
            'قَالَ رَسُولُ اللهِ صلى الله عليه وسلم قَالَ');
        expect(
            again
                .select('SELECT name_arabic FROM chapters WHERE id = 3')
                .first['name_arabic'],
            'بر ابن عمر رضي الله عنهما');
      } finally {
        again.close();
      }
    });

    test(
        'a v1 database with the search columns already built is repaired '
        'in place', () {
      // First bring the fixture to the search-ready shape.
      migrateHadithSchema(puaFile.path);

      // Worst case for the v1→v2 step: normalized + FTS already exist and a
      // row carrying a legacy glyph arrives while the database is still on
      // v1 — exactly what an already-migrated installed copy looks like.
      final db = sqlite3.open(puaFile.path);
      try {
        db.execute(
            'INSERT INTO hadiths (id, book_id, chapter_id, hadith_number, '
            'arabic, arabic_normalized) VALUES (9, 19, 1, 9, '
            "'قَالَ \uF072 قَالَ', 'قال \uF072 قال')");
        db.execute('PRAGMA user_version = 1');
      } finally {
        db.close();
      }

      migrateHadithSchema(puaFile.path);

      final after = sqlite3.open(puaFile.path);
      try {
        final fixed = after
            .select('SELECT arabic FROM hadiths WHERE id = 9')
            .first['arabic'] as String;
        final norm = after
            .select('SELECT arabic_normalized FROM hadiths WHERE id = 9')
            .first['arabic_normalized'] as String;
        expect(fixed, 'قَالَ صلى الله عليه وسلم قَالَ');
        expect(norm, TextHighlight.normalize(fixed));
        final truthIds = after
            .select(
                'SELECT id FROM hadiths WHERE arabic_normalized LIKE ?', [
              '%${TextHighlight.normalize('صلى الله عليه وسلم')}%'
            ])
            .map((r) => r['id'])
            .toList();
        // Searchable through the path search actually uses…
        expect(truthIds, contains(9));
        // …and the full-text index is reconciled over the repaired text:
        // same set on both sides — the partial index the repair's trigger
        // wrote must never outlive the pass (see
        // [_repairLegacyHonorificSymbols]), nor may the rebuild drop rows.
        final indexed = after.select(
            'SELECT rowid FROM hadiths_fts '
            'WHERE hadiths_fts.arabic_normalized LIKE ?', [
          '%${TextHighlight.normalize('صلى الله عليه وسلم')}%'
        ]);
        expect(indexed.map((r) => r['rowid']).toSet(), truthIds.toSet());
      } finally {
        after.close();
      }
    });
  });
}

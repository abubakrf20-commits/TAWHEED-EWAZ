import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'package:tawheeed/features/hadeeth_enc/services/hadeeth_enc_db_service.dart';
import 'package:tawheeed/shared/services/downloaded_sqlite_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  Future<void> createTestDatabase(File file, {bool withCategory = true}) async {
    final db = sqlite3.open(file.path);
    try {
      db.execute('''
        CREATE TABLE hadiths (
          id INTEGER,
          title_ar TEXT,
          title TEXT,
          text_ar TEXT,
          text TEXT,
          explanation TEXT,
          benefits TEXT,
          grade TEXT,
          takhrij TEXT,
          link TEXT${withCategory ? ',\n          category TEXT,\n          cat_main INTEGER' : ''}
        );
        INSERT INTO hadiths VALUES
          (1, 'حديث أول', 'حديث اول فارسي', 'نص عربي أول',
           'متن فارسی اول', 'شرح اول', 'منافع اول', 'صحیح', 'منبع اول', ''${withCategory ? ", 'فقه عبادات', 4" : ''}),
          (2, 'حديث ثان', 'حديث دوم فارسي', 'نص عربي ثان',
           'متن فارسی دوم', 'شرح دوم', 'منافع دوم', 'حسن', 'منبع دوم', ''${withCategory ? ", 'فقه خانواده', 4" : ''}),
          (3, 'حديث ثالث', 'حديث سوم فارسي', 'نص عربي ثالث',
           'متن فارسی سوم', 'شرح سوم', 'منافع سوم', 'ضعیف', 'منبع سوم', ''${withCategory ? ", 'فقه عبادات', 4" : ''});
      ''');
      if (withCategory) {
        db.execute('CREATE INDEX idx_hadeeth_category ON hadiths(category)');
      }
    } finally {
      db.close();
    }
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tawheeed_hadeeth_enc');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return tempDir.path;
      }
      return null;
    });
    await createTestDatabase(File(p.join(tempDir.path, 'hadeeth_enc.db')));
  });

  tearDown(() async {
    HadeethEncDbService().close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('isAvailable sees a categorized database on disk', () async {
    final service = HadeethEncDbService();
    expect(await service.isAvailable(), isTrue);
  });

  test('isAvailable is false for a legacy pre-category copy', () async {
    final file = File(p.join(tempDir.path, 'hadeeth_enc.db'));
    file.deleteSync();
    await createTestDatabase(file, withCategory: false);
    expect(await HadeethEncDbService().isAvailable(), isFalse);
  });

  test('init throws when the database is missing', () async {
    File(p.join(tempDir.path, 'hadeeth_enc.db')).deleteSync();
    final service = HadeethEncDbService();
    expect(service.init, throwsA(isA<ContentDatabaseMissingException>()));
  });

  test('init + getCount returns the total', () async {
    final service = HadeethEncDbService();
    expect(service.isReady, isFalse);
    await service.init();
    expect(service.isReady, isTrue);
    expect(await service.getCount(), 3);
    expect(await service.getCount(), 3); // cached second call
  });

  group('queries', () {
    test('getPage paginates ordered by id', () async {
      final service = HadeethEncDbService();
      await service.init();
      final page1 = await service.getPage(limit: 2);
      final page2 = await service.getPage(offset: 2, limit: 2);
      expect(page1.map((h) => h.id).toList(), [1, 2]);
      expect(page2.map((h) => h.id).toList(), [3]);
    });

    test('getPage filters by category', () async {
      final service = HadeethEncDbService();
      await service.init();
      final page = await service.getPage(limit: 10, category: 'فقه عبادات');
      expect(page.map((h) => h.id).toList(), [1, 3]);
    });

    test('rows carry the global hadith number (sequence)', () async {
      final service = HadeethEncDbService();
      await service.init();

      final page1 = await service.getPage(limit: 2);
      expect(page1.map((h) => h.sequence).toList(), [1, 2]);
      final page2 = await service.getPage(offset: 2, limit: 2);
      expect(page2.map((h) => h.sequence).toList(), [3]);

      // A filtered page keeps the encyclopedia number (id 3 → 3). The old
      // list-position hint renumbered such results from ۱, which made every
      // shared hadith say «حدیث شماره ۱».
      final filtered = await service.getPage(limit: 10, category: 'فقه عبادات');
      expect(filtered.map((h) => h.sequence).toList(), [1, 3]);

      expect((await service.getHadith(3))!.sequence, 3);
      expect((await service.getHadith(99)), isNull);
      expect((await service.search('منبع سوم')).single.sequence, 3);
      expect(
        (await service.getAllHadiths()).map((h) => h.sequence).toList(),
        [1, 2, 3],
      );
    });

    test('getCount supports a category filter', () async {
      final service = HadeethEncDbService();
      await service.init();
      expect(await service.getCount(category: 'فقه عبادات'), 2);
      expect(await service.getCount(category: 'فقه خانواده'), 1);
    });

    test('subCategories lists distinct topics of a main category', () async {
      final service = HadeethEncDbService();
      await service.init();
      expect(await service.subCategories(4), ['فقه خانواده', 'فقه عبادات']);
    });

    test('getHadith maps every column and returns null when missing', () async {
      final service = HadeethEncDbService();
      await service.init();
      final h = await service.getHadith(1);
      expect(h, isNotNull);
      expect(h!.text, 'متن فارسی اول');
      expect(h.titleAr, 'حديث أول');
      expect(h.grade, 'صحیح');
      expect(h.takhrij, 'منبع اول');
      expect(h.category, 'فقه عبادات');
      expect(await service.getHadith(99), isNull);
    });

    test('getAllHadiths returns all rows in id order', () async {
      final service = HadeethEncDbService();
      await service.init();
      final all = await service.getAllHadiths();
      expect(all.map((h) => h.id).toList(), [1, 2, 3]);
    });

    test('getHadithIdAt maps a list position to its hadith', () async {
      final service = HadeethEncDbService();
      await service.init();
      expect(await service.getHadithIdAt(0), 1);
      expect(await service.getHadithIdAt(2), 3);
      // Out of range: the jump target a user typed does not exist.
      expect(await service.getHadithIdAt(3), isNull);
      expect(await service.getHadithIdAt(-1), isNull);
    });

    test('hasTitle reflects the Persian title', () async {
      final service = HadeethEncDbService();
      await service.init();
      expect((await service.getHadith(1))!.hasTitle, isTrue);
    });
  });

  group('search', () {
    test('matches across text fields', () async {
      final service = HadeethEncDbService();
      await service.init();
      final byPersian = await service.search('متن فارسی دوم');
      expect(byPersian.map((h) => h.id).toList(), [2]);
      final byArabic = await service.search('نص عربي أول');
      expect(byArabic.map((h) => h.id).toList(), [1]);
      final byTakhrij = await service.search('منبع سوم');
      expect(byTakhrij.map((h) => h.id).toList(), [3]);
    });

    test('category filter narrows results', () async {
      final service = HadeethEncDbService();
      await service.init();
      final r = await service.search('متن', category: 'فقه عبادات');
      expect(r.map((h) => h.id).toList(), [1, 3]);
    });

    test('empty query returns nothing', () async {
      final service = HadeethEncDbService();
      await service.init();
      expect(await service.search('   '), isEmpty);
    });
  });

  test('close resets the database handle', () async {
    final service = HadeethEncDbService();
    await service.init();
    expect(service.isReady, isTrue);
    service.close();
    expect(service.isReady, isFalse);
  });
}

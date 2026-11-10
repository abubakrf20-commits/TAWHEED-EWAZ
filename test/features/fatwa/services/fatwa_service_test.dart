import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:tawheeed/features/fatwa/services/fatwa_service.dart';

/// Builds a tiny fixture database matching the production schema of
/// TAWHEED-EWAZ/fatwa/fatwas.db (see tools/build_fatwa_db.py).
Future<String> _fixtureDb() async {
  final dir = await Directory.systemTemp.createTemp('fatwa_test');
  final path = p.join(dir.path, 'fatwas.db');
  final db = sqlite3.open(path);
  db.execute('CREATE TABLE fatwas ('
      'id INTEGER PRIMARY KEY, '
      'question TEXT NOT NULL, '
      'answer TEXT NOT NULL, '
      'category TEXT NOT NULL, '
      'q_norm TEXT NOT NULL, '
      'search_norm TEXT NOT NULL)');

  final rows = <(int, String, String, String)>[
    (
      1,
      'حکم نماز خواندن با کفش چیست؟',
      'نماز با کفش پاک اشکال ندارد و در روایات تأکید شده است.',
      'نماز و مسجد'
    ),
    (
      2,
      'روزه قضا زنان باردار',
      'زن باردار که از روزه میترسد افطار میکند و قضا را بعدا میگیرد.',
      'روزه و رمضان'
    ),
    (
      3,
      'وضو با آب مقدس',
      'آب مباح برای وضو کافی است مگر آنکه نجاستی به آن رسیده باشد.',
      'طهارت'
    ),
    // The source text keeps its ZWNJ, which is what the shipped database
    // contains — the case the search used to miss.
    (
      4,
      'حکم مسح سر',
      'مسح سر با آب باقی‌ماندهٔ وضو انجام می‌شود.',
      'طهارت'
    ),
  ];
  for (final (id, q, a, cat) in rows) {
    final nq = FatwaService.normalizeText(q);
    final ns = FatwaService.normalizeText('$q\n$a');
    db.execute(
        'INSERT INTO fatwas VALUES (?,?,?,?,?,?)', [id, q, a, cat, nq, ns]);
  }
  db.close();
  return path;
}

void main() {
  group('FatwaService.normalizeText', () {
    test('unifies persian/arabic ye and kaf', () {
      expect(FatwaService.normalizeText('نماز'), 'نماز');
      // ی فارسی و ي عربی یکسان می‌شوند
      expect(
        FatwaService.normalizeText('می'),
        FatwaService.normalizeText('مي'),
      );
      // ک فارسی و ك عربی یکسان می‌شوند
      expect(
        FatwaService.normalizeText('کتاب'),
        FatwaService.normalizeText('كتاب'),
      );
    });

    test('strips tashkeel and unifies alif/ta-marbuta', () {
      // متن با اعراب و بدون اعراب یکسان نرمال میشود
      expect(
        FatwaService.normalizeText('كِتَابٌ مُبَارَكٌ'),
        FatwaService.normalizeText('کتاب مبارک'),
      );
      expect(FatwaService.normalizeText('أ'), FatwaService.normalizeText('ا'));
      expect(FatwaService.normalizeText('ة'), FatwaService.normalizeText('ه'));
    });
  });

  group('FatwaService (fixture db)', () {
    late FatwaService service;
    late String path;

    setUp(() async {
      path = await _fixtureDb();
      service = FatwaService.forPath(path);
      await service.ensureReady();
    });

    tearDown(() {
      service.close();
    });

    test('totalCount', () {
      expect(service.totalCount(), 4);
    });

    test('categories sorted by size', () {
      final cats = service.categories();
      expect(cats.length, 3);
      expect(cats.first['count'], 2);
    });

    test('listPage filters by category and pages', () {
      final all = service.listPage(limit: 2);
      expect(all.length, 2);
      expect(service.listPage(limit: 2, offset: 2).length, 2);

      final roza = service.listPage(category: 'روزه و رمضان');
      expect(roza.length, 1);
      expect(roza.first['question'], contains('قضا'));
    });

    test('byId returns full row', () {
      final row = service.byId(1);
      expect(row, isNotNull);
      expect(row!['answer'], contains('کفش'));
      expect(service.byId(999), isNull);
    });

    test('search matches single term in answer', () {
      final (:rows, more: more) = service.search('نجاست');
      expect(more, isFalse);
      expect(rows.length, 1);
      expect(rows.first['id'], 3);
      expect(rows.first['snippet'], isNotNull);
    });

    test('multi-term search is AND', () {
      // هر دو واژه فقط در فتوای روزه هست
      final (:rows, more: _) = service.search('باردار قضا');
      expect(rows.length, 1);
      expect(rows.first['id'], 2);
      // یکی از دو واژه ناموجود → بدون نتیجه
      final empty = service.search('باردار ناموجود');
      expect(empty.rows, isEmpty);
    });

    test('search tolerates persian vs arabic chars', () {
      // «میکند» با ي عربی ذخیره شده ولی با ی فارسی جستجو میشود
      final (:rows, more: _) = service.search('میکند');
      expect(rows.map((r) => r['id']), contains(2));
    });

    test('search respects limit and reports truncation', () {
      final r = service.search('است', limit: 1);
      expect(r.rows.length, 1);
      expect(r.more, isTrue);
    });

    test('random returns a valid entry', () {
      final f = service.random();
      expect(f, isNotNull);
      expect(f!['id'], isIn([1, 2, 3]));
    });
  });

  group('FatwaService.splitFatwa', () {
    test('splits full question from answer at جواب marker', () {
      final parts = FatwaService.splitFatwa(
          'شرایط خواندن خطبه عقد چیست؟\nجواب)الحمدلله،\nمستحب است قبل از عقد خطبه خوانده شود.');
      expect(parts.fullQuestion, 'شرایط خواندن خطبه عقد چیست؟');
      expect(parts.answer, 'مستحب است قبل از عقد خطبه خوانده شود.');
    });

    test('splits at الحمدلله marker without جواب', () {
      final parts = FatwaService.splitFatwa(
          'آیا فلان کار جایز است؟\nالحمدلله،\nجایز است.');
      expect(parts.fullQuestion, 'آیا فلان کار جایز است؟');
      expect(parts.answer, 'جایز است.');
    });

    test('returns null question when answer starts directly', () {
      final parts = FatwaService.splitFatwa('الحمدلله،\nاین کار اشکال ندارد.');
      expect(parts.fullQuestion, isNull);
      expect(parts.answer, 'این کار اشکال ندارد.');
    });

    test('no marker → whole text is the answer, no question', () {
      final parts = FatwaService.splitFatwa('نماز با کفش پاک اشکال ندارد.');
      expect(parts.fullQuestion, isNull);
      expect(parts.answer, 'نماز با کفش پاک اشکال ندارد.');
    });

    test('keeps question mark but strips other trailing punctuation', () {
      final parts = FatwaService.splitFatwa(
          'آیا جراحی زیبایی جایز است؟\nجواب)الحمدلله،\nبله جایز است.');
      expect(parts.fullQuestion, 'آیا جراحی زیبایی جایز است؟');
    });
  });

  group('search across ZWNJ', () {
    late FatwaService service;
    late String path;

    setUp(() async {
      path = await _fixtureDb();
      service = FatwaService.forPath(path);
      await service.ensureReady();
    });

    tearDown(() {
      service.close();
    });

    test('a word typed without ZWNJ finds a stored word with it', () {
      // «باقیمانده» بدون نیم‌فاصله، در حالی که متن ذخیره‌شده نیم‌فاصله دارد.
      final (:rows, more: _) = service.search('باقیمانده');
      expect(rows.length, 1, reason: 'ZWNJ must not decide the match');
      expect(rows.first['id'], 4);
    });

    test('a word typed with ZWNJ finds a stored word without it', () {
      // برعکس: کاربر نیم‌فاصله می‌زند، متن ذخیره‌شده ندارد.
      final (:rows, more: _) = service.search('کفش\u200Cها');
      // «کفش» در فتوای ۱ هست، «کفش‌ها» نه — ولی نباید خطا بدهد و باید
      // نرمال‌سازی نیم‌فاصله را حذف کرده باشد.
      expect(rows, isEmpty);
      // The fold also takes ی→ي and ک→ك, so the comparison is made against the
      // normalizer's own output rather than the Persian spelling.
      expect(FatwaService.normalizeText('کفش\u200Cها'),
          FatwaService.normalizeText('کفشها'));
    });

    test('the snippet is cut from the same text the WHERE matched', () {
      final (:rows, more: _) = service.search('باقیمانده');
      // The snippet is cut from the normalized column, so it carries the
      // folded spelling — what matters is that the term is inside it.
      expect(rows.first['snippet'],
          contains(FatwaService.normalizeText('باقیمانده')));
    });
  });

  group('byIds', () {
    late FatwaService service;
    late String path;

    setUp(() async {
      path = await _fixtureDb();
      service = FatwaService.forPath(path);
      await service.ensureReady();
    });

    tearDown(() {
      service.close();
    });

    test('returns only the asked ids, in id order', () {
      final rows = service.byIds([4, 1]);
      expect(rows.map((r) => r['id']).toList(), [1, 4]);
      expect(rows.first['question'], contains('کفش'));
    });

    test('an empty set is an empty list, not a full scan', () {
      expect(service.byIds(const []), isEmpty);
      expect(service.byIds(const <int>[]), isEmpty);
    });

    test('unknown ids are simply absent', () {
      expect(service.byIds([999, 1]).length, 1);
    });
  });
}

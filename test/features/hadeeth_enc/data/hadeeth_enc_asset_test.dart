import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:tawheeed/features/hadeeth_enc/domain/entities/hadeeth_enc_hadith.dart';

/// Strips Arabic tashkeel (combining diacritics) so plain-letter assertions
/// match the fully diacritized stored texts.
String stripDiacritics(String s) =>
    s.replaceAll(RegExp(r'\p{M}', unicode: true), '');

/// Validates the bundled موسوعه احادیث SQLite asset (the same file the app
/// copies on first launch). Guards against a corrupted/truncated export.
///
/// The database is generated locally by tools/xlsx_to_hadeeth_enc.py and is
/// gitignored, so checkouts that never ran the tool (CI, fresh worktrees)
/// skip the suite instead of failing in setUpAll — and crucially never let
/// tearDownAll close an uninitialized handle.
void main() {
  final asset = File('assets/hadeeth_enc.db');
  final skip = asset.existsSync()
      ? false
      : 'assets/hadeeth_enc.db is generated locally by '
          'tools/xlsx_to_hadeeth_enc.py and is not present in this checkout';

  group('hadeeth_enc asset', () {
    late Database db;

    setUpAll(() {
      if (skip != false) return;
      db = sqlite3.open(asset.path);
    });

    tearDownAll(() {
      if (skip != false) return;
      db.close();
    });

    test('contains all 2275 hadiths', () {
      final c =
          db.select('SELECT COUNT(*) AS c FROM hadiths').first['c'] as int;
      expect(c, 2275);
    });

    test('every hadith has Arabic text, Persian translation, grade and takhrij',
        () {
      final missing = db
          .select(
            'SELECT COUNT(*) AS c FROM hadiths '
            'WHERE text_ar IS NULL OR text_ar = \'\' '
            'OR text IS NULL OR text = \'\' '
            'OR grade IS NULL OR grade = \'\' '
            'OR takhrij IS NULL OR takhrij = \'\'',
          )
          .first['c'] as int;
      expect(missing, 0);
    });

    test('explanation is present for every hadith', () {
      final missing = db
          .select('SELECT COUNT(*) AS c FROM hadiths WHERE explanation IS NULL')
          .first['c'] as int;
      expect(missing, 0);
    });

    test('first hadith (id 1751) matches the known sample', () {
      final row = Map<String, dynamic>.from(
          db.select('SELECT * FROM hadiths WHERE id = 1751').first);
      final h = HadeethEncHadith.fromRow(row);
      expect(h.id, 1751);
      expect(stripDiacritics(h.textAr), contains('عطية'));
      expect(h.text, contains('ام عطیه'));
      expect(h.grade, contains('صحیح'));
      expect(h.takhrij, contains('متفق علیه'));
      expect(h.explanation, isNotEmpty);
      expect(h.link, contains('hadeethenc.com'));
    });

    test('rows are ordered by id (source order)', () {
      final ids = [
        for (final r in db.select('SELECT id FROM hadiths ORDER BY id'))
          r['id'] as int,
      ];
      expect(ids, orderedEquals(ids.toList()..sort()));
    });

    test('LIKE search across text finds expected hadiths', () {
      final rows = db.select(
          'SELECT id, title_ar, title FROM hadiths WHERE text LIKE ? LIMIT 5',
          ['%نیت%']);
      expect(rows, isNotEmpty);
    });

    test('advanced search covers explanation, benefits, grade and takhrij', () {
      // A term found in the explanation column is findable.
      final byExplanation = db.select(
        'SELECT id FROM hadiths WHERE (title_ar LIKE ? OR title LIKE ? OR '
        'text_ar LIKE ? OR text LIKE ? OR explanation LIKE ? OR '
        'benefits LIKE ? OR grade LIKE ? OR takhrij LIKE ?) LIMIT 5',
        [
          '%نماز%',
          '%نماز%',
          '%نماز%',
          '%نماز%',
          '%نماز%',
          '%نماز%',
          '%نماز%',
          '%نماز%'
        ],
      );
      expect(byExplanation, isNotEmpty);

      // Grade + takhrij are searchable.
      expect(
        db.select(
          'SELECT id FROM hadiths WHERE takhrij LIKE ? LIMIT 1',
          ['%متفق علیه%'],
        ),
        isNotEmpty,
      );
      expect(
        db.select(
          'SELECT id FROM hadiths WHERE grade LIKE ? LIMIT 1',
          ['%حسن%'],
        ),
        isNotEmpty,
      );
    });

    test('grade filter narrows results to matching authenticity', () {
      final sahihRows = db.select(
        'SELECT id FROM hadiths WHERE grade LIKE \'%صحیح%\' LIMIT 50',
      );
      expect(sahihRows, isNotEmpty);
      final all =
          db.select('SELECT COUNT(*) AS c FROM hadiths').first['c'] as int;
      final sahih = db
          .select(
              'SELECT COUNT(*) AS c FROM hadiths WHERE grade LIKE \'%صحیح%\'')
          .first['c'] as int;
      expect(sahih, greaterThan(0));
      expect(sahih, lessThan(all));

      // Empty query + grade filter lists every hadith of that grade.
      final hasanRows = db.select(
          'SELECT id FROM hadiths WHERE grade LIKE \'%حسن%\' ORDER BY id LIMIT ?',
          [5]);
      expect(hasanRows, isNotEmpty);
      for (final r in hasanRows) {
        final grade = db
            .select('SELECT grade FROM hadiths WHERE id = ?', [r['id']])
            .first['grade']
            .toString();
        expect(grade, contains('حسن'));
      }
    });

    test('ROW_NUMBER numbering covers every hadith exactly once', () {
      // The «شماره حدیث» shown in the list, detail and shared text/image is
      // computed with this window expression — it must stay available
      // (SQLite ≥ 3.25) and stay dense over all 2275 rows.
      final r = db.select(
        'SELECT MIN(s) AS lo, MAX(s) AS hi, COUNT(DISTINCT s) AS n FROM ('
        'SELECT ROW_NUMBER() OVER (ORDER BY id) AS s FROM hadiths)',
      );
      expect(r.first['lo'], 1);
      expect(r.first['hi'], 2275);
      expect(r.first['n'], 2275);
    });
  }, skip: skip);
}

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:tawheeed/features/adhkar/duas/data/hesn_db_service.dart';

/// Content guard for the bundled حصن المسلم database.
///
/// Whenever assets/hesn.db is rebuilt (tool/build_hesn_db.dart), bump BOTH
/// PRAGMA user_version in the tool and HesnDbService._contentVersion — then
/// update [_expectedVersion] here so the recopy-on-upgrade contract stays
/// verified.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const expectedVersion = 3;
  const expectedChapters = 132;
  const expectedIntros = 3;

  late File tmp;
  late Database db;

  setUpAll(() async {
    final data = await rootBundle.load('assets/hesn.db');
    tmp = File(
      '${Directory.systemTemp.path}/hesn_guard_${DateTime.now().millisecondsSinceEpoch}.db',
    );
    await tmp.writeAsBytes(data.buffer.asUint8List(), flush: true);
    db = sqlite3.open(tmp.path);
  });

  tearDownAll(() {
    db.close();
    if (tmp.existsSync()) tmp.deleteSync();
  });

  test('bundled content version matches HesnDbService', () {
    final v =
        (db.select('PRAGMA user_version').first.values.first as num).toInt();
    expect(v, expectedVersion);
    expect(v, HesnDbService.contentVersion);
  });

  test('book completeness: chapters + intros + items', () {
    final chapters = db
        .select("SELECT COUNT(*) c FROM chapters WHERE kind='chapter'")
        .first['c'] as int;
    final intros = db
        .select("SELECT COUNT(*) c FROM chapters WHERE kind='intro'")
        .first['c'] as int;
    final items = db.select('SELECT COUNT(*) c FROM items').first['c'] as int;
    final maxNo = db
        .select("SELECT MAX(number) m FROM chapters WHERE kind='chapter'")
        .first['m'] as int;

    expect(chapters, expectedChapters);
    expect(intros, expectedIntros);
    expect(maxNo, expectedChapters);
    expect(items, greaterThan(200));
  });

  test('no empty chapter', () {
    final orphans = db.select(
      'SELECT c.id FROM chapters c LEFT JOIN items i ON i.chapter_id = c.id '
      "WHERE c.kind='chapter' AND i.id IS NULL",
    );
    expect(orphans, isEmpty);
  });

  test('sharh coverage: most items carry commentary', () {
    final items = db.select('SELECT COUNT(*) c FROM items').first['c'] as int;
    final withSharh = db
        .select(
          'SELECT COUNT(*) c FROM items WHERE TRIM(words)<>\'\' '
          'OR TRIM(guidance)<>\'\' OR TRIM(benefits)<>\'\'',
        )
        .first['c'] as int;
    expect(withSharh / items, greaterThan(0.9));
  });
}

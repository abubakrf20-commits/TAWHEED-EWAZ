import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/quran/data/daos/ayah_highlight_dao.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late AyahHighlightDao dao;

  setUp(() {
    db = AppDatabase.withConnection(NativeDatabase.memory());
    dao = AyahHighlightDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('ayah highlights (schema v39)', () {
    test('fresh database reports the current schemaVersion', () async {
      final v = await db
          .customSelect('PRAGMA user_version')
          .getSingle()
          .then((r) => r.read<int>('user_version'));
      // Was 39. The goals work bumped the schema to v40 (foreign key +
      // indexes); pinning this test to a constant would break on every
      // future schema bump, so track the declared version instead. The
      // ayah_highlight_table creation itself is covered by the other
      // tests in this group, and the v39 → v40 upgrade contract lives in
      // app_database_schema_v40_test.dart.
      expect(v, AppDatabase.currentSchemaVersion);
    });

    test('setColor inserts and re-colors the same row', () async {
      await dao.setColor(2, 255, '#F4C95D');
      await dao.setColor(2, 255, '#7ED491');

      final rows = await dao.getAll();
      expect(rows, hasLength(1), reason: 'unique (surah, ayah) index');
      expect(rows.single.surah, 2);
      expect(rows.single.ayah, 255);
      expect(rows.single.colorHex, '#7ED491');
    });

    test('getForVerses returns only the verses on the page', () async {
      await dao.setColor(2, 255, '#F4C95D');
      await dao.setColor(2, 256, '#8FC7F2');
      await dao.setColor(3, 10, '#7ED491');

      final onPage = await dao.getForVerses(const [(2, 255), (2, 256)]);
      expect(onPage.map((r) => '${r.surah}:${r.ayah}').toSet(),
          {'2:255', '2:256'});
    });

    test('getForVerses with empty list returns empty without a query',
        () async {
      await dao.setColor(1, 1, '#F4C95D');
      expect(await dao.getForVerses(const []), isEmpty);
    });

    test('remove deletes the row and reports whether it existed', () async {
      await dao.setColor(18, 1, '#F4C95D');
      expect(await dao.remove(18, 1), isTrue);
      expect(await dao.remove(18, 1), isFalse);
      expect(await dao.getAll(), isEmpty);
    });

    test('watchAll emits on every change', () async {
      final first = await dao.watchAll().first;
      expect(first, isEmpty);

      // Seed a change, then read the next emission.
      final nextFuture = dao.watchAll().firstWhere((rows) => rows.isNotEmpty);
      await dao.setColor(112, 1, '#F2A2A2');
      final rows = await nextFuture;
      expect(rows.single.colorHex, '#F2A2A2');
    });
  });
}

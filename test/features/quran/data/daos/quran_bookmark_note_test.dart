import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/quran/data/daos/quran_bookmark_dao.dart';

/// The writer behind the ayah sheet's note tile (report §7.4).
///
/// The bookmark table has carried a nullable `note` column since the start —
/// the bookmark list even renders it — but nothing ever wrote one. These tests
/// pin the three rules the writer added: writing implies marking, a later write
/// updates the same row, and erasing the text never erases the position.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late QuranBookmarkDao dao;

  setUp(() {
    db = AppDatabase.withConnection(NativeDatabase.memory());
    dao = QuranBookmarkDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('bookmark notes (§7.4)', () {
    test('a note on an unmarked ayah creates the bookmark too', () async {
      expect(await dao.setNote(2, 255, 'تدبر در آیت‌الکرسی'), 'تدبر در آیت‌الکرسی');

      final rows = await dao.getAll();
      expect(rows, hasLength(1),
          reason: 'a note needs a bookmark row to live in');
      expect(rows.single.surah, 2);
      expect(rows.single.ayah, 255);
      expect(rows.single.note, 'تدبر در آیت‌الکرسی');
    });

    test('a later note updates the same row instead of adding one', () async {
      await dao.add(18, 10);
      await dao.setNote(18, 10, 'اول');
      await dao.setNote(18, 10, 'دوم');

      final rows = await dao.getAll();
      expect(rows, hasLength(1), reason: 'the note rides the bookmark row');
      expect(rows.single.note, 'دوم');
    });

    test('a blank note clears the text but keeps the mark', () async {
      await dao.setNote(18, 10, 'پاک‌شدنی');

      expect(await dao.setNote(18, 10, '   '), isNull);

      final row = await dao.getByAyah(18, 10);
      expect(row, isNotNull,
          reason: 'erasing the text must not cost the reader the position');
      expect(row!.note, isNull);
    });

    test('the note is trimmed before it is stored', () async {
      await dao.setNote(36, 1, '   سلام علی آل یاسین   ');
      expect((await dao.getByAyah(36, 1))!.note, 'سلام علی آل یاسین');
    });

    test('clearing the note keeps it out of the bookmark list rendering',
        () async {
      await dao.setNote(1, 1, 'کوتاه');
      await dao.setNote(1, 1, '');

      final rows = await dao.watchAll().first;
      expect(rows.single.note, isNull);
    });
  });
}

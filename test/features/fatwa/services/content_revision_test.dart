import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:tawheeed/features/fatwa/services/fatwa_service.dart';
import 'package:tawheeed/shared/services/downloaded_sqlite_db.dart';

/// A real sqlite file holding [chapters] rows — the only way to exercise the
/// shape check, which reads the file instead of the revision number.
void _writeContentDb(String path, {required int chapters}) {
  final db = sqlite3.open(path);
  db.execute('CREATE TABLE chapters (id INTEGER PRIMARY KEY, name TEXT)');
  for (var i = 1; i <= chapters; i++) {
    db.execute("INSERT INTO chapters (name) VALUES ('x$i')");
  }
  db.close();
}

/// `ContentDownloadService.ensureDownloaded` returns early for any file that is
/// already on disk ("downloaded exactly once ... kept forever"), so a
/// republished database would never reach an existing install. The revision
/// counter is what forces a re-fetch — these tests pin that down.
class _FakeContentDb extends DownloadedSqliteDbService {
  _FakeContentDb(this.path,
      {required super.contentRevision, super.minChapters = 0})
      : super(
          dbFileName: 'content.db',
          remoteKey: 'fake/content.db',
        );

  final String path;

  @override
  Future<String> localPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late File dbFile;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = await Directory.systemTemp.createTemp('content_rev');
    dbFile = File(p.join(dir.path, 'content.db'));
    // `ContentDownloadService.isDownloaded` requires more than 1000 bytes.
    await dbFile.writeAsBytes(List<int>.filled(2048, 65));
  });

  tearDown(() async {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('a copy that was never versioned counts as outdated', () async {
    final service = _FakeContentDb(dbFile.path, contentRevision: 2);
    expect(await service.isDownloadedFile(), isTrue);
    expect(await service.needsUpdate(), isTrue,
        reason: 'no stored revision means it predates this build');
  });

  test('a copy at the same revision is up to date', () async {
    SharedPreferences.setMockInitialValues({'content_rev_content.db': 2});
    final service = _FakeContentDb(dbFile.path, contentRevision: 2);
    expect(await service.needsUpdate(), isFalse);
  });

  test('a copy from a newer revision is left alone (no downgrade)', () async {
    SharedPreferences.setMockInitialValues({'content_rev_content.db': 9});
    final service = _FakeContentDb(dbFile.path, contentRevision: 2);
    expect(await service.needsUpdate(), isFalse);
  });

  test('a missing copy is not an update, just a first download', () async {
    await dbFile.delete();
    final service = _FakeContentDb(dbFile.path, contentRevision: 2);
    expect(await service.isDownloadedFile(), isFalse);
    expect(await service.needsUpdate(), isFalse);
  });

  test('raising the revision marks an existing copy outdated', () async {
    SharedPreferences.setMockInitialValues({'content_rev_content.db': 2});
    final old = _FakeContentDb(dbFile.path, contentRevision: 2);
    final newer = _FakeContentDb(dbFile.path, contentRevision: 7);
    expect(await old.needsUpdate(), isFalse);
    expect(await newer.needsUpdate(), isTrue,
        reason: 'a rebuilt app with a higher revision must refetch');
  });

  test('deleting the content clears the recorded revision', () async {
    SharedPreferences.setMockInitialValues({'content_rev_content.db': 2});
    final service = _FakeContentDb(dbFile.path, contentRevision: 2);
    expect(await service.needsUpdate(), isFalse);

    await service.deleteDownloadedFile();

    expect(dbFile.existsSync(), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('content_rev_content.db'), isNull,
        reason: 'a removed copy must not claim to be up to date');
  });

  test(
      'a copy shorter than the shipped shape is outdated even when its '
      'revision matches', () async {
    SharedPreferences.setMockInitialValues({'content_rev_content.db': 2});
    // Revision 2 recorded over the one-volume parse — the معالم trap: the
    // number matched, the bytes were stale, and nothing ever refetched.
    dbFile.deleteSync();
    _writeContentDb(dbFile.path, chapters: 1);

    final service =
        _FakeContentDb(dbFile.path, contentRevision: 2, minChapters: 10);
    expect(await service.needsUpdate(), isTrue,
        reason: '1 chapter is not the payload a 10-chapter build ships');
  });

  test('a copy of the shipped shape at the same revision is up to date',
      () async {
    SharedPreferences.setMockInitialValues({'content_rev_content.db': 2});
    dbFile.deleteSync();
    _writeContentDb(dbFile.path, chapters: 12);

    final service =
        _FakeContentDb(dbFile.path, contentRevision: 2, minChapters: 10);
    expect(await service.needsUpdate(), isFalse);
  });

  test('an unreadable copy is outdated, never trusted', () async {
    SharedPreferences.setMockInitialValues({'content_rev_content.db': 2});
    // The 2 KB of 'A' setUp wrote: a truncated or half-decompressed download,
    // which still records the revision it attempted.
    final service =
        _FakeContentDb(dbFile.path, contentRevision: 2, minChapters: 10);
    expect(await service.needsUpdate(), isTrue);
  });

  test('the fatwa service is pinned to the revision that fixed the sect rows',
      () async {
    // Regression guard: republishing fatwas.db without bumping this leaves
    // installed copies on the old, uncorrected database forever.
    expect(FatwaService().contentRevision, greaterThanOrEqualTo(2));
  });
}

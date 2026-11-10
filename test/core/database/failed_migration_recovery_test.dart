import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:tawheeed/core/database/app_database.dart';

/// Recovery from `app.sqlite.migration_failed` (audit SEC H2).
///
/// The recovery path runs inside `AppDatabase._openConnection`, which is not
/// reachable without a real documents directory, so the helper is exercised
/// directly against a temp directory. It is `@visibleForTesting`-shaped on
/// purpose: every branch here runs on the user's data at startup.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File db;
  late File backup;
  late File marker;

  setUp(() async {
    tempDir =
        await Directory.systemTemp.createTemp('tawheeed_migration_recovery');
    db = File(p.join(tempDir.path, 'app.sqlite'));
    backup = File(p.join(tempDir.path, 'app.sqlite.backup'));
    marker = File(p.join(tempDir.path, 'app.sqlite.migration_failed'));
  });

  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('restores the snapshot and clears the marker', () async {
    await db.writeAsString('half-migrated');
    await backup.writeAsString('known-good');
    await marker.writeAsString('2025-01-01T00:00:00.000');

    await AppDatabase.recoverFromFailedMigration(tempDir, db, backup, marker);

    expect(await db.readAsString(), 'known-good');
    expect(marker.existsSync(), isFalse);
  });

  test('keeps the half-migrated database as a forensic copy', () async {
    await db.writeAsString('half-migrated');
    await backup.writeAsString('known-good');
    await marker.writeAsString('failed');

    await AppDatabase.recoverFromFailedMigration(tempDir, db, backup, marker);

    // In the diagnostics subdirectory, not the documents root: Android backup
    // rules cannot glob, so a timestamped copy in the root could not be
    // excluded from the cloud backup.
    final diag = Directory(p.join(tempDir.path, 'database_diagnostics'));
    expect(diag.existsSync(), isTrue);
    final copies = diag.listSync().whereType<File>().toList();
    expect(copies, hasLength(1));
    expect(await copies.single.readAsString(), 'half-migrated');
    expect(
      tempDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('corrupt')),
      isEmpty,
    );
  });

  test('prunes forensic copies beyond the retained generations', () async {
    final diag = Directory(p.join(tempDir.path, 'database_diagnostics'))
      ..createSync(recursive: true);
    for (var i = 0; i < 6; i++) {
      File(p.join(diag.path, 'app.sqlite.100000000000$i.sqlite'))
          .writeAsStringSync('copy-$i');
    }
    await db.writeAsString('half-migrated');
    await backup.writeAsString('known-good');
    await marker.writeAsString('failed');

    await AppDatabase.recoverFromFailedMigration(tempDir, db, backup, marker);

    final kept = diag.listSync().whereType<File>().length;
    expect(kept, lessThanOrEqualTo(4));
  });

  test('recovers even when the live database is already gone', () async {
    await backup.writeAsString('known-good');
    await marker.writeAsString('failed');

    await AppDatabase.recoverFromFailedMigration(tempDir, db, backup, marker);

    expect(await db.readAsString(), 'known-good');
    expect(marker.existsSync(), isFalse);
  });

  test('leaves no temp file behind after a successful restore', () async {
    await db.writeAsString('half-migrated');
    await backup.writeAsString('known-good');
    await marker.writeAsString('failed');

    await AppDatabase.recoverFromFailedMigration(tempDir, db, backup, marker);

    expect(File(p.join(tempDir.path, 'app.sqlite.restore.tmp')).existsSync(),
        isFalse);
  });

  test('keeps the marker when there is no snapshot to roll back to', () async {
    await db.writeAsString('half-migrated');
    await marker.writeAsString('failed');

    await AppDatabase.recoverFromFailedMigration(tempDir, db, backup, marker);

    // The marker is the only signal that this database is mid-migration;
    // dropping it would silently keep a half-migrated schema forever.
    expect(marker.existsSync(), isTrue);
    expect(await db.readAsString(), 'half-migrated');
  });

  test('a stale temp file does not block the restore', () async {
    await db.writeAsString('half-migrated');
    await backup.writeAsString('known-good');
    await marker.writeAsString('failed');
    await File(p.join(tempDir.path, 'app.sqlite.restore.tmp'))
        .writeAsString('truncated-garbage');

    await AppDatabase.recoverFromFailedMigration(tempDir, db, backup, marker);

    expect(await db.readAsString(), 'known-good');
  });

  test('keeps the marker and the database when the snapshot copy fails',
      () async {
    await db.writeAsString('half-migrated');
    await marker.writeAsString('failed');
    // A directory where the snapshot file is expected makes `copy` throw.
    await Directory(backup.path).create();

    await AppDatabase.recoverFromFailedMigration(tempDir, db, backup, marker);

    expect(marker.existsSync(), isTrue);
    expect(await db.readAsString(), 'half-migrated');
  });

  test('restored snapshot is a usable sqlite database', () async {
    // End-to-end: write a real DB, snapshot it, corrupt the live copy, recover.
    final source = File(p.join(tempDir.path, 'source.sqlite'));
    final seed = AppDatabase.withConnection(NativeDatabase(source));
    await seed.customStatement('CREATE TABLE probe(id INTEGER PRIMARY KEY)');
    await seed.customStatement('INSERT INTO probe(id) VALUES (7)');
    await seed.close();
    await source.copy(backup.path);
    await db.writeAsString('not a database at all');
    await marker.writeAsString('failed');

    await AppDatabase.recoverFromFailedMigration(tempDir, db, backup, marker);

    final restored = AppDatabase.withConnection(NativeDatabase(db));
    final rows = await restored.customSelect('SELECT id FROM probe').get();
    expect(rows.single.read<int>('id'), 7);
    await restored.close();
  });

  test('two failures in a row each keep their own forensic copy', () async {
    // Both attempts must survive: the second recovery backs up the file the
    // first one restored, and the millisecond stamp keeps the names distinct.
    for (final i in [0, 1]) {
      await db.writeAsString('attempt-$i');
      await backup.writeAsString('known-good-$i');
      await marker.writeAsString('failed-$i');
      await AppDatabase.recoverFromFailedMigration(tempDir, db, backup, marker);
    }

    final diag = Directory(p.join(tempDir.path, 'database_diagnostics'));
    final copies = diag.existsSync()
        ? diag.listSync().whereType<File>().toList()
        : <File>[];
    expect(copies, hasLength(2));
    expect(copies.map((f) => p.basename(f.path)).toSet(), hasLength(2));
    expect(await db.readAsString(), 'known-good-1');
    expect(marker.existsSync(), isFalse);
  });
}

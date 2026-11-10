import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/personal/family_faith/data/family_faith_repository.dart';
import 'package:tawheeed/features/personal/family_faith/data/family_faith_tables.dart';
import 'package:tawheeed/features/worship/silat_al_rahim/domain/silat_al_rahim_models.dart';
import 'package:tawheeed/features/personal/family_faith/savings/savings_models.dart';

/// The backup path is generic: a portable backup is a `VACUUM INTO` snapshot of
/// the whole database, and restore copies every table name the two sides share.
/// So the only thing that can go wrong for a new tool is a table that is
/// missing from the snapshot or from restore's table list.
///
/// This drives the real snapshot on a real file and reads every stage-3 table
/// back out of it.
void main() {
  late Directory dir;
  late File live;
  late File snapshot;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('ff_backup');
    live = File('${dir.path}${Platform.pathSeparator}app.db');
    snapshot = File('${dir.path}${Platform.pathSeparator}backup.db');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  Future<void> writeSample(AppDatabase db) async {
    final relatives = DriftRelativesRepository(db);
    final savings = DriftSavingsRepository(db);

    final relative = Relative(
      id: 'r1',
      name: 'عمه زهرا',
      relation: RelationKind.paternalAunt,
      phone: '09120000000',
      createdAt: DateTime(2026, 1, 2),
      lastContactAt: DateTime(2026, 9, 1),
    );
    await relatives.saveRelative(relative);
    await relatives.saveContact(ContactLog(
      id: 'c1',
      relativeId: 'r1',
      date: DateTime(2026, 9, 1),
      kind: ContactKind.call,
    ));

    await savings.saveGoal(SavingsGoal(
      id: 'g1',
      title: 'سفر',
      targetAmount: 1000000,
      createdAt: DateTime(2026, 6, 1),
    ));
    await savings.saveDeposit(Deposit(
      id: 'd1',
      goalId: 'g1',
      date: DateTime(2026, 8, 1),
      amount: 250000,
    ));
  }

  test('every stage-3 table survives the backup snapshot', () async {
    final db = AppDatabase.withConnection(NativeDatabase(live));
    await writeSample(db);
    await db.customStatement('VACUUM INTO ?', [snapshot.path]);
    await db.close();
    expect(await snapshot.exists(), isTrue);

    final restored = AppDatabase.withConnection(NativeDatabase(snapshot));
    for (final table in FamilyFaithTables.tableNames) {
      final rows = await restored
          .customSelect('SELECT COUNT(*) AS c FROM $table')
          .getSingle();
      expect(rows.data['c'], greaterThan(0), reason: '$table is empty');
    }
    // Spot-check the content, not just the row count.
    final name = await restored
        .customSelect("SELECT name FROM relative WHERE id = 'r1'")
        .getSingle();
    expect(name.data['name'], 'عمه زهرا');
    await restored.close();
  });

  test('the table list is complete against the real schema', () async {
    final db = AppDatabase.withConnection(NativeDatabase(live));
    await writeSample(db);
    await db.customStatement('VACUUM INTO ?', [snapshot.path]);
    await db.close();

    final opened = AppDatabase.withConnection(NativeDatabase(snapshot));
    final rows = await opened
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    final names = rows.map((row) => row.data['name'] as String).toSet();
    for (final table in FamilyFaithTables.tableNames) {
      expect(names, contains(table));
    }
    // No stage-3 table may exist outside the list, or restore would drop it.
    final stage3 = names
        .where((name) =>
            name == 'relative' ||
            name.startsWith('relative_') ||
            name.startsWith('savings_'))
        .toSet();
    expect(stage3, FamilyFaithTables.tableNames.toSet());
    await opened.close();
  });
}

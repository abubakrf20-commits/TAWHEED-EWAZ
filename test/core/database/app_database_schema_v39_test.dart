import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/database/app_database.dart';

/// Audit 3.1: schema v39 — orphan sweeps for personal-profile→documents and
/// the two hot-column indexes (expense.date, identity_document.profile_id).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.withConnection(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('schema v39 (audit phase 3)', () {
    test('fresh database reports the current schemaVersion', () async {
      final v = await db
          .customSelect('PRAGMA user_version')
          .getSingle()
          .then((r) => r.read<int>('user_version'));
      // Tracked against the constant rather than a literal. This test is
      // about what v39 ADDED — its indexes and its orphan sweep — and those
      // must survive every later version bump. Pinning the number here just
      // guaranteed this file would fail on the next schema change while
      // saying nothing about v39 itself.
      expect(v, AppDatabase.currentSchemaVersion);
      expect(v, greaterThanOrEqualTo(39));
    });

    test('v39 indexes exist on expense.date and identity_document.profile_id',
        () async {
      final rows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='index' "
            "AND name IN ('idx_expense_date', 'idx_identity_doc_profile')",
          )
          .get();
      final names = rows.map((r) => r.read<String>('name')).toSet();
      expect(
          names,
          containsAll(
              <String>['idx_expense_date', 'idx_identity_doc_profile']));
    });

    test('orphan cleanup deletes documents whose profile is gone', () async {
      final now = DateTime.now();
      await db.into(db.personalProfileTable).insert(
            PersonalProfileTableCompanion.insert(
              id: 'p1',
              name: 'خودم',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db.into(db.identityDocumentTable).insert(
            IdentityDocumentTableCompanion.insert(
              id: 'doc-kept',
              profileId: 'p1',
              title: 'کارت ملی',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db.into(db.identityDocumentTable).insert(
            IdentityDocumentTableCompanion.insert(
              id: 'doc-orphan',
              profileId: 'p-deleted',
              title: 'شناسنامهٔ یتیم',
              createdAt: now,
              updatedAt: now,
            ),
          );

      await db.cleanupOrphanRowsForTest();

      final kept = await db.select(db.identityDocumentTable).get();
      expect(kept.map((d) => d.id), ['doc-kept']);
    });
  });
}

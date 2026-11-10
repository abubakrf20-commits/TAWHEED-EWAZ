import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';

final personalInfoDaoProvider = Provider<PersonalInfoDao>((ref) {
  return PersonalInfoDao(ref.read(appDatabaseProvider));
});

class PersonalInfoDao {
  final AppDatabase db;
  PersonalInfoDao(this.db);

  // ── Profiles ────────────────────────────────────────────────
  Future<List<PersonalProfileTableData>> getAllProfiles() =>
      (db.select(db.personalProfileTable)
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .get();

  Future<PersonalProfileTableData?> getProfile(String id) =>
      (db.select(db.personalProfileTable)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<void> upsertProfile(PersonalProfileTableCompanion entry) =>
      db.into(db.personalProfileTable).insertOnConflictUpdate(entry);

  Future<void> deleteProfile(String id) =>
      (db.delete(db.personalProfileTable)..where((t) => t.id.equals(id))).go();

  // ── Identity documents ─────────────────────────────────────
  Future<List<IdentityDocumentTableData>> getDocumentsForProfile(
          String profileId) =>
      (db.select(db.identityDocumentTable)
            ..where((t) => t.profileId.equals(profileId))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .get();

  Future<IdentityDocumentTableData?> getDocument(String id) =>
      (db.select(db.identityDocumentTable)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<void> upsertDocument(IdentityDocumentTableCompanion entry) =>
      db.into(db.identityDocumentTable).insertOnConflictUpdate(entry);

  Future<void> deleteDocument(String id) =>
      (db.delete(db.identityDocumentTable)..where((t) => t.id.equals(id))).go();

  // ── Credentials ────────────────────────────────────────────
  Future<List<CredentialTableData>> getCredentials({String? category}) {
    final q = db.select(db.credentialTable)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    if (category != null) q.where((t) => t.category.equals(category));
    return q.get();
  }

  Future<void> upsertCredential(CredentialTableCompanion entry) =>
      db.into(db.credentialTable).insertOnConflictUpdate(entry);

  Future<void> deleteCredential(String id) =>
      (db.delete(db.credentialTable)..where((t) => t.id.equals(id))).go();

  // ── Assets ─────────────────────────────────────────────────
  Future<List<AssetTableData>> getAssets({String? category}) {
    final q = db.select(db.assetTable)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    if (category != null) q.where((t) => t.category.equals(category));
    return q.get();
  }

  Future<void> upsertAsset(AssetTableCompanion entry) =>
      db.into(db.assetTable).insertOnConflictUpdate(entry);

  Future<void> deleteAsset(String id) =>
      (db.delete(db.assetTable)..where((t) => t.id.equals(id))).go();

  // ── Insurance ──────────────────────────────────────────────
  Future<List<InsuranceTableData>> getInsurances() =>
      (db.select(db.insuranceTable)
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .get();

  Future<void> upsertInsurance(InsuranceTableCompanion entry) =>
      db.into(db.insuranceTable).insertOnConflictUpdate(entry);

  Future<void> deleteInsurance(String id) =>
      (db.delete(db.insuranceTable)..where((t) => t.id.equals(id))).go();

  // ── Emergency contacts ─────────────────────────────────────
  Future<List<EmergencyContactTableData>> getEmergencyContacts() =>
      (db.select(db.emergencyContactTable)
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .get();

  Future<void> upsertEmergencyContact(EmergencyContactTableCompanion entry) =>
      db.into(db.emergencyContactTable).insertOnConflictUpdate(entry);

  Future<void> deleteEmergencyContact(String id) =>
      (db.delete(db.emergencyContactTable)..where((t) => t.id.equals(id))).go();

  // ── Expiry items ───────────────────────────────────────────
  Future<List<ExpiryItemTableData>> getExpiryItems(
      {bool includeArchived = false}) {
    final q = db.select(db.expiryItemTable)
      ..orderBy([(t) => OrderingTerm.asc(t.dueDate)]);
    if (!includeArchived) q.where((t) => t.isArchived.equals(false));
    return q.get();
  }

  Future<ExpiryItemTableData?> getExpiryItem(String id) =>
      (db.select(db.expiryItemTable)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<void> upsertExpiryItem(ExpiryItemTableCompanion entry) =>
      db.into(db.expiryItemTable).insertOnConflictUpdate(entry);

  Future<void> deleteExpiryItem(String id) =>
      (db.delete(db.expiryItemTable)..where((t) => t.id.equals(id))).go();

  Future<List<ExpiryItemTableData>> getActiveRemindableItems() => (db
          .select(db.expiryItemTable)
        ..where(
            (t) => t.remindEnabled.equals(true) & t.isArchived.equals(false)))
      .get();
}

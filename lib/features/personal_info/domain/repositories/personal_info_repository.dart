import 'package:tawheeed/core/database/app_database.dart';

/// Abstraction over «اطلاعات من» persistence. All rows are stored in the
/// main Drift database (so portable/cloud backup keeps them); sensitive
/// fields are already AES-encrypted by the caller before reaching the DAO.
abstract class PersonalInfoRepository {
  // Profiles
  Future<List<PersonalProfileTableData>> getAllProfiles();
  Future<PersonalProfileTableData?> getProfile(String id);
  Future<void> upsertProfile(PersonalProfileTableCompanion entry);
  Future<void> deleteProfile(String id);

  // Identity documents
  Future<List<IdentityDocumentTableData>> getDocumentsForProfile(
      String profileId);
  Future<IdentityDocumentTableData?> getDocument(String id);
  Future<void> upsertDocument(IdentityDocumentTableCompanion entry);
  Future<void> deleteDocument(String id);

  // Credentials
  Future<List<CredentialTableData>> getCredentials({String? category});
  Future<void> upsertCredential(CredentialTableCompanion entry);
  Future<void> deleteCredential(String id);

  // Assets
  Future<List<AssetTableData>> getAssets({String? category});
  Future<void> upsertAsset(AssetTableCompanion entry);
  Future<void> deleteAsset(String id);

  // Insurance
  Future<List<InsuranceTableData>> getInsurances();
  Future<void> upsertInsurance(InsuranceTableCompanion entry);
  Future<void> deleteInsurance(String id);

  // Emergency contacts
  Future<List<EmergencyContactTableData>> getEmergencyContacts();
  Future<void> upsertEmergencyContact(EmergencyContactTableCompanion entry);
  Future<void> deleteEmergencyContact(String id);

  // Expiry items
  Future<List<ExpiryItemTableData>> getExpiryItems(
      {bool includeArchived = false});
  Future<ExpiryItemTableData?> getExpiryItem(String id);
  Future<void> upsertExpiryItem(ExpiryItemTableCompanion entry);
  Future<void> deleteExpiryItem(String id);
  Future<List<ExpiryItemTableData>> getActiveRemindableItems();

  /// Explode a profile (its identity documents too) and delete every row —
  /// the caller is responsible for deleting the related files on disk.
  Future<void> deleteProfileWithDocuments(String profileId);
}

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';
import 'package:tawheeed/features/personal_info/data/daos/personal_info_dao.dart';
import 'package:tawheeed/features/personal_info/domain/repositories/personal_info_repository.dart';
import 'package:tawheeed/features/personal_info/services/attachment_storage.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

final personalInfoRepositoryProvider = Provider<PersonalInfoRepository>((ref) {
  return PersonalInfoRepositoryImpl(ref.read(personalInfoDaoProvider));
});

final personalInfoDaoProvider = Provider<PersonalInfoDao>((ref) {
  return PersonalInfoDao(ref.read(appDatabaseProvider));
});

class PersonalInfoRepositoryImpl implements PersonalInfoRepository {
  final PersonalInfoDao _dao;
  PersonalInfoRepositoryImpl(this._dao);

  @override
  Future<List<PersonalProfileTableData>> getAllProfiles() =>
      _dao.getAllProfiles();

  @override
  Future<PersonalProfileTableData?> getProfile(String id) =>
      _dao.getProfile(id);

  @override
  Future<void> upsertProfile(PersonalProfileTableCompanion entry) =>
      _dao.upsertProfile(entry);

  @override
  Future<void> deleteProfile(String id) => _dao.deleteProfile(id);

  @override
  Future<List<IdentityDocumentTableData>> getDocumentsForProfile(
          String profileId) =>
      _dao.getDocumentsForProfile(profileId);

  @override
  Future<IdentityDocumentTableData?> getDocument(String id) =>
      _dao.getDocument(id);

  @override
  Future<void> upsertDocument(IdentityDocumentTableCompanion entry) =>
      _dao.upsertDocument(entry);

  @override
  Future<void> deleteDocument(String id) => _dao.deleteDocument(id);

  @override
  Future<List<CredentialTableData>> getCredentials({String? category}) =>
      _dao.getCredentials(category: category);

  @override
  Future<void> upsertCredential(CredentialTableCompanion entry) =>
      _dao.upsertCredential(entry);

  @override
  Future<void> deleteCredential(String id) => _dao.deleteCredential(id);

  @override
  Future<List<AssetTableData>> getAssets({String? category}) =>
      _dao.getAssets(category: category);

  @override
  Future<void> upsertAsset(AssetTableCompanion entry) =>
      _dao.upsertAsset(entry);

  @override
  Future<void> deleteAsset(String id) => _dao.deleteAsset(id);

  @override
  Future<List<InsuranceTableData>> getInsurances() => _dao.getInsurances();

  @override
  Future<void> upsertInsurance(InsuranceTableCompanion entry) =>
      _dao.upsertInsurance(entry);

  @override
  Future<void> deleteInsurance(String id) => _dao.deleteInsurance(id);

  @override
  Future<List<EmergencyContactTableData>> getEmergencyContacts() =>
      _dao.getEmergencyContacts();

  @override
  Future<void> upsertEmergencyContact(EmergencyContactTableCompanion entry) =>
      _dao.upsertEmergencyContact(entry);

  @override
  Future<void> deleteEmergencyContact(String id) =>
      _dao.deleteEmergencyContact(id);

  @override
  Future<List<ExpiryItemTableData>> getExpiryItems(
          {bool includeArchived = false}) =>
      _dao.getExpiryItems(includeArchived: includeArchived);

  @override
  Future<ExpiryItemTableData?> getExpiryItem(String id) =>
      _dao.getExpiryItem(id);

  @override
  Future<void> upsertExpiryItem(ExpiryItemTableCompanion entry) =>
      _dao.upsertExpiryItem(entry);

  @override
  Future<void> deleteExpiryItem(String id) => _dao.deleteExpiryItem(id);

  @override
  Future<List<ExpiryItemTableData>> getActiveRemindableItems() =>
      _dao.getActiveRemindableItems();

  @override
  Future<void> deleteProfileWithDocuments(String profileId) async {
    final docs = await _dao.getDocumentsForProfile(profileId);
    for (final d in docs) {
      await _dao.deleteDocument(d.id);
      // Audit 3.1-2: delete the document photos from disk too — the
      // document screen already does this for single-document deletes,
      // but the profile-wide path previously left every image behind.
      if (d.imagesJson.isNotEmpty) {
        await _deleteDocImages(d.imagesJson);
      }
    }
    await _dao.deleteProfile(profileId);
  }

  static Future<void> _deleteDocImages(String imagesJson) async {
    try {
      final list = (jsonDecode(imagesJson) as List<dynamic>)
          .whereType<String>()
          .toList();
      await AttachmentStorage.deleteStoredList(list);
    } catch (e) {
      // Never block the profile delete on a malformed path list; the
      // v38 orphan sweep will still clean the rows, and stale files are
      // bounded by the attachment cap.
      AppLogger.warning(
          'PersonalInfo', 'profile document image cleanup failed: $e');
    }
  }
}

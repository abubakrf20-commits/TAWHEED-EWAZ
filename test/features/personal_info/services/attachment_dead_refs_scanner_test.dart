import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/personal_info/domain/repositories/personal_info_repository.dart';
import 'package:tawheeed/features/personal_info/services/attachment_dead_refs_scanner.dart';

/// In-memory repository: scan reads the four lists, sweep writes companions
/// back into them so the post-sweep re-scan sees the pruned state.
class _FakeRepo implements PersonalInfoRepository {
  final List<PersonalProfileTableData> profiles;
  final Map<String, List<IdentityDocumentTableData>> documents;
  final List<AssetTableData> assets;
  final List<InsuranceTableData> insurances;

  final List<PersonalProfileTableCompanion> profileWrites = [];
  final List<IdentityDocumentTableCompanion> documentWrites = [];
  final List<AssetTableCompanion> assetWrites = [];
  final List<InsuranceTableCompanion> insuranceWrites = [];

  _FakeRepo({
    this.profiles = const [],
    Map<String, List<IdentityDocumentTableData>>? documents,
    this.assets = const [],
    this.insurances = const [],
  }) : documents = documents ?? {};

  @override
  Future<List<PersonalProfileTableData>> getAllProfiles() async => profiles;

  @override
  Future<List<IdentityDocumentTableData>> getDocumentsForProfile(
          String profileId) async =>
      documents[profileId] ?? const [];

  @override
  Future<List<AssetTableData>> getAssets({String? category}) async => assets;

  @override
  Future<List<InsuranceTableData>> getInsurances() async => insurances;

  @override
  Future<void> upsertProfile(PersonalProfileTableCompanion entry) async {
    profileWrites.add(entry);
    final i = profiles.indexWhere((r) => r.id == entry.id.value);
    if (i >= 0 && entry.avatarPath.present) {
      profiles[i] = profiles[i].copyWith(avatarPath: entry.avatarPath.value);
    }
  }

  @override
  Future<void> upsertDocument(IdentityDocumentTableCompanion entry) async {
    documentWrites.add(entry);
    for (final list in documents.values) {
      final i = list.indexWhere((r) => r.id == entry.id.value);
      if (i >= 0 && entry.imagesJson.present) {
        list[i] = list[i].copyWith(imagesJson: entry.imagesJson.value);
      }
    }
  }

  @override
  Future<void> upsertAsset(AssetTableCompanion entry) async {
    assetWrites.add(entry);
    final i = assets.indexWhere((r) => r.id == entry.id.value);
    if (i >= 0 && entry.attachmentsJson.present) {
      assets[i] =
          assets[i].copyWith(attachmentsJson: entry.attachmentsJson.value);
    }
  }

  @override
  Future<void> upsertInsurance(InsuranceTableCompanion entry) async {
    insuranceWrites.add(entry);
    final i = insurances.indexWhere((r) => r.id == entry.id.value);
    if (i >= 0 && entry.attachmentsJson.present) {
      insurances[i] =
          insurances[i].copyWith(attachmentsJson: entry.attachmentsJson.value);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PersonalProfileTableData _profile(String id, String name,
        {String avatarPath = ''}) =>
    PersonalProfileTableData(
      id: id,
      name: name,
      relation: '',
      birthDate: '',
      nationalId: '',
      birthCertNo: '',
      passportNo: '',
      phone: '',
      address: '',
      notes: '',
      colorHex: '',
      avatarPath: avatarPath,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

IdentityDocumentTableData _document(String id, String profileId, String title,
        {String imagesJson = ''}) =>
    IdentityDocumentTableData(
      id: id,
      profileId: profileId,
      docType: 'other',
      title: title,
      documentNo: '',
      issuedPlace: '',
      issuedDate: '',
      expiryDate: '',
      notes: '',
      imagesJson: imagesJson,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

AssetTableData _asset(String id, String title, {String attachmentsJson = ''}) =>
    AssetTableData(
      id: id,
      category: 'other',
      title: title,
      details: '',
      registrationNo: '',
      attachmentsJson: attachmentsJson,
      notes: '',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

InsuranceTableData _insurance(String id, String title,
        {String attachmentsJson = ''}) =>
    InsuranceTableData(
      id: id,
      title: title,
      provider: '',
      policyNo: '',
      startDate: '',
      expiryDate: '',
      attachmentsJson: attachmentsJson,
      notes: '',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  late Directory docsDir;
  late Directory root;

  setUp(() async {
    docsDir = await Directory.systemTemp.createTemp('dead_refs_test');
    root =
        Directory(p.join(docsDir.path, 'app_data', 'attachments', 'document'));
    await root.create(recursive: true);
  });

  tearDown(() async {
    if (await docsDir.exists()) await docsDir.delete(recursive: true);
  });

  Future<File> store(String name, {String kind = 'document'}) async {
    final dir =
        Directory(p.join(docsDir.path, 'app_data', 'attachments', kind));
    await dir.create(recursive: true);
    return File(p.join(dir.path, name))..writeAsBytesSync(const [1, 2, 3]);
  }

  AttachmentDeadRefsScanner scannerFor(_FakeRepo repo) =>
      AttachmentDeadRefsScanner(
        repository: repo,
        documentsDirectory: () async => docsDir,
      );

  test('scan separates orphan files from dangling references', () async {
    final live = await store('live.png');
    await store('orphan.png');
    final missing = p.join(root.path, 'gone.png');

    final repo = _FakeRepo(
      profiles: [_profile('p1', 'خودم', avatarPath: live.path)],
      documents: {
        'p1': [
          _document('d1', 'p1', 'کارت ملی',
              imagesJson: jsonEncode([live.path, missing])),
        ],
      },
    );

    final report = await scannerFor(repo).scan();

    expect(report.orphanFiles, hasLength(1));
    expect(p.basename(report.orphanFiles.single), 'orphan.png');
    expect(report.danglingRefs, hasLength(1));
    expect(report.danglingRefs.single.path, missing);
    expect(report.danglingRefs.single.ownerType, 'document');
    expect(report.danglingRefs.single.field, 'imagesJson');
    expect(report.liveRefCount, 1);
    expect(report.isClean, isFalse);
    expect(report.errors, isEmpty);
  });

  test(
      'sweep deletes orphan files and prunes dangling entries from every '
      'owner type', () async {
    final live = await store('live.png');
    final orphan = await store('orphan.png');
    final goneDoc = p.join(root.path, 'gone_doc.png');
    final goneavatar = p.join(root.path, 'gone_avatar.png');
    final goneAsset = p.join(root.path, 'gone_asset.png');
    final goneIns = p.join(root.path, 'gone_ins.png');

    final repo = _FakeRepo(
      profiles: [_profile('p1', 'خودم', avatarPath: goneavatar)],
      documents: {
        'p1': [
          _document('d1', 'p1', 'کارت ملی',
              imagesJson: jsonEncode([live.path, goneDoc])),
        ],
      },
      assets: [
        _asset('a1', 'خودرو', attachmentsJson: jsonEncode([goneAsset])),
      ],
      insurances: [
        _insurance('i1', 'بیمه عمر', attachmentsJson: jsonEncode([goneIns])),
      ],
    );

    final result = await scannerFor(repo).sweep();

    expect(result.removedFiles, 1);
    expect(await orphan.exists(), isFalse);
    expect(await live.exists(), isTrue, reason: 'live files must survive');

    expect(result.prunedRefs, 4);
    expect(repo.profileWrites, hasLength(1));
    expect(repo.profileWrites.single.avatarPath.value, isEmpty);
    expect(repo.documentWrites, hasLength(1));
    expect(
        jsonDecode(repo.documentWrites.single.imagesJson.value), [live.path]);
    expect(repo.assetWrites, hasLength(1));
    expect(jsonDecode(repo.assetWrites.single.attachmentsJson.value), isEmpty);
    expect(repo.insuranceWrites, hasLength(1));
    expect(
        jsonDecode(repo.insuranceWrites.single.attachmentsJson.value), isEmpty);

    expect(result.reportAfter.isClean, isTrue);
  });

  test('never reports or deletes files outside the attachments root', () async {
    final outside = File(p.join(docsDir.path, 'user_photo.png'))
      ..writeAsBytesSync(const [9]);

    final repo = _FakeRepo(
      profiles: [_profile('p1', 'خودم', avatarPath: outside.path)],
    );

    final result = await scannerFor(repo).sweep();

    expect(result.reportAfter.orphanFiles, isEmpty);
    expect(result.reportAfter.danglingRefs, isEmpty);
    expect(await outside.exists(), isTrue,
        reason: 'a foreign path is out of scope for the file sweep');
    expect(result.removedFiles, 0);
  });

  test('sweep is idempotent — a second pass finds nothing to do', () async {
    await store('orphan.png');
    final repo = _FakeRepo(profiles: [_profile('p1', 'خودم')]);

    final first = await scannerFor(repo).sweep();
    expect(first.removedFiles, 1);
    expect(first.reportAfter.isClean, isTrue);

    final second = await scannerFor(repo).sweep();
    expect(second.removedFiles, 0);
    expect(second.prunedRefs, 0);
    expect(second.reportAfter.isClean, isTrue);
  });

  test('malformed JSON is reported and never crashes the scan', () async {
    final repo = _FakeRepo(
      profiles: [_profile('p1', 'خودم')],
      documents: {
        'p1': [_document('d1', 'p1', 'خراب', imagesJson: '{not json')],
      },
    );

    final report = await scannerFor(repo).scan();

    expect(report.danglingRefs, isEmpty);
    expect(report.errors, hasLength(1));
    expect(report.errors.single, contains('خراب'));
  });

  test('a store that does not exist yet scans as clean', () async {
    await docsDir.delete(recursive: true);
    final repo = _FakeRepo();

    final report = await scannerFor(repo).scan();

    expect(report.isClean, isTrue);
    expect(report.errors, isEmpty);
  });
}

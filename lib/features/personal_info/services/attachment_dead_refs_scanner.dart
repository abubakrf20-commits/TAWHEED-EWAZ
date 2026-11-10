import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/personal_info/domain/repositories/personal_info_repository.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// A path kept in the database whose file is gone from disk.
///
/// This is the "دangling" half of the dead-reference problem: the row still
/// points at a photo that no longer exists, so every screen that renders it
/// shows a broken/blank tile.
class DanglingAttachmentRef {
  /// Which table owns the reference: `profile` | `document` | `asset` |
  /// `insurance`.
  final String ownerType;
  final String ownerId;
  final String ownerTitle;

  /// Which column holds it: `avatarPath` | `imagesJson` | `attachmentsJson`.
  final String field;
  final String path;

  const DanglingAttachmentRef({
    required this.ownerType,
    required this.ownerId,
    required this.ownerTitle,
    required this.field,
    required this.path,
  });

  @override
  String toString() => '$ownerType($ownerId).$field=$path';
}

/// Read-only result of one scan pass.
class DeadAttachmentReport {
  /// Files under `<documents>/app_data/attachments/` that no DB row points at.
  final List<String> orphanFiles;

  /// DB references whose file is missing on disk.
  final List<DanglingAttachmentRef> danglingRefs;

  /// Non-fatal problems hit while scanning (malformed JSON, unreadable dirs).
  final List<String> errors;

  /// How many references were found alive — handy to tell "empty store" from
  /// "everything is orphaned".
  final int liveRefCount;

  const DeadAttachmentReport({
    required this.orphanFiles,
    required this.danglingRefs,
    required this.errors,
    required this.liveRefCount,
  });

  bool get isClean => orphanFiles.isEmpty && danglingRefs.isEmpty;
  int get totalIssues => orphanFiles.length + danglingRefs.length;

  static const DeadAttachmentReport empty = DeadAttachmentReport(
    orphanFiles: [],
    danglingRefs: [],
    errors: [],
    liveRefCount: 0,
  );
}

/// What a [AttachmentDeadRefsScanner.sweep] actually changed.
class DeadAttachmentSweepResult {
  /// Orphan files successfully deleted.
  final int removedFiles;

  /// DB reference entries removed (avatar paths cleared, JSON entries pruned).
  final int prunedRefs;

  /// Fresh scan taken after the sweep — reports whatever survived.
  final DeadAttachmentReport reportAfter;

  const DeadAttachmentSweepResult({
    required this.removedFiles,
    required this.prunedRefs,
    required this.reportAfter,
  });
}

/// One-shot maintenance pass over «اطلاعات من» attachment storage.
///
/// Two independent kinds of dead reference pile up in practice:
///
///   1. **Orphan files** — a file under the attachments root that no row
///      references any more (a delete that failed halfway, an edit that
///      crashed after copying but before saving, a restore that brought the
///      DB back without the vault). They waste space and ride along in the
///      portable backup.
///   2. **Dangling refs** — a row still pointing at a file that vanished
///      (the system cleared documents, an interrupted copy, a user deleting
///      the folder). The UI shows a blank tile forever.
///
/// [scan] reports both without touching anything; [sweep] deletes the orphan
/// files and prunes the dangling entries out of their columns.
class AttachmentDeadRefsScanner {
  final PersonalInfoRepository _repo;
  final Future<Directory> Function() _documentsDir;

  AttachmentDeadRefsScanner({
    required PersonalInfoRepository repository,
    Future<Directory> Function()? documentsDirectory,
  })  : _repo = repository,
        _documentsDir = documentsDirectory ?? getApplicationDocumentsDirectory;

  // Kept in sync with AttachmentStorage's private layout constants. They are
  // mirrored (not imported) so this maintenance tool never has to widen the
  // storage API just to read its own directory.
  static const String _root = 'app_data';
  static const String _dirName = 'attachments';

  Future<Directory> _attachmentsRoot() async {
    final docs = await _documentsDir();
    return Directory(p.join(docs.path, _root, _dirName));
  }

  /// Collects the current state without changing anything.
  Future<DeadAttachmentReport> scan() async => (await _collect()).report;

  /// Deletes every orphan file and prunes every dangling DB entry, then
  /// re-scans so the caller can show what is left.
  Future<DeadAttachmentSweepResult> sweep() async {
    final data = await _collect();
    var removed = 0;
    for (final path in data.report.orphanFiles) {
      try {
        final f = File(path);
        if (await f.exists()) {
          await f.delete();
          removed++;
        }
      } catch (e) {
        data.report.errors.add('حذف فایل ناموفق: $path');
        AppLogger.warning('AttachmentDeadRefs', 'orphan delete failed: $e');
      }
    }

    var pruned = 0;
    for (final entry in data.deadByOwner.entries) {
      pruned += await _pruneOwner(data, entry.key, entry.value);
    }

    final after = await scan();
    return DeadAttachmentSweepResult(
      removedFiles: removed,
      prunedRefs: pruned,
      reportAfter: after,
    );
  }

  Future<_ScanData> _collect() async {
    final errors = <String>[];
    final livePaths = <String>{};
    final dangling = <DanglingAttachmentRef>[];
    final deadByOwner = <(String, String), List<DanglingAttachmentRef>>{};
    final profiles = <String, PersonalProfileTableData>{};
    final documents = <String, IdentityDocumentTableData>{};
    final assets = <String, AssetTableData>{};
    final insurances = <String, InsuranceTableData>{};

    Future<void> record(String ownerType, String ownerId, String ownerTitle,
        String field, String rawPath) async {
      final norm = p.normalize(rawPath);
      if (await File(norm).exists()) {
        livePaths.add(norm);
        return;
      }
      final ref = DanglingAttachmentRef(
        ownerType: ownerType,
        ownerId: ownerId,
        ownerTitle: ownerTitle,
        field: field,
        path: rawPath,
      );
      dangling.add(ref);
      deadByOwner.putIfAbsent((ownerType, ownerId), () => []).add(ref);
    }

    for (final profile in await _repo.getAllProfiles()) {
      profiles[profile.id] = profile;
      final avatar = profile.avatarPath.trim();
      if (avatar.isNotEmpty) {
        await record('profile', profile.id, profile.name, 'avatarPath', avatar);
      }
      for (final doc in await _repo.getDocumentsForProfile(profile.id)) {
        documents[doc.id] = doc;
        for (final path
            in _decodePaths(doc.imagesJson, errors, 'مدرک «${doc.title}»')) {
          await record('document', doc.id, doc.title, 'imagesJson', path);
        }
      }
    }

    for (final asset in await _repo.getAssets()) {
      assets[asset.id] = asset;
      for (final path in _decodePaths(
          asset.attachmentsJson, errors, 'دارایی «${asset.title}»')) {
        await record('asset', asset.id, asset.title, 'attachmentsJson', path);
      }
    }

    for (final ins in await _repo.getInsurances()) {
      insurances[ins.id] = ins;
      for (final path
          in _decodePaths(ins.attachmentsJson, errors, 'بیمه «${ins.title}»')) {
        await record('insurance', ins.id, ins.title, 'attachmentsJson', path);
      }
    }

    final onDisk = <String>{};
    try {
      final root = await _attachmentsRoot();
      if (await root.exists()) {
        await for (final e in root.list(recursive: true, followLinks: false)) {
          if (e is File) onDisk.add(p.normalize(e.path));
        }
      }
    } catch (e) {
      errors.add('پیمایش پوشهٔ پیوست‌ها ناموفق بود');
      AppLogger.warning('AttachmentDeadRefs', 'walk failed: $e');
    }

    final orphans = onDisk.difference(livePaths).toList()..sort();

    return _ScanData(
      report: DeadAttachmentReport(
        orphanFiles: orphans,
        danglingRefs: dangling,
        errors: errors,
        liveRefCount: livePaths.length,
      ),
      deadByOwner: deadByOwner,
      profiles: profiles,
      documents: documents,
      assets: assets,
      insurances: insurances,
    );
  }

  Future<int> _pruneOwner(_ScanData data, (String, String) owner,
      List<DanglingAttachmentRef> refs) async {
    final type = owner.$1;
    final id = owner.$2;
    try {
      switch (type) {
        case 'profile':
          final row = data.profiles[id];
          if (row == null) return 0;
          if (refs.any((r) => r.field == 'avatarPath')) {
            await _repo
                .upsertProfile(row.copyWith(avatarPath: '').toCompanion(true));
            return 1;
          }
          return 0;
        case 'document':
          final row = data.documents[id];
          if (row == null) return 0;
          final kept = _withoutDead(row.imagesJson, refs);
          if (kept == null) return 0;
          await _repo
              .upsertDocument(row.copyWith(imagesJson: kept).toCompanion(true));
          return refs.length;
        case 'asset':
          final row = data.assets[id];
          if (row == null) return 0;
          final kept = _withoutDead(row.attachmentsJson, refs);
          if (kept == null) return 0;
          await _repo.upsertAsset(
              row.copyWith(attachmentsJson: kept).toCompanion(true));
          return refs.length;
        case 'insurance':
          final row = data.insurances[id];
          if (row == null) return 0;
          final kept = _withoutDead(row.attachmentsJson, refs);
          if (kept == null) return 0;
          await _repo.upsertInsurance(
              row.copyWith(attachmentsJson: kept).toCompanion(true));
          return refs.length;
      }
    } catch (e) {
      data.report.errors.add('اصلاح ردیف $type($id) ناموفق بود');
      AppLogger.warning('AttachmentDeadRefs', 'prune $type/$id failed: $e');
    }
    return 0;
  }

  /// Returns the re-encoded JSON array with [refs]' paths removed, or `null`
  /// when the row did not actually contain any of them (so we skip the write).
  static String? _withoutDead(String raw, List<DanglingAttachmentRef> refs) {
    final dead = refs.map((r) => r.path).toSet();
    final decoded = _decode(raw);
    if (decoded == null) return null;
    if (!decoded.any(dead.contains)) return null;
    final kept = decoded.where((path) => !dead.contains(path)).toList();
    return jsonEncode(kept);
  }

  /// Lenient JSON-list decode. Records a human-readable error on failure and
  /// degrades to an empty list so one corrupt row cannot abort the scan.
  static List<String> _decodePaths(
      String raw, List<String> errors, String label) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const [];
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! List) {
        errors.add('ساختار نامعتبر در $label');
        return const [];
      }
      return decoded
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (e) {
      errors.add('JSON خراب در $label');
      AppLogger.warning('AttachmentDeadRefs', 'bad json on $label: $e');
      return const [];
    }
  }

  /// Same as [_decodePaths] but returns `null` for a malformed payload so the
  /// caller knows not to rewrite the row.
  static List<String>? _decode(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const [];
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! List) return null;
      return decoded
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (_) {
      // Malformed JSON: null tells the scanner to leave the row untouched —
      // rewriting a value it cannot read would be the real damage.
      return null;
    }
  }
}

class _ScanData {
  final DeadAttachmentReport report;
  final Map<(String, String), List<DanglingAttachmentRef>> deadByOwner;
  final Map<String, PersonalProfileTableData> profiles;
  final Map<String, IdentityDocumentTableData> documents;
  final Map<String, AssetTableData> assets;
  final Map<String, InsuranceTableData> insurances;

  _ScanData({
    required this.report,
    required this.deadByOwner,
    required this.profiles,
    required this.documents,
    required this.assets,
    required this.insurances,
  });
}

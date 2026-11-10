import 'dart:async';
import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:package_info_plus/package_info_plus.dart';

import 'package:tawheeed/features/settings/services/backup_service.dart';
import 'package:tawheeed/features/settings/services/google_auth_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Metadata of one cloud backup file in the app's hidden Drive folder.
class CloudBackupInfo {
  final String fileId;
  final String name;
  final DateTime modifiedTime;
  final int sizeBytes;
  final String? deviceLabel;

  const CloudBackupInfo({
    required this.fileId,
    required this.name,
    required this.modifiedTime,
    required this.sizeBytes,
    this.deviceLabel,
  });
}

/// Upload/download/list for Tawheeed backups in Google Drive `appDataFolder`.
///
/// Payload format is byte-identical to the local backups produced by
/// [BackupService] (same ZIP, same optional password encryption, same
/// manifest) — restore reuses `BackupService.restoreBackup` untouched.
///
/// File naming: `tawheeed_backup_<millis>_<device>.zip`, newest-first listing,
///Retention: keep the newest 10 (same policy as local auto-backups).
class DriveBackupService {
  DriveBackupService._();
  static final DriveBackupService instance = DriveBackupService._();

  static const int maxCloudBackups = 10;
  static const String filePrefix = 'tawheeed_backup_';

  Future<drive.DriveApi> _driveApi() async {
    final user = GoogleAuthService.instance.currentUser;
    if (user == null) {
      throw StateError('برای پشتیبان ابری ابتدا وارد حساب گوگل شوید.');
    }
    final scopes = [GoogleAuthService.driveScope];
    final authz = user.authorizationClient;
    var auth = await authz.authorizationForScopes(scopes);
    auth ??= await authz.authorizeScopes(scopes);
    return drive.DriveApi(auth.authClient(scopes: scopes));
  }

  static Future<String> _deviceLabel() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } catch (e) {
      AppLogger.warning('DriveBackup', 'platform detection failed: $e');
      return 'android';
    }
  }

  static String fileNameFor(DateTime when, String deviceLabel) =>
      '$filePrefix${when.millisecondsSinceEpoch}_$deviceLabel.zip';

  /// Uploads a local backup ZIP to the hidden app folder. Returns the Drive
  /// file id. Prunes to [maxCloudBackups] afterwards (best-effort).
  Future<String> uploadBackup(
    File localZip, {
    void Function(int sent, int total)? onProgress,
  }) async {
    final api = await _driveApi();
    final length = await localZip.length();
    final label = await _deviceLabel();
    final name = fileNameFor(DateTime.now(), label);
    AppLogger.info('DriveBackup',
        'uploading $name (${(length / 1048576).toStringAsFixed(1)}MB)');
    final meta = drive.File()
      ..name = name
      ..mimeType = 'application/zip'
      ..parents = ['appDataFolder']
      ..description = 'Tawheeed backup $label';
    final stream = localZip.openRead();
    final media = drive.Media(stream, length);
    final created = await api.files.create(meta, uploadMedia: media);
    final id = created.id;
    if (id == null || id.isEmpty) {
      throw StateError('آپلود در گوگل درایو ناموفق بود.');
    }
    AppLogger.success('DriveBackup', 'uploaded $name ($id)');
    onProgress?.call(length, length);
    unawaited(pruneOldBackups());
    return id;
  }

  /// Newest-first listing of our backup files. Never throws — returns empty
  /// on any failure (callers show "no cloud backups / offline").
  Future<List<CloudBackupInfo>> listBackups() async {
    try {
      final api = await _driveApi();
      final result = await api.files.list(
        spaces: 'appDataFolder',
        q: "name contains '$filePrefix' and trashed = false",
        orderBy: 'modifiedTime desc',
        pageSize: 50,
        $fields: 'files(id,name,modifiedTime,size,description)',
      );
      final out = <CloudBackupInfo>[];
      for (final f in result.files ?? []) {
        if (f.id == null || f.name == null) continue;
        DateTime modified;
        try {
          modified = DateTime.parse(f.modifiedTime.toString());
        } catch (_) {
          AppLogger.warning('drive_backup_service', 'operation failed');
          continue;
        }
        out.add(CloudBackupInfo(
          fileId: f.id!,
          name: f.name!,
          modifiedTime: modified.toLocal(),
          sizeBytes: int.tryParse(f.size ?? '') ?? 0,
          deviceLabel: f.description,
        ));
      }
      return out;
    } catch (e) {
      AppLogger.warning('DriveBackup', 'list failed: $e');
      return [];
    }
  }

  /// Downloads a cloud backup to a temp file and returns its path.
  Future<String> downloadBackup(
    CloudBackupInfo info,
    Directory tempDir, {
    void Function(int received, int? total)? onProgress,
  }) async {
    final api = await _driveApi();
    final path = '${tempDir.path}/cloud_${info.name}';
    final file = File(path);
    final media = await api.files.get(
      info.fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    );
    if (media is! drive.Media) {
      throw StateError('دانلود از گوگل درایو ناموفق بود.');
    }
    final sink = file.openWrite();
    var received = 0;
    try {
      await for (final chunk in media.stream) {
        received += chunk.length;
        sink.add(chunk);
        onProgress?.call(received, info.sizeBytes > 0 ? info.sizeBytes : null);
      }
    } finally {
      await sink.close();
    }
    AppLogger.success('DriveBackup', 'downloaded ${info.name}');
    return path;
  }

  /// Deletes one cloud backup by id. Never throws.
  Future<void> deleteBackup(String fileId) async {
    try {
      final api = await _driveApi();
      await api.files.delete(fileId);
    } catch (e) {
      AppLogger.warning('DriveBackup', 'delete failed: $e');
    }
  }

  /// Keeps only the newest [maxCloudBackups] files (best-effort).
  Future<void> pruneOldBackups() async {
    try {
      final all = await listBackups();
      if (all.length <= maxCloudBackups) return;
      for (final extra in all.sublist(maxCloudBackups)) {
        await deleteBackup(extra.fileId);
      }
    } catch (e) {
      AppLogger.warning('DriveBackup', 'prune failed: $e');
    }
  }
}

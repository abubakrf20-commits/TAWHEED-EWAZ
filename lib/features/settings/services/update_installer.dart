import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'package:tawheeed/features/settings/services/update_checker.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Downloads the self-hosted update APK into app storage and hands it to the
/// Android package installer through open_filex' own FileProvider. Only runs
/// for "direct" builds; store builds keep opening the Play listing instead.
@immutable
class UpdateInstallResult {
  /// True when the installer was launched (or the file is ready to retry).
  final bool launched;

  /// Absolute path of the downloaded APK, kept so a failed install can be
  /// retried without re-downloading.
  final String apkPath;

  /// Persian-ready short cause when [launched] is false.
  final String? error;

  const UpdateInstallResult.launched(this.apkPath)
      : launched = true,
        error = null;

  const UpdateInstallResult.failed(this.error, this.apkPath) : launched = false;
}

/// Raised inside the download loop once [cancelActiveDownload] was called;
/// [downloadAndInstall] turns it into the `kUpdateCancelledMessage` result
/// instead of the generic network error.
class UpdateDownloadCancelled implements Exception {
  const UpdateDownloadCancelled();
}

/// Persian-ready message returned when the user cancels the download.
const String kUpdateCancelledMessage = 'دانلود لغو شد.';

http.Client? _activeClient;

/// Cancels the in-flight APK download started by [downloadAndInstall], if
/// any. Safe to call when nothing is running.
void cancelActiveDownload() {
  _activeClient?.close();
  _activeClient = null;
}

/// Downloads [update]'s APK to the app documents dir and opens the package
/// installer. [onProgress] receives total bytes (0 when the server sends no
/// Content-Length). Returns a cleared result on success — the system installer
/// takes over from there.
///
/// The APK is verified against the `apkSha256` pin from the manifest before
/// the installer is launched. Without that check a substituted download (a
/// tampered manifest, a hijacked CDN object) would be executed as an update.
Future<UpdateInstallResult> downloadAndInstall(
  UpdateInfo update, {
  required void Function(int received, int total) onProgress,
}) async {
  if (!update.hasPinnedApk) {
    return const UpdateInstallResult.failed(
        'این نسخه بدون امضای قابل بررسی منتشر شده و نصب نمی‌شود.', '');
  }
  final uri = Uri.tryParse(update.apkUrl);
  if (uri == null ||
      uri.scheme != 'https' ||
      !UpdateChecker.isAllowedApkUrl(update.apkUrl)) {
    AppLogger.warning('UpdateInstaller', 'refused apk url: ${update.apkUrl}');
    return const UpdateInstallResult.failed('نشانی فایل نامعتبر است.', '');
  }
  final client = http.Client();
  _activeClient = client;
  try {
    final dir = await getApplicationDocumentsDirectory();
    // A plain file name built from the version, never from manifest text.
    final version =
        update.versionName.replaceAll(RegExp(r'[^0-9A-Za-z._-]'), '_');
    final file = File('${dir.path}/update/tawheeed-$version.apk');
    await file.parent.create(recursive: true);

    final total = await _download(uri, file, onProgress, client);
    final digest = (await sha256.bind(file.openRead()).first).toString();
    if (digest != update.apkSha256) {
      AppLogger.error('UpdateInstaller',
          'apk hash mismatch for ${update.versionName}: got $digest');
      try {
        await file.delete();
      } catch (e) {
        AppLogger.warning(
            'UpdateInstaller', 'hash-mismatched apk delete failed: $e');
      }
      return const UpdateInstallResult.failed(
          'فایل دانلودشده با نسخه اعلام‌شده مطابقت ندارد.', '');
    }
    AppLogger.info('UpdateInstaller',
        'downloaded and verified $total bytes to ${file.path}');

    // Superseded installers only waste device storage — keep the folder at
    // most one APK (the verified current one). Old files stay until a new
    // download verifies, so a failed install can still be retried.
    try {
      await for (final stale in file.parent.list()) {
        if (stale is File && stale.path != file.path) {
          try {
            await stale.delete();
          } catch (e) {
            AppLogger.warning('UpdateInstaller', 'stale apk delete failed: $e');
          }
        }
      }
    } catch (e) {
      AppLogger.warning('UpdateInstaller', 'update dir sweep failed: $e');
    }

    final open = await OpenFilex.open(
      file.path,
      type: 'application/vnd.android.package-archive',
    );
    if (open.type == ResultType.done) {
      return UpdateInstallResult.launched(file.path);
    }
    AppLogger.warning('UpdateInstaller', 'open failed: ${open.message}');
    return UpdateInstallResult.failed('باز کردن APK ناموفق بود.', file.path);
  } on UpdateDownloadCancelled {
    return const UpdateInstallResult.failed(kUpdateCancelledMessage, '');
  } catch (e) {
    AppLogger.warning('UpdateInstaller', 'download failed: $e');
    return const UpdateInstallResult.failed(
        'دانلود ناموفق بود؛ اتصال اینترنت را بررسی کنید.', '');
  } finally {
    client.close();
    if (identical(_activeClient, client)) _activeClient = null;
  }
}

/// Refuse a download larger than this. An APK is ~30-60 MB; anything past the
/// cap is either a mistake or an attempt to fill the device.
const int _maxApkBytes = 256 << 20; // 256 MiB

Future<int> _download(
  Uri uri,
  File file,
  void Function(int received, int total) onProgress,
  http.Client client,
) async {
  final response = await client
      .send(http.Request('GET', uri))
      .timeout(const Duration(seconds: 60));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw HttpException(
        'HTTP ${response.statusCode} downloading ${uri.toString()}');
  }

  final sink = file.openWrite();
  var received = 0;
  try {
    final total = response.contentLength ?? 0;
    if (total > _maxApkBytes) {
      throw HttpException('declared APK size $total exceeds the limit');
    }
    await for (final chunk in response.stream) {
      if (_activeClient == null) throw const UpdateDownloadCancelled();
      received += chunk.length;
      if (received > _maxApkBytes) {
        throw const HttpException('APK exceeds the maximum size');
      }
      sink.add(chunk);
      if (total > 0) onProgress(received, total);
    }
  } finally {
    await sink.close();
  }
  return received;
}

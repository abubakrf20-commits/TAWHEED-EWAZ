import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:tawheeed/features/quran/api/quran_api_config.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Download progress callback. [received] / [total] are bytes; [total] may be
/// -1 when the server does not send a Content-Length header.
typedef DownloadProgress = void Function(int received, int total);

/// Downloads app content (hadith database, library books) from the app
/// owner's GitHub-hosted catalog — the same public repository that already
/// hosts the Quran content and mushaf pages.
///
/// Every file is downloaded exactly once into its feature's own directory and
/// kept forever. When [compressed] is true the hosted file is `<name>.gz` and
/// is decompressed during the download (the gzip copy is not kept); otherwise
/// the bytes are written as-is.
class ContentDownloadService {
  ContentDownloadService._();

  /// Base URL of the hosted catalog (see [QuranApiConfig.contentBaseUrl]).
  static String get baseUrl => QuranApiConfig.contentBaseUrl;

  /// True when a valid (non-empty) file exists at [localPath].
  static Future<bool> isDownloaded(String localPath) async {
    final f = File(localPath);
    return await f.exists() && await f.length() > 1000;
  }

  /// Downloads [remoteName] from [baseUrl] into [localPath] unless a valid
  /// copy already exists. When [compressed] is true the remote file is
  /// `$remoteName.gz` and is decompressed into [localPath]. Returns
  /// [localPath] on success or `null` on failure.
  static Future<String?> ensureDownloaded(
    String remoteName,
    String localPath, {
    bool compressed = false,
    DownloadProgress? onProgress,
  }) async {
    final f = File(localPath);
    if (await isDownloaded(localPath)) return localPath;

    final remote = compressed ? '$remoteName.gz' : remoteName;
    final url = '$baseUrl/$remote';
    final tmp = File('$localPath.part');
    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(url));
      final res = await client.send(req).timeout(const Duration(minutes: 15));
      if (res.statusCode != 200) {
        AppLogger.warning(
            'ContentDownloadService', 'GET $url -> ${res.statusCode}');
        return null;
      }
      final total = res.contentLength ?? -1;
      var received = 0;
      await tmp.parent.create(recursive: true);
      final sink = tmp.openWrite();
      try {
        await for (final chunk in res.stream) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(received, total);
        }
      } finally {
        await sink.close();
      }
      if (compressed) {
        final raw = await tmp.readAsBytes();
        await f.writeAsBytes(gzip.decode(raw), flush: true);
        // The decompressed copy is complete — a failed `.part` cleanup must
        // not turn a finished download into a reported failure. It used to:
        // the deletion threw into the catch below and returned null, and the
        // caller showed «دانلود ناموفق بود» while the file sat on disk.
        try {
          await tmp.delete();
        } catch (e) {
          AppLogger.warning(
              'ContentDownloadService', 'partial cleanup failed: $e');
        }
      } else {
        await tmp.rename(localPath);
      }
      return localPath;
    } catch (e) {
      AppLogger.warning('content_download_service', 'error: $e');
      if (await tmp.exists()) {
        try {
          await tmp.delete();
        } catch (e) {
          AppLogger.warning(
              'ContentDownloadService', 'partial cleanup failed: $e');
        }
      }
      AppLogger.warning(
          'ContentDownloadService', 'Download failed $remote: $e');
      return null;
    } finally {
      client.close();
    }
  }

  /// Removes [localPath] and any `$localPath.gz` stray copy.
  static Future<void> deleteDownloaded(String localPath) async {
    try {
      for (final path in [localPath, '$localPath.gz']) {
        final f = File(path);
        if (await f.exists()) await f.delete();
      }
    } catch (e) {
      AppLogger.warning(
          'ContentDownloadService', 'Delete failed $localPath: $e');
    }
  }
}

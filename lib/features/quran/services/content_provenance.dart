import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// The provenance sidecar for downloaded Quran content (upgrade wave-3 #3):
/// a `<file>.prov.json` written next to every successfully downloaded
/// content file, recording WHAT was fetched, from WHERE, and the sha256 of
/// the exact bytes committed — so a later read can prove the file on disk is
/// still the file that was downloaded (bit-rot, interrupted syncs and
/// hostile edits all fail the digest).
///
/// Format (schema 1):
/// ```json
/// {
///   "schema": 1,
///   "id": "persian_translation",
///   "fileName": "persian_translation.json",
///   "remoteUrl": "https://…/tafsir/persian_translation.json.gz",
///   "sha256": "<hex over the decompressed, committed bytes>",
///   "sizeBytes": 1778329,
///   "downloadedAt": "2026-11-06T…"
/// }
/// ```
/// This mirrors the quran.ws provenance discipline (source + digest beside
/// the data); the digest is over the DECOMPRESSED content, because that is
/// what the readers consume and what the hosted `.gz` cannot itself answer
/// for.
class ContentProvenance {
  static const int schemaVersion = 1;

  ContentProvenance._();

  static String sidecarPath(String contentPath) => '$contentPath.prov.json';

  /// Writes the sidecar for a freshly committed content file. Best-effort:
  /// a failed sidecar write is logged and swallowed — the content stays
  /// usable, it just reads as «unverified» until the next download.
  static Future<void> write(
    String contentPath,
    List<int> committedBytes, {
    required String id,
    required String remoteUrl,
  }) async {
    try {
      final record = {
        'schema': schemaVersion,
        'id': id,
        'fileName': contentPath
            .split(Platform.pathSeparator)
            .lastOrNull,
        'remoteUrl': remoteUrl,
        'sha256': sha256.convert(committedBytes).toString(),
        'sizeBytes': committedBytes.length,
        'downloadedAt': DateTime.now().toUtc().toIso8601String(),
      };
      await File(sidecarPath(contentPath)).writeAsString(
        const JsonEncoder.withIndent('  ').convert(record),
        flush: true,
      );
    } catch (e) {
      AppLogger.warning('content_provenance', 'sidecar write failed: $e');
    }
  }

  /// The recorded digest of a committed file, or null when there is no
  /// sidecar (content downloaded before this existed).
  static Future<String?> recordedSha256(String contentPath) async {
    try {
      final raw = await File(sidecarPath(contentPath)).readAsString();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['schema'] != schemaVersion) return null;
      return json['sha256'] as String?;
    } catch (_) {
      // An unreadable or malformed sidecar IS the documented "absent" state:
      // the caller keeps the legacy size/header checks instead of failing a
      // file that may be perfectly good.
      return null;
    }
  }

  /// Verifies the file on disk against its sidecar digest.
  ///
  /// * [ContentVerification.verified] — sidecar present, digest matches.
  /// * [ContentVerification.absent] — no sidecar file at all (legacy
  ///   download; treat as usable, the size/header sanity checks still apply).
  /// * [ContentVerification.mismatch] — sidecar present but the bytes differ,
  ///   OR the sidecar itself is unreadable/malformed/schema-unknown. A broken
  ///   sidecar cannot prove integrity, so the file must be re-downloaded —
  ///   it is never silently served as «unverified but usable» (audit B02/B14:
  ///   the old code folded a corrupt sidecar into the absent state, which let
  ///   a hostile edit that also corrupted the sidecar pass as legacy).
  static Future<ContentVerification> verify(String contentPath) async {
    final sidecar = File(sidecarPath(contentPath));
    String? recorded;
    try {
      final raw = await sidecar.readAsString();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      recorded = json['schema'] == schemaVersion
          ? json['sha256'] as String?
          : null;
    } on FileSystemException {
      // No sidecar on disk is the documented legacy "absent" state: keep
      // trusting the size/header sanity checks for that file.
      return ContentVerification.absent;
    } catch (e) {
      // Sidecar exists but is malformed or unreadable: fail closed.
      AppLogger.warning('content_provenance', 'broken sidecar: $e');
      return ContentVerification.mismatch;
    }
    if (recorded == null || recorded.isEmpty) {
      // Schema-unknown or digest-less sidecar cannot prove integrity.
      AppLogger.warning(
        'content_provenance',
        'sidecar has no usable digest (schema mismatch or empty sha256)',
      );
      return ContentVerification.mismatch;
    }
    try {
      final bytes = await File(contentPath).readAsBytes();
      return sha256.convert(bytes).toString() == recorded
          ? ContentVerification.verified
          : ContentVerification.mismatch;
    } catch (_) {
      // An unreadable file cannot be trusted: report a mismatch so the
      // downloader replaces it rather than serving bytes we could not hash.
      return ContentVerification.mismatch;
    }
  }
}

enum ContentVerification { verified, absent, mismatch }

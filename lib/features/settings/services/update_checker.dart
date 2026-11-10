import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'package:tawheeed/features/quran/api/quran_api_config.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// In-app update checker.
///
/// Probes `app/update.json` on the same content catalog that already serves
/// the hadith/fatwa/mushaf downloads (no new infrastructure).
///
/// Frozen versionCode + revision counter:
///  - Every build (Play and self-hosted) ships ONE frozen Android versionCode
///    from `android/app/build.gradle.kts` (`FROZEN_VERSION_CODE`). It stays put
///    through a development cycle, so a new APK always installs in place over
///    the previous one — never forcing a user to uninstall. It is bumped by
///    1..10 only right before a publish.
///  - Because that number is stable, the checker compares a separate `revision`
///    counter, baked into the build by the release pipeline
///    (`--dart-define=APP_REVISION=…`) and advertised in the manifest. At
///    publish time both are set to the same frozen number.
///
/// Manifest shape:
/// ```json
/// {
///   "revision": 6010,
///   "versionCode": 4009,
///   "versionName": "1.6.2",
///   "notes": "…",
///   "apkUrl": "https://?/tawheeed-1.6.2.apk",
///   "apkSha256": "e3b0c442…",
///   "apkVariants": [
///     {"abi": "arm64-v8a", "versionCode": 2000002010,
///      "url": "https://?/tawheeed-1.6.2-arm64-v8a.apk", "sha256": "…"}
///   ],
///   "playUrl": "https://play.google.com/store/apps/details?id=com.islamic.tawheeed",
///   "mandatory": false
/// }
/// ```
class UpdateChecker {
  UpdateChecker._();
  static final UpdateChecker instance = UpdateChecker._();

  static const String _manifestPath = 'app/update.json';

  /// Hosts allowed to serve an APK. The manifest is remote input, so a
  /// `apkUrl` pointing anywhere else is refused instead of downloaded: a
  /// tampered manifest must not be able to choose the source of an executable.
  static const List<String> allowedApkHosts = <String>[
    'raw.githubusercontent.com',
    'github.com',
    'objects.githubusercontent.com',
    'dl.google.com',
  ];

  /// Constant Android versionCode floor for self-hosted builds.
  ///
  /// Direct builds are detected by “at least this” rather than equality:
  /// `--split-per-abi` lays an ABI offset on top (`abi * 1000`, so arm64 is
  /// +2000 and armeabi-v7a +1000), and every one of those must still be
  /// treated as a direct build so the dialog routes to the APK URL, not Play.
  ///
  /// NOTE (frozen numbering, 2026-10-17): Play and self-hosted builds now share
  /// the SAME frozen versionCode, so this heuristic alone would call a Play
  /// build “direct”. The explicit [APP_CHANNEL] define is what separates them;
  /// this floor remains as the fallback for builds that predate the define.
  static const int _directCode = 2000000000;

  /// Build channel baked by `--dart-define=APP_CHANNEL=direct|play`. Empty when
  /// unset, in which case the checker falls back to the versionCode heuristic.
  /// The Google Play AAB build MUST pass `play` so its users are routed to the
  /// Play listing and never to a raw APK URL.
  static const String _channel = String.fromEnvironment('APP_CHANNEL');

  /// Revision baked into the build by `--dart-define=APP_REVISION=…`. Zero when
  /// the build predates the field; the checker then falls back to the OS
  /// versionCode so old releases keep checking correctly.
  static final int _localRevision =
      int.tryParse(const String.fromEnvironment('APP_REVISION')) ?? 0;

  /// Result of a single check.
  UpdateInfo? _lastResult;
  UpdateInfo? get lastResult => _lastResult;

  /// True when the last [check] could not reach or parse the manifest, so
  /// callers can distinguish "you're up to date" from "couldn't check".
  bool lastCheckFailed = false;

  /// Fetches the remote manifest and compares `revision` (falling back to
  /// `versionCode` for older manifests) with the running build. Returns null
  /// when up-to-date, unreachable, or malformed — never throws, so callers can
  /// fire-and-forget at boot. [lastCheckFailed] tells the two apart.
  Future<UpdateInfo?> check() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final runningCode = int.tryParse(info.buildNumber) ?? 0;

      final url = '${QuranApiConfig.contentBaseUrl}/$_manifestPath';
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        lastCheckFailed = true;
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final update = evaluate(
        runningCode: runningCode,
        localRevision: _localRevision,
        manifest: json,
      );
      lastCheckFailed = false;
      if (update == null || !update.hasPinnedApk) {
        // No actionable update any more, so the "update available" state
        // must not outlive the manifest that advertised it: up-to-date
        // clears the remembered result, and an un-pinned offer is never
        // remembered at all. A *failed* check returns earlier and keeps
        // the last known result — a dropped connection must not wipe the
        // banner the user has not acted on yet.
        if (update != null) {
          AppLogger.warning('UpdateChecker',
              'update ${update.versionName} ignored: no apkSha256 pin');
        }
        _lastResult = null;
        return null;
      }
      _lastResult = update;
      return update;
    } catch (e) {
      AppLogger.warning('UpdateChecker', 'check failed: $e');
      lastCheckFailed = true;
      return null;
    }
  }

  @visibleForTesting
  static bool isDirectBuild(int runningCode) {
    if (_channel == 'play') return false;
    if (_channel == 'direct') return true;
    return runningCode >= _directCode;
  }

  /// Whether [url] is an acceptable source for an APK: HTTPS, on a known
  /// content host, and not a `file:`/`intent:` style URL.
  static bool isAllowedApkUrl(String url) {
    if (url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (uri.scheme != 'https') return false;
    if (uri.host.isEmpty) return false;
    return allowedApkHosts.contains(uri.host.toLowerCase());
  }

  /// Whether [url] is an acceptable Play Store link.
  static bool isAllowedPlayUrl(String url) {
    if (url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (uri.scheme != 'https') return false;
    final host = uri.host.toLowerCase();
    return host == 'play.google.com' || host.endsWith('.play.google.com');
  }

  /// Normalises a manifest-supplied SHA-256 to lowercase hex, or null when it
  /// is not a 64-character hex digest.
  static String? normaliseSha256(String? value) {
    if (value == null) return null;
    final trimmed = value.trim().toLowerCase();
    if (trimmed.length != 64) return null;
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(trimmed)) return null;
    return trimmed;
  }

  /// Pure decision — testable without a device or network. Returns null when no
  /// update applies to the running build.
  @visibleForTesting
  static UpdateInfo? evaluate({
    required int runningCode,
    required int localRevision,
    required Map<String, dynamic> manifest,
  }) {
    final isDirect = isDirectBuild(runningCode);

    // Rank against the baked revision when present. Without one, a direct
    // build falls back to its constant (≥ _directCode) versionCode, which no
    // manifest can outrank — so every check stays quiet instead of nagging —
    // while older *store* builds fall back to their real versionCode and
    // keep checking correctly.
    final runningRevision = localRevision > 0 ? localRevision : runningCode;

    final remoteRevision = (manifest['revision'] as num?)?.toInt() ??
        (manifest['versionCode'] as num?)?.toInt() ??
        0;
    if (remoteRevision <= runningRevision) return null;

    final universalUrl = manifest['apkUrl'] as String? ?? '';
    final playUrl = manifest['playUrl'] as String? ?? '';
    // A split install downloads the artifact it already is: the manifest's
    // `apkVariants` maps each split's exact Android versionCode to its own
    // APK. Fat builds and older clients fall back to the universal `apkUrl`.
    final variant = _variantFor(manifest['apkVariants'], runningCode);
    final universalTrusted = isAllowedApkUrl(universalUrl);
    final apkUrl = variant?.url ?? (universalTrusted ? universalUrl : '');
    final apkSha256 = variant?.sha256 ??
        (universalTrusted
            ? normaliseSha256(manifest['apkSha256'] as String?)
            : null);
    // Refuse to act on a manifest whose URLs are not the ones we expect: a
    // tampered manifest must not be able to choose the source of an
    // executable, or a "play" link that opens something else entirely.
    if (apkUrl.isEmpty && !isAllowedPlayUrl(playUrl)) return null;

    return UpdateInfo(
      revision: remoteRevision,
      versionCode: (manifest['versionCode'] as num?)?.toInt() ?? remoteRevision,
      versionName: manifest['versionName'] as String? ?? '',
      notes: manifest['notes'] as String? ?? '',
      apkUrl: apkUrl,
      playUrl: isAllowedPlayUrl(playUrl) ? playUrl : '',
      apkSha256: apkSha256,
      mandatory: manifest['mandatory'] as bool? ?? false,
      isDirect: isDirect,
    );
  }

  /// The variant whose declared versionCode equals the running build's, or
  /// null when none matches. An entry with an untrusted URL or an invalid
  /// SHA-256 pin is skipped — never selected unpinned — so the universal
  /// fallback (with its own pin) wins instead.
  static ({String url, String sha256})? _variantFor(
      Object? raw, int runningCode) {
    if (raw is! List) return null;
    for (final item in raw) {
      if (item is! Map) continue;
      if ((item['versionCode'] as num?)?.toInt() != runningCode) continue;
      final url = item['url'] as String? ?? '';
      final sha = normaliseSha256(item['sha256'] as String?);
      if (!isAllowedApkUrl(url) || sha == null) continue;
      return (url: url, sha256: sha);
    }
    return null;
  }
}

/// An available update, resolved against the running build.
@immutable
class UpdateInfo {
  final int revision;
  final int versionCode;
  final String versionName;
  final String notes;
  final String apkUrl;
  final String playUrl;

  /// Lowercase hex SHA-256 of the APK the manifest advertises. An update
  /// without it is not offered: pinning the hash in the manifest is what stops
  /// a substituted download from reaching the package installer.
  final String? apkSha256;

  /// Whether this update can be verified before installing.
  bool get hasPinnedApk => apkSha256 != null && apkSha256!.isNotEmpty;

  /// When true the UI should block usage until updated (reserved; the current
  /// UI only shows a stronger prompt).
  final bool mandatory;

  /// True when this build is a self-hosted ("direct") APK. Direct builds
  /// open the APK URL (constant versionCode installs in place); Play builds
  /// open the Play Store listing.
  final bool isDirect;

  const UpdateInfo({
    required this.revision,
    required this.versionCode,
    required this.versionName,
    required this.notes,
    required this.apkUrl,
    required this.playUrl,
    required this.mandatory,
    required this.isDirect,
    this.apkSha256,
  });

  /// Best URL to open for this running build.
  String get bestUrl {
    if (isDirect) {
      return apkUrl.isNotEmpty ? apkUrl : playUrl;
    }
    return playUrl.isNotEmpty ? playUrl : apkUrl;
  }
}

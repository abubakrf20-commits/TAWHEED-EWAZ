import 'package:flutter/foundation.dart' show kReleaseMode, visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;

/// Credentials + endpoints for the Quran Foundation Content API.
///
/// The release build ships WITHOUT any credentials: the translation, tafsir
/// and audio all come from the public hosts configured below (plus bundled
/// data as an offline fallback), and the API calls fall back to the bundled
/// page table when no credentials are present.
///
/// Credentials are NEVER hardcoded. When provided for development, they are
/// read from:
///   1. `assets/env/quran_api.env`  (a `.env`-style file, see `_parseDotEnv`)
///   2. `--dart-define=QF_CLIENT_ID=...` / `QF_CLIENT_SECRET=...` (override)
class QuranApiConfig {
  QuranApiConfig._();

  static const String envAssetPath = 'assets/env/quran_api.env';

  /// API hostnames differ between environments — the official docs warn to
  /// never mix pre-live and production credentials, hosts or tokens.
  static const String envKey = 'QF_ENV';
  static const String envPrelive = 'prelive';
  static const String envProduction = 'production';

  static const String _apiBaseProduction =
      'https://apis.quran.foundation/content/api/v4';
  static const String _apiBasePrelive =
      'https://apis-prelive.quran.foundation/content/api/v4';
  static const String _tokenEndpointProduction =
      'https://oauth2.quran.foundation/oauth2/token';
  static const String _tokenEndpointPrelive =
      'https://prelive-oauth2.quran.foundation/oauth2/token';

  static const String clientIdEnvKey = 'QF_CLIENT_ID';
  static const String clientSecretEnvKey = 'QF_CLIENT_SECRET';

  /// Base URL of the hosted content catalog (`quran-content.json` + the
  /// tafsir `.db.gz` / translation files). Set via `QF_CONTENT_BASE` in
  /// `assets/env/quran_api.env`. Empty = fall back to [defaultContentBaseUrl].
  static const String contentBaseEnvKey = 'QF_CONTENT_BASE';

  /// Public (non-secret) default host of the content catalog (translation +
  /// tafsirs), used when no `.env`/dart-define value is present. It is a
  /// public GitHub repo, so it is safe to bundle as a fallback.
  static const String defaultContentBaseUrl =
      'https://raw.githubusercontent.com/abubakrf20-commits/TAWHEED-EWAZ/main';

  // ── Organized sub-paths (after repo restructuring) ──
  static const String _hadithDir = 'hadith';
  static const String _libraryDir = 'library';
  static const String _tafsirDir = 'tafsir';

  static String _env = envProduction;
  static String _contentBase = '';

  /// Base URL of the hosted content catalog (folder holding
  /// `quran-content.json` and the DB/JSON files). Falls back to the public
  /// host until `QF_CONTENT_BASE` is configured.
  static String get contentBaseUrl =>
      _contentBase.trim().isEmpty ? defaultContentBaseUrl : _contentBase.trim();

  // ── Organized path helpers ──
  static String get hadithBaseUrl => '$contentBaseUrl/$_hadithDir';
  static String get libraryBaseUrl => '$contentBaseUrl/$_libraryDir';
  static String get tafsirBaseUrl => '$contentBaseUrl/$_tafsirDir';

  /// Resolved API base URL for the active environment.
  static String get apiBase =>
      _env == envPrelive ? _apiBasePrelive : _apiBaseProduction;

  /// Resolved OAuth2 token endpoint for the active environment.
  static String get tokenEndpoint =>
      _env == envPrelive ? _tokenEndpointPrelive : _tokenEndpointProduction;

  /// Access-token lifetime announced by the token endpoint (seconds).
  static const int tokenLifetimeSeconds = 3600;

  /// Refresh the token this many seconds before it actually expires.
  static const int tokenRefreshMarginSeconds = 60;

  /// Page count of Mushaf 1 (QCF V2 — Medina Mushaf, 604 pages).
  static const int mushafPageCount = 604;

  /// Estimated download size of one whole-Quran talaawah set (mp3quran,
  /// ~114 surah files at ~8MB average). Shown for the «کل قرآن» button.
  static const double talaawahWholeQuranSizeMB = 900;

  /// Default mushaf: QCF V2 (closest to the 1439 Medina print).
  static const int defaultMushafId = 1;

  static String _clientId = '';
  static String _clientSecret = '';
  static bool _loaded = false;

  /// Whether the app can reach the Quran Foundation API directly (development
  /// builds with credentials present). The release build intentionally returns
  /// false — everything works from the bundled data and public hosts.
  static bool get isConfigured =>
      !kReleaseMode && _clientId.isNotEmpty && _clientSecret.isNotEmpty;

  static String get clientId => _clientId;
  static String get clientSecret => _clientSecret;

  /// Test-only: set the content base directly (normally driven by the .env
  /// file / dart-defines). Restores defaults when [base] is empty.
  @visibleForTesting
  static void debugSetContentBase({String base = ''}) {
    _contentBase = base;
  }

  /// Loads credentials from dart-defines, then from the bundled .env file.
  /// Safe to call multiple times; cached after the first successful load
  /// unless [force] is true (used by the setup screen's «بررسی دوباره»).
  static Future<void> load({bool force = false}) async {
    if (_loaded && !force) return;
    _loaded = true;

    // 1) dart-define overrides (highest priority, useful for CI).
    const envId = String.fromEnvironment(clientIdEnvKey);
    const envSecret = String.fromEnvironment(clientSecretEnvKey);
    const contentBase = String.fromEnvironment(contentBaseEnvKey);
    _clientId = envId.isNotEmpty ? envId : _clientId;
    _clientSecret = envSecret.isNotEmpty ? envSecret : _clientSecret;
    _contentBase = contentBase.isNotEmpty ? contentBase : _contentBase;

    // 2) Optional local .env file.
    try {
      final content = await rootBundle.loadString(envAssetPath);
      final map = _parseDotEnv(content);
      if (_clientId.isEmpty) {
        _clientId = map[clientIdEnvKey]?.trim() ?? '';
      }
      if (_clientSecret.isEmpty) {
        _clientSecret = map[clientSecretEnvKey]?.trim() ?? '';
      }
      if (_contentBase.isEmpty) {
        _contentBase = map[contentBaseEnvKey]?.trim() ?? '';
      }
      final env = map[envKey]?.trim().toLowerCase() ?? '';
      if (env == envPrelive || env == envProduction) {
        _env = env;
      }
    } catch (_) {
      // The asset may be absent while running tests or when the user has not
      // yet added their keys. Keep _loaded=false so a later force-load (e.g.
      // the setup screen's «بررسی دوباره») can try again.
      if (!force) _loaded = false;
    }

    // 3) Public fallback so the reader works even without a local .env file
    //    or build-time dart-defines (content catalog).
    if (_contentBase.isEmpty) {
      _contentBase = defaultContentBaseUrl;
    }
  }

  /// Minimal `.env` parser: `KEY=VALUE` per line, `#` comments, `=` allowed in
  /// values, no variable expansion.
  static Map<String, String> _parseDotEnv(String content) {
    final map = <String, String>{};
    for (final rawLine in content.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final eq = line.indexOf('=');
      if (eq <= 0) continue;
      final key = line.substring(0, eq).trim();
      var value = line.substring(eq + 1).trim();
      // Strip surrounding quotes.
      if (value.length >= 2 &&
          ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'")))) {
        value = value.substring(1, value.length - 1);
      }
      map[key] = value;
    }
    return map;
  }
}

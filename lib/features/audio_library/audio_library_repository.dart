import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/features/audio_library/audio_library_config.dart';
import 'package:tawheeed/features/audio_library/audio_library_manifest.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Why the audio-library manifest could not be fetched.
enum AudioLibraryFailure {
  /// The host could not be reached (no connection, DNS, timeout).
  offline,

  /// The host answered, but not with the manifest (402/403/500…). The user's
  /// own connection is fine in this case — blaming it sends them to settings.
  server,

  /// The host answered 200 with something that is not a readable manifest.
  data,
}

/// A manifest-load failure that carries [message] ready to show to the user.
class AudioLibraryException implements Exception {
  final AudioLibraryFailure failure;

  /// HTTP status when [failure] is [AudioLibraryFailure.server].
  final int? statusCode;

  /// Persian, user-facing.
  final String message;

  const AudioLibraryException({
    required this.failure,
    required this.message,
    this.statusCode,
  });

  factory AudioLibraryException.offline() => AudioLibraryException(
        failure: AudioLibraryFailure.offline,
        message: 'ارتباط با سرور کتابخانه صوتی (${AudioLibraryConfig.host}) '
            'برقرار نشد. اگر اینترنت شما وصل است، مشکل از سمت میزبان است؛ '
            'فایل‌های دانلودشده روی دستگاه می‌مانند.',
      );

  factory AudioLibraryException.server(int code) => AudioLibraryException(
        failure: AudioLibraryFailure.server,
        statusCode: code,
        message: 'سرور کتابخانه صوتی پاسخ نداد (کد $code). '
            'اتصال شما سالم است؛ مشکل از سمت سرویس میزبانی است.',
      );

  factory AudioLibraryException.data() => const AudioLibraryException(
        failure: AudioLibraryFailure.data,
        message: 'فهرست کتابخانه صوتی خراب بود؛ دوباره تلاش کنید.',
      );

  @override
  String toString() =>
      'AudioLibraryException(${failure.name}${statusCode == null ? '' : ', $statusCode'}): $message';
}

/// Loads and caches the audio-library manifest.
///
/// Cache first (stale-while-revalidate): a cached copy (in-memory, else
/// SharedPreferences) is served immediately and the network fetch runs in the
/// background, so the library opens instantly even on slow connections. The
/// network is only awaited on the very first run (no cache yet) or when the
/// caller explicitly asks for fresh data.
class AudioLibraryRepository {
  AudioLibraryRepository._();

  static final AudioLibraryRepository instance = AudioLibraryRepository._();

  static const String _cacheKey = 'audio_library_manifest_json';

  /// Test-only injection point (see `package:http/testing.dart`).
  http.Client? _client;

  AudioLibraryManifest? _lastGood;

  /// Result of an in-flight first-load so concurrent callers share it.
  Future<AudioLibraryManifest>? _firstLoad;

  /// Whether a background refresh is already running (collapses bursts).
  bool _refreshing = false;

  Future<AudioLibraryManifest> load() async {
    // 1) Same-session re-entry: serve the in-memory copy instantly and
    // refresh in the background so updates still arrive.
    final cached = _lastGood;
    if (cached != null) {
      _refreshInBackground();
      return cached;
    }
    // 2) First load this session: try the on-disk cache FIRST so the screen
    // paints immediately; the network only blocks when there is no cache at
    // all (very first app run).
    final fromDisk = await _loadFromDisk();
    if (fromDisk != null) {
      _refreshInBackground();
      return fromDisk;
    }
    // 3) No cache anywhere: fetch from the network (shared across callers).
    return _firstLoad ??= _fetchFresh().whenComplete(() => _firstLoad = null);
  }

  /// Network fetch + disk fallback (used on the very first load of a session).
  Future<AudioLibraryManifest> _fetchFresh() async {
    final client = _client ?? http.Client();
    var failure = AudioLibraryException.offline();
    try {
      final res = await client
          .get(Uri.parse(AudioLibraryConfig.manifestUrl))
          .timeout(const Duration(seconds: 30));
      if (res.statusCode == 200) {
        final manifest = _parse(res.bodyBytes);
        _lastGood = manifest;
        unawaited(_saveToDisk(manifest));
        return manifest;
      }
      failure = AudioLibraryException.server(res.statusCode);
    } on AudioLibraryException catch (e) {
      // Already a typed, user-presentable failure: it is carried in `failure`
      // and rethrown after the offline/cache fallbacks below.
      failure = e;
    } catch (e) {
      failure = e is TimeoutException || e is http.ClientException
          ? AudioLibraryException.offline()
          : AudioLibraryException.data();
      AppLogger.warning('AudioLibraryRepository', 'network load failed: $e');
    }

    final cached = _lastGood ?? await _loadFromDisk();
    if (cached != null) return cached;
    throw failure;
  }

  /// Body bytes → manifest. A host that answers 200 with an HTML error page or
  /// a truncated body is an [AudioLibraryFailure.data] problem, not a dead
  /// connection, so it must not be reported as one.
  static AudioLibraryManifest _parse(List<int> bodyBytes) {
    final decoded = jsonDecode(utf8.decode(bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw AudioLibraryException.data();
    }
    return AudioLibraryManifest.fromJson(decoded);
  }

  /// Picks up manifest updates without blocking the UI; failures are ignored
  /// because [load] already returned a cached copy. Collapsed: a second call
  /// while one refresh is in flight does nothing.
  void _refreshInBackground() {
    if (_refreshing) return;
    _refreshing = true;
    unawaited(() async {
      try {
        final client = _client ?? http.Client();
        final res = await client
            .get(Uri.parse(AudioLibraryConfig.manifestUrl))
            .timeout(const Duration(seconds: 30));
        if (res.statusCode == 200) {
          final manifest = AudioLibraryManifest.fromJson(
            jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
          );
          _lastGood = manifest;
          await _saveToDisk(manifest);
        }
      } catch (e) {
        AppLogger.warning(
            'AudioLibraryRepository', 'background refresh failed: $e');
      } finally {
        _refreshing = false;
      }
    }());
  }

  Future<void> _saveToDisk(AudioLibraryManifest manifest) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(manifest.toJson()));
    } catch (e) {
      AppLogger.warning('AudioLibraryRepository', 'cache write failed: $e');
    }
  }

  Future<AudioLibraryManifest?> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return null;
      final manifest = AudioLibraryManifest.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      _lastGood = manifest;
      return manifest;
    } catch (e) {
      AppLogger.warning('AudioLibraryRepository', 'cache read failed: $e');
      return null;
    }
  }

  @visibleForTesting
  void debugSetClient(http.Client? client) => _client = client;

  /// Simulates an app restart: forgets the in-memory copy but keeps the
  /// on-disk cache, so offline fallback is exercised.
  @visibleForTesting
  void debugForgetMemory() => _lastGood = null;

  @visibleForTesting
  Future<void> debugClearCache() async {
    _lastGood = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
    } catch (_) {
      AppLogger.warning('audio_library_repository', 'operation failed');
    }
  }
}

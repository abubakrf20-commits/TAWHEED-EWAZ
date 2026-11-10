import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/quran_helpers.dart'
    show getPageData, getPageNumber, getVerseCount, getJuzStartPage;
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'quran_api_cache.dart';
import 'quran_api_config.dart';
import 'quran_api_models.dart';

/// Error kinds surfaced to the UI (so it can show a friendly Persian message
/// instead of a crash or blank page).
enum QuranApiErrorType {
  configMissing,
  offline,
  unauthorized,
  notFound,
  server,
  invalidData,
}

class QuranApiException implements Exception {
  final QuranApiErrorType type;
  final String message;

  const QuranApiException(this.type, this.message);

  @override
  String toString() => 'QuranApiException($type): $message';
}

/// Typed client for the Quran Foundation Content API (v4).
///
/// Responsibilities:
///  * OAuth2 `client_credentials` token acquisition with local caching and
///    early refresh (no refresh token in this flow — a new token is requested
///    shortly before the current one expires).
///  * Typed endpoints: page verses, chapter audio + word timestamps, reciter
///    list, page lookup.
///  * Offline-first reads: every response is cached and served from cache when
///    the network is unavailable.
class QuranApiService {
  QuranApiService({http.Client? client}) : _client = client ?? http.Client();

  /// Shared app-wide instance (fonts, audio and pages all go through it).
  static final QuranApiService instance = QuranApiService();

  final http.Client _client;
  final QuranApiCache _cache = QuranApiCache.instance;

  /// Public quran.com API (no auth) — used for the wide reciter catalog.
  static const String _legacyApiBase = 'https://api.quran.com/api/v4';

  /// Closes the underlying HTTP client. Only call on instances owned by a
  /// widget's lifecycle (the shared [instance] must never be disposed).
  void dispose() => _client.close();

  static const _tokenKey = 'qf_access_token';
  static const _tokenExpiryKey = 'qf_access_token_expiry';

  String? _inMemoryToken;
  DateTime? _inMemoryExpiry;
  Future<String>? _tokenFuture;

  /// Force-fetches a brand-new token (used after a 401 or when credentials
  /// change). Does not consult the cache.
  Future<String> _fetchNewToken() async {
    if (!QuranApiConfig.isConfigured) {
      throw const QuranApiException(
        QuranApiErrorType.configMissing,
        'تنظیمات API قرآن (client_id و client_secret) هنوز در assets/env/quran_api.env '
        'قرار نگرفته است.',
      );
    }
    final credentials = base64Encode(utf8.encode('${QuranApiConfig.clientId}:'
        '${QuranApiConfig.clientSecret}'));
    try {
      final response = await _client
          .post(
            Uri.parse(QuranApiConfig.tokenEndpoint),
            headers: {
              'Authorization': 'Basic $credentials',
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: 'grant_type=client_credentials&scope=content',
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw QuranApiException(
          QuranApiErrorType.unauthorized,
          'دریافت توکن ناموفق بود (${response.statusCode}).',
        );
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final token = body['access_token'] as String?;
      if (token == null || token.isEmpty) {
        throw const QuranApiException(
          QuranApiErrorType.invalidData,
          'پاسخ توکن معتبر نیست.',
        );
      }
      final expiresIn = (body['expires_in'] as num?)?.toInt() ??
          QuranApiConfig.tokenLifetimeSeconds;
      final expiry = DateTime.now().add(Duration(seconds: expiresIn));

      _inMemoryToken = token;
      _inMemoryExpiry = expiry;
      await _cache.setString(_tokenKey, token);
      await _cache.setString(
          _tokenExpiryKey, expiry.millisecondsSinceEpoch.toString());
      return token;
    } on QuranApiException {
      rethrow;
    } catch (e) {
      AppLogger.warning('quran_api_service', 'error: $e');
      throw QuranApiException(
        QuranApiErrorType.offline,
        'ارتباط با سرور توکن برقرار نشد: $e',
      );
    }
  }

  /// Returns a valid token, reusing the in-memory / persisted copy until it is
  /// close to expiring. Concurrent callers share a single in-flight request.
  Future<String> ensureToken() async {
    // In-memory, still valid → reuse.
    final mem = _inMemoryToken;
    final memExpiry = _inMemoryExpiry;
    if (mem != null &&
        memExpiry != null &&
        memExpiry.difference(DateTime.now()) >
            const Duration(seconds: QuranApiConfig.tokenRefreshMarginSeconds)) {
      return mem;
    }
    // Persisted, still valid → reuse and cache in memory.
    final persisted = await _cache.getString(_tokenKey);
    final persistedExpiryRaw = await _cache.getString(_tokenExpiryKey);
    final persistedExpiry = DateTime.tryParse(persistedExpiryRaw ?? '') ??
        (persistedExpiryRaw != null
            ? DateTime.fromMillisecondsSinceEpoch(
                int.tryParse(persistedExpiryRaw) ?? 0)
            : null);
    if (persisted != null &&
        persistedExpiry != null &&
        persistedExpiry.difference(DateTime.now()) >
            const Duration(seconds: QuranApiConfig.tokenRefreshMarginSeconds)) {
      _inMemoryToken = persisted;
      _inMemoryExpiry = persistedExpiry;
      return persisted;
    }
    // Need a new token — dedupe concurrent refreshes.
    final inFlight = _tokenFuture;
    if (inFlight != null) return inFlight;
    final future = _fetchNewToken();
    _tokenFuture = future;
    try {
      return await future;
    } finally {
      _tokenFuture = null;
    }
  }

  /// Low-level authenticated GET with a single 401 → refresh → retry cycle.
  Future<Map<String, dynamic>> _getJson(
    String path, {
    Map<String, String>? query,
  }) async {
    final token = await ensureToken();
    final uri = Uri.parse('${QuranApiConfig.apiBase}$path')
        .replace(queryParameters: query);
    var response = await _send(uri, token);

    // Refresh the token once on 401 and retry.
    if (response.statusCode == 401) {
      final fresh = await _fetchNewToken();
      response = await _send(uri, fresh);
    }

    if (response.statusCode == 200) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {
        // fall through to error handling
      }
      throw const QuranApiException(
        QuranApiErrorType.invalidData,
        'پاسخ سرور قابل خواندن نیست.',
      );
    }

    throw _errorForStatus(response.statusCode);
  }

  /// Unauthenticated GET against the public quran.com API (no OAuth token).
  /// Used for the wide reciter catalog that the Quran Foundation API does not
  /// expose publicly.
  Future<Map<String, dynamic>> _getJsonPublic(
    String path, {
    Map<String, String>? query,
  }) async {
    final uri =
        Uri.parse('$_legacyApiBase$path').replace(queryParameters: query);
    late http.Response response;
    try {
      response = await _client.get(uri, headers: {
        'Accept': 'application/json'
      }).timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const QuranApiException(
        QuranApiErrorType.offline,
        'سرور پاسخ نداد؛ اتصال اینترنت را بررسی کنید.',
      );
    } catch (e) {
      AppLogger.warning('quran_api_service', 'error: $e');
      throw QuranApiException(
        QuranApiErrorType.offline,
        'ارتباط با سرور برقرار نشد: $e',
      );
    }
    if (response.statusCode != 200) {
      throw _errorForStatus(response.statusCode);
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      AppLogger.warning('quran_api_service', 'operation failed');
    }
    throw const QuranApiException(
      QuranApiErrorType.invalidData,
      'پاسخ سرور قابل خواندن نیست.',
    );
  }

  Future<http.Response> _send(Uri uri, String token) async {
    try {
      return await _client.get(uri, headers: {
        'x-auth-token': token,
        'x-client-id': QuranApiConfig.clientId,
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const QuranApiException(
        QuranApiErrorType.offline,
        'سرور پاسخ نداد؛ اتصال اینترنت را بررسی کنید.',
      );
    } catch (e) {
      AppLogger.warning('quran_api_service', 'error: $e');
      throw QuranApiException(
        QuranApiErrorType.offline,
        'ارتباط با سرور برقرار نشد: $e',
      );
    }
  }

  QuranApiException _errorForStatus(int status) {
    switch (status) {
      case 401:
        return const QuranApiException(
          QuranApiErrorType.unauthorized,
          'دسترسی غیرمجاز است؛ توکن نامعتبر شد.',
        );
      case 404:
        return const QuranApiException(
          QuranApiErrorType.notFound,
          'مورد درخواستی پیدا نشد.',
        );
      case 429:
        return const QuranApiException(
          QuranApiErrorType.server,
          'محدودیت تعداد درخواست؛ کمی بعد دوباره تلاش کنید.',
        );
      default:
        if (status >= 500) {
          return QuranApiException(
            QuranApiErrorType.server,
            'خطای سرور ($status)؛ دوباره تلاش کنید.',
          );
        }
        return QuranApiException(
          QuranApiErrorType.invalidData,
          'خطای نامشخص ($status).',
        );
    }
  }

  // ── Endpoints ─────────────────────────────────────────────────────────────

  /// Verses of one mushaf page (Mushaf 1 = QCF V2 / Medina print).
  /// Words carry QCF V2 glyphs (`code_v2`) + `line_number` for line grouping.
  Future<List<QuranVerse>> getPageVerses(
    int pageNumber, {
    int mushafId = QuranApiConfig.defaultMushafId,
  }) async {
    // v2: the payload now carries per-word translations (wave-2 #3); the
    // older key would keep serving translation-less rows for months.
    final cacheKey = 'qf_page_v2_${mushafId}_$pageNumber';
    final cached = await _cache.getJson(cacheKey);
    if (cached != null) {
      return _parsePageResponse(cached);
    }
    // No Quran Foundation credentials/proxy configured: the mushaf works
    // fully offline, so build the verse list from the bundled page table.
    // B01 fix: the bundled path now also carries the offline Persian
    // word-by-word meanings, so the release build's «معنی واژه» sheet works
    // (it used to receive word-less verses and became unreachable).
    if (!QuranApiConfig.isConfigured) {
      return _bundledPageVerses(pageNumber);
    }
    final json = await _getJson(
      '/verses/by_page/$pageNumber',
      query: {
        'mushaf': '$mushafId',
        'words': 'true',
        'word_fields':
            'code_v2,text_qpc_hafs,text_uthmani,line_number,page_number,translation',
        'per_page': '50',
      },
    );
    var verses = _parsePageResponse(json);
    if (verses.isEmpty && _pageHasRecords(json)) {
      // Prelive quirk: `by_page` with `words=true` returns an empty verses
      // array even though the page exists. Fall back to fetching each surah
      // on the page via `by_chapter` (which does return words) and keep only
      // the words that belong to this page.
      verses = await _fetchPageViaChapters(pageNumber, mushafId);
    }
    if (verses.isNotEmpty) {
      await _cache.setJson(cacheKey, _serializeVerses(verses));
    }
    return verses;
  }

  /// Whether the pagination metadata of a by_page response says the page has
  /// records (used to detect the prelive empty-verses quirk).
  bool _pageHasRecords(Map<String, dynamic> json) {
    final pagination = json['pagination'];
    if (pagination is Map<String, dynamic>) {
      final total = pagination['total_records'];
      if (total is num && total > 0) return true;
      final pages = pagination['total_pages'];
      if (pages is num && pages > 0) return true;
    }
    return false;
  }

  /// Fallback loader: fetch the surahs that appear on [pageNumber] via
  /// `by_chapter` and filter their words to this page. Used when `by_page`
  /// returns an empty verses array (prelive API quirk).
  Future<List<QuranVerse>> _fetchPageViaChapters(
    int pageNumber,
    int mushafId,
  ) async {
    final pageEntries = _surahsOnPage(pageNumber);
    // Fetch the page's surahs concurrently — the fallback must stay fast.
    final results = await Future.wait(
      pageEntries.map(
        (surah) => _fetchChapterVersesForPage(surah, pageNumber, mushafId),
      ),
    );
    final collected = <Map<String, dynamic>>[
      for (final list in results) ...list,
    ];
    return _parsePageResponse({'verses': collected});
  }

  /// One surah's verses whose words fall on [pageNumber].
  ///
  /// `chapter_id` is injected explicitly (prelive responses omit it) and
  /// `per_page` covers the longest surah (Al-Baqarah, 286 verses) so pages in
  /// the middle/end of long surahs still get their words.
  Future<List<Map<String, dynamic>>> _fetchChapterVersesForPage(
    int surah,
    int pageNumber,
    int mushafId,
  ) async {
    try {
      final json = await _getJson(
        '/verses/by_chapter/$surah',
        query: {
          'mushaf': '$mushafId',
          'words': 'true',
          'word_fields':
              'code_v2,text_qpc_hafs,text_uthmani,line_number,page_number,translation',
          'per_page': '300',
        },
      );
      final raw = json['verses'];
      if (raw is! List) return const [];
      final out = <Map<String, dynamic>>[];
      for (final v in raw.whereType<Map<String, dynamic>>()) {
        final rawWords = v['words'];
        if (rawWords is! List) continue;
        final pageWords = rawWords
            .whereType<Map<String, dynamic>>()
            .where((w) => (w['page_number'] as num?)?.toInt() == pageNumber)
            .toList();
        if (pageWords.isEmpty) continue;
        final copy = Map<String, dynamic>.from(v)
          ..['words'] = pageWords
          ..['chapter_id'] = surah;
        out.add(copy);
      }
      return out;
    } catch (_) {
      // Skip a failing surah; the rest of the page may still load.
      return const [];
    }
  }

  /// Surah numbers that share [pageNumber], from the local page map.
  List<int> _surahsOnPage(int pageNumber) {
    try {
      return getPageData(pageNumber)
          .map((e) => (e['surah'] as num?)?.toInt())
          .whereType<int>()
          .where((s) => s >= 1 && s <= 114)
          .toSet()
          .toList();
    } catch (_) {
      AppLogger.warning('quran_api_service', 'operation failed');
      return const [];
    }
  }

  /// Round-trips parsed verses back to JSON for the offline cache.
  Map<String, dynamic> _serializeVerses(List<QuranVerse> verses) => {
        'verses': [for (final v in verses) v.toJson()],
      };

  /// Builds a verse list for [pageNumber] from the bundled page table (used
  /// when the Quran Foundation API is not configured). Surah/verse numbers
  /// come from the page table; the verses carry no per-word data — the
  /// word-meaning sheet that consumed it is gone.
  Future<List<QuranVerse>> _bundledPageVerses(int pageNumber) async {
    try {
      final rows = getPageData(pageNumber);
      final verses = <QuranVerse>[];
      for (final row in rows) {
        final surah = row['surah'] as int;
        final start = row['start'] as int;
        final end = row['end'] as int;
        for (var v = start; v <= end; v++) {
          verses.add(QuranVerse(
            id: 0,
            chapterId: surah,
            verseNumber: v,
            verseKey: '$surah:$v',
            pageNumber: pageNumber,
          ));
        }
      }
      return verses;
    } catch (_) {
      AppLogger.warning('quran_api_service', 'operation failed');
      return const [];
    }
  }

  List<QuranVerse> _parsePageResponse(Map<String, dynamic> json) {
    final rawVerses = json['verses'];
    if (rawVerses is! List) {
      throw const QuranApiException(
        QuranApiErrorType.invalidData,
        'پاسخ صفحهٔ مصحف معتبر نیست.',
      );
    }
    return rawVerses
        .whereType<Map<String, dynamic>>()
        .map(QuranVerse.fromJson)
        .toList();
  }

  /// Dynamic reciter list from `/resources/chapter_reciters`.
  Future<List<ChapterReciter>> getReciters({String language = 'fa'}) async {
    // v2: prelive `chapter_reciters` returned only 2 reciters in earlier
    // builds (cached under the old key); bump the key so stale entries are
    // ignored and the full list (4 in prelive, many more in production) loads.
    final cacheKey = 'qf_reciters_v2_$language';
    final cached = await _cache.getJson(cacheKey);
    if (cached != null) {
      return _parseReciters(cached);
    }
    List<ChapterReciter> list = const [];
    String? qfError;
    try {
      final json = await _getJson(
        '/resources/chapter_reciters',
        query: {'language': language},
      );
      list = _parseReciters(json);
    } catch (e) {
      AppLogger.warning('quran_api_service', 'error: $e');
      qfError = '$e';
    }
    // The Quran Foundation list can be short (prelive had ~2-4). When it is
    // empty/short, fall back to the public quran.com recitation catalog, which
    // lists every reciter hosted on the public audio CDN (100+).
    if (list.length < 5) {
      try {
        final legacy = await _legacyReciters(language);
        if (legacy.isNotEmpty) list = legacy;
      } catch (_) {
        // keep the QF result / error below
      }
    }
    if (list.isNotEmpty) {
      await _cache.setJson(cacheKey, _serializeReciters(list));
      return list;
    }
    throw QuranApiException(
      qfError != null ? QuranApiErrorType.server : QuranApiErrorType.offline,
      qfError ?? 'لیست قاریان دریافت نشد.',
    );
  }

  /// Public (unauthenticated) reciter catalog from `api.quran.com` — the same
  /// source the quran.com apps use. Returns every reciter on the audio CDN.
  Future<List<ChapterReciter>> _legacyReciters(String language) async {
    final json = await _getJsonPublic(
      '/resources/recitations',
      query: {'language': language},
    );
    final raw = json['recitations'];
    if (raw is! List) {
      throw const QuranApiException(
        QuranApiErrorType.invalidData,
        'لیست قاریان معتبر نیست.',
      );
    }
    return raw
        .whereType<Map<String, dynamic>>()
        .map(ChapterReciter.fromJson)
        .toList();
  }

  Map<String, dynamic> _serializeReciters(List<ChapterReciter> list) => {
        'reciters': [for (final r in list) r.toJson()],
      };

  List<ChapterReciter> _parseReciters(Map<String, dynamic> json) {
    final raw = json['reciters'];
    if (raw is! List) {
      throw const QuranApiException(
        QuranApiErrorType.invalidData,
        'لیست قاریان معتبر نیست.',
      );
    }
    return raw
        .whereType<Map<String, dynamic>>()
        .map(ChapterReciter.fromJson)
        .toList();
  }

  /// Pages lookup for a chapter/juz/range (used by the «رفتن به» dialog).
  Future<PagesLookup> lookupPages({
    int? chapterNumber,
    int? juzNumber,
    String? from,
    String? to,
    int mushafId = QuranApiConfig.defaultMushafId,
  }) async {
    final query = <String, String>{'mushaf': '$mushafId'};
    if (chapterNumber != null) query['chapter_number'] = '$chapterNumber';
    if (juzNumber != null) query['juz_number'] = '$juzNumber';
    if (from != null) query['from'] = from;
    if (to != null) query['to'] = to;

    final cacheKey =
        'qf_lookup_${mushafId}_${chapterNumber ?? ''}_${juzNumber ?? ''}_'
        '${from ?? ''}_${to ?? ''}';
    final cached = await _cache.getJson(cacheKey);
    if (cached != null) return PagesLookup.fromJson(cached);

    // No Quran Foundation credentials/proxy configured: resolve pages from the
    // bundled page table (surah → start page, juz → start page).
    if (!QuranApiConfig.isConfigured) {
      return _bundledPagesLookup(
        chapterNumber: chapterNumber,
        juzNumber: juzNumber,
      );
    }

    final json = await _getJson('/pages/lookup', query: query);
    await _cache.setJson(cacheKey, json);
    return PagesLookup.fromJson(json);
  }

  /// Resolves the start page of [chapterNumber] or [juzNumber] from the
  /// bundled page table (used when the Quran Foundation API is not
  /// configured). Mirrors the shape of the `/pages/lookup` response.
  PagesLookup _bundledPagesLookup({int? chapterNumber, int? juzNumber}) {
    int page;
    String rangeFrom = '';
    String rangeTo = '';
    if (chapterNumber != null) {
      try {
        page = getPageNumber(chapterNumber, 1);
      } catch (_) {
        AppLogger.warning('quran_api_service', 'operation failed');
        page = 1;
      }
      rangeFrom = '$chapterNumber:1';
      rangeTo = '$chapterNumber:${getVerseCount(chapterNumber)}';
    } else if (juzNumber != null) {
      try {
        page = getJuzStartPage(juzNumber);
      } catch (_) {
        AppLogger.warning('quran_api_service', 'operation failed');
        page = 1;
      }
      rangeFrom = 'juz $juzNumber';
      rangeTo = 'juz $juzNumber';
    } else {
      page = 1;
    }
    return PagesLookup(
      rangeFrom: rangeFrom,
      rangeTo: rangeTo,
      totalPage: QuranApiConfig.mushafPageCount,
      pages: {
        page: PageInfo(
          from: rangeFrom,
          to: rangeTo,
          firstVerseKey: rangeFrom,
          lastVerseKey: rangeTo,
        ),
      },
    );
  }
}

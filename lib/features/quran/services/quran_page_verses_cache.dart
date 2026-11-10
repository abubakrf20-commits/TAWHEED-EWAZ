import 'package:tawheeed/features/quran/api/quran_api_models.dart';
import 'package:tawheeed/features/quran/api/quran_api_service.dart';
import 'package:tawheeed/features/quran/data/quran_helpers.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// The reader's per-page verse cache (wave-3 #4, second slice out of the
/// monolith): fetch, LRU bounding, retry-with-backoff, and the bundled-data
/// offline fallback, in one testable class with no widget state inside.
///
/// `onChanged` is what was `setState` in the view — called whenever the
/// cache's visible content changed (fetch landed, retry gave up), so the
/// host can re-render without this class knowing about widgets.
class QuranPageVersesCache {
  QuranPageVersesCache({QuranApiService? api})
      : _api = api ?? QuranApiService();

  final QuranApiService _api;
  final Map<int, List<QuranVerse>> _verses = {};
  final Set<int> _loading = {};

  /// How many pages are resident (bounded — see [_bound]) — for storage
  /// readouts and tests.
  int get residentCount => _verses.length;

  /// The cached verses of [page], or null when not resident.
  List<QuranVerse>? peek(int page) {
    final cached = _verses[page];
    if (cached == null || cached.isEmpty) return null;
    return cached;
  }

  /// Warm [page] if it is not resident and not already in flight. Failures
  /// retry twice with a short backoff (debug-logged), then give up — the
  /// offline fallback covers the reader until a later pass.
  Future<void> load(int page, {void Function()? onChanged}) async {
    if (_verses.containsKey(page) || _loading.contains(page)) return;
    await _load(page, 0, onChanged);
  }

  Future<void> _load(int page, int attempt, void Function()? onChanged) async {
    if (_verses.containsKey(page) || _loading.contains(page)) return;
    _loading.add(page);
    try {
      final verses = await _api.getPageVerses(page);
      _verses[page] = verses;
      // Bound the cache like the QCF4 page cache: only the recently-viewed
      // window stays resident (evicted pages re-fetch).
      while (_verses.length > 21) {
        _verses.remove(_verses.keys.first);
      }
      _loading.remove(page);
      onChanged?.call();
    } catch (e) {
      if (attempt < 2) {
        // Transient failures (cold network start, rate limit, timeouts) are
        // common on the very first open — retry a couple of times with a
        // short backoff before giving up. Retries are debug-only: up to 3
        // lines per page used to stack up in the on-device log.
        AppLogger.debug(
            'quran_page_verses_cache',
            'verse fetch failed (attempt ${attempt + 1}/3): $e');
        _loading.remove(page);
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        return _load(page, attempt + 1, onChanged);
      }
      AppLogger.warning(
          'quran_page_verses_cache', 'verse fetch failed for page $page: $e');
      _loading.remove(page);
      onChanged?.call();
    }
  }

  /// One page's verses: resident cache first, then a fetch, then the bundled
  /// page data when the network is gone — the sheets need only surah/verse
  /// numbers, never the ayah text.
  Future<List<QuranVerse>> versesForPage(int page) async {
    final cached = peek(page);
    if (cached != null) return cached;
    if (!_loading.contains(page)) {
      await load(page);
    }
    final loaded = peek(page);
    if (loaded != null) return loaded;
    return offlinePageVerses(page);
  }

  /// Rebuilds a page's verse list from the bundled page data, for a page the
  /// network never delivered.
  static List<QuranVerse> offlinePageVerses(int page) {
    try {
      final fallback = <QuranVerse>[];
      for (final row in getPageData(page)) {
        final surah = row['surah'] as int;
        final start = row['start'] as int;
        final end = row['end'] as int;
        for (var v = start; v <= end; v++) {
          fallback.add(QuranVerse(
            id: 0,
            chapterId: surah,
            verseNumber: v,
            verseKey: '$surah:$v',
            pageNumber: page,
          ));
        }
      }
      return fallback;
    } catch (e) {
      AppLogger.warning(
          'quran_page_verses_cache', 'page fallback failed: $e');
      return const [];
    }
  }
}

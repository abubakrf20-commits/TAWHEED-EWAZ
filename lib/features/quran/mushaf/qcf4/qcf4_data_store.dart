import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'package:tawheeed/features/quran/mushaf/qcf4/qcf4_config.dart';
import 'package:tawheeed/features/quran/services/content_provenance.dart';
import 'package:tawheeed/features/quran/mushaf/qcf4/qcf4_models.dart';
import 'package:tawheeed/features/quran/services/quran_storage.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Result of reading a page: either parsed, or a shortfall describing why.
sealed class Qcf4PageLoad {
  const Qcf4PageLoad();
}

class Qcf4PageLoaded extends Qcf4PageLoad {
  final Qcf4Page page;
  const Qcf4PageLoaded(this.page);
}

class Qcf4PageMissing extends Qcf4PageLoad {
  /// `true` when the page should be fetched from the CDN (not yet on disk).
  final bool fetchFromNetwork;
  const Qcf4PageMissing({required this.fetchFromNetwork});
}

/// Loads QCF4 page JSON (`pages/NNN.json`) from disk first, then the CDN.
///
/// Disk is authoritative once a page is downloaded (per the product decision:
/// "read source is always from disk after download; CDN only if not yet
/// downloaded"), so offline reading works once a page, or the whole mushaf,
/// has been fetched.
class Qcf4DataStore {
  Qcf4DataStore();

  Directory? _pagesDir;

  /// In-memory page cache, bounded as a small LRU (insertion-ordered map):
  /// only the recently-viewed window stays decoded in RAM; disk remains the
  /// authoritative source, so evicted pages simply re-read from disk.
  static const int _memMaxPages = 21;
  final Map<int, Qcf4Page> _mem = {};

  static final Qcf4DataStore instance = Qcf4DataStore();

  Qcf4Page? _memGet(int page) {
    final cached = _mem.remove(page);
    if (cached != null) _mem[page] = cached; // mark most-recently-used
    return cached;
  }

  void _memPut(int page, Qcf4Page value) {
    _mem.remove(page);
    _mem[page] = value;
    while (_mem.length > _memMaxPages) {
      _mem.remove(_mem.keys.first);
    }
  }

  /// Synchronous RAM-only peek: the decoded page if it is already in the
  /// in-memory LRU, without touching disk/network or the LRU order. Lets the
  /// viewer render instantly (no spinner) when everything is already cached.
  Qcf4Page? peek(int page) => _mem[page];

  /// Directory holding downloaded page JSON files.
  Future<Directory> _pagesDirAsync() async {
    if (_pagesDir != null) return _pagesDir!;
    final root = await QuranStorage.contentDir();
    final dir = Directory(p.join(root.path, Qcf4Config.cacheDirName, 'pages'));
    if (!await dir.exists()) await dir.create(recursive: true);
    _pagesDir = dir;
    return dir;
  }

  File _pageFile(Directory dir, int page) =>
      File(p.join(dir.path, '${page.toString().padLeft(3, '0')}.json'));

  /// Below this size an inline `jsonDecode` beats the isolate hand-off, so only
  /// the big payloads pay for the transfer. A typical mushaf page is a few
  /// hundred KB — long enough that decoding it on the UI isolate drops frames
  /// in the middle of a swipe.
  static const int _isolateDecodeThreshold = 48 * 1024;

  /// Decodes cached page JSON off the UI isolate.
  ///
  /// Parsing a page is pure CPU over a large `Map`/`List` graph, and this runs
  /// while the reader is scrolling. Left on the UI isolate it competes with the
  /// gesture frame budget, which is what made a page flip feel like a stutter
  /// even when the JSON was already on disk. [Qcf4Page] and its children hold
  /// only ints/strings/lists, so the result transfers cheaply.
  static Future<Qcf4Page?> _decodePageAsync(String raw) async {
    if (raw.length < _isolateDecodeThreshold) {
      return Qcf4Page.decode(raw);
    }
    try {
      return await Isolate.run(() => Qcf4Page.decode(raw));
    } catch (e) {
      // An isolate is a nicety here, never a requirement: fall back inline.
      AppLogger.info('qcf4_data_store', 'isolate decode failed: $e');
      return Qcf4Page.decode(raw);
    }
  }

  /// True if a page's JSON is already cached on disk.
  Future<bool> isPageCached(int page) async {
    if (_mem.containsKey(page)) return true;
    final dir = await _pagesDirAsync();
    return (await _pageFile(dir, page).exists());
  }

  /// Get a page, reading disk first and falling back to the CDN. When
  /// [allowNetwork] is false (offline / explicit no-network calls) a disk
  /// miss returns [Qcf4PageMissing] with `fetchFromNetwork=false` instead of
  /// hitting the network.
  Future<Qcf4PageLoad> loadPage(int page, {bool allowNetwork = true}) async {
    final cached = _memGet(page);
    if (cached != null) return Qcf4PageLoaded(cached);

    final dir = await _pagesDirAsync();
    final file = _pageFile(dir, page);
    if (await file.exists()) {
      try {
        final raw = await file.readAsString();
        final parsed = await _decodePageAsync(raw);
        if (parsed != null && parsed.page == page) {
          _memPut(page, parsed);
          return Qcf4PageLoaded(parsed);
        }
        // Corrupt cache — remove and fall through to network.
        await file.delete().catchError((_) => file);
      } catch (e) {
        AppLogger.debug('qcf4_data_store', 'read page $page failed: $e');
        await file.delete().catchError((_) => file);
      }
    }

    if (!allowNetwork) {
      return const Qcf4PageMissing(fetchFromNetwork: true);
    }

    final fetched = await _fetchPage(page);
    if (fetched == null) {
      return const Qcf4PageMissing(fetchFromNetwork: true);
    }
    _memPut(page, fetched);
    await _writePage(file, fetched);
    return Qcf4PageLoaded(fetched);
  }

  Future<Qcf4Page?> _fetchPage(int page) async {
    // Single attempt: retries with a 2s backoff made rapid page-flipping on
    // under-downloaded pages stall and spam the log. The pre-fetcher (and
    // user taps) re-trigger a fetch on the next pass, so one shot is enough.
    try {
      final res = await http
          .get(Uri.parse(Qcf4Config.pageJsonUrl(page)))
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        AppLogger.debug('qcf4_data_store', 'page $page HTTP ${res.statusCode}');
        return null;
      }
      // Decode AND parse in one hop off the UI isolate: this is a pure-CPU
      // pass over a large payload, and it is on the path of a page flip.
      final parsed = await Isolate.run(() {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        if (decoded is! Map<String, dynamic>) return null;
        return Qcf4Page.fromJson(decoded);
      });
      if (parsed == null || parsed.page != page) return null;
      return parsed;
    } catch (e) {
      AppLogger.debug('qcf4_data_store', 'fetch page $page failed: $e');
    }
    return null;
  }

  Future<void> _writePage(File file, Qcf4Page page) async {
    try {
      final encoded = page.encode();
      await file.writeAsString(encoded, flush: true);
      // Provenance sidecar (wave-3 #3): what the page is, where it came
      // from, and the sha256 of the exact canonical bytes committed. The
      // decode pass already gates corruption on read; the sidecar is the
      // audit trail, written best-effort so a failed sidecar can never fail
      // a page that is safely on disk.
      await ContentProvenance.write(
        file.path,
        utf8.encode(encoded),
        id: 'qcf4_page_${page.page}',
        remoteUrl: Qcf4Config.pageJsonUrl(page.page),
      );
    } catch (e) {
      AppLogger.debug('qcf4_data_store', 'write page ${page.page} failed: $e');
    }
  }

  /// Drop the in-memory cache (e.g. after a full-mushaf re-download).
  void clearMemory() => _mem.clear();

  /// Number of page JSON files cached on disk (for the download manager's
  /// storage readout / resume info).
  Future<int> cachedPageCount() async {
    try {
      final dir = await _pagesDirAsync();
      if (!await dir.exists()) return 0;
      var count = 0;
      await for (final e in dir.list()) {
        if (e is File && e.path.endsWith('.json')) count++;
      }
      return count;
    } catch (_) {
      AppLogger.warning('qcf4_data_store', 'count cached pages failed');
      return 0;
    }
  }

  /// Delete every cached page JSON from disk so a re-download starts fresh.
  /// Memory cache is cleared too.
  Future<void> clearCache() async {
    _mem.clear();
    try {
      final dir = await _pagesDirAsync();
      if (await dir.exists()) {
        await for (final e in dir.list()) {
          if (e is File && e.path.endsWith('.json')) {
            await e.delete().catchError((_) => e);
          }
        }
      }
    } catch (e) {
      AppLogger.info('qcf4_data_store', 'clear cache failed: $e');
    }
  }
}

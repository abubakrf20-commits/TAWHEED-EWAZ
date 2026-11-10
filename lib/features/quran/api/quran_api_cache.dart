import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Local cache layer for the Quran API.
///
/// * Small strings (access token, misc preferences) → [SharedPreferences].
/// * JSON metadata (page verses, reciters, page lookup) → JSON files under
///   `<app-support>/quran_cache/json` (page data can reach hundreds of KB per
///   entry; SharedPreferences loads its whole backing store into memory at
///   startup).
///
/// The JSON directory is capped at [maxJsonBytes]: every write prunes the
/// oldest entries first, so a reader who keeps opening new pages cannot grow the
/// cache without bound. Pruning is best-effort — a failure never fails the write.
///
/// Everything is best-effort: cache misses simply fall through to the network.
class QuranApiCache {
  QuranApiCache._();

  static final QuranApiCache instance = QuranApiCache._();

  /// Upper bound for the JSON cache directory. Page payloads reach hundreds of
  /// KB each and one mushaf keys up to 604 pages, so an uncapped cache grows by
  /// tens of megabytes; 16 MiB holds the pages a reader actually returns to, and
  /// anything evicted is simply re-fetched.
  @visibleForTesting
  static const int maxJsonBytes = 16 << 20;

  Directory? _cacheDir;

  Future<Directory> _ensureCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'quran_cache'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cacheDir = dir;
    return dir;
  }

  Future<Directory> _subDir(String name) async {
    final base = await _ensureCacheDir();
    final dir = Directory(p.join(base.path, name));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  // ── Metadata (SharedPreferences) ──────────────────────────────────────────

  Future<String?> getString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  Future<void> setString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> removeString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  /// Reads cached JSON for [key]; returns `null` when absent or corrupt.
  ///
  /// JSON payloads (page verses, audio timestamps, reciters, lookups) are
  /// stored as files — page data alone can reach hundreds of KB, and
  /// [SharedPreferences] loads its whole backing store into memory at startup.
  Future<Map<String, dynamic>?> getJson(String key) async {
    final dir = await _subDir('json');
    final file = File(p.join(dir.path, _jsonFileName(key)));
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // Corrupt cache entry — drop it and fall through to the network.
      try {
        await file.delete();
      } catch (_) {
        AppLogger.warning('quran_api_cache', 'operation failed');
      }
    }
    return null;
  }

  Future<void> setJson(String key, Map<String, dynamic> value) async {
    final dir = await _subDir('json');
    final file = File(p.join(dir.path, _jsonFileName(key)));
    await _atomicWrite(file, utf8.encode(jsonEncode(value)));
    try {
      await _pruneIfOverCap(dir, keepPath: file.path);
    } catch (e) {
      // A locked file or a full disk must never fail the network write.
      AppLogger.warning('quran_api_cache', 'prune failed: $e');
    }
  }

  /// Oldest-first eviction candidates from [entries] until the total fits
  /// [capBytes]. [keepPath] is never selected — that is the entry just written,
  /// the one a caller is about to read back.
  @visibleForTesting
  static List<String> evictionCandidatesFor(
    List<({String path, int bytes, DateTime modified})> entries, {
    required int capBytes,
    String? keepPath,
  }) {
    var total = 0;
    for (final entry in entries) {
      total += entry.bytes;
    }
    if (total <= capBytes) return const [];
    final ordered = [...entries]
      ..sort((a, b) => a.modified.compareTo(b.modified));
    final victims = <String>[];
    for (final entry in ordered) {
      if (total <= capBytes) break;
      if (entry.path == keepPath) continue;
      victims.add(entry.path);
      total -= entry.bytes;
    }
    return victims;
  }

  Future<void> _pruneIfOverCap(Directory dir,
      {required String keepPath}) async {
    final entries = <({String path, int bytes, DateTime modified})>[];
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      // Only completed entries are candidates; a '.part' temporary belongs to
      // the write that is running right now.
      if (!p.basename(entity.path).endsWith('.json')) continue;
      try {
        final stat = await entity.stat();
        entries.add((
          path: entity.path,
          bytes: stat.size,
          modified: stat.modified,
        ));
      } catch (_) {
        AppLogger.warning('quran_api_cache', 'stat failed');
      }
    }
    final victims = evictionCandidatesFor(
      entries,
      capBytes: maxJsonBytes,
      keepPath: keepPath,
    );
    for (final path in victims) {
      try {
        await File(path).delete();
      } catch (_) {
        AppLogger.warning('quran_api_cache', 'evict failed');
      }
    }
  }

  Future<void> _atomicWrite(File file, List<int> bytes) async {
    final temp = File('${file.path}.part');
    await temp.writeAsBytes(bytes, flush: true);
    if (await file.exists()) await file.delete();
    await temp.rename(file.path);
  }

  static String _jsonFileName(String key) =>
      '${base64Url.encode(utf8.encode(key))}.json';
}

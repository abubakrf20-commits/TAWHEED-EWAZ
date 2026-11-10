import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/features/quran/data/everyayah_catalog.dart';
import 'package:tawheeed/features/quran/data/quran_helpers.dart';
import 'package:tawheeed/features/quran/data/reciter_map.dart';
import 'package:tawheeed/features/quran/services/quran_storage.dart';

/// One reciter (Hafs / Murattal) with a [String] identifier matching the
/// islamic.network CDN (the same audio set used by Quran.com / everyayah).
///
/// The CDN serves **one mp3 per ayah** (`audio/128/{id}/{globalAyah}.mp3`)
/// plus **one mp3 per surah** (`audio-surah/128/{id}/{surah}.mp3`). Playing
/// the per-ayah file makes talaawah playback exact — the tapped verse IS the
/// verse that is heard, with no approximate seeking.
class Mp3QuranReciter {
  /// CDN identifier, e.g. `ar.alafasy`.
  final String identifier;

  /// Display name (Arabic), e.g. «مشاري العفاسي».
  final String name;

  final int surahCount;

  const Mp3QuranReciter({
    required this.identifier,
    required this.name,
    this.surahCount = 114,
  });

  /// Remote URL of the whole-surah mp3 (used by offline downloads and the
  /// "play from the start of the surah" convenience).
  String surahUrl(int surah) {
    final everyAyah = kEveryAyahFallback[identifier];
    if (everyAyah != null) {
      // EveryAyah per-surah via concatenated? fallback to per-ayah list not needed
      return 'https://cdn.islamic.network/quran/audio-surah/128/'
          '$identifier/$surah.mp3';
    }
    return 'https://cdn.islamic.network/quran/audio-surah/128/'
        '$identifier/$surah.mp3';
  }

  /// Remote URL of one ayah's mp3 — EveryAyah برای همه (تک‌سرور، هایلایت سازگار).
  String verseUrl(int surah, int verse) {
    if (identifier.startsWith('everyayah:')) {
      final folder = identifier.substring('everyayah:'.length);
      final s = surah.toString().padLeft(3, '0');
      final v = verse.toString().padLeft(3, '0');
      return 'https://everyayah.com/data/$folder/$s$v.mp3';
    }
    final everyAyah = kEveryAyahFallback[identifier];
    if (everyAyah != null) {
      final s = surah.toString().padLeft(3, '0');
      final v = verse.toString().padLeft(3, '0');
      return 'https://everyayah.com/data/$everyAyah/$s$v.mp3';
    }
    return 'https://cdn.islamic.network/quran/audio/128/'
        '$identifier/${globalAyahNumber(surah, verse)}.mp3';
  }

  /// Fallback URLs when primary EveryAyah fails (e.g., 404 for a specific ayah).
  List<String> verseUrlsWithFallback(int surah, int verse) {
    final primary = verseUrl(surah, verse);
    final list = <String>[primary];
    // برای everyayah: یک fallback به cdn اگر ar.* معادل داشته باشد
    if (identifier.startsWith('everyayah:')) {
      final folder = identifier.substring('everyayah:'.length);
      // تلاش برای نسخه 64kbps اگر 128 موجود نبود
      if (folder.endsWith('_128kbps')) {
        final alt = folder.replaceAll('_128kbps', '_64kbps');
        final s = surah.toString().padLeft(3, '0');
        final v = verse.toString().padLeft(3, '0');
        list.add('https://everyayah.com/data/$alt/$s$v.mp3');
      }
    }
    return list;
  }

  factory Mp3QuranReciter.fromJson(Map<String, dynamic> json) =>
      Mp3QuranReciter(
        identifier: json['identifier'] as String? ?? '',
        name: json['name'] as String? ?? '',
        surahCount: json['surah_count'] as int? ?? 114,
      );

  Map<String, dynamic> toJson() => {
        'identifier': identifier,
        'name': name,
        'surah_count': surahCount,
      };
}

/// Global (1-based) ayah number across the whole Quran: `2:6` → 13.
/// Used by the CDN's per-ayah file names.
int globalAyahNumber(int surah, int verse) {
  var global = verse;
  for (var s = 1; s < surah; s++) {
    global += getVerseCount(s);
  }
  return global;
}

/// Fetches the reciter catalog from the public alquran.cloud editions API and
/// builds playable URLs against the islamic.network CDN. No API key needed.
///
/// The live list is cached in [SharedPreferences] so the reciter picker keeps
/// working offline; when both the network and the cache fail, a curated
/// fallback list of well-known Hafs reciters is returned.
class Mp3QuranService {
  Mp3QuranService._();

  /// Editions API: Arabic audio, verse-by-verse (per-ayah files exist).
  static const String apiUrl = 'https://api.alquran.cloud/v1/edition'
      '?format=audio&language=ar&type=versebyverse';

  /// SharedPreferences key holding the cached reciter JSON.
  static const String cachePrefsKey = 'mp3quran_reciters_v5';

  /// Cache folder (relative to [QuranStorage.contentDir]) for downloaded
  /// audio: `audio_mp3quran/{identifier}/{surah:03}/{ayah:03}.mp3`.
  static const String audioCacheDirName = 'audio_mp3quran';

  /// مدت نگهداری کش صوتی — 7 روز؛ پس از آن به‌صورت خودکار حذف و در صورت نیاز دوباره دانلود می‌شود
  static const Duration cacheMaxAge = Duration(days: 7);

  // ── Explicit-download registry ("offline forever") ────────────────────
  // Files fetched by playback streaming/prefetch are ephemeral (7-day
  // expiry). Surahs the user EXPLICITLY downloads (surah/juz/whole-Quran)
  // are marked offline and never expire or get swept. Marks live in
  // SharedPreferences as `audio_offline_{sanitizedId}_{surah}` = 1.
  static const String _offlineMarkPrefix = 'audio_offline_';

  static String _offlineMarkKey(String reciterId, int surah) =>
      '$_offlineMarkPrefix${_sanitizeId(reciterId)}_$surah';

  static Future<bool> isMarkedOffline(String reciterId, int surah) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_offlineMarkKey(reciterId, surah)) == 1;
    } catch (e) {
      AppLogger.warning('Mp3Quran', 'offline check failed: $e');
      return false;
    }
  }

  static Future<void> markSurahOffline(String reciterId, int surah) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_offlineMarkKey(reciterId, surah), 1);
    } catch (e) {
      AppLogger.warning('Mp3Quran', 'mark offline failed: $e');
    }
  }

  static Future<void> unmarkSurahOffline(String reciterId, int surah) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_offlineMarkKey(reciterId, surah));
    } catch (e) {
      AppLogger.warning('Mp3Quran', 'unmark offline failed: $e');
    }
  }

  static Future<void> unmarkAllOffline(String reciterId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefix = '$_offlineMarkPrefix${_sanitizeId(reciterId)}_';
      for (final k in prefs.getKeys().where((k) => k.startsWith(prefix))) {
        await prefs.remove(k);
      }
    } catch (e) {
      AppLogger.warning('Mp3Quran', 'unmark-all failed: $e');
    }
  }

  /// لیست واحد EveryAyah — 47 قاری با هایلایت سازگار، بدون دستکاری.
  static const List<Mp3QuranReciter> fallbackReciters = kEveryAyahCatalog;

  /// برای سازگاری با کش قدیمی (ar.*)
  static const List<Mp3QuranReciter> attractiveReciters = kEveryAyahCatalog;

  /// Live reciter list — حالا فقط EveryAyah (تک‌سرور)؛ بدون ادغام alquran.cloud.
  static List<Mp3QuranReciter>? _cached;

  static Future<List<Mp3QuranReciter>> fetchReciters() async {
    if (_cached != null) return _cached!;
    // کش قدیمی اگر everyayah باشد معتبر است، اگر ar.* باشد منقضی
    final fromCache = await _loadCache();
    if (fromCache != null &&
        fromCache.isNotEmpty &&
        fromCache.any((r) => r.identifier.startsWith('everyayah:'))) {
      _cached = fromCache;
      return fromCache;
    }
    _cached = kEveryAyahCatalog;
    await _saveCache(kEveryAyahCatalog);
    return kEveryAyahCatalog;
  }

  /// Reciter with [identifier], or null when unknown.
  /// از کش قدیمی ar.* به everyayah: مهاجرت می‌کند.
  static Future<Mp3QuranReciter?> reciterById(String identifier) async {
    final list = await fetchReciters();
    for (final r in list) {
      if (r.identifier == identifier) return r;
    }
    final mapped = kEveryAyahFallback[identifier];
    if (mapped != null) {
      final everyId = 'everyayah:$mapped';
      for (final r in list) {
        if (r.identifier == everyId) return r;
      }
    }
    return null;
  }

  /// Remote whole-surah mp3 URL for [surah], or null when the reciter is
  /// unknown.
  static Future<String?> urlForSurah(String reciterId, int surah) async {
    final reciter = await reciterById(reciterId);
    if (reciter == null) return null;
    return reciter.surahUrl(surah);
  }

  /// Remote per-ayah mp3 URL — the exact file for [surah]:[verse], or null
  /// when the reciter is unknown.
  static Future<String?> urlForVerse(
      String reciterId, int surah, int verse) async {
    final reciter = await reciterById(reciterId);
    if (reciter == null) return null;
    return reciter.verseUrl(surah, verse);
  }

  static Future<bool> isCacheValid(File file) async {
    try {
      if (!await file.exists()) return false;
      if (await file.length() < 100) {
        try {
          await file.delete();
        } catch (e) {
          AppLogger.warning('Mp3Quran', 'file stat failed: $e');
        }
        return false;
      }
      final stat = await file.stat();
      final age = DateTime.now().difference(stat.modified);
      if (age > cacheMaxAge) {
        try {
          await file.delete();
        } catch (e) {
          AppLogger.warning('Mp3Quran', 'file stat failed: $e');
        }
        return false;
      }
      return true;
    } catch (e) {
      AppLogger.warning('Mp3Quran', 'offline check failed: $e');
      return false;
    }
  }

  /// Local cached mp3 path of one ayah for [reciterId], or null when not yet
  /// downloaded or expired (7 روز — مگر سوره دانلود صریح و «آفلاین دائم» باشد).
  static Future<String?> localCachedVersePath(
      String reciterId, int surah, int verse) async {
    final file = File(await localVersePath(reciterId, surah, verse));
    if (!await file.exists()) return null;
    if (await isMarkedOffline(reciterId, surah)) {
      // Explicitly downloaded: offline forever (size sanity only).
      if (await file.length() < 100) {
        try {
          await file.delete();
        } catch (e) {
          AppLogger.warning('Mp3Quran', 'resolve path failed: $e');
        }
        return null;
      }
      return file.path;
    }
    if (await isCacheValid(file)) return file.path;
    return null;
  }

  /// حذف فایل‌های کش قدیمی‌تر از 7 روز — به‌صورت best-effort در پس‌زمینه.
  /// سوره‌های دانلود صریح (offline-marked) هرگز لمس نمی‌شوند.
  static Future<void> cleanupExpiredCache() async {
    try {
      final dir = await contentDir();
      if (!await dir.exists()) return;
      // Offline marks, loaded once: `<sanitizedId>_<surah>` survivals whose
      // whole folder subtree is skipped by the sweeper.
      final keep = <String>{};
      try {
        final prefs = await SharedPreferences.getInstance();
        for (final k in prefs.getKeys()) {
          if (k.startsWith(_offlineMarkPrefix) && prefs.getInt(k) == 1) {
            keep.add(k.substring(_offlineMarkPrefix.length));
          }
        }
      } catch (e) {
        AppLogger.warning('Mp3Quran', 'dir prepare failed: $e');
      }
      final now = DateTime.now();
      final base = dir.path;
      await for (final entity in dir.list(recursive: true)) {
        if (entity is! File) continue;
        if (!entity.path.endsWith('.mp3')) continue;
        try {
          // path: <base>/<sanitizedId>/<SSS>/<AAA>.mp3 — marks store the
          // surah number unpadded, folders are zero-padded.
          final rel = p.relative(entity.path, from: base);
          final parts = p.split(rel);
          if (parts.length == 3) {
            final folderSurah = int.tryParse(parts[1]);
            if (folderSurah != null &&
                keep.contains('${parts[0]}_$folderSurah')) {
              continue;
            }
          }
          final stat = await entity.stat();
          if (now.difference(stat.modified) > cacheMaxAge) {
            await entity.delete();
          } else if (await entity.length() < 100) {
            await entity.delete();
          }
        } catch (e) {
          AppLogger.warning('Mp3Quran', 'file delete failed: $e');
        }
      }
    } catch (e) {
      AppLogger.warning('Mp3Quran', 'purge failed: $e');
    }
  }

  static String _sanitizeId(String id) => id.replaceAll(RegExp(r'[:/\\]'), '_');

  /// Expected local path of one ayah's mp3 (regardless of cache state).
  static Future<String> localVersePath(
      String reciterId, int surah, int verse) async {
    final dir = await contentDir();
    return p.join(
        dir.path,
        _sanitizeId(reciterId),
        surah.toString().padLeft(3, '0'),
        '${verse.toString().padLeft(3, '0')}.mp3');
  }

  /// Base folder holding the downloaded audio (`audio_mp3quran/`).
  static Future<Directory> contentDir() async {
    final root = await QuranStorage.contentDir();
    final dir = Directory(p.join(root.path, audioCacheDirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Whether every ayah of [surah] for [reciterId] is stored offline.
  ///
  /// Audit 9-D: the old auto-adoption marked ANY fully-cached surah as
  /// offline-forever — but mere PLAYBACK prefetches and caches verses
  /// into the same 7-day-expiry store, so listening through a surah once
  /// silently promoted every file out of the sweeper (the «کش خودکار
  /// پاک نمی‌شود» reports). Adoption now happens only when the files
  /// were explicitly downloaded; a complete-but-ephemeral set still
  /// reports as cached while it is young.
  static Future<bool> isSurahCached(String reciterId, int surah) async {
    final count = getVerseCount(surah);
    final marked = await isMarkedOffline(reciterId, surah);
    for (var v = 1; v <= count; v++) {
      final file = File(await localVersePath(reciterId, surah, v));
      final ok = marked
          ? (await file.exists() && await file.length() >= 100)
          : await isCacheValid(file);
      if (!ok) return false;
    }
    return true;
  }

  /// Downloads every ayah of [surah] for [reciterId] into the local cache.
  /// Skips already-cached verses. Throws on failure so callers can report.
  /// On success the surah is marked offline-forever (see registry above).
  static Future<void> downloadSurah(String reciterId, int surah) async {
    await downloadSurahRange(reciterId, surah, 1, getVerseCount(surah));
    await markSurahOffline(reciterId, surah);
  }

  /// Downloads the ayahs [fromVerse]..[toVerse] of [surah] for [reciterId]
  /// (a juz typically spans only part of its first/last surah). Skips
  /// already-cached verses; small files are fetched concurrently for speed.
  /// Marks the surah offline-forever only when the range covers it fully.
  static Future<void> downloadSurahRange(
      String reciterId, int surah, int fromVerse, int toVerse) async {
    final reciter = await reciterById(reciterId);
    if (reciter == null) throw StateError('قاری پیدا نشد');
    const pool = 12;
    var next = fromVerse;
    while (next <= toVerse) {
      final batch = <int>[];
      for (var i = 0; i < pool && next <= toVerse; i++) {
        batch.add(next++);
      }
      await Future.wait(batch.map((v) => _downloadVerse(reciter, surah, v)));
    }
    if (fromVerse <= 1 && toVerse >= getVerseCount(surah)) {
      await markSurahOffline(reciterId, surah);
    }
  }

  /// Whether an HTTP response actually carries MP3 audio (Audit 9-A).
  ///
  /// A 200 with an HTML/JSON error page (captive portal, CDN edge
  /// failure, rate-limit page) used to be written to the cache verbatim:
  /// it passed the `length() > 100` sanity check, so playback then
  /// failed forever on that ayah AND the expiry sweeper kept the file
  /// (fresh mtime). Response bodies starting with `<` or `{` are
  /// rejected as well, so servers that omit the header stay covered.
  static bool isPlausibleAudioResponse(
      int statusCode, String? contentType, List<int> body) {
    if (statusCode != 200) return false;
    final type = (contentType ?? '').toLowerCase();
    if (type.contains('text/') ||
        type.contains('json') ||
        type.contains('xml')) {
      return false;
    }
    if (body.length < 100) return false;
    if (body.isNotEmpty) {
      final b0 = body[0];
      // HTML tag / JSON object — never audio.
      if (b0 == 0x3C /* < */ || b0 == 0x7B /* { */) return false;
    }
    return true;
  }

  static Future<void> _downloadVerse(
      Mp3QuranReciter reciter, int surah, int verse) async {
    final path = await localVersePath(reciter.identifier, surah, verse);
    final file = File(path);
    if (await file.exists() && await file.length() > 100) return;
    Object? lastErr;
    for (final url in reciter.verseUrlsWithFallback(surah, verse)) {
      try {
        final response =
            await http.get(Uri.parse(url)).timeout(const Duration(minutes: 2));
        if (!isPlausibleAudioResponse(response.statusCode,
            response.headers['content-type'], response.bodyBytes)) {
          lastErr =
              StateError('دانلود صوت ناموفق بود (${response.statusCode}).');
          continue;
        }
        await file.parent.create(recursive: true);
        final tmp = File('$path.part');
        await tmp.writeAsBytes(response.bodyBytes, flush: true);
        if (await file.exists()) await file.delete();
        await tmp.rename(path);
        return;
      } catch (e) {
        AppLogger.warning('mp3quran_service', 'error: $e');
        lastErr = e;
        continue;
      }
    }
    throw lastErr ?? StateError('دانلود صوت ناموفق بود.');
  }

  /// Best-effort prefetch of ONE verse into the local cache. Never throws —
  /// used during playback so the next verse starts instantly instead of
  /// waiting for a fresh network buffer (the 5–10s gap between ayahs).
  static Future<void> prefetchVerse(
      String reciterId, int surah, int verse) async {
    try {
      if (verse < 1 || verse > getVerseCount(surah)) return;
      final reciter = await reciterById(reciterId);
      if (reciter == null) return;
      await _downloadVerse(reciter, surah, verse);
    } catch (e) {
      // Prefetch is opportunistic; playback falls back to streaming.
      AppLogger.warning('Mp3Quran', 'prefetch failed: $e');
    }
  }

  /// Number of surahs (fully cached) for [reciterId].
  static Future<int> countCachedSurahs(String reciterId) async {
    var count = 0;
    for (var s = 1; s <= 114; s++) {
      if (await isSurahCached(reciterId, s)) count++;
    }
    return count;
  }

  /// Deletes the cached audio of one [surah] for [reciterId]. No-op when
  /// nothing is cached. Always an explicit user action — talaawah files are
  /// never removed automatically (offline-marked surahs are skipped by the
  /// expiry sweeper). Clears the surah's offline mark as well.
  static Future<void> deleteSurah(String reciterId, int surah) async {
    try {
      final dir =
          Directory(p.dirname(await localVersePath(reciterId, surah, 1)));
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (e) {
      // Best-effort; a missing folder is already the desired state.
      AppLogger.warning('Mp3Quran', 'folder delete failed: $e');
    }
    await unmarkSurahOffline(reciterId, surah);
  }

  /// Deletes every cached file for [reciterId] (the whole offline talaawah).
  /// Clears the reciter's offline marks as well.
  static Future<void> deleteAllSurahs(String reciterId) async {
    try {
      final base = Directory(p.dirname(await localVersePath(reciterId, 1, 1)));
      if (await base.exists()) {
        await base.delete(recursive: true);
      }
    } catch (e) {
      AppLogger.warning('Mp3Quran', 'delete files failed: $e');
    }
    await unmarkAllOffline(reciterId);
  }

  /// Deletes every cached talaawah file for every reciter.
  static Future<void> deleteAllReciters() async {
    try {
      final dir = await contentDir();
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {
      AppLogger.warning('mp3quran_service', 'operation failed');
    }
  }

  // ── Parsing ───────────────────────────────────────────────────────────────

  /// Parses a legacy editions payload for migration tools.
  // ignore: unused_element
  static List<Mp3QuranReciter> _parseApiResponse(String body) {
    final json = jsonDecode(body);
    final data = json['data'];
    if (data is! List) return const [];
    final out = <Mp3QuranReciter>[];
    final seen = <String>{};
    for (final raw in data.whereType<Map<String, dynamic>>()) {
      final id = (raw['identifier'] as String?)?.trim() ?? '';
      if (id.isEmpty || id.endsWith('-2')) continue;
      final name = (raw['name'] as String?)?.trim() ?? '';
      if (name.isEmpty || !seen.add(id)) continue;
      out.add(Mp3QuranReciter(identifier: id, name: name));
    }
    // جذاب‌ها در صدر (درخواست کاربر: القطامی، الدوسری...) سپس الباقی الفبایی.
    final attractiveSet = attractiveReciters.map((e) => e.identifier).toSet();
    out.sort((a, b) {
      final aAtt = attractiveSet.contains(a.identifier);
      final bAtt = attractiveSet.contains(b.identifier);
      if (aAtt && !bAtt) return -1;
      if (!aAtt && bAtt) return 1;
      if (a.identifier == 'ar.alafasy' && !aAtt) return -1;
      if (b.identifier == 'ar.alafasy' && !bAtt) return 1;
      return a.name.compareTo(b.name);
    });
    return out;
  }

  static Future<void> _saveCache(List<Mp3QuranReciter> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cachePrefsKey,
          jsonEncode(list.map((r) => r.toJson()).toList(growable: false)));
    } catch (_) {
      // Cache is best-effort.
    }
  }

  static Future<List<Mp3QuranReciter>?> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(cachePrefsKey);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(Mp3QuranReciter.fromJson)
          .where((r) => r.identifier.isNotEmpty)
          .toList();
    } catch (_) {
      AppLogger.warning('mp3quran_service', 'operation failed');
      return null;
    }
  }
}

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'package:tawheeed/features/quran/data/quran_helpers.dart';
import 'package:tawheeed/features/quran/mushaf/quran_audio_download_service.dart';
import 'package:tawheeed/features/quran/services/mp3quran_service.dart';
import 'package:tawheeed/features/quran/mushaf/quran_translation_audio_controller.dart';
import 'package:tawheeed/features/quran/services/quran_storage.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Downloads the QuranEnc Persian translation audio (persian_ih) into the
/// local cache so translation playback works offline.
///
/// Files are stored under
/// `quran_content/audio_translation/persian_ih/{SSS}{AAA}.mp3`.
class QuranTranslationDownloadService {
  QuranTranslationDownloadService._();

  static final QuranTranslationDownloadService instance =
      QuranTranslationDownloadService._();

  static const String _cacheDirName = 'audio_translation';
  static const String _translationKey = 'persian_ih';

  /// The QuranEnc CDN rejects requests without a browser User-Agent
  /// (HTTP 403). The dart `http` client sends a Dart user-agent, so downloads
  /// must set a browser UA explicitly.
  static const Map<String, String> _headers = {
    'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0 Safari/537.36',
  };

  final ValueNotifier<QuranAudioDownloadState> state =
      ValueNotifier(const QuranAudioDownloadState());

  bool _cancel = false;

  // ── Public API ──────────────────────────────────────────────────────────

  Future<void> startSurah(int surah) async {
    if (state.value.running) return;
    _cancel = false;
    await _run(fromSurah: surah, toSurah: surah, wholeQuran: false);
  }

  Future<void> startAll() async {
    if (state.value.running) return;
    _cancel = false;
    await _run(fromSurah: 1, toSurah: 114, wholeQuran: true);
  }

  Future<void> startJuz(int juzNumber) async {
    if (state.value.running) return;
    _cancel = false;
    final ranges = juzVerseRanges(juzNumber);
    var total = 0;
    for (final e in ranges.entries) {
      total += e.value.$2 - e.value.$1 + 1;
    }
    state.value = QuranAudioDownloadState(
      running: true,
      surah: ranges.keys.first,
      total: total,
    );
    var done = 0;
    String? error;
    try {
      for (final e in ranges.entries) {
        if (_cancel) break;
        final count = e.value.$2 - e.value.$1 + 1;
        state.value = state.value.copyWith(surah: e.key, currentVerse: 0);
        try {
          await _downloadRange(e.key, e.value.$1, e.value.$2);
          done += count;
          state.value = state.value.copyWith(done: done, currentVerse: count);
        } catch (err) {
          AppLogger.warning(
              'quran_translation_download_service', 'error: $err');
          error = 'خطا در دانلود ترجمه صوتی؛ اتصال اینترنت را بررسی کنید.';
          break;
        }
      }
    } finally {
      state.value = state.value.copyWith(
        running: false,
        currentVerse: 0,
        error: error,
        cancelled: _cancel,
      );
    }
  }

  void cancel() => _cancel = true;

  /// Whether every ayah of [surah] is stored offline for translation.
  Future<bool> isSurahCached(int surah) async {
    try {
      final count = getVerseCount(surah);
      for (var v = 1; v <= count; v++) {
        final path = await localVersePath(surah, v);
        if (!await File(path).exists()) return false;
      }
      return true;
    } catch (_) {
      AppLogger.warning(
          'quran_translation_download_service', 'operation failed');
      return false;
    }
  }

  /// Deletes the cached translation audio of one [surah].
  Future<void> deleteSurah(int surah) async {
    try {
      final dir = Directory(p.dirname(await localVersePath(surah, 1)));
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {
      AppLogger.warning(
          'quran_translation_download_service', 'operation failed');
    }
  }

  /// Deletes every cached translation audio file.
  Future<void> deleteAll() async {
    try {
      final root = await QuranStorage.contentDir();
      final dir = Directory(p.join(root.path, _cacheDirName, _translationKey));
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {
      AppLogger.warning(
          'quran_translation_download_service', 'operation failed');
    }
  }

  /// Number of fully-cached surahs (translation audio).
  Future<int> countCachedSurahs() async {
    var count = 0;
    for (var s = 1; s <= 114; s++) {
      if (await isSurahCached(s)) count++;
    }
    return count;
  }

  /// In-flight downloads by `surah:verse`: playback and the background
  /// prefetch often ask for the same verse at the same moment (a tap on
  /// "next" while its prefetch is still downloading). Sharing one future
  /// avoids a double download and two concurrent writers on one file.
  static final Map<String, Future<String?>> _inflight = {};

  /// Downloads a single verse if it is missing and returns its local path
  /// (or null on failure). Used by the player so playback works even when
  /// the CDN blocks direct streaming.
  static Future<String?> ensureVerseDownloaded(int surah, int verse) {
    final key = '$surah:$verse';
    final existing = _inflight[key];
    if (existing != null) return existing;
    final fut = _downloadVerseFile(surah, verse);
    _inflight[key] = fut;
    return fut.whenComplete(() => _inflight.remove(key));
  }

  static Future<String?> _downloadVerseFile(int surah, int verse) async {
    final path = await localVersePath(surah, verse);
    if (await File(path).exists()) return path;
    final url = QuranTranslationAudioController.urlForVerse(surah, verse);
    try {
      final response = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(minutes: 2));
      // Audit 9-A: reject HTML/JSON error pages — a poisoned 200 used
      // to become a permanent broken cache file (see Mp3QuranService).
      if (!Mp3QuranService.isPlausibleAudioResponse(response.statusCode,
          response.headers['content-type'], response.bodyBytes)) {
        return null;
      }
      final f = File(path);
      await f.parent.create(recursive: true);
      await f.writeAsBytes(response.bodyBytes, flush: true);
      return path;
    } catch (_) {
      AppLogger.warning(
          'quran_translation_download_service', 'operation failed');
      return null;
    }
  }

  // ── Internal ────────────────────────────────────────────────────────────

  Future<void> _run({
    required int fromSurah,
    required int toSurah,
    required bool wholeQuran,
  }) async {
    var total = 0;
    for (var s = fromSurah; s <= toSurah; s++) {
      total += getVerseCount(s);
    }
    state.value = QuranAudioDownloadState(
      running: true,
      surah: fromSurah,
      total: total,
      wholeQuran: wholeQuran,
    );
    var done = 0;
    String? error;
    try {
      for (var s = fromSurah; s <= toSurah; s++) {
        if (_cancel) break;
        state.value = state.value.copyWith(surah: s, currentVerse: 0);
        try {
          final count = getVerseCount(s);
          await _downloadRange(s, 1, count);
          done += count;
          state.value = state.value.copyWith(done: done, currentVerse: count);
        } catch (e) {
          AppLogger.warning('quran_translation_download_service', 'error: $e');
          error = 'خطا در دانلود ترجمه صوتی؛ اتصال اینترنت را بررسی کنید.';
          break;
        }
      }
    } finally {
      state.value = state.value.copyWith(
        running: false,
        currentVerse: 0,
        error: error,
        cancelled: _cancel,
      );
    }
  }

  Future<void> _downloadRange(int surah, int fromVerse, int toVerse) async {
    const pool = 12;
    var next = fromVerse;
    while (next <= toVerse) {
      if (_cancel) return;
      final batch = <int>[];
      for (var i = 0; i < pool && next <= toVerse; i++) {
        batch.add(next++);
      }
      await Future.wait(batch.map((v) => _downloadVerse(surah, v)));
    }
  }

  Future<void> _downloadVerse(int surah, int verse) async {
    final path = await localVersePath(surah, verse);
    final file = File(path);
    if (await file.exists()) {
      try {
        if (await file.length() > 100) return;
      } catch (_) {
        AppLogger.warning(
            'quran_translation_download_service', 'operation failed');
      }
    }
    final url = QuranTranslationAudioController.urlForVerse(surah, verse);
    final response = await http
        .get(Uri.parse(url), headers: _headers)
        .timeout(const Duration(minutes: 2));
    if (response.statusCode != 200) {
      throw StateError('دانلود ترجمه ناموفق بود (${response.statusCode}).');
    }
    await file.parent.create(recursive: true);
    final tmp = File('$path.part');
    await tmp.writeAsBytes(response.bodyBytes, flush: true);
    if (await file.exists()) await file.delete();
    await tmp.rename(path);
  }

  // ── Path helpers ────────────────────────────────────────────────────────

  static Future<String> localVersePath(int surah, int verse) async {
    final root = await QuranStorage.contentDir();
    final dir = Directory(p.join(root.path, _cacheDirName, _translationKey));
    if (!await dir.exists()) await dir.create(recursive: true);
    final fileKey =
        '${surah.toString().padLeft(3, '0')}${verse.toString().padLeft(3, '0')}';
    return p.join(dir.path, '$fileKey.mp3');
  }

  static Future<String?> localCachedVersePath(int surah, int verse) async {
    final path = await localVersePath(surah, verse);
    return await File(path).exists() ? path : null;
  }
}

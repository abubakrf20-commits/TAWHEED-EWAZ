import 'package:flutter/foundation.dart';

import 'package:tawheeed/features/quran/data/quran_helpers.dart';
import 'package:tawheeed/features/quran/services/mp3quran_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Live state of an audio (talaawah) download run for the current reciter.
///
/// Audio is stored per-ayah (one small mp3 per verse), so a run downloads
/// verse files and progress counts verses.
@immutable
class QuranAudioDownloadState {
  final bool running;

  /// Reciter whose files are being downloaded (CDN identifier).
  final String reciterId;

  /// Surah currently being processed (0 when idle).
  final int surah;

  /// Verse files finished so far.
  final int done;

  /// Total verse files to download in this run.
  final int total;

  /// 1-based verse currently downloading inside [surah].
  final int currentVerse;

  final String? error;
  final bool cancelled;

  /// True when this run covers the whole Quran (not a single surah).
  final bool wholeQuran;

  const QuranAudioDownloadState({
    this.running = false,
    this.reciterId = '',
    this.surah = 0,
    this.done = 0,
    this.total = 0,
    this.currentVerse = 0,
    this.error,
    this.cancelled = false,
    this.wholeQuran = false,
  });

  QuranAudioDownloadState copyWith({
    bool? running,
    String? reciterId,
    int? surah,
    int? done,
    int? total,
    int? currentVerse,
    String? error,
    bool clearError = false,
    bool? cancelled,
    bool? wholeQuran,
  }) {
    return QuranAudioDownloadState(
      running: running ?? this.running,
      reciterId: reciterId ?? this.reciterId,
      surah: surah ?? this.surah,
      done: done ?? this.done,
      total: total ?? this.total,
      currentVerse: currentVerse ?? this.currentVerse,
      error: clearError ? null : (error ?? this.error),
      cancelled: cancelled ?? this.cancelled,
      wholeQuran: wholeQuran ?? this.wholeQuran,
    );
  }
}

/// Downloads the current reciter's per-ayah mp3s into the local cache so
/// playback works offline. [Mp3QuranService.downloadSurah] stores each verse
/// under `audio_mp3quran/{identifier}/{surah:03}/{ayah:03}.mp3`, which the
/// player picks up automatically — offline playback is as exact as online.
class QuranAudioDownloadService {
  QuranAudioDownloadService._();

  static final QuranAudioDownloadService instance =
      QuranAudioDownloadService._();

  final ValueNotifier<QuranAudioDownloadState> state =
      ValueNotifier(const QuranAudioDownloadState());

  bool _cancel = false;

  Future<void> startSurah(String reciterId, int surah) async {
    if (state.value.running) return;
    _cancel = false;
    await _run(
      reciterId,
      fromSurah: surah,
      toSurah: surah,
      wholeQuran: false,
    );
  }

  Future<void> startAll(String reciterId) async {
    if (state.value.running) return;
    _cancel = false;
    await _run(
      reciterId,
      fromSurah: 1,
      toSurah: 114,
      wholeQuran: true,
    );
  }

  /// Downloads exactly the ayahs that belong to [juzNumber] (1-30) for
  /// [reciterId] — the juz's first/last surah are downloaded only up to the
  /// juz boundary.
  Future<void> startJuz(String reciterId, int juzNumber) async {
    if (state.value.running) return;
    _cancel = false;
    final ranges = juzVerseRanges(juzNumber);
    var total = 0;
    for (final e in ranges.entries) {
      total += e.value.$2 - e.value.$1 + 1;
    }
    state.value = QuranAudioDownloadState(
      running: true,
      reciterId: reciterId,
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
          await Mp3QuranService.downloadSurahRange(
              reciterId, e.key, e.value.$1, e.value.$2);
          done += count;
          state.value = state.value.copyWith(done: done, currentVerse: count);
        } catch (err) {
          AppLogger.warning('quran_audio_download_service', 'error: $err');
          error = _friendly(err);
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

  Future<void> _run(
    String reciterId, {
    required int fromSurah,
    required int toSurah,
    required bool wholeQuran,
  }) async {
    // Total verse files across the covered surahs.
    var total = 0;
    for (var s = fromSurah; s <= toSurah; s++) {
      total += getVerseCount(s);
    }
    state.value = QuranAudioDownloadState(
      running: true,
      reciterId: reciterId,
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
          await Mp3QuranService.downloadSurah(reciterId, s);
          done += getVerseCount(s);
          state.value =
              state.value.copyWith(done: done, currentVerse: getVerseCount(s));
        } catch (e) {
          AppLogger.warning('quran_audio_download_service', 'error: $e');
          error = _friendly(e);
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

  /// Whether every ayah of [surah] for [reciterId] is stored offline.
  Future<bool> isSurahCached(String reciterId, int surah) async {
    try {
      return await Mp3QuranService.isSurahCached(reciterId, surah);
    } catch (_) {
      AppLogger.warning('quran_audio_download_service', 'operation failed');
      return false;
    }
  }

  /// Number of fully-cached surahs for [reciterId].
  Future<int> countCachedSurahs(String reciterId) async {
    try {
      return await Mp3QuranService.countCachedSurahs(reciterId);
    } catch (_) {
      AppLogger.warning('quran_audio_download_service', 'operation failed');
      return 0;
    }
  }

  String _friendly(Object e) {
    return 'خطا در دانلود تلاوت؛ اتصال اینترنت را بررسی کنید.';
  }
}

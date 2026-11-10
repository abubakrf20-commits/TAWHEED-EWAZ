import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:tawheeed/features/quran/mushaf/qcf4/qcf4_config.dart';
import 'package:tawheeed/features/quran/mushaf/qcf4/qcf4_data_store.dart';
import 'package:tawheeed/features/quran/mushaf/qcf4/qcf4_font_loader.dart';
import 'package:tawheeed/features/quran/services/quran_storage.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Live state of a full-mushaf QCF4 pre-download.
@immutable
class Qcf4DownloadState {
  final bool running;
  final int done;
  final int total;
  final String currentItem;
  final String requestedBy;
  final String? error;
  final bool cancelled;

  /// Whether the whole mushaf (604 pages + all fonts) is already on disk.
  /// Published by [refreshFullyDownloaded] / [isFullyDownloaded] so the UI
  /// can disable the download button on a fresh app start.
  final bool fullyDownloaded;

  /// Estimated size of the whole download (TTF fonts + page JSON + meta).
  final double sizeMB;

  /// Pages done so far (of [Qcf4Config.pageCount]) — shown separately from
  /// fonts so the UI can break progress down by asset type.
  final int pagesDone;

  /// Fonts done so far (of [_Qcf4DownloadManagerState]-known 48).
  final int fontsDone;

  /// Items that failed in the last run (e.g. `صفحه 042`, `فونت QCF4_Hafs_03`).
  /// A re-run resumes from cache, so these are retried rather than restarted.
  final List<String> failedItems;

  const Qcf4DownloadState({
    this.running = false,
    this.done = 0,
    this.total = 0,
    this.currentItem = '',
    this.requestedBy = 'user',
    this.error,
    this.cancelled = false,
    this.fullyDownloaded = false,
    this.sizeMB = 125.0,
    this.pagesDone = 0,
    this.fontsDone = 0,
    this.failedItems = const [],
  });

  Qcf4DownloadState copyWith({
    bool? running,
    int? done,
    int? total,
    String? currentItem,
    String? requestedBy,
    String? error,
    bool clearError = false,
    bool? cancelled,
    bool? fullyDownloaded,
    double? sizeMB,
    int? pagesDone,
    int? fontsDone,
    List<String>? failedItems,
  }) {
    return Qcf4DownloadState(
      running: running ?? this.running,
      done: done ?? this.done,
      total: total ?? this.total,
      currentItem: currentItem ?? this.currentItem,
      requestedBy: requestedBy ?? this.requestedBy,
      error: clearError ? null : (error ?? this.error),
      cancelled: cancelled ?? this.cancelled,
      fullyDownloaded: fullyDownloaded ?? this.fullyDownloaded,
      sizeMB: sizeMB ?? this.sizeMB,
      pagesDone: pagesDone ?? this.pagesDone,
      fontsDone: fontsDone ?? this.fontsDone,
      failedItems: failedItems ?? this.failedItems,
    );
  }
}

/// Downloads the whole QCF4 mushaf (all 604 page JSON files + all 48 TTF
/// fonts ≈ 90+ MB) so the live-font reader works fully offline.
///
/// JSON pages are written straight into [Qcf4DataStore]'s cache; fonts are
/// written as TTF and registered by [Qcf4FontLoader].
class Qcf4DownloadManager {
  Qcf4DownloadManager();

  static final Qcf4DownloadManager instance = Qcf4DownloadManager();

  final ValueNotifier<Qcf4DownloadState> state =
      ValueNotifier(const Qcf4DownloadState());

  bool _cancel = false;

  /// The in-flight [_run] future, so [clearAllDownloaded] can await the loop's
  /// exit before deleting files instead of racing it.
  Future<void>? _runFuture;

  bool get isRunning => state.value.running;

  /// Cancel an in-flight download.
  void cancel() => _cancel = true;

  /// Whether every page JSON + every font is already cached, so the reader is
  /// fully usable offline and a re-download would be a no-op.
  Future<bool> isFullyDownloaded() async {
    final store = Qcf4DataStore.instance;
    for (var page = 1; page <= Qcf4Config.pageCount; page++) {
      if (!await store.isPageCached(page)) return false;
    }
    final root = await QuranStorage.contentDir();
    final fontsDir =
        Directory(p.join(root.path, Qcf4Config.cacheDirName, 'fonts'));
    if (!await fontsDir.exists()) return false;
    for (final family in _allFontFamilies) {
      final ttf =
          File(p.join(fontsDir.path, Qcf4Config.fontTtfFileName(family)));
      if (!(await ttf.exists())) return false;
    }
    return true;
  }

  /// Computes [isFullyDownloaded] and publishes the result on [state] so the
  /// download UI reflects an already-complete library without a running job.
  Future<void> refreshFullyDownloaded() async {
    final done = await isFullyDownloaded();
    state.value = state.value.copyWith(fullyDownloaded: done);
  }

  /// Wipe every downloaded QCF4 page JSON + TTF font from disk and reset the
  /// download state so the UI returns to "not downloaded". If a download is
  /// in flight it is cancelled first and awaited, so files are never deleted
  /// while the loop is still writing them.
  Future<void> clearAllDownloaded() async {
    if (isRunning) {
      cancel();
      try {
        await _runFuture;
      } catch (_) {
        AppLogger.warning('qcf4_download_manager', 'operation failed');
      }
    }
    await Qcf4DataStore.instance.clearCache();
    await Qcf4FontLoader.instance.clearAll();
    state.value = Qcf4DownloadState(
      total: Qcf4Config.pageCount + Qcf4Config.hafsFontCount + 1,
      sizeMB: state.value.sizeMB,
    );
  }

  /// All font families in download order (QBSML header font + 47 Hafs).
  static List<String> get _allFontFamilies => <String>[
        Qcf4Config.qbsmlFontFamily,
        for (var i = 1; i <= Qcf4Config.hafsFontCount; i++)
          'QCF4_Hafs_${i.toString().padLeft(2, '0')}',
      ];

  /// Kick off a full download. Returns immediately; progress is published on
  /// [state]. Restarts resume from what is already cached instead of
  /// re-downloading everything, and clears prior per-font failures so nothing
  /// stays permanently borked for the rest of the process.
  void download({String requestedBy = 'user'}) {
    if (isRunning) return;
    _cancel = false;
    Qcf4FontLoader.instance.clearFailed();
    // ignore: discarded_futures
    _runFuture = _run(requestedBy);
  }

  Future<void> _run(String requestedBy) async {
    state.value = Qcf4DownloadState(
      running: true,
      total: Qcf4Config.pageCount + Qcf4Config.hafsFontCount + 1,
      requestedBy: requestedBy,
      sizeMB: state.value.sizeMB,
    );

    final store = Qcf4DataStore.instance;
    final root = await QuranStorage.contentDir();
    final fontsDir =
        Directory(p.join(root.path, Qcf4Config.cacheDirName, 'fonts'));
    if (!await fontsDir.exists()) await fontsDir.create(recursive: true);
    // Audit 3.6: sweep stale .part siblings from interrupted writes —
    // the atomic-rename scheme never leaves them live, but a kill between
    // writeAsBytes and rename can, and they would only waste disk.
    try {
      await for (final e in fontsDir.list()) {
        if (e is File && e.path.endsWith('.part')) await e.delete();
      }
    } catch (e) {
      AppLogger.info('qcf4_download', 'part sweep failed: $e');
    }

    var done = 0;
    var pagesDone = 0;
    var fontsDone = 0;
    // A single slow item no longer aborts the whole run: failures are
    // collected and reported at the end, and a re-run resumes from cache.
    final failed = <String>[];
    try {
      // 1) Page JSON files — cached pages are skipped instantly, so a
      //    restart after a network stall resumes instead of re-downloading.
      for (var page = 1; page <= Qcf4Config.pageCount; page++) {
        if (_cancel) {
          _finish(cancelled: true);
          return;
        }
        final label = 'صفحه ${page.toString().padLeft(3, '0')}';
        state.value = state.value.copyWith(
          done: done,
          pagesDone: pagesDone,
          fontsDone: fontsDone,
          currentItem: label,
        );
        final ok = await _downloadPage(store, page);
        if (_cancel) {
          _finish(cancelled: true);
          return;
        }
        if (!ok) {
          failed.add(label);
          continue;
        }
        done++;
        pagesDone++;
      }

      // 2) Fonts (QBSML + 47 Hafs) — already-registered fonts are skipped.
      final families = _allFontFamilies;
      for (final family in families) {
        if (_cancel) {
          _finish(cancelled: true);
          return;
        }
        if (Qcf4FontLoader.instance.isLoaded(family)) {
          done++;
          fontsDone++;
          continue;
        }
        final label = 'فونت $family';
        state.value = state.value.copyWith(
          done: done,
          pagesDone: pagesDone,
          fontsDone: fontsDone,
          currentItem: label,
        );
        final ok = await _downloadFont(store, fontsDir, family);
        if (_cancel) {
          _finish(cancelled: true);
          return;
        }
        if (!ok) {
          failed.add(label);
          continue;
        }
        done++;
        fontsDone++;
      }
      if (failed.isEmpty) {
        _finish();
      } else {
        final first = failed.first;
        final rest =
            failed.length > 1 ? ' و ${failed.length - 1} مورد دیگر' : '';
        _finish(
          error:
              'دریافت $first$rest ناموفق بود؛ با شروع مجدد ادامه دانلود از سر گرفته می‌شود.',
          failedItems: failed,
        );
      }
    } catch (e) {
      AppLogger.info('qcf4_download', 'download failed: $e');
      _finish(error: 'دانلود کامل نشد؛ با شروع مجدد از همان‌جا ادامه می‌یابد.');
    }
  }

  /// Fetch one page JSON with a few quick retries so a single slow/stalled
  /// request does not silently kill the whole 56 MB download.
  Future<bool> _downloadPage(Qcf4DataStore store, int page) async {
    final res = await store.loadPage(page);
    return res is Qcf4PageLoaded;
  }

  /// Fetch one font with retries. The font loader itself downloads + registers
  /// the TTF; here we only isolate failures so we can resume later.
  Future<bool> _downloadFont(
      Qcf4DataStore store, Directory fontsDir, String family) async {
    return Qcf4FontLoader.instance.ensure(family);
  }

  void _finish(
      {bool cancelled = false, String? error, List<String>? failedItems}) {
    state.value = state.value.copyWith(
      running: false,
      cancelled: cancelled,
      error: error,
      failedItems: failedItems ?? const [],
      // A clean (non-cancelled, non-errored) run means every page + font is on
      // disk, so the UI flips to "ready" immediately instead of waiting for the
      // next app start to recompute it.
      fullyDownloaded: (!cancelled && error == null),
    );
    _cancel = false;
    _runFuture = null;
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

import 'package:tawheeed/features/quran/services/quran_storage.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Reads a hosted verse-by-verse translation file.
///
/// Every translation the catalog ships — the Persian one and the Sorani Kurdish
/// ones — has the same contract: an array of `{"surah": n, "verse": n,
/// "text": "..."}` rows, 6236 entries. So one reader keyed by file name serves
/// them all instead of a class per language. Each file is parsed once per run
/// into per-surah lists sorted by verse, which makes every lookup a binary
/// search; ~1.8 MB of text per translation staying resident is fine.
class QuranTranslationReader {
  QuranTranslationReader._();

  /// The one translation bundled as an asset, so Persian reads offline out of
  /// the box. Every other file has to be downloaded first.
  static const String persianFileName = 'persian_translation.json';

  static final Map<String, Future<Map<int, List<({int verse, String text})>>>>
      _indexes = {};

  /// Whether [fileName] can answer without a download.
  static bool isBundled(String fileName) => fileName == persianFileName;

  /// True when [fileName] is readable now: downloaded, or bundled.
  ///
  /// The bundled check runs FIRST and without IO — a bundled file is
  /// available by definition, and answering it synchronously keeps callers
  /// (the share picker) usable where disk probes cannot complete (the
  /// widget tests' fake-async zone).
  static Future<bool> isAvailable(String fileName) async {
    if (isBundled(fileName)) return true;
    return await _downloadedFile(fileName) != null;
  }

  /// Drop the parsed copy of [fileName] — called when the file is deleted or
  /// replaced so the next read starts from scratch.
  static void evict(String fileName) => _indexes.remove(fileName);

  static Future<File?> _downloadedFile(String fileName) async {
    final file = File(p.join((await QuranStorage.contentDir()).path, fileName));
    return (await file.exists() && await file.length() > 0) ? file : null;
  }

  static Future<Map<int, List<({int verse, String text})>>> _indexed(
      String fileName) {
    final cached = _indexes[fileName];
    if (cached != null) return cached;
    final loaded = _load(fileName);
    _indexes[fileName] = loaded;
    // An empty result means "not downloaded yet", not "this file is empty", so
    // it must not be memoized — the read after a download has to see the data.
    loaded.then((index) {
      // Only drop the entry if it is still THIS load: a download that landed
      // meanwhile may already have replaced it with a populated future, and
      // removing that one would throw the fresh index away.
      if (index.isEmpty && identical(_indexes[fileName], loaded)) {
        _indexes.remove(fileName);
      }
    });
    return loaded;
  }

  static Future<Map<int, List<({int verse, String text})>>> _load(
      String fileName) async {
    final raw = await _rawContent(fileName);
    if (raw == null) return const {};
    try {
      return buildIndex(jsonDecode(raw) as List<dynamic>);
    } catch (e) {
      AppLogger.warning(
          'QuranTranslationReader', 'Failed to index $fileName: $e');
      return const {};
    }
  }

  /// Raw translation JSON: the downloaded copy when present AND valid,
  /// otherwise the bundled asset (only the Persian file has one). A corrupt
  /// download is quarantined (renamed aside) so it can never shadow the good
  /// asset again; a file with no asset behind it is simply not readable yet.
  static Future<String?> _rawContent(String fileName) async {
    final file = await _downloadedFile(fileName);
    if (file != null) {
      final path = file.path;
      try {
        final content = await file.readAsString();
        if (_looksValid(content, fileName)) return content;
        try {
          await file
              .rename('$path.bad.${DateTime.now().millisecondsSinceEpoch}');
        } catch (_) {
          AppLogger.warning(
              'QuranTranslationReader', 'could not quarantine $path');
        }
        AppLogger.warning('QuranTranslationReader',
            '$fileName failed validation; quarantined the downloaded copy');
      } catch (e) {
        AppLogger.warning(
            'QuranTranslationReader', '$fileName unreadable: $e');
      }
    }
    if (isBundled(fileName)) {
      return rootBundle.loadString('assets/$fileName');
    }
    return null;
  }

  /// Structural sanity of a translation payload: a full 6236-row array with a
  /// non-empty Ayat al-Kursi (2:255). Anything less is a truncated/corrupt
  /// download, not a translation. The check is language-blind — all three
  /// hosted translations pass it (6235, 6236, 6236 rows).
  static bool _looksValid(String content, String fileName) {
    try {
      final data = jsonDecode(content) as List<dynamic>;
      if (data.length < 6200) return false;
      for (final e in data) {
        final m = e as Map<String, dynamic>;
        if (m['surah'] == 2 && m['verse'] == 255) {
          final t = m['text'] as String?;
          return t != null && t.trim().isNotEmpty;
        }
      }
      return false;
    } catch (_) {
      AppLogger.warning(
          'QuranTranslationReader', 'validation failed for $fileName');
      return false;
    }
  }

  /// Pure index builder: `[{surah, verse, text}]` -> per-surah lists sorted by
  /// verse. Malformed rows are skipped (never wipe the whole index because of
  /// one bad row). Exposed for unit testing.
  static Map<int, List<({int verse, String text})>> buildIndex(
      List<dynamic> data) {
    final index = <int, List<({int verse, String text})>>{};
    for (final e in data) {
      try {
        final m = e as Map<String, dynamic>;
        final surah = (m['surah'] as num?)?.toInt();
        final verse = (m['verse'] as num?)?.toInt();
        final text = m['text'] as String? ?? '';
        if (surah == null ||
            verse == null ||
            surah < 1 ||
            surah > 114 ||
            verse < 1) {
          continue;
        }
        index.putIfAbsent(surah, () => []).add((verse: verse, text: text));
      } catch (_) {
        AppLogger.warning('QuranTranslationReader', 'skipped a bad row');
        continue;
      }
    }
    for (final list in index.values) {
      list.sort((a, b) => a.verse.compareTo(b.verse));
    }
    return index;
  }

  /// First entry whose verse is >= [verse]. Exposed so the binary-search
  /// contract is testable — a translation file may legitimately miss a row
  /// (the Kurdish host does), and a miss must read as `null`, never as the
  /// neighbouring verse's text.
  @visibleForTesting
  static int lowerBound(List<({int verse, String text})> list, int verse) {
    var lo = 0, hi = list.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (list[mid].verse < verse) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  /// Translation text for one ayah. `null` when the file is not readable yet
  /// or the ayah has no entry (a hosted file can legitimately miss a row).
  static Future<String?> getTranslation(
      String fileName, int surah, int verse) async {
    try {
      final list = (await _indexed(fileName))[surah];
      if (list == null || list.isEmpty) return null;
      final i = lowerBound(list, verse);
      if (i < list.length && list[i].verse == verse) return list[i].text;
      return null;
    } catch (e) {
      AppLogger.warning(
          'QuranTranslationReader', 'getTranslation failed: $e');
      return null;
    }
  }

  /// Translations for a verse range (verse number -> text).
  static Future<Map<int, String>> getTranslationsForRange(
    String fileName,
    int surah,
    int startVerse,
    int endVerse,
  ) async {
    try {
      final list = (await _indexed(fileName))[surah];
      if (list == null || list.isEmpty) return {};
      final from = lowerBound(list, startVerse);
      final map = <int, String>{};
      for (var i = from; i < list.length; i++) {
        if (list[i].verse > endVerse) break;
        map[list[i].verse] = list[i].text;
      }
      return map;
    } catch (e) {
      AppLogger.warning(
          'QuranTranslationReader', 'getTranslationsForRange failed: $e');
      return {};
    }
  }
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:tawheeed/features/quran/api/quran_api_config.dart';
import 'package:tawheeed/features/quran/services/content_provenance.dart';
import 'package:tawheeed/features/quran/services/quran_storage.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Download and extraction limits for hosted content (audit SEC M5).
///
/// The catalog is remote input, so both the transferred bytes and the
/// decompressed result are capped: a hostile or corrupt `.gz` that expands to
/// gigabytes used to be expanded in full inside an isolate and kill the app.
class QuranContentLimits {
  const QuranContentLimits._();

  /// Largest catalog JSON accepted.
  static const int maxCatalogBytes = 1 << 20; // 1 MiB

  /// Largest compressed transfer for a single content file.
  static const int maxDownloadBytes = 96 << 20; // 96 MiB

  /// Largest decompressed content file.
  static const int maxDecompressedBytes = 512 << 20; // 512 MiB
}

/// Thrown when remote content breaks a [QuranContentLimits] bound.
class QuranContentLimitException implements Exception {
  final String message;
  const QuranContentLimitException(this.message);
  @override
  String toString() => message;
}

/// Whether [name] is a plain, safe file name for hosted content.
///
/// The catalog is fetched over the network, and its `fileName` is joined onto
/// the content directory and turned into a request URL. Anything with a path
/// separator, a parent reference, a scheme or a host could therefore write
/// outside the content dir (`../../..`) or redirect the download.
bool isSafeContentFileName(String name) {
  if (name.isEmpty || name.length > 128) return false;
  if (name == '.' || name == '..') return false;
  if (name.contains('/') || name.contains('\\')) return false;
  if (name.contains(':')) return false;
  if (name.startsWith('.')) return false;
  if (name.contains('..')) return false;
  if (name.trim() != name) return false;
  // Whitespace anywhere: the name is interpolated into a request URL, where a
  // space needs escaping and a name we cannot escape safely is a bug in the
  // catalog, not something to accommodate.
  for (final unit in name.codeUnits) {
    if (unit == 0x20 || unit == 0x09) return false;
  }
  // Reserved URL characters: the same name is interpolated into a request URL,
  // where `?`/`#` would silently truncate the path and rewrite the query.
  if (name.contains('?') ||
      name.contains('#') ||
      name.contains('&') ||
      name.contains('=') ||
      name.contains('%') ||
      name.contains('+')) {
    return false;
  }
  // Control characters and NUL are never legitimate here.
  for (final unit in name.codeUnits) {
    if (unit < 0x20 || unit == 0x7f) return false;
  }
  return true;
}

/// Whether [name] is a safe *remote* name: a safe file name, optionally with
/// the `.gz` suffix the catalog adds for compressed entries.
bool isSafeContentRemoteName(String name) {
  if (isSafeContentFileName(name)) return true;
  if (name.endsWith('.gz')) {
    return isSafeContentFileName(name.substring(0, name.length - 3));
  }
  return false;
}

/// Decompresses [bytes], aborting as soon as the output passes
/// [QuranContentLimits.maxDecompressedBytes].
///
/// The limit is enforced *while* inflating, not after: `gzip.decode` builds
/// the whole output in memory first, so a few-KB bomb can allocate gigabytes
/// before any size check runs. Runs inside an isolate via [compute], which is
/// why this is a top-level function.
List<int> _gunzipBytes(List<int> bytes) =>
    gunzipBounded(bytes, QuranContentLimits.maxDecompressedBytes);

/// Inflates [bytes], refusing to produce more than [limit] output bytes.
///
/// Exposed for tests so the cap can be exercised with a small limit instead of
/// allocating the full production ceiling.
@visibleForTesting
List<int> gunzipBounded(List<int> bytes, int limit) {
  if (bytes.length > QuranContentLimits.maxDownloadBytes) {
    throw const QuranContentLimitException(
        'compressed content exceeds the size limit');
  }
  final sink = _CappedBytesSink(limit);
  GZipCodec().decoder.startChunkedConversion(sink).add(bytes);
  return sink.takeBytes();
}

/// A [ByteConversionSink] that throws once more than [limit] bytes are written.
class _CappedBytesSink extends ByteConversionSink {
  _CappedBytesSink(this.limit);

  final int limit;
  final BytesBuilder _builder = BytesBuilder(copy: false);
  int _written = 0;

  @override
  void add(List<int> chunk) {
    _written += chunk.length;
    if (_written > limit) {
      throw const QuranContentLimitException(
          'decompressed content exceeds the size limit');
    }
    _builder.add(chunk);
  }

  @override
  void addSlice(List<int> bytes, int start, int end, bool isLast) =>
      add(bytes.sublist(start, end));

  @override
  void close() {}

  List<int> takeBytes() => _builder.takeBytes();
}

/// A content file (a translation or a tafsir) that can be downloaded from
/// the app owner's GitHub-hosted catalog.
class QuranContentFile {
  final String id;
  final String type; // 'translation' | 'tafsir'
  final String name;
  final String fileName;
  final double sizeMB;

  /// When true the hosted file is `fileName + '.gz'` (gzip) and the app
  /// decompresses it to `fileName` on download. This cuts download traffic by
  /// ~70-80% for the tafsir databases (Persian text gzips extremely well).
  final bool compressed;

  /// Content language code (`'fa'` | `'ar'` | `'ku'`) shown as a badge in the
  /// content sheet. Null = unknown (no badge).
  final String? lang;

  const QuranContentFile({
    required this.id,
    required this.type,
    required this.name,
    required this.fileName,
    required this.sizeMB,
    this.compressed = false,
    this.lang,
  });

  bool get isTafsir => type == 'tafsir';
  bool get isTranslation => type == 'translation';

  /// Persian label for [lang] — empty when unknown.
  String get langLabel => switch (lang) {
        'fa' => 'فارسی',
        'ar' => 'عربی',
        'ku' => 'کوردی',
        _ => '',
      };

  /// Name of the file actually hosted on GitHub (the `.gz` when compressed).
  String get remoteName => compressed ? '$fileName.gz' : fileName;

  factory QuranContentFile.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final type = json['type'] as String? ?? '';
    final fileName = json['fileName'] as String? ?? '';
    // Remote input: a *present* fileName must be a plain name before it can
    // reach the filesystem or a request URL. An absent one stays tolerated
    // (the entry is simply not downloadable and is dropped by the catalog).
    if (fileName.isNotEmpty && !isSafeContentFileName(fileName)) {
      throw const FormatException('unsafe content fileName in catalog');
    }
    return QuranContentFile(
      id: id,
      type: type,
      name: localizedName(
        id: id,
        fileName: fileName,
        fallback: json['name'] as String? ?? '',
      ),
      fileName: fileName,
      sizeMB: (json['sizeMB'] as num?)?.toDouble() ?? 0,
      compressed: json['compressed'] as bool? ?? false,
      lang: json['lang'] as String?,
    );
  }

  /// Persian display name for a catalog entry, resolved from its stable id /
  /// file name only — never from [QuranContentFile.type], which cannot tell
  /// one translation's language from another.
  static String localizedName({
    required String id,
    required String fileName,
    required String fallback,
  }) {
    // The Persian translation has one fixed reading (its hosted file carries no
    // author metadata), but the label must NOT be keyed on `type`: the catalog
    // now ships Kurdish translations too, and a type-wide branch would rename
    // them «ترجمهٔ فارسی».
    if (id == 'persian_translation' ||
        fileName == 'persian_translation.json') {
      return 'ترجمهٔ فارسی — سایت اسلام هاوس';
    }
    const names = <String, String>{
      'mokhtasar_fa': 'المختصر فی التفسیر (فارسی)',
      'tafsir_noor': 'تفسیر نور — مصطفی خرمدل',
      'tafsir_anwar': 'انوار القرآن — عبدالرئوف مخلص',
      'tafsir_rastin': 'تفسیر راستین — السعدی',
      'safwa_tafasir': 'صفوة التفاسير — الصابوني',
      'fath_qadir': 'فتح القدير — الشوكاني',
      'mokhtasar_ibn_kathir': 'مختصر تفسير ابن كثير — الصابوني',
      'baghawi': 'معالم التنزيل — البغوي',
      'asbab_nuzul': 'أسباب النزول — الواحدي',
      'adwa_albayan': 'أضواء البيان — الشنقيطي',
      'baydawi': 'أنوار التنزيل — البيضاوي',
      'irab_alquran': 'إعراب القرآن',
      'tasheel': 'التسهيل لعلوم التنزيل — ابن جزي',
      'tahrir_ashur': 'تحرير المعنى — ابن عاشور',
      'jalalain': 'تفسير الجلالين — المحلي والسيوطي',
      'ibn_kathir': 'تفسير القرآن العظيم — ابن كثير',
      'tabari': 'جامع البيان — الطبري',
      // Sorani Kurdish. These four carry no author metadata in the file, so the
      // wording is read off the hosted name; each id equals the normalized file
      // basename, so `TafsirDbInfo.localizedNameForFile` resolves identically.
      // Exact `names` hits are checked BEFORE the [aliases] scan below — the
      // `'mokhtasar'` alias would otherwise rename `kurdish-mokhtasar` to the
      // Persian المختصر.
      'kurd_tafsir_rebar': 'تفسیر کوردی — ڕێبەر',
      'kurdish_mokhtasar': 'تفسیر کوردی — مختصر',
      'ku_burhan_muhammad_simple': 'ترجمهٔ کوردی — برهان محمد',
      'muhammad_saleh_bamoki_simple': 'ترجمهٔ کوردی — محمد صالح باموکی',
    };
    final normalizedId =
        id.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    if (names.containsKey(id)) return names[id] ?? '';
    if (names.containsKey(normalizedId)) return names[normalizedId] ?? '';

    // Older manifests used English ids or filenames (for example
    // `tasheel.db`), which leaked into the Arabic tafsir picker. Match the
    // stable part of the id/filename before falling back to remote metadata.
    final source =
        '$normalizedId ${fileName.toLowerCase()} ${fallback.toLowerCase()}';
    const aliases = <String, String>{
      'mokhtasar': 'المختصر فی التفسیر (فارسی)',
      'tasheel': 'التسهيل لعلوم التنزيل — ابن جزي',
      'tashil': 'التسهيل لعلوم التنزيل — ابن جزي',
      'noor': 'تفسیر نور — مصطفی خرمدل',
      'anwar': 'انوار القرآن — عبدالرئوف مخلص',
      'rastin': 'تفسیر راستین — السعدی',
      'jalalain': 'تفسير الجلالين — المحلي والسيوطي',
      'ibn_kathir': 'تفسير القرآن العظيم — ابن كثير',
      'tabari': 'جامع البيان — الطبري',
    };
    for (final entry in aliases.entries) {
      if (source.contains(entry.key)) return entry.value;
    }
    return fallback.trim().isEmpty ? fileName : fallback;
  }
}

/// Downloads hosted Quran content (translations & tafsirs) from the
/// app owner's GitHub repository (`raw.githubusercontent.com`).
///
/// Persistence: every file is downloaded exactly once into
/// `Documents/quran_content/` and kept forever — nothing deletes it
/// automatically (the same guarantee as the mushaf fonts). The user can
/// remove files from the content sheet in the mushaf.
class QuranContentService {
  /// Base URL of the content catalog (`quran-content.json` + DB files).
  ///
  /// Driven by `QF_CONTENT_BASE` (see [QuranApiConfig]); when unset it falls
  /// back to the public GitHub repo root that also hosts the mushaf pages.
  /// The previous code pinned a commit SHA here, but that SHA only contained
  /// the legacy translation file — every tafsir/translation download 404'd.
  static String get contentBaseUrl => QuranApiConfig.contentBaseUrl;

  /// Manifest file name expected at `$contentBaseUrl/quran-content.json`.
  static const String manifestFile = 'quran-content.json';

  /// Catalog entries known to be hosted in the repo. Used when the remote
  /// manifest is unreachable or not yet uploaded — the app keeps working and
  /// picks the manifest up automatically once it exists.
  static const List<QuranContentFile> builtinCatalog = [
    QuranContentFile(
      id: 'mokhtasar_fa',
      type: 'tafsir',
      name: 'المختصر فی التفسیر (فارسی)',
      fileName: 'mokhtasar_fa.db',
      sizeMB: 0.8,
      compressed: true,
      lang: 'fa',
    ),
    QuranContentFile(
      id: 'tafsir_noor',
      type: 'tafsir',
      name: 'تفسیر نور — مصطفی خرمدل',
      fileName: 'noor.db',
      sizeMB: 1.5,
      compressed: true,
      lang: 'fa',
    ),
    QuranContentFile(
      id: 'tafsir_anwar',
      type: 'tafsir',
      name: 'انوار القرآن — عبدالرئوف مخلص',
      fileName: 'anwar.db',
      sizeMB: 2.5,
      compressed: true,
      lang: 'fa',
    ),
    QuranContentFile(
      id: 'tafsir_rastin',
      type: 'tafsir',
      name: 'تفسیر راستین — السعدی',
      fileName: 'rastin.db',
      sizeMB: 2.7,
      compressed: true,
      lang: 'fa',
    ),
    QuranContentFile(
      id: 'persian_translation',
      type: 'translation',
      name: 'ترجمهٔ فارسی — سایت اسلام هاوس',
      fileName: 'persian_translation.json',
      sizeMB: 0.4,
      compressed: true,
      lang: 'fa',
    ),
    QuranContentFile(
      id: 'safwa_tafasir',
      type: 'tafsir',
      name: 'صفوة التفاسیر — الصابوني',
      fileName: 'safwa_tafasir.db',
      sizeMB: 0.5,
      compressed: true,
      lang: 'ar',
    ),
    QuranContentFile(
      id: 'fath_qadir',
      type: 'tafsir',
      name: 'فتح القدير — الشوكاني',
      fileName: 'fath_qadir.db',
      sizeMB: 4.4,
      compressed: true,
      lang: 'ar',
    ),
    QuranContentFile(
      id: 'mokhtasar_ibn_kathir',
      type: 'tafsir',
      name: 'مختصر تفسير ابن كثير — الصابوني',
      fileName: 'mokhtasar_ibn_kathir.db',
      sizeMB: 1.9,
      compressed: true,
      lang: 'ar',
    ),
    QuranContentFile(
      id: 'baghawi',
      type: 'tafsir',
      name: 'معالم التنزيل — البغوي',
      fileName: 'baghawi.db',
      sizeMB: 2.6,
      compressed: true,
      lang: 'ar',
    ),
    QuranContentFile(
      id: 'asbab_nuzul',
      type: 'tafsir',
      name: 'أسباب النزول — الواحدي',
      fileName: 'asbab_nuzul.db',
      sizeMB: 0.3,
      compressed: true,
      lang: 'ar',
    ),
    QuranContentFile(
      id: 'adwa_albayan',
      type: 'tafsir',
      name: 'أضواء البيان — الشنقيطي',
      fileName: 'adwa_albayan.db',
      sizeMB: 2.2,
      compressed: true,
      lang: 'ar',
    ),
    QuranContentFile(
      id: 'baydawi',
      type: 'tafsir',
      name: 'أنوار التنزيل — البيضاوي',
      fileName: 'baydawi.db',
      sizeMB: 2.1,
      compressed: true,
      lang: 'ar',
    ),
    QuranContentFile(
      id: 'irab_alquran',
      type: 'tafsir',
      name: 'إعراب القرآن',
      fileName: 'irab_alquran.db',
      sizeMB: 1.5,
      compressed: true,
      lang: 'ar',
    ),
    QuranContentFile(
      id: 'tasheel',
      type: 'tafsir',
      name: 'التسهيل لعلوم التنزيل — ابن جزي',
      fileName: 'tasheel.db',
      sizeMB: 1.1,
      compressed: true,
      lang: 'ar',
    ),
    QuranContentFile(
      id: 'tahrir_ashur',
      type: 'tafsir',
      name: 'تحرير المعنى — ابن عاشور',
      fileName: 'tahrir_ashur.db',
      sizeMB: 3.7,
      compressed: true,
      lang: 'ar',
    ),
    QuranContentFile(
      id: 'jalalain',
      type: 'tafsir',
      name: 'تفسير الجلالين — المحلي والسيوطي',
      fileName: 'jalalain.db',
      sizeMB: 0.8,
      compressed: true,
      lang: 'ar',
    ),
    QuranContentFile(
      id: 'ibn_kathir',
      type: 'tafsir',
      name: 'تفسير القرآن العظيم — ابن كثير',
      fileName: 'ibn_kathir.db',
      sizeMB: 4.3,
      compressed: true,
      lang: 'ar',
    ),
    QuranContentFile(
      id: 'tabari',
      type: 'tafsir',
      name: 'جامع البيان — الطبري',
      fileName: 'tabari.db',
      sizeMB: 2.4,
      compressed: true,
      lang: 'ar',
    ),
    QuranContentFile(
      id: 'kurd_tafsir_rebar',
      type: 'tafsir',
      name: 'تفسیر کوردی — ڕێبەر',
      fileName: 'kurd-tafsir-rebar.db',
      sizeMB: 1.53,
      compressed: true,
      lang: 'ku',
    ),
    QuranContentFile(
      id: 'kurdish_mokhtasar',
      type: 'tafsir',
      name: 'تفسیر کوردی — مختصر',
      fileName: 'kurdish-mokhtasar.db',
      sizeMB: 0.89,
      compressed: true,
      lang: 'ku',
    ),
    QuranContentFile(
      id: 'ku_burhan_muhammad_simple',
      type: 'translation',
      name: 'ترجمهٔ کوردی — برهان محمد',
      fileName: 'ku-burhan-muhammad-simple.json',
      sizeMB: 0.56,
      compressed: true,
      lang: 'ku',
    ),
    QuranContentFile(
      id: 'muhammad_saleh_bamoki_simple',
      type: 'translation',
      name: 'ترجمهٔ کوردی — محمد صالح باموکی',
      fileName: 'muhammad-saleh-bamoki-simple.json',
      sizeMB: 0.41,
      compressed: true,
      lang: 'ku',
    ),
  ];

  /// In-memory catalog cache (the manifest is static — fetch once per run).
  static List<QuranContentFile>? _cachedCatalog;

  /// The cached catalog, or null when it has not been fetched yet in this
  /// run (callers that must never block on the network use this).
  static List<QuranContentFile>? get cachedCatalogOrNull => _cachedCatalog;

  /// Fetches the list of available content files from the hosted catalog.
  /// Falls back to [builtinCatalog] when the manifest is unreachable,
  /// missing or malformed. The result is cached in memory for the rest of
  /// the app run, so opening the tafsir sheet repeatedly does not hit the
  /// network every time (this was the main source of the slow tafsir open).
  static Future<List<QuranContentFile>> fetchCatalog() async {
    if (_cachedCatalog != null) return _cachedCatalog!;
    try {
      final url = '$contentBaseUrl/$manifestFile';
      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        if (res.bodyBytes.length > QuranContentLimits.maxCatalogBytes) {
          throw const QuranContentLimitException(
              'catalog manifest exceeds the size limit');
        }
        final data =
            jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final list = data['contents'] as List<dynamic>? ?? [];
        if (list.isNotEmpty) {
          final parsed = <QuranContentFile>[];
          for (final entry in list) {
            if (entry is! Map<String, dynamic>) continue;
            // One hostile entry must not discard the whole catalog.
            try {
              final parsedEntry = QuranContentFile.fromJson(entry);
              if (parsedEntry.fileName.isEmpty) {
                AppLogger.warning('QuranContentService',
                    'skipped catalog entry ${parsedEntry.id}: no fileName');
                continue;
              }
              parsed.add(parsedEntry);
            } on FormatException catch (e) {
              AppLogger.warning(
                  'QuranContentService', 'skipped catalog entry: ${e.message}');
            }
          }
          if (parsed.isNotEmpty) {
            _cachedCatalog = parsed;
            return parsed;
          }
        }
      }
      AppLogger.warning(
          'QuranContentService', 'Catalog HTTP ${res.statusCode}');
    } catch (e) {
      AppLogger.warning('QuranContentService', 'Failed to fetch catalog: $e');
    }
    _cachedCatalog = builtinCatalog;
    return builtinCatalog;
  }

  /// Full path of [fileName] inside the content directory.
  ///
  /// Rejects anything that is not a plain file name *and* verifies containment,
  /// so a hostile catalog (or a stale external-root preference) cannot write
  /// outside the content directory.
  static Future<String> downloadPathFor(String fileName) async {
    if (!isSafeContentFileName(fileName)) {
      throw FormatException('unsafe content file name: $fileName');
    }
    final dir = await QuranStorage.contentDir();
    final path = p.join(dir.path, fileName);
    if (p.dirname(p.normalize(path)) != p.normalize(dir.path)) {
      throw const FormatException('content path escapes the content directory');
    }
    return path;
  }

  /// True when [file] has already been downloaded (valid size on disk).
  ///
  /// A provenance sidecar is trusted over the size heuristic: when one
  /// exists and its digest no longer matches the bytes on disk, the file is
  /// quarantined (renamed `.corrupt.<ts>`) and reported as not downloaded —
  /// a corrupted/tampered content file must be re-fetched, never served
  /// (upgrade wave-3 #3).
  static Future<bool> isDownloaded(QuranContentFile file) async {
    final path = await downloadPathFor(file.fileName);
    final f = File(path);
    if (!await f.exists() || await f.length() <= 1000) return false;
    final verification = await ContentProvenance.verify(path);
    if (verification != ContentVerification.mismatch) return true;
    try {
      await f.rename('$path.corrupt.${DateTime.now().millisecondsSinceEpoch}');
    } catch (_) {
      AppLogger.warning('quran_content_service',
          'could not quarantine mismatched ${file.fileName}');
    }
    return false;
  }

  /// Downloads [file] once (skips when already on disk) and keeps it forever.
  /// Compressed files are downloaded as `fileName.gz` and decompressed to
  /// `fileName` (the gzip copy is not kept). Uses a temp file + rename so a
  /// killed app never leaves a truncated DB that `isDownloaded()` (>1000 bytes)
  /// would permanently count as valid. Gzip decoding runs off the UI isolate.
  static Future<String?> ensureDownloaded(QuranContentFile file) async {
    final path = await downloadPathFor(file.fileName);
    final f = File(path);
    if (await f.exists() && await f.length() > 1000) {
      // Basic SQLite header sanity — a truncated tafsir DB begins with garbage.
      if (file.fileName.endsWith('.db')) {
        try {
          final header = await f.openRead(0, 16).first;
          if (header.length < 16 ||
              String.fromCharCodes(header.sublist(0, 6)) != 'SQLite') {
            await f.delete();
          } else {
            return path;
          }
        } catch (_) {
          AppLogger.warning('quran_content_service', 'operation failed');
          return path;
        }
      } else {
        return path;
      }
    }

    // Tafsir databases and translations are hosted under `tafsir/` in the
    // content repo (see the `tafsir/` folder next to `quran-content.json`).
    if (!isSafeContentRemoteName(file.remoteName)) {
      AppLogger.warning(
          'QuranContentService', 'refused unsafe remote name for ${file.id}');
      return null;
    }
    final uri = Uri.parse(
        '${QuranApiConfig.tafsirBaseUrl}/${Uri.encodeComponent(file.remoteName)}');
    if (uri.scheme != 'https') {
      AppLogger.warning(
          'QuranContentService', 'refused non-https content URL: $uri');
      return null;
    }
    try {
      // Streamed with a byte cap: `http.get` buffers the whole body, so a
      // hostile response could exhaust memory before any check runs.
      final bytes = await _downloadBounded(uri);
      final out = file.compressed ? await compute(_gunzipBytes, bytes) : bytes;
      if (out.length > QuranContentLimits.maxDecompressedBytes) {
        throw const QuranContentLimitException(
            'downloaded content exceeds the size limit');
      }
      // Validate the bytes we are about to commit. For a compressed download
      // `bytes` is gzip (`1f 8b 08 …`), so checking it rejected every valid
      // `.db.gz` as having an "invalid SQLite header".
      if (file.fileName.endsWith('.db') && out.length > 16) {
        if (String.fromCharCodes(out.sublist(0, 6)) != 'SQLite') {
          AppLogger.warning('QuranContentService',
              'Download ${file.fileName} has invalid SQLite header');
          return null;
        }
      }
      final tmp = File('$path.part');
      await tmp.writeAsBytes(out, flush: true);
      if (await f.exists()) await f.delete();
      await tmp.rename(path);
      // Provenance sidecar (wave-3 #3): what was fetched, from where, and
      // the digest of the exact bytes committed — written AFTER the rename,
      // so a sidecar's presence always implies a complete download.
      await ContentProvenance.write(path, out,
          id: file.id, remoteUrl: uri.toString());
      return path;
    } catch (e) {
      AppLogger.warning(
          'QuranContentService', 'Download failed ${file.fileName}: $e');
      try {
        final tmp = File('$path.part');
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {
        AppLogger.warning('quran_content_service', 'operation failed');
      }
      return null;
    }
  }

  /// Downloads [uri], aborting as soon as more than
  /// [QuranContentLimits.maxDownloadBytes] have arrived.
  static Future<List<int>> _downloadBounded(Uri uri) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', uri);
      final response =
          await client.send(request).timeout(const Duration(minutes: 10));
      if (response.statusCode != 200) {
        throw http.ClientException(
            'HTTP ${response.statusCode} for ${fileNameOf(uri)}', uri);
      }
      final declared = response.contentLength;
      if (declared != null && declared > QuranContentLimits.maxDownloadBytes) {
        throw const QuranContentLimitException(
            'content download declares more than the size limit');
      }
      final builder = BytesBuilder(copy: false);
      var received = 0;
      await for (final chunk in response.stream) {
        received += chunk.length;
        if (received > QuranContentLimits.maxDownloadBytes) {
          throw const QuranContentLimitException(
              'content download exceeds the size limit');
        }
        builder.add(chunk);
      }
      return builder.takeBytes();
    } finally {
      client.close();
    }
  }

  static String fileNameOf(Uri uri) =>
      uri.pathSegments.isEmpty ? uri.toString() : uri.pathSegments.last;

  /// Removes a downloaded content file (user-triggered cleanup only). Also
  /// removes a stray `.gz` copy if one exists.
  static Future<void> deleteDownloaded(QuranContentFile file) async {
    try {
      final path = await downloadPathFor(file.fileName);
      final f = File(path);
      if (await f.exists()) {
        await f.delete();
      }
      if (file.compressed) {
        final gz = File('$path.gz');
        if (await gz.exists()) {
          await gz.delete();
        }
      }
    } catch (e) {
      AppLogger.warning(
          'QuranContentService', 'Delete failed ${file.fileName}: $e');
    }
  }
}

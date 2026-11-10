import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'package:tawheeed/features/quran/services/quran_content_service.dart';
import 'package:tawheeed/features/quran/services/quran_storage.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// A tafsir database available to the reader.
class TafsirDbInfo {
  final int id;
  final String name;
  final String fileName;

  const TafsirDbInfo({
    required this.id,
    required this.name,
    required this.fileName,
  });

  /// Tafsirs downloaded from the hosted catalog (`Documents/quran_content`).
  /// Populated by [TafsirService.refreshDownloaded].
  static final List<TafsirDbInfo> downloaded = [];

  /// All available tafsirs.
  static List<TafsirDbInfo> get available => downloaded;

  /// Resolves a tafsir id from the settings to a downloadable database.
  ///
  /// `169` is the legacy default id (المختصر فی التفسیر): when the hosted
  /// `mokhtasar_fa` database is present it wins; otherwise null is returned
  /// so [TafsirService.databaseFor] falls back to the bundled المختصر
  /// database. (Never substitute another downloaded tafsir here — showing,
  /// e.g., an Arabic tafsir where the user expects the Persian المختصر is a
  /// silent wrong-language bug.)
  static TafsirDbInfo? byId(int id) {
    if (id == 169) {
      for (final t in downloaded) {
        if (t.fileName == 'mokhtasar_fa.db') return t;
      }
      return null;
    }
    for (final t in downloaded) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Stable numeric id for a downloaded tafsir (derived from its file name,
  /// so it survives app restarts).
  static int idForContentFile(QuranContentFile file) =>
      file.fileName.hashCode & 0x7fffffff;

  static String localizedNameForFile(String fileName) {
    final id = p.basenameWithoutExtension(fileName);
    return QuranContentFile.localizedName(
      id: id,
      fileName: fileName,
      fallback: id,
    );
  }
}

/// Reads tafsir texts from SQLite databases. Each tafsir has its own DB file
/// with the schema: `contents(sura INT, ayah INT, text TEXT)`.
class TafsirService {
  static final Map<int, Database> _dbs = {};

  /// Legacy/default tafsir id (المختصر فی التفسیر).
  static const int defaultTafsirId = 169;

  /// Bundled fallback tafsir, seeded into the content directory on first use
  /// so the default tafsir works offline without any download.
  static const String _bundledAsset = 'assets/mokhtasar.db';
  static const String _bundledFileName = 'mokhtasar.db';

  /// Copies `assets/mokhtasar.db` into `quran_content/bundled/` (once) and
  /// returns its path, or null when the asset is unavailable.
  static Future<String?> _ensureBundledDb() async {
    try {
      final root = await QuranStorage.contentDir();
      final dir = Directory(p.join(root.path, 'bundled'));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final path = p.join(dir.path, _bundledFileName);
      final file = File(path);
      if (await file.exists() && await file.length() > 1000) return path;
      final data = await rootBundle.load(_bundledAsset);
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
      return path;
    } catch (e) {
      AppLogger.warning('TafsirService', 'seed bundled tafsir failed: $e');
      return null;
    }
  }

  /// Scans the content directory and registers the downloaded tafsirs (id
  /// derived from the file name so it survives restarts). Only a cheap local
  /// directory scan runs on the critical path — the remote catalog fetch is
  /// awaited only when it is already cached, so opening the tafsir sheet never
  /// blocks on the network.
  static Future<void> refreshDownloaded() async {
    try {
      final dir = await QuranStorage.contentDir();
      final names = <String>{};
      if (await dir.exists()) {
        await for (final entity in dir.list()) {
          if (entity is File && entity.path.endsWith('.db')) {
            names.add(p.basename(entity.path));
          }
        }
      }
      // Names come from the catalog when already cached (no network); DB
      // files without catalog metadata fall back to their file name.
      final catalog = QuranContentService.cachedCatalogOrNull ??
          QuranContentService.builtinCatalog;
      final known = <String>{};
      for (final f in catalog.where((f) => f.isTafsir)) {
        known.add(f.fileName);
        if (names.contains(f.fileName) &&
            !TafsirDbInfo.downloaded
                .any((t) => t.id == TafsirDbInfo.idForContentFile(f))) {
          TafsirDbInfo.downloaded.add(TafsirDbInfo(
            id: TafsirDbInfo.idForContentFile(f),
            name: f.name,
            fileName: f.fileName,
          ));
        }
      }
      // DB files without catalog metadata are still usable.
      for (final n in names.where((n) => !known.contains(n))) {
        if (!TafsirDbInfo.downloaded.any((t) => t.fileName == n)) {
          TafsirDbInfo.downloaded.add(TafsirDbInfo(
            id: n.hashCode & 0x7fffffff,
            name: TafsirDbInfo.localizedNameForFile(n),
            fileName: n,
          ));
        }
      }
      TafsirDbInfo.downloaded.removeWhere((t) => !names.contains(t.fileName));
    } catch (e) {
      AppLogger.warning('TafsirService', 'refreshDownloaded failed: $e');
    }
  }

  static Future<Database> databaseFor(int tafsirId) async {
    final cached = _dbs[tafsirId];
    if (cached != null) return cached;
    final info = TafsirDbInfo.byId(tafsirId);
    String? path;
    if (info != null) {
      final contentDir = await QuranStorage.contentDir();
      path = p.join(contentDir.path, info.fileName);
    } else if (tafsirId == defaultTafsirId) {
      // No downloaded tafsir yet — fall back to the bundled المختصر database.
      path = await _ensureBundledDb();
    }
    if (path == null) {
      throw Exception('Unknown tafsir id: $tafsirId');
    }
    // Read-only: tafsir databases are reference content — never create,
    // migrate, or lock them for writing from the reader.
    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    _dbs[tafsirId] = db;
    return db;
  }

  /// Tafsir text for one ayah. Returns `null` when the tafsir is not
  /// downloaded, the id is unknown, or the ayah has no entry.
  static Future<String?> getTafsir(int surah, int verse,
      {int tafsirId = defaultTafsirId}) async {
    try {
      final db = await databaseFor(tafsirId);
      final result = db.select(
        'SELECT text FROM contents WHERE sura = ? AND ayah = ? LIMIT 1',
        [surah, verse],
      );
      if (result.isEmpty) return null;
      return result.first['text'] as String?;
    } catch (e) {
      AppLogger.warning('TafsirService', 'Failed to get tafsir: $e');
      return null;
    }
  }

  /// Tafsir texts for a verse range (ayah -> text).
  static Future<Map<int, String>> getTafsirForRange(
    int surah,
    int startVerse,
    int endVerse, {
    int tafsirId = 169,
  }) async {
    try {
      final db = await databaseFor(tafsirId);
      final results = db.select(
        'SELECT ayah, text FROM contents WHERE sura = ? AND ayah >= ? AND ayah <= ? ORDER BY ayah ASC',
        [surah, startVerse, endVerse],
      );
      final map = <int, String>{};
      for (final row in results) {
        final verse = row['ayah'] as int?;
        final text = row['text'] as String?;
        if (verse == null || text == null) continue;
        map[verse] = text;
      }
      return map;
    } catch (e) {
      AppLogger.warning('TafsirService', 'Failed to get tafsir range: $e');
      return {};
    }
  }

  static void close() {
    for (final db in _dbs.values) {
      try {
        db.close();
      } catch (_) {
        AppLogger.warning('tafsir_service', 'operation failed');
      }
    }
    _dbs.clear();
  }
}

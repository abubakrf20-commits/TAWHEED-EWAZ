import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/features/quran/services/quran_content_service.dart';
import 'package:tawheeed/features/quran/services/quran_translation_reader.dart';

/// The user's translation choice plus the read path that answers it.
///
/// The hosted catalog ships several translations (Persian and two Sorani
/// Kurdish ones), so the selection is a real setting: it is stored as the
/// catalog **id** under `quran_translation` and resolved against the local
/// catalog, which means reading it never waits on the network. An unset,
/// empty or unknown id is the Persian translation — the only file bundled as
/// an asset, so it is the one that is readable out of the box.
class QuranTranslationService {
  QuranTranslationService._();

  /// Catalog id of the bundled Persian translation.
  static const String defaultId = 'persian_translation';

  /// Value written before any picker existed. It meant "the Persian one", so
  /// it still resolves to it rather than to an unknown id.
  static const String legacyId = 'default';

  static const String _prefsKey = 'quran_translation';

  static Future<String> selectedId() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved == null || saved.isEmpty) return defaultId;
    return saved;
  }

  static Future<void> setSelectedId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, id.isEmpty ? defaultId : id);
  }

  /// The translation entries the app knows about, from the local catalog — it
  /// never fetches the manifest, so a picker opens instantly.
  static List<QuranContentFile> available() {
    final catalog =
        QuranContentService.cachedCatalogOrNull ?? QuranContentService.builtinCatalog;
    final list = catalog.where((f) => f.isTranslation).toList();
    // The Persian entry is the fallback, so it must be offered even if a remote
    // manifest somehow arrives without it.
    if (list.any((f) => f.id == defaultId)) return list;
    return [
      ...list,
      QuranContentService.builtinCatalog.firstWhere((f) => f.id == defaultId),
    ];
  }

  /// The catalog entry the stored id points at, falling back to Persian when
  /// the id is the default, a legacy value or unknown (a file the manifest no
  /// longer lists).
  static Future<QuranContentFile> selectedEntry() async {
    final id = await selectedId();
    final list = available();
    for (final f in list) {
      if (f.id == id) return f;
    }
    return list.firstWhere((f) => f.id == defaultId, orElse: () => list.first);
  }

  /// Display name of the selected translation — the sheet header's wording.
  static Future<String> selectedName() async => (await selectedEntry()).name;

  /// File name of the selected translation on disk.
  static Future<String> selectedFileName() async => (await selectedEntry()).fileName;

  /// True when the selected translation is readable now (bundled or
  /// downloaded). A file that still has to be fetched answers false, which is
  /// what makes the sheet show its download prompt.
  static Future<bool> isReady() async =>
      QuranTranslationReader.isAvailable(await selectedFileName());

  /// Downloads the selected translation if needed. Returns `null` on failure.
  static Future<String?> ensureDownloaded() async =>
      QuranContentService.ensureDownloaded(await selectedEntry());

  /// Forget the parsed copy of [fileName] — called when its file is deleted.
  static void evict(String fileName) => QuranTranslationReader.evict(fileName);

  /// Translation text for one ayah. Returns `null` when the translation is
  /// not downloaded yet or the ayah has no entry.
  static Future<String?> getTranslation(int surah, int verse) async =>
      QuranTranslationReader.getTranslation(
          await selectedFileName(), surah, verse);

  /// Translations for a verse range (verse number -> text).
  static Future<Map<int, String>> getTranslationsForPage(
    int surah,
    int startVerse,
    int endVerse,
  ) async =>
      QuranTranslationReader.getTranslationsForRange(
          await selectedFileName(), surah, startVerse, endVerse);
}

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central resolver for where downloaded Quran content (the Persian
/// translation file and the tafsir databases) lives.
///
/// Content is stored in `Documents/quran_content/`. When a previous build
/// moved the data to external storage (SD card / Download folder) the
/// persisted root is honored so the files keep working and survive app
/// uninstall; if the external location becomes unavailable (e.g. the SD card
/// is removed) the resolver falls back to the internal Documents directory.
class QuranStorage {
  QuranStorage._();

  static const String externalRootKey = 'quran_external_root';
  static const String contentDirName = 'quran_content';

  /// Persisted external root (e.g. `/storage/1234-5678/TAWHEED`), if set.
  static Future<String?> getExternalRoot() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(externalRootKey);
  }

  /// Directory holding downloaded tafsir/translation databases.
  static Future<Directory> contentDir() async {
    final root = await getExternalRoot();
    if (root != null) {
      final rootDir = Directory(root);
      if (await rootDir.exists()) {
        final dir = Directory(p.join(root, contentDirName));
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir;
      }
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, contentDirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}

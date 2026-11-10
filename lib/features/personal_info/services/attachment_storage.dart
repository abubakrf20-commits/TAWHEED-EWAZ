import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Stores attached files (document photos, profile avatars, scanned docs)
/// under the app's documents directory so they survive reinstall-less
/// backups and are exported/restored with the portable backup.
///
/// Layout:
///   `<documents>/app_data/attachments/<kind>/<random>.<ext>`
///
/// Files are moved (copied-then-original-removed) so the source picker can
/// return a path we don't own and the app keeps a stable, private copy.
class AttachmentStorage {
  static const _root = 'app_data';
  static const _dirName = 'attachments';

  // Kind directories, to separate document scans / avatars / generic files.
  static const _kinds = {
    'avatar': 'avatar',
    'document': 'document',
    'asset': 'asset',
    'generic': 'generic',
  };

  static String _kindDir(String kind) {
    final dir = _kinds[kind];
    if (dir != null) return dir;
    return _kinds['generic'] ?? 'generic';
  }

  static Future<Directory> _ensureDir(String kind) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, _root, _dirName, _kindDir(kind)));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Copies [source] into the store and returns the new absolute path.
  ///
  /// Audit 3.1-5: rejects files above [maxAttachmentBytes] (10 MB) so a
  /// stray video cannot balloon the documents vault (and its backup).
  ///
  /// A rejected (or missing) source returns the empty string — the caller
  /// skips it instead of silently storing a picker cache path that breaks
  /// the next time the system clears its temp directory.
  static const int maxAttachmentBytes = 10 * 1024 * 1024;

  static Future<String> storeFile(String sourcePath, String kind,
      {String? fallbackExt}) async {
    final src = File(sourcePath);
    if (!await src.exists()) return '';
    final size = await src.length();
    if (size > maxAttachmentBytes) {
      AppLogger.warning(
          'AttachmentStorage', 'rejected attachment of $size bytes (over cap)');
      return '';
    }
    final dir = await _ensureDir(kind);
    final ext = fallbackExt ?? p.extension(src.path);
    final name =
        '${DateTime.now().millisecondsSinceEpoch}_${_rand()}${ext.isEmpty ? '' : ext}';
    final dest = File(p.join(dir.path, name));
    await src.copy(dest.path);
    return dest.path;
  }

  /// Deletes a stored file if it lives inside our root (never touches
  /// arbitrary user paths).
  ///
  /// Stored paths are `<root>/<kind>/<file>`, so membership is checked with
  /// an isWithin test. (The previous basename comparison only matched files
  /// sitting directly in the root, which never happens — deletes silently
  /// no-op'd and files piled up.)
  static Future<void> deleteStoredFile(String path) async {
    if (path.isEmpty) return;
    final docs = await getApplicationDocumentsDirectory();
    final root = p.joinAll([docs.path, _root, _dirName]);
    if (!p.isWithin(root, p.normalize(path))) return;
    final f = File(path);
    if (await f.exists()) {
      try {
        await f.delete();
      } catch (e) {
        AppLogger.warning('AttachmentStorage', 'delete failed: $e');
      }
    }
  }

  /// Deletes every stored file whose path is listed in a JSON array.
  static Future<void> deleteStoredList(List<String> paths) async {
    for (final path in paths) {
      await deleteStoredFile(path);
    }
  }

  /// True when [path] is a stored attachment that still exists on disk.
  /// Used to prune dead references (missing files) from JSON path lists.
  static Future<bool> storedPathExists(String path) async {
    if (path.isEmpty) return false;
    final docs = await getApplicationDocumentsDirectory();
    final root = p.joinAll([docs.path, _root, _dirName]);
    if (!p.isWithin(root, p.normalize(path))) return false;
    return File(path).exists();
  }

  static String _rand() {
    final r = DateTime.now().microsecondsSinceEpoch.toString();
    return r.substring(r.length - 6);
  }
}

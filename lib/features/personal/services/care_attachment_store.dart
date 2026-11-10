import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:tawheeed/shared/utils/app_logger.dart';

/// Receipt / photo storage for the personal tools.
///
/// * pick through the system photo picker (`file_picker`, `FileType.image`) —
///   no storage permission, no `image_picker` dependency;
/// * decode + downscale + re-encode JPEG q80 off the UI isolate, which also
///   drops **all** EXIF, location included (we write fresh pixel data);
/// * store under `<documents>/app_data/attachments/care/`, the folder the
///   existing backup already archives wholesale;
/// * hand the UI a path **relative** to the documents directory, so the row
///   survives a restore to a different install path.
class CareAttachmentStore {
  CareAttachmentStore._();

  static const String _relativeRoot = 'app_data/attachments/care';
  static const int maxInputBytes = 12 * 1024 * 1024;
  static const int maxEdge = 1600;
  static const int jpegQuality = 80;

  /// Opens the picker and returns the stored relative paths (possibly empty
  /// when the user cancels or every file was rejected).
  static Future<List<String>> pickAndStore() async {
    try {
      // file_picker 13's top-level API: returns the picked files directly
      // (the old `FilePicker.platform.pickFiles` result object is gone).
      final files = await FilePicker.pickFiles(
        type: FileType.image,
      );
      final stored = <String>[];
      for (final file in files) {
        final path = file.path;
        if (path == null || path.isEmpty) continue;
        final relative = await storeImage(path);
        if (relative.isNotEmpty) stored.add(relative);
      }
      return stored;
    } catch (e) {
      AppLogger.warning('CareAttachment', 'picker failed: $e');
      return const [];
    }
  }

  /// Downscales + re-encodes [sourcePath] and stores it. Returns '' when the
  /// file is missing, too large or not a decodable image.
  static Future<String> storeImage(String sourcePath) async {
    try {
      final source = File(sourcePath);
      if (!await source.exists()) return '';
      if (await source.length() > maxInputBytes) {
        AppLogger.warning('CareAttachment', 'image over the input cap skipped');
        return '';
      }
      final bytes = await source.readAsBytes();
      final encoded = await compute(_downscaleJpeg, bytes);
      if (encoded == null) return '';

      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory(p.joinAll([docs.path, ..._relativeRoot.split('/')]));
      if (!await dir.exists()) await dir.create(recursive: true);
      final name = 'care_${DateTime.now().microsecondsSinceEpoch}_'
          '${bytes.length}.jpg';
      final dest = File(p.join(dir.path, name));
      await dest.writeAsBytes(encoded, flush: true);
      return '$_relativeRoot/$name';
    } catch (e) {
      AppLogger.warning('CareAttachment', 'store failed: $e');
      return '';
    }
  }

  /// Absolute path for a stored relative path (null when the file vanished).
  static Future<String?> absolutePath(String relative) async {
    if (relative.isEmpty) return null;
    final docs = await getApplicationDocumentsDirectory();
    final path = p.joinAll([docs.path, ...relative.split('/')]);
    return path;
  }

  static Future<void> delete(String relative) async {
    if (relative.isEmpty) return;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final root = p.joinAll([docs.path, ..._relativeRoot.split('/')]);
      final path = p.normalize(p.joinAll([docs.path, ...relative.split('/')]));
      if (!p.isWithin(root, path)) return;
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e) {
      AppLogger.warning('CareAttachment', 'delete failed: $e');
    }
  }

  static Future<void> deleteAll(Iterable<String> relatives) async {
    for (final relative in relatives) {
      await delete(relative);
    }
  }
}

/// Runs in an isolate: decode → clamp to [CareAttachmentStore.maxEdge] →
/// JPEG q80. Returning null means “not an image”.
Uint8List? _downscaleJpeg(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  var image = decoded;
  final longest = image.width > image.height ? image.width : image.height;
  if (longest > CareAttachmentStore.maxEdge) {
    final scale = CareAttachmentStore.maxEdge / longest;
    image = img.copyResize(
      image,
      width: (image.width * scale).round(),
      height: (image.height * scale).round(),
      interpolation: img.Interpolation.average,
    );
  }
  return Uint8List.fromList(
    img.encodeJpg(image, quality: CareAttachmentStore.jpegQuality),
  );
}

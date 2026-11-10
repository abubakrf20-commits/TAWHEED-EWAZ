import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

import 'package:tawheeed/shared/services/content_download_service.dart';

/// کش درون‌حافظهٔ فهرست کتاب‌های دانلودشده — در گرید کتابخانه 50+ کارت،
/// به‌جای 50 چک فایل مجزا فقط یک لیست دایرکتوری انجام می‌شود (در تلفن‌های
/// ضعیف جلوگیری از چند ده I/O هم‌زمان هنگام اسکرول).

/// Downloads individual library books (`book_<id>.json.gz`) from the hosted
/// catalog on first open.
///
/// The books index stays bundled; only the content of each book is fetched on
/// demand, so a user who reads a single book does not pay the download cost of
/// the whole library. Files are kept in `Documents/books_data/`.
class BookContentService {
  BookContentService._();

  static Future<Directory> _booksDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'books_data'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Local path of the (still gzipped) content file of [bookId].
  static Future<String> localPathFor(String bookId) async {
    final dir = await _booksDir();
    return p.join(dir.path, 'book_$bookId.json.gz');
  }

  /// Whether the content of [bookId] is already on disk.
  static Future<bool> isDownloaded(String bookId) async {
    final ids = await downloadedIds();
    return ids.contains(bookId);
  }

  /// شناسه‌های همهٔ کتاب‌هایی که محتوایشان روی دیسک است (با کش تا 15 ثانیه).
  static Set<String>? _cachedIds;
  static DateTime? _cacheTime;

  static Future<Set<String>> downloadedIds() async {
    final now = DateTime.now();
    if (_cachedIds != null &&
        _cacheTime != null &&
        now.difference(_cacheTime!) < const Duration(seconds: 15)) {
      return _cachedIds!;
    }
    try {
      final dir = await _booksDir();
      final ids = <String>{};
      await for (final entity in dir.list()) {
        final name = p.basename(entity.path);
        final m = RegExp(r'^book_(\d+)\.json\.gz$').firstMatch(name);
        if (m != null) {
          final id = m.group(1);
          if (id != null) ids.add(id);
        }
      }
      _cachedIds = ids;
      _cacheTime = now;
      return ids;
    } catch (e) {
      AppLogger.warning('BookContent', 'book id scan failed: $e');
      return _cachedIds ?? {};
    }
  }

  /// Invalidates the [downloadedIds] cache (after download/delete).
  static void invalidateCache() {
    _cachedIds = null;
    _cacheTime = null;
  }

  /// Downloads the content of [bookId] once and returns its local path, or
  /// `null` when the download failed. The hosted file is already gzipped so it
  /// is written as-is (no decompression).
  static Future<String?> ensureDownloaded(
    String bookId, {
    DownloadProgress? onProgress,
  }) async {
    final path = await ContentDownloadService.ensureDownloaded(
      'library/book_$bookId.json.gz',
      await localPathFor(bookId),
      onProgress: onProgress,
    );
    if (path != null) invalidateCache();
    return path;
  }

  /// Removes the downloaded content of [bookId].
  static Future<void> deleteDownloaded(String bookId) async {
    await ContentDownloadService.deleteDownloaded(await localPathFor(bookId));
    invalidateCache();
  }
}

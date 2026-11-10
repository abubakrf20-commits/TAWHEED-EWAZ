import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:tawheeed/shared/services/content_download_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Progress callback shared by every content download in the app.
typedef ContentDownloadProgress = DownloadProgress;

/// Thrown when a downloaded content database is required but missing.
class ContentDatabaseMissingException implements Exception {
  final String message;
  const ContentDatabaseMissingException(this.message);

  @override
  String toString() => message;
}

/// Base class for the downloadable read-only sqlite content databases
/// (کتب حدیث، ریاض الصالحین، موسوعه احادیث، فتاوای شرعی).
///
/// Owns the lifecycle all four services previously duplicated: local path
/// resolution, availability probing, `.gz` download via
/// [ContentDownloadService], open/close, and the ready flag. Subclasses add
/// only their schema-specific queries and (optionally) a migration hook.
abstract class DownloadedSqliteDbService {
  DownloadedSqliteDbService({
    required this.dbFileName,
    required this.remoteKey,
    this.readOnly = true,
    this.contentRevision = 1,
    this.minChapters = 0,
    this.schemaWork,
  });

  /// Heavy, one-shot schema work (column migrations, index backfills) that runs
  /// on a **worker isolate** before the main handle opens.
  ///
  /// A content database is downloaded once and migrated on first use: the hadith
  /// backfill normalizes 80k+ rows and builds their FTS index, which is seconds
  /// of work the user would otherwise feel as a frozen screen. The function must
  /// be top-level (or capture nothing but plain values) — `Isolate.run` sends
  /// the closure, and a Database handle, a Riverpod ref or `this` cannot cross
  /// that boundary.
  final void Function(String path)? schemaWork;

  /// File name inside the documents directory (e.g. `hadith.db`).
  final String dbFileName;

  /// Content-catalog key (e.g. `hadith/hadith.db`).
  final String remoteKey;

  /// Whether to open the database in read-only mode.
  final bool readOnly;

  /// Revision of the hosted content this build expects.
  ///
  /// [ContentDownloadService] keeps whatever is already on disk, so a
  /// republished database would never reach an existing install. Bump this
  /// whenever the hosted file is replaced with corrected content; the stale
  /// local copy is then dropped and fetched again on the next download.
  final int contentRevision;

  /// Lowest `chapters` row count a healthy copy of the hosted payload has.
  ///
  /// [contentRevision] alone cannot catch every stale copy. An install that
  /// once recorded the current number over older bytes keeps answering «up to
  /// date» forever — that is exactly how revision 3 of معالم outlived its
  /// payload and kept showing 474 of its 1,929 بab. A truncated or
  /// half-decompressed download records the number too.
  ///
  /// This floor is the shape of the shipped file: a copy shorter than it is
  /// replaced even when the stored revision matches. Set it to the chapter
  /// count the republished file actually carries, and move it together with
  /// [contentRevision] — never after the fact, or an install re-downloads on
  /// every open. 0 disables the check.
  final int minChapters;

  String get _revisionKey => 'content_rev_$dbFileName';

  Future<int> _appliedRevision() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_revisionKey) ?? 0;
    } catch (e) {
      AppLogger.warning('DownloadedSqliteDb', 'revision read failed: $e');
      return 0;
    }
  }

  /// Whether a copy exists on disk but predates [contentRevision], or is
  /// shorter than [minChapters] and therefore not the hosted payload.
  Future<bool> needsUpdate() async {
    if (!await isDownloadedFile()) return false;
    if (await _appliedRevision() < contentRevision) return true;
    if (minChapters <= 0) return false;
    return !await _carriesChapters(await localPath());
  }

  /// Whether the file at [path] really holds at least [minChapters] chapters.
  /// An unreadable file answers false: a corrupt copy is stale by definition.
  Future<bool> _carriesChapters(String path) async {
    Database? db;
    try {
      db = sqlite3.open(path, mode: OpenMode.readOnly);
      final rows = db.select('SELECT COUNT(*) AS n FROM chapters');
      return ((rows.first['n'] as int?) ?? 0) >= minChapters;
    } catch (e) {
      AppLogger.warning(runtimeType.toString(), 'shape check failed: $e');
      return false;
    } finally {
      db?.close();
    }
  }

  Database? _db;
  bool _ready = false;
  bool get isReady => _ready;

  /// The open database. Only valid after a successful [ensureReady].
  Database get db {
    final d = _db;
    if (d == null || !_ready) {
      throw StateError('$dbFileName is not initialized — call ensureReady()');
    }
    return d;
  }

  /// Local path of the database inside the documents directory.
  Future<String> localPath() async =>
      p.join((await getApplicationDocumentsDirectory()).path, dbFileName);

  /// Whether a valid copy of the database is already on disk.
  Future<bool> isDownloadedFile() async =>
      ContentDownloadService.isDownloaded(await localPath());

  /// Downloads the database (decompressing its `.gz`) if not present, or if
  /// the local copy predates [contentRevision]. Throws
  /// [ContentDatabaseMissingException] when the download fails.
  Future<void> downloadFile({DownloadProgress? onProgress}) async {
    final path = await localPath();
    // An outdated copy has to go first: [ContentDownloadService.ensureDownloaded]
    // returns early for any file already on disk, so it would never pick up
    // the republished database.
    if (await needsUpdate()) {
      await ContentDownloadService.deleteDownloaded(path);
    }
    final result = await ContentDownloadService.ensureDownloaded(
      remoteKey,
      path,
      compressed: true,
      onProgress: onProgress,
    );
    if (result == null) {
      // A null result can still leave a complete file on disk (the bytes
      // were written and only a later cleanup step failed). Re-check disk
      // before reporting failure: a valid copy must open, not send the user
      // back to the download prompt.
      if (!await ContentDownloadService.isDownloaded(path)) {
        throw ContentDatabaseMissingException(
            'دانلود دادهٔ $dbFileName ناموفق بود.');
      }
      AppLogger.warning('DownloadedSqliteDb',
          'download reported failure but $dbFileName is on disk — using it');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_revisionKey, contentRevision);
    } catch (e) {
      AppLogger.warning('DownloadedSqliteDb', 'revision write failed: $e');
    }
  }

  /// Removes the downloaded database (user-triggered cleanup).
  Future<void> deleteDownloadedFile() async {
    close();
    await ContentDownloadService.deleteDownloaded(await localPath());
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_revisionKey);
    } catch (e) {
      AppLogger.warning('DownloadedSqliteDb', 'revision clear failed: $e');
    }
  }

  /// Opens the database if a local copy exists; throws
  /// [ContentDatabaseMissingException] otherwise. Idempotent.
  Future<void> ensureReady() async {
    if (_ready) return;
    final path = await localPath();
    if (!await File(path).exists()) {
      throw ContentDatabaseMissingException(
          '$dbFileName هنوز دانلود نشده است.');
    }
    await _runSchemaWork(path);
    try {
      _db = sqlite3.open(path,
          mode: readOnly ? OpenMode.readOnly : OpenMode.readWrite);
    } catch (e) {
      AppLogger.warning(runtimeType.toString(), 'open failed: $e');
      rethrow;
    }
    // Mark ready before the hook so subclasses can use the [db] getter
    // (and run migrations) inside [onReady].
    _ready = true;
    onReady(_db!);
  }

  /// [schemaWork] on its own isolate, unless the file is already migrated.
  ///
  /// The check costs one cheap `PRAGMA user_version` read: content databases
  /// are migrated exactly once per install, and paying an isolate spawn on
  /// every later open would cost more than the work it avoids.
  Future<void> _runSchemaWork(String path) async {
    final work = schemaWork;
    if (work == null) return;
    Database? probe;
    try {
      probe = sqlite3.open(path,
          mode: readOnly ? OpenMode.readOnly : OpenMode.readWrite);
    } catch (e) {
      AppLogger.warning(runtimeType.toString(), 'schema probe failed: $e');
      return;
    }
    final int version;
    try {
      version =
          probe.select('PRAGMA user_version').first['user_version'] as int;
    } finally {
      probe.close();
    }
    if (version >= schemaWorkVersion) return;
    try {
      await Isolate.run(() => work(path));
    } catch (e) {
      AppLogger.warning(
          runtimeType.toString(), 'schema work failed for $dbFileName: $e');
      rethrow;
    }
  }

  /// The [schemaWork] revision this build expects. Bump it together with a
  /// changed [schemaWork] so installs on the old revision migrate again.
  int get schemaWorkVersion => 1;

  /// Schema migration / post-open hook for subclasses (default no-op).
  ///
  /// Runs on the UI isolate, so keep it to cheap statements (`COUNT`, a `PRAGMA`
  /// log). Moving a *query* off-isolate with `Isolate.run` is deliberately not
  /// offered: a second handle to the same file releases its OS handle only when
  /// the short-lived isolate is reaped, which races the next read or (in tests)
  /// the temp-directory cleanup, and a spawn per keystroke costs more than the
  /// indexed query it avoids. Subclasses make queries cheap instead — an index,
  /// a `LIMIT`, or a value cached at open time.
  void onReady(Database db) {}

  void close() {
    try {
      _db?.close();
    } catch (e) {
      AppLogger.warning('DownloadedSqliteDb', 'close failed: $e');
    }
    _db = null;
    _ready = false;
  }
}

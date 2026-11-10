import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show FontLoader, ByteData;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'package:tawheeed/features/quran/mushaf/qcf4/qcf4_config.dart';
import 'package:tawheeed/features/quran/services/quran_storage.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Downloads + registers a QCF4 font so `Text(fontFamily: 'QCF4_Hafs_01')`
/// renders. QCF4 fonts are served as **TTF** (no GSUB/ligature table, so each
/// code point maps straight to one precomposed glyph — a plain `FontLoader`
/// renders them without any shaping engine):
///
///  1. If `{family}.ttf` is already on disk → load it directly.
///  2. Else download the TTF from the CDN, cache it, register it.
///
/// Fonts are kept in memory (`_loaded`) so a page render never re-downloads a
/// font it already has. Flutter does not let us truly unload a registered
/// font, but all 47 QCF4 fonts are ~92 MB in RAM once every page uses its own
/// font; we hold only the handful required per page plus QBSML before that.
class Qcf4FontLoader {
  Qcf4FontLoader._();

  static final Qcf4FontLoader instance = Qcf4FontLoader._();

  /// Font families successfully registered with the engine.
  final Set<String> _loaded = {};

  /// Set of families currently being fetched (prevents duplicate downloads).
  final Set<String> _inflight = {};

  /// Families that failed last time so we don't hammer the network.
  final Set<String> _failed = {};

  /// Test-only override for engine font registration (see [_registerBytes]).
  /// Always null in production.
  @visibleForTesting
  Future<bool> Function(String family, Uint8List bytes)? testRegisterHook;

  Directory? _fontsDir;
  Future<Directory> _dir() async {
    if (_fontsDir != null) return _fontsDir!;
    final root = await QuranStorage.contentDir();
    final dir = Directory(p.join(root.path, Qcf4Config.cacheDirName, 'fonts'));
    if (!await dir.exists()) await dir.create(recursive: true);
    _fontsDir = dir;
    return dir;
  }

  File _ttfFile(Directory dir, String family) =>
      File(p.join(dir.path, Qcf4Config.fontTtfFileName(family)));

  /// Whether [fontFamily] is already usable (registered).
  bool isLoaded(String fontFamily) => _loaded.contains(fontFamily);

  /// Whether this family is known to have failed (don't retry repeatedly).
  bool hasFailed(String fontFamily) => _failed.contains(fontFamily);

  /// Forget every recorded failure so a fresh `ensure` retries them. Called
  /// when the user starts (or resumes) a full download so a transient network
  /// blip does not permanently bash a font for the rest of the process.
  void clearFailed() => _failed.clear();

  /// Number of QCF4 TTF font files stored on disk (for the download manager's
  /// storage readout / resume info).
  Future<int> cachedFontCount() async {
    try {
      final dir = await _dir();
      if (!await dir.exists()) return 0;
      return dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.ttf'))
          .length;
    } catch (_) {
      AppLogger.warning('qcf4_font_loader', 'operation failed');
      return 0;
    }
  }

  /// Delete every cached TTF from disk and reset in-memory registration state,
  /// so a "delete downloaded mushaf data" removes fonts on the next restart.
  /// Currently-registered fonts stay live for this process but reload (or
  /// re-download) on the next `ensure`.
  Future<void> clearAll() async {
    _loaded.clear();
    _inflight.clear();
    _failed.clear();
    _fontsDir = null;
    try {
      final root = await QuranStorage.contentDir();
      final dir =
          Directory(p.join(root.path, Qcf4Config.cacheDirName, 'fonts'));
      if (await dir.exists()) {
        await for (final e in dir.list()) {
          if (e is File && e.path.endsWith('.ttf')) {
            await e.delete().catchError((_) => e);
          }
        }
      }
    } catch (e) {
      AppLogger.info('qcf4_font', 'clear fonts failed: $e');
    }
  }

  /// Ensure [fontFamily] is registered. Returns true on success.
  Future<bool> ensure(String fontFamily) async {
    if (_loaded.contains(fontFamily)) return true;
    if (_inflight.contains(fontFamily)) {
      // Wait for the in-flight load.
      while (_inflight.contains(fontFamily)) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return _loaded.contains(fontFamily);
    }
    if (_failed.contains(fontFamily)) return false;

    _inflight.add(fontFamily);
    try {
      final ok = await _loadFont(fontFamily);
      if (ok) {
        _loaded.add(fontFamily);
      } else {
        _failed.add(fontFamily);
      }
      return ok;
    } finally {
      _inflight.remove(fontFamily);
    }
  }

  Future<bool> _loadFont(String family) async {
    final dir = await _dir();
    final ttf = _ttfFile(dir, family);

    // 1) TTF already on disk.
    if (await ttf.exists()) {
      final ok = await _registerBytes(family, await ttf.readAsBytes());
      if (!ok) {
        // Corrupt/partial file: delete it so a later retry (after
        // clearFailed/restart) re-downloads fresh bytes instead of failing
        // on the same bad file forever.
        try {
          await ttf.delete();
        } catch (e) {
          AppLogger.info('qcf4_font', 'delete corrupt $family failed: $e');
        }
        _failed.remove(family);
      }
      return ok;
    }

    // 2) Network — short timeout + a few retries so a flaky connection does
    //    not kill the download on the first hiccup.
    Uint8List? bytes;
    for (var attempt = 0; attempt < 3 && bytes == null; attempt++) {
      if (attempt > 0) {
        await Future.delayed(const Duration(seconds: 2));
      }
      try {
        final res = await http
            .get(Uri.parse(Qcf4Config.fontTtfUrl(family)))
            .timeout(const Duration(seconds: 45));
        if (res.statusCode == 200) {
          bytes = res.bodyBytes;
        } else {
          AppLogger.info(
              'qcf4_font', '$family HTTP ${res.statusCode} (${attempt + 1}/3)');
        }
      } catch (e) {
        AppLogger.info('qcf4_font',
            'download $family attempt ${attempt + 1}/3 failed: $e');
      }
    }
    if (bytes == null) return false;

    try {
      // Audit 3.6: write to a .part sibling first, then atomically rename.
      // A kill mid-write previously left a truncated .ttf that failed font
      // registration on the next launch (self-healing existed, but every
      // launch until then showed a broken page).
      final part = File('${ttf.path}.part');
      await part.writeAsBytes(bytes, flush: true);
      await part.rename(ttf.path);
    } catch (e) {
      AppLogger.info('qcf4_font', 'write ttf failed: $e');
    }
    return _registerBytes(family, bytes);
  }

  Future<bool> _registerBytes(String family, Uint8List bytes) async {
    // Test hook: the test engine accepts any bytes as a valid font, so
    // failure paths (corrupt-file delete, _failed bookkeeping) are driven
    // through this override in unit tests.
    final hook = testRegisterHook;
    if (hook != null) return hook(family, bytes);
    try {
      final loader = FontLoader(family);
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
      return true;
    } catch (e) {
      AppLogger.info('qcf4_font', 'register $family failed: $e');
      return false;
    }
  }
}

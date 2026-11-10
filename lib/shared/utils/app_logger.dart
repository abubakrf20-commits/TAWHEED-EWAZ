// ignore_for_file: avoid_debug_print
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding, WidgetsBindingObserver, AppLifecycleState;
import 'package:path_provider/path_provider.dart';

/// Centralized logging utility for the Tawheed app.
/// Replaces silent catch blocks with proper logging.
///
/// Console output (`debugPrint`) is debug-only. Every entry is also buffered
/// in an in-memory ring (200 lines) and flushed to a capped on-device log
/// file in all builds (including release) so a crash can be diagnosed without
/// a debugger/logcat — without paying a disk flush on every hot-path log.
class AppLogger {
  AppLogger._();

  static const int _maxBytes = 150 * 1024;

  /// Fixed name (`trayheed_log.txt` was a typo kept for one migration step).
  static const String _fileName = 'tawheed_log.txt';
  static const String _legacyFileName = 'trayheed_log.txt';

  /// In-memory ring: hot-path logs never touch disk directly.
  static const int _ringCap = 200;
  static final List<String> _ring = [];

  /// Debounced flush (5s) + immediate flush on errors.
  static const Duration _flushDelay = Duration(seconds: 5);
  static Timer? _flushTimer;
  static Future<void> _flushChain = Future<void>.value();

  static bool _testModeChecked = false;
  static late bool _isFlutterTest;

  /// Audit P-10: a write failure used to vanish without a trace — the
  /// diagnostics page then showed an empty log with no explanation. This
  /// counter is deliberately NOT written through `AppLogger` (that would
  /// recurse); it is read directly by the diagnostics UI and by tests.
  static int _failedWrites = 0;
  static int get failedWrites => _failedWrites;

  /// Last write error, already scrubbed — never the raw exception.
  static String? _lastWriteError;
  static String? get lastWriteError => _lastWriteError;

  @visibleForTesting
  static void resetDiagnostics() {
    _failedWrites = 0;
    _lastWriteError = null;
  }

  static void _noteWriteFailure(Object error) {
    _failedWrites++;
    // Bounded, scrubbed, and never logged: a broken disk must not produce an
    // unbounded stream of error strings in memory either.
    final scrubbed = _scrub('$error');
    _lastWriteError = scrubbed.length > 200
        ? '${scrubbed.substring(0, 200)}…'
        : scrubbed;
  }

  /// Whether we run under `flutter test`. Set by the Flutter tool via the
  /// `FLUTTER_TEST` environment variable. Kept static-cached so tests never
  /// pay env lookup on every log.
  static bool get _inFlutterTest {
    if (!_testModeChecked) {
      try {
        _isFlutterTest = Platform.environment['FLUTTER_TEST'] == 'true';
      } catch (_) {
        // Env lookup unavailable (restricted platform) — assume tests off.
        _isFlutterTest = false;
      }
      _testModeChecked = true;
    }
    return _isFlutterTest;
  }

  /// Log an error with optional stack trace and context.
  static void error(String context, Object error, [StackTrace? stackTrace]) {
    final message = '$error${stackTrace != null ? '\n   $stackTrace' : ''}';
    if (kDebugMode) {
      // Audit P-10: console output must be scrubbed too — a debug build is
      // exactly where a developer copies a stack trace into a bug report.
      debugPrint('❌ [$context] ${_scrub('$error')}');
      if (stackTrace != null) debugPrint('   ${_scrub('$stackTrace')}');
    }
    _persist('❌', message, flushNow: true);
  }

  /// Log a warning with context.
  static void warning(String context, String message) {
    if (kDebugMode) debugPrint('⚠️ [$context] ${_scrub(message)}');
    _persist('⚠️', '$context · $message');
  }

  /// Log informational message with context.
  static void info(String context, String message) {
    if (kDebugMode) debugPrint('ℹ️ [$context] ${_scrub(message)}');
    _persist('ℹ️', '$context · $message');
  }

  /// Debug-only trace: console output in debug builds, NEVER persisted to the
  /// on-device file. For hot-path chatter (per-page fetch attempts, per-word
  /// audio retries) that would flood `tawheed_log.txt` while being useless
  /// there — the persistable trail belongs to the rarer warning/error lines.
  static void debug(String context, String message) {
    if (kDebugMode) debugPrint('🐛 [$context] ${_scrub(message)}');
  }

  /// Log a service operation success with context.
  static void success(String context, String message) {
    if (kDebugMode) debugPrint('✅ [$context] ${_scrub(message)}');
    _persist('✅', '$context · $message');
  }

  /// Flush any buffered lines to disk. Safe to call at shutdown checkpoints.
  static Future<void> flush() => _enqueueFlush();

  /// Audit U7-01: the 5s debounce normally outruns the process death that
  /// follows a user swiping the app away — the last window of log lines
  /// never reached disk, and the diagnostics page then showed a log that
  /// ended *before* whatever the user was reporting. The observer self-wires
  /// on the first persisted log (no `main.dart` touch needed) and flushes
  /// synchronously-enough on paused/hidden/inactive so the tail survives.
  static bool _lifecycleObserverAttached = false;

  static void _ensureLifecycleFlush() {
    if (_lifecycleObserverAttached) return;
    _lifecycleObserverAttached = true;
    try {
      WidgetsBinding.instance.addObserver(const _LogLifecycleObserver());
    } catch (_) {
      // No binding yet (pure-Dart test): the debounced flush still covers it.
    }
  }

  static void _persist(String level, String message, {bool flushNow = false}) {
    try {
      if (!_inFlutterTest) _ensureLifecycleFlush();
      final line =
          '[$level] ${DateTime.now().toIso8601String()} ${_scrub(message)}\n';
      _ring.add(line);
      if (_ring.length > _ringCap) {
        _ring.removeRange(0, _ring.length - _ringCap);
      }
      if (flushNow || _inFlutterTest) {
        // Under `flutter test` a debounce timer would outlive the test's fake
        // clock and trip the `!timersPending` assertion — flush directly
        // instead (file IO failing is best-effort and swallowed).
        unawaited(_enqueueFlush());
      } else {
        _flushTimer ??= Timer(_flushDelay, () {
          _flushTimer = null;
          unawaited(_enqueueFlush());
        });
      }
    } catch (e) {
      // Persisting must never break the caller — but it must be countable.
      _noteWriteFailure(e);
    }
  }

  /// Serializes flushes so concurrent triggers can't interleave writes.
  static Future<void> _enqueueFlush() {
    _flushChain = _flushChain.then((_) => _flushRing());
    return _flushChain;
  }

  static Future<void> _flushRing() async {
    if (_ring.isEmpty) return;
    final batch = _ring.join();
    _ring.clear();
    try {
      final dir = await getApplicationDocumentsDirectory();
      // One-time (idempotent) migration from the old typo'd file name.
      try {
        final legacy = File('${dir.path}/$_legacyFileName');
        final current = File('${dir.path}/$_fileName');
        if (await legacy.exists() && !await current.exists()) {
          await legacy.rename(current.path);
        }
      } catch (_) {
        // Legacy-rename is best-effort only.
      }
      final file = File('${dir.path}/$_fileName');
      try {
        if (await file.exists() && await file.length() > _maxBytes) {
          // Rotate: keep the newest half instead of wiping the whole log.
          final lines = await file.readAsLines();
          final keep = lines.length > 500
              ? lines.sublist(lines.length - 500)
              : <String>[];
          await file.writeAsString(keep.isEmpty ? '' : '${keep.join('\n')}\n',
              flush: true);
        }
      } catch (e) {
        // Log-rotation failure must not block the append below — but the
        // rotation loss is still a diagnostic fact.
        _noteWriteFailure(e);
      }
      await file.writeAsString(batch, mode: FileMode.append, flush: true);
    } catch (e) {
      // Best-effort only; the failure is surfaced via `failedWrites`.
      _noteWriteFailure(e);
    }
  }

  /// Absolute path of the on-device log file, or null when unavailable.
  /// Audit 7.5: the diagnostics page offers a "share logs" button wired
  /// to this — the missing link that kept perfect logs from ever reaching
  /// the developer.
  static Future<String?> logFilePath() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_fileName');
      final legacy = File('${dir.path}/$_legacyFileName');
      if (await file.exists()) return file.path;
      if (await legacy.exists()) return legacy.path;
      return null;
    } catch (_) {
      // Filesystem unavailable (tests / restricted profile): there is
      // no log path to report — logging the failure would recurse.
      return null;
    }
  }

  /// Full log content (capped at [maxChars] tail) or null when missing.
  static Future<String?> readLogs({int maxChars = 100 * 1024}) async {
    try {
      final path = await logFilePath();
      if (path == null) return null;
      final file = File(path);
      final text = await file.readAsString();
      return text.length > maxChars
          ? text.substring(text.length - maxChars)
          : text;
    } catch (_) {
      // Read failure (locked / deleted file): diagnostics degrades to an
      // empty log — logging the failure here would recurse.
      return null;
    }
  }

  /// Scrubs likely-PII so logs shared from the diagnostics screen don't leak
  /// user data. Audit P-10 widened this from "email + 8+ Western digits" to
  /// Persian/Arabic-Indic digits, key=value secrets, and city labels.
  ///
  /// Free-text Persian *names* cannot be recognised reliably by a regex; the
  /// real defence for those is not logging them at all (see the share opt-out
  /// and the Home privacy mode from the same audit).
  static final RegExp _emailRe =
      RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}');
  static final RegExp _secretRe = RegExp(
      r'\b(?:token|uid|user_?id|api[_-]?key|password|passwd|secret|session|auth|bearer)\b\s*[:=]\s*\S+',
      caseSensitive: false);
  static final RegExp _cityLabelRe =
      RegExp(r'شهر\s*[:：]\s*[^\s,،\n]+');
  static final RegExp _cityKeyRe = RegExp(
      r'\b(?:city|cityName|location|coords?)\s*[:=]\s*\S+',
      caseSensitive: false);
  static final RegExp _digitsRe =
      RegExp(r'[0-9\u0660-\u0669\u06F0-\u06F9]{7,}');

  static String _scrub(String message) {
    var out = message.replaceAll(_emailRe, '[email]');
    out = out.replaceAll(_secretRe, '[secret]');
    out = out.replaceAllMapped(
        _cityLabelRe, (_) => 'شهر: [city]');
    out = out.replaceAll(_cityKeyRe, '[location]');
    out = out.replaceAll(_digitsRe, '[digits]');
    return out;
  }
}

/// Flushes the log ring when the app leaves the foreground. Const so the
/// observer itself carries no state; all state lives in [AppLogger].
class _LogLifecycleObserver with WidgetsBindingObserver {
  const _LogLifecycleObserver();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
        // The debounced timer may never fire under process death; an
        // explicit flush on every leave-foreground step keeps the loss
        // window at the few lines logged after this point.
        unawaited(AppLogger.flush());
      case AppLifecycleState.resumed:
        break;
    }
  }
}

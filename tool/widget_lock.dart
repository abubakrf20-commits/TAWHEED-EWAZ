// The widget lock's engine: hashes the prayer + tasbih widget sources and
// compares them with the committed manifest.
//
// This is a TRIPWIRE, not a security boundary. It cannot stop someone who
// decides to run `--update`; what it does is make every change to a widget
// file fail a test and show up as an explicit, dated line in
// WIDGET_LOCK_LOG.md with a stated reason. That is exactly the contract the
// user asked for: «هیچ دستیاری بدون اجازهٔ صریح ویجت را دستکاری نکند».
//
//   dart run tool/widget_lock.dart            # verify (exit 1 on drift)
//   dart run tool/widget_lock.dart --update --reason "…"   # re-lock
//
// See WIDGET_LOCK.md.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const String manifestPath = 'widget_lock.json';
const String logPath = 'WIDGET_LOCK_LOG.md';

/// What the lock covers: the two home-screen widgets and the pipeline that
/// feeds them. A trailing `/` means «every .kt/.dart below this directory».
///
/// Deliberately NOT covered:
///  * `assets/widget_palettes.json` — user-facing palette data, meant to be
///    tuned;
///  * `widget_settings_screen.dart` — the settings UI, not the widget.
const List<String> protectedPaths = <String>[
  'android/app/src/main/kotlin/com/islamic/tawheeed/widget/',
  'lib/features/prayer/presentation/widgets/prayer_widget_preview.dart',
  'lib/features/adhkar/tasbih/presentation/widgets/tasbih_widget_preview.dart',
  'lib/features/home/services/widget_bridge.dart',
  'lib/features/home/services/widget_sync.dart',
  'lib/shared/services/widget_sync_service.dart',
];

const Set<String> _extensions = {'.kt', '.dart'};

/// path → sha256, for every file the lock covers. Sorted, so the manifest is
/// stable and a diff means a real change.
Map<String, String> computeHashes({String root = '.'}) {
  final out = <String, String>{};
  for (final entry in protectedPaths) {
    final full = '$root/$entry';
    if (entry.endsWith('/')) {
      final dir = Directory(full);
      if (!dir.existsSync()) continue;
      for (final f in dir.listSync(recursive: true).whereType<File>()) {
        final name = f.path.replaceAll('\\', '/');
        if (!_extensions.any(name.endsWith)) continue;
        out[_relativise(name, root)] = _sha256(f);
      }
    } else {
      final f = File(full);
      if (f.existsSync()) out[entry] = _sha256(f);
    }
  }
  final keys = out.keys.toList()..sort();
  return {for (final k in keys) k: out[k]!};
}

class LockReport {
  const LockReport({
    required this.changed,
    required this.added,
    required this.missing,
    required this.checked,
  });

  /// Same path, different bytes — the thing the lock exists to catch.
  final List<String> changed;

  /// A file under a protected directory that the manifest has never seen.
  final List<String> added;

  /// Locked in the manifest but gone from disk.
  final List<String> missing;

  final int checked;

  bool get isClean => changed.isEmpty && added.isEmpty && missing.isEmpty;

  List<String> get problems => [...changed, ...added, ...missing];
}

/// Compares the tree against [manifestPath]. A missing manifest is itself a
/// failure: it would silently pass every check otherwise.
LockReport verifyLock({String root = '.'}) {
  final file = File('$root/$manifestPath');
  if (!file.existsSync()) {
    return const LockReport(
      changed: [],
      added: [],
      missing: ['$manifestPath (the manifest itself)'],
      checked: 0,
    );
  }
  final manifest = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final locked = (manifest['files'] as Map).cast<String, String>();
  final now = computeHashes(root: root);

  final changed = <String>[];
  final added = <String>[];
  final missing = <String>[];
  for (final e in now.entries) {
    final was = locked[e.key];
    if (was == null) {
      added.add(e.key);
    } else if (was != e.value) {
      changed.add(e.key);
    }
  }
  for (final k in locked.keys) {
    if (!now.containsKey(k)) missing.add(k);
  }
  changed.sort();
  added.sort();
  missing.sort();
  return LockReport(
    changed: changed,
    added: added,
    missing: missing,
    checked: now.length,
  );
}

/// Re-locks the tree and appends the reason to [logPath].
///
/// [reason] is not optional in spirit: an unlock with no stated reason is the
/// thing this file exists to prevent, so an empty one is refused.
void updateLock({required String reason, String root = '.'}) {
  if (reason.trim().isEmpty) {
    throw ArgumentError('A re-lock needs --reason "…": say who allowed it and '
        'why the widget had to change.');
  }
  final hashes = computeHashes(root: root);
  final manifest = <String, Object>{
    'version': 1,
    'lockedAt': DateTime.now().toIso8601String(),
    'policy': 'WIDGET_LOCK.md',
    'note': 'Do not edit by hand. dart run tool/widget_lock.dart --update '
        '--reason "…"',
    'files': hashes,
  };
  File('$root/$manifestPath')
      .writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(manifest)}\n');

  final log = File('$root/$logPath');
  final stamp = DateTime.now().toIso8601String();
  log.writeAsStringSync(
    '- $stamp — ${hashes.length} files re-locked — $reason\n',
    mode: FileMode.append,
  );
}

String _relativise(String path, String root) {
  final p = path.replaceAll('\\', '/');
  if (root == '.') return p.startsWith('./') ? p.substring(2) : p;
  final prefix = '${root.replaceAll('\\', '/')}/';
  return p.startsWith(prefix) ? p.substring(prefix.length) : p;
}

String _sha256(File f) => digestOfBytes(f.readAsBytesSync());

/// sha256 of [bytes] once the things that are not source are removed.
///
/// The lock guards *code*, not the bytes a checkout happens to write. This
/// repo is worked on from several Windows worktrees at once, and
/// `core.autocrlf` gives each of them different line endings for the same
/// committed blob. Hashing raw bytes then reported the untouched
/// `IslamicCalendars.kt` / `WidgetTiming.kt` / `PrayerTimesCalculator.kt` as
/// «changed» purely because one worktree wrote CRLF where another wrote LF —
/// a tripwire that cries wolf is worse than none, because it trains everyone
/// to ignore it. So: strip a UTF-8 BOM, drop the CR of every CRLF pair, keep
/// lone CRs (they are content), then hash. Any real edit still trips it.
String digestOfBytes(List<int> bytes) {
  var start = 0;
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    start = 3;
  }
  final normalised = <int>[];
  for (var i = start; i < bytes.length; i++) {
    final b = bytes[i];
    if (b == 0x0D && i + 1 < bytes.length && bytes[i + 1] == 0x0A) continue;
    normalised.add(b);
  }
  return sha256.convert(normalised).toString();
}

Future<void> main(List<String> args) async {
  final update = args.contains('--update');
  if (update) {
    final i = args.indexOf('--reason');
    final reason = i >= 0 && i + 1 < args.length ? args[i + 1] : '';
    updateLock(reason: reason);
    stdout.writeln('widget lock updated — see $logPath');
    return;
  }
  final report = verifyLock();
  if (report.isClean) {
    stdout.writeln('widget lock OK (${report.checked} files)');
    return;
  }
  stderr.writeln('WIDGET LOCK VIOLATED — ${report.problems.length} file(s).');
  for (final p in report.changed) {
    stderr.writeln('  changed: $p');
  }
  for (final p in report.added) {
    stderr.writeln('  added:   $p');
  }
  for (final p in report.missing) {
    stderr.writeln('  missing: $p');
  }
  stderr.writeln('');
  stderr.writeln('The prayer and tasbih widgets are locked: do not touch them '
      'without the user\'s explicit permission (see WIDGET_LOCK.md). With that '
      'permission, re-lock with a stated reason:');
  stderr.writeln('  dart run tool/widget_lock.dart --update --reason "…"');
  exitCode = 1;
}

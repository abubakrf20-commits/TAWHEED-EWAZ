// tool/check_import_lints.dart
//
// Import/layering lint for the Tawheed Flutter repo.
//
// Usage (from the repo root):
//   dart run tool/check_import_lints.dart
//
// Checks:
//   1. domain/ files must not import package:flutter.
//      (Known debt is allowlisted below; new violations fail the run.)
//   2. domain/ files must not import features/<x>/data or
//      features/<x>/presentation.
//   3. Known-bad cross-feature pairs are forbidden in BOTH directions.
//      A file inside feature A importing feature B fails when {A, B} is in
//      _badPairs — regardless of direction.
//
// Escape hatch: append `// import-lint-allow: <reason>` to a violating
// import line to suppress that single line (use sparingly, reference a
// tracking note).
//
// Exits non-zero when any violation is found (CI-friendly).

import 'dart:io';

/// Feature imports that violate rule 1 despite being known debt.
/// Remove entries once the underlying debt is fixed.
const _rule1Allowlist = <String>{
  // Entity keeps an IconData convenience field; tracked in
  // docs/FEATURE_CONTRACT.md (domain must become Flutter-free).
  'lib/features/worship/domain/entities/worship_item.dart',
};

/// Unordered feature pairs that must never import each other, in either
/// direction. Only add pairs that are currently clean — adding a pair that
/// has an existing import will fail every run until the import is removed.
const _badPairs = <(String, String)>[
  // Isolated/tool-ish features must not couple into the main app graph.
  ('tasks', 'settings'),
  ('tasks', 'home'),
  ('tasks', 'prayer'),
  ('tasks', 'quran'),
  ('tasks', 'adhkar'),
  ('tasks', 'worship'),
  ('tasks', 'books'),
  ('expenses', 'home'),
  ('expenses', 'settings'),
  ('expenses', 'worship'),
  ('expenses', 'prayer'),
  ('fatwa', 'settings'),
  ('fatwa', 'home'),
  ('notes', 'settings'),
  ('notes', 'home'),
  ('notes', 'prayer'),
  ('splash', 'home'),
  ('suggestions', 'settings'),
  ('suggestions', 'home'),
  ('riyad', 'settings'),
  ('yaqeen', 'settings'),
  ('yaqeen', 'home'),
  ('audio_library', 'settings'),
  ('audio_library', 'home'),
  ('hadeeth_enc', 'settings'),
  ('dua_from_quran', 'settings'),
  ('dua_from_quran', 'home'),
  ('onboarding', 'home'),
  ('checklist', 'settings'),
  ('checklist', 'prayer'),
  ('hifz', 'settings'),
  ('khatm', 'home'),
  ('ruqyah', 'settings'),
  ('hajj_umrah', 'settings'),
  ('ramadan', 'home'),
  ('search', 'settings'),
  ('worship', 'quran'),
  ('education', 'settings'),
  ('books', 'prayer'),
  ('books', 'worship'),
  ('hadith', 'settings'),
];

final _featureImportRe =
    RegExp(r"import\s+'package:tawheeed/features/([^/]+)/([^']*)'");
final _flutterImportRe = RegExp(r"import\s+'package:flutter/");

void main() {
  final featuresDir = Directory('lib/features');
  if (!featuresDir.existsSync()) {
    stderr.writeln('error: run from the repository root (lib/features not found).');
    exit(2);
  }

  final violations = <String>[];
  final dartFiles = featuresDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  for (final file in dartFiles) {
    final relPath = file.path.replaceAll('\\', '/');
    final isDomain = relPath.contains('/domain/');
    final feature = _featureOf(relPath);
    final lines = file.readAsLinesSync();

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (!line.contains('import ')) continue;
      if (line.contains('import-lint-allow')) continue;

      // Rule 1: domain must not import Flutter.
      if (isDomain &&
          _flutterImportRe.hasMatch(line) &&
          !_rule1Allowlist.contains(relPath)) {
        violations.add('$relPath:${i + 1}: domain imports Flutter — $line');
      }

      final match = _featureImportRe.firstMatch(line);
      if (match == null) continue;
      final targetFeature = match.group(1)!;
      final targetRest = match.group(2)!;

      // Rule 2: domain must not import other layers of a feature.
      if (isDomain &&
          (targetRest.startsWith('data/') ||
              targetRest.startsWith('presentation/'))) {
        violations
            .add('$relPath:${i + 1}: domain imports $targetFeature/$targetRest — $line');
      }

      // Rule 3: known-bad cross-feature pairs (both directions).
      if (feature != null && targetFeature != feature) {
        if (_isBadPair(feature, targetFeature)) {
          violations.add(
              '$relPath:${i + 1}: forbidden feature pair {$feature, $targetFeature} — $line');
        }
      }
    }
  }

  if (violations.isEmpty) {
    stdout.writeln('check_import_lints: OK');
    return;
  }

  stderr.writeln('check_import_lints: ${violations.length} violation(s):');
  for (final v in violations) {
    stderr.writeln('  $v');
  }
  exit(1);
}

String? _featureOf(String relPath) {
  final m = RegExp(r'^lib/features/([^/]+)/').firstMatch(relPath);
  return m?.group(1);
}

bool _isBadPair(String a, String b) {
  for (final pair in _badPairs) {
    if ((pair.$1 == a && pair.$2 == b) || (pair.$1 == b && pair.$2 == a)) {
      return true;
    }
  }
  return false;
}

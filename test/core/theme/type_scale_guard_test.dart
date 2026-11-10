import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/theme/theme.dart';

/// The app's typography is a single closed set of steps (`AppTheme.typeScale`).
/// Every size should sit on it, so the whole app feels proportional and the
/// «اندازه فونت» setting scales a coherent scale rather than a scatter of
/// one-off numbers.
///
/// This scans the source rather than the rendered tree on purpose: a hardcoded
/// `fontSize: 13.5` is invisible to widget tests (it renders fine) but it is
/// exactly the drift that made sizes inconsistent across the app.
void main() {
  test('the type scale is sorted and unique', () {
    const scale = AppTheme.typeScale;
    expect(scale, isNotEmpty);
    expect(scale.toSet().length, scale.length, reason: 'no duplicate steps');
    for (var i = 1; i < scale.length; i++) {
      expect(scale[i], greaterThan(scale[i - 1]), reason: 'must ascend');
    }
  });

  test('no hardcoded fontSize in lib sits outside the type scale', () {
    const themeFile = 'core/theme/theme.dart'; // defines the scale itself
    // A whole-number literal right after `fontSize:` — deliberately NOT
    // matching `fontSize: someVar`, `fontSize: 12 * fontScale` or
    // `fontSize: AppTheme.scaledFontSize(...)`.
    final pattern = RegExp(r'fontSize:\s*(\d+(?:\.\d+)?)\s*(?=[,)\r\n]|$)');
    final allowed = AppTheme.typeScale.toSet();
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (!path.endsWith('.dart') || path.endsWith('.g.dart')) continue;
      if (path.endsWith(themeFile)) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final trimmed = lines[i].trimLeft();
        if (trimmed.startsWith('//') ||
            trimmed.startsWith('*') ||
            trimmed.startsWith('/*')) {
          continue;
        }
        for (final match in pattern.allMatches(lines[i])) {
          final value = double.parse(match.group(1)!);
          if (!allowed.contains(value)) {
            offenders.add('$path:${i + 1}  fontSize: $value');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'These sizes are off the shared scale (${AppTheme.typeScale}) — '
          'use `AppTheme.scaledFontSize(context, <step>)` instead:\n'
          '${offenders.join('\n')}',
    );
  });
}

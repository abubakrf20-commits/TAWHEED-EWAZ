import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Audit B-02: six `Image.file` sites in personal_info decoded photos at full
/// resolution — a phone photo costs tens of MB, and the thumbnail strips build
/// several at once, so the section jumped in memory and janked. Every site now
/// asks for a `cacheWidth` derived from the drawn size × devicePixelRatio;
/// this guard fails when a new decode path appears without one.
void main() {
  List<File> sectionSources() => Directory('lib/features/personal_info')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  /// Returns the full argument text of each `Image.file(` call, matching
  /// parentheses so a nested `Container(width: …)` cannot truncate the region.
  List<String> imageFileArguments(String source) {
    final calls = <String>[];
    var from = 0;
    while (true) {
      final start = source.indexOf('Image.file(', from);
      if (start < 0) break;
      var depth = 0;
      var end = start + 'Image.file'.length;
      for (; end < source.length; end++) {
        final ch = source[end];
        if (ch == '(') depth++;
        if (ch == ')') {
          depth--;
          if (depth == 0) {
            end++;
            break;
          }
        }
      }
      calls.add(source.substring(start, end));
      from = end;
    }
    return calls;
  }

  test('every Image.file in personal_info asks for a cacheWidth', () {
    final files = sectionSources();
    expect(files, isNotEmpty);

    final offenders = <String>[];
    var checked = 0;
    for (final file in files) {
      for (final call in imageFileArguments(file.readAsStringSync())) {
        checked++;
        if (!call.contains('cacheWidth:')) {
          offenders.add('${file.path}: ${call.split('\n').first.trim()}');
        }
      }
    }

    expect(checked, greaterThan(0),
        reason: 'the matcher found no Image.file call — the guard would pass '
            'vacuously; verify the call spelling before trusting it');
    expect(offenders, isEmpty,
        reason: 'decode at the drawn size, not the file size:\n'
            '${offenders.join('\n')}');
  });

  test('no alternate full-resolution image decode path sneaks in', () {
    final offenders = <String>[];
    for (final file in sectionSources()) {
      final source = file.readAsStringSync();
      if (source.contains('FileImage(') || source.contains('MemoryImage(')) {
        offenders.add(file.path);
      }
    }

    expect(offenders, isEmpty,
        reason: 'Image(image: FileImage(…)) bypasses the Image.file cacheWidth '
            'budget; use Image.file(…, cacheWidth: …) instead:\n'
            '${offenders.join('\n')}');
  });
}

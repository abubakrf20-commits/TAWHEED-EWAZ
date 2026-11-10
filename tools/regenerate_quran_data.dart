// Regenerates lib/features/quran/data/quran_data.dart keeping only the
// fields actually read by the app (sora, aya_no, aya_text, aya_text_emlaey).
//
// Run from the project root:  dart run tools/regenerate_quran_data.dart
//
// The previous file shipped ~9 fields per verse (id, jozz, sora_name_en,
// sora_name_ar, page, line_start, line_end, aya_text_othmanic, qcfData) that
// nothing reads. Those strings (Othmanic PUA text + QCF glyph codes) were the
// bulk of the 6.3 MB source, so pruning them shrinks the AOT snapshot inside
// libapp.so and reduces runtime memory. The data itself is untouched.

// ignore_for_file: avoid_relative_lib_imports, avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:tawheeed/features/quran/data/quran_data.dart';

const liveKeys = ['sora', 'aya_no', 'aya_text', 'aya_text_emlaey'];

void main() {
  final buffer = StringBuffer()
    ..writeln('// ignore_for_file: prefer_single_quotes, prefer_double_quotes')
    ..writeln('const List quran = [');

  var count = 0;
  for (final aya in quran) {
    buffer.write('  {\n');
    for (final key in liveKeys) {
      final value = aya[key];
      if (value == null) {
        throw StateError('missing key $key in verse $count');
      }
      if (value is int) {
        buffer.writeln('    "$key": $value,');
      } else if (value is String) {
        buffer.writeln('    "$key": ${jsonEncode(value)},');
      } else {
        throw StateError('unexpected type for $key: ${value.runtimeType}');
      }
    }
    buffer.writeln('  },');
    count++;
  }
  buffer.writeln('];');

  final outPath =
      File('lib/features/quran/data/quran_data.dart').absolute.path;
  File(outPath).writeAsStringSync(buffer.toString());
  print('regenerated $outPath with $count verses '
      '(${(buffer.length / 1048576).toStringAsFixed(2)} MB)');
}
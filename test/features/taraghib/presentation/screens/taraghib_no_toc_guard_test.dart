import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The edition's فهرست مطالب is NOT part of this section (user request,
/// 2026-10-27: «فهرست مطالب را حذف کنید»). It repeated the book and باب list
/// the browse page already shows, so the builder stores no `toc` matter rows
/// and nothing in the app may offer or render one.
///
/// This is a source scan, the repo's idiom for a "must not come back"
/// invariant (see `test/app/router/tab_page_header_guard_test.dart`). It
/// targets code tokens, never the Persian phrase: the browse page's doc
/// comment legitimately explains the removal by name.
String _stripComments(String source) => source.split('\n').map((line) {
      final i = line.indexOf('//');
      return i < 0 ? line : line.substring(0, i);
    }).join('\n');

/// `toc` as its own word plus the builder's `toc_vol9/10/11` ids.
final _tocToken = RegExp(r'\btoc\b|toc_vol');

void main() {
  test('no taraghib source mentions a toc section', () {
    final offenders = <String>[];
    for (final entity in Directory('lib/features/taraghib')
        .listSync(recursive: true)
        .whereType<File>()) {
      if (!entity.path.endsWith('.dart')) continue;
      final src = _stripComments(entity.readAsStringSync());
      if (_tocToken.hasMatch(src)) offenders.add(entity.path);
    }
    expect(
      offenders,
      isEmpty,
      reason: 'a toc section must not be stored, offered or rendered',
    );
  });

  test('the deep search reads no toc source', () {
    final src = _stripComments(
      File('lib/features/search/services/more_content_search.dart')
          .readAsStringSync(),
    );
    expect(_tocToken.hasMatch(src), isFalse);
  });

  test('the browse page partitions matters by intro and khatimah only', () {
    final src = _stripComments(
      File('lib/features/taraghib/presentation/screens/taraghib_screen.dart')
          .readAsStringSync(),
    );
    final kinds = RegExp(r"""\['kind'\]\s*==\s*'([a-z_]+)'""")
        .allMatches(src)
        .map((m) => m.group(1))
        .toSet();
    expect(kinds, {'intro', 'khatimah'});
  });
}

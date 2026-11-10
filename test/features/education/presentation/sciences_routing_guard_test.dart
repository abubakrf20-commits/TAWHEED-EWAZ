import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/app/router/route_names.dart';

/// The science detail view (`/sciences/:id`) is a GoRouter route wrapped in the
/// ambient background (`app_router.dart` `_ambient`). A raw `Navigator.push`
/// leaves the router branch behind, so the detail screen's transparent scaffold
/// ends up painting the bare window — the reported "light theme but black
/// background" bug inside علوم اسلامی. Every science navigation must therefore
/// go through `context.push`.
String _withoutComments(String source) => source.split('\n').map((line) {
      final comment = line.indexOf('//');
      return comment < 0 ? line : line.substring(0, comment);
    }).join('\n');

void main() {
  test('the education screens never push a screen by themselves', () {
    final offenders = <String>[];
    for (final file in Directory('lib/features/education')
        .listSync(recursive: true)
        .whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final code = _withoutComments(file.readAsStringSync());
      if (code.contains('Navigator.push')) offenders.add(file.path);
    }
    expect(offenders, isEmpty,
        reason: 'science pages must reach each other through context.push, or '
            'the ambient background is lost and the page renders black');
  });

  test('every science screen routes through the path helper', () {
    for (final path in const [
      'lib/features/education/presentation/screens/sciences_home_screen.dart',
      'lib/features/education/presentation/screens/science_detail_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('context.push'),
          reason: '$path must navigate with context.push');
      expect(source, contains('RouteNames.scienceDetailPath'),
          reason: '$path must build the location through the path helper');
    }
  });

  test('the detail route stays ambient-wrapped', () {
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    expect(router, contains('RouteNames.scienceDetail'));
    expect(router, contains('_ambient(ScienceDetailScreen'));
  });

  test('the path helper builds a concrete location', () {
    expect(RouteNames.scienceDetailPath('tafsir'), '/sciences/tafsir');
    expect(RouteNames.scienceDetail, '/sciences/:id');
  });
}

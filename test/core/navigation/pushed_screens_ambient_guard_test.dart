import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Transparent scaffolds pushed via `Navigator.push` leave the GoRouter branch
/// (and its `AmbientBackground`) behind, so they paint the bare window — the
/// reported black-background class (sciences, calendar converter, and now the
/// inner hadith/share/stats pages). Every such page must either self-wrap in
/// `AmbientBackground` (share screens) or be wrapped at its push site
/// (hadith detail/list/chapter/search, reading stats).
String _withoutComments(String source) => source.split('\n').map((line) {
      final comment = line.indexOf('//');
      return comment < 0 ? line : line.substring(0, comment);
    }).join('\n');

/// True when [file] builds [widget] only inside an `AmbientBackground`.
/// Class/constructor declarations are skipped — only build sites (arrow
/// builders pushing a route) count.
bool _wrappedInAmbient(File file, String widget) {
  final lines = _withoutComments(file.readAsStringSync()).split('\n');
  var checked = 0;
  for (var i = 0; i < lines.length; i++) {
    if (!lines[i].contains('$widget(')) continue;
    // Class and constructor declarations are not build sites.
    if (RegExp('^\\s*(class|const)\\s+$widget').hasMatch(lines[i])) continue;
    final lo = i - 3 < 0 ? 0 : i - 3;
    final hi = i + 4 > lines.length ? lines.length : i + 4;
    final window = lines.sublist(lo, hi).join('\n');
    if (!window.contains('=>') && !window.contains('builder:')) continue;
    checked++;
    if (!window.contains('AmbientBackground(')) return false;
  }
  return checked > 0;
}

void main() {
  group('share screens self-wrap the ambient background', () {
    const selfWrapped = [
      'lib/features/adhkar/duas/presentation/screens/dua_share_screen.dart',
      'lib/features/adhkar/presentation/screens/adhkar_share_screen.dart',
      'lib/features/dua_from_quran/presentation/screens/dua_from_quran_share_screen.dart',
    ];
    for (final path in selfWrapped) {
      test('$path returns AmbientBackground', () {
        final source = File(path).readAsStringSync();
        expect(source, contains('return AmbientBackground('),
            reason: '$path must self-wrap: it is pushed via Navigator.push '
                'outside the router');
        // The scaffold stays transparent (the ambient shows through); the fix
        // must never become a hardcoded background color.
        expect(source, contains('backgroundColor: Colors.transparent'));
      });
    }
  });

  group('hadith inner pages are wrapped at their push sites', () {
    const targets = [
      'HadithBookDetailScreen',
      'HadithListAllScreen',
      'HadithChapterScreen',
      'HadithSearchResultsScreen',
    ];
    final file = File(
        'lib/features/hadith/presentation/screens/hadith_books_screen.dart');
    for (final widget in targets) {
      test('$widget is only built inside AmbientBackground', () {
        expect(_wrappedInAmbient(file, widget), isTrue,
            reason: '$widget is a transparent scaffold pushed via '
                'Navigator.push — an unwrapped site paints black');
      });
    }
  });

  test('ReadingStatsScreen is only built inside AmbientBackground', () {
    final file = File(
        'lib/features/books/presentation/screens/ketabkhaneh_screen.dart');
    expect(_wrappedInAmbient(file, 'ReadingStatsScreen'), isTrue,
        reason: 'ReadingStatsScreen is a transparent scaffold pushed via '
            'Navigator.push — an unwrapped site paints black');
  });

  test('the app builder wraps the whole navigator in the ambient', () {
    // The router's per-route `_ambient` cannot cover a raw `Navigator.push`:
    // the pushed page is opaque, so the ambient route below it is never
    // painted. The ROOT wrap in main.dart is what keeps a transparent pushed
    // scaffold from showing the platform window — the reported black
    // background. Pin the nesting so the protection cannot be refactored away.
    final source = File('lib/main.dart').readAsStringSync();
    final builderAt = source.indexOf('builder: (context, child)');
    expect(builderAt, greaterThan(-1),
        reason: 'the app builder is still the one place every route passes');

    final windowEnd =
        builderAt + 300 > source.length ? source.length : builderAt + 300;
    final window = source.substring(builderAt, windowEnd);
    final ambientAt = window.indexOf('AmbientBackground(');
    final scaleAt = window.indexOf('AppTextScale(');
    expect(ambientAt, greaterThan(-1),
        reason: 'main.dart must wrap the navigator in AmbientBackground');
    expect(scaleAt, greaterThan(-1),
        reason: 'the single root TextScaler must stay in the builder');
    expect(ambientAt, lessThan(scaleAt),
        reason: 'the ambient must be the OUTERMOST wrap — inside the TextScaler '
            'it would sit above the navigator and be covered by it');
  });

  test('opaque pushed screens need no wrap (documents the boundary)', () {
    // BookReaderScreen uses an opaque themed scaffold, so Navigator.push is
    // harmless for it. DuaDetailScreen used to be listed here too, but the
    // flat-language pass (9bb7fce) made it transparent — that is safe
    // because the ROOT wrap pinned above covers every route, pushed or
    // routed, so it does not need a per-site wrap. AdhkarCategoryPage left
    // this list earlier by moving onto the router (RouteNames.azkarCategory)
    // instead of Navigator.push.
    for (final path in const [
      'lib/features/books/presentation/screens/book_reader_screen.dart',
    ]) {
      final source = _withoutComments(File(path).readAsStringSync());
      expect(source.contains('backgroundColor: Colors.transparent'), isFalse,
          reason: '$path must stay opaque, or it needs an ambient wrap too');
    }
  });

  test('the home timeline pages travel on the router, not Navigator.push',
      () {
    // actions_timeline_card.dart and adhkar_category_page.dart must not
    // contain a Navigator.push: both destinations are GoRoutes now, and a
    // raw push would leave the router branch (and its ambient) behind.
    for (final path in const [
      'lib/features/home/presentation/widgets/actions_timeline_card.dart',
      'lib/features/home/presentation/widgets/adhkar_category_page.dart',
    ]) {
      final source = _withoutComments(File(path).readAsStringSync());
      expect(source.contains('Navigator.push'), isFalse,
          reason: '$path must navigate with context.push');
    }
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    expect(router.contains('RouteNames.azkarCategory'), isTrue,
        reason: 'the category destination must be a registered route');
    expect(router.contains('RouteNames.azkarShare'), isTrue,
        reason: 'the share destination must be a registered route');
  });
}

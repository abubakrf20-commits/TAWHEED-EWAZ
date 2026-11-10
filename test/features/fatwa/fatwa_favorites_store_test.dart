import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the fatwa favorites migration: the screen used to hand-roll its
/// SharedPreferences reads/writes, duplicating [FavoritesStore] (which was
/// generalized from fatwa's own pattern but never adopted back). The screen
/// must persist through the store, keep integer ids in memory, and keep the
/// on-disk format (sorted string list) unchanged so existing favorites
/// survive the migration byte-for-byte.
///
/// Source-level guard in the repo's established style: pumping FatwaScreen
/// needs its database, while the wiring is what must not regress.
Future<String> readSource(String path) async =>
    (await File(path).readAsString()).replaceAll('\r\n', '\n');

void main() {
  test('fatwa favorites persist through the shared store', () async {
    final source = await readSource(
        'lib/features/fatwa/presentation/screens/fatwa_screen.dart');
    expect(source.contains('FavoritesStore.load(_favKey)'), isTrue,
        reason: 'loading must go through the shared store');
    expect(source.contains('FavoritesStore.save(_favKey,'), isTrue,
        reason: 'toggling must go through the shared store');
    expect(
        source.contains('SharedPreferences.getInstance()'), isFalse,
        reason: 'no hand-rolled prefs access may remain on this screen');
  });

  test('fatwa accent comes from the shared topic hue', () async {
    final source = await readSource(
        'lib/features/fatwa/presentation/screens/fatwa_screen.dart');
    expect(source.contains('TopicHues.fatwa'), isTrue,
        reason: 'the accent must be the single-source hue, not a literal');
    expect(source.contains('Color(0xFF00695C)'), isFalse,
        reason: 'no raw copy of the hue may remain on this screen');
  });
}

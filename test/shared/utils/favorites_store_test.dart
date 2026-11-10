import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/shared/utils/favorites_store.dart';

/// The shared string-id favorites store behind the hadith/dua/fatwa
/// favorite chips: round-trips, toggle semantics and corrupt-entry
/// tolerance (a bad row must never crash a screen).
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('load returns empty when nothing is stored', () async {
    expect(await FavoritesStore.load('k'), isEmpty);
  });

  test('save then load round-trips the ids', () async {
    await FavoritesStore.save('k', {'b', 'a'});
    expect(await FavoritesStore.load('k'), {'a', 'b'});
  });

  test('toggle adds then removes', () async {
    expect(await FavoritesStore.toggle('k', 'x'), {'x'});
    expect(await FavoritesStore.toggle('k', 'x'), isEmpty);
  });

  test('blank and whitespace-only rows are dropped', () async {
    SharedPreferences.setMockInitialValues({
      'k': ['ok', '', '   '],
    });
    expect(await FavoritesStore.load('k'), {'ok'});
  });
}

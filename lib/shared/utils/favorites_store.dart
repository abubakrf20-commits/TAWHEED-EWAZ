import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Tiny string-id favorites store (the fatwa `Set<int>` pattern generalized).
///
/// Ids are strings so every feature (hadith ids, dua keys, lesson ids) shares
/// one implementation. Corrupt entries are dropped with `tryParse`-style
/// tolerance instead of crashing the screen (see the old fatwa `int.parse`
/// failure mode).
class FavoritesStore {
  FavoritesStore._();

  /// Loads the id set for [key]. Never throws — returns empty on any failure.
  static Future<Set<String>> load(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(key);
      if (list == null) return {};
      return list.where((e) => e.trim().isNotEmpty).toSet();
    } catch (_) {
      AppLogger.warning('favorites_store', 'operation failed');
      return {};
    }
  }

  /// Persists [ids] for [key] (sorted for stable diffs). Never throws.
  static Future<void> save(String key, Set<String> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sorted = ids.toList()..sort();
      await prefs.setStringList(key, sorted);
    } catch (_) {
      AppLogger.warning('favorites_store', 'operation failed');
    }
  }

  /// Toggles [id] in the set stored under [key] and returns the new set.
  static Future<Set<String>> toggle(String key, String id) async {
    final current = await load(key);
    final next = {...current};
    if (!next.remove(id)) next.add(id);
    await save(key, next);
    return next;
  }
}

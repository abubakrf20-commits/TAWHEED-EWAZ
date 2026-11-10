/// Small, non-critical converter state: the last category, the favourite unit
/// pairs, the last five conversions per category and the digit style.
///
/// Preferences (not the database): losing them costs the user nothing, and the
/// values the spec asks to survive a backup — the local-unit bases — live in
/// `unit_local_override` instead.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/shared/utils/app_logger.dart';

class ConversionEntry {
  const ConversionEntry({
    required this.categoryId,
    required this.fromId,
    required this.toId,
    required this.input,
    required this.output,
  });

  final String categoryId;
  final String fromId;
  final String toId;
  final String input;
  final String output;

  Map<String, Object?> toJson() => {
        'c': categoryId,
        'f': fromId,
        't': toId,
        'i': input,
        'o': output,
      };

  static ConversionEntry? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final c = raw['c'];
    final f = raw['f'];
    final t = raw['t'];
    final i = raw['i'];
    final o = raw['o'];
    if (c is! String || f is! String || t is! String) return null;
    return ConversionEntry(
      categoryId: c,
      fromId: f,
      toId: t,
      input: i is String ? i : '',
      output: o is String ? o : '',
    );
  }
}

class UnitPrefs {
  UnitPrefs._();

  static const _lastCategoryKey = 'calculator.units.last_category';
  static const _persianDigitsKey = 'calculator.units.persian_digits';
  static const _favoritesKey = 'calculator.units.favorites';
  static const _historyKey = 'calculator.units.history';
  static const _lastTabKey = 'calculator.tab_v1';

  static Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (e) {
      AppLogger.warning('UnitPrefs', 'prefs unavailable: $e');
      return null;
    }
  }

  static Future<String?> lastCategory() async =>
      (await _prefs())?.getString(_lastCategoryKey);

  static Future<void> saveLastCategory(String id) async {
    await (await _prefs())?.setString(_lastCategoryKey, id);
  }

  static Future<String?> lastTab() async =>
      (await _prefs())?.getString(_lastTabKey);

  static Future<void> saveLastTab(String id) async {
    await (await _prefs())?.setString(_lastTabKey, id);
  }

  static Future<bool> persianDigits() async =>
      (await _prefs())?.getBool(_persianDigitsKey) ?? false;

  static Future<void> savePersianDigits(bool value) async {
    await (await _prefs())?.setBool(_persianDigitsKey, value);
  }

  /// Favourites are stored as `category|from>to`.
  static Future<List<String>> favorites() async =>
      (await _prefs())?.getStringList(_favoritesKey) ?? const [];

  static Future<void> saveFavorites(List<String> values) async {
    await (await _prefs())?.setStringList(_favoritesKey, values);
  }

  static Future<List<ConversionEntry>> history() async {
    final raw = (await _prefs())?.getString(_historyKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map(ConversionEntry.tryParse)
          .whereType<ConversionEntry>()
          .toList();
    } catch (e) {
      AppLogger.warning('UnitPrefs', 'bad history json: $e');
      return const [];
    }
  }

  static Future<void> saveHistory(List<ConversionEntry> entries) async {
    try {
      final raw = jsonEncode([for (final e in entries) e.toJson()]);
      await (await _prefs())?.setString(_historyKey, raw);
    } catch (e) {
      AppLogger.warning('UnitPrefs', 'history write failed: $e');
    }
  }
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/features/tools/calendar/domain/day_journal_entry.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Persists «کارها و یادداشت‌های روز» per calendar day in SharedPreferences.
///
/// Each Gregorian date (`YYYY-MM-DD`) maps to a JSON list of
/// [DayJournalEntry]. The payload is tiny (a few short texts per day), so one
/// key per date keeps reads/writes cheap without a database migration.
class DayJournalService {
  DayJournalService._();

  static const String _keyPrefix = 'day_journal_';

  /// Canonical date key used across the app (`2026-09-04`).
  static String dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _prefsKey(String dateKey) => '$_keyPrefix$dateKey';

  /// Loads every stored date at once: date key → its entries (newest last).
  /// A storage failure is thrown, not swallowed — returning `{}` made the
  /// provider render a real error as «nothing recorded yet».
  static Future<Map<String, List<DayJournalEntry>>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <String, List<DayJournalEntry>>{};
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_keyPrefix)) continue;
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) continue;
      try {
        final list = (jsonDecode(raw) as List)
            .whereType<Map<String, dynamic>>()
            .map(DayJournalEntry.fromJson)
            .whereType<DayJournalEntry>()
            .toList();
        if (list.isNotEmpty) {
          result[key.substring(_keyPrefix.length)] = list;
        }
      } catch (_) {
        // Skip a single corrupt day instead of failing the whole journal.
      }
    }
    return result;
  }

  /// Persists one day's entries (an empty list removes the day's key).
  /// Rethrown after logging: the caller has already shown the entry
  /// optimistically, and swallowing here lost it on the next load.
  static Future<void> saveDay(
      String dateKey, List<DayJournalEntry> entries) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _prefsKey(dateKey);
      if (entries.isEmpty) {
        await prefs.remove(key);
      } else {
        await prefs.setString(
            key, jsonEncode(entries.map((e) => e.toJson()).toList()));
      }
    } catch (e) {
      AppLogger.warning('day_journal', 'saveDay failed: $e');
      rethrow;
    }
  }
}

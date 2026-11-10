/// The user's edits to the suggested care defaults (D1 / G-6).
///
/// The asset stays the source of the suggestion — nothing here rewrites it. An
/// edit is one row in `p2_template_override` (the same table the kids/teacher
/// template editors use), and the merge is a pure function so a malformed row
/// can only be ignored, never applied as a nonsense interval.
library;

import 'dart:convert';

import 'package:drift/drift.dart' show Variable;
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/personal/care_engine/care_templates.dart';
import 'package:tawheeed/features/personal2/data/personal2_tables.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// The `kind` column values this editor writes.
const String careTemplateKind = 'care_template';

/// Merges stored overrides into the parsed defaults.
///
/// Rules, all pinned by tests:
///  * an override for a key the bundle no longer has is ignored;
///  * a non-positive interval is ignored (a 0-day service would come due every
///    launch, which is worse than the shipped suggestion);
///  * an interval the template's schedule cannot use (days on a km-only
///    distance task) is ignored rather than silently changing its dimension;
///  * an empty title is ignored.
CareTemplates applyCareTemplateOverrides(
  CareTemplates base,
  Map<String, Map<String, Object?>> overrides,
) {
  if (overrides.isEmpty) return base;

  CareTemplate merge(CareTemplate template) {
    final raw = overrides[template.key];
    if (raw == null) return template;

    final title = raw['titleFa'];
    final days = raw['intervalDays'];
    final km = raw['intervalKm'];

    final newTitle =
        title is String && title.trim().isNotEmpty ? title.trim() : null;
    final newDays = days is num && days.toInt() > 0 && template.scheduleType.usesTime
        ? days.toInt()
        : null;
    final newKm = km is num && km.toInt() > 0 && template.scheduleType.usesDistance
        ? km.toInt()
        : null;

    final changed = newTitle != null || newDays != null || newKm != null;
    if (!changed) return template;
    return template.copyWith(
      titleFa: newTitle,
      intervalDays: newDays,
      intervalKm: newKm,
    );
  }

  List<CareTemplate> mergeAll(List<CareTemplate> list) {
    final out = <CareTemplate>[];
    var touched = false;
    for (final template in list) {
      final merged = merge(template);
      if (!identical(merged, template)) touched = true;
      out.add(merged);
    }
    return touched ? out : list;
  }

  return CareTemplates(
    carDefaults: mergeAll(base.carDefaults),
    homeDefaults: mergeAll(base.homeDefaults),
    seasonPacks: base.seasonPacks,
    note: base.note,
  );
}

/// The seam tests and the UI talk to: the real store is database-backed, a
/// harness can hand in a map without opening one.
abstract class CareTemplateOverrideStore {
  Future<Map<String, Map<String, Object?>>> load();

  Future<bool> save({
    required CareTemplate template,
    int? intervalDays,
    int? intervalKm,
    String? titleFa,
  });

  Future<bool> reset(String templateKey);
}

/// Reads and writes those rows.
class CareTemplateOverrides implements CareTemplateOverrideStore {
  CareTemplateOverrides(this._db);

  final AppDatabase _db;

  /// Every stored override for the care defaults, keyed by template key.
  @override
  Future<Map<String, Map<String, Object?>>> load() async {
    try {
      final rows = await _db.customSelect(
        'SELECT template_key, payload FROM ${Personal2Tables.templateOverride} '
        'WHERE kind = ?',
        variables: [Variable.withString(careTemplateKind)],
      ).get();
      final out = <String, Map<String, Object?>>{};
      for (final row in rows) {
        final key = row.read<String>('template_key');
        final raw = row.read<String>('payload');
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            out[key] = {
              for (final entry in decoded.entries)
                if (entry.key is String) entry.key as String: entry.value,
            };
          }
        } catch (e) {
          // One unreadable row must not hide the others.
          AppLogger.warning('CareTemplateOverrides', 'bad payload for $key: $e');
        }
      }
      return out;
    } catch (e) {
      // No table (or no database yet): the shipped defaults are still correct.
      AppLogger.warning('CareTemplateOverrides', 'read failed: $e');
      return const {};
    }
  }

  /// Persists only the values the editor actually changed.
  @override
  Future<bool> save({
    required CareTemplate template,
    int? intervalDays,
    int? intervalKm,
    String? titleFa,
  }) async {
    final payload = <String, Object?>{
      'key': template.key,
      if (titleFa != null) 'titleFa': titleFa,
      if (intervalDays != null) 'intervalDays': intervalDays,
      if (intervalKm != null) 'intervalKm': intervalKm,
    };
    try {
      await _db.customStatement(
        'INSERT OR REPLACE INTO ${Personal2Tables.templateOverride} '
        '(template_key, kind, payload, updated_at) VALUES (?, ?, ?, ?)',
        [
          template.key,
          careTemplateKind,
          jsonEncode(payload),
          DateTime.now().millisecondsSinceEpoch,
        ],
      );
      return true;
    } catch (e) {
      AppLogger.warning('CareTemplateOverrides', 'save failed: $e');
      return false;
    }
  }

  @override
  Future<bool> reset(String templateKey) async {
    try {
      await _db.customStatement(
        'DELETE FROM ${Personal2Tables.templateOverride} '
        'WHERE template_key = ? AND kind = ?',
        [templateKey, careTemplateKind],
      );
      return true;
    } catch (e) {
      AppLogger.warning('CareTemplateOverrides', 'reset failed: $e');
      return false;
    }
  }
}

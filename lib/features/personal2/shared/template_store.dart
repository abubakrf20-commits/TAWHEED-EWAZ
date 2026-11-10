import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';
import 'package:tawheeed/features/personal2/data/personal2_tables.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// One habit template from `assets/data/habit_templates.json`.
class HabitTemplate {
  const HabitTemplate({
    required this.key,
    required this.titleFa,
    required this.iconKey,
    required this.defaultStars,
    this.categoryKey = 'general',
    this.note = '',
    this.reviewed = false,
  });

  final String key;
  final String titleFa;
  final String iconKey;
  final int defaultStars;
  final String categoryKey;

  /// Editor-supplied hint («فقط مدت خواندن ثبت می‌شود…»). Never a ruling.
  final String note;

  /// False until a human audits the entry. The report lists every false one.
  final bool reviewed;

  static HabitTemplate? fromJson(Object? json) {
    if (json is! Map) return null;
    final key = json['key'];
    final title = json['titleFa'];
    if (key is! String || key.isEmpty) return null;
    if (title is! String || title.isEmpty) return null;
    final stars = (json['defaultStars'] as num?)?.toInt() ?? 1;
    // A template outside the 1..5 star range is a data error, not a tidying
    // opportunity: clamp so a bad asset cannot produce a 0-star habit.
    return HabitTemplate(
      key: key,
      titleFa: title,
      iconKey: (json['iconKey'] as String?) ?? 'star',
      defaultStars: stars.clamp(1, 5),
      categoryKey: (json['categoryKey'] as String?) ?? 'general',
      note: (json['note'] as String?) ?? '',
      reviewed: json['reviewed'] == true,
    );
  }
}

/// One reward template from the same asset.
class RewardTemplate {
  const RewardTemplate({
    required this.key,
    required this.titleFa,
    required this.iconKey,
    required this.costStars,
    this.reviewed = false,
  });

  final String key;
  final String titleFa;
  final String iconKey;
  final int costStars;
  final bool reviewed;

  static RewardTemplate? fromJson(Object? json) {
    if (json is! Map) return null;
    final key = json['key'];
    final title = json['titleFa'];
    if (key is! String || key.isEmpty) return null;
    if (title is! String || title.isEmpty) return null;
    final cost = (json['costStars'] as num?)?.toInt() ?? 0;
    if (cost <= 0) return null; // a free reward is not a reward
    return RewardTemplate(
      key: key,
      titleFa: title,
      iconKey: (json['iconKey'] as String?) ?? 'gift',
      costStars: cost,
      reviewed: json['reviewed'] == true,
    );
  }
}

/// One tajweed tag from `assets/data/tajweed_tags.json`. A LABEL only.
class TajweedTag {
  const TajweedTag({
    required this.key,
    required this.titleFa,
    this.reviewed = false,
  });

  final String key;
  final String titleFa;
  final bool reviewed;

  static TajweedTag? fromJson(Object? json) {
    if (json is! Map) return null;
    final key = json['key'];
    final title = json['titleFa'];
    if (key is! String || key.isEmpty) return null;
    if (title is! String || title.isEmpty) return null;
    return TajweedTag(
      key: key,
      titleFa: title,
      reviewed: json['reviewed'] == true,
    );
  }
}

/// One grade row from `assets/data/grade_scale.json`. [value] feeds averages
/// only; nothing in the UI derives a ruling from it.
class GradeScaleEntry {
  const GradeScaleEntry({
    required this.key,
    required this.titleFa,
    required this.value,
    this.reviewed = false,
  });

  final String key;
  final String titleFa;
  final int value;
  final bool reviewed;

  static GradeScaleEntry? fromJson(Object? json) {
    if (json is! Map) return null;
    final key = json['key'];
    final title = json['titleFa'];
    if (key is! String || key.isEmpty) return null;
    if (title is! String || title.isEmpty) return null;
    final value = (json['value'] as num?)?.toInt();
    if (value == null) return null;
    return GradeScaleEntry(
      key: key,
      titleFa: title,
      value: value,
      reviewed: json['reviewed'] == true,
    );
  }
}

/// Everything the two tools read from `assets/data/*.json`.
class Personal2Templates {
  const Personal2Templates({
    required this.habits,
    required this.rewards,
    required this.tajweedTags,
    required this.grades,
  });

  final List<HabitTemplate> habits;
  final List<RewardTemplate> rewards;
  final List<TajweedTag> tajweedTags;
  final List<GradeScaleEntry> grades;

  static const Personal2Templates empty = Personal2Templates(
    habits: [],
    rewards: [],
    tajweedTags: [],
    grades: [],
  );

  bool get isEmpty =>
      habits.isEmpty && rewards.isEmpty && tajweedTags.isEmpty && grades.isEmpty;

  /// Default (asset) value of a grade's numeric scale, used for averages when
  /// the editor has not overridden the scale.
  int gradeValue(String key) {
    for (final g in grades) {
      if (g.key == key) return g.value;
    }
    return 0;
  }

  String gradeTitle(String key) {
    for (final g in grades) {
      if (g.key == key) return g.titleFa;
    }
    return key;
  }

  String tagTitle(String key) {
    for (final t in tajweedTags) {
      if (t.key == key) return t.titleFa;
    }
    return key;
  }

  /// A tag's title, or null when the key is unknown. Null lets a caller decide
  /// to hide a stale key rather than print it raw.
  String? tagsTitle(String key) {
    for (final t in tajweedTags) {
      if (t.key == key) return t.titleFa;
    }
    return null;
  }
}

/// Loads, validates and OVERLAYS `assets/data/*.json` with the user's edits.
///
/// The asset is the shipped default; `p2_template_override` holds one JSON
/// payload per overridden key, so «reset to default» is a single DELETE and a
/// future asset update still reaches every key the user never touched.
///
/// The parsing stays pure (each `fromJson` above); this class only does I/O,
/// which keeps the validation rules unit-testable without a bundle.
class TemplateStore {
  TemplateStore(this._db);

  final AppDatabase _db;

  static const String habitAsset = 'assets/data/habit_templates.json';
  static const String tajweedAsset = 'assets/data/tajweed_tags.json';
  static const String gradeAsset = 'assets/data/grade_scale.json';

  static const String kindHabit = 'habit';
  static const String kindTag = 'tajweed_tag';
  static const String kindGrade = 'grade';

  Personal2Templates? _cached;

  /// Templates with every user override applied. Never throws: an unreadable
  /// asset degrades to the overrides alone, and an unreadable override is
  /// ignored rather than blanking the list.
  Future<Personal2Templates> load({bool refresh = false}) async {
    if (!refresh && _cached != null) return _cached!;

    final base = await _loadAssets();
    final overrides = await _loadOverrides();
    final merged = _applyOverrides(base, overrides);
    _cached = merged;
    return merged;
  }

  Future<void> resetToDefault(String templateKey) async {
    try {
      await _db.customStatement(
        'DELETE FROM ${Personal2Tables.templateOverride} WHERE template_key = ?',
        [templateKey],
      );
      _cached = null;
    } catch (e) {
      AppLogger.warning('TemplateStore', 'reset failed: $e');
    }
  }

  /// Persists an edited template. [payload] must round-trip through the same
  /// `fromJson` used for the asset, so an override can never introduce a shape
  /// the parser would reject.
  Future<bool> saveOverride({
    required String kind,
    required Map<String, Object?> payload,
  }) async {
    final key = payload['key'];
    if (key is! String || key.isEmpty) return false;
    try {
      await _db.customStatement(
        'INSERT OR REPLACE INTO ${Personal2Tables.templateOverride} '
        '(template_key, kind, payload, updated_at) VALUES (?, ?, ?, ?)',
        [
          key,
          kind,
          jsonEncode(payload),
          DateTime.now().millisecondsSinceEpoch,
        ],
      );
      _cached = null;
      return true;
    } catch (e) {
      AppLogger.warning('TemplateStore', 'override save failed: $e');
      return false;
    }
  }

  // ── Internals ────────────────────────────────────────────────────────

  Future<Personal2Templates> _loadAssets() async {
    try {
      final habitRaw = await rootBundle.loadString(habitAsset);
      final tagRaw = await rootBundle.loadString(tajweedAsset);
      final gradeRaw = await rootBundle.loadString(gradeAsset);

      final habitJson = jsonDecode(habitRaw);
      final tagJson = jsonDecode(tagRaw);
      final gradeJson = jsonDecode(gradeRaw);

      final habits = _parseList(habitJson, 'habits', HabitTemplate.fromJson);
      final rewards = _parseList(habitJson, 'rewards', RewardTemplate.fromJson);
      final tags = _parseList(tagJson, 'tags', TajweedTag.fromJson);
      final grades = _parseList(gradeJson, 'grades', GradeScaleEntry.fromJson);

      if (habits.isEmpty && rewards.isEmpty) {
        AppLogger.warning(
          'TemplateStore',
          'habit asset parsed to zero entries — check the asset declaration',
        );
      }
      return Personal2Templates(
        habits: habits,
        rewards: rewards,
        tajweedTags: tags,
        grades: grades,
      );
    } catch (e) {
      // The failure that used to be invisible: an undeclared asset throws
      // here, and only this log line records it.
      AppLogger.warning('TemplateStore', 'templates unreadable: $e');
      return Personal2Templates.empty;
    }
  }

  static List<T> _parseList<T>(
    Object? json,
    String field,
    T? Function(Object?) parse,
  ) {
    if (json is! Map) return const [];
    final list = json[field];
    if (list is! List) return const [];
    final out = <T>[];
    final seen = <String>{};
    for (final item in list) {
      final parsed = parse(item);
      if (parsed == null) continue;
      // Duplicate keys would make «which one is the override» ambiguous.
      final key = (item as Map)['key'] as String;
      if (!seen.add(key)) continue;
      out.add(parsed);
    }
    return out;
  }

  Future<Map<String, ({String kind, Object? payload})>> _loadOverrides() async {
    final out = <String, ({String kind, Object? payload})>{};
    try {
      final rows = await _db.customSelect(
        'SELECT template_key, kind, payload FROM ${Personal2Tables.templateOverride}',
      ).get();
      for (final row in rows) {
        final key = row.read<String>('template_key');
        final kind = row.read<String>('kind');
        try {
          out[key] = (kind: kind, payload: jsonDecode(row.read<String>('payload')));
        } catch (e) {
          AppLogger.warning('TemplateStore', 'override $key unreadable: $e');
        }
      }
    } catch (e) {
      AppLogger.warning('TemplateStore', 'overrides unreadable: $e');
    }
    return out;
  }

  Personal2Templates _applyOverrides(
    Personal2Templates base,
    Map<String, ({String kind, Object? payload})> overrides,
  ) {
    if (overrides.isEmpty) return base;

    final habits = _overlay(base.habits, overrides, kindHabit, HabitTemplate.fromJson,
        (h) => h.key);
    final rewards = _overlay(
        base.rewards, overrides, kindHabit, RewardTemplate.fromJson, (r) => r.key);
    final tags = _overlay(
        base.tajweedTags, overrides, kindTag, TajweedTag.fromJson, (t) => t.key);
    final grades = _overlay(base.grades, overrides, kindGrade, GradeScaleEntry.fromJson,
        (g) => g.key);

    return Personal2Templates(
      habits: habits,
      rewards: rewards,
      tajweedTags: tags,
      grades: grades,
    );
  }

  /// Replaces matching entries in place and appends new ones, so editing a
  /// template never reorders the picker.
  static List<T> _overlay<T>(
    List<T> base,
    Map<String, ({String kind, Object? payload})> overrides,
    String kind,
    T? Function(Object?) parse,
    String Function(T) keyOf,
  ) {
    final out = List<T>.from(base);
    final indexByKey = <String, int>{
      for (var i = 0; i < out.length; i++) keyOf(out[i]): i,
    };
    for (final entry in overrides.entries) {
      if (entry.value.kind != kind) continue;
      final parsed = parse(entry.value.payload);
      if (parsed == null) continue; // invalid override: keep the asset value
      final at = indexByKey[entry.key];
      if (at == null) {
        out.add(parsed);
        indexByKey[entry.key] = out.length - 1;
      } else {
        out[at] = parsed;
      }
    }
    return out;
  }
}

final templateStoreProvider = Provider<TemplateStore>(
  (ref) => TemplateStore(ref.read(appDatabaseProvider)),
);

/// The merged template set, loaded lazily (never during the first frame).
final personal2TemplatesProvider = FutureProvider<Personal2Templates>(
  (ref) => ref.read(templateStoreProvider).load(),
);

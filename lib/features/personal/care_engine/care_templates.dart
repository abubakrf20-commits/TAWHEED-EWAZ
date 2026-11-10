/// Parser for `assets/data/care_templates.json` — the editable DEFAULTS.
///
/// The file is the single source of the suggested intervals; this class only
/// reads it. Every item carries `reviewed:false` so the report can list what
/// still awaits the owner's review.
library;

import 'dart:convert';

import 'package:tawheeed/features/personal/care_engine/care_models.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// One suggested task definition.
class CareTemplate {
  const CareTemplate({
    required this.key,
    required this.titleFa,
    required this.iconKey,
    required this.scheduleType,
    this.intervalDays,
    this.intervalKm,
    this.window,
    this.note = '',
    this.reviewed = false,
  });

  final String key;
  final String titleFa;
  final String iconKey;
  final CareScheduleType scheduleType;
  final int? intervalDays;
  final int? intervalKm;
  final CareWindow? window;
  final String note;
  final bool reviewed;

  /// «5,000 km / 180 روز» — the picker's subtitle.
  String get intervalLabel {
    final parts = <String>[];
    if (intervalKm != null) {
      // One grouping rule for the whole feature: the engine's `remainingText`
      // already prints kilometres through this formatter.
      parts.add('${NumberFormat.formatPlain(intervalKm!.toDouble())} km');
    }
    if (intervalDays != null) {
      final days = intervalDays!;
      if (days == 365) {
        parts.add('سالانه');
      } else if (days % 365 == 0) {
        parts.add('${days ~/ 365} سال');
      } else if (days % 30 == 0) {
        parts.add('${days ~/ 30} ماه');
      } else {
        parts.add('$days روز');
      }
    }
    return parts.join(' / ');
  }

  /// An edited copy — the defaults editor writes interval/title overrides and
  /// must not mutate the parsed asset.
  CareTemplate copyWith({
    String? titleFa,
    int? intervalDays,
    bool clearIntervalDays = false,
    int? intervalKm,
    bool clearIntervalKm = false,
  }) =>
      CareTemplate(
        key: key,
        titleFa: titleFa ?? this.titleFa,
        iconKey: iconKey,
        scheduleType: scheduleType,
        intervalDays:
            clearIntervalDays ? null : (intervalDays ?? this.intervalDays),
        intervalKm: clearIntervalKm ? null : (intervalKm ?? this.intervalKm),
        window: window,
        note: note,
        reviewed: reviewed,
      );

  /// A fresh, unscheduled task from this template.
  CareTask toTask({
    required String id,
    required String assetId,
    required DateTime now,
  }) =>
      CareTask(
        id: id,
        assetId: assetId,
        title: titleFa,
        templateKey: key,
        categoryKey: window == null ? 'general' : 'seasonal',
        iconKey: iconKey,
        scheduleType: scheduleType,
        intervalDays: intervalDays,
        intervalKm: intervalKm,
        window: window,
        notes: note,
        createdAt: now,
      );

  static CareTemplate? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final key = raw['key'];
    final title = raw['titleFa'];
    if (key is! String || key.trim().isEmpty) return null;
    if (title is! String || title.trim().isEmpty) return null;

    int? positive(Object? value) =>
        value is num && value.toInt() > 0 ? value.toInt() : null;

    final type = CareScheduleType.fromKey(raw['scheduleType'] as String? ?? '');
    final days = positive(raw['intervalDays']);
    final km = positive(raw['intervalKm']);
    // A schedule with no interval can never come due — reject it instead of
    // creating an invisible task.
    if (type.usesTime && days == null) return null;
    if (type.usesDistance && km == null) return null;

    return CareTemplate(
      key: key.trim(),
      titleFa: title.trim(),
      iconKey: (raw['iconKey'] as String? ?? '').trim(),
      scheduleType: type,
      intervalDays: days,
      intervalKm: km,
      window: CareWindow.fromJson(raw['window']),
      note: (raw['note'] as String? ?? '').trim(),
      reviewed: raw['reviewed'] == true,
    );
  }
}

/// «آماده‌سازی زمستان» / «آماده‌سازی تابستان».
class CareSeasonPack {
  const CareSeasonPack({
    required this.key,
    required this.titleFa,
    required this.iconKey,
    required this.templateKeys,
  });

  final String key;
  final String titleFa;
  final String iconKey;
  final List<String> templateKeys;

  static CareSeasonPack? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final key = raw['key'];
    final title = raw['titleFa'];
    if (key is! String || key.trim().isEmpty) return null;
    if (title is! String || title.trim().isEmpty) return null;
    final keys = raw['templateKeys'];
    if (keys is! List) return null;
    final parsed = keys.whereType<String>().map((k) => k.trim()).toList();
    if (parsed.isEmpty) return null;
    return CareSeasonPack(
      key: key.trim(),
      titleFa: title.trim(),
      iconKey: (raw['iconKey'] as String? ?? '').trim(),
      templateKeys: parsed,
    );
  }
}

/// The parsed defaults file.
class CareTemplates {
  const CareTemplates({
    required this.carDefaults,
    required this.homeDefaults,
    required this.seasonPacks,
    this.note = '',
  });

  final List<CareTemplate> carDefaults;
  final List<CareTemplate> homeDefaults;
  final List<CareSeasonPack> seasonPacks;

  /// The «پیشنهادی؛ …» note shown under the template picker.
  final String note;

  List<CareTemplate> of(CareAssetKind kind) =>
      kind == CareAssetKind.car ? carDefaults : homeDefaults;

  CareTemplate? byKey(String key) {
    for (final t in [...carDefaults, ...homeDefaults]) {
      if (t.key == key) return t;
    }
    return null;
  }

  /// Parses the bundled JSON. Never throws: a malformed file yields whatever
  /// valid items it contained, and an empty set rather than a crash.
  static CareTemplates parse(String source) {
    Map<String, dynamic> root;
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map<String, dynamic>) {
        return const CareTemplates(
            carDefaults: [], homeDefaults: [], seasonPacks: []);
      }
      root = decoded;
    } catch (_) {
      // Unreadable bundle: the caller falls back to an empty template set.
      return const CareTemplates(
          carDefaults: [], homeDefaults: [], seasonPacks: []);
    }

    List<CareTemplate> readList(Object? raw) {
      if (raw is! List) return const [];
      final seen = <String>{};
      final out = <CareTemplate>[];
      for (final item in raw) {
        final template = CareTemplate.fromJson(item);
        if (template == null || !seen.add(template.key)) continue;
        out.add(template);
      }
      return out;
    }

    final car = readList(root['carDefaults']);
    final home = readList(root['homeDefaults']);
    final knownKeys = {for (final t in [...car, ...home]) t.key};
    final packs = <CareSeasonPack>[];
    final rawPacks = root['homeSeasonPacks'];
    if (rawPacks is List) {
      final seen = <String>{};
      for (final item in rawPacks) {
        final pack = CareSeasonPack.fromJson(item);
        if (pack == null || !seen.add(pack.key)) continue;
        final keys = pack.templateKeys.where(knownKeys.contains).toList();
        if (keys.isEmpty) continue;
        packs.add(CareSeasonPack(
          key: pack.key,
          titleFa: pack.titleFa,
          iconKey: pack.iconKey,
          templateKeys: keys,
        ));
      }
    }

    return CareTemplates(
      carDefaults: car,
      homeDefaults: home,
      seasonPacks: packs,
      note: (root['note'] as String? ?? '').trim(),
    );
  }

  /// Every default's title + interval, for the report and for the template
  /// picker's subtitles.
  List<String> describeDefaults() => [
        for (final t in carDefaults) 'خودرو — ${t.titleFa}: ${_interval(t)}',
        for (final t in homeDefaults) 'خانه — ${t.titleFa}: ${_interval(t)}',
      ];

  static String _interval(CareTemplate t) {
    final base = t.intervalLabel;
    if (t.window == null) return base;
    return '$base (پنجرهٔ ${t.window!.startMonth}/${t.window!.startDay})';
  }
}

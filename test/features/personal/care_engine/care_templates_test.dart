import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/personal/care_engine/care_models.dart';
import 'package:tawheeed/features/personal/care_engine/care_templates.dart';

/// Reads the SHIPPED defaults file, not a copy, so an edit that breaks the
/// bundle (a missing interval, a pack pointing at a deleted key) fails here
/// instead of silently producing empty task lists on a user's phone.
void main() {
  late CareTemplates templates;
  late String raw;

  setUpAll(() {
    raw = File('assets/data/care_templates.json').readAsStringSync();
    templates = CareTemplates.parse(raw);
  });

  test('the asset is declared in pubspec', () {
    // Either the directory (which bundles everything beneath it) or this exact
    // file. A per-file entry for a sibling must not satisfy it.
    bool declares(String pubspec) => pubspec
        .split('\n')
        .map((line) => line.trim())
        .any(
          (line) =>
              line == '- assets/data/' ||
              line == '- assets/data/care_templates.json',
        );

    expect(
      declares(File('pubspec.yaml').readAsStringSync()),
      isTrue,
      reason: 'pubspec must bundle assets/data/ or the template file',
    );
    expect(declares('assets:\n    - assets/data/\n'), isTrue);
    expect(
      declares('assets:\n    - assets/data/care_templates.json\n'),
      isTrue,
    );
    expect(declares('assets:\n    - assets/data/other.json\n'), isFalse);
  });

  test('both default sets are non-empty and distinct', () {
    expect(templates.carDefaults, isNotEmpty);
    expect(templates.homeDefaults, isNotEmpty);
    final carKeys = templates.carDefaults.map((t) => t.key).toSet();
    final homeKeys = templates.homeDefaults.map((t) => t.key).toSet();
    expect(carKeys.intersection(homeKeys), isEmpty);
  });

  test('every key is unique inside its set', () {
    for (final set in [templates.carDefaults, templates.homeDefaults]) {
      final keys = set.map((t) => t.key).toList();
      expect(keys.toSet().length, keys.length);
    }
  });

  test('every template has a title, an icon and a usable interval', () {
    for (final t in [...templates.carDefaults, ...templates.homeDefaults]) {
      expect(t.titleFa.trim(), isNotEmpty, reason: t.key);
      expect(t.iconKey.trim(), isNotEmpty, reason: t.key);
      if (t.scheduleType.usesTime) {
        expect(t.intervalDays, isNotNull, reason: '${t.key} needs intervalDays');
        expect(t.intervalDays, greaterThan(0), reason: t.key);
      }
      if (t.scheduleType.usesDistance) {
        expect(t.intervalKm, isNotNull, reason: '${t.key} needs intervalKm');
        expect(t.intervalKm, greaterThan(0), reason: t.key);
      }
    }
  });

  test('every window is a valid Jalali range', () {
    for (final t in [...templates.carDefaults, ...templates.homeDefaults]) {
      final w = t.window;
      if (w == null) continue;
      expect(w.startMonth, inInclusiveRange(1, 12), reason: t.key);
      expect(w.endMonth, inInclusiveRange(1, 12), reason: t.key);
      expect(w.startDay, inInclusiveRange(1, 31), reason: t.key);
      expect(w.endDay, inInclusiveRange(1, 31), reason: t.key);
    }
  });

  test('every item is still marked unreviewed, including the raw JSON', () {
    for (final t in [...templates.carDefaults, ...templates.homeDefaults]) {
      expect(t.reviewed, isFalse, reason: '${t.key} awaits the owner\'s review');
    }
    expect(RegExp('"reviewed":\\s*false').allMatches(raw).length,
        templates.carDefaults.length + templates.homeDefaults.length);
  });

  test('the advisory note is the approved wording', () {
    expect(templates.note, startsWith('پیشنهادی'));
    expect(templates.note, contains('دفترچهٔ خودرو'));
    expect(templates.note, contains('راهنمای سازنده'));
  });

  test('season packs only reference existing templates', () {
    expect(templates.seasonPacks, isNotEmpty);
    for (final pack in templates.seasonPacks) {
      expect(pack.templateKeys, isNotEmpty, reason: pack.key);
      for (final key in pack.templateKeys) {
        expect(templates.byKey(key), isNotNull, reason: '${pack.key} → $key');
      }
    }
  });

  test('the winter and summer packs exist', () {
    expect(templates.seasonPacks.map((p) => p.key), containsAll(['winter', 'summer']));
  });

  test('describeDefaults lists every default once', () {
    expect(
      templates.describeDefaults().length,
      templates.carDefaults.length + templates.homeDefaults.length,
    );
  });

  test('the interval label reads in months, years or days', () {
    final oil = templates.byKey('engine_oil')!;
    expect(oil.intervalLabel, '5,000 km / 6 ماه');

    final boiler = templates.byKey('boiler_service');
    if (boiler != null && boiler.intervalDays == 365) {
      expect(boiler.intervalLabel, contains('سالانه'));
    }
  });

  test('a malformed bundle degrades instead of throwing', () {
    final broken = CareTemplates.parse('{ not json');
    expect(broken.carDefaults, isEmpty);
    expect(broken.homeDefaults, isEmpty);
    expect(broken.note, isEmpty);
  });

  test('a duplicate key keeps only the first definition', () {
    final parsed = CareTemplates.parse('''
{
  "carDefaults": [
    {"key":"a","titleFa":"یک","scheduleType":"time","intervalDays":10},
    {"key":"a","titleFa":"دو","scheduleType":"time","intervalDays":20}
  ],
  "homeDefaults": []
}
''');
    expect(parsed.carDefaults.length, 1);
    expect(parsed.carDefaults.single.titleFa, 'یک');
  });

  test('an entry with no interval for its schedule type is dropped', () {
    final parsed = CareTemplates.parse('''
{
  "carDefaults": [
    {"key":"km_only","titleFa":"فاصله","scheduleType":"distance"},
    {"key":"ok","titleFa":"درست","scheduleType":"time","intervalDays":30}
  ],
  "homeDefaults": []
}
''');
    expect(parsed.carDefaults.map((t) => t.key), ['ok']);
  });

  test('a template becomes a task with the right schedule shape', () {
    final oil = templates.byKey('engine_oil')!;
    final task = oil.toTask(
      id: 't1',
      assetId: 'a1',
      now: DateTime(2026),
    );
    expect(task.title, oil.titleFa);
    expect(task.templateKey, 'engine_oil');
    expect(task.scheduleType, CareScheduleType.both);
    expect(task.intervalKm, 5000);
    expect(task.intervalDays, 180);
    expect(task.active, isTrue);
    expect(task.categoryKey, 'general');
  });
}

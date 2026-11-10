import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/personal/care_engine/care_models.dart';
import 'package:tawheeed/features/personal/care_engine/care_template_overrides.dart';
import 'package:tawheeed/features/personal/care_engine/care_templates.dart';

/// The editor writes rows; this merge is the only thing that decides what
/// those rows mean, so every refusal is pinned here.
void main() {
  late CareTemplates base;

  setUpAll(() {
    base = CareTemplates.parse(
      File('assets/data/care_templates.json').readAsStringSync(),
    );
  });

  CareTemplate homeOf(CareTemplates list, String key) =>
      list.homeDefaults.firstWhere((t) => t.key == key);

  test('no overrides returns the parsed defaults untouched', () {
    expect(identical(applyCareTemplateOverrides(base, const {}), base), isTrue);
  });

  test('a title and an interval are both applied', () {
    final merged = applyCareTemplateOverrides(base, {
      'oil_filter': {'titleFa': 'فیلتر روغن (اصل)', 'intervalKm': 4000},
    });
    final filter = merged.carDefaults.firstWhere((t) => t.key == 'oil_filter');
    expect(filter.titleFa, 'فیلتر روغن (اصل)');
    expect(filter.intervalKm, 4000);
    // The dimension the override did not name keeps its shipped value.
    expect(filter.intervalDays, base.carDefaults
        .firstWhere((t) => t.key == 'oil_filter')
        .intervalDays);
  });

  test('the shipped defaults are not mutated', () {
    final shippedTitle =
        base.carDefaults.firstWhere((t) => t.key == 'oil_filter').titleFa;
    applyCareTemplateOverrides(base, {
      'oil_filter': {'titleFa': 'چیز دیگر'},
    });
    expect(
      base.carDefaults.firstWhere((t) => t.key == 'oil_filter').titleFa,
      shippedTitle,
    );
  });

  test('a dimension the schedule cannot use is refused', () {
    // battery is time-only; a km override on it must not pretend otherwise.
    expect(
      base.carDefaults.firstWhere((t) => t.key == 'battery').scheduleType,
      CareScheduleType.time,
    );
    final merged = applyCareTemplateOverrides(base, {
      'battery': {'intervalKm': 10000},
    });
    expect(
      merged.carDefaults.firstWhere((t) => t.key == 'battery').intervalKm,
      base.carDefaults.firstWhere((t) => t.key == 'battery').intervalKm,
    );
  });

  test('zero, negative and empty values are ignored', () {
    final merged = applyCareTemplateOverrides(base, {
      'engine_oil': {'intervalDays': 0, 'intervalKm': -5, 'titleFa': '  '},
    });
    final oil = merged.carDefaults.firstWhere((t) => t.key == 'engine_oil');
    final shipped = base.carDefaults.firstWhere((t) => t.key == 'engine_oil');
    expect(oil.intervalDays, shipped.intervalDays);
    expect(oil.intervalKm, shipped.intervalKm);
    expect(oil.titleFa, shipped.titleFa);
  });

  test('an override for a key the bundle dropped is ignored', () {
    final merged = applyCareTemplateOverrides(base, {
      'no_such_template': {'intervalDays': 3},
    });
    expect(merged.carDefaults.length, base.carDefaults.length);
    expect(merged.homeDefaults.length, base.homeDefaults.length);
  });

  test('windows and season packs survive the merge', () {
    final merged = applyCareTemplateOverrides(base, {
      'chimney_cleaning': {'intervalDays': 200},
    });
    final chimney = homeOf(merged, 'chimney_cleaning');
    expect(chimney.window, isNotNull);
    expect(chimney.window!.startMonth, homeOf(base, 'chimney_cleaning').window!.startMonth);
    expect(merged.seasonPacks.length, base.seasonPacks.length);
    expect(merged.seasonPacks.first.templateKeys,
        base.seasonPacks.first.templateKeys);
    expect(merged.note, base.note);
  });

  test('an interval label follows the edited number', () {
    final merged = applyCareTemplateOverrides(base, {
      'cabin_filter': {'intervalKm': 8000},
    });
    expect(
      merged.carDefaults.firstWhere((t) => t.key == 'cabin_filter').intervalLabel,
      contains('8,000 km'),
    );
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/features/personal/care_engine/care_models.dart';
import 'package:tawheeed/features/personal/care_engine/care_season_plan.dart';
import 'package:tawheeed/features/personal/care_engine/care_templates.dart';

/// The packs are read from the SHIPPED asset, so a window edited in the bundle
/// (or a pack pointing at a template that no longer exists) is caught here.
void main() {
  late CareTemplates templates;
  late CareSeasonPack winter;
  late CareSeasonPack summer;

  DateTime jalali(int y, int m, int d) => Jalali(y, m, d).toDateTime();

  setUpAll(() {
    templates = CareTemplates.parse(
      File('assets/data/care_templates.json').readAsStringSync(),
    );
    winter = templates.seasonPacks.firstWhere((p) => p.key == 'winter');
    summer = templates.seasonPacks.firstWhere((p) => p.key == 'summer');
  });

  CareTask task(String key, {bool active = true}) => CareTask(
        id: 't_$key',
        assetId: 'home',
        title: key,
        templateKey: key,
        categoryKey: 'seasonal',
        iconKey: '',
        scheduleType: CareScheduleType.time,
        intervalDays: 365,
        createdAt: jalali(1405, 1, 1),
        active: active,
      );

  group('the window comes from the pack, not the calendar', () {
    test('Mehr puts winter in its window, with the union Mehr 1 – Azar 30', () {
      final plan = careSeasonPlanFor(
        pack: winter,
        templates: templates,
        tasks: const [],
        now: jalali(1405, 7, 15),
      )!;
      expect(plan.state, CareSeasonState.inWindow);
      expect(Jalali.fromDateTime(plan.windowStart!).month, 7);
      expect(Jalali.fromDateTime(plan.windowStart!).day, 1);
      expect(Jalali.fromDateTime(plan.windowEnd!).month, 9);
      expect(Jalali.fromDateTime(plan.windowEnd!).day, 30);
      expect(plan.daysRemaining, greaterThan(0));
      expect(plan.statusLabel, startsWith('در پنجره'));
    });

    test('before the window the countdown is positive', () {
      final plan = careSeasonPlanFor(
        pack: winter,
        templates: templates,
        tasks: const [],
        now: jalali(1405, 3, 1),
      )!;
      expect(plan.state, CareSeasonState.before);
      expect(plan.daysUntilStart, greaterThan(0));
      expect(plan.statusLabel, endsWith('روز تا پنجره'));
    });

    test('after the window it is missed, and next year is named', () {
      final plan = careSeasonPlanFor(
        pack: winter,
        templates: templates,
        tasks: const [],
        now: jalali(1405, 10, 10),
      )!;
      expect(plan.state, CareSeasonState.missed);
      expect(plan.statusLabel, 'پنجرهٔ امسال گذشت');
      expect(Jalali.fromDateTime(plan.nextWindowStart!).year, 1406);
      expect(Jalali.fromDateTime(plan.nextWindowStart!).month, 7);
      expect(plan.actionLabel, contains('فصل بعد'));
    });

    test('the last day of the window is still inside it', () {
      final plan = careSeasonPlanFor(
        pack: winter,
        templates: templates,
        tasks: const [],
        now: jalali(1405, 9, 30),
      )!;
      expect(plan.state, CareSeasonState.inWindow);
      expect(plan.daysRemaining, 0);
      expect(plan.statusLabel, 'امروز آخرین روز پنجره');
    });
  });

  group('only the missing templates are offered', () {
    test('a fresh asset misses every template of the pack', () {
      final plan = careSeasonPlanFor(
        pack: winter,
        templates: templates,
        tasks: const [],
        now: jalali(1405, 7, 15),
      )!;
      expect(plan.total, winter.templateKeys.length);
      expect(plan.missing.map((t) => t.key), winter.templateKeys);
      expect(plan.scheduled, 0);
      expect(plan.isComplete, isFalse);
      expect(plan.actionLabel, 'افزودن 4 مورد');
    });

    test('scheduled templates drop out, and a full pack has no action', () {
      final half = careSeasonPlanFor(
        pack: winter,
        templates: templates,
        tasks: [task('boiler_service'), task('chimney_cleaning')],
        now: jalali(1405, 7, 15),
      )!;
      expect(half.missing.map((t) => t.key),
          ['fire_extinguisher', 'detector_battery']);
      expect(half.actionLabel, 'افزودن 2 مورد');

      final full = careSeasonPlanFor(
        pack: winter,
        templates: templates,
        tasks: winter.templateKeys.map(task).toList(),
        now: jalali(1405, 7, 15),
      )!;
      expect(full.isComplete, isTrue);
      expect(full.actionLabel, isNull);
      expect(full.scheduled, full.total);
    });

    test('a removed (inactive) task is offered again', () {
      final plan = careSeasonPlanFor(
        pack: winter,
        templates: templates,
        tasks: [task('boiler_service', active: false)],
        now: jalali(1405, 7, 15),
      )!;
      expect(plan.missing.map((t) => t.key), contains('boiler_service'));
    });
  });

  group('picking the pack to show', () {
    test('an open pack wins over one that already closed', () {
      // Khordad: summer's window (Ordibehesht) has closed, winter's has not
      // opened yet — the next window is the more useful thing to show.
      final plan = careNextSeasonPlan(
        templates: templates,
        tasks: const [],
        now: jalali(1405, 3, 1),
      )!;
      expect(plan.pack.key, 'winter');
      expect(plan.state, CareSeasonState.before);

      final open = careNextSeasonPlan(
        templates: templates,
        tasks: const [],
        now: jalali(1405, 2, 3),
      )!;
      expect(open.pack.key, 'summer');
      expect(open.state, CareSeasonState.inWindow);
    });

    test('an open complete pack yields to an open one with work left', () {
      final plan = careNextSeasonPlan(
        templates: templates,
        tasks: summer.templateKeys.map(task).toList(),
        now: jalali(1405, 7, 15),
      )!;
      expect(plan.pack.key, 'winter');
      expect(plan.isComplete, isFalse);
    });
  });

  group('degenerate bundles', () {
    const noWindows = CareTemplates(
      carDefaults: [],
      homeDefaults: [
        CareTemplate(
          key: 'extinguisher',
          titleFa: 'کپسول آتش‌نشانی',
          iconKey: 'fire',
          scheduleType: CareScheduleType.time,
          intervalDays: 365,
        ),
      ],
      seasonPacks: [
        CareSeasonPack(
          key: 'safety',
          titleFa: 'ایمنی',
          iconKey: 'fire',
          templateKeys: ['extinguisher'],
        ),
      ],
    );

    test('a pack without windows is offerable at any time', () {
      final plan = careSeasonPlanFor(
        pack: noWindows.seasonPacks.first,
        templates: noWindows,
        tasks: const [],
        now: jalali(1405, 7, 15),
      )!;
      expect(plan.hasWindow, isFalse);
      expect(plan.state, CareSeasonState.before);
      expect(plan.actionLabel, 'افزودن 1 مورد');
    });

    test('a pack whose keys are all unknown is not shown at all', () {
      final plan = careSeasonPlanFor(
        pack: winter,
        templates: noWindows,
        tasks: const [],
        now: jalali(1405, 7, 15),
      );
      expect(plan, isNull);
    });

    test('no packs means no banner', () {
      expect(
        careNextSeasonPlan(
          templates: noWindows,
          tasks: const [],
          now: jalali(1405, 7, 15),
        ),
        isNotNull,
      );
      expect(
        careNextSeasonPlan(
          templates: const CareTemplates(
              carDefaults: [], homeDefaults: [], seasonPacks: []),
          tasks: const [],
          now: jalali(1405, 7, 15),
        ),
        isNull,
      );
    });
  });
}

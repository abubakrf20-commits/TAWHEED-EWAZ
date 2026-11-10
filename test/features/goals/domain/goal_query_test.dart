import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/goals/domain/goal_query.dart';

final today = DateTime(2026, 9, 10);
final now = DateTime(2026, 9);

GoalTableData goal(
  String id, {
  String title = 'هدف',
  String description = '',
  String category = 'hifz',
  int target = 30,
  String deadline = '',
  int priority = 1,
  bool active = true,
  bool archived = false,
  int dailyTarget = 0,
  bool remindEnabled = false,
  String remindAt = '',
  String linkedType = '',
  String linkedId = '',
  DateTime? createdAt,
}) {
  return GoalTableData(
    id: id,
    title: title,
    description: description,
    category: category,
    startDate: '',
    deadline: deadline,
    targetType: 'count',
    targetNumber: target,
    isActive: active,
    isArchived: archived,
    createdAt: createdAt ?? now,
    updatedAt: now,
    priority: priority,
    dailyTarget: dailyTarget,
    remindEnabled: remindEnabled,
    remindAt: remindAt,
    linkedType: linkedType,
    linkedId: linkedId,
  );
}

GoalListEntry entry(
  GoalTableData g,
  int total, {
  int streak = 0,
  int best = 0,
}) =>
    GoalListEntry(
      goal: g,
      total: total,
      streak: GoalStreak(current: streak, best: best),
    );

List<String> idsOf(List<GoalListEntry> list) =>
    list.map((e) => e.goal.id).toList();

/// Applies [sort] with no filtering, for the sorting tests.
List<GoalListEntry> sorted(List<GoalListEntry> list, GoalSort sort) =>
    applyGoalQuery(list, filter: const GoalFilter(), sort: sort, today: today);

void main() {
  group('GoalFilter', () {
    test('a default filter narrows nothing', () {
      expect(const GoalFilter().isEmpty, isTrue);
    });

    test('any set field counts as narrowing', () {
      expect(const GoalFilter(query: 'a').isEmpty, isFalse);
      expect(const GoalFilter(category: 'hifz').isEmpty, isFalse);
      expect(const GoalFilter(priority: 1).isEmpty, isFalse);
      expect(const GoalFilter(hideCompleted: true).isEmpty, isFalse);
    });

    test('whitespace-only search text is not a filter', () {
      expect(const GoalFilter(query: '   ').isEmpty, isTrue);
    });

    test('value equality, so the provider does not over-notify', () {
      // Without ==, GoalListOptions equality fell back to identity and every
      // keystroke rebuilt widgets that only cared about the sort order.
      expect(const GoalFilter(query: 'a'), const GoalFilter(query: 'a'));
      expect(const GoalFilter(query: 'a').hashCode,
          const GoalFilter(query: 'a').hashCode);
      expect(const GoalFilter(query: 'a'), isNot(const GoalFilter(query: 'b')));
    });

    test('clear flags actually clear', () {
      const f = GoalFilter(query: 'a', category: 'hifz', priority: 2);
      final cleared = f.copyWith(clearCategory: true, clearPriority: true);
      expect(cleared.category, isNull);
      expect(cleared.priority, isNull);
      expect(cleared.query, 'a', reason: 'the query was not asked to clear');
    });
  });

  group('GoalListOptions', () {
    test('isEmpty follows the filter', () {
      expect(const GoalListOptions().isEmpty, isTrue);
      expect(const GoalListOptions(filter: GoalFilter(query: 'x')).isEmpty,
          isFalse);
      // Changing only the sort does not count as filtering: the list is not
      // empty, it is just ordered differently.
      expect(const GoalListOptions(sort: GoalSort.deadline).isEmpty, isTrue);
    });

    test('value equality across both fields', () {
      expect(const GoalListOptions(), const GoalListOptions());
      expect(
        const GoalListOptions(sort: GoalSort.deadline),
        isNot(const GoalListOptions(sort: GoalSort.progress)),
      );
    });
  });

  group('search', () {
    final list = [
      entry(goal('g1', title: 'حفظ جزء اول', description: 'برنامه هفتگی'), 5),
      entry(goal('g2', title: 'مطالعه', description: 'کتاب فقه'), 3),
      entry(goal('g3', title: 'قرآن'), 1),
    ];

    test('an empty query returns everything', () {
      expect(applyGoalQuery(list, filter: const GoalFilter(), today: today),
          hasLength(3));
    });

    test('matches the title', () {
      final r = applyGoalQuery(list,
          filter: const GoalFilter(query: 'حفظ'), today: today);
      expect(idsOf(r), ['g1']);
    });

    test('matches the description too', () {
      final r = applyGoalQuery(list,
          filter: const GoalFilter(query: 'فقه'), today: today);
      expect(idsOf(r), ['g1', 'g2'].where((i) => i == 'g2').toList());
    });

    test('is case-insensitive for Latin text', () {
      final latin = [entry(goal('g1', title: 'Read Quran'), 1)];
      expect(
        applyGoalQuery(latin,
            filter: const GoalFilter(query: 'QURAN'), today: today),
        hasLength(1),
      );
    });

    test('folds Arabic and Persian letter variants', () {
      // «ک» U+0643 vs «ك» U+0643: a user searching with the Arabic keyboard
      // must not miss a goal typed with the Persian one.
      final rows = [entry(goal('g1', title: 'مکتب'), 1)];
      expect(
        applyGoalQuery(rows,
            filter: const GoalFilter(query: 'مكتب'), today: today),
        hasLength(1),
      );
      // And ی / ي.
      final rows2 = [entry(goal('g2', title: 'مستند'), 1)];
      expect(
        applyGoalQuery(rows2,
            filter: const GoalFilter(query: 'مستند'), today: today),
        hasLength(1),
      );
    });

    test('strips the diacritics a keyboard adds', () {
      final rows = [entry(goal('g1', title: 'مُطالعه'), 1)];
      expect(
        applyGoalQuery(rows,
            filter: const GoalFilter(query: 'مطالعه'), today: today),
        hasLength(1),
      );
    });

    test('a query that matches nothing returns an empty list', () {
      expect(
        applyGoalQuery(list,
            filter: const GoalFilter(query: 'zzz'), today: today),
        isEmpty,
      );
    });
  });

  group('filters', () {
    // g1 and g3 are hifz, g2 is quran.
    final list = [
      entry(goal('g1', priority: 2), 30),
      entry(goal('g2', category: 'quran', priority: 0), 1),
      entry(goal('g3'), 10),
    ];

    test('by category', () {
      expect(
        idsOf(applyGoalQuery(list,
            filter: const GoalFilter(category: 'hifz'), today: today)),
        // g1 is 30/30, so the default order sinks it below g3 — the category
        // filter narrows the set, the sort still decides within it.
        ['g3', 'g1'],
      );
    });

    test('by priority', () {
      expect(
        idsOf(applyGoalQuery(list,
            filter: const GoalFilter(priority: 2), today: today)),
        ['g1'],
      );
    });

    test('hideCompleted drops the goals that already hit their target', () {
      final r = applyGoalQuery(list,
          filter: const GoalFilter(hideCompleted: true), today: today);
      // g1 is complete and gone; of the rest, g3 (priority 1) outranks
      // g2 (priority 0) under the default order.
      expect(idsOf(r), ['g3', 'g2']);
    });

    test('a goal with no numeric target is never "complete"', () {
      // Marking a target-less goal as finished would hide it behind a filter
      // the user can never undo, since nothing will ever raise its total.
      final open = [entry(goal('g1', target: 0), 0)];
      expect(
        applyGoalQuery(open,
            filter: const GoalFilter(hideCompleted: true), today: today),
        hasLength(1),
      );
    });

    test('filters combine with AND', () {
      final r = applyGoalQuery(
        list,
        filter: const GoalFilter(category: 'hifz', priority: 1),
        today: today,
      );
      expect(idsOf(r), ['g3']);
    });
  });

  group('sorting', () {
    final list = [
      // g1: 10/10 done, priority 1 (the default), deadline in 5 days
      entry(goal('g1', target: 10, deadline: '2026-09-15'), 10),
      // g2: 0/10, priority 2 (high), no deadline
      entry(goal('g2', priority: 2, target: 10), 0),
      // g3: 5/20, priority 0, deadline in 2 days
      entry(goal('g3', priority: 0, deadline: '2026-09-12', target: 20), 5),
    ];

    test('manual puts priority above newness', () {
      final r = sorted(list, GoalSort.manual);
      // g2 (priority 2) and g3 (priority 0) are live; g1 is complete, and the
      // default order sinks finished goals below live work.
      expect(idsOf(r), ['g2', 'g3', 'g1']);
    });

    test('manual pushes inactive goals down', () {
      final withInactive = [
        ...list,
        entry(goal('g9', priority: 2, active: false), 0),
      ];
      final r = sorted(withInactive, GoalSort.manual);
      expect(idsOf(r).last, 'g9');
    });

    test('deadline puts the soonest first and no-deadline last', () {
      final r = sorted(list, GoalSort.deadline);
      expect(idsOf(r), ['g3', 'g1', 'g2']);
    });

    test('remaining puts the closest to done first', () {
      // g1 is finished (0 left), g3 has 15 left, g2 has 10 left.
      final r = sorted(list, GoalSort.remaining);
      expect(idsOf(r).first, 'g1');
      expect(idsOf(r).last, 'g3');
    });

    test('progress puts the most advanced first', () {
      final r = sorted(list, GoalSort.progress);
      expect(idsOf(r), ['g1', 'g3', 'g2']);
    });

    test('streak puts the live streak first', () {
      final rows = [
        entry(goal('g1'), 5, streak: 2, best: 9),
        entry(goal('g2'), 5, streak: 12, best: 12),
        entry(goal('g3'), 5, best: 4),
      ];
      final r = sorted(rows, GoalSort.streak);
      expect(idsOf(r), ['g2', 'g1', 'g3']);
    });

    test('alphabetical sorts by title', () {
      final rows = [
        entry(goal('g1', title: 'مطالعه'), 1),
        entry(goal('g2', title: 'احادیث'), 1),
        entry(goal('g3', title: 'قرآن'), 1),
      ];
      final r = sorted(rows, GoalSort.alphabetical);
      // «ق» is a letter before «م» in Persian, even though م is the lower
      // code point — the reverse of what a plain compareTo gives.
      expect(idsOf(r), ['g2', 'g3', 'g1']);
    });

    test('alphabetical follows Persian letter order, not code points', () {
      // The discriminating case: پ U+067E, گ U+06AF and ه U+0647. Code-point
      // order files them ه, گ, پ — the exact reverse of the dictionary for
      // the first two, because the Persian additions live high in the block.
      final rows = [
        entry(goal('h', title: 'هفت'), 1),
        entry(goal('p', title: 'پنج'), 1),
        entry(goal('g', title: 'گل'), 1),
        entry(goal('b', title: 'چای'), 1),
      ];
      final r = sorted(rows, GoalSort.alphabetical);
      // پ precedes چ (ب پ ت ث ج چ), and ه is last — code-point order would give
      // the exact reverse for the first three.
      expect(idsOf(r), ['p', 'b', 'g', 'h']);
    });

    test('alphabetical puts Latin and Persian titles in a stable order', () {
      final rows = [
        entry(goal('l', title: 'Quran'), 1),
        entry(goal('a', title: 'قرآن'), 1),
      ];
      final r = sorted(rows, GoalSort.alphabetical);
      // Persian-script rows sort ahead of Latin ones, so a mixed list does not
      // interleave by raw code point.
      expect(idsOf(r), ['a', 'l']);
    });

    test('a goal with no deadline never sorts as due today', () {
      // Treating an empty deadline as "overdue" pushed open-ended goals to
      // the top of the deadline order, which is the opposite of useful.
      final rows = [
        entry(goal('open'), 0),
        entry(goal('later', deadline: '2027-01-01'), 0),
      ];
      final r = sorted(rows, GoalSort.deadline);
      expect(idsOf(r), ['later', 'open']);
    });

    test('sorting is stable for equal keys', () {
      final rows = [
        entry(goal('a', title: 'الف'), 0),
        entry(goal('b', title: 'الف'), 0),
      ];
      expect(idsOf(sorted(rows, GoalSort.progress)), ['a', 'b']);
    });
  });

  group('GoalListEntry', () {
    test('fraction is zero for a target-less goal, not NaN', () {
      expect(entry(goal('g1', target: 0), 5).fraction, 0);
    });

    test('fraction is clamped at one', () {
      expect(entry(goal('g1', target: 10), 25).fraction, 1.0);
    });

    test('isComplete follows the target', () {
      expect(entry(goal('g1', target: 10), 10).isComplete, isTrue);
      expect(entry(goal('g1', target: 10), 9).isComplete, isFalse);
      expect(entry(goal('g1', target: 0), 5).isComplete, isFalse);
    });
  });

  group('goalCategoryLabel / goalPriorityLabel', () {
    test('known categories map to Persian labels', () {
      expect(goalCategoryLabel('hifz'), 'حفظ');
      expect(goalCategoryLabel('other'), 'دیگر');
    });

    test('an unknown category still renders something', () {
      // The column predates the feature; rows already exist with values the
      // editor never offered, and they must not crash the list.
      expect(goalCategoryLabel('made-up'), 'دیگر');
      expect(goalCategoryLabel(''), 'دیگر');
    });

    test('priority labels are clamped for a corrupt value', () {
      expect(goalPriorityLabel(0), 'عادی');
      expect(goalPriorityLabel(1), 'متوسط');
      expect(goalPriorityLabel(2), 'زیاد');
      expect(goalPriorityLabel(99), 'زیاد');
      expect(goalPriorityLabel(-1), 'عادی');
    });
  });
}

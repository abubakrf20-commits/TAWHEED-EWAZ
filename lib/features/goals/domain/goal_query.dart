import 'package:flutter/foundation.dart' show immutable;
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/goals/domain/goal_streak.dart';
import 'package:tawheeed/features/goals/presentation/utils/goal_dates.dart';

export 'package:tawheeed/features/goals/domain/goal_streak.dart'
    show GoalStreak, goalStreakFrom;

/// How the list is ordered.
enum GoalSort {
  /// The user's own ordering: important and new work first.
  manual('اولویت و جدیدترین'),

  /// Soonest deadline first. Goals with no deadline sink to the bottom
  /// instead of being treated as "due immediately".
  deadline('نزدیک‌ترین مهلت'),

  /// Closest to finished first — the ones about to be worth archiving.
  remaining('نزدیک‌ترین به اتمام'),

  /// Most progress made so far.
  progress('بیشترین پیشرفت'),

  /// Streak first, because a live streak is the thing worth protecting.
  streak('بیشترین پیشرفت پیوسته'),

  alphabetical('الفبایی');

  const GoalSort(this.label);
  final String label;
}

/// Which goals the list shows.
class GoalFilter {
  /// Free text over the title and description.
  final String query;

  /// Empty means «no category filter».
  final String? category;

  /// Null means «any priority».
  final int? priority;

  /// Hide goals whose target has already been reached.
  final bool hideCompleted;

  const GoalFilter({
    this.query = '',
    this.category,
    this.priority,
    this.hideCompleted = false,
  });

  bool get isEmpty =>
      query.trim().isEmpty &&
      category == null &&
      priority == null &&
      !hideCompleted;

  GoalFilter copyWith({
    String? query,
    String? category,
    int? priority,
    bool? hideCompleted,
    bool clearCategory = false,
    bool clearPriority = false,
  }) =>
      GoalFilter(
        query: query ?? this.query,
        category: clearCategory ? null : (category ?? this.category),
        priority: clearPriority ? null : (priority ?? this.priority),
        hideCompleted: hideCompleted ?? this.hideCompleted,
      );

  // Without these, two filters with identical text compare unequal, so
  // GoalListOptions.== fell back to identity and Riverpod notified every
  // listener on each keystroke — including ones that only render the sort.
  @override
  bool operator ==(Object other) =>
      other is GoalFilter &&
      other.query == query &&
      other.category == category &&
      other.priority == priority &&
      other.hideCompleted == hideCompleted;

  @override
  int get hashCode => Object.hash(query, category, priority, hideCompleted);
}

/// The view's search text, filters and ordering, as one immutable value.
///
/// Held by [GoalListOptions] so that changing the sort does not rebuild every
/// consumer watching the filter, and vice versa — a keystroke in the search
/// field should not invalidate a widget that only cares about the ordering.
@immutable
class GoalListOptions {
  final GoalFilter filter;
  final GoalSort sort;

  const GoalListOptions(
      {this.filter = const GoalFilter(), this.sort = GoalSort.manual});

  /// True when nothing narrows the list, so the screen can tell an empty
  /// database apart from an over-restrictive filter.
  bool get isEmpty => filter.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is GoalListOptions && other.filter == filter && other.sort == sort;

  @override
  int get hashCode => Object.hash(filter, sort);
}

/// The categories the editor can produce, in the order a user thinks about
/// them. Keyed to `GoalTableData.category`.
const List<(String, String)> kGoalCategories = [
  ('hifz', 'حفظ'),
  ('quran', 'قرآن'),
  ('prayer', 'نماز'),
  ('study', 'مطالعه'),
  ('ibadat', 'عبادت'),
  ('health', 'سلامت'),
  ('other', 'دیگر'),
];

/// Persian label for [category], or «دیگر» for anything unknown.
///
/// An unknown key must still render something: the column predates this
/// feature and rows already exist with values the editor never offered.
String goalCategoryLabel(String category) {
  for (final entry in kGoalCategories) {
    if (entry.$1 == category) return entry.$2;
  }
  return 'دیگر';
}

/// Priority labels indexed by `GoalTableData.priority` (0 = normal).
const List<String> kGoalPriorityLabels = ['عادی', 'متوسط', 'زیاد'];

/// Label for a stored priority, clamped so a corrupt value cannot crash the
/// list.
String goalPriorityLabel(int priority) =>
    kGoalPriorityLabels[priority.clamp(0, kGoalPriorityLabels.length - 1)];

/// One goal plus the numbers the list needs to sort and display it.
///
/// The row itself cannot answer "how far along is this", so [total] and
/// [streak] travel alongside it rather than being looked up per card.
class GoalListEntry {
  final GoalTableData goal;
  final int total;
  final GoalStreak streak;

  const GoalListEntry({
    required this.goal,
    required this.total,
    required this.streak,
  });

  /// Whether the target has been reached. A goal with no numeric target
  /// (boolean) is complete once one positive day is recorded, which is the
  /// whole point of a boolean goal.
  bool get isComplete {
    if (goal.targetType == 'boolean') return total > 0;
    if (goal.targetNumber <= 0) return false;
    return total >= goal.targetNumber;
  }

  double get fraction {
    if (goal.targetNumber <= 0) return 0;
    return (total / goal.targetNumber).clamp(0.0, 1.0);
  }

  int get remaining {
    final r = goal.targetNumber - total;
    return r < 0 ? 0 : r;
  }
}

/// Apply [filter] and order by [sort].
///
/// Pure and in-memory on purpose: the goal list is a handful of rows, and
/// keeping it out of SQL means the rules are unit-testable and identical
/// whether the caller is a widget or a test.
List<GoalListEntry> applyGoalQuery(
  List<GoalListEntry> entries, {
  required GoalFilter filter,
  GoalSort sort = GoalSort.manual,
  DateTime? today,
}) {
  final now = today ?? DateTime.now();
  final q = _normalize(filter.query.trim());

  final filtered = entries.where((e) {
    if (filter.category != null && e.goal.category != filter.category) {
      return false;
    }
    if (filter.priority != null && e.goal.priority != filter.priority) {
      return false;
    }
    if (filter.hideCompleted && e.isComplete) return false;
    if (q.isNotEmpty) {
      // The user's own script, lower-cased once. Matching is substring-based
      // on both title and description: a goal is often found by a word in its
      // notes («جز ۳۰») rather than by its title.
      final haystack = _normalize('${e.goal.title} ${e.goal.description}');
      if (!haystack.contains(q)) return false;
    }
    return true;
  }).toList();

  filtered.sort((a, b) {
    // Inactive goals sink under every sort — see [_byActivity].
    final byActivity = _byActivity(a, b);
    if (byActivity != 0) return byActivity;
    return _compare(a, b, sort, now);
  });
  return filtered;
}

int _compare(GoalListEntry a, GoalListEntry b, GoalSort sort, DateTime now) {
  switch (sort) {
    case GoalSort.manual:
      // Priority desc, then newest first. Completed goals sink: a finished
      // goal is history, and leaving it pinned above live work was the
      // complaint that made the list feel stuck.
      if (a.isComplete != b.isComplete) return a.isComplete ? 1 : -1;
      if (a.goal.priority != b.goal.priority) {
        return b.goal.priority.compareTo(a.goal.priority);
      }
      return b.goal.createdAt.compareTo(a.goal.createdAt);
    case GoalSort.deadline:
      return _byDeadline(a, b);
    case GoalSort.remaining:
      // Completed goals come FIRST, not last. The sort exists to answer "what
      // is closest to being finished", and a met goal is the closest thing
      // there is — it is also the one worth archiving. Sinking them here
      // contradicted the option's own description.
      if (a.isComplete != b.isComplete) return a.isComplete ? -1 : 1;
      return a.remaining.compareTo(b.remaining);
    case GoalSort.progress:
      return b.fraction.compareTo(a.fraction);
    case GoalSort.streak:
      if (a.streak.current != b.streak.current) {
        return b.streak.current.compareTo(a.streak.current);
      }
      return b.streak.best.compareTo(a.streak.best);
    case GoalSort.alphabetical:
      return compareForDisplay(a.goal.title, b.goal.title);
  }
}

/// A paused goal is not work in progress.
///
/// Without this, marking a high-priority goal inactive left it pinned above
/// every active goal in the default order, because nothing in the comparison
/// looked at `isActive` — the card showed a «غیرفعال» label and the list still
/// asked the user to look at it first. Applied to every ordering, since a
/// paused goal should not outrank live work under any sort.
int _byActivity(GoalListEntry a, GoalListEntry b) =>
    a.goal.isActive == b.goal.isActive ? 0 : (a.goal.isActive ? -1 : 1);

int _byDeadline(GoalListEntry a, GoalListEntry b) {
  final da = goalDaysUntil(a.goal.deadline);
  final db = goalDaysUntil(b.goal.deadline);
  // No deadline is not «due today». Open-ended goals go last, not first.
  if (da == null && db == null) {
    return b.goal.createdAt.compareTo(a.goal.createdAt);
  }
  if (da == null) {
    return 1;
  }
  if (db == null) {
    return -1;
  }
  return da.compareTo(db);
}

/// Arabic/Persian letter folding for search.
///
/// The user types «ياد» with a Persian keyboard and the goal is titled
/// «یادداشت» with an Arabic yeh. A byte comparison says they differ, which
/// makes search look broken for exactly the words the user just wrote. This
/// folds the six letters whose code points differ between the two scripts,
/// plus Arabic/Persian digits, to one form each.
String _normalize(String input) {
  const folds = <int, int>{
    0x064A: 0x06CC, // ARABIC YEH   → FARSI YEH
    0x0649: 0x06CC, // ALEF MAKSURA → FARSI YEH
    0x0643: 0x06A9, // ARABIC KAF   → KEHEH
    0x06A9: 0x06A9, // KEHEH         → KEHEH
    0x0629: 0x0647, // TEH MARBUTA  → HEH
    0x0623: 0x0627, // ALEF WITH HAMZA ABOVE → ALEF
    0x0622: 0x0627, // ALEF WITH MADDA ABOVE → ALEF
    0x0625: 0x0627, // ALEF WITH HAMZA BELOW → ALEF
    0x06F0: 0x06F0, // EXTENDED ARABIC DIGIT ZERO
    0x06F1: 0x0030,
    0x06F2: 0x0031,
    0x06F3: 0x0032,
    0x06F4: 0x0033,
    0x06F5: 0x0034,
    0x06F6: 0x0035,
    0x06F7: 0x0036,
    0x06F8: 0x0037,
    0x06F9: 0x0038,
  };
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    // Diacritics (fatha, damma, kasra, shadda, sukun, tanwin) and the
    // tatweel are dropped, not folded. Persian keyboards add them casually
    // and users do not notice they typed one, so a search for «مطالعه» has to
    // find «مُطالعه» — otherwise search looks broken on the user's own words.
    if (rune >= 0x064B && rune <= 0x065F) continue;
    if (rune == 0x0670) continue; // superscript alef
    if (rune == 0x0640) continue; // tatweel / kashida
    buffer.writeCharCode(folds[rune] ?? rune);
  }
  return buffer.toString().toLowerCase();
}

/// Persian dictionary order, as a rank per letter.
///
/// Sorting Persian by code point is wrong in a way users notice constantly:
/// «پ» is U+067E and «گ» is U+06AF, both far above «ه» (U+0647) and «ی»
/// (U+06CC), so a code-point sort files every goal starting with those letters
/// at the very end of a list. The collation is by position in the alphabet,
/// so the rank has to be written out — there is no arithmetic that recovers
/// it.
const List<String> _persianAlphabet = [
  'ا', 'آ', 'أ', 'إ', 'ٱ', //
  'ب', 'پ', //
  'ت', 'ث', //
  'ج', 'چ', //
  'ح', 'خ', //
  'د', 'ذ', //
  'ر', 'ز', 'ژ', //
  'س', 'ش', //
  'ص', 'ض', //
  'ط', 'ظ', //
  'ع', 'غ', //
  'ف', 'ق', //
  'ک', 'گ', //
  'ل', 'م', 'ن', //
  'و', 'ؤ', //
  'ه', 'ة', 'ی', 'ي', 'ى', 'ئ', //
];

/// Rank of the first Persian-alphabet letter in [s], or null if it has none.
///
/// Compared on the *normalized* string, so «ي» and «ی» and a word carrying
/// diacritics all land on the same rank.
int? _persianRank(String s) {
  for (final rune in s.runes) {
    final ch = String.fromCharCode(rune);
    final i = _persianAlphabet.indexOf(ch);
    if (i >= 0) return i;
  }
  return null;
}

/// Collator for [GoalSort.alphabetical].
///
/// Persian letters first, by dictionary order; then anything else (Latin,
/// digits) by code point, so a mixed-script list is still deterministic. The
/// normalized form is the tiebreaker so «مُطالعه» and «مطالعه» do not swap
/// places between rebuilds.
int compareForDisplay(String a, String b) {
  final na = _normalize(a);
  final nb = _normalize(b);
  final ra = _persianRank(na);
  final rb = _persianRank(nb);
  if (ra != null && rb != null && ra != rb) return ra.compareTo(rb);
  if (ra != null && rb == null) return -1;
  if (ra == null && rb != null) return 1;
  final c = na.compareTo(nb);
  return c != 0 ? c : a.compareTo(b);
}

import 'package:tawheeed/features/tasks/domain/task_recurrence.dart';
import 'package:tawheeed/shared/utils/date_range.dart';

/// Weekly-completion helpers for the «آمار هفتگی» card.
///
/// The Iranian week starts on Saturday — the same mapping the rest of the
/// app uses — so index 0 = شنبه … 6 = جمعه (Dart's `weekday` is
/// 1 = Monday … 7 = Sunday).
int taskWeekIndex(DateTime date) => (date.weekday + 1) % 7;

/// One-letter Persian weekday labels, Saturday first (شنبه … جمعه).
const List<String> taskWeekdayShortFa = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];

/// Persian full weekday name of a week index (0 = شنبه).
String taskWeekdayNameFa(int index) => TaskRecurrence.weekdayNamesFa[index % 7];

/// Midnight of the Saturday that starts the week containing [now].
DateTime taskWeekStart(DateTime now) => DateTime(now.year, now.month, now.day)
    .subtract(Duration(days: taskWeekIndex(now)));

/// How many completions fall on each day of the week containing [now]
/// (index 0 = شنبه … 6 = جمعه). Completions outside that week are ignored.
List<int> weeklyCompletionCounts(List<DateTime> completions, DateTime now) {
  final counts = List<int>.filled(7, 0);
  final start = taskWeekStart(now);
  final end = start.addCalendarDaysFromMidnight(7);
  for (final c in completions) {
    if (c.isBefore(start) || !c.isBefore(end)) continue;
    counts[taskWeekIndex(c)]++;
  }
  return counts;
}

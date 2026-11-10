import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/personal2/kids/domain/kid_logic.dart';

/// The monthly report is the weekly roll-up over a longer window, so the only
/// new pieces are the window itself and the way the roll-up adds up 30 days.
/// Both are pinned here; the screen is a switch between two provider families.
void main() {
  test('the thirty-day window ends today and holds thirty distinct days', () {
    final keys = weekKeysEndingAt('1405-08-14', days: 30);
    expect(keys, hasLength(30));
    expect(keys.last, '1405-08-14');
    expect(keys.toSet(), hasLength(30));
    expect(keys.first, '1405-07-15');
  });

  test('a month collects every scheduled day, not just the week', () {
    final keys = weekKeysEndingAt('1405-08-14', days: 30);
    const habit = HabitSpec(
      id: 'h1',
      title: 'مسواک',
      iconKey: 'brush',
      stars: 1,
      schedule: HabitSchedule.daily,
    );
    final scheduled = {
      for (final key in keys) 'h1|$key',
    };
    final done = {
      for (final key in keys.take(21)) 'h1|$key',
    };

    final summary = buildWeeklySummary(
      dayKeys: keys,
      habits: [habit],
      doneHabitDays: done,
      scheduledHabitDays: scheduled,
      prayersDone: 0,
      prayersScheduled: 0,
      starsEarned: 21,
      activeDayKeys: done.map((e) => e.split('|').last).toSet(),
    );

    expect(summary.dayKeys, hasLength(30));
    expect(summary.perDayDone, hasLength(30));
    expect(summary.perDayDone.reduce((a, b) => a + b), 21);
    expect(summary.habits.single.doneDays, 21);
    expect(summary.habits.single.scheduledDays, 30);
    expect(summary.activeDays, 21);
  });

  test('an empty window is empty, not an exception', () {
    expect(weekKeysEndingAt('not-a-day', days: 30), isEmpty);
  });
}

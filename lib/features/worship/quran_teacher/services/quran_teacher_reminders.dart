/// The Quran teacher tool's reminders — the settings row had switches and quiet
/// hours, and nothing anywhere scheduled a notification for them.
///
/// Two nudges, both honest about what the app can know:
///  * **ثبت درس امروز** — only when a session exists for today and has no
///    lesson recorded yet. There is no timetable in this tool, so «no session
///    today» is not evidence of anything and is never nudged.
///  * **خلاصهٔ هفتگی** — a Friday-evening pointer to the week's review. The
///    counts are not invented: the text names nothing it cannot know.
library;

import 'package:shamsi_date/shamsi_date.dart';

import 'package:tawheeed/features/personal2/shared/soft_notifier.dart';
import 'package:tawheeed/features/worship/quran_teacher/data/quran_teacher_dao.dart';
import 'package:tawheeed/features/worship/quran_teacher/domain/quran_teacher_logic.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

class QuranTeacherReminderPlan {
  const QuranTeacherReminderPlan({
    required this.key,
    required this.at,
    required this.title,
    required this.body,
  });

  final String key;
  final DateTime at;
  final String title;
  final String body;
}

String quranTeacherDayKeyOf(DateTime date) {
  final j = Jalali.fromDateTime(date);
  return '${j.year.toString().padLeft(4, '0')}-'
      '${j.month.toString().padLeft(2, '0')}-'
      '${j.day.toString().padLeft(2, '0')}';
}

/// 20:00 the same day, for each class that has a session today without lessons.
QuranTeacherReminderPlan? planUnrecordedLessonNudge({
  required TeacherSettingsRecord settings,
  required List<String> unrecordedClassNames,
  required DateTime now,
}) {
  if (!settings.remindersEnabled || !settings.unrecordedReminder) return null;
  if (unrecordedClassNames.isEmpty) return null;
  final at = DateTime(now.year, now.month, now.day, 20);
  if (!at.isAfter(now)) return null;

  final names = unrecordedClassNames;
  const title = 'ثبت درس امروز';
  final body = names.length == 1
      ? 'جلسهٔ امروز «${names.first}» هنوز درس ثبت‌نشده دارد.'
      : '${names.length} جلسهٔ امروز هنوز درس ثبت‌نشده دارد.';
  return QuranTeacherReminderPlan(
    key: 'unrecorded_${quranTeacherDayKeyOf(now)}',
    at: at,
    title: title,
    body: body,
  );
}

/// Half an hour before each class that meets today, using the class's own
/// start time from «مدیریت کلاس‌ها» — the one piece of timetable this tool has.
List<QuranTeacherReminderPlan> planClassStartNudges({
  required TeacherSettingsRecord settings,
  required List<ClassGroupRecord> classes,
  required DateTime now,
}) {
  if (!settings.remindersEnabled || !settings.classStartReminder) {
    return const [];
  }
  final dayKey = quranTeacherDayKeyOf(now);
  final plans = <QuranTeacherReminderPlan>[];
  for (final klass in classes) {
    if (klass.archived) continue;
    final start = klass.startMinutes;
    if (start == null) continue;
    if (!classMeetsOn(dayKey, klass.weekdaysMask)) continue;
    final startAt =
        DateTime(now.year, now.month, now.day, start ~/ 60, start % 60);
    final at = startAt.subtract(const Duration(minutes: 30));
    if (!at.isAfter(now)) continue;
    final clock = '${(start ~/ 60).toString().padLeft(2, '0')}:' '${(start % 60).toString().padLeft(2, '0')}';
    plans.add(QuranTeacherReminderPlan(
      key: 'classstart_${klass.id}_$dayKey',
      at: at,
      title: 'کلاس ${klass.name}',
      body: 'کلاس ساعت $clock شروع می‌شود؛ نیم ساعت وقت دارید.',
    ));
  }
  return plans;
}

/// Friday 19:00 — this week's if it is still ahead, next week's otherwise.
QuranTeacherReminderPlan? planWeeklySummary({
  required TeacherSettingsRecord settings,
  required DateTime now,
}) {
  if (!settings.remindersEnabled || !settings.weeklySummary) return null;
  final j = Jalali.fromDateTime(now);
  // Jalali.weekDay: 1 = Saturday … 7 = Friday.
  final daysToFriday = 7 - j.weekDay;
  var friday = j.addDays(daysToFriday).toDateTime();
  var at = DateTime(friday.year, friday.month, friday.day, 19);
  if (!at.isAfter(now)) {
    friday = j.addDays(daysToFriday + 7).toDateTime();
    at = DateTime(friday.year, friday.month, friday.day, 19);
  }
  return QuranTeacherReminderPlan(
    key: 'weekly_${quranTeacherDayKeyOf(at)}',
    at: at,
    title: 'خلاصهٔ هفتهٔ کلاس',
    body: 'یک نگاه به هفتهٔ گذشته: حضور و غیبت‌ها و درس‌های ثبت‌شده را مرور کنید.',
  );
}

/// Schedules (and clears) the teacher nudges through [SoftNotifier], so the
/// quiet-hours window the settings row already carries applies to them.
class QuranTeacherReminders {
  QuranTeacherReminders({SoftNotifier? notifier})
      : _notifier = notifier ?? SoftNotifier();

  final SoftNotifier _notifier;

  static const List<String> _fixedKeys = ['quran_teacher_daily', 'quran_teacher_weekly'];

  Future<int> sync({
    required TeacherSettingsRecord settings,
    required List<ClassGroupRecord> classes,
    required List<String> unrecordedClassNames,
    required DateTime now,
  }) async {
    try {
      final plans = [
        ...planClassStartNudges(
          settings: settings,
          classes: classes,
          now: now,
        ),
        if (planUnrecordedLessonNudge(
          settings: settings,
          unrecordedClassNames: unrecordedClassNames,
          now: now,
        )
            case final plan?)
          plan,
        if (planWeeklySummary(settings: settings, now: now) case final plan?)
          plan,
      ];

      if (!settings.remindersEnabled) {
        await cancel(now: now, classes: classes);
        return 0;
      }

      // A plan made earlier today (or last week) must not survive as a second
      // buzz on the same evening.
      for (final key in _staleKeys(now, classes)) {
        if (!plans.any((p) => p.key == key)) {
          await _notifier.cancel(tool: 'quran_teacher', key: key);
        }
      }

      var scheduled = 0;
      for (final plan in plans) {
        final ok = await _notifier.schedule(
          tool: 'quran_teacher',
          key: plan.key,
          title: plan.title,
          body: plan.body,
          when: plan.at,
          quietStartMinutes: settings.quietStartMinutes,
          quietEndMinutes: settings.quietEndMinutes,
          payload: 'quran_teacher_reminder',
        );
        if (ok) scheduled++;
      }
      return scheduled;
    } catch (e) {
      AppLogger.warning('QuranTeacherReminders', 'sync failed: $e');
      return 0;
    }
  }

  Future<void> cancel({
    required DateTime now,
    required List<ClassGroupRecord> classes,
  }) async {
    for (final key in _staleKeys(now, classes)) {
      await _notifier.cancel(tool: 'quran_teacher', key: key);
    }
  }

  Iterable<String> _staleKeys(
    DateTime now,
    List<ClassGroupRecord> classes,
  ) sync* {
    yield* _fixedKeys;
    for (var offset = -1; offset <= 8; offset++) {
      final day = DateTime(now.year, now.month, now.day).add(Duration(days: offset));
      yield 'unrecorded_${quranTeacherDayKeyOf(day)}';
      for (final klass in classes) {
        yield 'classstart_${klass.id}_${quranTeacherDayKeyOf(day)}';
      }
    }
    // Friday keys for this week and the next one.
    for (var week = 0; week < 2; week++) {
      final today = Jalali.fromDateTime(now);
      final day = DateTime(now.year, now.month, now.day).add(Duration(days: 7 * week + (7 - today.weekDay)));
      yield 'weekly_${quranTeacherDayKeyOf(day)}';
    }
  }
}

/// The kids evening nudge — the one reminder `kid_settings` has a switch and an
/// hour for, and which nothing scheduled until now.
///
/// It is deliberately a *nudge*, not a report: the counts are known only for
/// tonight, so tonight's notification can name them while the following days
/// say «کارهای امروز را یک نگاه بیندازید». Seven days are scheduled and each
/// one carries its own `evening_<dayKey>` key, so switching the feature off can
/// cancel exactly the ones it created.
library;

import 'package:shamsi_date/shamsi_date.dart';

import 'package:tawheeed/features/personal2/kids/data/kids_dao.dart';
import 'package:tawheeed/features/personal2/shared/soft_notifier.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// How many nights ahead are scheduled in one pass.
///
/// A day's plan is a one-shot notification, so something has to keep topping
/// the queue up; a week is long enough that a phone left alone still nudges,
/// and short enough that a changed hour takes effect without a stale week.
const int kKidEveningHorizonDays = 7;

class KidEveningPlan {
  const KidEveningPlan({
    required this.dayKey,
    required this.at,
    required this.title,
    required this.body,
  });

  final String dayKey;
  final DateTime at;
  final String title;
  final String body;

  String get key => 'evening_$dayKey';
}

String kidDayKeyOf(DateTime date) {
  final j = Jalali.fromDateTime(date);
  return '${j.year.toString().padLeft(4, '0')}-'
      '${j.month.toString().padLeft(2, '0')}-'
      '${j.day.toString().padLeft(2, '0')}';
}

/// Text for tonight, with the day's real counts.
String kidEveningBody({
  required String kidName,
  required int done,
  required int total,
  required int stars,
}) {
  if (total <= 0) {
    return 'برای $kidName کاری برای امروز ثبت نشده؛ یک لحظه نگاهش بیندازید.';
  }
  final starsPart = stars > 0 ? ' · $stars ستاره' : '';
  if (done >= total) {
    return 'همهٔ $total کار $kidName امروز انجام شد$starsPart.';
  }
  return '$done از $total کار $kidName امروز انجام شد$starsPart.';
}

/// The plans for tonight and the next [days] − 1 nights.
///
/// Returns an empty list when the feature is off or the hour for tonight has
/// already passed — a summary for a moment that has gone is not scheduled, and
/// tomorrow's plan is built from tomorrow's counts.
List<KidEveningPlan> planKidEvening({
  required KidSettingsRecord settings,
  required String kidName,
  required int done,
  required int total,
  required int stars,
  required DateTime now,
  int days = kKidEveningHorizonDays,
}) {
  if (!settings.eveningSummaryEnabled) return const [];
  final minutes = settings.eveningSummaryMinutes;
  if (minutes < 0 || minutes > 1439) return const [];

  final plans = <KidEveningPlan>[];
  for (var offset = 0; offset < days; offset++) {
    final day = DateTime(now.year, now.month, now.day)
        .add(Duration(days: offset));
    final at = DateTime(
      day.year,
      day.month,
      day.day,
      minutes ~/ 60,
      minutes % 60,
    );
    if (!at.isAfter(now)) continue; // today's hour has passed
    plans.add(KidEveningPlan(
      dayKey: kidDayKeyOf(day),
      at: at,
      title: offset == 0 ? 'خلاصهٔ امروز $kidName' : 'دفتر $kidName',
      body: offset == 0
          ? kidEveningBody(
              kidName: kidName,
              done: done,
              total: total,
              stars: stars,
            )
          : '$kidName امروز چه کرد؟ ثبت کارها را یک بار نگاه بیندازید.',
    ));
  }
  return plans;
}

/// Schedules (or cancels) the kids evening nudges through [SoftNotifier], so
/// the quiet-hours window and the daily cap apply to them like every other
/// personal-tool reminder.
class KidEveningSummaryService {
  KidEveningSummaryService({SoftNotifier? notifier})
      : _notifier = notifier ?? SoftNotifier();

  final SoftNotifier _notifier;

  /// Returns how many notifications are now pending for this child.
  Future<int> sync({
    required KidSettingsRecord settings,
    required String kidName,
    required int done,
    required int total,
    required int stars,
    required DateTime now,
  }) async {
    try {
      if (!settings.eveningSummaryEnabled) {
        await cancelAll(now: now);
        return 0;
      }
      final plans = planKidEvening(
        settings: settings,
        kidName: kidName,
        done: done,
        total: total,
        stars: stars,
        now: now,
      );
      final wanted = plans.map((p) => p.key).toSet();
      // Yesterday's key (and any key from a previous hour choice) must not
      // linger as a second nudge on the same evening.
      for (final stale in _staleKeys(now)) {
        if (!wanted.contains(stale)) {
          await _notifier.cancel(tool: 'kids', key: stale);
        }
      }
      var scheduled = 0;
      for (final plan in plans) {
        final ok = await _notifier.schedule(
          tool: 'kids',
          key: plan.key,
          title: plan.title,
          body: plan.body,
          when: plan.at,
          quietStartMinutes: settings.quietStartMinutes,
          quietEndMinutes: settings.quietEndMinutes,
          payload: 'kids_evening',
          now: now,
        );
        if (ok) scheduled++;
      }
      return scheduled;
    } catch (e) {
      AppLogger.warning('KidEveningSummary', 'sync failed: $e');
      return 0;
    }
  }

  /// Cancels every evening key this feature could have created.
  Future<void> cancelAll({required DateTime now}) async {
    for (final key in _staleKeys(now)) {
      await _notifier.cancel(tool: 'kids', key: key);
    }
  }

  /// Every `evening_<dayKey>` this service may have written: the horizon ahead
  /// plus a few days back, so a plan made yesterday is cleaned up too.
  Iterable<String> _staleKeys(DateTime now) sync* {
    for (var offset = -3; offset < kKidEveningHorizonDays; offset++) {
      final day =
          DateTime(now.year, now.month, now.day).add(Duration(days: offset));
      yield 'evening_${kidDayKeyOf(day)}';
    }
  }
}

/// Reminder planning for «دفتر مالی» — pure, no plugin, no I/O.
///
/// The rules the spec asks for, each one visible in a test:
/// * a reminder [Obligation.remindBeforeDays] before the due date, at the
///   user's preferred hour;
/// * one ON the due day;
/// * one the day after an unpaid due date («عقبافتاده»), and never more —
///   a daily nag is how a reminder becomes noise;
/// * everything that lands on the same day collapses into ONE notification;
/// * quiet hours push the time to the end of the quiet window;
/// * only the next `horizonDays` days are scheduled.
library;

import 'package:tawheeed/features/personal/finance/finance_engine.dart';
import 'package:tawheeed/features/personal/finance/finance_models.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// User-tunable behaviour, stored beside the stage-1 care settings.
class FinanceReminderSettings {
  const FinanceReminderSettings({
    this.enabled = true,
    this.hour = 9,
    this.quietStart = 22,
    this.quietEnd = 7,
    this.horizonDays = 30,
    this.overdueReminderEnabled = true,
  });

  final bool enabled;

  /// Preferred hour of day (0–23).
  final int hour;
  final int quietStart;
  final int quietEnd;
  final int horizonDays;

  /// When true, obligations that passed their due date without being paid also
  /// get a single reminder the next day.
  final bool overdueReminderEnabled;

  bool isQuietAt(int hourOfDay) {
    if (quietStart == quietEnd) return false;
    if (quietStart < quietEnd) {
      return hourOfDay >= quietStart && hourOfDay < quietEnd;
    }
    return hourOfDay >= quietStart || hourOfDay < quietEnd;
  }

  /// The hour a reminder actually fires at, after quiet hours.
  int get effectiveHour => isQuietAt(hour) ? quietEnd : hour;

  FinanceReminderSettings copyWith({
    bool? enabled,
    int? hour,
    int? quietStart,
    int? quietEnd,
    int? horizonDays,
    bool? overdueReminderEnabled,
  }) =>
      FinanceReminderSettings(
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        quietStart: quietStart ?? this.quietStart,
        quietEnd: quietEnd ?? this.quietEnd,
        horizonDays: horizonDays ?? this.horizonDays,
        overdueReminderEnabled: overdueReminderEnabled ?? this.overdueReminderEnabled,
      );
}

/// One OS notification to post.
class FinanceReminderEvent {
  const FinanceReminderEvent({
    required this.at,
    required this.title,
    required this.body,
    required this.payload,
    required this.items,
  });

  final DateTime at;
  final String title;
  final String body;

  /// `finance_obligation_<id>` for one row, `finance_day_<yyyy-MM-dd>` for a
  /// grouped day. The scheduler's cancellation keys on the prefix.
  final String payload;
  final List<Obligation> items;

  bool get isGroup => items.length > 1;
}

class FinanceReminderPlanner {
  const FinanceReminderPlanner();

  /// Money for a notification body: no currency symbol soup, just the user's
  /// unit (the same `NumberFormat.formatMoney` the app uses everywhere).
  static String _money(double value, String unit) =>
      NumberFormat.formatMoney(value, unit);

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  List<FinanceReminderEvent> plan({
    required FinanceSnapshot snapshot,
    required FinanceReminderSettings settings,
    required DateTime now,
    String currencyUnit = 'تومان',
  }) {
    if (!settings.enabled) return const [];
    final today = financeDay(now);
    final end = today.add(Duration(days: settings.horizonDays));
    final hour = settings.effectiveHour;

    // day → obligations due that day (for the «due today» and overdue notes)
    final buckets = <DateTime, List<Obligation>>{};
    void addAt(DateTime day, Obligation o) {
      if (day.isBefore(today) || day.isAfter(end)) return;
      buckets.putIfAbsent(day, () => []).add(o);
    }

    for (final o in snapshot.obligations) {
      if (!o.status.isActive) continue;
      final due = financeDay(o.dueDate);
      addAt(due.subtract(Duration(days: o.remindBeforeDays)), o);
      addAt(due, o);
      // Overdue reminder: only when the user has opted in.
      if (settings.overdueReminderEnabled) {
        addAt(due.add(const Duration(days: 1)), o);
      }
    }

    final events = <FinanceReminderEvent>[];
    final days = buckets.keys.toList()..sort();
    for (final day in days) {
      final items = buckets[day] ?? const <Obligation>[];
      if (items.isEmpty) continue;
      final at = DateTime(day.year, day.month, day.day, hour);
      if (!at.isAfter(now)) continue;

      // A row can appear twice on the same day (its «before» window and the
      // due day itself when remindBeforeDays is 0); dedupe by id.
      final unique = <String, Obligation>{};
      for (final o in items) {
        unique[o.id] = o;
      }
      final list = unique.values.toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
      final total = list.fold<double>(0, (sum, o) => sum + o.amount);

      if (list.length == 1) {
        final o = list.first;
        final dueDay = financeDay(o.dueDate);
        final late = financeDaysBetween(dueDay, day);
        final when = late > 0
            ? '$late روز از موعد گذشته'
            : late == 0
                ? 'امروز سررسید است'
                : '${financeDaysBetween(day, dueDay)} روز تا سررسید';
        events.add(FinanceReminderEvent(
          at: at,
          title: '${o.kind.labelFa} · ${o.title}',
          body: '${_money(o.amount, currencyUnit)} — $when',
          payload: 'finance_obligation_${o.id}',
          items: list,
        ));
      } else {
        events.add(FinanceReminderEvent(
          at: at,
          title: '${list.length} تعهد مالی',
          body: '${_money(total, currencyUnit)} — '
              '${list.first.dueDate.isBefore(today) ? 'برخی عقب‌افتاده‌اند' : 'در پیش رو'}',
          payload: 'finance_day_${_dateKey(day)}',
          items: list,
        ));
      }
    }
    return events;
  }
}

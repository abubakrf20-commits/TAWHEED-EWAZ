/// Pure planning of care reminders — no notification plugin, no I/O.
///
/// The scheduler maps these events onto the app's existing notification
/// service; the tests drive THIS file, so the windowing, quiet hours, per-day
/// grouping and cap are verified without an OS.
library;

import 'package:tawheeed/features/personal/care_engine/care_engine.dart';
import 'package:tawheeed/features/personal/services/care_settings.dart';

/// One OS notification to post.
class CareReminderEvent {
  const CareReminderEvent({
    required this.at,
    required this.title,
    required this.body,
    required this.payload,
    required this.items,
  });

  final DateTime at;
  final String title;
  final String body;

  /// `care_task_<id>` for a single item, `care_day_<yyyy-MM-dd>` for a group.
  final String payload;
  final List<CareDueItem> items;

  bool get isGroup => items.length > 1;
}

/// Turns due items into at most one notification per day, inside the horizon.
class CareReminderPlanner {
  const CareReminderPlanner();

  static String _payloadFor(List<CareDueItem> items) {
    if (items.length == 1) return items.first.payload;
    final d = items.first.remindDate;
    final date = '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    return 'care_day_$date';
  }

  List<CareReminderEvent> plan({
    required List<CareDueItem> items,
    required CareReminderSettings settings,
    required DateTime now,
    Duration? horizon,
  }) {
    if (!settings.enabled) return const [];
    final horizonDays = horizon?.inDays ?? settings.horizonDays;
    final end = DateTime(now.year, now.month, now.day)
        .add(Duration(days: horizonDays));

    // Bucket by the reminder DAY, after applying category + quiet-hour rules.
    final byDay = <DateTime, List<CareDueItem>>{};
    for (final item in items) {
      if (!settings.allowsCategory(item.category)) continue;
      final day = DateTime(
        item.remindDate.year,
        item.remindDate.month,
        item.remindDate.day,
      );
      if (day.isAfter(end)) continue;
      final hour = settings.categoryHours[item.category] ?? settings.hour;
      final at = DateTime(day.year, day.month, day.day, hour);
      // A reminder that already passed today has nothing left to announce.
      if (!at.isAfter(now)) continue;
      // Quiet hours suppress, they do not shift: the user asked for silence,
      // not for the same notification at 07:00.
      if (settings.isQuietAt(settings.hour)) continue;
      byDay.putIfAbsent(day, () => []).add(item);
    }

    final days = byDay.keys.toList()..sort();
    final events = <CareReminderEvent>[];
    for (final day in days) {
      final dayItems = byDay[day] ?? <CareDueItem>[];
      dayItems.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      // Group into ONE summary notification per day; the channel's daily cap
      // then holds trivially, but keep the cap for a future per-item mode.
      final at = DateTime(day.year, day.month, day.day, settings.hour);
      final grouped = dayItems.take(settings.dailyCap).toList();
      if (grouped.isEmpty) continue;
      final single = grouped.length == 1;
      final title = single
          ? 'یادآوری: ${grouped.first.title}'
          : '${grouped.length} مورد سررسید دارید';
      final body = single
          ? _singleBody(grouped.first)
          : grouped
              .take(3)
              .map((i) => '• ${i.title}')
              .followedBy(grouped.length > 3
                  ? ['و ${grouped.length - 3} مورد دیگر']
                  : const [])
              .join('\n');
      events.add(CareReminderEvent(
        at: at,
        title: title,
        body: body,
        payload: _payloadFor(grouped),
        items: grouped,
      ));
    }
    return events;
  }

  String _singleBody(CareDueItem item) {
    final days = DateTime(item.dueDate.year, item.dueDate.month, item.dueDate.day)
        .difference(
            DateTime(item.remindDate.year, item.remindDate.month, item.remindDate.day))
        .inDays;
    if (days <= 0) return 'امروز سررسید «${item.title}» است.';
    return '$days روز تا سررسید «${item.title}» باقی مانده است.';
  }
}

/// Pure reminder planning for «صله رحم».
///
/// The planner decides *what* to say and *when*; the scheduler only hands the
/// result to the app's one notification service. Keeping it pure is what lets
/// the gentle cadence be tested without a clock or a plugin:
///
///  * one notice on the day a call becomes due;
///  * then at most one weekly nudge while it stays overdue ([maxNudges] total,
///    counting the due-day notice);
///  * everything that lands on the same day is ONE summary notification
///    («۳ تماس منتظر شماست») instead of a burst.
library;

import 'package:tawheeed/features/worship/silat_al_rahim/domain/silat_al_rahim_models.dart';

class FamilyReminderSettings {
  const FamilyReminderSettings({
    this.enabled = true,
    this.hour = 9,
    this.quietStart = 22,
    this.quietEnd = 7,
    this.weeklyNudge = true,
    this.maxNudges = 3,
  });

  final bool enabled;
  final int hour;
  final int quietStart;
  final int quietEnd;
  final bool weeklyNudge;

  /// Total notices per overdue cycle, including the due-day one.
  final int maxNudges;

  FamilyReminderSettings copyWith({
    bool? enabled,
    int? hour,
    int? quietStart,
    int? quietEnd,
    bool? weeklyNudge,
    int? maxNudges,
  }) =>
      FamilyReminderSettings(
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        quietStart: quietStart ?? this.quietStart,
        quietEnd: quietEnd ?? this.quietEnd,
        weeklyNudge: weeklyNudge ?? this.weeklyNudge,
        maxNudges: maxNudges ?? this.maxNudges,
      );

  /// True when [h] (0–23) is inside the quiet window, which may wrap midnight.
  bool isQuietHour(int h) {
    if (quietStart == quietEnd) return false;
    if (quietStart < quietEnd) return h >= quietStart && h < quietEnd;
    return h >= quietStart || h < quietEnd;
  }

  /// The hour the planner actually uses: a quiet hour is pushed to the end of
  /// the quiet window rather than silently dropped.
  int get deliveryHour =>
      isQuietHour(hour.clamp(0, 23)) ? quietEnd.clamp(0, 23) : hour.clamp(0, 23);
}

class FamilyReminderEvent {
  const FamilyReminderEvent({
    required this.at,
    required this.title,
    required this.body,
    required this.payload,
    this.isGroup = false,
  });

  final DateTime at;
  final String title;
  final String body;

  /// `family_relative_<id>` or `family_relative_day_<yyyy-MM-dd>`.
  final String payload;
  final bool isGroup;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

class RelativeReminderPlanner {
  const RelativeReminderPlanner();

  /// Plans every event between [now] and [now] + [horizonDays].
  ///
  /// [now] is usually the current time; an event on today's date whose hour has
  /// already passed is dropped — a notification in the past is never useful.
  List<FamilyReminderEvent> plan({
    required List<Relative> relatives,
    required FamilyReminderSettings settings,
    required DateTime now,
    int horizonDays = 14,
  }) {
    if (!settings.enabled) return const [];
    final today = _day(now);
    final horizon = today.add(Duration(days: horizonDays.clamp(1, 60)));

    // One bucket per day: name, kinds. The summary text is derived from it.
    final buckets = <String, _DayBucket>{};

    void add(DateTime day, _Kind kind, Relative relative, {String? extra}) {
      if (day.isBefore(today) || day.isAfter(horizon)) return;
      final key = day.toIso8601String().substring(0, 10);
      final bucket = buckets.putIfAbsent(
        key,
        () => _DayBucket(day: day, hour: settings.deliveryHour),
      );
      bucket.items.add(_Item(
        kind: kind,
        name: relative.name,
        relativeId: relative.id,
        extra: extra,
      ));
    }

    for (final relative in relatives) {
      if (!relative.isActive || relative.muted) continue;
      final period = relativeStatus(relative, now: now);
      final due = _day(period.dueDay);

      if (!due.isBefore(today)) {
        add(due, _Kind.callDue, relative);
      } else if (settings.weeklyNudge) {
        // The due-day notice is in the past; offer the weekly nudges that are
        // still ahead, never more than maxNudges in total for this cycle.
        final maxNudges = settings.maxNudges.clamp(1, 8);
        for (var index = 1; index < maxNudges; index++) {
          final nudge = due.add(Duration(days: 7 * index));
          if (!nudge.isBefore(today)) add(nudge, _Kind.nudge, relative);
          if (nudge.isAfter(horizon)) break;
        }
      }
    }

    final events = <FamilyReminderEvent>[];
    for (final bucket in buckets.values) {
      final at = bucket.day.add(Duration(hours: bucket.hour));
      if (!at.isAfter(now)) continue;
      events.add(_event(bucket, at));
    }
    events.sort((a, b) => a.at.compareTo(b.at));
    return events;
  }

  FamilyReminderEvent _event(_DayBucket bucket, DateTime at) {
    final dateKey = bucket.day.toIso8601String().substring(0, 10);
    if (bucket.items.length == 1) {
      final item = bucket.items.first;
      return FamilyReminderEvent(
        at: at,
        title: _title(item),
        body: _body(item),
        payload: 'family_relative_${item.relativeId}',
      );
    }

    final calls = bucket.items.where((i) => i.isCall).length;
    final parts = <String>[
      if (calls > 0) '$calls تماس',
    ];
    return FamilyReminderEvent(
      at: at,
      title: '${parts.join(' و ')} امروز',
      body: 'یک لحظه وقت بگذارید و حالشان را بپرسید؛ همین کافی است.',
      payload: 'family_relative_day_$dateKey',
      isGroup: true,
    );
  }

  static String _title(_Item item) => switch (item.kind) {
        _Kind.callDue => 'وقت تماس با ${item.name} است',
        _Kind.nudge => '${item.name} منتظر یک تماس است',
      };

  static String _body(_Item item) => switch (item.kind) {
        _Kind.callDue =>
          'اگر امروز حالش را بپرسید، خیالتان راحت می‌شود.',
        _Kind.nudge => 'یک پیام کوتاه هم حساب می‌شود؛ عجله‌ای نیست.',
      };
}

enum _Kind { callDue, nudge }

class _Item {
  const _Item({
    required this.kind,
    required this.name,
    required this.relativeId,
    this.extra,
  });

  final _Kind kind;
  final String name;
  final String relativeId;
  final String? extra;

  bool get isCall => kind == _Kind.callDue || kind == _Kind.nudge;
}

class _DayBucket {
  _DayBucket({required this.day, required this.hour});

  final DateTime day;
  final int hour;
  final List<_Item> items = [];
}

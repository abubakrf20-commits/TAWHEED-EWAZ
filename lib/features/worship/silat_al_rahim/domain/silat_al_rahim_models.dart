/// Data model and the pure date math of «صله رحم» (stage 3).
///
/// No Flutter, no Drift: the repository maps rows to these values and the
/// screens read them, so every rule here runs in a unit test without a
/// database.
///
/// **The app never calls anyone and never reads contacts.** A phone number is
/// the user's own note, stored locally, and the action pills only hand a
/// `tel:`/`sms:` URI to the platform.
library;

/// Relation kinds offered in the add/edit sheet. [labelFa] is what the relation
/// chip shows; `other` uses the user's own label.
enum RelationKind {
  father('father', 'پدر', 7, GiftAudience.elder),
  mother('mother', 'مادر', 7, GiftAudience.elder),
  spouse('spouse', 'همسر', 7, GiftAudience.all),
  brother('brother', 'برادر', 14, GiftAudience.all),
  sister('sister', 'خواهر', 14, GiftAudience.all),
  child('child', 'فرزند', 14, GiftAudience.child),
  grandfather('grandfather', 'پدربزرگ', 14, GiftAudience.elder),
  grandmother('grandmother', 'مادربزرگ', 14, GiftAudience.elder),
  paternalUncle('paternalUncle', 'عمو', 30, GiftAudience.all),
  paternalAunt('paternalAunt', 'عمه', 30, GiftAudience.all),
  maternalUncle('maternalUncle', 'دایی', 30, GiftAudience.all),
  maternalAunt('maternalAunt', 'خاله', 30, GiftAudience.all),
  cousin('cousin', 'پسرعمو/دخترعمو', 30, GiftAudience.all),
  other('other', 'سایر', 30, GiftAudience.all);

  const RelationKind(this.key, this.labelFa, this.defaultIntervalDays,
      this.defaultAudience);

  final String key;
  final String labelFa;

  /// The interval suggested when this relation is picked. Only a default: the
  /// user edits it freely in the sheet.
  final int defaultIntervalDays;

  /// Audience tag used to pre-filter gift ideas for this relation.
  final GiftAudience defaultAudience;

  static RelationKind fromKey(String value) => RelationKind.values.firstWhere(
        (k) => k.key == value,
        orElse: () => RelationKind.other,
      );
}

/// Who a gift idea is aimed at. Used to narrow the catalogue, never as a claim
/// about a person.
enum GiftAudience {
  child('child', 'کودک'),
  young('young', 'جوان'),
  elder('elder', 'سالمند'),
  all('all', 'همه');

  const GiftAudience(this.key, this.labelFa);

  final String key;
  final String labelFa;

  static GiftAudience fromKey(String value) => GiftAudience.values.firstWhere(
        (a) => a.key == value,
        orElse: () => GiftAudience.all,
      );
}

/// How the contact happened. Every kind refreshes `lastContactAt`, because a
/// delivered gift or a visit IS the connection the reminder is about.
enum ContactKind {
  call('call', 'تماس'),
  message('message', 'پیام'),
  visit('visit', 'دیدار'),
  gift('gift', 'هدیه');

  const ContactKind(this.key, this.labelFa);

  final String key;
  final String labelFa;

  static ContactKind fromKey(String value) => ContactKind.values.firstWhere(
        (k) => k.key == value,
        orElse: () => ContactKind.call,
      );
}

/// What the per-person statistics show: the latest contact of each kind plus
/// how many of each happened in the last [windowDays] days (and in total).
///
/// Pure and derived from [ContactLog] rows only — the card and the history
/// sheet read the same numbers, and a unit test needs no database.
class RelativeContactSummary {
  const RelativeContactSummary({
    this.lastCall,
    this.lastMessage,
    this.lastVisit,
    this.lastGift,
    this.recentByKind = const {},
    this.totalByKind = const {},
  });

  final ContactLog? lastCall;
  final ContactLog? lastMessage;
  final ContactLog? lastVisit;
  final ContactLog? lastGift;

  /// Contact counts inside the summary window, keyed by kind.
  final Map<ContactKind, int> recentByKind;

  /// Contact counts since the log began, keyed by kind.
  final Map<ContactKind, int> totalByKind;

  int recent(ContactKind kind) => recentByKind[kind] ?? 0;
  int total(ContactKind kind) => totalByKind[kind] ?? 0;

  ContactLog? lastOf(ContactKind kind) => switch (kind) {
        ContactKind.call => lastCall,
        ContactKind.message => lastMessage,
        ContactKind.visit => lastVisit,
        ContactKind.gift => lastGift,
      };

  /// The most recent contact of ANY kind — what «آخرین ارتباط» prints.
  ContactLog? get lastAny {
    ContactLog? best;
    for (final kind in ContactKind.values) {
      final row = lastOf(kind);
      if (row == null) continue;
      if (best == null || row.date.isAfter(best.date)) best = row;
    }
    return best;
  }

  /// Builds the summary from one relative's rows. Rows may arrive in any
  /// order. [recentSince] bounds the «اخیر» counters (callers pass
  /// `now − 30 days`).
  factory RelativeContactSummary.from(
    Iterable<ContactLog> contacts, {
    DateTime? recentSince,
  }) {
    final recent = <ContactKind, int>{};
    final total = <ContactKind, int>{};
    ContactLog? call;
    ContactLog? message;
    ContactLog? visit;
    ContactLog? gift;
    for (final row in contacts) {
      total[row.kind] = (total[row.kind] ?? 0) + 1;
      if (recentSince != null && !row.date.isBefore(recentSince)) {
        recent[row.kind] = (recent[row.kind] ?? 0) + 1;
      }
      switch (row.kind) {
        case ContactKind.call:
          if (call == null || row.date.isAfter(call.date)) call = row;
        case ContactKind.message:
          if (message == null || row.date.isAfter(message.date)) message = row;
        case ContactKind.visit:
          if (visit == null || row.date.isAfter(visit.date)) visit = row;
        case ContactKind.gift:
          if (gift == null || row.date.isAfter(gift.date)) gift = row;
      }
    }
    return RelativeContactSummary(
      lastCall: call,
      lastMessage: message,
      lastVisit: visit,
      lastGift: gift,
      recentByKind: recent,
      totalByKind: total,
    );
  }
}

/// Where a relative stands today. Derived, never stored: a stored status would
/// go stale the moment the clock passed midnight.
enum RelativeState {
  ok('ok', 'به‌روز'),
  dueSoon('due_soon', 'نزدیک'),
  overdue('overdue', 'عقب‌افتاده');

  const RelativeState(this.key, this.labelFa);

  final String key;
  final String labelFa;
}

class Relative {
  const Relative({
    required this.id,
    required this.name,
    required this.relation,
    required this.createdAt,
    this.relationLabel = '',
    this.phone = '',
    this.note = '',
    this.giftNote = '',
    this.audience,
    this.intervalDays = 30,
    this.lastContactAt,
    this.snoozeUntil,
    this.muted = false,
    this.archived = false,
  });

  final String id;
  final String name;
  final RelationKind relation;

  /// Only meaningful for [RelationKind.other]; otherwise the kind's own label.
  final String relationLabel;
  final String phone;
  final String note;

  /// «ذخیرهٔ ایده برای او» keeps one short note per relative.
  final String giftNote;
  final GiftAudience? audience;
  final int intervalDays;
  final DateTime? lastContactAt;
  final DateTime? snoozeUntil;
  final bool muted;
  final bool archived;
  final DateTime createdAt;

  /// What the relation chip prints.
  String get displayRelation => relation == RelationKind.other
      ? (relationLabel.trim().isEmpty ? relation.labelFa : relationLabel.trim())
      : relation.labelFa;

  GiftAudience get effectiveAudience => audience ?? relation.defaultAudience;

  bool get isActive => !archived;

  /// The day this relative was added, normalised.
  DateTime get createdDay =>
      DateTime(createdAt.year, createdAt.month, createdAt.day);

  /// Last contact, or the creation day when there has never been one.
  DateTime get anchorDay =>
      lastContactAt ?? DateTime(createdAt.year, createdAt.month, createdAt.day);

  /// `anchorDay + intervalDays` — the raw cycle due date.
  DateTime get cycleDue =>
      anchorDay.add(Duration(days: intervalDays.clamp(1, 3650)));

  /// The due date the user actually sees — a snooze pushes it forward.
  DateTime get dueDay {
    final cycle = cycleDue;
    final snooze = snoozeUntil;
    if (snooze == null) return cycle;
    return snooze.isAfter(cycle) ? snooze : cycle;
  }

  Relative copyWith({
    String? name,
    RelationKind? relation,
    String? relationLabel,
    String? phone,
    String? note,
    String? giftNote,
    Object? audience = _unset,
    int? intervalDays,
    Object? lastContactAt = _unset,
    Object? snoozeUntil = _unset,
    bool? muted,
    bool? archived,
  }) {
    return Relative(
      id: id,
      name: name ?? this.name,
      relation: relation ?? this.relation,
      relationLabel: relationLabel ?? this.relationLabel,
      phone: phone ?? this.phone,
      note: note ?? this.note,
      giftNote: giftNote ?? this.giftNote,
      audience: audience == _unset ? this.audience : audience as GiftAudience?,
      intervalDays: intervalDays ?? this.intervalDays,
      lastContactAt: lastContactAt == _unset
          ? this.lastContactAt
          : lastContactAt as DateTime?,
      snoozeUntil:
          snoozeUntil == _unset ? this.snoozeUntil : snoozeUntil as DateTime?,
      muted: muted ?? this.muted,
      archived: archived ?? this.archived,
      createdAt: createdAt,
    );
  }
}

const Object _unset = Object();

class ContactLog {
  const ContactLog({
    required this.id,
    required this.relativeId,
    required this.date,
    required this.kind,
    this.note = '',
  });

  final String id;
  final String relativeId;
  final DateTime date;
  final ContactKind kind;
  final String note;
}

/// The computed state of one relative on one day.
class RelativePeriod {
  const RelativePeriod({
    required this.state,
    required this.dueDay,
    required this.daysLate,
    required this.daysUntil,
    required this.snoozed,
  });

  final RelativeState state;
  final DateTime dueDay;

  /// How many days have passed since [dueDay]; 0 while not overdue.
  final int daysLate;

  /// Days left until [dueDay]; 0 while due or overdue.
  final int daysUntil;
  final bool snoozed;

  /// What the status chip says. Warm, never shaming.
  String get chipLabel => switch (state) {
        RelativeState.overdue => '$daysLate روز دیر',
        RelativeState.dueSoon => daysUntil == 0 ? 'همین امروز' : '$daysUntil روز مانده',
        RelativeState.ok => 'به‌روز',
      };

  bool get needsAttention => state != RelativeState.ok;
}

DateTime _todayOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Evaluates [relative] against [now]. Pure: the caller pins [now] in tests.
RelativePeriod relativeStatus(Relative relative, {required DateTime now}) {
  final today = _todayOnly(now);
  final due = relative.dueDay;
  if (due.isBefore(today)) {
    return RelativePeriod(
      state: RelativeState.overdue,
      dueDay: due,
      daysLate: today.difference(due).inDays,
      daysUntil: 0,
      snoozed: relative.snoozeUntil != null && due == relative.snoozeUntil,
    );
  }
  final until = due.difference(today).inDays;
  return RelativePeriod(
    state: until <= 2 ? RelativeState.dueSoon : RelativeState.ok,
    dueDay: due,
    daysLate: 0,
    daysUntil: until,
    snoozed: relative.snoozeUntil != null && due == relative.snoozeUntil,
  );
}

/// Whole days between [date] and [now], counted on calendar days.
///
/// Negative when [date] is in the future. Used for «۳ روز پیش» labels so the
/// card and the history sheet round the same way.
int daysBetweenDays(DateTime date, DateTime now) {
  final a = _todayOnly(date);
  final b = _todayOnly(now);
  return b.difference(a).inDays;
}

/// Warm, human wording for «how long ago»: امروز / دیروز / N روز پیش /
/// N ماه پیش, never a raw timestamp.
String daysAgoLabel(DateTime date, DateTime now) {
  final days = daysBetweenDays(date, now);
  if (days <= 0) return 'امروز';
  if (days == 1) return 'دیروز';
  if (days < 31) return '$days روز پیش';
  final months = (days / 30.4).round();
  if (months < 12) return '$months ماه پیش';
  final years = (days / 365.25).round();
  return years <= 1 ? 'یک سال پیش' : '$years سال پیش';
}

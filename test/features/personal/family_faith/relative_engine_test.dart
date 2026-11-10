import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/worship/silat_al_rahim/domain/silat_al_rahim_models.dart';

Relative _relative({
  String id = 'r1',
  DateTime? createdAt,
  DateTime? lastContactAt,
  DateTime? snoozeUntil,
  int intervalDays = 7,
  bool archived = false,
  bool muted = false,
  RelationKind relation = RelationKind.mother,
}) =>
    Relative(
      id: id,
      name: 'مادر',
      relation: relation,
      createdAt: createdAt ?? DateTime(2026, 1, 1),
      lastContactAt: lastContactAt,
      snoozeUntil: snoozeUntil,
      intervalDays: intervalDays,
      archived: archived,
      muted: muted,
    );

void main() {
  group('relative status', () {
    test('never contacted: the cycle starts at creation', () {
      final relative = _relative(
        createdAt: DateTime(2026, 3, 1),
        intervalDays: 7,
      );
      expect(relative.cycleDue, DateTime(2026, 3, 8));

      final period = relativeStatus(relative, now: DateTime(2026, 3, 1));
      expect(period.state, RelativeState.ok);
      expect(period.daysUntil, 7);
      expect(relativeStatus(relative, now: DateTime(2026, 3, 6)).state,
          RelativeState.dueSoon);
    });

    test('overdue counts the days past the due date', () {
      final relative = _relative(
        createdAt: DateTime(2026, 1, 1),
        lastContactAt: DateTime(2026, 9, 1),
        intervalDays: 7,
      );
      final period = relativeStatus(relative, now: DateTime(2026, 9, 12));
      expect(period.state, RelativeState.overdue);
      expect(period.daysLate, 4);
      expect(period.dueDay, DateTime(2026, 9, 8));
      expect(period.chipLabel, '4 روز دیر');
    });

    test('due tomorrow and due in two days are both «near»', () {
      final relative = _relative(
        lastContactAt: DateTime(2026, 9, 1),
        intervalDays: 7,
      );
      expect(relativeStatus(relative, now: DateTime(2026, 9, 7)).state,
          RelativeState.dueSoon);
      expect(relativeStatus(relative, now: DateTime(2026, 9, 6)).state,
          RelativeState.dueSoon);
      expect(relativeStatus(relative, now: DateTime(2026, 9, 5)).state,
          RelativeState.ok);
    });

    test('due today is near, not overdue', () {
      final relative = _relative(
        lastContactAt: DateTime(2026, 9, 1),
        intervalDays: 7,
      );
      final period = relativeStatus(relative, now: DateTime(2026, 9, 8));
      expect(period.state, RelativeState.dueSoon);
      expect(period.chipLabel, 'همین امروز');
      expect(period.daysLate, 0);
    });

    test('a snooze pushes the due date and clears the overdue state', () {
      final relative = _relative(
        lastContactAt: DateTime(2026, 9, 1),
        intervalDays: 7,
        snoozeUntil: DateTime(2026, 9, 20),
      );
      final period = relativeStatus(relative, now: DateTime(2026, 9, 12));
      expect(period.dueDay, DateTime(2026, 9, 20));
      expect(period.state, RelativeState.ok);
      expect(period.snoozed, isTrue);
    });

    test('a snooze shorter than the cycle never brings the due date forward',
        () {
      final relative = _relative(
        lastContactAt: DateTime(2026, 9, 1),
        intervalDays: 30,
        snoozeUntil: DateTime(2026, 9, 5),
      );
      expect(relative.dueDay, DateTime(2026, 10, 1));
    });
  });

  group('how long ago', () {
    final now = DateTime(2026, 9, 12);
    test('today, yesterday, days, months and years', () {
      expect(daysAgoLabel(DateTime(2026, 9, 12), now), 'امروز');
      expect(daysAgoLabel(DateTime(2026, 9, 11), now), 'دیروز');
      expect(daysAgoLabel(DateTime(2026, 9, 9), now), '3 روز پیش');
      expect(daysAgoLabel(DateTime(2026, 7, 14), now), '2 ماه پیش');
      expect(daysAgoLabel(DateTime(2024, 9, 12), now), '2 سال پیش');
    });

    test('a future day never reads as «ago»', () {
      expect(daysAgoLabel(DateTime(2026, 9, 20), now), 'امروز');
      expect(daysBetweenDays(DateTime(2026, 9, 12), now), 0);
      expect(daysBetweenDays(DateTime(2026, 9, 1), now), 11);
    });
  });

  group('per-person contact summary', () {
    ContactLog row(String id, ContactKind kind, DateTime date,
            {String note = ''}) =>
        ContactLog(
          id: id,
          relativeId: 'r1',
          date: date,
          kind: kind,
          note: note,
        );

    test('keeps the newest row of each kind and counts the totals', () {
      final summary = RelativeContactSummary.from([
        row('a', ContactKind.call, DateTime(2026, 8, 1)),
        row('b', ContactKind.call, DateTime(2026, 9, 1)),
        row('c', ContactKind.visit, DateTime(2026, 7, 1)),
        row('d', ContactKind.gift, DateTime(2026, 9, 5), note: 'عسل'),
      ]);
      expect(summary.lastCall?.id, 'b');
      expect(summary.lastVisit?.id, 'c');
      expect(summary.lastGift?.note, 'عسل');
      expect(summary.total(ContactKind.call), 2);
      expect(summary.total(ContactKind.visit), 1);
      expect(summary.lastAny?.id, 'd');
    });

    test('the recent window only counts rows inside it', () {
      final summary = RelativeContactSummary.from(
        [
          row('old', ContactKind.visit, DateTime(2026, 6, 1)),
          row('new', ContactKind.visit, DateTime(2026, 9, 1)),
        ],
        recentSince: DateTime(2026, 8, 13),
      );
      expect(summary.recent(ContactKind.visit), 1);
      expect(summary.total(ContactKind.visit), 2);
      // The newest row is the newest regardless of the window.
      expect(summary.lastVisit?.id, 'new');
    });

    test('an empty log is nulls and zeros, never a crash', () {
      final summary = RelativeContactSummary.from(const []);
      expect(summary.lastAny, isNull);
      expect(summary.lastGift, isNull);
      expect(summary.recent(ContactKind.message), 0);
      expect(summary.total(ContactKind.gift), 0);
    });
  });

  group('relation defaults', () {
    test('parents default to a week, siblings and grandparents to two', () {
      expect(RelationKind.father.defaultIntervalDays, 7);
      expect(RelationKind.mother.defaultIntervalDays, 7);
      expect(RelationKind.brother.defaultIntervalDays, 14);
      expect(RelationKind.grandmother.defaultIntervalDays, 14);
      expect(RelationKind.paternalUncle.defaultIntervalDays, 30);
    });

    test('a custom label is only used for «other»', () {
      final other = _relative(relation: RelationKind.other).copyWith(
        relationLabel: 'پسرخاله',
      );
      expect(other.displayRelation, 'پسرخاله');
      expect(
        _relative(relation: RelationKind.sister)
            .copyWith(relationLabel: 'هرچه')
            .displayRelation,
        'خواهر',
      );
    });

    test('the gift audience follows the relation until it is overridden', () {
      expect(_relative(relation: RelationKind.child).effectiveAudience,
          GiftAudience.child);
      expect(_relative(relation: RelationKind.grandfather).effectiveAudience,
          GiftAudience.elder);
      expect(
        _relative(relation: RelationKind.child)
            .copyWith(audience: GiftAudience.young)
            .effectiveAudience,
        GiftAudience.young,
      );
    });
  });
}

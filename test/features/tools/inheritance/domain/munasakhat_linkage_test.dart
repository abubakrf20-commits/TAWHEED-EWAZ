import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/tools/inheritance/domain/inheritance_calculator.dart';

/// مناسخات linkage decided by a RELATIONSHIP (`inheritedFromHeir`), which is
/// what the stage picker in the UI sends: no share is ever matched by guessing
/// at a typed label, and a link that cannot be resolved stops the calculation
/// instead of splitting the estate equally behind the user's back.
void main() {
  /// 300,000 between one son and one daughter: 2/3 to the son, 1/3 to the
  /// daughter — the numbers every assertion below is built on.
  const firstStage = InheritanceInput(
    estate: 300000,
    son: 1,
    daughter: 1,
  );

  group('calculateMunasakhat — inheritedFromHeir', () {
    test('the picked heir’s exact share becomes the next stage’s estate', () {
      final c = calculateMunasakhat(
        'مناسخات',
        [
          ('متوفی اول', firstStage),
          ('متوفی دوم', const InheritanceInput(husband: 1, mother: 1)),
        ],
        inheritedFromHeir: [null, HeirType.daughter],
      );

      final daughter = c.stages.first.result.shares
          .firstWhere((s) => s.type == HeirType.daughter)
          .amount;
      expect(daughter, closeTo(100000, 0.001));
      expect(c.stages[1].result.estate, closeTo(daughter, 0.001));
      expect(c.warnings, isEmpty);
    });

    test('the pick wins over the label — a misleading name cannot mislink', () {
      // The label names the son; the picker says the daughter.
      final c = calculateMunasakhat(
        'مناسخات',
        [
          ('متوفی اول', firstStage),
          ('متوفی دوم (پسر)', const InheritanceInput(husband: 1, mother: 1)),
        ],
        inheritedFromHeir: [null, HeirType.daughter],
        strictLinkage: true,
      );

      expect(c.stages[1].result.estate, closeTo(100000, 0.001));
      expect(c.stages[1].result.estate, isNot(closeTo(200000, 0.001)));
    });

    test('a three-stage chain carries each link from the stage before it', () {
      final c = calculateMunasakhat(
        'مناسخات',
        [
          (
            'متوفی اول',
            const InheritanceInput(estate: 480000, son: 2, daughter: 1)
          ),
          ('متوفی دوم', const InheritanceInput(wife: 1, son: 1)),
          ('متوفی سوم', const InheritanceInput(wife: 1, mother: 1)),
        ],
        inheritedFromHeir: [null, HeirType.son, HeirType.son],
        strictLinkage: true,
      );

      // 480,000 in 5 parts (2:1 twice + once): each son 192,000.
      expect(c.stages[1].result.estate, closeTo(192000, 0.001));
      // of the second stage: wife 1/8, the son the residue.
      final sonOfStage2 = c.stages[1].result.shares
          .firstWhere((s) => s.type == HeirType.son)
          .amount;
      expect(sonOfStage2, closeTo(168000, 0.001));
      expect(c.stages[2].result.estate, closeTo(sonOfStage2, 0.001));
      expect(c.warnings, isEmpty);
    });

    test('one of two sons carries his own part, not the brothers’ total', () {
      final c = calculateMunasakhat(
        'مناسخات',
        [
          (
            'متوفی اول',
            const InheritanceInput(estate: 480000, son: 2, daughter: 1)
          ),
          ('متوفی دوم', const InheritanceInput(wife: 1, mother: 1)),
        ],
        inheritedFromHeir: [null, HeirType.son],
        strictLinkage: true,
      );

      final sons = c.stages.first.result.shares
          .firstWhere((s) => s.type == HeirType.son);
      expect(sons.count, 2);
      expect(sons.amount, closeTo(384000, 0.001));
      expect(c.stages[1].result.estate, closeTo(192000, 0.001));
    });

    test('strict: an heir who takes nothing has no estate to pass on', () {
      // The father excludes the brother entirely.
      expect(
        () => calculateMunasakhat(
          'مناسخات',
          [
            (
              'متوفی اول',
              const InheritanceInput(estate: 100000, father: 1, fullBrother: 1)
            ),
            ('متوفی دوم', const InheritanceInput(mother: 1)),
          ],
          inheritedFromHeir: [null, HeirType.fullBrother],
          strictLinkage: true,
        ),
        throwsA(isA<MunasakhatLinkageException>()
            .having((e) => e.stageIndex, 'stageIndex', 1)),
      );
    });

    test('non-strict: an unclear link is announced in Persian, never silently',
        () {
      final c = calculateMunasakhat(
        'مناسخات',
        [
          ('متوفی اول', firstStage),
          ('فرد بدون نام', const InheritanceInput(mother: 1)),
        ],
      );

      expect(c.warnings, hasLength(1));
      expect(c.warnings.single, contains('تخمین'));
      expect(c.warnings.single, contains('عمل نکنید'));
      expect(c.warnings.single, isNot(contains('Stage')));
      // equal-split estimate of the allocated estate over the two heirs
      expect(c.stages[1].result.estate, closeTo(150000, 0.001));
    });

    test('the engine still resolves a relation written in the label', () {
      // No picker: the fallback path the older callers rely on.
      final c = calculateMunasakhat(
        'مناسخات',
        [
          ('متوفی اول', firstStage),
          ('متوفی دوم (دختر)', const InheritanceInput(husband: 1, mother: 1)),
        ],
        strictLinkage: true,
      );

      expect(c.stages[1].result.estate, closeTo(100000, 0.001));
    });
  });

  group('InheritanceInput.fromCounts', () {
    test('every heir of the catalog round-trips, and only that heir', () {
      for (final t in HeirType.values) {
        final input = InheritanceInput.fromCounts({t: 2});
        expect(input.countOf(t), 2, reason: heirLabel(t));
        for (final other in HeirType.values) {
          if (other == t) continue;
          expect(input.countOf(other), 0,
              reason: '${heirLabel(t)} wrote into ${heirLabel(other)}');
        }
      }
    });

    test('estate and madhab come through with the counts', () {
      final input = InheritanceInput.fromCounts(
        {HeirType.son: 3, HeirType.wife: 1, HeirType.mother: 1},
        estate: 500000,
        madhab: Madhab.hanafi,
      );
      expect(input.countOf(HeirType.son), 3);
      expect(input.countOf(HeirType.wife), 1);
      expect(input.countOf(HeirType.mother), 1);
      expect(input.estate, 500000);
      expect(input.madhab, Madhab.hanafi);
    });
  });

  group('heirIsMale / heirMaxCount', () {
    test('the spouse pair splits by gender', () {
      expect(heirIsMale(HeirType.husband), isTrue);
      expect(heirIsMale(HeirType.wife), isFalse);
      expect(heirIsMale(HeirType.son), isTrue);
      expect(heirIsMale(HeirType.daughter), isFalse);
    });

    test('a single-position heir cannot be counted twice', () {
      expect(heirMaxCount(HeirType.husband), 1);
      expect(heirMaxCount(HeirType.wife), 4);
      expect(heirMaxCount(HeirType.father), 1);
      expect(heirMaxCount(HeirType.mother), 1);
      expect(heirMaxCount(HeirType.grandfather), 1);
      expect(heirMaxCount(HeirType.son), greaterThan(1));
      for (final t in HeirType.values) {
        expect(heirMaxCount(t), greaterThanOrEqualTo(1), reason: heirLabel(t));
      }
    });
  });
}

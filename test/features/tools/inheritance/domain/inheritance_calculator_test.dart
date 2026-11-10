import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/tools/inheritance/domain/inheritance_calculator.dart';
import 'package:tawheeed/features/tools/inheritance/domain/madhab_calculator.dart';

InheritanceShare? shareOf(InheritanceResult r, HeirType t) =>
    r.shares.where((s) => s.type == t).firstOrNull;

void main() {
  group('calculateInheritance (Shafii default)', () {
    test('ʿawl: wife + parents + 2 daughters', () {
      final r = calculateInheritance(const InheritanceInput(
        estate: 27000,
        wife: 1,
        father: 1,
        mother: 1,
        daughter: 2,
      ));
      expect(r.method, 'awl');
      expect(shareOf(r, HeirType.wife)!.amount, closeTo(3000, 0.001));
      expect(shareOf(r, HeirType.father)!.amount, closeTo(4000, 0.001));
      expect(shareOf(r, HeirType.mother)!.amount, closeTo(4000, 0.001));
      expect(shareOf(r, HeirType.daughter)!.amount, closeTo(16000, 0.001));
      expect(r.totalAllocated, closeTo(27000, 0.001));
    });

    test('son + daughter → 2:1 asaba', () {
      final r = calculateInheritance(const InheritanceInput(
        estate: 3000,
        son: 1,
        daughter: 1,
      ));
      expect(r.method, 'normal');
      expect(shareOf(r, HeirType.son)!.isAsaba, true);
      expect(shareOf(r, HeirType.son)!.amount, closeTo(2000, 0.001));
      expect(shareOf(r, HeirType.daughter)!.amount, closeTo(1000, 0.001));
    });

    test('husband + daughter + mother → radd', () {
      final r = calculateInheritance(const InheritanceInput(
        estate: 48000,
        husband: 1,
        daughter: 1,
        mother: 1,
      ));
      expect(r.method, 'radd');
      expect(shareOf(r, HeirType.husband)!.amount, closeTo(12000, 0.001));
      expect(shareOf(r, HeirType.daughter)!.amount, closeTo(27000, 0.001));
      expect(shareOf(r, HeirType.mother)!.amount, closeTo(9000, 0.001));
      expect(r.totalAllocated, closeTo(48000, 0.001));
    });

    test('father + mother + daughter → father is asaba', () {
      final r = calculateInheritance(const InheritanceInput(
        estate: 48000,
        father: 1,
        mother: 1,
        daughter: 1,
      ));
      expect(r.method, 'normal');
      expect(shareOf(r, HeirType.father)!.isAsaba, true);
      expect(shareOf(r, HeirType.father)!.amount, closeTo(16000, 0.001));
      expect(shareOf(r, HeirType.mother)!.amount, closeTo(8000, 0.001));
      expect(shareOf(r, HeirType.daughter)!.amount, closeTo(24000, 0.001));
    });

    test('only daughter → radd gives everything', () {
      final r = calculateInheritance(const InheritanceInput(
        estate: 100,
        daughter: 1,
      ));
      expect(r.method, 'radd');
      expect(shareOf(r, HeirType.daughter)!.amount, closeTo(100, 0.001));
    });

    test('only husband → 1/2, remainder to bayt al-mal', () {
      final r = calculateInheritance(const InheritanceInput(
        estate: 100,
        husband: 1,
      ));
      expect(shareOf(r, HeirType.husband)!.fraction.toDouble(),
          closeTo(0.5, 0.001));
      expect(r.totalAllocated, closeTo(50, 0.001));
      expect(r.notes.join('\n'), contains('بیت‌المال'));
    });

    test('multiple wives share the single portion', () {
      final r = calculateInheritance(const InheritanceInput(
        estate: 8000,
        wife: 2,
      ));
      final w = shareOf(r, HeirType.wife)!;
      expect(w.fraction.toDouble(), closeTo(0.25, 0.001));
      expect(w.count, 2);
      expect(w.amount, closeTo(2000, 0.001));
    });

    test('son blocks brothers (hajb)', () {
      final r = calculateInheritance(const InheritanceInput(
        estate: 1000,
        son: 1,
        fullBrother: 1,
        father: 1,
        mother: 1,
      ));
      expect(shareOf(r, HeirType.fullBrother), isNull);
      expect(r.notes.join('\n'), contains('محجوب'));
      expect(r.totalAllocated, closeTo(1000, 0.001));
    });

    test('two daughters (no other heir) → 2/3 fard, radd gives all', () {
      final r = calculateInheritance(const InheritanceInput(
        estate: 3000,
        daughter: 2,
      ));
      expect(shareOf(r, HeirType.daughter)!.fraction.toDouble(),
          closeTo(1, 0.001));
    });

    test('maternal siblings (kalala) capped at 1/3, rest to bayt al-mal', () {
      final r = calculateInheritance(const InheritanceInput(
        estate: 3000,
        maternalBrother: 1,
        maternalSister: 1,
      ));
      expect(shareOf(r, HeirType.maternalBrother)!.amount, closeTo(500, 0.001));
      expect(shareOf(r, HeirType.maternalSister)!.amount, closeTo(500, 0.001));
      expect(r.totalAllocated, closeTo(1000, 0.001));
      expect(r.notes.join('\n'), contains('بیت‌المال'));
    });
  });

  group('Mother share with single sibling (madhab diff)', () {
    test('Hanafi: one sibling reduces mother to 1/6', () {
      final r = getCalculator(Madhab.hanafi).calculate(const InheritanceInput(
        estate: 1200,
        mother: 1,
        fullBrother: 1,
      ));
      expect(shareOf(r, HeirType.mother)!.fraction.toDouble(),
          closeTo(1 / 6, 0.001));
      expect(shareOf(r, HeirType.fullBrother)!.isAsaba, true);
    });

    test('Shafii: one sibling does NOT reduce mother (stays 1/3)', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 1200,
        mother: 1,
        fullBrother: 1,
      ));
      expect(shareOf(r, HeirType.mother)!.fraction.toDouble(),
          closeTo(1 / 3, 0.001));
    });

    test('Shafii: two siblings reduce mother to 1/6', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 1200,
        mother: 1,
        fullBrother: 2,
      ));
      expect(shareOf(r, HeirType.mother)!.fraction.toDouble(),
          closeTo(1 / 6, 0.001));
    });

    test('Maliki: one sibling does NOT reduce mother', () {
      final r = getCalculator(Madhab.maliki).calculate(const InheritanceInput(
        estate: 1200,
        mother: 1,
        fullSister: 1,
      ));
      expect(shareOf(r, HeirType.mother)!.fraction.toDouble(),
          closeTo(2 / 5, 0.001));
    });

    test('Hanbali: one sibling does NOT reduce mother', () {
      final r = getCalculator(Madhab.hanbali).calculate(const InheritanceInput(
        estate: 1200,
        mother: 1,
        fullSister: 1,
      ));
      expect(shareOf(r, HeirType.mother)!.fraction.toDouble(),
          closeTo(2 / 5, 0.001));
    });
  });

  group('Grandfather muqasamah', () {
    test('Hanafi: grandfather takes all (blocks siblings)', () {
      final r = getCalculator(Madhab.hanafi).calculate(const InheritanceInput(
        estate: 6000,
        grandfather: 1,
        fullBrother: 1,
      ));
      expect(shareOf(r, HeirType.grandfather)!.amount, closeTo(6000, 0.001));
      expect(shareOf(r, HeirType.fullBrother), isNull);
    });

    test('Shafii: grandfather muqasamah with siblings', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 6000,
        grandfather: 1,
        fullBrother: 1,
      ));
      // Grandfather treated as brother (2 shares), brother (2 shares) = 4 parts
      // Grandfather: 2/4 * 6000 = 3000, Brother: 2/4 * 6000 = 3000
      expect(shareOf(r, HeirType.grandfather)!.amount, closeTo(3000, 0.001));
      expect(shareOf(r, HeirType.fullBrother)!.amount, closeTo(3000, 0.001));
    });

    test('Shafii: grandfather + brother + sister muqasamah (2:2:1)', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 5000,
        grandfather: 1,
        fullBrother: 1,
        fullSister: 1,
      ));
      // gf=2, bro=2, sis=1 = 5 heads → gf 2/5 > 1/3، فيأخذ 2/5
      // gf: 2/5*5000=2000, bro: 2/5*5000=2000, sis: 1/5*5000=1000
      expect(shareOf(r, HeirType.grandfather)!.amount, closeTo(2000, 0.001));
      expect(shareOf(r, HeirType.fullBrother)!.amount, closeTo(2000, 0.001));
      expect(shareOf(r, HeirType.fullSister)!.amount, closeTo(1000, 0.001));
    });

    test('Shafii: grandfather takes at least 1/3 with many brothers', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 6000,
        grandfather: 1,
        fullBrother: 10, // Many brothers would push grandfather below 1/3
      ));
      // gf=2, bro=10*2=20 = 22 heads → gf 2/22 = 1/11 < 1/3
      // So gf gets 1/3 = 2000, remaining 4000 split among brothers (each 400)
      expect(shareOf(r, HeirType.grandfather)!.amount, closeTo(2000, 0.001));
      expect(r.totalAllocated, closeTo(6000, 0.001));
    });
  });

  group('Radd (return) differences', () {
    test('Shafii: maternal siblings exempt from radd', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 6000,
        maternalBrother: 1,
        maternalSister: 1,
      ));
      // 1/6 each = 1/3 total, radd exempt → 2/3 to bayt al-mal
      expect(r.method, 'baytMal');
      expect(r.totalAllocated, closeTo(2000, 0.001));
      expect(r.notes.join('\n'), contains('بیت‌المال'));
    });

    test('Hanbali: maternal siblings receive radd', () {
      final r = getCalculator(Madhab.hanbali).calculate(const InheritanceInput(
        estate: 6000,
        maternalBrother: 1,
        maternalSister: 1,
      ));
      // Each gets 1/6 = 1000, leftover 4000 returned to them proportionally
      // Total: 6000 fully allocated
      expect(r.method, 'radd');
      expect(r.totalAllocated, closeTo(6000, 0.001));
      expect(
          shareOf(r, HeirType.maternalBrother)!.amount, closeTo(3000, 0.001));
      expect(shareOf(r, HeirType.maternalSister)!.amount, closeTo(3000, 0.001));
    });
  });

  group('Full sister + paternal sister', () {
    test('One full sister (1/2) + one paternal sister (1/6) = 2/3', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 6000,
        fullSister: 1,
        paternalSister: 1,
      ));
      expect(shareOf(r, HeirType.fullSister)!.fraction.toDouble(),
          closeTo(3 / 4, 0.001));
      expect(shareOf(r, HeirType.paternalSister)!.fraction.toDouble(),
          closeTo(1 / 4, 0.001));
    });

    test('Hanafi: full sister blocks paternal sister', () {
      final r = getCalculator(Madhab.hanafi).calculate(const InheritanceInput(
        estate: 6000,
        fullSister: 1,
        paternalSister: 1,
      ));
      expect(shareOf(r, HeirType.fullSister)!.fraction.toDouble(),
          closeTo(1, 0.001));
      expect(shareOf(r, HeirType.paternalSister), isNull);
    });
  });

  group('Granddaughter scenarios', () {
    test('One granddaughter + one daughter = 1/2 + 1/6', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 6000,
        daughter: 1,
        granddaughter: 1,
      ));
      expect(shareOf(r, HeirType.daughter)!.fraction.toDouble(),
          closeTo(3 / 4, 0.001));
      expect(shareOf(r, HeirType.granddaughter)!.fraction.toDouble(),
          closeTo(1 / 4, 0.001));
    });

    test('Two granddaughters + no daughter = 2/3', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 6000,
        granddaughter: 2,
      ));
      expect(shareOf(r, HeirType.granddaughter)!.fraction.toDouble(),
          closeTo(1, 0.001));
    });
  });

  group('Madhab calculators match calculateInheritance for basic cases', () {
    test('Simple spouse case matches across all madhabs', () {
      for (final madhab in Madhab.values) {
        final input = InheritanceInput(
          estate: 8000,
          wife: 1,
          madhab: madhab,
        );
        final r1 = calculateInheritance(input);
        final r2 = getCalculator(madhab).calculate(input);
        expect(r2.shares.length, r1.shares.length,
            reason: 'Mismatch for $madhab');
        for (final s in r1.shares) {
          final s2 = shareOf(r2, s.type);
          expect(s2, isNotNull, reason: 'Missing ${s.type} in $madhab');
          expect(s2!.amount, closeTo(s.amount, 0.001),
              reason: 'Amount mismatch for ${s.type} in $madhab');
        }
      }
    });
  });

  group('Gharewain (mother + father + spouse)', () {
    test('husband + mother + father → mother 1/3 of remainder', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 6000,
        husband: 1,
        mother: 1,
        father: 1,
      ));
      // husband 1/2 (3000); mother 1/3 of the REMAINDER (1/3 × 3000 = 1000);
      // father inherits the rest (2000).
      expect(shareOf(r, HeirType.husband)!.amount, closeTo(3000, 0.001));
      expect(shareOf(r, HeirType.mother)!.amount, closeTo(1000, 0.001));
      expect(shareOf(r, HeirType.father)!.amount, closeTo(2000, 0.001));
    });

    test('wife + mother + father → mother 1/3 of remainder', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 6000,
        wife: 1,
        mother: 1,
        father: 1,
      ));
      // wife 1/4 (1500); mother 1/3 of remainder (1/3 × 4500 = 1500); father 3000.
      expect(shareOf(r, HeirType.wife)!.amount, closeTo(1500, 0.001));
      expect(shareOf(r, HeirType.mother)!.amount, closeTo(1500, 0.001));
      expect(shareOf(r, HeirType.father)!.amount, closeTo(3000, 0.001));
    });

    test('mother with one brother in Hanafi is 1/6, in others 1/3', () {
      final hanafi =
          getCalculator(Madhab.hanafi).calculate(const InheritanceInput(
        estate: 6000,
        mother: 1,
        fullBrother: 1,
      ));
      expect(shareOf(hanafi, HeirType.mother)!.amount, closeTo(1000, 0.001));

      final shafii =
          getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 6000,
        mother: 1,
        fullBrother: 1,
      ));
      // Hanbali/Shafii: one brother does NOT hajb the mother → she gets 1/3
      expect(shareOf(shafii, HeirType.mother)!.fraction.toDouble(),
          closeTo(1 / 3, 0.001));
    });

    // Gharrāʾ بدون أب (إجماع): زوج/زوجة + أم + إخوة اثنين فأكثر، بلا فرع
    // وارث — الأم ثلث الباقي بعد فرض الزوجين (وليست سدس الأصل).
    test('wife + mother + 2 full brothers → mother 1/3 of the 3/4 remainder',
        () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 4000,
        wife: 1,
        mother: 1,
        fullBrother: 2,
      ));
      // wife ¼ (1000); mother ⅓ × ¾ = ¼ (1000); two brothers ½ as ʿaṣaba (2000).
      expect(shareOf(r, HeirType.wife)!.amount, closeTo(1000, 0.001));
      expect(shareOf(r, HeirType.mother)!.fraction.toDouble(),
          closeTo(1 / 4, 1e-9));
      expect(shareOf(r, HeirType.mother)!.amount, closeTo(1000, 0.001));
      expect(shareOf(r, HeirType.fullBrother)!.amount, closeTo(2000, 0.001));
      expect(r.totalAllocated, closeTo(4000, 0.001));
    });

    test('husband + mother + 2 paternal brothers → mother 1/6 (= ⅓ of ½)', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 6000,
        husband: 1,
        mother: 1,
        paternalBrother: 2,
      ));
      // husband ½ (3000); mother ⅓ × ½ = ⅙ (1000); brothers remainder (2000).
      expect(shareOf(r, HeirType.husband)!.amount, closeTo(3000, 0.001));
      expect(shareOf(r, HeirType.mother)!.fraction.toDouble(),
          closeTo(1 / 6, 1e-9));
      expect(shareOf(r, HeirType.mother)!.amount, closeTo(1000, 0.001));
      expect(
          shareOf(r, HeirType.paternalBrother)!.amount, closeTo(2000, 0.001));
      expect(r.totalAllocated, closeTo(6000, 0.001));
    });

    test('wife + mother + 2 full sisters → ʿawl, mother ⅓ of remainder', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 1400,
        wife: 1,
        mother: 1,
        fullSister: 2,
      ));
      // ¼ + ¼ + ⅔ = 7/6: asl 12 ʿawl to 14 → 3/14, 3/14, 8/14.
      expect(r.method, 'awl');
      expect(shareOf(r, HeirType.wife)!.amount, closeTo(300, 0.001));
      expect(shareOf(r, HeirType.mother)!.amount, closeTo(300, 0.001));
      expect(shareOf(r, HeirType.fullSister)!.amount, closeTo(800, 0.001));
      expect(r.totalAllocated, closeTo(1400, 0.001));
    });

    test('Maliki without father: no muqasamah, no phantom father share', () {
      final r = getCalculator(Madhab.maliki).calculate(const InheritanceInput(
        estate: 4000,
        wife: 1,
        mother: 1,
        fullBrother: 2,
      ));
      // Muqāsamah is the FATHER sharing heads with siblings; with no father
      // the siblings take the remainder directly and mother stays ⅓ of it.
      expect(shareOf(r, HeirType.father), isNull);
      expect(shareOf(r, HeirType.mother)!.amount, closeTo(1000, 0.001));
      expect(shareOf(r, HeirType.fullBrother)!.amount, closeTo(2000, 0.001));
      expect(r.totalAllocated, closeTo(4000, 0.001));
    });
  });

  group('Spouse reason text follows any farʿ wārith (incl. grandson)', () {
    test('wife + grandson → 1/8 and reason says یک‌هشتم', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 8000,
        wife: 1,
        grandson: 1,
      ));
      final wife = shareOf(r, HeirType.wife)!;
      expect(wife.fraction.toDouble(), closeTo(1 / 8, 1e-9));
      expect(wife.reason, contains('یک‌هشتم'));
    });

    test('husband + grandson → 1/4 and reason says یک‌چهارم', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 4000,
        husband: 1,
        grandson: 1,
      ));
      final husband = shareOf(r, HeirType.husband)!;
      expect(husband.fraction.toDouble(), closeTo(1 / 4, 1e-9));
      expect(husband.reason, contains('یک‌چهارم'));
      expect(husband.reason, contains('فرع وارث'));
    });
  });

  group('Classic farāʾiḍ cases (hand-computed from Quranic fractions)', () {
    test('wife + 2 daughters + son → ⅛ then 2:1 taʿṣīb of the rest', () {
      // 4:12 wife ⅛ with a descendant; 4:11 residuum split 2:1 male:female
      // over 4 heads (son = 2, each daughter = 1) of the remaining 7/8.
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 32000,
        wife: 1,
        daughter: 2,
        son: 1,
      ));
      expect(shareOf(r, HeirType.wife)!.amount, closeTo(4000, 0.001));
      expect(shareOf(r, HeirType.son)!.amount, closeTo(14000, 0.001));
      expect(shareOf(r, HeirType.daughter)!.amount, closeTo(14000, 0.001));
      expect(r.totalAllocated, closeTo(32000, 0.001));
    });

    test('mother + 3 sons → ⅙ fard + remainder by heads', () {
      // 4:11: mother ⅙ in presence of a descendant; the 5/6 remainder is
      // ʿaṣaba divided equally among the 3 sons.
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 18000,
        mother: 1,
        son: 3,
      ));
      expect(shareOf(r, HeirType.mother)!.amount, closeTo(3000, 0.001));
      expect(
          shareOf(r, HeirType.son)!.fraction.toDouble(), closeTo(5 / 6, 1e-9));
      expect(shareOf(r, HeirType.son)!.amount, closeTo(15000, 0.001));
      expect(r.totalAllocated, closeTo(18000, 0.001));
    });
  });

  group('Grandmother share (always 1/6)', () {
    test('only grandmother → fard 1/6, radd returns the rest', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 6000,
        paternalGrandmother: 1,
      ));
      // fard = 1/6; after radd (only non-exempt heir) she receives everything
      expect(r.method, 'radd');
      expect(shareOf(r, HeirType.paternalGrandmother)!.fraction.toDouble(),
          closeTo(1, 0.001));
      expect(shareOf(r, HeirType.paternalGrandmother)!.amount,
          closeTo(6000, 0.001));
    });

    test('grandmother with child → final share 1/4 (fard 1/6 + radd)', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 6000,
        paternalGrandmother: 1,
        daughter: 1,
      ));
      // daughter fard 1/2, grandmother fard 1/6; radd distributes leftover
      // proportionally (1/6 : 3/6) → grandmother gets 1/4 of the estate.
      expect(r.method, 'radd');
      expect(shareOf(r, HeirType.paternalGrandmother)!.fraction.toDouble(),
          closeTo(0.25, 0.001));
      expect(shareOf(r, HeirType.paternalGrandmother)!.amount,
          closeTo(1500, 0.001));
      expect(shareOf(r, HeirType.daughter)!.amount, closeTo(4500, 0.001));
    });

    test('grandmother + husband → fard stays exactly 1/6', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 6000,
        paternalGrandmother: 1,
        husband: 1,
      ));
      // husband 1/2 (3000), grandmother fard 1/6 (1000), radd goes to grandmother (2000)
      expect(shareOf(r, HeirType.paternalGrandmother)!.amount,
          closeTo(3000, 0.001));
      expect(shareOf(r, HeirType.husband)!.amount, closeTo(3000, 0.001));
    });

    test('grandmother fard is 1/6 across all madhabs (with daughter present)',
        () {
      for (final madhab in Madhab.values) {
        final r = getCalculator(madhab).calculate(InheritanceInput(
          estate: 6000,
          paternalGrandmother: 1,
          daughter: 1,
          madhab: madhab,
        ));
        // final share = fard 1/6 + radd → 1/4 for every madhab
        expect(shareOf(r, HeirType.paternalGrandmother)!.fraction.toDouble(),
            closeTo(0.25, 0.001),
            reason:
                'Grandmother final share should be 1/4 (fard 1/6 + radd) in $madhab');
      }
    });
  });

  group('Grandfather + sister without brother (non-Hanafi)', () {
    test('Shafii: grandfather + one full sister → muqasamah 2:1', () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 6000,
        grandfather: 1,
        fullSister: 1,
      ));
      // gf=2, sis=1 = 3 heads → gf 2/3 > 1/3، فيأخذ 2/3، أخت 1/3
      expect(shareOf(r, HeirType.fullSister)!.fraction.toDouble(),
          closeTo(1 / 3, 0.001));
      expect(shareOf(r, HeirType.grandfather)!.fraction.toDouble(),
          closeTo(2 / 3, 0.001));
      expect(r.totalAllocated, closeTo(6000, 0.001));
    });

    test('Shafii: grandfather + two full sisters → muqasamah 1/2 each side',
        () {
      final r = getCalculator(Madhab.shafii).calculate(const InheritanceInput(
        estate: 6000,
        grandfather: 1,
        fullSister: 2,
      ));
      // gf=2, sis=2 = 4 heads → gf 2/4 = 1/2 > 1/3، فيأخذ 1/2، الأختان 1/2
      expect(shareOf(r, HeirType.fullSister)!.fraction.toDouble(),
          closeTo(1 / 2, 0.001));
      expect(shareOf(r, HeirType.grandfather)!.fraction.toDouble(),
          closeTo(1 / 2, 0.001));
    });

    test('Hanbali: grandfather + sister → muqasamah 2:1', () {
      final r = getCalculator(Madhab.hanbali).calculate(const InheritanceInput(
        estate: 6000,
        grandfather: 1,
        fullSister: 1,
      ));
      // gf=2, sis=1 → gf 2/3، أخت 1/3 (المقاسمة أفضل من الثلث)
      expect(shareOf(r, HeirType.fullSister)!.fraction.toDouble(),
          closeTo(1 / 3, 0.001));
      expect(shareOf(r, HeirType.grandfather)!.fraction.toDouble(),
          closeTo(2 / 3, 0.001));
      expect(r.totalAllocated, closeTo(6000, 0.001));
    });

    test('Hanafi: grandfather blocks sister entirely', () {
      final r = getCalculator(Madhab.hanafi).calculate(const InheritanceInput(
        estate: 6000,
        grandfather: 1,
        fullSister: 1,
      ));
      expect(shareOf(r, HeirType.fullSister), isNull);
      expect(shareOf(r, HeirType.grandfather)!.amount, closeTo(6000, 0.001));
    });
  });

  group('CalculateMunasakhat', () {
    test('two-stage munasakhat', () {
      final result = calculateMunasakhat('test', [
        (
          'متوفی اول (پدر)',
          const InheritanceInput(
            estate: 100000,
            son: 2,
          )
        ),
        (
          'متوفی دوم (پسر)',
          const InheritanceInput(
            daughter: 1,
          )
        ),
      ]);
      expect(result.stages.length, 2);
      expect(result.stages[0].result.shares.length, 1); // 2 sons split
      expect(result.stages[1].result.shares.length, 1); // 1 daughter
    });
  });
}

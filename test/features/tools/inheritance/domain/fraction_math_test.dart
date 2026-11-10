import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/tools/inheritance/domain/fraction_math.dart';

/// Tests the «ماشین حساب کسرها» math with real numbers: simplification,
/// addition, division, gcd/lcm — the operations the tab exposes.
void main() {
  group('gcdOf', () {
    test('gcd of 12 and 18 is 6', () {
      expect(gcdOf(12, 18), 6);
    });
    test('gcd of 48 and 36 is 12', () {
      expect(gcdOf(48, 36), 12);
    });
    test('gcd of 7 and 13 (coprime) is 1', () {
      expect(gcdOf(7, 13), 1);
    });
    test('gcd works with negative inputs', () {
      expect(gcdOf(-12, 18), 6);
      expect(gcdOf(12, -18), 6);
    });
    test('gcd of n and 0 is n', () {
      expect(gcdOf(0, 5), 5);
      expect(gcdOf(5, 0), 5);
    });
  });

  group('lcmOf', () {
    test('lcm of 4 and 6 is 12', () {
      expect(lcmOf(4, 6), 12);
    });
    test('lcm of 6 and 8 is 24', () {
      expect(lcmOf(6, 8), 24);
    });
    test('lcm of coprime 7 and 13 is their product', () {
      expect(lcmOf(7, 13), 91);
    });
  });

  group('simplifyFraction', () {
    test('8/12 simplifies to 2/3 with gcd 4', () {
      final r = simplifyFraction(8, 12);
      expect(r.gcd, 4);
      expect(r.simplifiedN, 2);
      expect(r.simplifiedD, 3);
      expect(r.mixed, '2/3');
      expect(r.decimal, '0.6667');
    });

    test('24/36 simplifies to 2/3 with gcd 12', () {
      final r = simplifyFraction(24, 36);
      expect(r.gcd, 12);
      expect(r.simplifiedN, 2);
      expect(r.simplifiedD, 3);
    });

    test('10/4 simplifies to 5/2 → mixed 2 و 1/2, decimal 2.5', () {
      final r = simplifyFraction(10, 4);
      expect(r.gcd, 2);
      expect(r.simplifiedN, 5);
      expect(r.simplifiedD, 2);
      expect(r.mixed, '2 و 1/2');
      expect(r.decimal, '2.5');
    });

    test('denominator 1 collapses to a whole number', () {
      final r = simplifyFraction(7, 1);
      expect(r.simplifiedN, 7);
      expect(r.simplifiedD, 1);
      expect(r.mixed, '7');
      expect(r.decimal, '7');
    });

    test('negative fraction keeps its sign', () {
      final r = simplifyFraction(-4, 8);
      expect(r.gcd, 4);
      expect(r.simplifiedN, -1);
      expect(r.simplifiedD, 2);
      expect(r.mixed, '-1/2');
    });
  });

  group('applyFractionOp — addition', () {
    test('1/2 + 1/3 = 5/6', () {
      final r = applyFractionOp(1, 2, 1, 3, FractionOp.add);
      expect(r.raw, '5/6');
      expect(r.gcd, 1);
      expect(r.simplified, '5/6');
      expect(r.mixed, '5/6');
      expect(r.decimal, '0.8333');
    });

    test('1/4 + 1/4 = 1/2', () {
      final r = applyFractionOp(1, 4, 1, 4, FractionOp.add);
      expect(r.raw, '8/16');
      expect(r.gcd, 8);
      expect(r.simplified, '1/2');
      expect(r.decimal, '0.5');
    });

    test('1/2 + 1/2 = 1 (whole)', () {
      final r = applyFractionOp(1, 2, 1, 2, FractionOp.add);
      expect(r.simplified, '1');
      expect(r.mixed, '1');
    });
  });

  group('applyFractionOp — division', () {
    test('1/2 ÷ 3/4 = 2/3', () {
      final r = applyFractionOp(1, 2, 3, 4, FractionOp.div);
      expect(r.raw, '4/6');
      expect(r.gcd, 2);
      expect(r.simplified, '2/3');
      expect(r.mixed, '2/3');
      expect(r.decimal, '0.6667');
    });

    test('3/4 ÷ 1/2 = 3/2 → mixed 1 و 1/2', () {
      final r = applyFractionOp(3, 4, 1, 2, FractionOp.div);
      expect(r.raw, '6/4');
      expect(r.gcd, 2);
      expect(r.simplified, '3/2');
      expect(r.mixed, '1 و 1/2');
      expect(r.decimal, '1.5');
    });

    test('5/6 ÷ 5/12 = 2', () {
      final r = applyFractionOp(5, 6, 5, 12, FractionOp.div);
      expect(r.simplified, '2');
      expect(r.mixed, '2');
    });
  });

  group('applyFractionOp — multiplication & subtraction', () {
    test('2/3 × 3/4 = 1/2', () {
      final r = applyFractionOp(2, 3, 3, 4, FractionOp.mul);
      expect(r.raw, '6/12');
      expect(r.gcd, 6);
      expect(r.simplified, '1/2');
    });

    test('3/4 − 1/2 = 1/4', () {
      final r = applyFractionOp(3, 4, 1, 2, FractionOp.sub);
      expect(r.raw, '2/8');
      expect(r.gcd, 2);
      expect(r.simplified, '1/4');
      expect(r.decimal, '0.25');
    });

    test('1/3 − 2/3 = −1/3 keeps the sign', () {
      final r = applyFractionOp(1, 3, 2, 3, FractionOp.sub);
      expect(r.simplified, '-1/3');
      expect(r.sign, -1);
    });
  });

  group('parseFractionToken', () {
    test('parses fractions, negatives and whole numbers', () {
      expect(parseFractionToken('1/3'), (1, 3));
      expect(parseFractionToken('-2/3'), (-2, 3));
      expect(parseFractionToken('7'), (7, 1));
      expect(parseFractionToken(' 7/8 '), (7, 8));
      expect(parseFractionToken('+1/2'), (1, 2));
    });

    test('rejects zero denominator and garbage', () {
      expect(parseFractionToken('1/0'), isNull);
      expect(parseFractionToken('abc'), isNull);
      expect(parseFractionToken('1/2/3'), isNull);
      expect(parseFractionToken(''), isNull);
      expect(parseFractionToken('   '), isNull);
    });
  });

  group('parseFractionInput', () {
    test('splits on whitespace into fractions', () {
      expect(parseFractionInput('1/2  3/4 5'), [(1, 2), (3, 4), (5, 1)]);
    });
    test('returns null on empty or invalid input', () {
      expect(parseFractionInput('   '), isNull);
      expect(parseFractionInput('1/2 3/0'), isNull);
      expect(parseFractionInput('1/2 x'), isNull);
    });
  });

  group('parseIntegerInput & lcmOfAll', () {
    test('parses space separated integers', () {
      expect(parseIntegerInput('4 6 8'), [4, 6, 8]);
      expect(parseIntegerInput('  12  18  '), [12, 18]);
      expect(parseIntegerInput('a 5'), isNull);
      expect(parseIntegerInput(' '), isNull);
    });
    test('lcm of 4, 6, 8 is 24', () {
      expect(lcmOfAll([4, 6, 8]), 24);
    });
    test('lcm of a single number is itself; empty is 0', () {
      expect(lcmOfAll([7]), 7);
      expect(lcmOfAll([]), 0);
    });
  });

  group('applyFractions — جمع (N کسر)', () {
    test('1/2 + 1/3 + 1/4 = 13/12 (common den 12)', () {
      final r = applyFractions([(1, 2), (1, 3), (1, 4)], FractionOp.add)!;
      expect(r.commonDen, 12);
      expect(r.scaledNs, [6, 4, 3]);
      expect(r.rawN, 13);
      expect(r.rawD, 12);
      expect(r.simplified, '13/12');
      expect(r.mixed, '1 و 1/12');
    });

    test('1/2 + 1/4 + 1/4 = 1 (whole)', () {
      final r = applyFractions([(1, 2), (1, 4), (1, 4)], FractionOp.add)!;
      expect(r.simplified, '1');
      expect(r.decimal, '1');
    });

    test('2/3 + 1/6 = 5/6', () {
      final r = applyFractions([(2, 3), (1, 6)], FractionOp.add)!;
      expect(r.simplified, '5/6');
    });
  });

  group('applyFractions — تفریق', () {
    test('3/4 − 1/2 = 1/4', () {
      final r = applyFractions([(3, 4), (1, 2)], FractionOp.sub)!;
      expect(r.commonDen, 4);
      expect(r.scaledNs, [3, 2]);
      expect(r.simplified, '1/4');
    });

    test('1 − 1/2 − 1/4 = 1/4 with a whole number term', () {
      final r = applyFractions([(1, 1), (1, 2), (1, 4)], FractionOp.sub)!;
      expect(r.simplified, '1/4');
    });
  });

  group('applyFractions — ضرب و تقسیم', () {
    test('2/3 × 3/4 × 1/2 = 1/4', () {
      final r = applyFractions([(2, 3), (3, 4), (1, 2)], FractionOp.mul)!;
      expect(r.simplified, '1/4');
    });

    test('3/4 ÷ 1/2 = 3/2 → mixed 1 و 1/2', () {
      final r = applyFractions([(3, 4), (1, 2)], FractionOp.div)!;
      expect(r.rawN, 6);
      expect(r.rawD, 4);
      expect(r.simplified, '3/2');
      expect(r.mixed, '1 و 1/2');
    });

    test('division by a zero numerator is undefined', () {
      expect(applyFractions([(1, 2), (0, 3)], FractionOp.div), isNull);
    });

    test('empty input returns null', () {
      expect(applyFractions([], FractionOp.add), isNull);
    });

    test('negative result keeps its sign across N terms', () {
      final r = applyFractions([(1, 2), (3, 4)], FractionOp.sub)!;
      expect(r.sign, -1);
      expect(r.simplified, '-1/4');
    });
  });

  group('fractionDecimal', () {
    test('1/3 → 0.3333', () {
      expect(fractionDecimal(1, 3), '0.3333');
    });
    test('1/2 → 0.5 and whole numbers collapse', () {
      expect(fractionDecimal(1, 2), '0.5');
      expect(fractionDecimal(4, 2), '2');
    });
  });

  group('calculateShares — سهام مسائل الفرائض', () {
    test('1/2 1/6 1/3: اصل 6، سهام [3،1،2]، مجموع = اصل (عادی)', () {
      final r = calculateShares([(1, 2), (1, 6), (1, 3)]);
      expect(r.asl, 6);
      expect(r.shares, [3, 1, 2]);
      expect(r.totalShares, 6);
      expect(r.mode, 'normal');
      expect(r.correctedAsl, 6);
    });

    test('1/4 1/2: اصل 4، سهام [1،2]، مجموع 3 < 4 ← ردّ', () {
      final r = calculateShares([(1, 4), (1, 2)]);
      expect(r.asl, 4);
      expect(r.shares, [1, 2]);
      expect(r.totalShares, 3);
      expect(r.mode, 'radd');
      expect(r.correctedAsl, 4);
    });

    test('1/2 2/3: مجموع 7 > اصل 6 ← عول، اصل تصحیح‌شده 7', () {
      final r = calculateShares([(1, 2), (2, 3)]);
      expect(r.asl, 6);
      expect(r.shares, [3, 4]);
      expect(r.totalShares, 7);
      expect(r.mode, 'awl');
      expect(r.correctedAsl, 7);
    });

    test('1/2 1/6: مجموع 4 < اصل 6 ← ردّ، باقی‌مانده 2', () {
      final r = calculateShares([(1, 2), (1, 6)]);
      expect(r.asl, 6);
      expect(r.shares, [3, 1]);
      expect(r.totalShares, 4);
      expect(r.mode, 'radd');
      expect(r.correctedAsl, 6);
    });

    test('1/4 1/3 1/6: اصل 12، سهام [3،4،2]، مجموع 9 ← ردّ', () {
      final r = calculateShares([(1, 4), (1, 3), (1, 6)]);
      expect(r.asl, 12);
      expect(r.shares, [3, 4, 2]);
      expect(r.totalShares, 9);
      expect(r.mode, 'radd');
      expect(r.correctedAsl, 12);
    });

    test('کسرهای ناساده هنوز سهام درست می‌دهد: 2/6 == 1/3', () {
      final r = calculateShares([(1, 2), (2, 6), (1, 3)]);
      expect(r.asl, 6);
      expect(r.shares, [3, 2, 2]);
      expect(r.totalShares, 7);
      expect(r.mode, 'awl');
    });
  });
}

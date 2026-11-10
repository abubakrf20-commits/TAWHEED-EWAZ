import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/tools/inheritance/domain/inheritance_calculator.dart';
import 'package:tawheeed/features/tools/inheritance/domain/madhab_calculator.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/inheritance_amount_input.dart';

void main() {
  group('parseNonNegativeAmount', () {
    test('an empty optional field is zero', () {
      for (final text in ['', '   ', '\t']) {
        final r = parseNonNegativeAmount(text, label: 'بدهی');
        expect(r.ok, isTrue);
        expect(r.value, 0);
      }
    });

    test('reads Persian, Arabic and Latin digits with separators', () {
      expect(parseNonNegativeAmount('۱۲۳۴', label: 'x').value, 1234);
      expect(parseNonNegativeAmount('١٢٣٤', label: 'x').value, 1234);
      expect(parseNonNegativeAmount('1,234', label: 'x').value, 1234);
      expect(parseNonNegativeAmount('۱٬۲۳۴', label: 'x').value, 1234);
      expect(parseNonNegativeAmount('1.5', label: 'x').value, 1.5);
      expect(parseNonNegativeAmount('۰', label: 'x').value, 0);
    });

    test('rejects a negative amount with a message naming the field', () {
      final r = parseNonNegativeAmount('-500', label: 'بدهی');
      expect(r.ok, isFalse);
      expect(r.error, contains('بدهی'));
      expect(r.error, contains('منفی'));
    });

    test('rejects unreadable text instead of silently reading it as zero', () {
      for (final text in ['abc', '۱۲abc', '12 34', '1/2', '--5', '1e', '+']) {
        final r = parseNonNegativeAmount(text, label: 'وصیت');
        expect(r.ok, isFalse, reason: 'accepted "$text"');
        expect(r.value, 0);
      }
    });

    test('rejects infinite input', () {
      // `double.tryParse('1e400')` is Infinity, which used to flow straight
      // into the share arithmetic.
      for (final text in ['1e400', '-1e400', '1e999']) {
        final r = parseNonNegativeAmount(text, label: 'ترکه');
        expect(r.ok, isFalse, reason: 'accepted "$text"');
        expect(r.value, 0);
      }
    });

    test('allowZero: false rejects an empty or zero amount', () {
      for (final text in ['', '0', '۰', '0.0']) {
        final r = parseNonNegativeAmount(text, label: 'ترکه', allowZero: false);
        expect(r.ok, isFalse, reason: 'accepted "$text"');
      }
      expect(
          parseNonNegativeAmount('1', label: 'x', allowZero: false).ok, isTrue);
    });
  });

  group('parseEstate', () {
    test('requires a real amount', () {
      expect(parseEstate('').ok, isFalse);
      expect(parseEstate('0').ok, isFalse);
      expect(parseEstate('-1').ok, isFalse);
      expect(parseEstate('abc').ok, isFalse);
      expect(parseEstate('1e400').ok, isFalse);
    });

    test('accepts a normal amount', () {
      final r = parseEstate('۴۲۰,۰۰۰');
      expect(r.ok, isTrue);
      expect(r.value, 420000);
    });
  });

  group('parseDeductions', () {
    DeductionsParseResult parse({
      String funeral = '',
      String debt = '',
      String w1 = '',
      String w2 = '',
      String w3 = '',
      double estate = 1000,
    }) =>
        parseDeductions(
          funeralText: funeral,
          debtText: debt,
          willText: w1,
          will2Text: w2,
          will3Text: w3,
          estate: estate,
        );

    test('empty fields are zero', () {
      final r = parse();
      expect(r.ok, isTrue);
      expect(r.funeral, 0);
      expect(r.debts, 0);
      expect(r.totalWill, 0);
    });

    test('reports the first invalid field', () {
      expect(parse(funeral: 'abc').error, contains('کفن'));
      expect(parse(debt: '-1').error, contains('بدهی'));
      expect(parse(w1: 'abc').error, contains('وصیت'));
      expect(parse(w2: '-1').error, contains('وصیت دوم'));
      expect(parse(w3: '1e400').error, contains('وصیت سوم'));
    });

    test('funeral plus debt may not exceed the estate', () {
      final r = parse(funeral: '600', debt: '600');
      expect(r.ok, isFalse);
      expect(r.error, contains('ترکه'));
    });

    test('funeral plus debt may equal the estate', () {
      final r = parse(funeral: '600', debt: '400');
      expect(r.ok, isTrue);
    });

    test('a single will may not exceed the estate', () {
      final r = parse(w1: '2000');
      expect(r.ok, isFalse);
      expect(r.error, contains('وصیت'));
    });

    test('a will equal to the estate is allowed (the calculator caps it)', () {
      final r = parse(w1: '1000');
      expect(r.ok, isTrue);
      expect(r.will1, 1000);
    });
  });

  group('calculator rejects unusable amounts', () {
    InheritanceInput input({
      double estate = 1000,
      double funeral = 0,
      double debts = 0,
      double will = 0,
      double will2 = 0,
      double will3 = 0,
    }) =>
        InheritanceInput(
          estate: estate,
          funeralExpenses: funeral,
          debts: debts,
          willAmount: will,
          willAmount2: will2,
          willAmount3: will3,
          son: 1,
          wife: 1,
          father: 1,
          mother: 1,
        );

    for (final madhab in Madhab.values) {
      test('${madhab.name} rejects a negative estate', () {
        expect(() => getCalculator(madhab).calculate(input(estate: -1)),
            throwsArgumentError);
      });
      test('${madhab.name} rejects a negative debt', () {
        expect(() => getCalculator(madhab).calculate(input(debts: -5)),
            throwsArgumentError);
      });
      test('${madhab.name} rejects a negative will', () {
        expect(() => getCalculator(madhab).calculate(input(will: -5)),
            throwsArgumentError);
      });
      test('${madhab.name} rejects a non-finite estate', () {
        expect(
            () =>
                getCalculator(madhab).calculate(input(estate: double.infinity)),
            throwsArgumentError);
        expect(() => getCalculator(madhab).calculate(input(estate: double.nan)),
            throwsArgumentError);
      });
      test('${madhab.name} still computes valid input', () {
        final result = getCalculator(madhab).calculate(input());
        expect(result.shares, isNotEmpty);
        for (final s in result.shares) {
          expect(s.amount.isFinite, isTrue);
          expect(s.amount, greaterThanOrEqualTo(0));
        }
      });
    }
  });

  group('heir labels', () {
    test('every heir type has a non-empty Persian label', () {
      for (final t in HeirType.values) {
        final label = heirLabel(t);
        expect(label.trim(), isNotEmpty, reason: t.name);
        // U+FFFD would mean a mangled source file.
        expect(label.contains('\uFFFD'), isFalse, reason: t.name);
      }
    });

    test('every share type has a non-empty Persian label', () {
      for (final t in ShareType.values) {
        final label = shareTypeLabel(t);
        expect(label.trim(), isNotEmpty, reason: t.name);
        expect(label.contains('\uFFFD'), isFalse, reason: t.name);
      }
    });

    test('labels are unique per heir type', () {
      final labels = HeirType.values.map(heirLabel).toList();
      expect(labels.toSet().length, labels.length);
    });
  });
}

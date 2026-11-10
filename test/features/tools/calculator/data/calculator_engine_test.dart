import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/tools/calculator/data/calculator_engine.dart';

void main() {
  group('CalculatorEngine.evaluate', () {
    test('basic arithmetic', () {
      expect(CalculatorEngine.evaluate('2+3'), 5);
      expect(CalculatorEngine.evaluate('10-4'), 6);
      expect(CalculatorEngine.evaluate('6*7'), 42);
      expect(CalculatorEngine.evaluate('8/2'), 4);
      expect(CalculatorEngine.evaluate('(2+3)*4'), 20);
      expect(CalculatorEngine.evaluate('2+3*4'), 14);
    });

    test('power', () {
      expect(CalculatorEngine.evaluate('2^3'), 8);
      expect(CalculatorEngine.evaluate('2**3'), 8);
      expect(CalculatorEngine.evaluate('2^3^2'), 512);
    });

    test('percentage', () {
      expect(CalculatorEngine.evaluate('50%'), closeTo(0.5, 1e-9));
      expect(CalculatorEngine.evaluate('200*10%'), closeTo(20, 1e-9));
      expect(CalculatorEngine.evaluate('100+10%'), closeTo(110, 1e-9));
      expect(CalculatorEngine.evaluate('100-10%'), closeTo(90, 1e-9));
    });

    test('functions', () {
      expect(CalculatorEngine.evaluate('sin(30)'), closeTo(0.5, 1e-9));
      expect(CalculatorEngine.evaluate('cos(60)'), closeTo(0.5, 1e-9));
      expect(CalculatorEngine.evaluate('sqrt(9)'), 3);
      expect(CalculatorEngine.evaluate('log(100)'), closeTo(2, 1e-9));
      expect(CalculatorEngine.evaluate('abs(-5)'), 5);
    });

    test('division by zero returns null', () {
      expect(CalculatorEngine.evaluate('1/0'), isNull);
      expect(CalculatorEngine.evaluate('5/0'), isNull);
    });

    test('invalid returns null', () {
      expect(CalculatorEngine.evaluate('abc'), isNull);
      expect(CalculatorEngine.evaluate('2+'), isNull);
    });

    test('unary minus and plus', () {
      expect(CalculatorEngine.evaluate('-5+3'), -2);
      expect(CalculatorEngine.evaluate('+5'), 5);
    });

    test('persian operators', () {
      expect(CalculatorEngine.evaluate('2×3'), 6);
      expect(CalculatorEngine.evaluate('6÷2'), 3);
    });

    test('constants pi and e', () {
      expect(CalculatorEngine.evaluate('π'), closeTo(3.141592653589793, 1e-12));
      expect(
          CalculatorEngine.evaluate('2*π'), closeTo(6.283185307179586, 1e-12));
      expect(CalculatorEngine.evaluate('e'), closeTo(2.718281828459045, 1e-12));
      expect(
          CalculatorEngine.evaluate('π/2'), closeTo(1.5707963267948966, 1e-12));
    });

    test('factorial', () {
      expect(CalculatorEngine.evaluate('5!'), 120);
      expect(CalculatorEngine.evaluate('0!'), 1);
      expect(CalculatorEngine.evaluate('(2+3)!'), 120);
      expect(CalculatorEngine.evaluate('3!+4'), 10);
      expect(CalculatorEngine.evaluate('1.5!'), isNull);
      expect(CalculatorEngine.evaluate('(-2)!'), isNull);
      expect(CalculatorEngine.evaluate('200!'), isNull);
    });
  });

  group('CalculatorEngine.formatResult', () {
    test('int', () => expect(CalculatorEngine.formatResult(42.0), '42'));
    test('trailing zeros',
        () => expect(CalculatorEngine.formatResult(1.500000), '1.5'));
    test('large',
        () => expect(CalculatorEngine.formatResult(1e16), contains('e')));
  });
}

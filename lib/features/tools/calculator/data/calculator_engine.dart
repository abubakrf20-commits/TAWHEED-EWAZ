import 'dart:math' as math;
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

class CalculatorEngine {
  CalculatorEngine._();

  /// Evaluate a mathematical expression string
  static double? evaluate(String expression) {
    try {
      // Fold Persian (۰-۹) / Arabic-Indic (٠-٩) digits to Latin first, so an
      // expression typed on a Persian keyboard parses like one typed on the
      // built-in keypad (which only ever emits Latin digits).
      var cleaned = NumberFormat.normalizeDigits(expression)
          .replaceAll('×', '*')
          .replaceAll('÷', '/')
          .replaceAll('−', '-')
          .replaceAll(' ', '')
          .replaceAll(',', '.')
          .replaceAll('π', '(3.141592653589793)');
      // Euler's «e» is a standalone token; an «e» glued to a number (1e+21,
      // 2e5) is a scientific-notation exponent, not the constant — replacing
      // those corrupted a result that had been chained back into the input.
      cleaned = cleaned.replaceAll(
          RegExp(r'(?<![\d.])e(?![\d])'), '(2.718281828459045)');

      // Handle percentage
      cleaned = _handlePercentage(cleaned);

      // Handle power operator
      cleaned = cleaned.replaceAll('^', '**');

      // Parse and evaluate using a simple approach
      final result = _eval(cleaned);
      // A NaN/Infinity (asin(2), ln(-1), sqrt(-4), 0/0 …) must not reach the
      // display as «NaN» — surface a proper error instead.
      if (result.isNaN || result.isInfinite) {
        throw Exception('نتیجه یک عدد معتبر نیست');
      }
      return result;
    } catch (e) {
      AppLogger.warning(
          'CalculatorEngine', 'evaluate failed for "$expression": $e');
      return null;
    }
  }

  static String _handlePercentage(String expr) {
    // «A ± B%» is relative to A (100-10% = 90, 100+10% = 110), while «A*B%» and
    // «A/B%» simply use B/100 (100*10% = 10). The relative form is only applied
    // when the left side is a single operand (or a parenthesised group): in a
    // chained expression like «10+5+20%» the true running-total semantics would
    // need an evaluator state, so the plain «/100» form is kept there instead of
    // producing a subtly wrong number.
    final buffer = StringBuffer();
    for (var i = 0; i < expr.length; i++) {
      if (expr[i] != '%') {
        buffer.write(expr[i]);
        continue;
      }
      final out = buffer.toString();
      // The value the % applies to: a trailing parenthesised group, or the
      // trailing number.
      String value;
      int valueStart;
      if (out.endsWith(')')) {
        var depth = 0;
        var k = out.length - 1;
        for (; k >= 0; k--) {
          if (out[k] == ')') depth++;
          if (out[k] == '(') {
            depth--;
            if (depth == 0) break;
          }
        }
        valueStart = k < 0 ? out.length : k;
        value = out.substring(valueStart);
      } else {
        var k = out.length;
        while (k > 0 && '0123456789.'.contains(out[k - 1])) {
          k--;
        }
        valueStart = k;
        value = out.substring(k);
      }
      if (value.isEmpty) continue; // bare % → drop it

      final opIdx = valueStart - 1;
      final op = opIdx >= 0 ? out[opIdx] : '';
      final left = opIdx >= 0 ? out.substring(0, opIdx) : '';
      if ((op == '+' || op == '-') &&
          left.isNotEmpty &&
          !_hasTopLevelOperator(left)) {
        // A ± B%  →  A ± A*B/100 — replace the whole «A op B%» tail with
        // «A op A*B/100» (truncate back to before the operand, then rebuild).
        buffer
          ..clear()
          ..write(left)
          ..write(op)
          ..write(left)
          ..write('*')
          ..write(value)
          ..write('/100');
      } else {
        buffer.write('/100');
      }
    }
    return buffer.toString();
  }

  /// True when [s] contains a top-level (depth-0) arithmetic operator, i.e. it
  /// is more than a single operand. A leading sign is not an operator.
  static bool _hasTopLevelOperator(String s) {
    var depth = 0;
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (c == '(') depth++;
      if (c == ')') depth--;
      if (depth == 0 && (c == '+' || c == '-' || c == '*' || c == '/')) {
        if (i == 0) continue;
        return true;
      }
    }
    return false;
  }

  static double _eval(String expr) {
    // Postfix factorial: evaluate the base first so things like (2+3)! work.
    if (expr.endsWith('!')) {
      return _factorial(_eval(expr.substring(0, expr.length - 1)));
    }

    // Remove outer parentheses if they match
    expr = _removeOuterParentheses(expr);

    // Find the last operator outside parentheses (+ or -)
    var depth = 0;
    for (var i = expr.length - 1; i >= 0; i--) {
      if (expr[i] == ')') depth++;
      if (expr[i] == '(') depth--;
      if (depth == 0 && (expr[i] == '+' || expr[i] == '-')) {
        // Make sure it's not a unary minus at the start or after another operator
        if (i > 0 && !_isOperator(expr[i - 1])) {
          final left = _eval(expr.substring(0, i));
          final right = _eval(expr.substring(i + 1));
          return expr[i] == '+' ? left + right : left - right;
        }
      }
    }

    // Find the last operator outside parentheses (* or /)
    depth = 0;
    for (var i = expr.length - 1; i >= 0; i--) {
      if (expr[i] == ')') depth++;
      if (expr[i] == '(') depth--;
      if (depth == 0 && (expr[i] == '*' || expr[i] == '/')) {
        // Skip '*' characters that belong to the '**' power operator.
        if (expr[i] == '*' &&
            ((i > 0 && expr[i - 1] == '*') ||
                (i + 1 < expr.length && expr[i + 1] == '*'))) {
          continue;
        }
        final left = _eval(expr.substring(0, i));
        final right = _eval(expr.substring(i + 1));
        if (expr[i] == '/') {
          if (right == 0) throw Exception('Division by zero');
          return left / right;
        }
        return left * right;
      }
    }

    // Find ** (power) operator. Power binds tighter than * and /, and is
    // right-associative, so split at the leftmost '**' at depth 0.
    depth = 0;
    for (var i = 0; i < expr.length - 1; i++) {
      if (expr[i] == '(') depth++;
      if (expr[i] == ')') depth--;
      if (depth == 0 && expr[i] == '*' && expr[i + 1] == '*') {
        final left = _eval(expr.substring(0, i));
        final right = _eval(expr.substring(i + 2));
        return math.pow(left, right).toDouble();
      }
    }

    // Handle functions
    final funcMatch = RegExp(r'^(sin|cos|tan|log|ln|sqrt|abs|asin|acos|atan)\(')
        .matchAsPrefix(expr);
    if (funcMatch != null) {
      final funcName = funcMatch.group(1)!;
      final argStr = expr.substring(funcMatch.end, expr.length - 1);
      final arg = _eval(argStr);
      return _applyFunction(funcName, arg);
    }

    // Handle unary minus
    if (expr.startsWith('-')) {
      return -_eval(expr.substring(1));
    }

    // Handle unary plus
    if (expr.startsWith('+')) {
      return _eval(expr.substring(1));
    }

    // Parse number
    final num = double.tryParse(expr);
    if (num != null) return num;

    throw Exception('Cannot parse: $expr');
  }

  static String _removeOuterParentheses(String expr) {
    if (expr.isEmpty || expr[0] != '(') return expr;

    var depth = 0;
    for (var i = 0; i < expr.length; i++) {
      if (expr[i] == '(') depth++;
      if (expr[i] == ')') depth--;
      if (depth == 0) {
        // If we return to 0 before the end, the outer parentheses don't match
        if (i != expr.length - 1) return expr;
      }
    }

    // All parentheses match, remove outer ones
    return expr.substring(1, expr.length - 1);
  }

  static bool _isOperator(String char) {
    return char == '+' || char == '-' || char == '*' || char == '/';
  }

  static double _factorial(double n) {
    if (n != n.roundToDouble() || n < 0 || n > 170) {
      throw Exception('Factorial of $n is undefined');
    }
    var result = 1.0;
    for (var i = 2; i <= n.toInt(); i++) {
      result *= i;
    }
    return result;
  }

  static double _applyFunction(String name, double arg) {
    switch (name) {
      case 'sin':
        return math.sin(arg * math.pi / 180);
      case 'cos':
        return math.cos(arg * math.pi / 180);
      case 'tan':
        return math.tan(arg * math.pi / 180);
      case 'asin':
        if (arg < -1 || arg > 1) {
          throw Exception('asin فقط برای اعداد بین -1 و 1 تعریف شده است');
        }
        return math.asin(arg) * 180 / math.pi;
      case 'acos':
        if (arg < -1 || arg > 1) {
          throw Exception('acos فقط برای اعداد بین -1 و 1 تعریف شده است');
        }
        return math.acos(arg) * 180 / math.pi;
      case 'atan':
        return math.atan(arg) * 180 / math.pi;
      case 'log':
        if (arg <= 0) {
          throw Exception('log فقط برای اعداد مثبت تعریف شده است');
        }
        return math.log(arg) / math.ln10;
      case 'ln':
        if (arg <= 0) {
          throw Exception('ln فقط برای اعداد مثبت تعریف شده است');
        }
        return math.log(arg);
      case 'sqrt':
        if (arg < 0) {
          throw Exception('جذر اعداد منفی تعریف نشده است');
        }
        return math.sqrt(arg);
      case 'abs':
        return arg.abs();
      default:
        throw Exception('Unknown function: $name');
    }
  }

  /// Format result for display
  static String formatResult(double value) {
    if (value == value.toInt().toDouble() && value.abs() < 1e15) {
      return value.toInt().toString();
    }

    // Handle very large or very small numbers
    if (value.abs() >= 1e15 || (value.abs() < 1e-10 && value != 0)) {
      return value.toStringAsExponential(6);
    }

    // Round to avoid floating point issues
    final rounded = double.parse(value.toStringAsFixed(10));
    final str = rounded.toString();

    // Remove trailing zeros
    if (str.contains('.') && !str.contains('e')) {
      return str.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }

    return str;
  }
}

/// Pure fraction-math helpers used by the «حاسبة الكسور» tab in the میراث
/// section. Kept free of Flutter dependencies so they can be unit-tested.
library;

/// The four binary operations supported by the fraction calculator.
enum FractionOp {
  add('جمع'),
  sub('تفریق'),
  mul('ضرب'),
  div('تقسیم');

  const FractionOp(this.label);
  final String label;
}

/// Result of simplifying a single fraction.
class FractionSimplifyResult {
  final int gcd;
  final int simplifiedN;
  final int simplifiedD;
  final String mixed;
  final String decimal;
  const FractionSimplifyResult({
    required this.gcd,
    required this.simplifiedN,
    required this.simplifiedD,
    required this.mixed,
    required this.decimal,
  });
}

/// Result of applying an operation to two fractions.
class FractionOpResult {
  final String raw;
  final int gcd;
  final String simplified;
  final String mixed;
  final String decimal;
  final int sign;
  const FractionOpResult({
    required this.raw,
    required this.gcd,
    required this.simplified,
    required this.mixed,
    required this.decimal,
    required this.sign,
  });
}

/// Result of computing gcd/lcm of two whole numbers.
class GcdLcmResult {
  final int gcd;
  final int lcm;
  const GcdLcmResult({required this.gcd, required this.lcm});
}

/// Result of an N-ary fraction operation (جمع/تفریق/ضرب/تقسیم of 2+ کسرها).
class NFractionOpResult {
  final FractionOp op;
  final List<(int, int)> inputs;

  /// Denominator shared by all terms when the operation used a common
  /// denominator (add/sub); equals 1 for mul/div.
  final int commonDen;

  /// Numerators scaled to [commonDen] for add/sub; empty for mul/div.
  final List<int> scaledNs;
  final int rawN;
  final int rawD;
  final int gcd;
  final int sign;
  final String simplified;
  final String mixed;
  final String decimal;

  const NFractionOpResult({
    required this.op,
    required this.inputs,
    required this.commonDen,
    required this.scaledNs,
    required this.rawN,
    required this.rawD,
    required this.gcd,
    required this.sign,
    required this.simplified,
    required this.mixed,
    required this.decimal,
  });
}

int gcdOf(int a, int b) {
  a = a.abs();
  b = b.abs();
  while (b != 0) {
    final t = a % b;
    a = b;
    b = t;
  }
  return a;
}

int lcmOf(int a, int b) => (a.abs() * b.abs()) ~/ gcdOf(a, b);

String _fracString(int n, int d) {
  if (d == 1) return '$n';
  return '$n/$d';
}

String _mixedString(int n, int d) {
  final sign = n < 0 ? '-' : '';
  final an = n.abs();
  final whole = an ~/ d;
  final rem = an % d;
  if (whole == 0) return _fracString(n, d);
  if (rem == 0) return '$sign$whole';
  return '$sign$whole و $rem/$d';
}

String _decimal(double v) => v
    .toStringAsFixed(4)
    .replaceFirst(RegExp(r'0+$'), '')
    .replaceFirst(RegExp(r'\.$'), '');

/// Simplifies n/d, returning the gcd used, the reduced fraction, the mixed
/// number form and the decimal form.
FractionSimplifyResult simplifyFraction(int n, int d) {
  final sign = (n < 0) != (d < 0) ? -1 : 1;
  n = n.abs();
  d = d.abs();
  final g = gcdOf(n, d);
  final sn = sign * (n ~/ g);
  final sd = d ~/ g;
  return FractionSimplifyResult(
    gcd: g,
    simplifiedN: sn,
    simplifiedD: sd,
    mixed: sd == 1 ? '$sn' : _mixedString(sn, sd),
    decimal: _decimal(sn / sd),
  );
}

/// Returns an [NFractionOpResult] matching the site’s «ماشین حساب کسرها»:
/// N کسر can be added/subtracted/multiplied/divided in one go.
FractionOpResult applyFractionOp(
    int n1, int d1, int n2, int d2, FractionOp op) {
  final (rn, rd) = switch (op) {
    FractionOp.add => (n1 * d2 + n2 * d1, d1 * d2),
    FractionOp.sub => (n1 * d2 - n2 * d1, d1 * d2),
    FractionOp.mul => (n1 * n2, d1 * d2),
    FractionOp.div => (n1 * d2, d1 * n2),
  };
  final g = gcdOf(rn, rd);
  final sn = rn ~/ g;
  final sd = rd ~/ g;
  final sign = (sn < 0) != (sd < 0) ? -1 : 1;
  final an = sn.abs();
  final ad = sd.abs();
  final mixed = ad == 1 ? '${sign * an}' : _mixedString(sign * an, ad);
  return FractionOpResult(
    raw: _fracString(rn, rd),
    gcd: g,
    simplified: sd == 1 ? '$sn' : '$sn/$sd',
    mixed: mixed,
    decimal: _decimal(sn / sd),
    sign: sign,
  );
}

/// Parses a single fraction token: «1/3», «-2/3», «7» (→ 7/1). Returns null
/// for anything malformed, including a zero denominator.
(int, int)? parseFractionToken(String token) {
  final t = token.trim();
  if (t.isEmpty) return null;
  final m = RegExp(r'^([+-]?\d+)/(\d+)$').firstMatch(t);
  if (m != null) {
    final numer = int.tryParse(m[1] ?? '');
    final denom = int.tryParse(m[2] ?? '');
    if (numer == null || denom == null || denom == 0) return null;
    return (numer, denom);
  }
  final whole = int.tryParse(t);
  if (whole != null) return (whole, 1);
  return null;
}

/// Splits [input] on whitespace and parses every token as a fraction. Returns
/// null when the input is empty or any token is invalid.
List<(int, int)>? parseFractionInput(String input) {
  final tokens =
      input.split(RegExp(r'\s+')).where((t) => t.trim().isNotEmpty).toList();
  if (tokens.isEmpty) return null;
  final out = <(int, int)>[];
  for (final t in tokens) {
    final f = parseFractionToken(t);
    if (f == null) return null;
    out.add(f);
  }
  return out;
}

/// Parses whole numbers separated by whitespace; null on empty/invalid input.
List<int>? parseIntegerInput(String input) {
  final tokens =
      input.split(RegExp(r'\s+')).where((t) => t.trim().isNotEmpty).toList();
  if (tokens.isEmpty) return null;
  final out = <int>[];
  for (final t in tokens) {
    final v = int.tryParse(t.trim());
    if (v == null) return null;
    out.add(v);
  }
  return out;
}

/// Least common multiple of every number in [nums]. Empty input yields 0.
int lcmOfAll(Iterable<int> nums) {
  var l = 1;
  var first = true;
  for (final n in nums) {
    if (n == 0) continue;
    l = first ? n.abs() : lcmOf(l, n);
    first = false;
  }
  return first ? 0 : l;
}

/// Applies [op] to 2..N fractions. add/sub use the LCM of all denominators as
/// the shared denominator (exactly how الفرائض مسائل are solved); mul/div fold
/// the numerators/denominators. Returns null when the result is undefined
/// (empty input, or division by a zero numerator).
NFractionOpResult? applyFractions(List<(int, int)> fs, FractionOp op) {
  if (fs.isEmpty) return null;
  var rawN = 0;
  var rawD = 0;
  var commonDen = 1;
  var scaledNs = <int>[];
  if (op == FractionOp.add || op == FractionOp.sub) {
    commonDen = lcmOfAll([for (final f in fs) f.$2]);
    scaledNs = [for (final f in fs) f.$1 * (commonDen ~/ f.$2)];
    rawD = commonDen;
    if (op == FractionOp.add) {
      rawN = scaledNs.fold(0, (a, b) => a + b);
    } else {
      var acc = scaledNs.first;
      for (final s in scaledNs.skip(1)) {
        acc -= s;
      }
      rawN = acc;
    }
  } else if (op == FractionOp.mul) {
    rawN = fs.fold(1, (a, f) => a * f.$1);
    rawD = fs.fold(1, (a, f) => a * f.$2);
  } else {
    rawN = fs.first.$1;
    rawD = fs.first.$2;
    for (final f in fs.skip(1)) {
      if (f.$1 == 0) return null;
      rawN *= f.$2;
      rawD *= f.$1;
    }
  }
  if (rawD == 0) return null;
  final s = simplifyFraction(rawN, rawD);
  return NFractionOpResult(
    op: op,
    inputs: fs,
    commonDen: commonDen,
    scaledNs: scaledNs,
    rawN: rawN,
    rawD: rawD,
    gcd: s.gcd,
    sign: s.simplifiedN < 0 ? -1 : 1,
    simplified: s.simplifiedD == 1
        ? '${s.simplifiedN}'
        : '${s.simplifiedN}/${s.simplifiedD}',
    mixed: s.mixed,
    decimal: s.decimal,
  );
}

/// Decimal form of n/d, e.g. 1/3 → «0.3333».
String fractionDecimal(int n, int d) => _decimal(n / d);

/// نتيجة حساب سهام مسألة من مسائل الفرائض (مثل أداة «حساب السهام» في
/// almwareeth.com): أصل المسألة = ک.م.م مخرج‌ها، سهام كل فرض = كسره × أصل.
class SharesCalculationResult {
  /// أصل المسألة قبل العول/الردّ (ک.م.م مخرج‌ها).
  final int asl;

  /// الكسور المدخلة بالترتيب.
  final List<(int, int)> fractions;

  /// سهام كل كسر: numerator × (asl ÷ denominator).
  final List<int> shares;

  /// مجموع السهام.
  final int totalShares;

  /// 'normal' | 'awl' (مجموع أكبر من الأصل) | 'radd' (مجموع أصغر من الأصل).
  final String mode;

  /// الأصل بعد التصحيح: في العول يساوي مجموع السهام، وإلا يبقى asl.
  final int correctedAsl;

  const SharesCalculationResult({
    required this.asl,
    required this.fractions,
    required this.shares,
    required this.totalShares,
    required this.mode,
    required this.correctedAsl,
  });
}

/// يحسب سهام المسألة وفق الطريقة الكلاسيكية: أصل المسألة = ک.م.م مخرج الفروض،
/// سهام كل وارث = كسره × الأصل. إذا زاد مجموع السهام عن الأصل كان عولًا (يُعدَّل
/// الأصل إلى المجموع)، وإن نقص كان ردًّا (يبقى الأصل ويوزَّع الباقي حسب السهام).
SharesCalculationResult calculateShares(List<(int, int)> fs) {
  final asl = lcmOfAll([for (final f in fs) f.$2]);
  final shares = [for (final f in fs) f.$1 * (asl ~/ f.$2)];
  final total = shares.fold(0, (a, b) => a + b);
  final mode = total > asl
      ? 'awl'
      : total < asl
          ? 'radd'
          : 'normal';
  return SharesCalculationResult(
    asl: asl,
    fractions: fs,
    shares: shares,
    totalShares: total,
    mode: mode,
    correctedAsl: mode == 'awl' ? total : asl,
  );
}

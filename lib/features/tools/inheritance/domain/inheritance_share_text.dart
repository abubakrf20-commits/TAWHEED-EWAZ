import 'inheritance_calculator.dart';

/// Formats an amount with thousands separators (Latin digits, chat-friendly):
/// `450000` → `450,000`; `1234.5` → `1,234.5`.
String inheritanceMoney(double v) {
  final s = v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2);
  final parts = s.split('.');
  final buf = StringBuffer();
  for (var i = 0; i < parts[0].length; i++) {
    if (i > 0 && i % 3 == 0) buf.write(',');
    buf.write(parts[0][parts[0].length - 1 - i]);
  }
  final body = buf.toString().split('').reversed.join();
  return parts.length > 1 ? '$body.${parts[1]}' : body;
}

/// Largest-remainder (Hare quota) apportionment: splits [total] among
/// [values] proportionally in units of 1/[scale] so the ROUNDED parts add up
/// to exactly [total] — independent per-row rounding can otherwise display
/// 99%/101% or a cent short of the estate. Display-only: the exact [Frac]
/// shares are never touched by this.
List<double> hareAllocate(List<double> values, double total,
    {int scale = 100}) {
  final n = values.length;
  if (n == 0) return const [];
  final sum = values.fold<double>(0.0, (a, b) => a + b);
  final target = (total * scale).round();
  if (sum <= 0 || target <= 0) return List<double>.filled(n, 0.0);
  final exact = [for (final v in values) v / sum * target];
  final parts = [for (final e in exact) e.floor()];
  var rest = target - parts.fold<int>(0, (a, b) => a + b);
  final order = List<int>.generate(n, (i) => i)
    ..sort((a, b) {
      final ra = exact[a] - parts[a];
      final rb = exact[b] - parts[b];
      final c = rb.compareTo(ra);
      return c != 0 ? c : a.compareTo(b);
    });
  for (var i = 0; rest > 0; i++, rest--) {
    parts[order[i % n]]++;
  }
  return [for (final p in parts) p / scale];
}

/// Integer percent labels that always sum to exactly 100 (Hare rule),
/// proportional to [values].
List<int> harePercents(List<double> values) =>
    [for (final v in hareAllocate(values, 100, scale: 1)) v.round()];

/// Builds a plain-text inheritance summary ready to paste into a chat.
/// Pure and testable: no Flutter, no platform channels.
String buildInheritanceShareText({
  required InheritanceResult result,
  required double estate,
}) {
  final lines = <String>[
    'نتایج تقسیم میراث',
    'ترکه: ${inheritanceMoney(estate)}',
    result.mandatoryWillAmount > 0
        ? 'ترکه پس از هزینه، دیون و وصیت عادی: ${inheritanceMoney(result.netEstate)}'
        : 'ترکه قابل تقسیم: ${inheritanceMoney(result.netEstate)}',
    if (result.mandatoryWillAmount > 0)
      'وصیت واجبه: ${inheritanceMoney(result.mandatoryWillAmount)} — مانده برای وراث اصلی: ${inheritanceMoney(result.estateForMainHeirs)}',
    'مذهب / قانون: ${madhabLabel(result.madhab)}',
    'روش تقسیم: ${result.methodLabel}',
    '',
    'سهم هر وارث:',
  ];

  if (result.shares.isEmpty) {
    lines.add('• وارثی یافت نشد.');
  } else {
    // Hare-rounded amounts so the listed figures add up to the estate.
    final displayAmounts = hareAllocate(
        [for (final s in result.shares) s.amount], result.totalAllocated);
    for (var i = 0; i < result.shares.length; i++) {
      final s = result.shares[i];
      final count = s.count > 1 ? ' (${s.count} نفر)' : '';
      lines.add('• ${heirLabel(s.type)}$count: '
          '${s.fraction.toArString()} — ${inheritanceMoney(displayAmounts[i])}');
      if (s.reason.isNotEmpty) {
        lines.add('  ${s.reason}');
      }
    }
  }

  for (final w in result.warnings) {
    lines.add('');
    lines.add('⚠️ $w');
  }

  lines
    ..add('')
    ..add('— ساخته شده با برنامهٔ توحید');
  return lines.join('\n');
}

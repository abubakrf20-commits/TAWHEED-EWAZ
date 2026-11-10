import 'inheritance_calculator.dart';
import 'madhab_calculator.dart';

/// مقایسهٔ نتیجهٔ ارث بین همهٔ مذاهب فقهی به‌طور هم‌زمان.
///
/// همان قابلیتی که در الموسوعة الإسلامية وجود دارد: «الميراث حسب
/// جماهير أهل العلم / المالكي / الحنبلي / الشافعي / الحنفي» در یک
/// نمای مقایسه‌ای ارائه می‌دهد.
class MadhhabComparison {
  final InheritanceInput input;
  final List<InheritanceResult> results;

  const MadhhabComparison({required this.input, required this.results});

  /// مذاهب فقهی (بدون قوانین مدنی).
  static const List<Madhab> fiqhMadhhabs = [
    Madhab.jumhur,
    Madhab.maliki,
    Madhab.hanbali,
    Madhab.shafii,
    Madhab.hanafi,
  ];

  /// همهٔ کدهای قابل‌مقایسه: پنج مذهب فقهی + کدهای قانونی مدنی کشورها.
  /// هر کلاینت مقایسه‌ای (تب، PDF، …) نتایجش را فقط از اینجا می‌گیرد تا
  /// ترکیب مذاهب/کدها یک‌جا تعریف شود.
  static const List<Madhab> comparisonMadhhabs = [
    ...fiqhMadhhabs,
    Madhab.egyptian,
    Madhab.saudi,
    Madhab.algerian,
    Madhab.moroccan,
    Madhab.jordanian,
    Madhab.emirati,
    Madhab.omani,
    Madhab.kuwaiti,
    Madhab.tunisia1956,
  ];

  InheritanceResult resultFor(Madhab madhab) {
    for (final r in results) {
      if (r.madhab == madhab) return r;
    }
    throw ArgumentError('نتیجه‌ای برای مذهب ${madhabLabel(madhab)} یافت نشد.');
  }
}

/// محاسبهٔ هم‌زمان مسألهٔ ارث در همهٔ مذاهب فقهی.
///
/// [madhhabs] را می‌توان محدود کرد (پیش‌فرض: هر پنج مذهب فقهی).
MadhhabComparison compareMadhhabs(
  InheritanceInput input, {
  List<Madhab>? madhhabs,
}) {
  final list = madhhabs ?? MadhhabComparison.fiqhMadhhabs;
  final results = <InheritanceResult>[];
  for (final m in list) {
    final run = input.madhab != m ? input.copyWith(madhab: m) : input;
    results.add(getCalculator(m).calculate(run));
  }
  return MadhhabComparison(input: input, results: results);
}

/// فهرست وارثانی که در یک مذهب ارث می‌برند اما در مذهب دیگر محجوب‌اند.
///
/// مفید برای نمایش تفاوت‌های بین‌مذهبی در نمای مقایسه.
class CrossMadhabDiff {
  final HeirType type;
  final String label;
  final Set<Madhab> inherits;
  final Set<Madhab> blocked;

  const CrossMadhabDiff({
    required this.type,
    required this.label,
    required this.inherits,
    required this.blocked,
  });

  bool get differs => inherits.isNotEmpty && blocked.isNotEmpty;
}

/// محاسبهٔ تفاوت‌های حجب بین مذاهب برای همان ورودی.
List<CrossMadhabDiff> crossMadhabBlockingDiffs(InheritanceInput input) {
  final comparison = compareMadhhabs(input);
  final diffs = <CrossMadhabDiff>[];

  for (final t in HeirType.values) {
    if (input.countOf(t) <= 0) continue;
    final inherits = <Madhab>{};
    final blocked = <Madhab>{};
    for (final r in comparison.results) {
      final hasIt = r.shares.any((s) => s.type == t);
      if (hasIt) {
        inherits.add(r.madhab);
      } else {
        blocked.add(r.madhab);
      }
    }
    diffs.add(CrossMadhabDiff(
      type: t,
      label: heirLabel(t),
      inherits: inherits,
      blocked: blocked,
    ));
  }

  return diffs.where((d) => d.differs).toList();
}

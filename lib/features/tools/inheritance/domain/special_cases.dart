import 'package:tawheeed/shared/utils/number_format.dart';

import 'inheritance_calculator.dart';
import 'madhab_calculator.dart';
import 'madhab_rules.dart';

/// نوع حالت خاص.
enum SpecialCaseKind { unbornChild, missingPerson, intersex }

/// یک سناریوی ممکن در حالت خاص (مثلاً «اگر نوزاد پسر باشد»).
class SpecialScenario {
  final String label;
  final InheritanceInput input;
  final InheritanceResult result;

  /// سهم (مبلغ) شخص موردبحث در این سناریو.
  final double pendingShare;

  const SpecialScenario({
    required this.label,
    required this.input,
    required this.result,
    required this.pendingShare,
  });
}

/// نتیجه محاسبه حالت خاص: چند سناریو + مبلغی که باید نگهداری شود.
class SpecialCaseResult {
  final SpecialCaseKind kind;
  final String explanation;
  final List<SpecialScenario> scenarios;
  final double reservedAmount;

  const SpecialCaseResult({
    required this.kind,
    required this.explanation,
    required this.scenarios,
    required this.reservedAmount,
  });
}

InheritanceInput _withExtra(InheritanceInput input, HeirType t, int add) {
  if (add <= 0) return input;
  final v = input.countOf(t) + add;
  switch (t) {
    case HeirType.son:
      return input.copyWith(son: v);
    case HeirType.daughter:
      return input.copyWith(daughter: v);
    case HeirType.husband:
      return input.copyWith(husband: v);
    case HeirType.wife:
      return input.copyWith(wife: v);
    case HeirType.fullBrother:
      return input.copyWith(fullBrother: v);
    case HeirType.fullSister:
      return input.copyWith(fullSister: v);
    case HeirType.grandson:
      return input.copyWith(grandson: v);
    case HeirType.granddaughter:
      return input.copyWith(granddaughter: v);
    case HeirType.greatGrandson:
      return input.copyWith(greatGrandson: v);
    case HeirType.greatGranddaughter:
      return input.copyWith(greatGranddaughter: v);
    case HeirType.maternalBrother:
      return input.copyWith(maternalBrother: v);
    case HeirType.maternalSister:
      return input.copyWith(maternalSister: v);
    case HeirType.paternalBrother:
      return input.copyWith(paternalBrother: v);
    case HeirType.paternalSister:
      return input.copyWith(paternalSister: v);
    case HeirType.nephewFull:
      return input.copyWith(nephewFull: v);
    case HeirType.nieceFull:
      return input.copyWith(nieceFull: v);
    case HeirType.nephewPaternal:
      return input.copyWith(nephewPaternal: v);
    case HeirType.niecePaternal:
      return input.copyWith(niecePaternal: v);
    case HeirType.paternalUncle:
      return input.copyWith(paternalUncle: v);
    case HeirType.paternalAunt:
      return input.copyWith(paternalAunt: v);
    case HeirType.paternalUncleSon:
      return input.copyWith(paternalUncleSon: v);
    case HeirType.uncleDaughter:
      return input.copyWith(uncleDaughter: v);
    default:
      return input;
  }
}

double _shareOf(InheritanceResult r, HeirType t) {
  for (final s in r.shares) {
    if (s.type == t) return s.amount;
  }
  return 0;
}

/// محاسبه حالت خاص:
///
/// - [unbornChild]: نوزاد متولدنشده — سناریوی پسر و دختر.
/// - [intersex]: شخصی با جنسیت نامعلوم — سناریوی مذکر/مؤنث.
/// - [missingPerson]: شخص مفقود با [pendingType] و [pendingCount].
SpecialCaseResult calculateSpecialCase(
  InheritanceInput input,
  SpecialCaseKind kind, {
  HeirType pendingType = HeirType.fullBrother,
  int pendingCount = 1,
}) {
  final calc = getCalculator(input.madhab);
  switch (kind) {
    case SpecialCaseKind.unbornChild:
      final male = _withExtra(input, HeirType.son, pendingCount);
      final female = _withExtra(input, HeirType.daughter, pendingCount);
      final maleR = calc.calculate(male);
      final femaleR = calc.calculate(female);
      return SpecialCaseResult(
        kind: kind,
        explanation:
            'ارث شامل نوزادِ در رحم است. تا زمان تولد، تقسیم قطعی انجام نمی‌شود و سهم نوزاد (حداکثر حالت) نگهداری می‌شود.',
        scenarios: [
          SpecialScenario(
            label: 'اگر نوزاد پسر باشد',
            input: male,
            result: maleR,
            pendingShare: _shareOf(maleR, HeirType.son),
          ),
          SpecialScenario(
            label: 'اگر نوزاد دختر باشد',
            input: female,
            result: femaleR,
            pendingShare: _shareOf(femaleR, HeirType.daughter),
          ),
        ],
        reservedAmount: 0,
      );
    case SpecialCaseKind.intersex:
      final male = _withExtra(input, HeirType.son, 1);
      final female = _withExtra(input, HeirType.daughter, 1);
      final maleR = calc.calculate(male);
      final femaleR = calc.calculate(female);
      return SpecialCaseResult(
        kind: kind,
        explanation:
            'شخص خنثی تا روشن‌شدن جنسیت، در دو حالت مذکر/مؤنث محاسبه می‌شود و سهم بیشتر به‌عنوان احتیاط نگهداری می‌شود.',
        scenarios: [
          SpecialScenario(
            label: 'اگر مذکر باشد',
            input: male,
            result: maleR,
            pendingShare: _shareOf(maleR, HeirType.son),
          ),
          SpecialScenario(
            label: 'اگر مؤنث باشد',
            input: female,
            result: femaleR,
            pendingShare: _shareOf(femaleR, HeirType.daughter),
          ),
        ],
        reservedAmount: 0,
      );
    case SpecialCaseKind.missingPerson:
      final present = _withExtra(input, pendingType, pendingCount);
      final presentR = calc.calculate(present);
      final absentR = calc.calculate(input);
      return SpecialCaseResult(
        kind: kind,
        explanation:
            'شخص مفقود تا تعیین وضعیت، در دو حالت «زنده» و «مرده» محاسبه می‌شود؛ سهم حالت زنده به‌عنوان احتیاط نگهداری می‌شود.',
        scenarios: [
          SpecialScenario(
            label: 'اگر مفقود زنده باشد',
            input: present,
            result: presentR,
            pendingShare: _shareOf(presentR, pendingType),
          ),
          SpecialScenario(
            label: 'اگر مفقود مرده باشد',
            input: input,
            result: absentR,
            pendingShare: 0,
          ),
        ],
        reservedAmount: 0,
      );
  }
}

/// حداکثر سهمی که باید تا روشن‌شدن وضعیت نگهداری شود.
double reservedForSpecialCase(SpecialCaseResult r) {
  return r.scenarios
      .fold(0.0, (m, s) => s.pendingShare > m ? s.pendingShare : m);
}

// ══════════════════════════════════════════════════════════
//  الحمل (حاملگی) — سناریوهای متعدد
// ══════════════════════════════════════════════════════════

/// رابطهٔ زن حامله با متوفی — تعیین می‌کند فرزند چه جایگاهی دارد.
enum PregnancyRelation {
  /// زوجة الميت حامل → فرزند او: پسر یا دختر.
  wife,

  /// زوجة ابن الميت حامل → پسرِ پسر یا دخترِ پسر.
  sonWife,

  /// زوجة ابن ابن الميت حامل → پسرِ پسرِ پسر یا دخترِ پسرِ پسر.
  grandsonWife,

  /// أم الميت حامل → برادر/خواهر (پدری و مادری).
  mother,

  /// أم الميت حامل من زوج آخر → برادر/خواهر مادری.
  motherFromAnotherHusband,

  /// زوجة أب الميت حامل → برادر/خواهر پدری.
  fathersWife,

  /// زوجة الأخ الشقيق حامل → پسرِ برادر (پدری و مادری).
  fullBrotherWife,

  /// زوجة الأخ لأب حامل → پسرِ برادرِ پدری.
  paternalBrotherWife,

  /// زوجة الجد (جدة الميت) حامل → عمو/عمه.
  grandfatherWife,
}

/// نتیجهٔ احتمالی زایمان: سقط یا تولد با تعداد معین.
class PregnancyOutcome {
  final String label;

  /// تعداد فرزندان مذکر متولدشده.
  final int males;

  /// تعداد فرزندان مؤنث متولدشده.
  final int females;

  const PregnancyOutcome({
    required this.label,
    required this.males,
    required this.females,
  });
}

/// همهٔ نتایج ممکن زایمان (مطابق الموسوعة الإسلامية):
/// سقط، ذكر، أنثى، ذكر وأنثى، ذكرين، أنثيين، أربعة ذكور، أربع إناث.
const List<PregnancyOutcome> allPregnancyOutcomes = [
  PregnancyOutcome(label: 'سقط ميتًا (بدون اثر)', males: 0, females: 0),
  PregnancyOutcome(label: 'یک فرزند پسر', males: 1, females: 0),
  PregnancyOutcome(label: 'یک فرزند دختر', males: 0, females: 1),
  PregnancyOutcome(label: 'پسر و دختر', males: 1, females: 1),
  PregnancyOutcome(label: 'دو فرزند پسر', males: 2, females: 0),
  PregnancyOutcome(label: 'دو فرزند دختر', males: 0, females: 2),
  PregnancyOutcome(label: 'چهار فرزند پسر', males: 4, females: 0),
  PregnancyOutcome(label: 'چهار فرزند دختر', males: 0, females: 4),
];

/// نوع مذکر و مؤنث نوزاد بر اساس رابطهٔ حامله.
(HeirType, HeirType) _pregnancyTypes(PregnancyRelation relation) {
  switch (relation) {
    case PregnancyRelation.wife:
      return (HeirType.son, HeirType.daughter);
    case PregnancyRelation.sonWife:
      return (HeirType.grandson, HeirType.granddaughter);
    case PregnancyRelation.grandsonWife:
      return (HeirType.greatGrandson, HeirType.greatGranddaughter);
    case PregnancyRelation.mother:
      return (HeirType.fullBrother, HeirType.fullSister);
    case PregnancyRelation.motherFromAnotherHusband:
      return (HeirType.maternalBrother, HeirType.maternalSister);
    case PregnancyRelation.fathersWife:
      return (HeirType.paternalBrother, HeirType.paternalSister);
    case PregnancyRelation.fullBrotherWife:
      return (HeirType.nephewFull, HeirType.nieceFull);
    case PregnancyRelation.paternalBrotherWife:
      return (HeirType.nephewPaternal, HeirType.niecePaternal);
    case PregnancyRelation.grandfatherWife:
      return (HeirType.paternalUncle, HeirType.paternalAunt);
  }
}

String _pregnancyRelationLabel(PregnancyRelation relation) {
  switch (relation) {
    case PregnancyRelation.wife:
      return 'همسر متوفی حامله است';
    case PregnancyRelation.sonWife:
      return 'همسر پسر متوفی حامله است';
    case PregnancyRelation.grandsonWife:
      return 'همسر نوهٔ پسر متوفی حامله است';
    case PregnancyRelation.mother:
      return 'مادر متوفی حامله است';
    case PregnancyRelation.motherFromAnotherHusband:
      return 'مادر متوفی از همسر دیگر حامله است';
    case PregnancyRelation.fathersWife:
      return 'همسر پدر متوفی حامله است';
    case PregnancyRelation.fullBrotherWife:
      return 'همسر برادر (پدری و مادری) متوفی حامله است';
    case PregnancyRelation.paternalBrotherWife:
      return 'همسر برادر پدری متوفی حامله است';
    case PregnancyRelation.grandfatherWife:
      return 'همسر پدربزرگ (مادربزرگ متوفی) حامله است';
  }
}

/// محاسبهٔ حالت حاملگی با تمام نتایج ممکن (سقط تا چهار فرزند).
///
/// هر نتیجه یک سناریو با سهم‌های مربوطه می‌سازد و مبلغی که باید تا
/// وضع‌حمل نگهداری شود حداکثر سهم فرزندان در همهٔ نتایج است.
SpecialCaseResult calculatePregnancyCase(
  InheritanceInput input,
  PregnancyRelation relation,
) {
  final calc = getCalculator(input.madhab);
  final (maleType, femaleType) = _pregnancyTypes(relation);
  final scenarios = <SpecialScenario>[];

  for (final outcome in allPregnancyOutcomes) {
    var scenarioInput = input;
    if (outcome.males > 0) {
      scenarioInput = _withExtra(scenarioInput, maleType, outcome.males);
    }
    if (outcome.females > 0) {
      scenarioInput = _withExtra(scenarioInput, femaleType, outcome.females);
    }
    final r = calc.calculate(scenarioInput);
    final unbornShare = _shareOf(r, maleType) + _shareOf(r, femaleType);
    scenarios.add(SpecialScenario(
      label: outcome.label,
      input: scenarioInput,
      result: r,
      pendingShare: unbornShare,
    ));
  }

  final reserved =
      scenarios.fold(0.0, (m, s) => s.pendingShare > m ? s.pendingShare : m);

  return SpecialCaseResult(
    kind: SpecialCaseKind.unbornChild,
    explanation:
        '${_pregnancyRelationLabel(relation)}. ارث شامل فرزند در رحم است؛ تا زمان تولد '
        'تقسیم قطعی نمی‌شود و بیشترین سهم ممکن برای فرزندان '
        '(${NumberFormat.groupDigits(reserved.toStringAsFixed(0))}) '
        'نگهداری می‌شود.',
    scenarios: scenarios,
    reservedAmount: reserved,
  );
}

// ══════════════════════════════════════════════════════════
//  الخنثى (دوگانه‌جنسی) — دو حالت
// ══════════════════════════════════════════════════════════

/// نحوهٔ برخورد با خنثی:
/// - [disclosed]: امید روشن‌شدن جنسیت هست → دو سناریو و نگهداری سهم بیشتر.
/// - [undisclosed]: روشن نمی‌شود (مذهب مالکی) → به‌عنوان مؤنث ارث می‌برد.
enum IntersexMode { disclosed, undisclosed }

/// محاسبهٔ حالت خنثی با دو شیوه.
SpecialCaseResult calculateIntersexCase(
  InheritanceInput input,
  HeirType pendingType,
  IntersexMode mode,
) {
  final calc = getCalculator(input.madhab);
  final male = _withExtra(input, pendingType, 1);
  final female = _withExtra(input, _femaleOf(pendingType), 1);

  if (mode == IntersexMode.undisclosed) {
    // المالكية: لا يُرجى انكشاف حالته، فيُعطى أقلَّ السهمين (حكم الأنثى).
    final femaleR = calc.calculate(female);
    return SpecialCaseResult(
      kind: SpecialCaseKind.intersex,
      explanation:
          'شخص خنثی مشتبه که انکشاف حالتش ممکن نیست (مذهب مالکی): به‌عنوان '
          'مؤنث ارث می‌برد (سهم کمتر احتیاطاً).',
      scenarios: [
        SpecialScenario(
          label: 'به‌عنوان مؤنث (مذهب مالکی)',
          input: female,
          result: femaleR,
          pendingShare: _shareOf(femaleR, _femaleOf(pendingType)),
        ),
      ],
      reservedAmount: 0,
    );
  }

  final maleR = calc.calculate(male);
  final femaleR = calc.calculate(female);
  return SpecialCaseResult(
    kind: SpecialCaseKind.intersex,
    explanation:
        'شخص خنثی تا روشن‌شدن جنسیت در دو حالت مذکر/مؤنث محاسبه می‌شود و '
        'سهم بیشتر به‌عنوان احتیاط نگهداری می‌شود.',
    scenarios: [
      SpecialScenario(
        label: 'اگر مذکر باشد',
        input: male,
        result: maleR,
        pendingShare: _shareOf(maleR, pendingType),
      ),
      SpecialScenario(
        label: 'إذا كان أنثى',
        input: female,
        result: femaleR,
        pendingShare: _shareOf(femaleR, _femaleOf(pendingType)),
      ),
    ],
    reservedAmount: 0,
  );
}

/// نوع مؤنث متناظر برای یک وارث مذکر (یا خودش اگر مؤنث باشد).
HeirType _femaleOf(HeirType t) {
  switch (t) {
    case HeirType.son:
      return HeirType.daughter;
    case HeirType.grandson:
      return HeirType.granddaughter;
    case HeirType.greatGrandson:
      return HeirType.greatGranddaughter;
    case HeirType.fullBrother:
      return HeirType.fullSister;
    case HeirType.paternalBrother:
      return HeirType.paternalSister;
    case HeirType.maternalBrother:
      return HeirType.maternalSister;
    case HeirType.nephewFull:
      return HeirType.nieceFull;
    case HeirType.nephewPaternal:
      return HeirType.niecePaternal;
    case HeirType.paternalUncle:
      return HeirType.paternalAunt;
    case HeirType.paternalUncleSon:
      return HeirType.uncleDaughter;
    case HeirType.daughter:
    case HeirType.granddaughter:
    case HeirType.greatGranddaughter:
    case HeirType.fullSister:
    case HeirType.paternalSister:
    case HeirType.maternalSister:
    case HeirType.nieceFull:
    case HeirType.niecePaternal:
    case HeirType.paternalAunt:
      return t;
    default:
      return t;
  }
}

// ══════════════════════════════════════════════════════════
//  العبد المبعض (بردهٔ آزادشدهٔ بخشی) — عند الحنابلة فقط
// ══════════════════════════════════════════════════════════

/// نتیجهٔ محاسبهٔ ارث بردهٔ مبعض (کسی که بخشی از وجودش آزاد و بخشی برده است).
class BondmanCase {
  final HeirType type;
  final int count;
  final double freeFraction;
  final InheritanceResult result;

  /// مقدار سهمی که به‌خاطر بخش آزادش به او می‌رسد.
  final double inheritedAmount;

  /// مقداری که به‌خاطر بخشِ بردهٔ او (برای مولای او) نگهداری می‌شود.
  final double withheldAmount;

  const BondmanCase({
    required this.type,
    required this.count,
    required this.freeFraction,
    required this.result,
    required this.inheritedAmount,
    required this.withheldAmount,
  });
}

/// محاسبهٔ میراث العبد المبعض (عند الحنابلة فقط).
///
/// وارثی که بردهٔ مبعض است به اندازهٔ بخشِ آزادش ارث می‌برد و باقی‌ماندهٔ
/// سهمش به مولای او (یا بیت‌المال) می‌رسد.
/// [freeFraction] کسری از 0 تا 1 است (مثل 0٫5 یعنی نصفش آزاد است).
BondmanCase calculateBondmanCase(
  InheritanceInput input,
  HeirType type, {
  double freeFraction = 0.5,
}) {
  final base = MadhabRules.baseMadhab(input.madhab);
  if (base != Madhab.hanbali) {
    throw ArgumentError(
        'میراث «العبد المبعض» (بندهٔ مشاع) فقط در مذهب حنبلی (و قوانین بر پایهٔ آن) جاری است.');
  }
  if (freeFraction <= 0 || freeFraction > 1) {
    throw ArgumentError('کسری از بخشِ آزاد باید بین 0 تا 1 باشد.');
  }

  final calc = getCalculator(input.madhab);
  final result = calc.calculate(input);
  final share = result.shares
      .where((s) => s.type == type)
      .fold(0.0, (m, s) => m + s.amount);
  final count = input.countOf(type);

  return BondmanCase(
    type: type,
    count: count,
    freeFraction: freeFraction,
    result: result,
    inheritedAmount: share * freeFraction,
    withheldAmount: share * (1 - freeFraction),
  );
}

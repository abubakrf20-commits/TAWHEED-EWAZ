import 'inheritance_calculator.dart';
import 'madhab_calculator.dart';

/// جنس ولد الميت الذي توفي قبل أصله المورث (صاحب الأولاد المستحقين للوصية).
enum DeceasedChildGender {
  /// ذكر — أبٌّ للمستحقين (أولاد الابن المتوفى).
  male,

  /// أنثى — أمٌّ للمستحقين (أبناء البنت المتوفاة).
  female,
}

/// قانون کشور در خصوص الوصية الواجبة (وصیت اجباری به نوه‌های یتیم).
class MandatoryWillLaw {
  final String country;
  final String codeName;
  final double capFraction; // حداکثر کسر ترکه (مثل 1/3)

  const MandatoryWillLaw({
    required this.country,
    required this.codeName,
    this.capFraction = 1 / 3,
  });
}

/// قوانین کشورهایی که وصیت واجبه دارند.
const List<MandatoryWillLaw> mandatoryWillLaws = [
  MandatoryWillLaw(
    country: 'مصر',
    codeName: 'قانون وصیت شمارهٔ 71 سال 1946 مصر، مادهٔ 76',
  ),
  MandatoryWillLaw(
    country: 'سوریه',
    codeName: 'قانون احوال شخصیهٔ سوریه، مادهٔ 257',
  ),
  MandatoryWillLaw(
    country: 'تونس',
    codeName: 'مجلهٔ احوال شخصیهٔ تونس، مادهٔ 191',
  ),
  MandatoryWillLaw(
    country: 'الجزایر',
    codeName: 'قانون خانوادهٔ الجزایر، مادهٔ 72',
  ),
  MandatoryWillLaw(
    country: 'مراکش',
    codeName: 'قانون خانوادهٔ مراکش (مدونة الأسرة)، مادهٔ 303',
  ),
  MandatoryWillLaw(
    country: 'لیبی',
    codeName: 'قانون احوال شخصیهٔ لیبی',
  ),
  MandatoryWillLaw(
    country: 'عراق',
    codeName: 'قانون احوال شخصیهٔ عراق',
  ),
  MandatoryWillLaw(
    country: 'امارات',
    codeName: 'قانون احوال شخصیهٔ امارات (اتحادی)، مادهٔ 272',
  ),
  MandatoryWillLaw(
    country: 'کویت',
    codeName: 'قانون احوال شخصیهٔ کویت، مادهٔ 290',
  ),
  MandatoryWillLaw(
    country: 'قطر',
    codeName: 'قانون خانوادهٔ قطر',
  ),
  MandatoryWillLaw(
    country: 'سودان',
    codeName: 'قانون احوال شخصیهٔ سودان',
  ),
  MandatoryWillLaw(
    country: 'اردن',
    codeName: 'قانون احوال شخصیهٔ اردن، مادهٔ 282',
  ),
];

/// سهم یک نوه در وصیت واجبه.
class OrphanShare {
  final HeirType type;
  final int count;
  final double amount;
  final Frac fraction;

  const OrphanShare({
    required this.type,
    required this.count,
    required this.amount,
    required this.fraction,
  });
}

/// نتیجه محاسبه وصیت واجبه.
class MandatoryWillResult {
  final MandatoryWillLaw law;
  final bool applies;

  /// مقدار وصیت واجبه (حداکثر 1/3 ترکه).
  final double mandatoryAmount;

  /// سهم‌های نوه‌های یتیم از این وصیت (مذکر 2 برابر مؤنث).
  final List<OrphanShare> orphans;

  /// توزیع باقی‌مانده ترکه (بعد از کسر وصیت) بین سایر وراث.
  final InheritanceResult remainingResult;

  /// جنس ولد متوفی که پیش از مورث اصلی مرده است.
  final DeceasedChildGender deceasedChildGender;

  const MandatoryWillResult({
    required this.law,
    required this.applies,
    required this.mandatoryAmount,
    required this.orphans,
    required this.remainingResult,
    this.deceasedChildGender = DeceasedChildGender.male,
  });

  double get totalAllocated =>
      remainingResult.totalAllocated +
      orphans.fold(0.0, (s, o) => s + o.amount);
}

InheritanceInput _withoutOrphans(InheritanceInput input) {
  return input.copyWith(grandson: 0, granddaughter: 0);
}

InheritanceInput _withEstate(InheritanceInput input, double estate) {
  return input.copyWith(estate: estate);
}

/// محاسبه الوصية الواجبة.
///
/// وقتی پسر متوفی قبل از او فوت کرده و فرزندانی (نوه‌ها) از خود به‌جای
/// گذاشته است، قانون کشورهای منتخب به آن نوه‌ها وصیت اجباری به‌اندازه سهم
/// پدرشان (حداکثر 1/3 ترکه) می‌دهد؛ مذکر دو برابر مؤنث.
MandatoryWillResult calculateMandatoryWill(
  InheritanceInput input,
  MandatoryWillLaw law, {
  DeceasedChildGender deceasedChildGender = DeceasedChildGender.male,
}) {
  final orphanGrandsons = input.grandson;
  final orphanGranddaughters = input.granddaughter;
  final applies = orphanGrandsons + orphanGranddaughters > 0;

  if (!applies) {
    return MandatoryWillResult(
      law: law,
      applies: false,
      mandatoryAmount: 0,
      orphans: const [],
      remainingResult: getCalculator(input.madhab).calculate(input),
      deceasedChildGender: deceasedChildGender,
    );
  }

  // ترکه صافی که وصیت واجبه از آن محاسبه می‌شود: بعد از هزینه و دیون و وصیت.
  final netEstate =
      input.estate - input.funeralExpenses - input.debts - input.willAmount;
  if (netEstate <= 0) {
    return MandatoryWillResult(
      law: law,
      applies: true,
      mandatoryAmount: 0,
      orphans: const [],
      remainingResult: getCalculator(input.madhab).calculate(input),
      deceasedChildGender: deceasedChildGender,
    );
  }

  // فرض: فرزند متوفی زنده است → سهم او (یکی از پسرها یا دخترها) را به‌دست می‌آوریم.
  final isMaleChild = deceasedChildGender == DeceasedChildGender.male;
  final childType = isMaleChild ? HeirType.son : HeirType.daughter;
  final hypothetical = _withoutOrphans(input).copyWith(
    estate: netEstate,
    son: isMaleChild ? input.son + 1 : input.son,
    daughter: isMaleChild ? input.daughter : input.daughter + 1,
    funeralExpenses: 0,
    debts: 0,
    willAmount: 0,
    willAmount2: 0,
    willAmount3: 0,
  );
  final hypResult = getCalculator(input.madhab).calculate(hypothetical);

  final childrenShare = hypResult.shares
      .where((s) => s.type == childType)
      .fold(0.0, (m, s) => m + s.amount);
  final oneChildShare =
      childrenShare / (isMaleChild ? input.son + 1 : input.daughter + 1);
  final maxAllowed = netEstate * law.capFraction;
  final mandatoryAmount =
      oneChildShare > maxAllowed ? maxAllowed : oneChildShare;

  // توزیع وصیت بین نوه‌ها: مذکر 2 برابر مؤنث.
  final totalUnits = orphanGrandsons * 2 + orphanGranddaughters;
  final orphans = <OrphanShare>[];
  if (totalUnits > 0 && mandatoryAmount > 0) {
    final perUnit = mandatoryAmount / totalUnits;
    if (orphanGrandsons > 0) {
      orphans.add(OrphanShare(
        type: HeirType.grandson,
        count: orphanGrandsons,
        amount: perUnit * 2 * orphanGrandsons,
        fraction: Frac(2 * orphanGrandsons, totalUnits),
      ));
    }
    if (orphanGranddaughters > 0) {
      orphans.add(OrphanShare(
        type: HeirType.granddaughter,
        count: orphanGranddaughters,
        amount: perUnit * orphanGranddaughters,
        fraction: Frac(orphanGranddaughters, totalUnits),
      ));
    }
  }

  // توزیع باقی‌مانده بین سایر وراث (نوه‌ها در این مرحله وارث نیستند).
  final remainingInput =
      _withEstate(_withoutOrphans(input), netEstate - mandatoryAmount);
  final remainingResult = getCalculator(input.madhab).calculate(remainingInput);

  return MandatoryWillResult(
    law: law,
    applies: true,
    mandatoryAmount: mandatoryAmount,
    orphans: orphans,
    remainingResult: remainingResult,
    deceasedChildGender: deceasedChildGender,
  );
}

import 'madhab_calculator.dart';

/// مذهب فقهی انتخاب شده.
///
/// [jumhur] همان پیش‌فرض سایت almwareeth.com (جمهور فقها) است.
/// افزون بر مذاهب چهارگانه، قوانین مدنی کشورهای عربی (مطابق
/// almwareeth.com) نیز در اینجا قرار دارند.
enum Madhab {
  jumhur,
  hanafi,
  maliki,
  shafii,
  hanbali,
  egyptian,
  saudi,
  algerian,
  moroccan,
  jordanian,
  emirati,
  omani,
  kuwaiti,
  tunisia1956,
}

/// Persian label for a madhab or legal code.
String madhabLabel(Madhab m) {
  switch (m) {
    case Madhab.jumhur:
      return 'جمهور';
    case Madhab.hanafi:
      return 'حنفی';
    case Madhab.maliki:
      return 'مالکی';
    case Madhab.shafii:
      return 'شافعی';
    case Madhab.hanbali:
      return 'حنبلی';
    case Madhab.egyptian:
      return 'قانون مصری';
    case Madhab.saudi:
      return 'قانون سعودی';
    case Madhab.algerian:
      return 'قانون الجزایری';
    case Madhab.moroccan:
      return 'قانون مغربی';
    case Madhab.jordanian:
      return 'قانون اردنی';
    case Madhab.emirati:
      return 'قانون اماراتی';
    case Madhab.omani:
      return 'قانون عمانی';
    case Madhab.kuwaiti:
      return 'قانون کویتی';
    case Madhab.tunisia1956:
      return 'تونس 1956';
  }
}

/// نوع استحقاق الوارث.
enum ShareType { fard, asaba, radd, hajb, mandatoryWill }

/// Label for a share type in Persian.
String shareTypeLabel(ShareType t) {
  switch (t) {
    case ShareType.fard:
      return 'فرض';
    case ShareType.asaba:
      return 'تعصيب';
    case ShareType.radd:
      return 'رد';
    case ShareType.hajb:
      return 'حجب';
    case ShareType.mandatoryWill:
      return 'وصیت واجبه';
  }
}

/// Immutable exact fraction using integer numerator/denominator.
class Frac {
  final int n;
  final int d;

  const Frac._(this.n, this.d) : assert(d > 0);

  factory Frac(int n, int d) {
    if (n == 0) return const Frac._(0, 1);
    if (d < 0) {
      n = -n;
      d = -d;
    }
    final g = _gcd(n.abs(), d);
    return Frac._(n ~/ g, d ~/ g);
  }

  static const zero = Frac._(0, 1);
  static const one = Frac._(1, 1);

  static int _gcd(int a, int b) {
    a = a.abs();
    b = b.abs();
    while (b != 0) {
      final t = b;
      b = a % b;
      a = t;
    }
    return a;
  }

  Frac operator +(Frac o) => Frac(n * o.d + o.n * d, d * o.d);
  Frac operator -(Frac o) => Frac(n * o.d - o.n * d, d * o.d);
  Frac operator *(Frac o) => Frac(n * o.n, d * o.d);
  Frac operator /(Frac o) => Frac(n * o.d, d * o.n);
  bool operator <(Frac o) => n * o.d < o.n * d;
  bool operator >(Frac o) => n * o.d > o.n * d;
  bool operator <=(Frac o) => n * o.d <= o.n * d;
  bool operator >=(Frac o) => n * o.d >= o.n * d;

  double toDouble() => n / d;
  bool get isZero => n == 0;
  bool get isPositive => n > 0;

  /// Format as a plain fraction string, e.g. "1/2".
  String toArString() {
    if (n == 0) return '0';
    if (d == 1) return n.toString();
    return '$n/$d';
  }
}

/// أنواع الورثة (44 وارثًا) — مطابق نموذج موقع almwareeth.com.
enum HeirType {
  husband,
  wife,
  mother,
  father,
  // الجدّات (5)
  maternalGrandmother, // أم الأم
  paternalGrandmother, // أم الأب
  greatMaternalGrandmother, // أم أم الأم
  paternalGreatGrandmotherFather, // أم أب الأب
  paternalGreatGrandmotherMother, // أم أم الأب
  // الأجداد
  grandfather, // أب الأب
  greatGrandfather, // أب أب الأب
  // الفرع الوارث
  daughter,
  son,
  granddaughter,
  grandson,
  greatGranddaughter,
  greatGrandson,
  // الإخوة
  fullSister,
  fullBrother,
  paternalSister,
  paternalBrother,
  maternalSister,
  maternalBrother,
  // بنو الإخوة
  nephewPaternal,
  nephewFull,
  nephewSonPaternal,
  nephewSonFull,
  // العمومة
  paternalUnclePaternal,
  paternalUncle,
  paternalUncleSonPaternal,
  paternalUncleSon,
  paternalUncleGrandsonPaternal,
  paternalUncleGrandson,
  // عمومة الأب (أخوال الجد)
  fatherUnclePaternal,
  fatherUncleFull,
  fatherCousinPaternal,
  fatherCousinFull,
  // وراث غیر اصلی
  paternalAunt,
  maternalUncle,
  maternalAunt,
  nieceFull,
  niecePaternal,
  // ذوو الأرحام (خویشاوندان دور)
  nieceSon, // ابن الأخت
  uncleDaughter, // بنت العم
}

/// Persian label for a heir type.
String heirLabel(HeirType t) {
  switch (t) {
    case HeirType.husband:
      return 'شوهر';
    case HeirType.wife:
      return 'همسر';
    case HeirType.mother:
      return 'مادر';
    case HeirType.father:
      return 'پدر';
    case HeirType.maternalGrandmother:
      return 'مادربزرگ مادری (مادرِ مادر)';
    case HeirType.paternalGrandmother:
      return 'مادربزرگ پدری (مادرِ پدر)';
    case HeirType.greatMaternalGrandmother:
      return 'مادرِ مادرِ مادر (مادربزرگِ مادریِ مادر)';
    case HeirType.paternalGreatGrandmotherFather:
      return 'مادرِ پدرِ پدر (مادرِ پدربزرگِ پدری)';
    case HeirType.paternalGreatGrandmotherMother:
      return 'مادرِ مادرِ پدر (مادربزرگِ مادریِ پدر)';
    case HeirType.grandfather:
      return 'پدربزرگ پدری (پدرِ پدر)';
    case HeirType.greatGrandfather:
      return 'پدرِ پدربزرگ (پدرِ پدرِ پدر)';
    case HeirType.daughter:
      return 'دختر';
    case HeirType.son:
      return 'پسر';
    case HeirType.granddaughter:
      return 'دخترِ پسر';
    case HeirType.grandson:
      return 'پسرِ پسر';
    case HeirType.greatGranddaughter:
      return 'دخترِ پسرِ پسر';
    case HeirType.greatGrandson:
      return 'پسرِ پسرِ پسر';
    case HeirType.fullSister:
      return 'خواهر (پدری و مادری)';
    case HeirType.fullBrother:
      return 'برادر (پدری و مادری)';
    case HeirType.paternalSister:
      return 'خواهر پدری';
    case HeirType.paternalBrother:
      return 'برادر پدری';
    case HeirType.maternalSister:
      return 'خواهر مادری';
    case HeirType.maternalBrother:
      return 'برادر مادری';
    case HeirType.nephewPaternal:
      return 'پسرِ برادرِ پدری';
    case HeirType.nephewFull:
      return 'پسرِ برادرِ پدری و مادری';
    case HeirType.nephewSonPaternal:
      return 'پسرِ پسرِ برادرِ پدری';
    case HeirType.nephewSonFull:
      return 'پسرِ پسرِ برادرِ پدری و مادری';
    case HeirType.paternalUnclePaternal:
      return 'عموی پدری (برادرِ پدریِ پدر)';
    case HeirType.paternalUncle:
      return 'عمو (برادرِ پدر)';
    case HeirType.paternalUncleSonPaternal:
      return 'پسرِ عموی پدری (پسرِ برادرِ پدریِ پدر)';
    case HeirType.paternalUncleSon:
      return 'پسرِ عمو (پسرِ برادرِ پدر)';
    case HeirType.paternalUncleGrandsonPaternal:
      return 'پسرِ پسرِ عمویِ پدری (پسرِ پسرِ برادرِ پدریِ پدر)';
    case HeirType.paternalUncleGrandson:
      return 'پسرِ پسرِ عمو (پسرِ پسرِ برادرِ پدر)';
    case HeirType.fatherUnclePaternal:
      return 'عموی پدریِ پدر (برادرِ پدریِ پدربزرگ)';
    case HeirType.fatherUncleFull:
      return 'عمویِ پدر (برادرِ پدربزرگِ پدری)';
    case HeirType.fatherCousinPaternal:
      return 'پسرِ عموی پدریِ پدر';
    case HeirType.fatherCousinFull:
      return 'پسرِ عمویِ پدر (پسرِ برادرِ پدربزرگ)';
    case HeirType.paternalAunt:
      return 'عمه (خواهرِ پدر)';
    case HeirType.maternalUncle:
      return 'دایی (برادرِ مادر)';
    case HeirType.maternalAunt:
      return 'خاله (خواهرِ مادر)';
    case HeirType.nieceFull:
      return 'دخترِ برادرِ پدری و مادری';
    case HeirType.niecePaternal:
      return 'دخترِ برادرِ پدری';
    case HeirType.nieceSon:
      return 'پسرِ خواهر';
    case HeirType.uncleDaughter:
      return 'دخترِ عمو';
  }
}

/// Gender of the heir itself — the deceased's gender follows from the heirs
/// being entered (a man never has a husband, a woman never has more than four
/// wives), so no screen has to keep a manual switch in sync with the list.
bool heirIsMale(HeirType t) {
  return switch (t) {
    HeirType.husband ||
    HeirType.father ||
    HeirType.grandfather ||
    HeirType.greatGrandfather ||
    HeirType.son ||
    HeirType.grandson ||
    HeirType.greatGrandson ||
    HeirType.fullBrother ||
    HeirType.paternalBrother ||
    HeirType.maternalBrother ||
    HeirType.nephewPaternal ||
    HeirType.nephewFull ||
    HeirType.nephewSonPaternal ||
    HeirType.nephewSonFull ||
    HeirType.paternalUnclePaternal ||
    HeirType.paternalUncle ||
    HeirType.paternalUncleSonPaternal ||
    HeirType.paternalUncleSon ||
    HeirType.paternalUncleGrandsonPaternal ||
    HeirType.paternalUncleGrandson ||
    HeirType.fatherUnclePaternal ||
    HeirType.fatherUncleFull ||
    HeirType.fatherCousinPaternal ||
    HeirType.fatherCousinFull ||
    HeirType.maternalUncle ||
    HeirType.nieceSon =>
      true,
    HeirType.wife ||
    HeirType.mother ||
    HeirType.maternalGrandmother ||
    HeirType.paternalGrandmother ||
    HeirType.greatMaternalGrandmother ||
    HeirType.paternalGreatGrandmotherFather ||
    HeirType.paternalGreatGrandmotherMother ||
    HeirType.daughter ||
    HeirType.granddaughter ||
    HeirType.greatGranddaughter ||
    HeirType.fullSister ||
    HeirType.paternalSister ||
    HeirType.maternalSister ||
    HeirType.paternalAunt ||
    HeirType.maternalAunt ||
    HeirType.nieceFull ||
    HeirType.niecePaternal ||
    HeirType.uncleDaughter =>
      false,
  };
}

/// Highest admissible number of this heir: one father, one husband, up to four
/// wives, and 99 for everyone who can genuinely be counted.
int heirMaxCount(HeirType t) {
  switch (t) {
    case HeirType.husband:
      return 1;
    case HeirType.wife:
      return 4;
    case HeirType.father:
    case HeirType.mother:
    case HeirType.grandfather:
    case HeirType.greatGrandfather:
    case HeirType.maternalGrandmother:
    case HeirType.paternalGrandmother:
    case HeirType.greatMaternalGrandmother:
    case HeirType.paternalGreatGrandmotherFather:
    case HeirType.paternalGreatGrandmotherMother:
      return 1;
    default:
      return 99;
  }
}

/// Input to the inheritance calculator.
class InheritanceInput {
  final double estate;
  final double funeralExpenses;
  final double debts;
  final double willAmount;
  final double willAmount2;
  final double willAmount3;
  final bool heirsConsentExceedThird;
  final bool applyMandatoryWill;
  final int orphanGrandsons;
  final int orphanGranddaughters;
  final Madhab madhab;
  final int husband;
  final int wife;
  final int mother;
  final int father;
  final int maternalGrandmother;
  final int paternalGrandmother;
  final int greatMaternalGrandmother;
  final int paternalGreatGrandmotherFather;
  final int paternalGreatGrandmotherMother;
  final int grandfather;
  final int greatGrandfather;
  final int daughter;
  final int son;
  final int granddaughter;
  final int grandson;
  final int greatGranddaughter;
  final int greatGrandson;
  final int fullSister;
  final int fullBrother;
  final int paternalSister;
  final int paternalBrother;
  final int maternalSister;
  final int maternalBrother;
  final int nephewPaternal;
  final int nephewFull;
  final int nephewSonPaternal;
  final int nephewSonFull;
  final int paternalUnclePaternal;
  final int paternalUncle;
  final int paternalUncleSonPaternal;
  final int paternalUncleSon;
  final int paternalUncleGrandsonPaternal;
  final int paternalUncleGrandson;
  final int fatherUnclePaternal;
  final int fatherUncleFull;
  final int fatherCousinPaternal;
  final int fatherCousinFull;
  final int paternalAunt;
  final int maternalUncle;
  final int maternalAunt;
  final int nieceFull;
  final int niecePaternal;
  final int nieceSon;
  final int uncleDaughter;

  const InheritanceInput({
    this.estate = 0,
    this.funeralExpenses = 0,
    this.debts = 0,
    this.willAmount = 0,
    this.willAmount2 = 0,
    this.willAmount3 = 0,
    this.heirsConsentExceedThird = false,
    this.applyMandatoryWill = false,
    this.orphanGrandsons = 0,
    this.orphanGranddaughters = 0,
    this.madhab = Madhab.jumhur,
    this.husband = 0,
    this.wife = 0,
    this.mother = 0,
    this.father = 0,
    this.maternalGrandmother = 0,
    this.paternalGrandmother = 0,
    this.greatMaternalGrandmother = 0,
    this.paternalGreatGrandmotherFather = 0,
    this.paternalGreatGrandmotherMother = 0,
    this.grandfather = 0,
    this.greatGrandfather = 0,
    this.daughter = 0,
    this.son = 0,
    this.granddaughter = 0,
    this.grandson = 0,
    this.greatGranddaughter = 0,
    this.greatGrandson = 0,
    this.fullSister = 0,
    this.fullBrother = 0,
    this.paternalSister = 0,
    this.paternalBrother = 0,
    this.maternalSister = 0,
    this.maternalBrother = 0,
    this.nephewPaternal = 0,
    this.nephewFull = 0,
    this.nephewSonPaternal = 0,
    this.nephewSonFull = 0,
    this.paternalUnclePaternal = 0,
    this.paternalUncle = 0,
    this.paternalUncleSonPaternal = 0,
    this.paternalUncleSon = 0,
    this.paternalUncleGrandsonPaternal = 0,
    this.paternalUncleGrandson = 0,
    this.fatherUnclePaternal = 0,
    this.fatherUncleFull = 0,
    this.fatherCousinPaternal = 0,
    this.fatherCousinFull = 0,
    this.paternalAunt = 0,
    this.maternalUncle = 0,
    this.maternalAunt = 0,
    this.nieceFull = 0,
    this.niecePaternal = 0,
    this.nieceSon = 0,
    this.uncleDaughter = 0,
  });

  /// The exact inverse of [countOf]: build an input from a heir→count map so
  /// every screen that collects counts (محاسبه، مناسخات) maps them the same
  /// way and a newly added HeirType cannot be forgotten in one of them.
  factory InheritanceInput.fromCounts(
    Map<HeirType, int> counts, {
    double estate = 0,
    Madhab madhab = Madhab.jumhur,
  }) {
    int c(HeirType t) => counts[t] ?? 0;
    return InheritanceInput(
      estate: estate,
      madhab: madhab,
      husband: c(HeirType.husband),
      wife: c(HeirType.wife),
      mother: c(HeirType.mother),
      father: c(HeirType.father),
      maternalGrandmother: c(HeirType.maternalGrandmother),
      paternalGrandmother: c(HeirType.paternalGrandmother),
      greatMaternalGrandmother: c(HeirType.greatMaternalGrandmother),
      paternalGreatGrandmotherFather:
          c(HeirType.paternalGreatGrandmotherFather),
      paternalGreatGrandmotherMother:
          c(HeirType.paternalGreatGrandmotherMother),
      grandfather: c(HeirType.grandfather),
      greatGrandfather: c(HeirType.greatGrandfather),
      daughter: c(HeirType.daughter),
      son: c(HeirType.son),
      granddaughter: c(HeirType.granddaughter),
      grandson: c(HeirType.grandson),
      greatGranddaughter: c(HeirType.greatGranddaughter),
      greatGrandson: c(HeirType.greatGrandson),
      fullSister: c(HeirType.fullSister),
      fullBrother: c(HeirType.fullBrother),
      paternalSister: c(HeirType.paternalSister),
      paternalBrother: c(HeirType.paternalBrother),
      maternalSister: c(HeirType.maternalSister),
      maternalBrother: c(HeirType.maternalBrother),
      nephewPaternal: c(HeirType.nephewPaternal),
      nephewFull: c(HeirType.nephewFull),
      nephewSonPaternal: c(HeirType.nephewSonPaternal),
      nephewSonFull: c(HeirType.nephewSonFull),
      paternalUnclePaternal: c(HeirType.paternalUnclePaternal),
      paternalUncle: c(HeirType.paternalUncle),
      paternalUncleSonPaternal: c(HeirType.paternalUncleSonPaternal),
      paternalUncleSon: c(HeirType.paternalUncleSon),
      paternalUncleGrandsonPaternal: c(HeirType.paternalUncleGrandsonPaternal),
      paternalUncleGrandson: c(HeirType.paternalUncleGrandson),
      fatherUnclePaternal: c(HeirType.fatherUnclePaternal),
      fatherUncleFull: c(HeirType.fatherUncleFull),
      fatherCousinPaternal: c(HeirType.fatherCousinPaternal),
      fatherCousinFull: c(HeirType.fatherCousinFull),
      paternalAunt: c(HeirType.paternalAunt),
      maternalUncle: c(HeirType.maternalUncle),
      maternalAunt: c(HeirType.maternalAunt),
      nieceFull: c(HeirType.nieceFull),
      niecePaternal: c(HeirType.niecePaternal),
      nieceSon: c(HeirType.nieceSon),
      uncleDaughter: c(HeirType.uncleDaughter),
    );
  }

  /// أبناء الابن المتوفى (أولاد الابن) الذين تشملهم الوصية الواجبة.
  bool get hasMandatoryWill =>
      applyMandatoryWill && (orphanGrandsons + orphanGranddaughters > 0);

  int countOf(HeirType t) {
    switch (t) {
      case HeirType.husband:
        return husband;
      case HeirType.wife:
        return wife;
      case HeirType.mother:
        return mother;
      case HeirType.father:
        return father;
      case HeirType.maternalGrandmother:
        return maternalGrandmother;
      case HeirType.paternalGrandmother:
        return paternalGrandmother;
      case HeirType.greatMaternalGrandmother:
        return greatMaternalGrandmother;
      case HeirType.paternalGreatGrandmotherFather:
        return paternalGreatGrandmotherFather;
      case HeirType.paternalGreatGrandmotherMother:
        return paternalGreatGrandmotherMother;
      case HeirType.grandfather:
        return grandfather;
      case HeirType.greatGrandfather:
        return greatGrandfather;
      case HeirType.daughter:
        return daughter;
      case HeirType.son:
        return son;
      case HeirType.granddaughter:
        return granddaughter;
      case HeirType.grandson:
        return grandson;
      case HeirType.greatGranddaughter:
        return greatGranddaughter;
      case HeirType.greatGrandson:
        return greatGrandson;
      case HeirType.fullSister:
        return fullSister;
      case HeirType.fullBrother:
        return fullBrother;
      case HeirType.paternalSister:
        return paternalSister;
      case HeirType.paternalBrother:
        return paternalBrother;
      case HeirType.maternalSister:
        return maternalSister;
      case HeirType.maternalBrother:
        return maternalBrother;
      case HeirType.nephewPaternal:
        return nephewPaternal;
      case HeirType.nephewFull:
        return nephewFull;
      case HeirType.nephewSonPaternal:
        return nephewSonPaternal;
      case HeirType.nephewSonFull:
        return nephewSonFull;
      case HeirType.paternalUnclePaternal:
        return paternalUnclePaternal;
      case HeirType.paternalUncle:
        return paternalUncle;
      case HeirType.paternalUncleSonPaternal:
        return paternalUncleSonPaternal;
      case HeirType.paternalUncleSon:
        return paternalUncleSon;
      case HeirType.paternalUncleGrandsonPaternal:
        return paternalUncleGrandsonPaternal;
      case HeirType.paternalUncleGrandson:
        return paternalUncleGrandson;
      case HeirType.fatherUnclePaternal:
        return fatherUnclePaternal;
      case HeirType.fatherUncleFull:
        return fatherUncleFull;
      case HeirType.fatherCousinPaternal:
        return fatherCousinPaternal;
      case HeirType.fatherCousinFull:
        return fatherCousinFull;
      case HeirType.paternalAunt:
        return paternalAunt;
      case HeirType.maternalUncle:
        return maternalUncle;
      case HeirType.maternalAunt:
        return maternalAunt;
      case HeirType.nieceFull:
        return nieceFull;
      case HeirType.niecePaternal:
        return niecePaternal;
      case HeirType.nieceSon:
        return nieceSon;
      case HeirType.uncleDaughter:
        return uncleDaughter;
    }
  }

  /// بازگشت یک نسخهٔ جدید با فقط فیلدهای داده‌شده تغییر کرده.
  InheritanceInput copyWith({
    double? estate,
    double? funeralExpenses,
    double? debts,
    double? willAmount,
    double? willAmount2,
    double? willAmount3,
    bool? heirsConsentExceedThird,
    bool? applyMandatoryWill,
    int? orphanGrandsons,
    int? orphanGranddaughters,
    Madhab? madhab,
    int? husband,
    int? wife,
    int? mother,
    int? father,
    int? maternalGrandmother,
    int? paternalGrandmother,
    int? greatMaternalGrandmother,
    int? paternalGreatGrandmotherFather,
    int? paternalGreatGrandmotherMother,
    int? grandfather,
    int? greatGrandfather,
    int? daughter,
    int? son,
    int? granddaughter,
    int? grandson,
    int? greatGranddaughter,
    int? greatGrandson,
    int? fullSister,
    int? fullBrother,
    int? paternalSister,
    int? paternalBrother,
    int? maternalSister,
    int? maternalBrother,
    int? nephewPaternal,
    int? nephewFull,
    int? nephewSonPaternal,
    int? nephewSonFull,
    int? paternalUnclePaternal,
    int? paternalUncle,
    int? paternalUncleSonPaternal,
    int? paternalUncleSon,
    int? paternalUncleGrandsonPaternal,
    int? paternalUncleGrandson,
    int? fatherUnclePaternal,
    int? fatherUncleFull,
    int? fatherCousinPaternal,
    int? fatherCousinFull,
    int? paternalAunt,
    int? maternalUncle,
    int? maternalAunt,
    int? nieceFull,
    int? niecePaternal,
    int? nieceSon,
    int? uncleDaughter,
  }) {
    return InheritanceInput(
      estate: estate ?? this.estate,
      funeralExpenses: funeralExpenses ?? this.funeralExpenses,
      debts: debts ?? this.debts,
      willAmount: willAmount ?? this.willAmount,
      willAmount2: willAmount2 ?? this.willAmount2,
      willAmount3: willAmount3 ?? this.willAmount3,
      heirsConsentExceedThird:
          heirsConsentExceedThird ?? this.heirsConsentExceedThird,
      applyMandatoryWill: applyMandatoryWill ?? this.applyMandatoryWill,
      orphanGrandsons: orphanGrandsons ?? this.orphanGrandsons,
      orphanGranddaughters: orphanGranddaughters ?? this.orphanGranddaughters,
      madhab: madhab ?? this.madhab,
      husband: husband ?? this.husband,
      wife: wife ?? this.wife,
      mother: mother ?? this.mother,
      father: father ?? this.father,
      maternalGrandmother: maternalGrandmother ?? this.maternalGrandmother,
      paternalGrandmother: paternalGrandmother ?? this.paternalGrandmother,
      greatMaternalGrandmother:
          greatMaternalGrandmother ?? this.greatMaternalGrandmother,
      paternalGreatGrandmotherFather:
          paternalGreatGrandmotherFather ?? this.paternalGreatGrandmotherFather,
      paternalGreatGrandmotherMother:
          paternalGreatGrandmotherMother ?? this.paternalGreatGrandmotherMother,
      grandfather: grandfather ?? this.grandfather,
      greatGrandfather: greatGrandfather ?? this.greatGrandfather,
      daughter: daughter ?? this.daughter,
      son: son ?? this.son,
      granddaughter: granddaughter ?? this.granddaughter,
      grandson: grandson ?? this.grandson,
      greatGranddaughter: greatGranddaughter ?? this.greatGranddaughter,
      greatGrandson: greatGrandson ?? this.greatGrandson,
      fullSister: fullSister ?? this.fullSister,
      fullBrother: fullBrother ?? this.fullBrother,
      paternalSister: paternalSister ?? this.paternalSister,
      paternalBrother: paternalBrother ?? this.paternalBrother,
      maternalSister: maternalSister ?? this.maternalSister,
      maternalBrother: maternalBrother ?? this.maternalBrother,
      nephewPaternal: nephewPaternal ?? this.nephewPaternal,
      nephewFull: nephewFull ?? this.nephewFull,
      nephewSonPaternal: nephewSonPaternal ?? this.nephewSonPaternal,
      nephewSonFull: nephewSonFull ?? this.nephewSonFull,
      paternalUnclePaternal:
          paternalUnclePaternal ?? this.paternalUnclePaternal,
      paternalUncle: paternalUncle ?? this.paternalUncle,
      paternalUncleSonPaternal:
          paternalUncleSonPaternal ?? this.paternalUncleSonPaternal,
      paternalUncleSon: paternalUncleSon ?? this.paternalUncleSon,
      paternalUncleGrandsonPaternal:
          paternalUncleGrandsonPaternal ?? this.paternalUncleGrandsonPaternal,
      paternalUncleGrandson:
          paternalUncleGrandson ?? this.paternalUncleGrandson,
      fatherUnclePaternal: fatherUnclePaternal ?? this.fatherUnclePaternal,
      fatherUncleFull: fatherUncleFull ?? this.fatherUncleFull,
      fatherCousinPaternal: fatherCousinPaternal ?? this.fatherCousinPaternal,
      fatherCousinFull: fatherCousinFull ?? this.fatherCousinFull,
      paternalAunt: paternalAunt ?? this.paternalAunt,
      maternalUncle: maternalUncle ?? this.maternalUncle,
      maternalAunt: maternalAunt ?? this.maternalAunt,
      nieceFull: nieceFull ?? this.nieceFull,
      niecePaternal: niecePaternal ?? this.niecePaternal,
      nieceSon: nieceSon ?? this.nieceSon,
      uncleDaughter: uncleDaughter ?? this.uncleDaughter,
    );
  }
}

/// A single heir's computed share.
class InheritanceShare {
  final HeirType type;
  final int count;
  final Frac fraction;
  final double amount;
  final ShareType shareType;
  final String reason;
  final String? hajbReason;

  const InheritanceShare({
    required this.type,
    required this.count,
    required this.fraction,
    required this.amount,
    required this.shareType,
    required this.reason,
    this.hajbReason,
  });

  bool get isAsaba => shareType == ShareType.asaba;
}

/// Result of an inheritance calculation.
class InheritanceResult {
  final double estate;
  final double netEstate;
  final Madhab madhab;
  final List<InheritanceShare> shares;
  final String
      method; // 'normal' | 'awl' | 'radd' | 'distantKindred' | 'baytMal'
  final List<String> warnings;
  final List<String> notes;
  final int baseAsl; // أصل المسألة قبل العول/الرد
  final int correctedAsl; // الأصل بعد التصحيح (العول/الرد)
  final double mandatoryWillAmount; // مقدار الوصية الواجبة المخصومة

  const InheritanceResult({
    required this.estate,
    required this.netEstate,
    required this.madhab,
    required this.shares,
    required this.method,
    this.warnings = const [],
    this.notes = const [],
    this.baseAsl = 0,
    this.correctedAsl = 0,
    this.mandatoryWillAmount = 0,
  });

  double get totalAllocated => shares.fold(0.0, (s, h) => s + h.amount);

  /// مقدار باقی‌مانده برای وارثان اصلی پس از کسر وصیت واجبه.
  /// [netEstate] همچنان قرارداد قدیمیِ «پس از هزینه، بدهی و وصیت عادی» را نگه می‌دارد.
  double get estateForMainHeirs => netEstate - mandatoryWillAmount;

  bool get awlApplied => method == 'awl';
  bool get raddApplied => method == 'radd';

  String get methodLabel {
    switch (method) {
      case 'awl':
        return 'عول (تنزیل سهم‌ها)';
      case 'radd':
        return 'رد (برگشت باقی‌مانده)';
      case 'distantKindred':
        return 'ذوی‌الأرحام (باقی‌مانده پس از فرض‌ها)';
      case 'baytMal':
        return 'باقی‌مانده به بیت‌المال';
      default:
        return 'تخصیص عادی';
    }
  }
}

/// A single stage in a مناسخات (munasakhat / multi-stage inheritance) case.
///
/// Represents one death event in a chain where an heir dies before the
/// estate is fully distributed. Each stage has its own input (the heirs
/// of the person who died at this stage) and the result of that stage's
/// distribution.
class MunasakhatStage {
  final String deceasedLabel; // e.g. "متوفی اول (پدر)"
  final InheritanceInput input;
  final InheritanceResult result;

  const MunasakhatStage({
    required this.deceasedLabel,
    required this.input,
    required this.result,
  });
}

/// A complete مناسخات (munasakhat) case — a chain of inheritance events.
///
/// Example: Person A dies, leaving son B and son C. Before distribution,
/// son C dies, leaving a daughter D. The estate is split: B takes 1/2,
/// then C's share (1/2) passes to D.
class MunasakhatCase {
  final String label;
  final List<MunasakhatStage> stages;

  /// Non-fatal issues encountered while chaining the stages — e.g. a stage
  /// whose linkage to the previous estate had to be approximated. Empty for a
  /// fully determined chain. Shown in the UI so estimates never pass silently.
  final List<String> warnings;

  const MunasakhatCase({
    required this.label,
    required this.stages,
    this.warnings = const [],
  });

  double get totalEstate => stages.isEmpty ? 0 : stages.first.result.estate;
}

/// Thrown when a stage cannot be linked to ONE specific share of the previous
/// stage. Previously such a stage silently split the previous estate equally
/// between all heirs, so a case could show numbers that were simply wrong with
/// no indication at all.
class MunasakhatLinkageException implements Exception {
  final int stageIndex;
  final String deceasedLabel;

  const MunasakhatLinkageException(this.stageIndex, this.deceasedLabel);

  @override
  String toString() =>
      'Stage ${stageIndex + 1} could not be linked to a single heir share. '
      'Name the relation in the deceased label or pass inheritedFromHeir '
      'explicitly.';
}

/// Solve a مناسخات (munasakhat / multi-stage inheritance) case.
///
/// [label] is a descriptive name for the case.
/// [stagesData] is a list of (deceasedLabel, input) pairs in chronological
/// order of death. Each stage's estate is that deceased person's share
/// inherited from the previous stage (or the original estate for stage 0).
///
/// Returns a [MunasakhatCase] with computed results for every stage.
MunasakhatCase calculateMunasakhat(
  String label,
  List<(String, InheritanceInput)> stagesData, {
  InheritanceResult Function(InheritanceInput)? calculator,

  /// The heir of the PREVIOUS stage who dies at each stage (element 0 is
  /// unused). A picker hands the engine a relationship, not a name to guess:
  /// it wins over label matching, so the chain contains no estimate at all.
  List<HeirType?>? inheritedFromHeir,

  /// When true, a stage whose linkage cannot be determined (no match, or an
  /// ambiguous multi-match) throws [MunasakhatLinkageException] instead of
  /// silently approximating the estate.
  bool strictLinkage = false,
}) {
  if (stagesData.isEmpty) {
    throw ArgumentError('مِنَاسَخَات requires at least one stage.');
  }

  final stages = <MunasakhatStage>[];
  final warnings = <String>[];
  double currentEstate = stagesData.first.$2.estate;

  for (int i = 0; i < stagesData.length; i++) {
    final (deceased, input) = stagesData[i];
    final stageInput = input.estate != currentEstate
        ? input.copyWith(estate: currentEstate)
        : input;

    final result = calculator != null
        ? calculator(stageInput)
        : calculateInheritance(stageInput);
    stages.add(MunasakhatStage(
      deceasedLabel: deceased,
      input: stageInput,
      result: result,
    ));

    // The next stage's estate is the share of this deceased person inherited by
    // the person who dies next. Resolution order:
    //   1. an explicit `inheritedFromHeir` (exact, no guessing),
    //   2. a UNIQUE label match against this stage's heirs,
    //   3. otherwise: refuse (strict) or approximate with a LOUD warning.
    if (i + 1 < stagesData.length) {
      final nextDeceasedLabel = stagesData[i + 1].$1;
      final heir = (inheritedFromHeir != null &&
              i + 1 < inheritedFromHeir.length)
          ? inheritedFromHeir[i + 1]
          : null;
      final matching = heir != null
          ? result.shares.where((s) => s.type == heir).toList()
          : result.shares
              .where((s) => _matchesLabel(s.type, nextDeceasedLabel))
              .toList();
      if (matching.length == 1) {
        // ONE person dies at the next stage, so a type counted several times
        // (two sons, four wives) passes only its per-head part: shares of the
        // same heir type are always equal — furūḍ split their fixed share per
        // head and ʿaṣāba divides within the type at a fixed ratio.
        final share = matching.first;
        currentEstate =
            share.count <= 1 ? share.amount : share.amount / share.count;
      } else {
        if (strictLinkage) {
          throw MunasakhatLinkageException(i + 1, nextDeceasedLabel);
        }
        warnings.add(
            'پیوند مرحله ${i + 2} روشن نبود؛ ترکه به‌طور مساوی میان ورثهٔ این '
            'مرحله تخمین زده شد. به این عدد عمل نکنید.');
        currentEstate = result.shares.isEmpty
            ? 0
            : result.totalAllocated / result.shares.length;
      }
    }
  }

  return MunasakhatCase(label: label, stages: stages, warnings: warnings);
}

bool _matchesLabel(HeirType type, String label) {
  // Try to match labels like "پسر", "دختر", "همسر", etc.
  final typeLabel = heirLabel(type);
  if (typeLabel == label) return true;
  // "پسر (متوفی دوم)" → "پسر"
  if (label.startsWith(typeLabel)) return true;
  // "متوفی دوم (پسر)" → relation inside parentheses
  final m = RegExp(r'\((.+)\)$').firstMatch(label.trim());
  final rel = m?.group(1)?.trim();
  if (rel != null && rel.isNotEmpty) {
    if (rel == typeLabel || rel.startsWith(typeLabel)) return true;
  }
  return false;
}

/// Compute the Islamic inheritance (farāʾiḍ) distribution.
///
/// Based on the general Sunni rules (الجمهور) as implemented on
/// almwareeth.com. Handles the fixed shares (furūḍ), residuaries
/// (ʿaṣabāt), proportional reduction (ʿawl) when the fixed shares
/// exceed the estate, and return (radd) of a remainder when no
/// residuary exists.
InheritanceResult calculateInheritance(InheritanceInput input) {
  return getCalculator(input.madhab).calculate(input);
}

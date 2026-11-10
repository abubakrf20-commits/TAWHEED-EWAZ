import 'inheritance_calculator.dart';
import 'madhab_calculator.dart';
import 'madhab_rules.dart';

/// یک وارثِ واردشده که در تقسیم نهایی محجوب (حجب حرمان) شد و ارث نمی‌برد.
class BlockedHeir {
  final HeirType type;
  final int count;
  final String reason;

  const BlockedHeir({
    required this.type,
    required this.count,
    required this.reason,
  });
}

/// تجزیه و تحلیل وارثان محجوب:
///
/// برای هر وارثی که در ورودی حضور دارد اما در سهم‌های نهایی محاسبه ظاهر
/// نشده است، یک [BlockedHeir] با دلیل (حسب قواعد الحجب في المذهب) برمی‌گرداند.
/// اگر [result] داده نشود، محاسبهٔ خودکار انجام می‌شود.
List<BlockedHeir> analyzeBlockedHeirs(
  InheritanceInput input, {
  InheritanceResult? result,
}) {
  final r = result ?? getCalculator(input.madhab).calculate(input);
  final inherited = <HeirType>{for (final s in r.shares) s.type};

  final blocked = <BlockedHeir>[];
  for (final t in HeirType.values) {
    final count = input.countOf(t);
    if (count <= 0) continue;
    if (inherited.contains(t)) continue;
    final reason = _blockReason(t, input, input.madhab);
    if (reason == null) continue;
    blocked.add(BlockedHeir(type: t, count: count, reason: reason));
  }
  return blocked;
}

/// آیا ترکه به بیت‌المال تعلق می‌گیرد (هیچ وارثی نیست)؟
bool estateGoesToBaytAlMal(InheritanceInput input) {
  final result = getCalculator(input.madhab).calculate(input);
  return result.shares.isEmpty;
}

/// فرزند پسر و نسل پسر (فرع وارث مذکر).
bool _maleLine(InheritanceInput i) =>
    i.son > 0 || i.grandson > 0 || i.greatGrandson > 0;

/// فرع وارث (هر نسل وارث).
bool _far3(InheritanceInput i) =>
    _maleLine(i) ||
    i.daughter > 0 ||
    i.granddaughter > 0 ||
    i.greatGranddaughter > 0;

bool _anyFullSibling(InheritanceInput i) =>
    i.fullBrother > 0 || i.fullSister > 0;

/// ترتیب قرب جدّات (الأقرب يحجب الأبعد).
const List<HeirType> _grandmothersByProximity = [
  HeirType.maternalGrandmother,
  HeirType.paternalGrandmother,
  HeirType.greatMaternalGrandmother,
  HeirType.paternalGreatGrandmotherFather,
  HeirType.paternalGreatGrandmotherMother,
];

int _indexOf(HeirType t) => _grandmothersByProximity.indexOf(t);

/// دليل الحجب لكل وارث حسب القواعد المعروفة وحسب المذهب.
String? _blockReason(HeirType t, InheritanceInput i, Madhab madhab) {
  final m = MadhabRules.baseMadhab(madhab);
  final shafiiOrMaliki = m == Madhab.shafii || m == Madhab.maliki;
  final gfHajbsBrothers =
      MadhabRules.grandfatherHajbsBrothers(madhab) || m == Madhab.hanafi;

  switch (t) {
    // ── الزوجان ──
    case HeirType.husband:
    case HeirType.wife:
      return null;

    // ── الأصول: الأب والجدود ──
    case HeirType.mother:
      return null;
    case HeirType.father:
      return null;
    case HeirType.grandfather:
      if (i.father > 0) {
        return 'به دلیل وجود پدر محجوب شد و ارث نمی‌برد.';
      }
      return null;
    case HeirType.greatGrandfather:
      if (i.father > 0 || i.grandfather > 0) {
        return 'به دلیل وجود پدر/پدربزرگ محجوب شد و ارث نمی‌برد.';
      }
      return null;
    case HeirType.maternalGrandmother:
    case HeirType.paternalGrandmother:
    case HeirType.greatMaternalGrandmother:
    case HeirType.paternalGreatGrandmotherFather:
    case HeirType.paternalGreatGrandmotherMother:
      if (i.mother > 0) {
        return 'به دلیل وجود مادر محجوب شد و ارث نمی‌برد.';
      }
      // الجدّة الأقرب تحجب الأبعد.
      final idx = _indexOf(t);
      for (int j = 0; j < idx; j++) {
        final nearer = _grandmothersByProximity[j];
        if (i.countOf(nearer) > 0) {
          return 'به دلیل وجود جدّهٔ نزدیک‌تر (${heirLabel(nearer)}) محجوب شد و ارث نمی‌برد.';
        }
      }
      // الشافعية والمالكية: أم الأب تحجب البعيدة من جهة الأب فقط.
      if (shafiiOrMaliki) {
        if (t == HeirType.paternalGreatGrandmotherFather ||
            t == HeirType.paternalGreatGrandmotherMother) {
          if (i.paternalGrandmother > 0) {
            return 'به دلیل وجود مادربزرگِ پدری (مادرِ پدر) محجوب شد و ارث نمی‌برد.';
          }
        }
      }
      return null;

    // ── الفرع الوارث ──
    case HeirType.son:
      return null;
    case HeirType.grandson:
      if (i.son > 0) {
        return 'به دلیل وجود پسر محجوب شد و ارث نمی‌برد.';
      }
      return null;
    case HeirType.greatGrandson:
      if (i.son > 0 || i.grandson > 0) {
        return 'به دلیل وجود پسر/پسرِ پسر محجوب شد و ارث نمی‌برد.';
      }
      return null;
    case HeirType.daughter:
    case HeirType.granddaughter:
    case HeirType.greatGranddaughter:
      return null;

    // ── الإخوة ──
    case HeirType.fullBrother:
      if (_maleLine(i) || i.father > 0) {
        return 'به دلیل وجود فرزند پسر (یا پدر) محجوب شد و ارث نمی‌برد.';
      }
      return null;
    case HeirType.fullSister:
      if (_maleLine(i) || i.father > 0) {
        return 'به دلیل وجود فرزند پسر (یا پدر) محجوب شد و ارث نمی‌برد.';
      }
      // الجد يحجب الشقيقة في الحنفي (وفي نظام السعودية).
      if (gfHajbsBrothers && i.grandfather > 0) {
        return 'به دلیل وجود پدربزرگ (که در این مذهب/قانون جای پدر را می‌گیرد) محجوب شد و ارث نمی‌برد.';
      }
      return null;
    case HeirType.paternalBrother:
      if (_maleLine(i) || i.father > 0) {
        return 'به دلیل وجود فرزند پسر (یا پدر) محجوب شد و ارث نمی‌برد.';
      }
      if (i.fullBrother > 0) {
        return 'به دلیل وجود برادر (پدری و مادری) محجوب شد و ارث نمی‌برد.';
      }
      return null;
    case HeirType.paternalSister:
      if (_maleLine(i) || i.father > 0) {
        return 'به دلیل وجود فرزند پسر (یا پدر) محجوب شد و ارث نمی‌برد.';
      }
      // أختان شقيقتان تحجبان الأخت لأب (تكملة الثلثين)؛
      // وأخت شقيقة واحدة تجعلها تأخذ السدس فلا تُحجب.
      if (i.fullSister >= 2) {
        return 'به دلیل وجود دو خواهر (پدری و مادری) محجوب شد و ارث نمی‌برد.';
      }
      if (i.fullBrother > 0) {
        return 'به دلیل وجود برادر (پدری و مادری) محجوب شد و ارث نمی‌برد.';
      }
      return null;
    case HeirType.maternalBrother:
    case HeirType.maternalSister:
      if (_far3(i) || i.father > 0 || i.grandfather > 0) {
        return 'به دلیل وجود فرزند، پدر یا پدربزرگ محجوب شد و ارث نمی‌برد.';
      }
      return null;

    // ── بنو الإخوة (أبناء الإخوة) ──
    case HeirType.nephewFull:
      if (_maleLine(i) ||
          i.father > 0 ||
          i.grandfather > 0 ||
          _anyFullSibling(i)) {
        return 'به دلیل وجود فرزند پسر، پدر/پدربزرگ یا برادر محجوب شد و ارث نمی‌برد.';
      }
      return null;
    case HeirType.nephewPaternal:
      if (_maleLine(i) ||
          i.father > 0 ||
          i.grandfather > 0 ||
          _anyFullSibling(i) ||
          i.paternalBrother > 0) {
        return 'به دلیل وجود فرزند پسر، پدر/پدربزرگ یا برادر محجوب شد و ارث نمی‌برد.';
      }
      return null;
    case HeirType.nephewSonFull:
      if (_maleLine(i) ||
          i.father > 0 ||
          i.grandfather > 0 ||
          _anyFullSibling(i) ||
          i.nephewFull > 0) {
        return 'به دلیل وجود وارث نزدیک‌تر (فرزند پسر/پدر/برادر/پسرِ برادر) محجوب شد و ارث نمی‌برد.';
      }
      return null;
    case HeirType.nephewSonPaternal:
      if (_maleLine(i) ||
          i.father > 0 ||
          i.grandfather > 0 ||
          _anyFullSibling(i) ||
          i.paternalBrother > 0 ||
          i.nephewPaternal > 0) {
        return 'به دلیل وجود وارث نزدیک‌تر (فرزند پسر/پدر/برادر/پسرِ برادر) محجوب شد و ارث نمی‌برد.';
      }
      return null;

    // ── العمومة ──
    case HeirType.paternalUncle:
      if (_maleLine(i) ||
          i.father > 0 ||
          i.grandfather > 0 ||
          _anyFullSibling(i) ||
          i.paternalBrother > 0 ||
          i.nephewFull > 0 ||
          i.nephewPaternal > 0) {
        return 'به دلیل وجود وارث نزدیک‌تر (فرزند/پدر/برادر/پسرِ برادر) محجوب شد و ارث نمی‌برد.';
      }
      return null;
    case HeirType.paternalUnclePaternal:
      if (_maleLine(i) ||
          i.father > 0 ||
          i.grandfather > 0 ||
          _anyFullSibling(i) ||
          i.paternalBrother > 0 ||
          i.nephewFull > 0 ||
          i.nephewPaternal > 0 ||
          i.paternalUncle > 0) {
        return 'به دلیل وجود وارث نزدیک‌تر (از جمله عمو) محجوب شد و ارث نمی‌برد.';
      }
      return null;
    case HeirType.paternalUncleSon:
      if (_maleLine(i) ||
          i.father > 0 ||
          i.grandfather > 0 ||
          _anyFullSibling(i) ||
          i.paternalBrother > 0 ||
          i.nephewFull > 0 ||
          i.nephewPaternal > 0 ||
          i.paternalUncle > 0 ||
          i.paternalUnclePaternal > 0) {
        return 'به دلیل وجود وارث نزدیک‌تر (عمو یا پسرِ برادر) محجوب شد و ارث نمی‌برد.';
      }
      return null;
    case HeirType.paternalUncleSonPaternal:
      if (_maleLine(i) ||
          i.father > 0 ||
          i.grandfather > 0 ||
          _anyFullSibling(i) ||
          i.paternalBrother > 0 ||
          i.nephewFull > 0 ||
          i.nephewPaternal > 0 ||
          i.paternalUncle > 0 ||
          i.paternalUnclePaternal > 0 ||
          i.paternalUncleSon > 0) {
        return 'به دلیل وجود وارث نزدیک‌تر محجوب شد و ارث نمی‌برد.';
      }
      return null;
    case HeirType.paternalUncleGrandson:
    case HeirType.paternalUncleGrandsonPaternal:
    case HeirType.fatherUncleFull:
    case HeirType.fatherUnclePaternal:
    case HeirType.fatherCousinFull:
    case HeirType.fatherCousinPaternal:
      return 'به دلیل وجود وارث نزدیک‌تر از طبقهٔ بالاتر محجوب شد و ارث نمی‌برد.';

    // ── ذوو الأرحام ──
    case HeirType.paternalAunt:
    case HeirType.maternalUncle:
    case HeirType.maternalAunt:
    case HeirType.nieceFull:
    case HeirType.niecePaternal:
    case HeirType.nieceSon:
    case HeirType.uncleDaughter:
      // ذوو الأرحام يرثون الباقي بعد الفروض عند نفي العصبة في القوانين التي
      // تجيزهم؛ فإذن يُحجب من كان مع وجود عاصب أو خويشاوند دور أقرب، أو في
      // القانونين المالكيين (الباقي لبيت المال).
      return 'از خویشاوندان دور (ذوی‌الأرحام) است و به دلیل وجود وارثِ نزدیک‌تر (عصبه یا خویشاوند دورِ نزدیک‌تر) یا قانونی که برایش ارثی قائل نیست، ارث نمی‌برد.';
  }
}

import 'inheritance_calculator.dart';
import 'madhab_rules.dart';

/// واجهة المحرك الحسابي لكل مذهب.
abstract class MadhabCalculator {
  Madhab get madhab;
  InheritanceResult calculate(InheritanceInput input);

  /// The heirs [calculate] would exclude (محجوب) for [input], computed with
  /// exactly the same حجب engine. Kept as a separate entry so the UI can
  /// live-preview blocked heirs (e.g. red icon) without touching the actual
  /// share calculation.
  Set<HeirType> blockedHeirs(InheritanceInput input);
}

/// ترتيب العُصبة الأدنى بالنفس: من ابن الأخ إلى ابن عم الأب.
const List<HeirType> _lowerAsabaOrder = [
  HeirType.greatGrandfather,
  HeirType.nephewFull,
  HeirType.nephewPaternal,
  HeirType.nephewSonFull,
  HeirType.nephewSonPaternal,
  HeirType.paternalUncle,
  HeirType.paternalUnclePaternal,
  HeirType.paternalUncleSon,
  HeirType.paternalUncleSonPaternal,
  HeirType.paternalUncleGrandson,
  HeirType.paternalUncleGrandsonPaternal,
  HeirType.fatherUncleFull,
  HeirType.fatherUnclePaternal,
  HeirType.fatherCousinFull,
  HeirType.fatherCousinPaternal,
];

/// أنواع الجدّات الخمس.
const List<HeirType> _grandmotherTypes = [
  HeirType.maternalGrandmother,
  HeirType.paternalGrandmother,
  HeirType.greatMaternalGrandmother,
  HeirType.paternalGreatGrandmotherFather,
  HeirType.paternalGreatGrandmotherMother,
];

/// ترتيب ذوي الأرحام (الأقرب أولًا): أحفاد البنات ← أصول الأم ← جدّات الأب ←
/// بنات الإخوة ← أعمام الأم/خالاتها ← بنات الأعمام.
const List<HeirType> _distantKindredOrder = [
  HeirType.nieceSon,
  HeirType.nieceFull,
  HeirType.niecePaternal,
  HeirType.maternalUncle,
  HeirType.maternalAunt,
  HeirType.paternalAunt,
  HeirType.uncleDaughter,
];

/// محرك الحساب المشترك بين جميع المذاهب.
///
/// يوفر المنطق الأساسي المتفق عليه (الجمهور) كما في almwareeth.com،
/// ويستدعي القواعد الخاصة بكل مذهب عبر [MadhabRules].
class _BaseCalculator implements MadhabCalculator {
  @override
  final Madhab madhab;

  _BaseCalculator(this.madhab);

  /// هل تُورّث ذوو الأرحام في هذا القانون؟ القانونان المالكیان (المغرب/تونس
  /// 1956) يوليان الباقي لبيت المال عند فقد العصبة، فلا يرث فيهما ذوو الأرحام.
  bool get _arhamAllowed =>
      madhab != Madhab.moroccan && madhab != Madhab.tunisia1956;

  /// أقرب ذي رحم حاضر حسب الترتيب الكلاسيكي، أو null إذا لم يوجد.
  HeirType? _closestArham(InheritanceInput input) {
    for (final t in _distantKindredOrder) {
      if (input.countOf(t) > 0) return t;
    }
    return null;
  }

  /// هل مع [input] (بعد الحجب) عَصبهٌ يأخذ الباقي؟ (تُستعمل في [blockedHeirs]
  /// لتحديد ما إذا كان ذوو الأرحام يرثون الباقي أم يُحجبون.)
  bool _anyAsabaPotential(InheritanceInput input, Set<HeirType> excluded) {
    const byNature = <HeirType>{
      HeirType.son,
      HeirType.grandson,
      HeirType.greatGrandson,
      HeirType.father,
      HeirType.grandfather,
      HeirType.greatGrandfather,
      HeirType.fullBrother,
      HeirType.paternalBrother,
      HeirType.nephewFull,
      HeirType.nephewPaternal,
      HeirType.nephewSonFull,
      HeirType.nephewSonPaternal,
      HeirType.paternalUncle,
      HeirType.paternalUnclePaternal,
      HeirType.paternalUncleSon,
      HeirType.paternalUncleSonPaternal,
      HeirType.paternalUncleGrandson,
      HeirType.paternalUncleGrandsonPaternal,
      HeirType.fatherUncleFull,
      HeirType.fatherUnclePaternal,
      HeirType.fatherCousinFull,
      HeirType.fatherCousinPaternal,
    };
    for (final t in byNature) {
      if (input.countOf(t) > 0 && !excluded.contains(t)) return true;
    }
    // عصبة مع الغير: أخت شقيقة (أو لأب) مع فرع وارث أنثى تصير عاصبة.
    final femaleFar3 =
        (input.daughter > 0 && !excluded.contains(HeirType.daughter)) ||
            (input.granddaughter > 0 &&
                !excluded.contains(HeirType.granddaughter)) ||
            (input.greatGranddaughter > 0 &&
                !excluded.contains(HeirType.greatGranddaughter));
    if (femaleFar3) {
      if (input.fullSister > 0 && !excluded.contains(HeirType.fullSister)) {
        return true;
      }
      if (input.fullSister == 0 &&
          input.paternalSister > 0 &&
          !excluded.contains(HeirType.paternalSister)) {
        return true;
      }
    }
    // الأكدرية: زوج/زوجة + أم + جد + أخت واحدة → الأخت عاصبة.
    final hasFar3Warith = input.son > 0 ||
        input.daughter > 0 ||
        input.grandson > 0 ||
        input.granddaughter > 0 ||
        input.greatGrandson > 0 ||
        input.greatGranddaughter > 0;
    if (_akderiaSisterType(input, hasFar3Warith) != null) return true;
    return false;
  }

  @override
  InheritanceResult calculate(InheritanceInput input) {
    // Guard the money math at the single engine entry: a negative or
    // infinite amount used to flow silently into the share fractions.
    void check(String field, double v) {
      if (!v.isFinite) {
        throw ArgumentError('مقدار $field باید عددی متناهی باشد');
      }
      if (v < 0) {
        throw ArgumentError('مقدار $field نمی‌تواند منفی باشد');
      }
    }

    check('ترکه', input.estate);
    check('هزینه کفن و دفن', input.funeralExpenses);
    check('بدهی', input.debts);
    check('وصیت', input.willAmount);
    check('وصیت دوم', input.willAmount2);
    check('وصیت سوم', input.willAmount3);

    // 1. تحديد التركة الصافية
    // الوصايا قد تكون عدة (وصية/ثانية/ثالثة). مجموعها لا يتجاوز الثلث
    // ما لم يوافق الورثة على أكثر من الثلث (عندئذٍ حدها التركة كلها).
    final totalWill = input.willAmount + input.willAmount2 + input.willAmount3;
    // الوصية لا تنفذ إلا من ثلث ما بقي بعد مؤنة التجهيز والديون (كما في
    // almwareeth.com): الأساس هو التركة بعد خصم المصاريف والديون.
    final willBase = (input.estate - input.funeralExpenses - input.debts) > 0
        ? input.estate - input.funeralExpenses - input.debts
        : 0.0;
    final maxWill = input.heirsConsentExceedThird ? willBase : willBase / 3;
    final actualWill = totalWill > maxWill ? maxWill : totalWill;
    final netEstate =
        input.estate - input.funeralExpenses - input.debts - actualWill;

    final warnings = <String>[];
    if (totalWill > maxWill) {
      warnings.add(
          'وصیت‌ها (${totalWill.toInt()}) از یک‌سوم بیشتر بود و به ${actualWill.toInt()} (حداکثر مجاز) تعدیل شد.');
    }

    var estate = netEstate > 0 ? netEstate : 0.0;

    if (netEstate < 0) {
      warnings.add(
          'کل ترکه (${input.estate.toInt()}) پس از کسر هزینه‌ها، دیون و وصیت کافی نیست '
          '(باقیمانده ${netEstate.toInt()}). مبالغ سهمیه‌ها صفر محاسبه شده است.');
    } else if (netEstate == 0) {
      warnings.add(
          'پس از کسر هزینه‌ها، دیون و وصیت، چیزی از ترکه باقی نمانده است.');
    }

    // 2. تحديد الورثة الأحياء
    final hasSon = input.son > 0;
    final hasDaughter = input.daughter > 0;
    final hasGrandson = input.grandson > 0;
    final hasGranddaughter = input.granddaughter > 0;
    final hasGreatGrandson = input.greatGrandson > 0;
    final hasGreatGranddaughter = input.greatGranddaughter > 0;
    // فرع وارث: أي نسل وارث (ابن، بنت، ابن الابن، بنت الابن، ابن ابن الابن،
    // بنت ابن الابن) يقلّص حصة الزوج والزوجة والأم والأب.
    final hasFar3Warith = hasSon ||
        hasDaughter ||
        hasGrandson ||
        hasGranddaughter ||
        hasGreatGrandson ||
        hasGreatGranddaughter;

    final siblingCount = input.fullBrother +
        input.fullSister +
        input.paternalBrother +
        input.paternalSister +
        input.maternalBrother +
        input.maternalSister;
    final anySibling = siblingCount > 0;
    final hasFullSiblings = input.fullBrother + input.fullSister > 0 ||
        input.paternalBrother + input.paternalSister > 0;

    // حجب الإخوة والأعمام: ابن أو ابن ابن أو أب أو جد
    final maleLineBlocker = hasSon ||
        hasGrandson ||
        hasGreatGrandson ||
        input.father > 0 ||
        input.grandfather > 0;

    final grandfatherHajbsSiblings =
        input.grandfather > 0 && MadhabRules.grandfatherHajbsBrothers(madhab);

    // الغراوين (العمريتان): زوج/زوجة + أم بلا فرع وارث — مع الأب، أو بلا أب
    // ومع إخوة أشقاء/لأب اثنين فأكثر (الأم تأخذ ثلث الباقي بعد الزوج).
    final isGharrawain = _isGharrawain(input, hasFar3Warith);
    // أقوال المذاهب في الغراوين متلازمة، فلا يجوز خلطها:
    //  • قول عمر (جمهور/حنفي/شافعي، وقانوناهم): الأم ثلث الباقي بعد الزوج،
    //    والأب يأخذ الباقي تعصيبًا — والإخوة محجوبون بالأب فلا يرثون شيئًا.
    //  • قول علي وزيد (مالكي/حنبلي والجزائري والسعودي): الأم ثلث الأصل،
    //    والباقي بين الأب والإخوة مقاسمة (الأب كأحد الإخوة: للذكر سهمان).
    // لذلك تُطبَّق المقاسمة فقط حيث تأخذ الأم ثلث الأصل.
    final gharrawainMuqasamah = _gharrawainMuqasamah(input, hasFar3Warith);

    // المسألة الأكدريه: زوج/زوجة + أم + جد + أخت واحدة، بلا أب ولا فرع وارث
    // ولا غيرها من الإخوة.
    final akderiaSisterType = _akderiaSisterType(input, hasFar3Warith);
    final isAkderia = akderiaSisterType != null;

    // المسألة شبه المالكية: زوج + أم + جد + أخ شقيق/لأب + إخوة لأم (اثنان
    // فأكثر)، بلا أب ولا فرع وارث. الثلث الباقي بعد الزوج والأم كان سيأخذه
    // أولاد الأم، لكن الجد يحجبهم فيسقط الأخ الشقيق أيضًا (لأنه لم يكن ليرث
    // إلا بالمشتركة معهم) ويأخذ الجد الباقي كله. (حكم الجمهور والمالكية)
    final isShabihMaliki = !isAkderia &&
        !MadhabRules.grandfatherHajbsBrothers(madhab) &&
        (MadhabRules.baseMadhab(madhab) == Madhab.jumhur ||
            MadhabRules.baseMadhab(madhab) == Madhab.maliki) &&
        input.husband > 0 &&
        input.mother > 0 &&
        input.grandfather > 0 &&
        input.father == 0 &&
        !hasFar3Warith &&
        (input.fullBrother > 0 || input.paternalBrother > 0) &&
        (input.maternalBrother + input.maternalSister) >= 2 &&
        input.fullSister == 0 &&
        input.paternalSister == 0;

    // 3. الحجب
    final excluded = _applyHajb(
      input,
      hasSon: hasSon,
      hasGrandson: hasGrandson,
      hasGreatGrandson: hasGreatGrandson,
      grandfatherHajbsSiblings: grandfatherHajbsSiblings,
      siblingsShareWithFather: gharrawainMuqasamah,
    );

    final granddaughterSurvives =
        input.granddaughter > 0 && !excluded.contains(HeirType.granddaughter);
    final greatGranddaughterSurvives = input.greatGranddaughter > 0 &&
        !excluded.contains(HeirType.greatGranddaughter);
    final femaleFar3Present = input.daughter > 0 ||
        granddaughterSurvives ||
        greatGranddaughterSurvives;

    // 4. توزيع الفروض
    final frads = <HeirType, Frac>{};
    final counts = <HeirType, int>{};

    // ذوو الأرحام: يُحسب أقربهم مرّة واحدة لاستعماله في باقي المسار.
    final arhamAllowed = _arhamAllowed;
    final closestArham = _closestArham(input);

    void addFard(HeirType t, Frac f, int c) {
      if (c <= 0 || f.isZero || excluded.contains(t)) return;
      frads[t] = (frads[t] ?? Frac.zero) + f;
      counts[t] = c;
    }

    // الزوج
    if (input.husband > 0 && !excluded.contains(HeirType.husband)) {
      addFard(HeirType.husband, MadhabRules.husbandShare(hasFar3Warith),
          input.husband);
    }
    // الزوجة (الزوجات)
    if (input.wife > 0 && !excluded.contains(HeirType.wife)) {
      addFard(HeirType.wife, MadhabRules.wifeShare(hasFar3Warith), input.wife);
    }
    // الأم
    if (input.mother > 0 && !excluded.contains(HeirType.mother)) {
      if (isGharrawain) {
        // الغراوان: زوج/زوجة + أم + أب → الأم ثلث الباقي بعد الزوج
        // (قول عمر: جمهور/حنفي/شافعي دائمًا)، أو ثلث الأصل مع مشاركة
        // الإخوة للأب (قول علي وزيد: مالكي/حنبلي والجزائري/السعودي).
        final spouseFrac = input.husband > 0
            ? MadhabRules.husbandShare(false)
            : MadhabRules.wifeShare(false);
        final remainderAfterSpouse = Frac.one - spouseFrac;
        addFard(
            HeirType.mother,
            gharrawainMuqasamah
                ? Frac(1, 3)
                : remainderAfterSpouse / Frac(3, 1),
            input.mother);
      } else {
        addFard(
            HeirType.mother,
            MadhabRules.motherShare(hasFar3Warith, siblingCount, madhab),
            input.mother);
      }
    }
    // الأب (فرض فقط مع فرع وارث)
    if (input.father > 0 &&
        hasFar3Warith &&
        !excluded.contains(HeirType.father)) {
      addFard(HeirType.father, MadhabRules.fatherShare(hasFar3Warith),
          input.father);
    }
    // الجدّات: السدس يقسم بين الجدّات الناجيات بالتساوي.
    final survivingGrandmothers = [
      for (final t in _grandmotherTypes)
        if (input.countOf(t) > 0 && !excluded.contains(t)) t,
    ];
    if (survivingGrandmothers.isNotEmpty) {
      final each = Frac(1, 6) / Frac(survivingGrandmothers.length, 1);
      for (final t in survivingGrandmothers) {
        addFard(t, each, 1);
      }
    }
    // الجد: فرض 1/6 مع فرع وارث، وإلا عصبة/مقاسمة لاحقًا.
    if (input.grandfather > 0 &&
        input.father == 0 &&
        !excluded.contains(HeirType.grandfather)) {
      if (hasFar3Warith) {
        addFard(HeirType.grandfather, Frac(1, 6), input.grandfather);
      }
    }
    // البنت (فرض بدون ابن)
    if (input.daughter > 0 &&
        !hasSon &&
        !excluded.contains(HeirType.daughter)) {
      addFard(HeirType.daughter,
          MadhabRules.daughterShare(input.daughter, false), input.daughter);
    }
    // بنت الابن — فرض، أو عصبة بالغير مع ابن الابن.
    if (input.granddaughter > 0 &&
        !hasGrandson &&
        !excluded.contains(HeirType.granddaughter)) {
      if (input.daughter == 0) {
        addFard(
            HeirType.granddaughter,
            input.granddaughter == 1 ? Frac(1, 2) : Frac(2, 3),
            input.granddaughter);
      } else if (input.daughter == 1) {
        // بنت واحدة (1/2) + بنت الابن (1/6) = 2/3
        addFard(HeirType.granddaughter, Frac(1, 6), input.granddaughter);
      }
    }
    // بنت ابن الابن — فرض، أو عصبة بالغير مع ابن ابن الابن.
    if (input.greatGranddaughter > 0 &&
        !hasGreatGrandson &&
        !excluded.contains(HeirType.greatGranddaughter)) {
      if (input.daughter == 0 && input.granddaughter == 0) {
        addFard(
            HeirType.greatGranddaughter,
            input.greatGranddaughter == 1 ? Frac(1, 2) : Frac(2, 3),
            input.greatGranddaughter);
      } else if ((input.daughter == 1 && input.granddaughter == 0) ||
          (input.daughter == 0 && input.granddaughter == 1)) {
        // تكملة الثلثين: فرض أعلى 1/2 + بنت ابن الابن 1/6
        addFard(
            HeirType.greatGranddaughter, Frac(1, 6), input.greatGranddaughter);
      }
    }
    // الأخت الشقيقة: فرض عندما لا أب ولا جد ولا فرع ولا أخ شقيق ولا بنت.
    final sisterFardAllowed = input.father == 0 &&
        input.grandfather == 0 &&
        !hasSon &&
        !hasGrandson &&
        !hasGreatGrandson &&
        !femaleFar3Present &&
        input.fullBrother == 0;
    if (sisterFardAllowed &&
        input.fullSister > 0 &&
        !excluded.contains(HeirType.fullSister)) {
      addFard(HeirType.fullSister,
          MadhabRules.fullSisterShare(input.fullSister), input.fullSister);
    }
    // الأخت لأب
    if (sisterFardAllowed &&
        input.paternalSister > 0 &&
        input.paternalBrother == 0 &&
        !excluded.contains(HeirType.paternalSister)) {
      addFard(
          HeirType.paternalSister,
          MadhabRules.paternalSisterShare(
              input.paternalSister, input.fullSister, madhab),
          input.paternalSister);
    }
    // الإخوة لأم (كلالة) — يحجبهم الأب والجد وأي فرع وارث.
    if (!excluded.contains(HeirType.maternalBrother) &&
        !excluded.contains(HeirType.maternalSister)) {
      final c = input.maternalBrother + input.maternalSister;
      if (c > 0) {
        final total = MadhabRules.maternalSiblingShare(c);
        final each = total / Frac(c, 1);
        if (input.maternalBrother > 0) {
          // سهم مجموعة الإخوة لأم (نصيب الفرد × عددهم) — سهم جماعي.
          addFard(HeirType.maternalBrother,
              each * Frac(input.maternalBrother, 1), input.maternalBrother);
        }
        if (input.maternalSister > 0) {
          addFard(HeirType.maternalSister, each * Frac(input.maternalSister, 1),
              input.maternalSister);
        }
      }
    }

    // 5. حساب مجموع الفروض وأصل المسألة
    Frac fixedSum = Frac.zero;
    frads.forEach((_, f) => fixedSum += f);

    int baseAsl = 0;
    frads.forEach((_, f) {
      baseAsl = _lcm(baseAsl, f.d);
    });

    // 6. المسألة المشتركة (المنبرية/الحمارية):
    // زوج + إخوة أشقاء + إخوة لأم (مع أم غالبًا)، بلا أب ولا جد ولا فرع وارث.
    // تتحقق عندما تبلغ الفروض = 1 بالضبط، فيشارك الأشقاء الإخوة لأم في ثلثهم.
    final isMushtarak = !isAkderia &&
        MadhabRules.applyMushtarak(madhab) &&
        input.husband > 0 &&
        input.fullBrother > 0 &&
        (input.maternalBrother > 0 || input.maternalSister > 0) &&
        !hasFar3Warith &&
        input.father == 0 &&
        input.grandfather == 0 &&
        fixedSum.n == 1 &&
        fixedSum.d == 1;

    // 7. العول أو التعصيب أو الرد
    final asaba = <HeirType, Frac>{};
    final notes = <String>[];
    String method = 'normal';

    // الوصية الواجبة لأولاد الابن المتوفى: يُفرض لهم قدر نصيب أبيهم
    // (كأنه حي) في حدود ثلث ما بقي بعد التجهيز والديون والوصايا،
    // ويُخصم قبل توزيع التركة على باقي الورثة (كما في almwareeth.com).
    double mandatoryWillAmount = 0;
    if (input.hasMandatoryWill && estate > 0) {
      final hyp = input.copyWith(
        estate: estate,
        son: input.son + 1,
        orphanGrandsons: 0,
        orphanGranddaughters: 0,
        applyMandatoryWill: false,
        funeralExpenses: 0,
        debts: 0,
        willAmount: 0,
        willAmount2: 0,
        willAmount3: 0,
        heirsConsentExceedThird: false,
      );
      final hypResult = calculate(hyp);
      final sonsShare = hypResult.shares
          .where((s) => s.type == HeirType.son)
          .fold(0.0, (m, s) => m + s.amount);
      final oneSonShare = sonsShare / (input.son + 1);
      final maxMandatory = estate / 3;
      mandatoryWillAmount =
          oneSonShare > maxMandatory ? maxMandatory : oneSonShare;
      estate -= mandatoryWillAmount;
      notes.add(
          'وصیت واجبه: به فرزندانِ پسرِ متوفی به‌اندازهٔ سهم پدرشان (گویی زنده است) '
          'در حد یک‌سوم باقی‌مانده پرداخت شد و مبلغ (${mandatoryWillAmount.toInt()}) پیش از توزیع کسر گردید.');
    }

    if (isAkderia) {
      // المسألة الأكدريه: يُفرض للجد السدس وللأخت النصف ثم يُضمّان
      // ويقسمان للذكر مثل حظ الأنثيين (2:1) بعد العول.
      method = 'awl';
      final spouseType = input.husband > 0 ? HeirType.husband : HeirType.wife;
      final spouseFard = frads[spouseType] ?? Frac.zero;
      final motherFard = frads[HeirType.mother] ?? Frac.zero;
      final gfFard = Frac(1, 6);
      final sisFard = Frac(1, 2);
      // أصل المسألة قبل العول يشمل فروض الزوج/الزوجة والأم والجد والأخت.
      final totalBeforeAwl = fixedSum + gfFard + sisFard;
      final spouseScaled = spouseFard / totalBeforeAwl;
      final motherScaled = motherFard / totalBeforeAwl;
      final merged = (gfFard + sisFard) / totalBeforeAwl; // 4/9 أو 8/15
      frads.clear();
      frads[spouseType] = spouseScaled;
      frads[HeirType.mother] = motherScaled;
      frads[HeirType.grandfather] = merged * Frac(2, 3);
      frads[akderiaSisterType] = merged * Frac(1, 3);
      notes.add(
          'مسأله اکدریه: شوهر/همسر، مادر، جد و یک خواهر جمع شده‌اند و پدر و فرزندی نیست. '
          'برای جد یک‌ششم و برای خواهر نصف فرض شد؛ سپس سهم هر دو با هم ادغام و به نسبت 2 به 1 '
          '(جد دو سهم و خواهر یک سهم) پس از عول تقسیم شد.');
    } else if (isMushtarak) {
      // المسألة المشتركة: حذف فرض الإخوة لأم وتوزيع ثلثهم على جميع أفراد
      // المجموعتين (الأشقاء والإخوة لأم) بالتساوي فردًا فردًا.
      final maternalFard = (frads[HeirType.maternalBrother] ?? Frac.zero) +
          (frads[HeirType.maternalSister] ?? Frac.zero);
      frads.remove(HeirType.maternalBrother);
      frads.remove(HeirType.maternalSister);
      final n = input.fullBrother +
          input.fullSister +
          input.maternalBrother +
          input.maternalSister;
      if (n > 0) {
        final each = maternalFard / Frac(n, 1);
        if (input.fullBrother > 0) {
          asaba[HeirType.fullBrother] = each * Frac(input.fullBrother, 1);
        }
        if (input.fullSister > 0) {
          asaba[HeirType.fullSister] = each * Frac(input.fullSister, 1);
        }
        if (input.maternalBrother > 0) {
          asaba[HeirType.maternalBrother] =
              each * Frac(input.maternalBrother, 1);
        }
        if (input.maternalSister > 0) {
          asaba[HeirType.maternalSister] = each * Frac(input.maternalSister, 1);
        }
      }
      notes.add(
          'مسأله مشترکه (منبریه): وقتی شوهر، برادران/خواهران اشقاء و برادران/خواهران مادری جمع شده‌اند، '
          'فرض برادران/خواهران مادری (یک‌سوم) بین همهٔ افراد دو گروه به‌طور مساوی (فرد به فرد) تقسیم می‌شود.');
    } else if (fixedSum.n > fixedSum.d) {
      // العول
      method = 'awl';
      frads.updateAll((_, f) => f / fixedSum);
      notes.add(
          'مجموع سهم‌های فرض بیشتر از کل ترکه بود، پس طبق قاعده «عول» همه سهم‌ها به نسبت کاهش یافت.');
    } else {
      final leftover = Frac.one - fixedSum;

      // ترتيب العصبات بالنفس (الأدنى): من ابن الأخ إلى ابن عم الأب.
      HeirType? lowerAsabaHead;
      if (!maleLineBlocker) {
        for (final t in _lowerAsabaOrder) {
          if (input.countOf(t) > 0 && !excluded.contains(t)) {
            lowerAsabaHead = t;
            break;
          }
        }
      }

      if (hasSon) {
        // الابن والبنت: تعصيب 2:1
        final wSon = input.son * 2;
        final wDau = input.daughter;
        final tot = wSon + wDau;
        if (wSon > 0) asaba[HeirType.son] = leftover * Frac(wSon, tot);
        if (wDau > 0) asaba[HeirType.daughter] = leftover * Frac(wDau, tot);
      } else if (hasGrandson) {
        // ابن الابن: عصبة، مع بنت الابن 2:1
        final wGSon = input.grandson * 2;
        final wGDau = granddaughterSurvives ? input.granddaughter : 0;
        final tot = wGSon + wGDau;
        if (wGSon > 0) asaba[HeirType.grandson] = leftover * Frac(wGSon, tot);
        if (wGDau > 0) {
          asaba[HeirType.granddaughter] = leftover * Frac(wGDau, tot);
        }
      } else if (hasGreatGrandson) {
        // ابن ابن الابن: عصبة، مع بنت ابن الابن 2:1
        final wGGSon = input.greatGrandson * 2;
        final wGGDau =
            greatGranddaughterSurvives ? input.greatGranddaughter : 0;
        final tot = wGGSon + wGGDau;
        if (wGGSon > 0) {
          asaba[HeirType.greatGrandson] = leftover * Frac(wGGSon, tot);
        }
        if (wGGDau > 0) {
          asaba[HeirType.greatGranddaughter] = leftover * Frac(wGGDau, tot);
        }
      } else if (gharrawainMuqasamah) {
        // الغراوين مع إخوة (قول علي وزيد): الأب والإخوة (الأشقاء/لأب)
        // يتقاسمان الباقي، والأب يُعامَل كأخ (سهمان للذكر).
        _gharrawainFatherMuqasamah(input, leftover, asaba);
      } else if (input.father > 0) {
        // الأب: تعصيب
        asaba[HeirType.father] = leftover;
      } else if (input.grandfather > 0 && grandfatherHajbsSiblings) {
        // حنفي: الجد يحجب الإخوة ويأخذ كل الباقي
        asaba[HeirType.grandfather] = leftover;
      } else if (isShabihMaliki) {
        // شبه المالكية (الجمهور والمالكية): الجد يحجب أولاد الأم فيسقط
        // الأخ الشقيق أيضًا ويأخذ الجد الباقي كله.
        asaba[HeirType.grandfather] = leftover;
        notes.add(
            'مسأله شبه مالکی: شوهر، مادر، جد و برادرِ اشقی/پدری و برادران/خواهران مادری جمع شده‌اند. '
            'جد هر آن‌کس را که از سمت مادر ارث می‌برد محجوب می‌کند؛ بنابراین برادر نیز ساقط می‌شود '
            '(زیرا جز از راه مشترکه با فرزندانِ مادری ارث نمی‌برد) و جد همهٔ باقی‌مانده را می‌برد.');
      } else if (input.grandfather > 0 && hasFullSiblings) {
        // غير حنفي: مقاسمة الجد مع الإخوة (أشقاء ولأب) — المعادّة مع الثلث
        final muq = MadhabRules.calculateGrandfatherMuqasamah(
          madhab: madhab,
          leftover: leftover,
          fullBrother: input.fullBrother,
          fullSister: input.fullSister,
          paternalBrother: input.paternalBrother,
          paternalSister: input.paternalSister,
        );
        if (muq != null) {
          asaba.addAll(muq);
          notes.add(
              'جد با برادران: جد بهترینِ «مقاسمه» در باقی‌مانده (با احتساب برادران/خواهران پدری در شمارش) یا یک‌سوم کل مال را گرفت؛ '
              'سپس خواهر اشقی تا فرض خود (نصف یا دو‌سوم) از سهمی که برادران پدری در مقاسمه می‌گرفتند تکمیل شد.');
        } else {
          asaba[HeirType.grandfather] = leftover;
        }
      } else if (input.grandfather > 0) {
        // الجد وحده يأخذ الباقي
        asaba[HeirType.grandfather] = leftover;
      } else if (madhab == Madhab.tunisia1956 &&
          femaleFar3Present &&
          (input.fullBrother > 0 ||
              input.paternalBrother > 0 ||
              lowerAsabaHead != null)) {
        // إصلاح تونس 1956 (الفصل 121): البنت/بنت الابن تأخذ الباقي ردًا
        // عليها حتى لو وُجد من العصبة بالنفس من الإخوة والأعمام — فيسقطون.
        final dauF = frads[HeirType.daughter] ?? Frac.zero;
        final gdF = frads[HeirType.granddaughter] ?? Frac.zero;
        final ggdF = frads[HeirType.greatGranddaughter] ?? Frac.zero;
        final totF = dauF + gdF + ggdF;
        if (totF.isPositive) {
          if (dauF.isPositive) {
            asaba[HeirType.daughter] = leftover * (dauF / totF);
          }
          if (gdF.isPositive) {
            asaba[HeirType.granddaughter] = leftover * (gdF / totF);
          }
          if (ggdF.isPositive) {
            asaba[HeirType.greatGranddaughter] = leftover * (ggdF / totF);
          }
          notes.add(
              'قانون تونس 1956: با وجود دختر/نوه‌ی دختر، باقی‌مانده به آنان برمی‌گردد (ردّ) و برادران/عموها از تعصیب محروم می‌شوند.');
        }
      } else if (!maleLineBlocker &&
          femaleFar3Present &&
          input.fullBrother == 0 &&
          input.fullSister > 0) {
        // عصبة مع الغير (الأخت الشقيقة مع البنت/بنت الابن):
        // تصير بمنزلة الأخ الشقيق في الإرث والحجب، فتأخذ الباقي كله
        // وتسقط الإخوة لأب وأبناء الإخوة والأعمام (الإجماع سوى ابن حزم).
        asaba[HeirType.fullSister] = leftover;
      } else if (!maleLineBlocker &&
          (input.fullBrother > 0 || input.paternalBrother > 0)) {
        // الإخوة: تعصيب (الأشقاء 2:1، وإن لم يوجد أخ شقيق فالأخ لأب 2:1)
        _calculateSiblingAsaba(input, leftover, asaba);
      } else if (!maleLineBlocker &&
          femaleFar3Present &&
          (input.fullSister > 0 || input.paternalSister > 0)) {
        // عصبة مع الغير: البنت/بنت الابن تجعل الأخت الشقيقة (أو الأخت لأب
        // عند عدم وجود الشقيقة) عصبة تأخذ الباقي.
        if (input.fullSister > 0) {
          asaba[HeirType.fullSister] = leftover;
        } else if (input.paternalSister > 0) {
          asaba[HeirType.paternalSister] = leftover;
        }
      } else if (lowerAsabaHead != null) {
        // أول العُصبة الأدنى (ابن الأخ → ابن عم الأب)
        asaba[lowerAsabaHead] = leftover;
      } else if (leftover.isZero) {
        // کل ترکه بین صاحبان الفروض توزیع شد، لا عول ولا رد.
        method = 'normal';
      } else if (arhamAllowed && closestArham != null) {
        // ذوو الأرحام: مع نبود أي عاصب، الباقي بعد الفروض يذهب إلى أقرب ذي رحم
        // (المعتمد في المذهب الحنفي وبعض القوانين — سوريا/لبنان...)، ولا يصح
        // الردّ مع وجود ذي رحم: ﴿وَلِكُلٍّ جَعَلْنَا مَوَالِيَ مِمَّا تَرَكَ﴾.
        method = 'distantKindred';
        asaba[closestArham] = leftover;
        final whole = leftover.n == leftover.d;
        notes.add(whole
            ? 'با نبود هیچ‌یک از وراث اصلی، ترکهٔ کامل به ${heirLabel(closestArham)} (ذوی‌الأرحام) رسید.'
            : 'با نبود هیچ‌یک از عَصَبه، باقی‌ماندهٔ پس از سهم‌های فرض (${leftover.n}/${leftover.d} ترکه) به نزدیک‌ترین خویشاوند دور (${heirLabel(closestArham)}) رسید.');
      } else {
        // الرد — أو بیت‌المال اگر کسی نمی‌توان بر او رد کرد
        method = _calculateRadd(frads, leftover, notes) ? 'radd' : 'baytMal';
      }
    }

    // 8. بناء النتائج
    final allTypes = <HeirType>{...frads.keys, ...asaba.keys};
    final shares = <InheritanceShare>[];

    // ذوو الأرحام (distant kindred): the «remainder after fards» case is
    // handled in the تعصيب chain above — the closest ذو رحم is added to
    // `asaba` and takes `leftover`. By the time we reach this point, the only
    // way `allTypes` is empty is when no fard, no عاصب and no head ذو رحم
    // exists — the estate then goes to بيت المال.
    if (allTypes.isEmpty) {
      notes.add(arhamAllowed
          ? 'هیچ‌یک از وراث حضور ندارند؛ ترکه به بیت‌المال تعلق می‌گیرد.'
          : 'در این قانون (مالکی) با نبود هیچ‌یک از وراث اصلی و عصبه، ترکه به بیت‌المال تعلق می‌گیرد و ذوی‌الأرحام ارث نمی‌برند.');
    }
    for (final t in allTypes) {
      final frac = (frads[t] ?? Frac.zero) + (asaba[t] ?? Frac.zero);
      if (frac.isZero) continue;
      final count = counts[t] ?? input.countOf(t);
      final isMushtarakSibling = isMushtarak &&
          (t == HeirType.maternalBrother || t == HeirType.maternalSister);
      final isAsaba = asaba.containsKey(t) && !isMushtarakSibling;
      shares.add(InheritanceShare(
        type: t,
        count: count,
        fraction: frac,
        amount: estate * frac.toDouble(),
        shareType: isAsaba ? ShareType.asaba : ShareType.fard,
        reason: _reason(t, input, hasSon, anySibling, isAsaba, count, madhab),
      ));
    }

    // حصص الوصية الواجبة (أولاد الابن المتوفى): تُضاف كسهم مستقل.
    if (mandatoryWillAmount > 0) {
      final totalUnits = input.orphanGrandsons * 2 + input.orphanGranddaughters;
      if (totalUnits > 0) {
        if (input.orphanGrandsons > 0) {
          shares.add(InheritanceShare(
            type: HeirType.grandson,
            count: input.orphanGrandsons,
            fraction: Frac(2 * input.orphanGrandsons, totalUnits),
            amount:
                mandatoryWillAmount * (2 * input.orphanGrandsons) / totalUnits,
            shareType: ShareType.mandatoryWill,
            reason:
                'وصیت واجبه: فرزندانِ پسرِ متوفی به‌اندازهٔ سهم پدرشان ارث می‌برند (پسر دو برابر دختر).',
          ));
        }
        if (input.orphanGranddaughters > 0) {
          shares.add(InheritanceShare(
            type: HeirType.granddaughter,
            count: input.orphanGranddaughters,
            fraction: Frac(input.orphanGranddaughters, totalUnits),
            amount:
                mandatoryWillAmount * input.orphanGranddaughters / totalUnits,
            shareType: ShareType.mandatoryWill,
            reason:
                'وصیت واجبه: فرزندانِ پسرِ متوفی به‌اندازهٔ سهم پدرشان ارث می‌برند (پسر دو برابر دختر).',
          ));
        }
      }
    }

    shares
        .sort((a, b) => b.fraction.toDouble().compareTo(a.fraction.toDouble()));

    // 9. تنبيهات الحجب
    _addBlockingNotes(input, shares, notes, hasFar3Warith, anySibling);

    // إضافة تنبيه المذهب
    notes.add('محاسبه بر اساس مذهب ${madhabLabel(madhab)}.');

    // أصل المسألة بعد التصحيح (من مقامات الكسور النهائية)
    int correctedAsl = 0;
    for (final s in shares) {
      if (s.shareType == ShareType.mandatoryWill) continue;
      correctedAsl = _lcm(correctedAsl, s.fraction.d);
    }
    if (isMushtarak) correctedAsl = baseAsl > 0 ? baseAsl : correctedAsl;

    return InheritanceResult(
      estate: input.estate,
      netEstate: netEstate,
      madhab: madhab,
      shares: shares,
      method: method,
      warnings: warnings,
      notes: notes,
      baseAsl: baseAsl,
      correctedAsl: correctedAsl,
      mandatoryWillAmount: mandatoryWillAmount,
    );
  }

  static int _gcd(int a, int b) {
    a = a.abs();
    b = b.abs();
    while (b != 0) {
      final t = b;
      b = a % b;
      a = t;
    }
    return a == 0 ? 1 : a;
  }

  static int _lcm(int a, int b) {
    if (a == 0) return b;
    if (b == 0) return a;
    return a ~/ _gcd(a, b) * b;
  }

  /// هل تنطبق الغراوين مع مقاسمة الأب للإخوة (قول علي وزيد)؟
  ///
  /// تتطلب: زوج/زوجة + أم + أب بلا فرع وارث، وأن يكون المذهب/القانون آخذًا
  /// بثلث الأصل للأم (مالكي/حنبلي/الجزائري/السعودي)، ووجود إخوة أشقاء أو لأب.
  /// عند قول عمر (جمهور/حنفي/شافعي وقوانينهم) لا يرث الإخوة مع الأب شيئًا.
  bool _gharrawainMuqasamah(InheritanceInput input, bool hasFar3Warith) {
    // المقاسمة قسمةُ الأب مع الإخوة؛ بلا أب لا مقاسمة — الإخوة يأخذون
    // الباقي تعصيبًا مباشرةً وتُنزَّل الأم ثلث الباقي فقط.
    if (input.father == 0) return false;
    if (!_isGharrawain(input, hasFar3Warith)) return false;
    if (!MadhabRules.gharrawainMotherThirdOfWhole(madhab)) return false;
    return input.fullBrother +
            input.fullSister +
            input.paternalBrother +
            input.paternalSister >
        0;
  }

  /// هل تنطبق المسألة الأكدريه؟
  ///
  /// زوج/زوجة + أم + جد + أخت واحدة (شقيقة أو لأب)، بلا أب ولا فرع وارث
  /// ولا غيرها من الإخوة. تُرجِع نوع الأخت الوارثة أو null.
  HeirType? _akderiaSisterType(InheritanceInput input, bool hasFar3Warith) {
    if (hasFar3Warith) return null;
    if (input.grandfather == 0 || input.father > 0) return null;
    // حيث يحجب الجد الإخوة (حنفي / السعودية) لا تنطبق الأكدريه:
    // الجد يأخذ كل الباقي ولا أخت له.
    if (MadhabRules.grandfatherHajbsBrothers(madhab)) return null;
    if ((input.husband == 0 && input.wife == 0) || input.mother == 0) {
      return null;
    }
    if (input.fullBrother > 0 || input.paternalBrother > 0) return null;
    if (input.maternalBrother > 0 || input.maternalSister > 0) return null;
    if (input.fullSister + input.paternalSister != 1) return null;
    return input.fullSister > 0 ? HeirType.fullSister : HeirType.paternalSister;
  }

  @override
  Set<HeirType> blockedHeirs(InheritanceInput input) {
    final hasSon = input.son > 0;
    final hasGrandson = input.grandson > 0;
    final hasGreatGrandson = input.greatGrandson > 0;
    final hasFar3Warith = hasSon ||
        input.daughter > 0 ||
        hasGrandson ||
        input.granddaughter > 0 ||
        hasGreatGrandson ||
        input.greatGranddaughter > 0;
    final grandfatherHajbsSiblings =
        input.grandfather > 0 && MadhabRules.grandfatherHajbsBrothers(madhab);
    final excluded = _applyHajb(
      input,
      hasSon: hasSon,
      hasGrandson: hasGrandson,
      hasGreatGrandson: hasGreatGrandson,
      grandfatherHajbsSiblings: grandfatherHajbsSiblings,
      siblingsShareWithFather: _gharrawainMuqasamah(input, hasFar3Warith),
    );

    // ذوو الأرحام: they inherit the remainder after fards (أو كل التركة) only
    // when no عاصب exists and the law allows distant kindred — mirror of the
    // تعصيب chain in `calculate`, so the preview can never disagree with the
    // shares. Note: the corner case where الفروض sum to exactly 1 leaves no
    // remainder for ذوو الأرحام; in that rare case the head may show as a mere
    // possible inheritor here, but the actual shares remain correct.
    const arham = <HeirType>{
      HeirType.paternalAunt,
      HeirType.maternalUncle,
      HeirType.maternalAunt,
      HeirType.nieceFull,
      HeirType.niecePaternal,
      HeirType.nieceSon,
      HeirType.uncleDaughter,
    };
    if (!_arhamAllowed || _anyAsabaPotential(input, excluded)) {
      // قانون مالکی (بيت المال) أو وجود عاصب → ذوو الأرحام محجوبون كلهم.
      excluded.addAll(arham);
    } else {
      // لا عاصب: أقرب ذي رحم حاضر يرث الباقي، والبقية محجوبة.
      final head = _closestArham(input);
      for (final t in arham) {
        if (t != head) excluded.add(t);
      }
    }
    return excluded;
  }

  /// تطبيق الحجب. Same engine [calculate] drives; see [blockedHeirs].
  Set<HeirType> _applyHajb(
    InheritanceInput input, {
    required bool hasSon,
    required bool hasGrandson,
    required bool hasGreatGrandson,
    required bool grandfatherHajbsSiblings,
    required bool siblingsShareWithFather,
  }) {
    final excluded = <HeirType>{};

    // الأب يحجب الجد وأب الجد.
    if (input.father > 0) {
      excluded.add(HeirType.grandfather);
      excluded.add(HeirType.greatGrandfather);
    }
    // الجد يحجب أب الجد.
    if (input.grandfather > 0) {
      excluded.add(HeirType.greatGrandfather);
    }

    // الأم تحجب جميع الجدّات.
    if (input.mother > 0) {
      for (final t in _grandmotherTypes) {
        excluded.add(t);
      }
    } else {
      // الجدّة القريبة تحجب البعيدة.
      final nearMaternal = input.maternalGrandmother > 0;
      final nearPaternal = input.paternalGrandmother > 0;
      if (MadhabRules.nearGrandmotherHajbsAll(madhab)) {
        // جمهور/حنفي/حنبلي: القريبة (من أي جهة) تحجب البعيدة من كل الجهات.
        if (nearMaternal || nearPaternal) {
          excluded.add(HeirType.greatMaternalGrandmother);
          excluded.add(HeirType.paternalGreatGrandmotherFather);
          excluded.add(HeirType.paternalGreatGrandmotherMother);
        }
      } else {
        // شافعي/مالكي: أم الأم تحجب البعيدة من الجهتين؛ أم الأب تحجب
        // البعيدة من جهة الأب فقط.
        if (nearMaternal) {
          excluded.add(HeirType.greatMaternalGrandmother);
          excluded.add(HeirType.paternalGreatGrandmotherFather);
          excluded.add(HeirType.paternalGreatGrandmotherMother);
        }
        if (nearPaternal) {
          excluded.add(HeirType.paternalGreatGrandmotherFather);
          excluded.add(HeirType.paternalGreatGrandmotherMother);
        }
      }
    }

    // الابن أو ابن الابن أو الأب يحجب الإخوة (أشقاء/لأب/لأم).
    // في الغراوين على قول علي وزيد لا يُحجب الأشقاء/لأب لأنهم يقاسمون الأب،
    // وأما على قول عمر فهم محجوبون بالأب فلا يرثون شيئًا.
    if (hasSon || hasGrandson || hasGreatGrandson || input.father > 0) {
      if (!siblingsShareWithFather) {
        excluded.add(HeirType.fullBrother);
        excluded.add(HeirType.fullSister);
        excluded.add(HeirType.paternalBrother);
        excluded.add(HeirType.paternalSister);
      }
      excluded.add(HeirType.maternalBrother);
      excluded.add(HeirType.maternalSister);
    }
    // الفرع الوارث (ذكرًا أو أنثى) يحجب الإخوة لأم.
    if (input.daughter > 0 ||
        input.granddaughter > 0 ||
        input.greatGranddaughter > 0) {
      excluded.add(HeirType.maternalBrother);
      excluded.add(HeirType.maternalSister);
    }
    // الجد يحجب الإخوة لأم (متفق عليه)، والأشقاء/لأب في الحنفي فقط.
    if (input.grandfather > 0) {
      excluded.add(HeirType.maternalBrother);
      excluded.add(HeirType.maternalSister);
      if (grandfatherHajbsSiblings) {
        excluded.add(HeirType.fullBrother);
        excluded.add(HeirType.fullSister);
        excluded.add(HeirType.paternalBrother);
        excluded.add(HeirType.paternalSister);
      }
    }

    // الأخ الشقيق يحجب الأخ والأخت لأب.
    if (input.fullBrother > 0) {
      excluded.add(HeirType.paternalBrother);
      excluded.add(HeirType.paternalSister);
    }
    // الأختان الشقيقتان تحجبان الأخت لأب (في الحنفي تكفي واحدة).
    if (input.fullSister >= 2 ||
        (MadhabRules.baseMadhab(madhab) == Madhab.hanafi &&
            input.fullSister >= 1)) {
      excluded.add(HeirType.paternalSister);
    }

    // حجب بنات العمود النازل.
    final greatGrandsonAlive = hasGreatGrandson && !hasSon && !hasGrandson;
    // بنت الابن: يحجبها ابن عمها (الابن) أو بنتان ما لم يكن أخوها حيًا.
    if (hasSon || (input.daughter >= 2 && !hasGrandson)) {
      excluded.add(HeirType.granddaughter);
    }
    // بنت ابن الابن: يحجبها الأعمام (ابن/ابن الابن) أو بلوغ الثلثين
    // من الفروع النسائية ما لم يكن أخوها حيًا.
    final higherFemalesReachTwoThirds = input.daughter >= 2 ||
        input.granddaughter >= 2 ||
        (input.daughter == 1 && input.granddaughter == 1);
    if (hasSon ||
        hasGrandson ||
        (higherFemalesReachTwoThirds && !greatGrandsonAlive)) {
      excluded.add(HeirType.greatGranddaughter);
    }
    // الابن يحجب ابن الابن وأولاد ابن الابن.
    if (hasSon) {
      excluded.add(HeirType.grandson);
      excluded.add(HeirType.greatGrandson);
    }
    if (hasGrandson) {
      excluded.add(HeirType.greatGrandson);
    }

    // حجب العُصبة الأدنى: ابن أو ابن ابن أو أب أو جد.
    if (hasSon ||
        hasGrandson ||
        hasGreatGrandson ||
        input.father > 0 ||
        input.grandfather > 0) {
      for (final t in _lowerAsabaOrder) {
        excluded.add(t);
      }
    }
    // ابن الأخ الشقيق يحجب ابن الأخ لأب وأولاد الإخوة.
    if (input.nephewFull > 0) {
      excluded.add(HeirType.nephewPaternal);
      excluded.add(HeirType.nephewSonFull);
      excluded.add(HeirType.nephewSonPaternal);
    } else if (input.nephewPaternal > 0) {
      excluded.add(HeirType.nephewSonPaternal);
    }
    // العم الشقيق يحجب العم لأب وأولاد الأعمام.
    if (input.paternalUncle > 0) {
      excluded.add(HeirType.paternalUnclePaternal);
      excluded.add(HeirType.paternalUncleSon);
      excluded.add(HeirType.paternalUncleSonPaternal);
      excluded.add(HeirType.paternalUncleGrandson);
      excluded.add(HeirType.paternalUncleGrandsonPaternal);
    } else if (input.paternalUnclePaternal > 0) {
      excluded.add(HeirType.paternalUncleSonPaternal);
      excluded.add(HeirType.paternalUncleGrandsonPaternal);
    }
    if (input.paternalUncleSon > 0) {
      excluded.add(HeirType.paternalUncleSonPaternal);
      excluded.add(HeirType.paternalUncleGrandson);
      excluded.add(HeirType.paternalUncleGrandsonPaternal);
    } else if (input.paternalUncleSonPaternal > 0) {
      excluded.add(HeirType.paternalUncleGrandsonPaternal);
    }
    if (input.paternalUncleGrandson > 0) {
      excluded.add(HeirType.paternalUncleGrandsonPaternal);
    }
    // عمو الأب الشقيق يحجب عمو الأب لأب وأولادهم.
    if (input.fatherUncleFull > 0) {
      excluded.add(HeirType.fatherUnclePaternal);
      excluded.add(HeirType.fatherCousinFull);
      excluded.add(HeirType.fatherCousinPaternal);
    } else if (input.fatherUnclePaternal > 0) {
      excluded.add(HeirType.fatherCousinPaternal);
    }
    if (input.fatherCousinFull > 0) {
      excluded.add(HeirType.fatherCousinPaternal);
    }

    return excluded;
  }

  /// هل تنطبق المسألة الغراوان (الغراوين/العمريتان)؟
  ///
  /// زوج/زوجة + أم، بلا فرع وارث وبلا جد، مع أحد شكلين:
  /// 1. مع الأب (العمريتان) — والإخوة لا يمنعون الغراوين بل هم
  ///    موضوع الخلاف (قول عمر مقابل قول علي وزيد).
  /// 2. بلا أب مع إخوة أشقاء/لأب اثنين فأكثر — فالتنزيل إلى ثلث الباقي
  ///    (قول عمر) إنما ينطبق حين لا يكون أبٌ يحجب الإخوة؛ عندئذٍ تأخذ
  ///    الأم ثلث الباقي بعد الزوج بدل السدس.
  bool _isGharrawain(InheritanceInput input, bool hasFar3Warith) {
    if (hasFar3Warith) return false;
    if ((input.husband == 0 && input.wife == 0) || input.mother == 0) {
      return false;
    }
    // وجود الجد مكان الأب أو بجانبه يخرجه من الغراوين.
    if (input.grandfather != 0) return false;
    if (input.father > 0) return true;
    return input.fullBrother +
            input.fullSister +
            input.paternalBrother +
            input.paternalSister >=
        2;
  }

  /// مقاسمة الأب مع الإخوة في الغراوين (عند وجود إخوة أشقاء/لأب).
  ///
  /// الأب يُعامَل كأخ: للذكر سهمان وللأنثى سهم واحد.
  void _gharrawainFatherMuqasamah(
    InheritanceInput input,
    Frac leftover,
    Map<HeirType, Frac> asaba,
  ) {
    const int wF = 2;
    final int wFullB = input.fullBrother * 2;
    final int wFullS = input.fullSister;
    final int wPatB = input.paternalBrother * 2;
    final int wPatS = input.paternalSister;
    final int tot = wF + wFullB + wFullS + wPatB + wPatS;
    if (tot == 0) {
      asaba[HeirType.father] = leftover;
      return;
    }
    asaba[HeirType.father] = leftover * Frac(wF, tot);
    if (input.fullBrother > 0) {
      asaba[HeirType.fullBrother] = leftover * Frac(wFullB, tot);
    }
    if (input.fullSister > 0) {
      asaba[HeirType.fullSister] = leftover * Frac(wFullS, tot);
    }
    if (input.paternalBrother > 0) {
      asaba[HeirType.paternalBrother] = leftover * Frac(wPatB, tot);
    }
    if (input.paternalSister > 0) {
      asaba[HeirType.paternalSister] = leftover * Frac(wPatS, tot);
    }
  }

  /// حساب تعصيب الإخوة (أشقاء 2:1، وإن لم يوجد أخ شقيق فالأخ لأب 2:1).
  ///
  /// ملاحظة: الأخت الشقيقة مع الأخ لأب لا تقاسمه، بل تأخذ فرضها.
  void _calculateSiblingAsaba(
    InheritanceInput input,
    Frac leftover,
    Map<HeirType, Frac> asaba,
  ) {
    if (input.fullBrother > 0) {
      final wB = input.fullBrother * 2;
      final wS = input.fullSister;
      final tot = wB + wS;
      if (tot > 0) {
        asaba[HeirType.fullBrother] = leftover * Frac(wB, tot);
        if (wS > 0) asaba[HeirType.fullSister] = leftover * Frac(wS, tot);
      }
    } else if (input.paternalBrother > 0) {
      final wB = input.paternalBrother * 2;
      final wS = input.paternalSister;
      final tot = wB + wS;
      if (tot > 0) {
        asaba[HeirType.paternalBrother] = leftover * Frac(wB, tot);
        if (wS > 0) {
          asaba[HeirType.paternalSister] = leftover * Frac(wS, tot);
        }
      }
    }
  }

  /// حساب الردّ — `true` اگر باقی‌مانده واقعاً به صاحبان فرض برگشت.
  ///
  /// وقتی تنها سهم‌دارانِ حاضر زوجین‌اند (و آنان در این مذهب/قانون از رد
  /// مستثن‌اند) چیزی «رد» نمی‌شود؛ آن‌گاه باقی‌مانده به بیت‌المال می‌رسد و
  /// روش مسأله نباید «رد» نامیده شود.
  bool _calculateRadd(
    Map<HeirType, Frac> frads,
    Frac leftover,
    List<String> notes,
  ) {
    Frac raddBase = Frac.zero;
    frads.forEach((t, f) {
      if (MadhabRules.isRaddExempt(t, madhab)) return;
      raddBase += f;
    });
    if (raddBase.isZero) {
      notes.add(
          'باقی‌مانده‌ای پس از سهم‌های فرض باقی ماند که طبق فقه به بیت‌المال تعلق می‌گیرد.');
      return false;
    }
    frads.updateAll((t, f) {
      if (MadhabRules.isRaddExempt(t, madhab)) return f;
      return f + (f * leftover / raddBase);
    });
    final spouseParticipates = MadhabRules.isSpouseRaddExempt(madhab)
        ? 'به سهم‌دارانِ غیرِ همسری'
        : 'به سهم‌داران (از جمله همسر)';
    notes.add(
        'در این حالت باقی‌مانده‌ای پس از سهم‌های فرض باقی ماند و چون وارثِ باقی‌مانده (عصبه) نبود، طبق قاعده «رد» $spouseParticipates برگشت داده شد.');
    return true;
  }

  /// تنبيهات الحجب
  void _addBlockingNotes(
    InheritanceInput input,
    List<InheritanceShare> shares,
    List<String> notes,
    bool hasFar3Warith,
    bool anySibling,
  ) {
    bool present(HeirType t) => shares.any((s) => s.type == t);

    // الإخوة محجوبون بالابن/ابن الابن/الأب
    if (input.son > 0 ||
        input.grandson > 0 ||
        input.greatGrandson > 0 ||
        input.father > 0) {
      final blockedSib = [
        if (input.fullBrother > 0 && !present(HeirType.fullBrother))
          'برادر (پدری و مادری)',
        if (input.fullSister > 0 && !present(HeirType.fullSister))
          'خواهر (پدری و مادری)',
        if (input.paternalBrother > 0 && !present(HeirType.paternalBrother))
          'برادر پدری',
        if (input.paternalSister > 0 && !present(HeirType.paternalSister))
          'خواهر پدری',
        if (input.maternalBrother > 0 && !present(HeirType.maternalBrother))
          'برادر مادری',
        if (input.maternalSister > 0 && !present(HeirType.maternalSister))
          'خواهر مادری',
      ];
      if (blockedSib.isNotEmpty) {
        notes.add(
            '${blockedSib.join('، ')} به دلیل وجود فرزند پسر/پدر محجوب (حجب) شدند و ارث نمی‌برند.');
      }
    }
    if (input.father > 0 &&
        (input.grandfather > 0 || input.greatGrandfather > 0) &&
        !present(HeirType.grandfather) &&
        !present(HeirType.greatGrandfather)) {
      notes.add('پدربزرگ‌ها به دلیل وجود پدر محجوب (حجب) شدند و ارث نمی‌برند.');
    }
    if (input.grandfather > 0 &&
        input.greatGrandfather > 0 &&
        !present(HeirType.greatGrandfather)) {
      notes.add(
          'پدرِ پدربزرگ به دلیل وجود پدربزرگ محجوب (حجب) شد و ارث نمی‌برد.');
    }
    if (input.mother > 0) {
      final blockedGm = [
        for (final t in _grandmotherTypes)
          if (input.countOf(t) > 0) heirLabel(t),
      ];
      if (blockedGm.isNotEmpty && !_anyGrandmotherPresent(shares)) {
        notes.add(
            '${blockedGm.join('، ')} به دلیل وجود مادر محجوب (حجب) شدند و ارث نمی‌برند.');
      }
    }
    if (input.fullBrother > 0 &&
        (input.paternalBrother > 0 || input.paternalSister > 0) &&
        !present(HeirType.paternalBrother) &&
        !present(HeirType.paternalSister)) {
      notes.add(
          'برادر/خواهر پدری به دلیل وجود برادر/خواهر (پدری و مادری) محجوب شدند.');
    }
    if (input.son > 0 && input.grandson > 0 && !present(HeirType.grandson)) {
      notes.add('پسرِ پسر به دلیل وجود پسر محجوب (حجب) شد و ارث نمی‌برد.');
    }
  }

  bool _anyGrandmotherPresent(List<InheritanceShare> shares) {
    for (final s in shares) {
      if (_grandmotherTypes.contains(s.type)) return true;
    }
    return false;
  }

  /// دليل كل وارث
  String _reason(
    HeirType t,
    InheritanceInput input,
    bool hasSon,
    bool anySibling,
    bool isAsaba,
    int count,
    Madhab madhab,
  ) {
    // فرض الزوجين يُحسب من «أي فرع وارث» (يشمل ابن الابن)، فلا يجوز أن
    // يتفرع نص التعليل من «الابن» وحده وإلا ناقض الكسور المعروضة.
    final hasFar3 = input.son > 0 ||
        input.daughter > 0 ||
        input.grandson > 0 ||
        input.granddaughter > 0 ||
        input.greatGrandson > 0 ||
        input.greatGranddaughter > 0;
    switch (t) {
      case HeirType.husband:
        return hasFar3
            ? 'با وجود فرع وارث، سهم شوهر یک‌چهارم است: ﴿فَإِن كَانَ لَهُنَّ وَلَدٌ فَلَكُمُ الرُّبْعُ﴾ (نساء/12).'
            : 'بدون فرع وارث، سهم شوهر نصف ترکه است: ﴿وَلَكُمْ نِصْفُ مَا تَرَكَ أَزْوَاجُكُمْ﴾ (نساء/12).';
      case HeirType.wife:
        final share = hasFar3 ? 'یک‌هشتم' : 'یک‌چهارم';
        final verse = hasFar3
            ? '﴿فَإِن كَانَ لَكُمْ وَلَدٌ فَلَهُنَّ الثُّمُنُ﴾ (نساء/12)'
            : '﴿وَلَهُنَّ الرُّبُعُ﴾ (نساء/12)';
        final shareNote = count > 1
            ? ' همه همسران ($count نفر) در این $share مشترک‌اند.'
            : '';
        return 'سهم همسر $share است: $verse$shareNote';
      case HeirType.son:
        return 'پسر «عصبه» است و با نسبت 2 به 1 نسبت به دختر، باقی‌مانده ترکه را می‌برد: ﴿لِلذَّكَرِ مِثْلُ حَظِّ الْأُنثَيَيْنِ﴾ (نساء/11).';
      case HeirType.daughter:
        if (hasSon) {
          return 'دختر با وجود برادر «عصبه» می‌شود و به نسبت 1 به 2 سهم می‌برد: ﴿لِلذَّكَرِ مِثْلُ حَظِّ الْأُنثَيَيْنِ﴾ (نساء/11).';
        }
        return count == 1
            ? 'دخترِ تنها نصف ترکه را می‌برد: ﴿وَإِن كَانَتْ وَاحِدَةً فَلَهَا النِّصْفُ﴾ (نساء/11).'
            : 'دو دختر یا بیشتر، دو‌سوم ترکه را می‌برند: ﴿فَإِن كُنَّ نِسَاءً فَوْقَ اثْنَتَيْنِ فَلَهُنَّ ثُلُثَا مَا تَرَكَ﴾ (نساء/11).';
      case HeirType.father:
        return isAsaba
            ? 'بدون فرزند، پدر «عصبه» است و تمام باقی‌مانده ترکه را می‌برد.'
            : 'با وجود فرزند، پدر سهم فرض یک‌ششم دارد: ﴿وَلِأَبَوَيْهِ لِكُلِّ وَاحِدٍ مِنْهُمَا السُّدُسُ﴾ (نساء/11).';
      case HeirType.mother:
        return 'سهم مادر طبق ضابطه فرض (1/3 یا 1/6) محاسبه شد: ﴿فَإِن لَّمْ يَكُن لَّهُ وَلَدٌ فَلِأُمِّهِ الثُّلُثُ﴾ (نساء/11).';
      case HeirType.maternalGrandmother:
        return 'مادربزرگ مادری (مادرِ مادر) در صورت نبود مادر، سهم فرض یک‌ششم دارد و اگر جده‌های دیگری هم باشند در آن سهیم است.';
      case HeirType.paternalGrandmother:
        return 'مادربزرگ پدری (مادرِ پدر) در صورت نبود مادر، سهم فرض یک‌ششم دارد و اگر جده‌های دیگری هم باشند در آن سهیم است.';
      case HeirType.greatMaternalGrandmother:
        return 'مادرِ مادرِ مادر در صورت نبود مادر و جدهٔ نزدیک‌تر، سهم فرض یک‌ششم دارد.';
      case HeirType.paternalGreatGrandmotherFather:
        return 'مادرِ پدرِ پدر در صورت نبود مادر و جدهٔ نزدیک‌تر، سهم فرض یک‌ششم دارد.';
      case HeirType.paternalGreatGrandmotherMother:
        return 'مادرِ مادرِ پدر در صورت نبود مادر و جدهٔ نزدیک‌تر، سهم فرض یک‌ششم دارد.';
      case HeirType.grandfather:
        if (isAsaba) {
          return madhab == Madhab.hanafi || madhab == Madhab.saudi
              ? 'پدربزرگ جای پدر را می‌گیرد و «عصبه» بوده و باقی‌مانده را می‌برد (این قانون/مذهب، برادران را محجوب می‌کند).'
              : 'پدربزرگ جای پدر را می‌گیرد و «عصبه» بوده و باقی‌مانده را می‌برد.';
        }
        return 'پدربزرگ پدری با وجود فرع وارث، سهم فرض یک‌ششم دارد: ﴿وَلِأَبَوَيْهِ لِكُلِّ وَاحِدٍ مِنْهُمَا السُّدُسُ﴾ (نساء/11).';
      case HeirType.greatGrandfather:
        return 'پدرِ پدربزرگ «عصبه» است و در نبود پسر، پدر و جد، باقی‌مانده را می‌برد.';
      case HeirType.grandson:
        return 'پسرِ پسر در نبود پسر، «عصبه» است و با نسبت 2 به 1 نسبت به دخترِ پسر، باقی‌مانده ترکه را می‌برد.';
      case HeirType.granddaughter:
        if (isAsaba) {
          return 'دخترِ پسر با وجود برادرش (پسرِ پسر) «عصبه» می‌شود و به نسبت 1 به 2 سهم می‌برد.';
        }
        if (input.daughter == 1) {
          return 'دخترِ پسر با یک دختر، سهم یک‌ششم را به عنوان تکمله دو‌سوم می‌برد.';
        }
        return 'دخترِ پسر در نبود پسر و پسرِ پسر و دختر، سهم فرض ${input.granddaughter == 1 ? 'نصف' : 'دو‌سوم'} دارد.';
      case HeirType.greatGrandson:
        return 'پسرِ پسرِ پسر در نبود پسر و پسرِ پسر، «عصبه» است و با نسبت 2 به 1 نسبت به دخترِ پسرِ پسر، باقی‌مانده ترکه را می‌برد.';
      case HeirType.greatGranddaughter:
        if (isAsaba) {
          return 'دخترِ پسرِ پسر با وجود برادرش (پسرِ پسرِ پسر) «عصبه» می‌شود.';
        }
        if (input.daughter == 1 || input.granddaughter == 1) {
          return 'دخترِ پسرِ پسر به عنوان تکمله دو‌سوم، سهم یک‌ششم می‌برد.';
        }
        return 'دخترِ پسرِ پسر در نبود فرزندان بالاتر، سهم فرض ${input.greatGranddaughter == 1 ? 'نصف' : 'دو‌سوم'} دارد.';
      case HeirType.fullBrother:
        return isAsaba
            ? 'برادر (پدری و مادری) «عصبه» است و با نسبت 2 به 1 نسبت به خواهر، باقی‌مانده را می‌برد.'
            : 'سهم برادر (پدری و مادری) طبق ضابطه عمومی محاسبه شد.';
      case HeirType.fullSister:
        if (isAsaba) {
          return 'خواهر (پدری و مادری) با وجود برادر یا دختر، «عصبه» می‌شود و باقی‌مانده را می‌برد.';
        }
        return count == 1
            ? 'خواهر (پدری و مادری) در نبود پدر، فرزند و برادر، سهم فرض نصف دارد.'
            : 'خواهران (پدری و مادری) در نبود پدر، فرزند و برادر، در مجموع دو‌سوم سهم فرض دارند.';
      case HeirType.paternalBrother:
        return isAsaba
            ? 'برادر پدری «عصبه» است و با نسبت 2 به 1 نسبت به خواهر، باقی‌مانده را می‌برد.'
            : 'سهم برادر پدری طبق ضابطه عمومی محاسبه شد.';
      case HeirType.paternalSister:
        if (isAsaba) return 'خواهر پدری با وجود برادر یا دختر، «عصبه» می‌شود.';
        if (input.fullSister == 1) {
          return 'خواهر پدری با یک خواهر (پدری و مادری) سهم یک‌ششم را به عنوان تکمله دو‌سوم می‌برد.';
        }
        return count == 1
            ? 'خواهر پدری در نبود پدر، فرزند و برادر، سهم فرض نصف دارد.'
            : 'خواهران پدری در نبود پدر، فرزند و برادر، در مجموع دو‌سوم سهم فرض دارند.';
      case HeirType.maternalBrother:
      case HeirType.maternalSister:
        return 'برادر/خواهر مادری از مصادیق «کلاله»‌اند و در نبود پدر، مادر و فرزند، مجموعاً یک‌سوم می‌برند: ﴿فَلِكُلِّ وَاحِدٍ مِنْهُمَا السُّدُسُ﴾ (نساء/12).';
      case HeirType.nephewFull:
        return 'پسرِ برادرِ پدری و مادری «عصبه» است و در صورت نبود پسر، پدر، برادر و عمو، باقی‌مانده ترکه را می‌برد.';
      case HeirType.nephewPaternal:
        return 'پسرِ برادرِ پدری «عصبه» است و در صورت نبود پسر، پدر، برادر (پدری و مادری) و پسرِ برادر (پدری و مادری)، باقی‌مانده ترکه را می‌برد.';
      case HeirType.nieceSon:
        return isAsaba
            ? 'پسرِ خواهر (ابن الأخت) از ذوی‌الأرحام است و در نبودِ عَصَبه، باقی‌ماندهٔ پس از سهم‌های فرض (یا تمام ترکه) را می‌برد.'
            : 'پسرِ خواهر (ابن الأخت) از ذوی‌الأرحام است و نزدیک‌ترین خویشاوند بهتر از او وجود دارد، پس ارث نمی‌برد.';
      case HeirType.uncleDaughter:
        return isAsaba
            ? 'دخترِ عمو (بنت العم) از ذوی‌الأرحام است و در نبودِ عَصَبه، باقی‌ماندهٔ پس از سهم‌های فرض (یا تمام ترکه) را می‌برد.'
            : 'دخترِ عمو (بنت العم) از ذوی‌الأرحام است و نزدیک‌ترین خویشاوند بهتر از او وجود دارد، پس ارث نمی‌برد.';
      case HeirType.nieceFull:
        return isAsaba
            ? 'دخترِ برادرِ پدری و مادری از ذوی‌الأرحام است و در نبودِ عَصَبه، باقی‌ماندهٔ پس از سهم‌های فرض (یا تمام ترکه) را می‌برد.'
            : 'دخترِ برادرِ پدری و مادری از ذوی‌الأرحام است و نزدیک‌ترین خویشاوند بهتر از او وجود دارد، پس ارث نمی‌برد.';
      case HeirType.niecePaternal:
        return isAsaba
            ? 'دخترِ برادرِ پدری از ذوی‌الأرحام است و در نبودِ عَصَبه، باقی‌ماندهٔ پس از سهم‌های فرض (یا تمام ترکه) را می‌برد.'
            : 'دخترِ برادرِ پدری از ذوی‌الأرحام است و نزدیک‌ترین خویشاوند بهتر از او وجود دارد، پس ارث نمی‌برد.';
      case HeirType.paternalAunt:
        return isAsaba
            ? 'عمه (خواهرِ پدر) از ذوی‌الأرحام است و در نبودِ عَصَبه، باقی‌ماندهٔ پس از سهم‌های فرض (یا تمام ترکه) را می‌برد.'
            : 'عمه (خواهرِ پدر) از ذوی‌الأرحام است و نزدیک‌ترین خویشاوند بهتر از او وجود دارد، پس ارث نمی‌برد.';
      case HeirType.maternalUncle:
        return isAsaba
            ? 'دایی (برادرِ مادر) از ذوی‌الأرحام است و در نبودِ عَصَبه، باقی‌ماندهٔ پس از سهم‌های فرض (یا تمام ترکه) را می‌برد.'
            : 'دایی (برادرِ مادر) از ذوی‌الأرحام است و نزدیک‌ترین خویشاوند بهتر از او وجود دارد، پس ارث نمی‌برد.';
      case HeirType.maternalAunt:
        return isAsaba
            ? 'خاله (خواهرِ مادر) از ذوی‌الأرحام است و در نبودِ عَصَبه، باقی‌ماندهٔ پس از سهم‌های فرض (یا تمام ترکه) را می‌برد.'
            : 'خاله (خواهرِ مادر) از ذوی‌الأرحام است و نزدیک‌ترین خویشاوند بهتر از او وجود دارد، پس ارث نمی‌برد.';
      case HeirType.nephewSonFull:
        return 'پسرِ پسرِ برادرِ پدری و مادری «عصبه» است و در نبود پسر، پدر، برادر و پسرِ برادر، باقی‌مانده را می‌برد.';
      case HeirType.nephewSonPaternal:
        return 'پسرِ پسرِ برادرِ پدری «عصبه» است و در نبود پسرِ پسرِ برادرِ اشقی، باقی‌مانده را می‌برد.';
      case HeirType.paternalUncle:
        return 'عمو (برادر پدر) «عصبه» است و در صورت نبود پسر، پدر، برادر و پسرِ برادر، باقی‌مانده ترکه را می‌برد.';
      case HeirType.paternalUnclePaternal:
        return 'عموی پدری (برادر پدریِ پدر) «عصبه» است و در نبود عموی اشقی و پسرانش باقی‌مانده را می‌برد.';
      case HeirType.paternalUncleSon:
        return 'پسر عمو (پسر برادر پدر) «عصبه» است و در صورت نبود پسر، پدر، برادر، پسرِ برادر و عمو، باقی‌مانده ترکه را می‌برد.';
      case HeirType.paternalUncleSonPaternal:
        return 'پسر عموی پدری «عصبه» است و در نبود پسر عموی اشقی، باقی‌مانده را می‌برد.';
      case HeirType.paternalUncleGrandson:
        return 'پسرِ پسرِ عمو (پسرِ پسرِ برادرِ پدر) «عصبه» است و باقی‌مانده را می‌برد.';
      case HeirType.paternalUncleGrandsonPaternal:
        return 'پسرِ پسرِ عموی پدری «عصبه» است و باقی‌مانده را می‌برد.';
      case HeirType.fatherUncleFull:
        return 'عمویِ پدر (برادرِ پدربزرگِ پدری) «عصبه» است و در نبود پسر، پدر، برادر، پسرِ برادر، عمو و پسرعمو، باقی‌مانده را می‌برد.';
      case HeirType.fatherUnclePaternal:
        return 'عموی پدریِ پدر (برادرِ پدریِ پدربزرگ) «عصبه» است و در نبود عمویِ پدر اشقی، باقی‌مانده را می‌برد.';
      case HeirType.fatherCousinFull:
        return 'پسرِ عمویِ پدر (پسرِ برادرِ پدربزرگ) «عصبه» است و در نبود عمویِ پدر، باقی‌مانده را می‌برد.';
      case HeirType.fatherCousinPaternal:
        return 'پسرِ عمویِ پدریِ پدر «عصبه» است و در نبود پسرِ عمویِ پدر اشقی، باقی‌مانده را می‌برد.';
    }
  }
}

// ══════════════════════════════════════════════════════════
//  المحركات الخاصة بكل مذهب
// ══════════════════════════════════════════════════════════

/// المحرك الجمهوري (المعتمد في almwareeth.com)
class JumhurCalculator extends _BaseCalculator {
  JumhurCalculator() : super(Madhab.jumhur);
}

/// المحرك الحنفي
class HanafiCalculator extends _BaseCalculator {
  HanafiCalculator() : super(Madhab.hanafi);
}

/// المحرك المالكي
class MalikiCalculator extends _BaseCalculator {
  MalikiCalculator() : super(Madhab.maliki);
}

/// المحرك الشافعي
class ShafiiCalculator extends _BaseCalculator {
  ShafiiCalculator() : super(Madhab.shafii);
}

/// المحرك الحنبلي
class HanbaliCalculator extends _BaseCalculator {
  HanbaliCalculator() : super(Madhab.hanbali);
}

/// الحصول على المحرك المناسب حسب المذهب أو القانون.
MadhabCalculator getCalculator(Madhab madhab) {
  switch (madhab) {
    case Madhab.jumhur:
      return JumhurCalculator();
    case Madhab.hanafi:
      return HanafiCalculator();
    case Madhab.maliki:
      return MalikiCalculator();
    case Madhab.shafii:
      return ShafiiCalculator();
    case Madhab.hanbali:
      return HanbaliCalculator();
    // القوانين المدنية: نفس المحرك الأساسي، والقواعد الخاصة تُقرأ من
    // [MadhabRules] حسب القانون (baseMadhab + التعديلات الخاصة).
    case Madhab.egyptian:
    case Madhab.saudi:
    case Madhab.algerian:
    case Madhab.moroccan:
    case Madhab.jordanian:
    case Madhab.emirati:
    case Madhab.omani:
    case Madhab.kuwaiti:
    case Madhab.tunisia1956:
      return _BaseCalculator(madhab);
  }
}

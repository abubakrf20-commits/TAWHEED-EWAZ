import 'inheritance_calculator.dart';

/// جداول الفروض والحجب الخاصة بكل مذهب فقهي.
///
/// يحتوي على القواعد الفقهية المتفق عليها (الجمهور) والخلافات بين
/// المذاهب الأربعة: الحنفي، المالكي، الشافعي، الحنبلي.
class MadhabRules {
  MadhabRules._();

  // ══════════════════════════════════════════════════════════
  //  قوانين المواريث المدنية (الأحكام الخاصة بها)
  // ══════════════════════════════════════════════════════════

  /// هل [madhab] قانون مدني (وليست مذهبًا فقهيًا)؟
  static bool isLegalCode(Madhab madhab) {
    switch (madhab) {
      case Madhab.egyptian:
      case Madhab.saudi:
      case Madhab.algerian:
      case Madhab.moroccan:
      case Madhab.jordanian:
      case Madhab.emirati:
      case Madhab.omani:
      case Madhab.kuwaiti:
      case Madhab.tunisia1956:
        return true;
      default:
        return false;
    }
  }

  /// المذهب الفقهي الأساسي الذي تقوم عليه كل قانون مدني.
  ///
  /// تستخدم القوانين عمومًا قواعد أحد المذاهب مع تعديلات خاصة،
  /// لذا نرجع للمذهب الأساسي ثم نطبق التعديلات في الدوال أدناه.
  static Madhab baseMadhab(Madhab madhab) {
    switch (madhab) {
      case Madhab.egyptian:
      case Madhab.emirati:
      case Madhab.omani:
      case Madhab.kuwaiti:
        return Madhab.jumhur;
      case Madhab.saudi:
        return Madhab.hanbali;
      case Madhab.algerian:
      case Madhab.moroccan:
      case Madhab.tunisia1956:
        return Madhab.maliki;
      case Madhab.jordanian:
        return Madhab.hanafi;
      default:
        return madhab;
    }
  }

  // ══════════════════════════════════════════════════════════
  //  فروض الزوج والزوجة
  // ══════════════════════════════════════════════════════════

  /// سهم الزوج: 1/2 بدون فرع وارث، 1/4 معه (متفق عليه)
  static Frac husbandShare(bool hasFar3Warith) {
    return hasFar3Warith ? Frac(1, 4) : Frac(1, 2);
  }

  /// سهم الزوجة: 1/4 بدون فرع وارث، 1/8 معه (متفق عليه)
  static Frac wifeShare(bool hasFar3Warith) {
    return hasFar3Warith ? Frac(1, 8) : Frac(1, 4);
  }

  // ══════════════════════════════════════════════════════════
  //  فروض الأم
  // ══════════════════════════════════════════════════════════

  /// سهم الأم: 1/6 مع فرع وارث أو عدد إخوة، 1/3 بدونهما.
  /// الخلاف: حنفي → أخ واحد يكفي (1/6)؛ جمهور/شافعي/مالكي/حنبلي →
  /// أخوان اثنان فأكثر.
  static Frac motherShare(bool hasFar3Warith, int siblingCount, Madhab madhab) {
    if (hasFar3Warith) return Frac(1, 6);
    if (baseMadhab(madhab) == Madhab.hanafi) {
      return siblingCount >= 1 ? Frac(1, 6) : Frac(1, 3);
    }
    return siblingCount >= 2 ? Frac(1, 6) : Frac(1, 3);
  }

  // ══════════════════════════════════════════════════════════
  //  فروض الأب
  // ══════════════════════════════════════════════════════════

  /// سهم الأب: 1/6 مع فرع وارث، تعصيب بدونه (متفق عليه)
  static Frac fatherShare(bool hasFar3Warith) {
    return hasFar3Warith ? Frac(1, 6) : Frac.zero;
  }

  // ══════════════════════════════════════════════════════════
  //  فروض الجدّات
  // ══════════════════════════════════════════════════════════

  /// هل الجدة القريبة تحجب الجدة البعيدة من أي جهة كانت؟
  ///
  /// الجمهور (كما في almwareeth.com) والحنفي والحنبلي: الجدة القريبة
  /// (من أي جهة) تحجب البعيدة من كل الجهات.
  /// الشافعي والمالكي: أم الأم تحجب البعيدة من الجهتين، أما أم الأب
  /// فتحجب البعيدة من جهة الأب فقط (أم أب الأب وأم أم الأب).
  static bool nearGrandmotherHajbsAll(Madhab madhab) {
    return baseMadhab(madhab) != Madhab.shafii &&
        baseMadhab(madhab) != Madhab.maliki;
  }

  // ══════════════════════════════════════════════════════════
  //  فروض البنات
  // ══════════════════════════════════════════════════════════

  /// سهم البنت: 1/2 (بنت واحدة)، 2/3 (بنتان أو أكثر) بدون ابن.
  static Frac daughterShare(int count, bool hasSon) {
    if (hasSon) return Frac.zero; // التعصيب يتم لاحقًا
    if (count == 1) return Frac(1, 2);
    return Frac(2, 3);
  }

  // ══════════════════════════════════════════════════════════
  //  فروض الأخوات
  // ══════════════════════════════════════════════════════════

  /// سهم الأخت الشقيقة: 1/2 (واحدة)، 2/3 (اثنتان أو أكثر).
  /// لا يسقطها الأخ لأب؛ يسقطها الأب والابن والأخ الشقيق.
  static Frac fullSisterShare(int count) {
    if (count == 1) return Frac(1, 2);
    return Frac(2, 3);
  }

  /// سهم الأخت لأب: 1/2 (واحدة)، 2/3 (اثنتان أو أكثر)،
  /// ومع أخت شقيقة واحدة تأخذ 1/6 (تكملة الثلثين) في غير الحنفي.
  /// الحنفي: الأخت الشقيقة (ولو واحدة) تحجب الأخت لأب.
  static Frac paternalSisterShare(
      int count, int fullSisterCount, Madhab madhab) {
    if (fullSisterCount > 0) {
      if (baseMadhab(madhab) != Madhab.hanafi && fullSisterCount == 1) {
        return Frac(1, 6);
      }
      return Frac.zero;
    }
    if (count == 1) return Frac(1, 2);
    return Frac(2, 3);
  }

  /// سهم الإخوة لأم: 1/6 (واحد)، 1/3 (اثنان أو أكثر) في مجموعهم.
  /// شرط: لا أب ولا جد ولا فرع وارث (كلالة).
  static Frac maternalSiblingShare(int count) {
    if (count <= 1) return Frac(1, 6);
    return Frac(1, 3);
  }

  // ══════════════════════════════════════════════════════════
  //  الحجب (يختلف بين المذاهب)
  // ══════════════════════════════════════════════════════════

  /// الجد يحجب الإخوة في المذهب الحنفي فقط.
  ///
  /// كما أن القانون السعودي (نظام الأحوال الشخصية) جعل ميراث الجد
  /// كالأب فيحجب الإخوة — حسب الفقرة 3 من المادة 212.
  static bool grandfatherHajbsBrothers(Madhab madhab) {
    return madhab == Madhab.hanafi || madhab == Madhab.saudi;
  }

  // ══════════════════════════════════════════════════════════
  //  الرد (يختلف بين المذاهب)
  // ══════════════════════════════════════════════════════════

  /// هل يُرد على الزوجين؟
  ///
  /// - مذاهب الجمهور/حنفي/مالكي/شافعي/حنبلي والقوانين الأخرى: لا يُرد
  ///   عليهما (ما لم يكن وارثًا نسبيًا ولا ذو رحم في القانون المصري).
  /// - القانون الأردني (تعديل 2019): يُرد على أحد الزوجين مع غيره من
  ///   أصحاب الفروض.
  /// - تونس 1956 (فصل 143 مكرر): الرد شامل ويشمل الزوجين.
  static bool isSpouseRaddExempt(Madhab madhab) {
    return madhab != Madhab.jordanian && madhab != Madhab.tunisia1956;
  }

  /// هل يُرد على الإخوة لأم؟
  /// - جمهور/حنفي/شافعي/مالكي: لا يُرد عليهم
  /// - حنبلي (والقانون السعودي): يُرد عليهم
  /// - تونس 1956: الرد شامل لكل أصحاب الفروض فيُرد عليهم
  static bool isMaternalSiblingRaddExempt(Madhab madhab) =>
      madhab != Madhab.hanbali &&
      madhab != Madhab.saudi &&
      madhab != Madhab.tunisia1956;

  /// هل الوارث مستثنى من الرد؟
  static bool isRaddExempt(HeirType t, Madhab madhab) {
    if (t == HeirType.husband || t == HeirType.wife) {
      return isSpouseRaddExempt(madhab);
    }
    if (t == HeirType.maternalBrother || t == HeirType.maternalSister) {
      return isMaternalSiblingRaddExempt(madhab);
    }
    return false;
  }

  // ══════════════════════════════════════════════════════════
  //  المسألة المشتركة (المنبرية/الحمارية)
  // ══════════════════════════════════════════════════════════

  /// هل يُشرَك الإخوة الأشقاء مع الإخوة لأم في سهمهم (1/3)؟
  ///
  /// المشهور عند الجمهور (قول عمر وابن مسعود وزيد بن ثابت):
  /// الأشقاء يشاركون الإخوة لأم بالتساوي.
  /// الحنبلي (رأي علي) — وبه أخذ القانون السعودي: الأشقاء محرومون،
  /// فيأخذ أولاد الأم ثلثهم كاملًا.
  static bool applyMushtarak(Madhab madhab) => madhab != Madhab.saudi;

  // ══════════════════════════════════════════════════════════
  //  الغراوين (العمريتان) مع وجود الإخوة
  // ══════════════════════════════════════════════════════════

  /// في الغراوين (زوج/زوجة + أم + أب + إخوة) هل تأخذ الأم ثلث الأصل (الكل)؟
  ///
  /// - جمهور/حنفي/شافعي (قول عمر بن الخطاب): الأم تأخذ ثلث الباقي بعد الزوج.
  /// - مالكي/حنبلي (قول علي وزيد): عند وجود الإخوة الأم تأخذ ثلث الأصل.
  /// - القانون الجزائري يتبع المالكي، والقانون السعودي يتبع الحنبلي.
  /// - القانونان المغربي والتونسي أخذا قول عمر (ثلث الباقي).
  static bool gharrawainMotherThirdOfWhole(Madhab madhab) {
    return madhab == Madhab.maliki ||
        madhab == Madhab.hanbali ||
        madhab == Madhab.algerian ||
        madhab == Madhab.saudi;
  }

  // ══════════════════════════════════════════════════════════
  //  التعصيب
  // ══════════════════════════════════════════════════════════

  /// ترتيب العصبات بالنفس (22 درجة): من الابن إلى ابن عم الأب.
  static List<HeirType> asabaOrder() {
    return [
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
    ];
  }

  // ══════════════════════════════════════════════════════════
  //  مقاسمة الجد مع الإخوة (غير الحنفي)
  // ══════════════════════════════════════════════════════════

  /// مقاسمة الجد مع الإخوة عندما يجتمع معهم (بدون أب ولا فرع وارث).
  ///
  /// عند الجمهور (كما في almwareeth.com) يأخذ الجد الأفضل من ثلاثة:
  /// - المقاسمة في الباقي (يُعامل كأخ: للذكر سهمان) مع إدخال الإخوة لأب
  ///   في العدّ (المعادّة) ولو كانوا محجوبين (يقللون نصيبه في المقاسمة)،
  /// - ثلث الباقي بعد أصحاب الفروض،
  /// - سدس المال كله.
  /// ولا يزيد نصيبه على الباقي كله.
  ///
  /// ثم يقسم الباقي بين الإخوة الذين يرثون (الأشقاء يحجبون الإخوة لأب).
  static Map<HeirType, Frac>? calculateGrandfatherMuqasamah({
    required Madhab madhab,
    required Frac leftover,
    required int fullBrother,
    required int fullSister,
    required int paternalBrother,
    required int paternalSister,
  }) {
    if (grandfatherHajbsBrothers(madhab)) return null;
    if (fullBrother + fullSister + paternalBrother + paternalSister == 0) {
      return null;
    }

    // المعادّة: جميع الإخوة أشقاءً ولأب (ولو كانوا محجوبين) في العدّ.
    final heads =
        2 + fullBrother * 2 + fullSister + paternalBrother * 2 + paternalSister;
    Frac gfShare = leftover * Frac(2, heads);
    // الجد يأخذ الأفضل من المقاسمة أو ثلث الباقي أو سدس المال كله.
    final thirdOfRemainder = leftover / Frac(3, 1);
    final sixthOfWhole = Frac(1, 6);
    if (gfShare < thirdOfRemainder) gfShare = thirdOfRemainder;
    if (gfShare < sixthOfWhole) gfShare = sixthOfWhole;
    if (gfShare > leftover) gfShare = leftover;

    final result = <HeirType, Frac>{HeirType.grandfather: gfShare};
    final remaining = leftover - gfShare;
    if (remaining.isZero) return result;

    // الباقي يقسم بين الإخوة الوارثين: الأشقاء أولاً (2:1) ثم لأب.
    if (fullBrother > 0) {
      final wB = fullBrother * 2;
      final wS = fullSister;
      final tot = wB + wS;
      if (tot > 0) {
        result[HeirType.fullBrother] = remaining * Frac(wB, tot);
        if (wS > 0) result[HeirType.fullSister] = remaining * Frac(wS, tot);
      }
    } else if (fullSister > 0) {
      // «نُكمل للشقيقة فرضها وهو النصف» (أو الثلثان للاثنتين فأكثر):
      // تأخذ الأخت الشقيقة فرضها كاملاً مما كان سيأخذه الإخوة لأب
      // (الذين دخلوا في عدّ المعادّة)، وما تبقى بعد فرضها فهو للأخوة لأب.
      final Frac fard = fullSister == 1 ? Frac(1, 2) : Frac(2, 3);
      final sistersShare = remaining < fard ? remaining : fard;
      result[HeirType.fullSister] = sistersShare;
      final afterSisters = remaining - sistersShare;
      if (afterSisters.isPositive) {
        final wB = paternalBrother * 2;
        final wS = paternalSister;
        final tot = wB + wS;
        if (tot > 0) {
          result[HeirType.paternalBrother] = afterSisters * Frac(wB, tot);
          if (wS > 0) {
            result[HeirType.paternalSister] = afterSisters * Frac(wS, tot);
          }
        }
      }
    } else {
      final wB = paternalBrother * 2;
      final wS = paternalSister;
      final tot = wB + wS;
      if (tot > 0) {
        result[HeirType.paternalBrother] = remaining * Frac(wB, tot);
        if (wS > 0) {
          result[HeirType.paternalSister] = remaining * Frac(wS, tot);
        }
      }
    }
    return result;
  }
}

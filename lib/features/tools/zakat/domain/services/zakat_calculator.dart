import '../entities/zakat_input.dart';
import '../entities/zakat_result.dart';
import 'nisab_service.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// نام مذهب به فارسی.
String zakatMadhabLabel(ZakatMadhab m) {
  switch (m) {
    case ZakatMadhab.jumhur:
      return 'جمهور علما';
    case ZakatMadhab.hanbali:
      return 'حنابله';
    case ZakatMadhab.shafii:
      return 'شافعی';
    case ZakatMadhab.maliki:
      return 'مالکی';
    case ZakatMadhab.hanafi:
      return 'حنفی';
  }
}

/// نام مبنای نصاب به فارسی.
String zakatNisabBasisLabel(ZakatNisabBasis b) {
  switch (b) {
    case ZakatNisabBasis.auto:
      return 'خودکار (بر اساس مذهب)';
    case ZakatNisabBasis.gold:
      return 'طلا';
    case ZakatNisabBasis.silver:
      return 'نقره';
  }
}

/// موتور محاسبهٔ زکات بر پایهٔ قواعد فقهی چهار مذهب.
///
/// قواعد پیاده‌سازی‌شده:
/// - نصاب پول و دارایی: ارزش 85 گرم طلای خالص در جمهور/شافعی/مالکی؛
///   کمترینِ دو نصاب (طلا یا نقره) در حنبلی و حنفی.
/// - قاعدهٔ خلط: اگر طلا و نقره و پول هرکدام جدا به نصاب نرسند ولی جمعشان
///   برسد، به احترام مصلحت فقرا با کمترینِ دو نصاب حساب می‌شود.
/// - زکات عسل: یک‌دهم؛ نصاب ده قیرب ≈ 62 کیلوگرم (حنبلی و حنفی).
/// - زکات اسب: نصاب 5 رأس؛ یک‌چهارم یک‌دهم ارزش.
/// - گنج دوران جاهلیت (دفینه): یک‌پنجم (20٪) فوراً.
/// - دین مرجو (قوي): هر سال با حول و نصاب؛ دین غیرمرجو (ضعیف): پس از قبض برای یک سال.
/// - زکات دام: گوسفند/بز از 40، گاو از 30، شتر از 5 — با شرط حول و
///   سائمة بودن (مالکی سائمة را شرط نمی‌داند).
/// - زکات کشاورزی: از خود محصول؛ بارانی یک‌دهم، آبی یک‌بیستم؛ نصاب
///   5 وسق ≈ 653 کیلوگرم — حول شرط نیست.
class ZakatCalculator {
  ZakatCalculator._();

  /// ارقام لاتین برای پیام‌های جدول دام — هماهنگ با بندهای literal
  /// همین جدول ('2 گوساله'…).
  static String _en(int n) => '$n';

  /// تک‌منبع قیمت: فقط قیمتی که کاربر (یا دریافت آنلاین) وارد کرده است.
  ///
  /// هیچ قیمت پیش‌فرضی جای خالی را پر نمی‌کند؛ نبودِ قیمت یعنی «نصاب نامعلوم»
  /// ([ZakatResult.priceKnown] = false) و نه یک عدد ساختگی. همه‌جا (نصاب و
  /// ارزش دارایی) از همین دو تابع گرفته می‌شود تا قیمت رقیبی وجود نداشته باشد.
  static double goldPriceUsed(ZakatInput i) =>
      i.goldPricePerGram24 > 0 ? i.goldPricePerGram24 : 0;

  static double silverPriceUsed(ZakatInput i) =>
      i.silverPricePerGram > 0 ? i.silverPricePerGram : 0;

  /// ارزش نصاب طلا (85 گرم خالص) با قیمت معتبر.
  static double goldNisabValue(ZakatInput i) =>
      NisabService.nisabByGold(goldPriceUsed(i));

  /// ارزش نصاب نقره (595 گرم خالص) با قیمت معتبر.
  static double silverNisabValue(ZakatInput i) =>
      NisabService.nisabBySilver(silverPriceUsed(i));

  /// نصاب معتبر برای پول — تک‌منبع آستانهٔ نقدی در مسیر زنده.
  /// انتخاب صریح کاربر (طلا/نقره) بر قاعدهٔ مذهبی اولویت دارد؛ در حالت
  /// خودکار: حنفی نقره (595 گرم — مبنای مشهور احناف برای ورق/درهم)،
  /// حنبلی کمترینِ دو نصاب، و بقیه طلا (85 گرم).
  static double moneyNisabThreshold(ZakatInput i) {
    final gold = goldNisabValue(i);
    final silver = silverNisabValue(i);
    return switch (i.nisabBasis) {
      ZakatNisabBasis.gold => gold,
      ZakatNisabBasis.silver => silver,
      ZakatNisabBasis.auto => switch (i.madhab) {
          ZakatMadhab.hanafi => silver,
          ZakatMadhab.hanbali => gold < silver ? gold : silver,
          _ => gold,
        },
    };
  }

  /// آستانهٔ نقدی از دید «طلا یا نقره» برای برچسب نمایش — هم‌راستا با
  /// moneyNisabThreshold؛ در حالت خودکار از مذهب گرفته می‌شود.
  static bool _moneyBasisIsGold(ZakatInput i, double gold, double silver) {
    return switch (i.nisabBasis) {
      ZakatNisabBasis.gold => true,
      ZakatNisabBasis.silver => false,
      ZakatNisabBasis.auto => switch (i.madhab) {
          ZakatMadhab.hanafi => false,
          ZakatMadhab.hanbali => gold <= silver,
          _ => true,
        },
    };
  }

  /// تک‌منبع گرد‌کردن تعهد نقدی: به بالا تا واحد کامل (تومان، دلار، افغانی…)،
  /// چون زکات بر ذمه تا قطعی‌البرائت به بالا گرد می‌شود تا حق فقرا کم نشود
  /// (هم‌راستا با `due()` در PDF).
  static double _unitDue(double v) => v <= 0 ? 0 : v.ceilToDouble();

  /// مقدار زکات واجب روی دام‌ها به صورت توضیح فارسی.
  /// خالی = هیچ نصابی پر نشده.
  static String livestockDue(int sheep, int goats, int cows, int camels) {
    final parts = <String>[];

    // گوسفند و بز: نصاب از 40 رأس.
    final totalSG = sheep + goats;
    if (totalSG >= 40) {
      int due;
      if (totalSG <= 120) {
        due = 1;
      } else if (totalSG <= 200) {
        due = 2;
      } else if (totalSG <= 300) {
        due = 3;
      } else if (totalSG <= 400) {
        due = 4;
      } else if (totalSG <= 500) {
        due = 5;
      } else {
        // از 500 رأس به بعد، برای هر 100 رأس یک رأس اضافه می‌شود.
        due = 5 + ((totalSG - 500) ~/ 100);
      }
      parts.add('${_en(due)} گوسفند یک‌ساله');
    }

    // گاو: نصاب از 30 رأس. از 120 به بعد ترکیب دقیق گروه‌های 30 و 40
    // جستجو می‌شود تا نتیجه با علامت تقریبی نمایش داده نشود.
    if (cows >= 30) {
      if (cows <= 39) {
        parts.add('1 گوساله یک‌ساله (تیبع)');
      } else if (cows <= 59) {
        parts.add('1 گاو دو ساله (مسنّه)');
      } else if (cows <= 69) {
        parts.add('2 گوساله یک‌ساله');
      } else if (cows <= 79) {
        parts.add('1 گوساله یک‌ساله + 1 گاو دو ساله');
      } else if (cows <= 89) {
        parts.add('2 گاو دو ساله');
      } else if (cows <= 99) {
        parts.add('3 گوساله یک‌ساله');
      } else if (cows <= 109) {
        parts.add('2 گوساله یک‌ساله + 1 گاو دو ساله');
      } else if (cows <= 119) {
        parts.add('2 گاو دو ساله + 1 گوساله یک‌ساله');
      } else {
        final combination = _cattleCombination(cows);
        parts.add(combination);
      }
    }

    // شتر: نصاب از 5 رأس. از 130 به بعد، ترکیب‌ها باید بر اساس
    // گروه‌های 40تایی (بنت لبون) و 50تایی (حِقّه) کامل نمایش داده شوند.
    if (camels >= 5) {
      if (camels <= 9) {
        parts.add('1 گوسفند');
      } else if (camels <= 14) {
        parts.add('2 گوسفند');
      } else if (camels <= 19) {
        parts.add('3 گوسفند');
      } else if (camels <= 24) {
        parts.add('4 گوسفند');
      } else if (camels <= 35) {
        parts.add('1 شتر ماده یک‌ساله (بنت مخاض)');
      } else if (camels <= 45) {
        parts.add('1 شتر ماده دو ساله (بنت لبون)');
      } else if (camels <= 60) {
        parts.add('1 شتر ماده سه ساله (حِقّه)');
      } else if (camels <= 75) {
        parts.add('1 شتر ماده چهار ساله (جذعه)');
      } else if (camels <= 90) {
        parts.add('2 شتر ماده دو ساله (بنت لبون)');
      } else if (camels <= 120) {
        parts.add('2 شتر ماده سه ساله (حِقّه)');
      } else if (camels <= 129) {
        parts.add('3 شتر ماده دو ساله (بنت لبون)');
      } else if (camels <= 139) {
        parts.add('2 بنت لبون + 1 حِقّه');
      } else if (camels <= 149) {
        parts.add('1 بنت لبون + 2 حِقّه');
      } else if (camels <= 159) {
        parts.add('3 شتر ماده سه ساله (حِقّه)');
      } else if (camels <= 169) {
        parts.add('4 شتر ماده دو ساله (بنت لبون)');
      } else if (camels <= 179) {
        parts.add('3 بنت لبون + 1 حِقّه');
      } else if (camels <= 189) {
        parts.add('2 بنت لبون + 2 حِقّه');
      } else if (camels <= 199) {
        parts.add('1 بنت لبون + 3 حِقّه');
      } else {
        final bintLabun = camels ~/ 40;
        final hiqqa = camels ~/ 50;
        parts.add(
            'هر 40 رأس: ${_en(bintLabun)} بنت لبون یا هر 50 رأس: ${_en(hiqqa)} حِقّه');
      }
    }

    return parts.isNotEmpty ? parts.join('، ') : '';
  }

  static String _cattleCombination(int cows) {
    var bestCovered = -1;
    var bestTabi = 0;
    var bestMusinna = 0;

    for (var musinna = 0; musinna <= cows ~/ 40; musinna++) {
      for (var tabi = 0; tabi <= cows ~/ 30; tabi++) {
        final covered = tabi * 30 + musinna * 40;
        if (covered > cows || covered < bestCovered) continue;
        if (covered == bestCovered &&
            (tabi + musinna) >= (bestTabi + bestMusinna)) {
          continue;
        }
        bestCovered = covered;
        bestTabi = tabi;
        bestMusinna = musinna;
      }
    }

    if (bestCovered < 0) return 'به ترکیب استاندارد نرسیده است';
    final options = <String>[];
    if (bestTabi > 0) {
      options.add('${_en(bestTabi)} گوساله یک‌ساله');
    }
    if (bestMusinna > 0) {
      options.add('${_en(bestMusinna)} گاو دو ساله');
    }
    return options.join(' + ');
  }

  /// آیا تعداد دام‌ها به هر نصابی رسیده (بدون شرط‌های حول/سائمة)؟
  static bool livestockCountsReachNisab(
      int sheep, int goats, int cows, int camels) {
    return (sheep + goats >= 40) || (cows >= 30) || (camels >= 5);
  }

  /// نصاب دام با رعایت شرط سائمة (در مالکی شرط نیست).
  static bool livestockNisabMet(
      ZakatInput i, int sheep, int goats, int cows, int camels) {
    if (i.madhab != ZakatMadhab.maliki && !i.grazing) return false;
    return livestockCountsReachNisab(sheep, goats, cows, camels);
  }

  /// A money/weight figure as the reader sees it: Latin digits, grouped by
  /// thousands, two decimals only when there is a fraction.
  static String _round(double v) {
    if (v == v.roundToDouble()) return NumberFormat.grouped(v.round());
    return NumberFormat.groupDigits(v.toStringAsFixed(2));
  }

  /// محاسبهٔ کامل زکات بر اساس مذهب انتخابی.
  static ZakatResult calculate(ZakatInput i) {
    final u = i.currency.unit;
    final goldPrice = goldPriceUsed(i);
    final silverPrice = silverPriceUsed(i);

    // ── طلا و نقره (خلوص: عیار از 24 و عیار نقره از 1000) ──
    final goldPureGrams = i.goldGrams * (i.goldKarat / 24.0);
    final silverPureGrams = i.silverGrams * (i.silverFineness / 1000.0);
    final goldValue = goldPureGrams * goldPrice;
    final silverValue = silverPureGrams * silverPrice;

    final goldNisab = NisabService.nisabByGold(goldPrice);
    final silverNisab = NisabService.nisabBySilver(silverPrice);

    // مبنای نصاب پول: انتخاب صریح کاربر (طلا/نقره) و در حالت خودکار قاعدهٔ
    // مذهبی — حنفی همیشه نقره؛ حنبلی کمترین دو نصاب؛ بقیه طلا.
    final basisGold = _moneyBasisIsGold(i, goldNisab, silverNisab);

    // ── پول و کالای تجارت ──
    final monetaryAssets = i.cashAndBank + i.businessValue;
    final totalAssets = monetaryAssets + goldValue + silverValue;
    final netAssets = totalAssets - i.debts;

    // قاعدهٔ خلط (جمع طلا و نقره برای رسیدن به کمترین نصاب): تنها نزد
    // حنابله و احناف که جمع را جایز می‌دانند اعمال می‌شود. نزد شافعی و
    // مالکی (و در این ابزار «جمهور» با مبنای طلا) جمع جایز نیست و اعمال
    // نمی‌شود — با قول صحیح شافعی (عدم جمع) سازگار ماند.
    final combiningAllowed =
        i.madhab == ZakatMadhab.hanbali || i.madhab == ZakatMadhab.hanafi;
    final mixtureNisab = goldNisab < silverNisab ? goldNisab : silverNisab;
    final eachBelowNisab = goldValue < goldNisab && silverValue < silverNisab;
    final mixtureApplied = combiningAllowed &&
        mixtureNisab > 0 &&
        eachBelowNisab &&
        netAssets >= mixtureNisab &&
        netAssets > 0;
    final effectiveNisab =
        mixtureApplied ? mixtureNisab : moneyNisabThreshold(i);
    String basisLabel(bool gold) =>
        gold ? 'نصاب طلا — 85 گرم خالص' : 'نصاب نقره — 595 گرم خالص';
    final effectiveBasis = mixtureApplied
        ? (goldNisab < silverNisab
            ? 'کمترین دو نصاب (طلا)'
            : 'کمترین دو نصاب (نقره)')
        : basisLabel(basisGold);

    // نصاب نامعلوم: برای واحدهای غیرایرانی هیچ قیمت پیش‌فرضی فرض نمی‌شود.
    // اگر قیمت وارد نشده باشد نصاب صفر می‌شود و «دارایی ≥ ۰» نباید به
    // «زکات واجب شد» ترجمه شود — پس این حالت جدا و بسته (fail-closed) است.
    final priceKnown = effectiveNisab > 0;
    final meetsNisab = priceKnown && netAssets >= effectiveNisab;

    final monetaryZakat =
        (meetsNisab && i.hawlComplete) ? _unitDue(netAssets * 0.025) : 0.0;

    // ── گنج دوران جاهلیت: خمس ──
    final kanzZakat = _unitDue(i.kanzValue * 0.20);

    // ── دین: مرجو (قوي) و غير مرجو (ضعيف) ──
    // مرجو: كالمال الحاضر — يزكّى كل سنة إذا بلغ النصاب وحال الحول.
    // غير مرجو: لا زكاة حتى القبض، ثم لسنة واحدة؛ لذا لا يُحتسب فوراً
    // (المبلغ المحتمل يُعرض للتنبيه فقط).
    // آستانهٔ دینِ خوب‌طلب همان نصاب معتبر پول است (موثر/Nisab) — هم‌سان با
    // پول نقد؛ تغییر داده نشده چون درستی‌اش در فقه مرجّح است (دیدگاه، نه خطا).
    final friendlyDebtZakat =
        (priceKnown && i.friendlyDebt >= effectiveNisab && i.hawlComplete)
            ? _unitDue(i.friendlyDebt * 0.025)
            : 0.0;
    // مقدار محتمل پس از وصول (برای اطلاع)، نه واجبِ فوری
    final uglyDebtPotential = (priceKnown && i.uglyDebt >= effectiveNisab)
        ? _unitDue(i.uglyDebt * 0.025)
        : 0.0;
    final uglyDebtZakat = uglyDebtPotential; // نگهداری برای نمایشِ «پس از وصول»

    // ── عسل (حنبلی و حنفی) ──
    const honeyNisabKg = 62.0; // ده قیرب
    final honeyAllowed =
        i.madhab == ZakatMadhab.hanbali || i.madhab == ZakatMadhab.hanafi;
    final honeyNisabReached = honeyAllowed && i.honeyKg >= honeyNisabKg;
    final honeyZakatKg = honeyNisabReached ? i.honeyKg * 0.10 : 0.0;

    // ── اسب: زکات تنها نزد حنفی، و با شرط حول ──
    final horsesNisabMet = i.horses >= 5;
    final horsesZakatApplicable =
        i.madhab == ZakatMadhab.hanafi && i.hawlComplete && horsesNisabMet;
    final horsesZakatValue = horsesZakatApplicable
        ? _unitDue(i.horses * i.horsePricePerHead * 0.025)
        : 0.0;

    // ── دام (انعام) ──
    final livestockDesc = livestockDue(i.sheep, i.goats, i.cows, i.camels);
    final countsReachNisab =
        livestockCountsReachNisab(i.sheep, i.goats, i.cows, i.camels);
    final grazingConditionMet = i.madhab == ZakatMadhab.maliki || i.grazing;
    final livestockNisabOk =
        livestockNisabMet(i, i.sheep, i.goats, i.cows, i.camels);
    // وجوب زکات دام: نصاب + حول + سائمة (مالکی سائمة را شرط نمی‌داند).
    final hasLivestock =
        i.hawlComplete && livestockNisabOk && livestockDesc.isNotEmpty;
    final livestockDescription = hasLivestock
        ? (i.livestockDescriptionOverride.isNotEmpty
            ? i.livestockDescriptionOverride
            : livestockDesc)
        : '';

    // یادداشت‌های شرطی دام — همیشه وقتی تعداد دام وارد شده نمایش داده
    // می‌شوند تا کاربر نداند چرا نتیجه‌ای نگرفته.
    final livestockConditions = <String>[];
    if (countsReachNisab) {
      if (!i.hawlComplete) {
        livestockConditions.add('حول (یک سال قمری) هنوز کامل نشده است.');
      }
      if (!grazingConditionMet) {
        livestockConditions.add(
            'دام «سائمه» (چرانیده در چراگاه) نیست — در مذاهب غیر مالکی شرط است؛ '
            'گزینهٔ «دام سائمه است» را فعال کنید.');
      }
    }
    final grazingNote = livestockConditions.join(' ');

    // ── کشاورزی: زکات از خود محصول (حول شرط نیست) ──
    const agriNisabKg = 653.0; // پنج وسق
    final agriRate = i.irrigation == ZakatIrrigation.rain ? 0.10 : 0.05;
    final agricultureNisabReached =
        i.agricultureKg > 0 && i.agricultureKg >= agriNisabKg;
    final agricultureZakat =
        agricultureNisabReached ? i.agricultureKg * agriRate : 0.0;
    final agricultureZakatValue = agricultureZakat * i.agriculturePricePerKg;
    final cropsBelowNisab = i.agricultureKg > 0 && !agricultureNisabReached;
    final agriValueSuffix = i.agriculturePricePerKg > 0
        ? ' (≈ ${_round(agricultureZakatValue)} $u)'
        : '';

    // ── وضعیت‌های کمکی برای نمایش ──
    final goldOwnNisab =
        i.goldGrams > 0 && goldPureGrams >= NisabService.goldNisabGrams;
    final silverOwnNisab =
        i.silverGrams > 0 && silverPureGrams >= NisabService.silverNisabGrams;

    const zakatRate = 0.025;
    final breakdown = <String>[
      if (monetaryAssets > 0)
        'پول نقد، بانک و دارایی تجاری: ${_round(monetaryAssets)} $u',
      if (i.goldGrams > 0)
        'طلا: ${_round(goldPureGrams)} گرم خالص ≈ ${_round(goldValue)} $u${goldOwnNisab ? ' (از نصاب 85 گرم گذشته ✓)' : ''}',
      if (i.silverGrams > 0)
        'نقره: ${_round(silverPureGrams)} گرم خالص ≈ ${_round(silverValue)} $u${silverOwnNisab ? ' (از نصاب 595 گرم گذشته ✓)' : ''}',
      if (i.kanzValue > 0)
        'گنج (دفینهٔ جاهلیت): ${_round(i.kanzValue)} $u — یک‌پنجم (20٪): ${_round(kanzZakat)} $u',
      if (i.friendlyDebt > 0)
        'دین مرجو (قابل وصول — بدهکار توانا): ${_round(i.friendlyDebt)} $u — زکاتش همین حالا، هر سال با حول (2.5٪): ${_round(friendlyDebtZakat)} $u${!i.hawlComplete && friendlyDebtZakat == 0 ? ' (حول کامل نیست)' : ''}',
      if (i.uglyDebt > 0)
        'دین غیرمرجو (ضعیف/مشکوک — مفلس یا منکر): ${_round(i.uglyDebt)} $u — زکاتش پس از وصول، برای یک سال: ${_round(uglyDebtZakat)} $u (اکنون واجب نیست)',
      if (i.honeyKg > 0)
        'عسل: ${_round(i.honeyKg)} کیلوگرم — زکات (یک‌دهم): ${_round(honeyZakatKg)} کیلوگرم${honeyAllowed ? ' (حنبلی و حنفی — نزد شافعی/مالکی زکات ندارد)' : ' (در مذهب ${zakatMadhabLabel(i.madhab)} زکات ندارد)'}',
      if (i.horses > 0)
        'اسب: ${i.horses} رأس${horsesZakatValue > 0 ? ' — زکات (2.5٪ ارزش، با حول): ${_round(horsesZakatValue)} $u' : ''} ${i.madhab != ZakatMadhab.hanafi ? '(زکات اسب تنها نزد حنفی واجب است؛ در مذهب ${zakatMadhabLabel(i.madhab)} زکاتی ندارد)' : (!i.hawlComplete ? '(به نصاب 5 رأس رسیده اما حول کامل نیست)' : (!horsesNisabMet ? '(به نصاب 5 رأس نرسیده)' : ''))}',
      if (i.debts > 0) 'بدهی‌ها: -${_round(i.debts)} $u',
      '',
      'نصاب اعمال‌شده ($effectiveBasis) — مذهب ${zakatMadhabLabel(i.madhab)}: ${_round(effectiveNisab)} $u',
      if (mixtureApplied)
        'قاعدهٔ خلط (احتیاطی): جمع طلا، نقره و پول هیچ‌کدام جدا به نصاب نرسیده ولی مجموع به کمترین دو نصاب رسیده — به نفع فقیر با کمترین نصاب حساب شد. تذکر: قول صحیح شافعی عدم جمع است؛ این محاسبه برای برائت ذمه و احتیاط نگه داشته شده (مذهب انتخابی: ${zakatMadhabLabel(i.madhab)}).',
      if (countsReachNisab && hasLivestock) 'زکات دام: $livestockDescription',
      if (countsReachNisab && !hasLivestock && livestockConditions.isNotEmpty)
        'دام: نصاب تعداد پر شده اما زکات واجب نشده — ${livestockConditions.join(' ')}',
      if (agricultureZakat > 0)
        'زکات کشاورزی (${i.agricultureCropLabel}): ${_round(agricultureZakat)} کیلوگرم از خود محصول$agriValueSuffix',
      if (cropsBelowNisab)
        'محصول ${i.agricultureCropLabel} به نصاب نرسیده (5 وسق ≈ 653 کیلوگرم)؛ زکاتی ندارد.',
    ];

    // دین غیرمرجو فوری واجب نیست — فقط برای اطلاع پس از وصول
    final specialParts = <String>[
      if (kanzZakat > 0) 'گنج',
      if (friendlyDebtZakat > 0) 'دین مرجو (قابل وصول)',
      if (honeyZakatKg > 0) 'عسل',
      if (horsesZakatValue > 0) 'اسب',
    ];

    final parts = <String>[
      if (monetaryZakat > 0) 'پول، طلا و نقره',
      if (hasLivestock) 'دام',
      if (agricultureZakat > 0) 'کشاورزی',
      ...specialParts,
    ];

    String explanation;
    if (monetaryZakat > 0 ||
        hasLivestock ||
        agricultureZakat > 0 ||
        specialParts.isNotEmpty) {
      explanation = parts.isNotEmpty
          ? 'بر اساس مذهب ${zakatMadhabLabel(i.madhab)}، زکات در موارد زیر واجب شده است: ${parts.join('، ')}.'
          : 'بر اساس مذهب ${zakatMadhabLabel(i.madhab)}، در اموال واردشده زکاتی واجب نیست.';
    } else if (livestockConditions.isNotEmpty) {
      explanation =
          'تعداد دام‌ها به نصاب رسیده اما زکات دام واجب نشده چون: ${livestockConditions.join(' ')}';
    } else if (cropsBelowNisab && netAssets <= 0) {
      explanation =
          'محصول ${i.agricultureCropLabel} به نصاب زکات نرسیده (5 وسق ≈ 653 کیلوگرم)؛ پس زکاتی بر آن نیست.';
    } else if (!priceKnown) {
      explanation =
          'قیمت روز طلا و نقره وارد نشده است؛ نصاب زکات قابل محاسبه نیست. '
          'برای واحد «${i.currency.label}» قیمت پیش‌فرضی فرض نمی‌شود — '
          'قیمت هر گرم طلا و نقره را به $u وارد کنید.';
    } else if (!i.hawlComplete && netAssets > 0) {
      explanation =
          'حول (یک سال قمری) هنوز کامل نشده؛ تا کامل شدن آن زکات پول و دام واجب نمی‌شود.';
    } else {
      explanation =
          'دارایی به نصاب مورد نظر ($effectiveBasis: ${_round(effectiveNisab)} $u) نرسیده است.';
    }

    return ZakatResult(
      totalAssets: totalAssets,
      totalDebts: i.debts,
      netAssets: netAssets,
      goldValue: goldValue,
      goldPureGrams: goldPureGrams,
      silverValue: silverValue,
      silverPureGrams: silverPureGrams,
      cashAndBank: i.cashAndBank,
      businessValue: i.businessValue,
      nisabThreshold: effectiveNisab,
      nisabBasis: effectiveBasis,
      goldNisabValue: goldNisab,
      silverNisabValue: silverNisab,
      zakatAmount: monetaryZakat,
      zakatRate: zakatRate,
      livestockDescription: livestockDescription,
      agricultureZakat: agricultureZakat,
      agricultureZakatValue: agricultureZakatValue,
      agricultureRate: agriRate,
      agricultureNisabReached: agricultureNisabReached,
      livestockNisabMet: livestockNisabOk,
      meetsNisab: meetsNisab,
      hawlComplete: i.hawlComplete,
      madhab: i.madhab,
      kanzZakat: kanzZakat,
      friendlyDebtZakat: friendlyDebtZakat,
      uglyDebtZakat: uglyDebtZakat,
      honeyZakatKg: honeyZakatKg,
      honeyNisabReached: honeyNisabReached,
      horsesZakatValue: horsesZakatValue,
      horsesNisabMet: horsesNisabMet,
      mixtureApplied: mixtureApplied,
      mixtureDescription: mixtureApplied
          ? 'قاعدهٔ خلط (احتیاطی به نفع فقیر با کمترین دو نصاب) — قول صحیح شافعی عدم جمع است؛ برای برائت ذمه با کمترین نصاب حساب شد (مذهب انتخابی: ${zakatMadhabLabel(i.madhab)}).'
          : '',
      grazingNote: grazingNote,
      explanation: explanation,
      breakdownLines: breakdown,
      currency: i.currency,
      priceKnown: priceKnown,
    );
  }
}

import 'package:tawheeed/shared/models/app_currency.dart';

/// مذاهب معتبر در محاسبهٔ زکات (مطابق موسوعهٔ اسلامی).
enum ZakatMadhab {
  /// جمهور علما.
  jumhur,

  /// حنابله.
  hanbali,

  /// شافعیه.
  shafii,

  /// مالکیه.
  maliki,

  /// احناف.
  hanafi;

  /// بازیابی از prefs. نام ناشناخته یا خالی به پیش‌فرض تاریخی (جمهور) برمی‌گردد
  /// تا دادهٔ خراب یا نسخهٔ قدیمی هرگز صفحه را نشکند.
  static ZakatMadhab fromName(String? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return ZakatMadhab.jumhur;
  }
}

/// نوع آبیاری محصول: بارانی (یک‌دهم) یا آبیاری با ابزار (نیم‌دهم).
enum ZakatIrrigation { rain, irrigated }

/// مبنای نصاب پول.
/// - خودکار: از مذهب گرفته می‌شود (حنفی نقره، حنبلی کمترین، بقیه طلا) —
///   رفتار پیشین بدون تغییر.
/// - طلا/نقره: انتخاب صریح کاربر؛ بر محاسبهٔ مذهب اولویت دارد.
enum ZakatNisabBasis {
  auto,
  gold,
  silver;

  /// بازیابی از prefs؛ ناشناخته یعنی «خودکار» (رفتار پیشین).
  static ZakatNisabBasis fromName(String? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return ZakatNisabBasis.auto;
  }
}

class ZakatInput {
  final double cashAndBank;
  final double goldGrams;
  final int goldKarat;
  final double goldPricePerGram24;
  final double silverGrams;
  final int silverFineness;
  final double silverPricePerGram;
  final double businessValue;
  final double debts;
  final bool hawlComplete;

  // ── افزوده‌های موسوعهٔ اسلامی ──

  /// گنج دوران جاهلیت (دفینه): زکات آن یک‌پنجم است.
  final double kanzValue;

  /// دین قوی/مرجو (قابل وصول — بدهکار توانا و معترف): زکات آن هر سال
  /// اگر به نصاب برسد و حول کامل شود، مانند مال حاضر.
  final double friendlyDebt;

  /// دین ضعیف/غیرمرجو (مشکوک/مأیوس — بدهکار مفلس یا منکر): زکاتی ندارد
  /// تا زمانی که وصول شود، پس از وصول برای یک سال زکات دارد.
  final double uglyDebt;

  /// وزن عسل به کیلوگرم (فقط نزد حنابله و احناف).
  final double honeyKg;

  /// تعداد اسب‌ها (نصاب آن پنج رأس و بیشتر).
  final int horses;

  /// قیمت هر رأس اسب (به واحد پولی انتخابی).
  final double horsePricePerHead;

  /// دام سائمه است یا خیر؛ نزد مالکیه شرط سائمه بودن نیست.
  final bool grazing;

  /// تعداد گوسفند (بره) و بز.
  final int sheep;
  final int goats;

  /// تعداد گاو.
  final int cows;

  /// تعداد شتر.
  final int camels;

  // ── کشاورزی ──

  /// وزن محصول برداشت‌شده به کیلوگرم.
  final double agricultureKg;

  /// قیمت هر کیلوگرم (اختیاری — برای نمایش معادل پولی).
  final double agriculturePricePerKg;

  /// نوع آبیاری.
  final ZakatIrrigation irrigation;

  /// نام محصول برای نمایش در نتیجه (مثل «گندم»).
  final String agricultureCropLabel;

  /// توضیح آمادهٔ زکات دام به زبان فارسی (برای نمایش به‌جای توضیح پیش‌فرض).
  final String livestockDescriptionOverride;

  /// مذهب انتخاب‌شده برای محاسبهٔ زکات.
  final ZakatMadhab madhab;

  /// مبنای نصاب پول؛ خودکار یعنی از مذهب گرفته شود.
  final ZakatNisabBasis nisabBasis;

  /// واحد پولی که همهٔ مبالغ ورودی با آن بیان شده‌اند.
  ///
  /// محاسبه به آن وابسته نیست (همهٔ نسبت‌ها واحدless‌اند)، ولی قیمت پیش‌فرض
  /// و برچسب‌ها به آن بستگی دارند: قیمت‌های پیش‌فرض بازار ایران‌اند، پس برای
  /// واحد غیرایرانی هیچ قیمتی فرض نمی‌شود.
  final AppCurrency currency;

  const ZakatInput({
    this.cashAndBank = 0,
    this.goldGrams = 0,
    this.goldKarat = 24,
    this.goldPricePerGram24 = 0,
    this.silverGrams = 0,
    this.silverFineness = 1000,
    this.silverPricePerGram = 0,
    this.businessValue = 0,
    this.debts = 0,
    this.hawlComplete = false,
    this.kanzValue = 0,
    this.friendlyDebt = 0,
    this.uglyDebt = 0,
    this.honeyKg = 0,
    this.horses = 0,
    this.horsePricePerHead = 0,
    this.grazing = false,
    this.sheep = 0,
    this.goats = 0,
    this.cows = 0,
    this.camels = 0,
    this.agricultureKg = 0,
    this.agriculturePricePerKg = 0,
    this.irrigation = ZakatIrrigation.rain,
    this.agricultureCropLabel = '',
    this.livestockDescriptionOverride = '',
    this.madhab = ZakatMadhab.jumhur,
    this.nisabBasis = ZakatNisabBasis.auto,
    this.currency = AppCurrency.toman,
  });

  ZakatInput copyWith({
    double? cashAndBank,
    double? goldGrams,
    int? goldKarat,
    double? goldPricePerGram24,
    double? silverGrams,
    int? silverFineness,
    double? silverPricePerGram,
    double? businessValue,
    double? debts,
    bool? hawlComplete,
    double? kanzValue,
    double? friendlyDebt,
    double? uglyDebt,
    double? honeyKg,
    int? horses,
    double? horsePricePerHead,
    bool? grazing,
    int? sheep,
    int? goats,
    int? cows,
    int? camels,
    double? agricultureKg,
    double? agriculturePricePerKg,
    ZakatIrrigation? irrigation,
    String? agricultureCropLabel,
    String? livestockDescriptionOverride,
    ZakatMadhab? madhab,
    ZakatNisabBasis? nisabBasis,
    AppCurrency? currency,
  }) {
    return ZakatInput(
      cashAndBank: cashAndBank ?? this.cashAndBank,
      goldGrams: goldGrams ?? this.goldGrams,
      goldKarat: goldKarat ?? this.goldKarat,
      goldPricePerGram24: goldPricePerGram24 ?? this.goldPricePerGram24,
      silverGrams: silverGrams ?? this.silverGrams,
      silverFineness: silverFineness ?? this.silverFineness,
      silverPricePerGram: silverPricePerGram ?? this.silverPricePerGram,
      businessValue: businessValue ?? this.businessValue,
      debts: debts ?? this.debts,
      hawlComplete: hawlComplete ?? this.hawlComplete,
      kanzValue: kanzValue ?? this.kanzValue,
      friendlyDebt: friendlyDebt ?? this.friendlyDebt,
      uglyDebt: uglyDebt ?? this.uglyDebt,
      honeyKg: honeyKg ?? this.honeyKg,
      horses: horses ?? this.horses,
      horsePricePerHead: horsePricePerHead ?? this.horsePricePerHead,
      grazing: grazing ?? this.grazing,
      sheep: sheep ?? this.sheep,
      goats: goats ?? this.goats,
      cows: cows ?? this.cows,
      camels: camels ?? this.camels,
      agricultureKg: agricultureKg ?? this.agricultureKg,
      agriculturePricePerKg:
          agriculturePricePerKg ?? this.agriculturePricePerKg,
      irrigation: irrigation ?? this.irrigation,
      agricultureCropLabel: agricultureCropLabel ?? this.agricultureCropLabel,
      livestockDescriptionOverride:
          livestockDescriptionOverride ?? this.livestockDescriptionOverride,
      madhab: madhab ?? this.madhab,
      nisabBasis: nisabBasis ?? this.nisabBasis,
      currency: currency ?? this.currency,
    );
  }
}

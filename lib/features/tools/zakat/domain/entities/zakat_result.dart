import 'package:tawheeed/shared/models/app_currency.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'zakat_input.dart';

class ZakatResult {
  final double totalAssets;
  final double totalDebts;
  final double netAssets;
  final double goldValue;
  final double goldPureGrams;
  final double silverValue;
  final double silverPureGrams;
  final double cashAndBank;
  final double businessValue;
  final double nisabThreshold;
  final String nisabBasis;
  final double goldNisabValue;
  final double silverNisabValue;
  final double zakatAmount;
  final double zakatRate;
  final String livestockDescription;

  /// زکات کشاورزی به کیلوگرم (از خود محصول برداشت می‌شود).
  final double agricultureZakat;

  /// معادل پولی زکات کشاورزی به واحد انتخابی (در صورت وارد کردن قیمت هر کیلوگرم).
  final double agricultureZakatValue;

  /// نرخ زکات کشاورزی (0.10 بارانی / 0.05 آبی).
  final double agricultureRate;

  /// آیا محصول برداشت‌شده به نصاب (5 وسق ≈ 653 کیلوگرم) رسیده است.
  final bool agricultureNisabReached;
  final bool meetsNisab;
  final bool livestockNisabMet;
  final bool hawlComplete;
  final String explanation;
  final List<String> breakdownLines;

  // ── افزوده‌های موسوعهٔ اسلامی ──

  /// مذهبی که زکات بر اساس آن محاسبه شده است.
  final ZakatMadhab madhab;

  /// زکات گنج دوران جاهلیت (یک‌پنجم).
  final double kanzZakat;

  /// زکات دین مرجو/قوی — هر سال با حول و نصاب، فوراً واجب.
  final double friendlyDebtZakat;

  /// زکات دین غیرمرجو/ضعیف — تا وصول واجب نیست، پس از وصول برای یک سال.
  /// این مقدار «محتمل پس از وصول» است و در جمع فوری حساب نمی‌شود.
  final double uglyDebtZakat;

  /// زکات عسل به کیلوگرم (یک‌دهم).
  final double honeyZakatKg;
  final bool honeyNisabReached;

  /// زکات اسب (2.5٪ از ارزش اسب‌ها).
  final double horsesZakatValue;
  final bool horsesNisabMet;

  /// آیا قاعدهٔ خلطه اعمال شده است (جمع طلا، نقره و پول به نصاب رسیده)؟
  final bool mixtureApplied;
  final String mixtureDescription;

  /// یادداشت شرط سائمه بودن دام (مالکیه آن را شرط نمی‌داند).
  final String grazingNote;

  /// واحد پولی که همهٔ مبالغ این نتیجه با آن بیان شده‌اند.
  final AppCurrency currency;

  /// آیا نصاب قابل محاسبه بود؟
  ///
  /// برای واحدهای غیرایرانی هیچ قیمت پیش‌فرضی فرض نمی‌شود؛ اگر کاربر قیمت
  /// طلا/نقره را وارد نکرده باشد نصاب صفر می‌شود و «دارایی ≥ صفر» هرگز
  /// نباید به «زکات واجب شد» ترجمه شود. این پرچم همان حالت را جدا می‌کند.
  final bool priceKnown;

  /// کلمهٔ واحد پول برای متن‌های این نتیجه.
  String get unit => currency.unit;

  const ZakatResult({
    required this.totalAssets,
    required this.totalDebts,
    required this.netAssets,
    required this.goldValue,
    required this.goldPureGrams,
    required this.silverValue,
    this.silverPureGrams = 0,
    required this.cashAndBank,
    required this.businessValue,
    required this.nisabThreshold,
    required this.nisabBasis,
    this.goldNisabValue = 0,
    this.silverNisabValue = 0,
    required this.zakatAmount,
    required this.zakatRate,
    this.livestockDescription = '',
    this.agricultureZakat = 0,
    this.agricultureZakatValue = 0,
    this.agricultureRate = 0,
    this.agricultureNisabReached = false,
    required this.meetsNisab,
    this.livestockNisabMet = false,
    required this.hawlComplete,
    required this.explanation,
    required this.breakdownLines,
    this.madhab = ZakatMadhab.jumhur,
    this.kanzZakat = 0,
    this.friendlyDebtZakat = 0,
    this.uglyDebtZakat = 0,
    this.honeyZakatKg = 0,
    this.honeyNisabReached = false,
    this.horsesZakatValue = 0,
    this.horsesNisabMet = false,
    this.mixtureApplied = false,
    this.mixtureDescription = '',
    this.grazingNote = '',
    this.currency = AppCurrency.toman,
    this.priceKnown = true,
  });

  bool get hasLivestockZakat => livestockDescription.isNotEmpty;
  bool get hasAgricultureZakat => agricultureZakat > 0;
  bool get hasMonetaryZakat => zakatAmount > 0;
  bool get hasSpecialZakat =>
      kanzZakat > 0 || friendlyDebtZakat > 0 || hasHoneyZakat || hasHorsesZakat;

  /// دین غیرمرجو فقط پس از قبض و برای یک سال — واجبِ فوری نیست، فقط
  /// برای اطلاع نمایش داده می‌شود.
  bool get hasDeferredDebtInfo => uglyDebtZakat > 0;
  bool get hasHoneyZakat => honeyZakatKg > 0;
  bool get hasHorsesZakat => horsesZakatValue > 0;

  /// مجموع زکات‌های نقدی (به واحد انتخابی) — پول/طلا/نقره + گنج + دین مرجو + اسب.
  /// دام و کشاورزی در این جمع نیستند چون به‌صورت جنس (head/kg) ادا می‌شوند.
  double get totalCashZakat =>
      zakatAmount + kanzZakat + friendlyDebtZakat + horsesZakatValue;

  bool get hasZakat =>
      hasMonetaryZakat ||
      hasLivestockZakat ||
      hasAgricultureZakat ||
      hasSpecialZakat ||
      hasHoneyZakat ||
      hasHorsesZakat;

  String toSummaryText() {
    final buf = StringBuffer();
    final u = unit;
    buf.writeln('محاسبه زکات');
    buf.writeln('─────────────');
    buf.writeln('دارایی کل: ${NumberFormat.formatMoney(totalAssets, u)}');
    if (totalDebts > 0) {
      buf.writeln('بدهی‌ها: ${NumberFormat.formatMoney(totalDebts, u)}');
    }
    buf.writeln('خالص دارایی: ${NumberFormat.formatMoney(netAssets, u)}');
    if (priceKnown) {
      buf.writeln(
          'نصاب ($nisabBasis): ${NumberFormat.formatMoney(nisabThreshold, u)}');
    } else {
      buf.writeln('نصاب: قیمت روز طلا/نقره وارد نشده است — قابل محاسبه نیست.');
    }
    buf.writeln('─────────────');
    if (totalCashZakat > 0) {
      buf.writeln(
          'جمع زکات نقدی: ${NumberFormat.formatMoney(totalCashZakat, u)}');
    }
    if (zakatAmount > 0) {
      buf.writeln(
          'زکات نقدی (2.5%): ${NumberFormat.formatMoney(zakatAmount, u)}');
    }
    if (hasLivestockZakat) {
      buf.writeln('زکات دام: $livestockDescription');
    }
    if (hasAgricultureZakat) {
      final agriUnit = agricultureZakatValue > 0
          ? ' کیلوگرم (≈ ${NumberFormat.formatMoney(agricultureZakatValue, u)})'
          : ' کیلوگرم از محصول';
      buf.writeln(
          'زکات کشاورزی: ${NumberFormat.formatPlain(agricultureZakat)}$agriUnit');
    }
    if (!hasZakat) {
      buf.writeln(explanation);
    }
    return buf.toString();
  }
}

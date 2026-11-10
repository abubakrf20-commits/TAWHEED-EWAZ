import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/shared/utils/hijri_utils.dart';
import 'package:tawheeed/core/design_system/components/components.dart'
    hide SectionHeader;
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/shared/widgets/app_snack_bar.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/shared/widgets/number_input_formatters.dart';
import 'package:tawheeed/shared/utils/shamsi_date_picker.dart';
import 'package:tawheeed/features/education/presentation/widgets/education_widgets.dart';
import 'package:tawheeed/features/home/presentation/utils/date_formatters.dart';
import 'package:tawheeed/features/tools/zakat/data/zakat_data.dart';
import 'package:tawheeed/features/tools/zakat/data/zakat_price_store.dart';
import 'package:tawheeed/shared/models/app_currency.dart';
import 'package:tawheeed/shared/services/currency_store.dart';
import 'package:tawheeed/features/tools/zakat/domain/entities/zakat_input.dart';
import 'package:tawheeed/features/tools/zakat/domain/entities/zakat_result.dart';
import 'package:tawheeed/features/tools/zakat/domain/services/zakat_calculator.dart';
import 'package:tawheeed/features/tools/zakat/presentation/widgets/zakat_report_pdf.dart';
import 'package:tawheeed/features/tools/shared/pdf_report_util.dart';

import 'package:tawheeed/features/tools/zakat/presentation/widgets/zakat/zakat_info_tabs.dart';
import 'package:tawheeed/features/tools/zakat/presentation/widgets/zakat/zakat_result_card.dart';
import 'package:tawheeed/features/tools/zakat/presentation/providers/zakat_price_provider.dart';

class ZakatScreen extends StatelessWidget {
  const ZakatScreen({super.key, this.initialCashAmount, this.initialCashUnit});

  /// When set (e.g. from the expenses report «محاسبه زکات این موجودی»),
  /// the cash field of the calculator is prefilled with this amount.
  final double? initialCashAmount;

  /// The unit [initialCashAmount] was counted in. When it is set and differs
  /// from the unit the calculator resolves to, the prefill is dropped: a bare
  /// number from another unit would be compared against a nisab expressed in
  /// this one, which is a wrong answer, not a cosmetic one.
  final AppCurrency? initialCashUnit;

  static const Color _accent = TopicHues.zakat;

  static const List<String> _tabs = [
    'محاسبه',
    'آشنایی',
    'شرایط و اموال',
    'نصاب',
    'مصارف',
    'احکام معاصر',
    'پرسش‌ها',
  ];

  /// The whole reading half of the page, indexed for the in-section search.
  ///
  /// The calculator tab (0) is deliberately absent: it has no prose, and a hit
  /// that lands on an empty form is a false promise. Everything a reader would
  /// actually go looking for is here — including the FAQ, whose question is the
  /// title, because that is the phrase someone types.
  static List<SectionSearchEntry> _buildSearchEntries() {
    SectionSearchEntry of(
      int tab,
      String tabLabel,
      Map<String, dynamic> row, {
      String titleKey = 'title',
      String bodyKey = 'body',
    }) =>
        SectionSearchEntry(
          tab: tab,
          tabLabel: tabLabel,
          title: row[titleKey] as String? ?? '',
          body: row[bodyKey] as String? ?? '',
        );

    return [
      for (final row in ZakatContent.intro) of(1, 'آشنایی', row),
      for (final row in ZakatContent.conditions) of(2, 'شرایط و اموال', row),
      for (final row in ZakatContent.assetTypes) of(2, 'شرایط و اموال', row),
      for (final row in ZakatContent.nisab) of(3, 'نصاب', row),
      for (final row in ZakatContent.recipients) of(4, 'مصارف', row),
      for (final row in ZakatContent.contemporary) of(5, 'احکام معاصر', row),
      for (final row in ZakatContent.specialRulings) of(5, 'احکام معاصر', row),
      for (final row in ZakatContent.faq)
        of(6, 'پرسش‌ها', row, titleKey: 'question', bodyKey: 'answer'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final entries = _buildSearchEntries();
    return SectionPage(
      id: 'zakat',
      title: 'زکات',
      tabs: _tabs,
      searchEntries: entries.isEmpty ? null : entries,
      children: [
        _CalculatorTab(
          initialCash: initialCashAmount,
          initialCashUnit: initialCashUnit,
        ),
        const IntroTab(),
        const ConditionsTab(),
        const NisabTab(),
        const RecipientsTab(),
        const ContemporaryTab(),
        const FaqTab(),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAB 0: CALCULATOR
// ════════════════════════════════════════════════════════════════
class _CalculatorTab extends ConsumerStatefulWidget {
  const _CalculatorTab({this.initialCash, this.initialCashUnit});

  final double? initialCash;

  /// Unit of [initialCash] when the caller knows it (the expenses report does).
  final AppCurrency? initialCashUnit;

  @override
  ConsumerState<_CalculatorTab> createState() => _CalculatorTabState();
}

class _CalculatorTabState extends ConsumerState<_CalculatorTab> {
  static const _goldColor = Color(0xFFC9A94E);
  static const _silverColor = Color(0xFF8E9AAF);
  static const _dollarColor = Color(0xFF2E86AB);
  Color get _cashColor => Theme.of(context).brightness == Brightness.dark
      ? AppTheme.darkSuccess
      : AppTheme.lightSuccess;
  static const _tradeColor = Color(0xFF7C4DFF);
  final _cashCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();
  final _savingsCtrl = TextEditingController();
  final _goldWeightCtrl = TextEditingController();
  final _goldKaratCtrl = TextEditingController(text: '18');
  final _silverWeightCtrl = TextEditingController();
  final _silverFinenessCtrl = TextEditingController(text: '1000');
  final _goldPriceCtrl = TextEditingController();
  final _silverPriceCtrl = TextEditingController();
  final _dollarPriceCtrl = TextEditingController();
  final _dollarHoldingsCtrl = TextEditingController();
  final _businessCtrl = TextEditingController();
  final _debtsCtrl = TextEditingController();
  final _otherCtrl = TextEditingController();
  final _kanzCtrl = TextEditingController();
  final _friendlyDebtCtrl = TextEditingController();
  final _uglyDebtCtrl = TextEditingController();
  final _honeyCtrl = TextEditingController();
  final _horseCtrl = TextEditingController();
  final _horsePriceCtrl = TextEditingController();
  final _sheepCtrl = TextEditingController();
  final _goatCtrl = TextEditingController();
  final _cowCtrl = TextEditingController();
  final _camelCtrl = TextEditingController();
  final _agriAmountCtrl = TextEditingController();
  final _agriPriceCtrl = TextEditingController();
  String _selectedIrrigationType = 'بارانی';
  String _selectedCropType = 'گندم';
  bool _showLivestockTable = false;
  bool _hawlComplete = false;
  bool _grazing = false;
  ZakatMadhab _madhab = ZakatMadhab.jumhur;
  ZakatNisabBasis _nisabBasis = ZakatNisabBasis.auto;

  /// مذهب و مبنای نصاب **تنظیم** هستند، نه دادهٔ واردشده: هر بار برگشتن به
  /// «جمهور / خودکار» کاربری را که آگاهانه حنفی یا نقره را انتخاب کرده بود
  /// وادار می‌کرد هر بار دوباره انتخاب کند — و اگر یادش می‌رفت، نصاب بی‌صدا
  /// عوض می‌شد.
  static const String _madhabKey = 'zakat_madhab';
  static const String _nisabBasisKey = 'zakat_nisab_basis';

  /// واحد پولی که همهٔ مبالغ با آن وارد می‌شوند. پیش‌فرض تومان است تا رفتار
  /// نسخه‌های قبلی عوض نشود.
  ///
  /// این واحد بین ابزارهای مالی **مشترک** است ([CurrencyStore.calculators]):
  /// کسی که زکاتش را به افغانی حساب می‌کند، زکات فطر و میراثش هم افغانی است.
  AppCurrency _currency = AppCurrency.toman;

  /// کلمهٔ واحد برای برچسب فیلدها («تومان»، «دلار»…).
  String get _unit => _currency.unit;

  /// Stored Gregorian start of the hawl (lunar year) as epoch millis. When set,
  /// [_hawlComplete] is derived automatically from an exact Hijri year rather
  /// than the manual checkbox.
  static const String _hawlStartKey = 'zakat_hawl_start_ms';
  int? _hawlStartMs;
  final _scrollCtrl = ScrollController();
  ZakatResult? _result;
  int _pricesUpdatedAt = 0;
  bool _showAdvanced = false;

  /// مبلغ پیش‌پر به واحد دیگری بود و دور ریخته شد (توضیحش زیر فیلد نقدی).
  bool _prefillDropped = false;

  /// مبلغی که از صفحهٔ دیگری (گزارش هزینه‌ها) آمده و هنوز در فیلد ننشسته،
  /// چون واحدش تا پایان خواندن انبار روشن نیست.
  double? _pendingCash;
  final List<TextEditingController> _allControllers = [];

  void _onInputChanged() {
    if (_result != null) setState(() => _result = null);
  }

  void _setupClearOnInput() {
    for (final c in _allControllers) {
      c.addListener(_onInputChanged);
    }
  }

  @override
  void initState() {
    super.initState();
    // The prefill is NOT written into the field here: the unit is not known
    // yet (the store read is async), and showing an amount before knowing what
    // it is counted in is exactly the mislabelling this guard exists to stop.
    // _loadCurrency applies it as soon as the unit is resolved.
    final cash = widget.initialCash;
    if (cash != null && cash > 0) _pendingCash = cash;
    _loadSavedPrices();
    _loadCurrency();
    _loadFiqhSettings();
    _loadHawlStart();
    final cs = [
      _cashCtrl,
      _bankCtrl,
      _savingsCtrl,
      _goldWeightCtrl,
      _goldKaratCtrl,
      _silverWeightCtrl,
      _silverFinenessCtrl,
      _goldPriceCtrl,
      _silverPriceCtrl,
      _dollarPriceCtrl,
      _dollarHoldingsCtrl,
      _businessCtrl,
      _debtsCtrl,
      _otherCtrl,
      _kanzCtrl,
      _friendlyDebtCtrl,
      _uglyDebtCtrl,
      _honeyCtrl,
      _horseCtrl,
      _horsePriceCtrl,
      _sheepCtrl,
      _goatCtrl,
      _cowCtrl,
      _camelCtrl,
      _agriAmountCtrl,
      _agriPriceCtrl,
    ];
    _allControllers.addAll(cs);
    _setupClearOnInput();
    CurrencyStore.calculators.notifier.addListener(_onStoreCurrencyChanged);
  }

  @override
  void dispose() {
    CurrencyStore.calculators.notifier.removeListener(_onStoreCurrencyChanged);
    for (final c in _allControllers) {
      c.removeListener(_onInputChanged);
    }
    for (final c in _allControllers) {
      c.dispose();
    }
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSavedPrices() async {
    // Capture the unit first: a currency switch may land while the read is in
    // flight, and writing the old unit's prices into the new unit's fields
    // would be exactly the mis-reading this store exists to prevent.
    final code = _currency.code;
    final SavedZakatPrices? saved;
    try {
      saved = await ZakatPriceStore.load(currencyCode: code);
    } catch (e) {
      // A failed read is not a reason to lose the calculator: the fields stay
      // as the user left them and the nisab falls back to the shipped default.
      // But it must leave a trace, because the default is not the real price.
      AppLogger.warning('zakat_screen', 'saved prices load failed: $e');
      return;
    }
    if (!mounted || code != _currency.code) return;
    setState(() {
      // قیمت‌های ذخیره‌شدهٔ واحد دیگر نباید در فیلدهای این واحد بمانند.
      _goldPriceCtrl.text = saved != null && saved.goldPerGram > 0
          ? NumberFormat.formatPlain(saved.goldPerGram)
          : '';
      _silverPriceCtrl.text = saved != null && saved.silverPerGram > 0
          ? NumberFormat.formatPlain(saved.silverPerGram)
          : '';
      _dollarPriceCtrl.text = saved != null && saved.dollarPrice > 0
          ? NumberFormat.formatPlain(saved.dollarPrice)
          : '';
      _pricesUpdatedAt = saved?.updatedAt ?? 0;
    });
  }

  /// Best-effort persistence of the market prices the user just typed.
  ///
  /// It runs *after* the answer is on screen, and it cannot fail the
  /// calculation: pressing «محاسبه» used to await this write first, so a
  /// throwing prefs write aborted the method before `setState` — the result
  /// had already been computed and was then discarded, and the button looked
  /// dead. A stale saved price is a much smaller loss than no answer at all.
  Future<void> _rememberPrices({
    required double gold,
    required double silver,
    required double dollar,
  }) async {
    try {
      final existing = await ZakatPriceStore.load(currencyCode: _currency.code);
      await ZakatPriceStore.save(
        goldPerGram: gold > 0 ? gold : (existing?.goldPerGram ?? 0),
        silverPerGram: silver > 0 ? silver : (existing?.silverPerGram ?? 0),
        dollarPrice: dollar > 0 ? dollar : (existing?.dollarPrice ?? 0),
        currencyCode: _currency.code,
      );
      if (!mounted) return;
      // Only now may the banner claim a fresh update — a failed write must not
      // leave it saying «همین حالا به‌روز شد» over prices that never landed.
      setState(
          () => _pricesUpdatedAt = DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      AppLogger.warning('zakat_screen', 'price save failed: $e');
    }
  }

  Future<void> _loadCurrency() async {
    final c = await CurrencyStore.calculators.load();
    if (!mounted) return;
    if (c != _currency) {
      setState(() => _currency = c);
      await _loadSavedPrices();
    }
    _applyPendingCash();
  }

  /// مبلغ پیش‌پر از صفحهٔ دیگری آمده و واحدش هم اعلام شده است. اگر واحد
  /// حساب‌گر چیز دیگری باشد، عدد بی‌برچسب می‌ماند و نصاب با مبلغ اشتباه سنجیده
  /// می‌شود؛ پس در فیلد گذاشته نمی‌شود و دلیلش زیر فیلد نوشته می‌شود. اگر
  /// بعداً واحد هم‌واحد شد، همان مبلغ (که هنوز نگه داشته شده) می‌نشیند.
  void _applyPendingCash() {
    final cash = _pendingCash;
    if (cash == null) return;
    final from = widget.initialCashUnit;
    final matches = from == null || from == _currency;
    if (!matches) {
      if (_prefillDropped) return;
      setState(() => _prefillDropped = true);
      return;
    }
    _pendingCash = null;
    if (_cashCtrl.text.isNotEmpty) return; // the user has typed their own number
    _cashCtrl.text = cash == cash.truncateToDouble()
        ? cash.toInt().toString()
        : cash.toString();
    if (_prefillDropped) setState(() => _prefillDropped = false);
  }

  Future<void> _loadFiqhSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final madhab = ZakatMadhab.fromName(prefs.getString(_madhabKey));
      final basis = ZakatNisabBasis.fromName(prefs.getString(_nisabBasisKey));
      if (madhab == _madhab && basis == _nisabBasis) return;
      setState(() {
        _madhab = madhab;
        _nisabBasis = basis;
        _result = null;
      });
    } catch (e) {
      AppLogger.warning('zakat_screen', 'fiqh settings load failed: $e');
    }
  }

  Future<void> _saveFiqhSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_madhabKey, _madhab.name);
      await prefs.setString(_nisabBasisKey, _nisabBasis.name);
    } catch (e) {
      // Not a cosmetic setting: the madhab decides the nisab, so a save that
      // silently failed means the reader sees their school selected while the
      // next open computes by the default one. Say it.
      AppLogger.warning('zakat_screen', 'fiqh settings save failed: $e');
      if (!mounted) return;
      AppSnackBar.error(
        context,
        'تنظیمات مذهب ذخیره نشد؛ با باز شدن دوباره، مقدار قبلی برمی‌گردد.',
        onRetry: _saveFiqhSettings,
      );
    }
  }

  /// واحد تازه را روی همین صفحه اعمال می‌کند.
  ///
  /// تنها مسیرش ردیف «واحد حساب‌گرها» در تنظیمات است؛ این صفحه چیپ واحد ندارد
  /// و چیزی نمی‌نویسد — واحد پول فقط از تنظیمات عوض می‌شود.
  void _applyCurrency(AppCurrency c) {
    setState(() {
      _currency = c;
      _result = null;
      _goldPriceCtrl.clear();
      _silverPriceCtrl.clear();
      _dollarPriceCtrl.clear();
      _dollarHoldingsCtrl.clear();
      _pricesUpdatedAt = 0;
    });
  }

  /// تغییر واحد از صفحهٔ تنظیمات. این صفحه در تب دیگری زنده می‌ماند، پس بدون
  /// گوش دادن به انبار، فیلدها و نتیجه با واحد قدیمی روی صفحه می‌مانند در
  /// حالی که تنظیمات واحد تازه را ذخیره کرده است.
  void _onStoreCurrencyChanged() {
    final next = CurrencyStore.calculators.notifier.value;
    if (!mounted || next == _currency) return;
    _applyCurrency(next);
    _loadSavedPrices();
    // A prefill that was held back for a unit mismatch can now land, if the
    // user went to Settings and made the two units agree.
    _applyPendingCash();
  }

  DateTime? get _hawlStart => _hawlStartMs == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(_hawlStartMs!);

  /// The Gregorian date one exact Hijri year after [start] — the moment the
  /// lunar year (حول) is complete.
  DateTime? _hawlEndDate(DateTime start) {
    final h = HijriUtils.hijriFromGreg(start.year, start.month, start.day);
    return HijriUtils.hijriToGreg(h.year + 1, h.month, h.day);
  }

  bool get _hawlElapsedFromStart {
    final s = _hawlStart;
    if (s == null) return false;
    final end = _hawlEndDate(s);
    return end != null && !DateTime.now().isBefore(end);
  }

  int get _hawlDaysRemaining {
    final s = _hawlStart;
    if (s == null) return 0;
    final end = _hawlEndDate(s);
    if (end == null) return 0;
    final d = end.difference(DateTime.now()).inDays;
    return d < 0 ? 0 : d;
  }

  Future<void> _loadHawlStart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt(_hawlStartKey);
      if (ms != null && mounted) {
        setState(() {
          _hawlStartMs = ms;
          _hawlComplete = _hawlElapsedFromStart;
        });
      }
    } catch (e) {
      AppLogger.warning('zakat_screen', 'hawl load failed: $e');
    }
  }

  Future<void> _saveHawlStart(DateTime? d) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (d == null) {
        await prefs.remove(_hawlStartKey);
      } else {
        await prefs.setInt(_hawlStartKey, d.millisecondsSinceEpoch);
      }
    } catch (e) {
      // The hawl date drives the «یک سال گذشت» countdown. If it did not save,
      // the screen shows a start date the app will not remember tomorrow.
      AppLogger.warning('zakat_screen', 'hawl save failed: $e');
      if (!mounted) return;
      AppSnackBar.error(
        context,
        'تاریخ آغاز حول ذخیره نشد و با باز شدن دوباره برمی‌گردد.',
        onRetry: () => _saveHawlStart(d),
      );
    }
  }

  Future<void> _pickHawlStart() async {
    final now = DateTime.now();
    // The Jalali dialog, not Material's: the app pins a Persian locale, so
    // Material would render and expect Persian digits for a back-dated day.
    final picked = await ShamsiDatePicker.show(
      context,
      initialDate: _hawlStart ?? now,
      earliestDate: DateTime(now.year - 30),
      latestDate: now,
      title: 'تاریخ رسیدن به نصاب (شروع حول)',
    );
    if (picked == null) return;
    await _saveHawlStart(picked);
    if (!mounted) return;
    setState(() {
      _hawlStartMs = picked.millisecondsSinceEpoch;
      _hawlComplete = _hawlElapsedFromStart;
      _result = null;
    });
  }

  Future<void> _clearHawlStart() async {
    await _saveHawlStart(null);
    if (!mounted) return;
    setState(() {
      _hawlStartMs = null;
      _hawlComplete = false;
      _result = null;
    });
  }

  Future<void> _calculate() async {
    final cash = NumberFormat.parse(_cashCtrl.text) +
        NumberFormat.parse(_bankCtrl.text) +
        NumberFormat.parse(_savingsCtrl.text);
    final dollarHoldings = NumberFormat.parse(_dollarHoldingsCtrl.text);
    final dollarRate = NumberFormat.parse(_dollarPriceCtrl.text);
    // تبدیل دلار→واحد پایه فقط برای واحدهای ایرانی معنا دارد؛ فیلدهایش هم
    // فقط همان‌جا نمایش داده می‌شوند.
    final dollarValue =
        _currency.isIranian ? dollarHoldings * dollarRate : 0.0;
    final goldWeight = NumberFormat.parse(_goldWeightCtrl.text);
    final goldKaratRaw =
        int.tryParse(NumberFormat.normalizeDigits(_goldKaratCtrl.text)) ?? 24;
    final goldKarat = goldKaratRaw.clamp(1, 24);
    final goldPrice = NumberFormat.parse(_goldPriceCtrl.text);
    final silverWeight = NumberFormat.parse(_silverWeightCtrl.text);
    final silverPrice = NumberFormat.parse(_silverPriceCtrl.text);
    final silverFinenessRaw =
        int.tryParse(NumberFormat.normalizeDigits(_silverFinenessCtrl.text)) ??
            1000;
    final silverFineness = silverFinenessRaw.clamp(100, 1000);
    final business = NumberFormat.parse(_businessCtrl.text) +
        NumberFormat.parse(_otherCtrl.text);
    final debts = NumberFormat.parse(_debtsCtrl.text);

    // Remember the user's latest market prices so the nisab calculation
    // stays accurate on the next visit — but only after the answer is shown.
    final hasCustomPrices = goldPrice > 0 || silverPrice > 0 || dollarRate > 0;

    final sheepCount =
        int.tryParse(NumberFormat.normalizeDigits(_sheepCtrl.text)) ?? 0;
    final goatCount =
        int.tryParse(NumberFormat.normalizeDigits(_goatCtrl.text)) ?? 0;
    final cowCount =
        int.tryParse(NumberFormat.normalizeDigits(_cowCtrl.text)) ?? 0;
    final camelCount =
        int.tryParse(NumberFormat.normalizeDigits(_camelCtrl.text)) ?? 0;

    // If a hawl start date is tracked, its status wins over the manual toggle.
    if (_hawlStartMs != null) _hawlComplete = _hawlElapsedFromStart;

    final input = ZakatInput(
      cashAndBank: cash + dollarValue,
      goldGrams: goldWeight,
      goldKarat: goldKarat,
      goldPricePerGram24: goldPrice,
      silverGrams: silverWeight,
      silverFineness: silverFineness,
      silverPricePerGram: silverPrice,
      businessValue: business,
      debts: debts,
      hawlComplete: _hawlComplete,
      kanzValue: NumberFormat.parse(_kanzCtrl.text),
      friendlyDebt: NumberFormat.parse(_friendlyDebtCtrl.text),
      uglyDebt: NumberFormat.parse(_uglyDebtCtrl.text),
      honeyKg: NumberFormat.parse(_honeyCtrl.text),
      horses: int.tryParse(NumberFormat.normalizeDigits(_horseCtrl.text)) ?? 0,
      horsePricePerHead: NumberFormat.parse(_horsePriceCtrl.text),
      grazing: _grazing,
      sheep: sheepCount,
      goats: goatCount,
      cows: cowCount,
      camels: camelCount,
      agricultureKg: NumberFormat.parse(_agriAmountCtrl.text),
      agriculturePricePerKg: NumberFormat.parse(_agriPriceCtrl.text),
      irrigation: _selectedIrrigationType == 'بارانی'
          ? ZakatIrrigation.rain
          : ZakatIrrigation.irrigated,
      agricultureCropLabel: _selectedCropType,
      // توضیح زکات دام حالا داخل خود ZakatCalculator به فارسی ساخته می‌شود.
      madhab: _madhab,
      nisabBasis: _nisabBasis,
      currency: _currency,
    );

    // The answer goes up before anything is written. Saving the market prices
    // is a side effect of pressing «محاسبه», not a precondition for it.
    if (!mounted) return;
    setState(() {
      _result = ZakatCalculator.calculate(input);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });

    if (!hasCustomPrices) return;
    await _rememberPrices(
      gold: goldPrice,
      silver: silverPrice,
      dollar: dollarRate,
    );
  }

  void _clearAll() {
    for (final c in _allControllers) {
      c.clear();
    }
    _goldKaratCtrl.text = '18';
    _silverFinenessCtrl.text = '1000';
    _selectedIrrigationType = 'بارانی';
    _selectedCropType = 'گندم';
    _agriPriceCtrl.clear();
    _hawlComplete = false;
    _hawlStartMs = null;
    _saveHawlStart(null);
    _grazing = false;
    // مذهب و مبنای نصاب عمداً پاک نمی‌شوند: «پاک کردن» اعداد واردشده را
    // پاک می‌کند، نه انتخاب فقهی کاربر را.
    // قیمت‌ها هم پاک شدند، پس تاریخ «آخرین به‌روزرسانی» نباید بماند؛
    // وگرنه بنر می‌گوید «قیمت‌ها X روز پیش به‌روز شده‌اند» در حالی که
    // فیلدها خالی‌اند و قیمت پیش‌فرض اعمال می‌شود.
    _pricesUpdatedAt = 0;
    setState(() => _result = null);
  }

  Widget _buildHawlSection(BuildContext context, bool isDark, Color accent) {
    final start = _hawlStart;
    final surfaceColor = TimeThemeKit.of(context).palette.surfaceAlt;
    final outlineColor = TimeThemeKit.of(context).palette.outline;

    if (start == null) {
      // No tracked start date → manual toggle + optional date seeding.
      return Material(
        color: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: outlineColor),
        ),
        child: Column(
          children: [
            CheckboxListTile(
              value: _hawlComplete,
              onChanged: (v) => setState(() {
                _hawlComplete = v ?? false;
                _result = null;
              }),
              activeColor: accent,
              title: Text('حول (یک سال قمری) کامل شده است',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 13),
                      fontWeight: FontWeight.w600,
                      color: TimeThemeKit.of(context).palette.textPrimary)),
              subtitle: Text('برای زکات نقدی و دام، گذشتن یک سال قمری شرط است',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 11),
                      color: TimeThemeKit.of(context).palette.textMuted)),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            TextButton.icon(
              onPressed: _pickHawlStart,
              icon: const Icon(Icons.event, size: 18),
              label: const Text('شروع خودکار حول از تاریخ نصاب',
                  textDirection: TextDirection.rtl),
              style: TextButton.styleFrom(foregroundColor: accent),
            ),
          ],
        ),
      );
    }

    // A start date is stored → status is derived automatically from a Hijri year.
    final done = _hawlElapsedFromStart;
    final h = HijriUtils.hijriFromGreg(start.year, start.month, start.day);
    return AppCard(
      padding: const EdgeInsets.all(12),
      color: surfaceColor,
      borderColor: outlineColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(done ? Icons.verified : Icons.hourglass_bottom,
                  size: 20,
                  color: done
                      ? accent
                      : TimeThemeKit.of(context).palette.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  done
                      ? 'حول کامل شده است ✓'
                      : 'حول نمانده — $_hawlDaysRemaining روز قمری باقی مانده',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 13),
                      fontWeight: FontWeight.w700,
                      color: done
                          ? accent
                          : TimeThemeKit.of(context).palette.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'تاریخ شروع حول: ${h.year}/${h.month}/${h.day} قمری',
            textDirection: TextDirection.rtl,
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 11),
                color: TimeThemeKit.of(context).palette.textMuted),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              TextButton.icon(
                onPressed: _pickHawlStart,
                icon: const Icon(Icons.edit_calendar, size: 16),
                label: const Text('تغییر تاریخ'),
                style: TextButton.styleFrom(foregroundColor: accent),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: _clearHawlStart,
                icon: const Icon(Icons.close, size: 16),
                label: const Text('حذف و ورود دستی'),
                style: TextButton.styleFrom(
                    foregroundColor:
                        TimeThemeKit.of(context).palette.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accent = ZakatScreen._accent;

    return ListView(
      controller: _scrollCtrl,
      padding:
          const EdgeInsets.fromLTRB(DsSpacing.page, 12, DsSpacing.page, 40),
      children: [
        const TabIntroCard(
          icon: Icons.volunteer_activism,
          accent: ZakatScreen._accent,
          title: 'زکات',
          subtitle: 'یکی از ارکان اسلام برای پاکی مال و یاری نیازمندان',
        ),
        const SizedBox(height: 12),
        _buildMadhabSelector(isDark, accent),
        const SizedBox(height: 12),
        _buildNisabBasisSelector(isDark, accent),
        const SizedBox(height: 12),
        const SectionHeader(
            title: 'قیمت طلا و نقره',
            icon: Icons.diamond,
            accentColor: ZakatScreen._accent),
        OutlinedButton.icon(
          onPressed: _editTodayPrices,
          icon: const Icon(Icons.edit_calendar_outlined, size: 18),
          label: Text('ویرایش قیمت روز طلا و نقره',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 13),
                  fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            foregroundColor: accent,
            side: BorderSide(color: accent.withValues(alpha: 0.45)),
            minimumSize: const Size.fromHeight(44),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Text(
              'قیمت طلا به‌صورت عیار 24 محاسبه می‌شود؛ برای عیارهای دیگر وزن به‌صورت خودکار به معادل 24 عیار تبدیل می‌شود.',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  color: TimeThemeKit.of(context).palette.textMuted)),
        ),
        const SizedBox(height: 8),
        _inputField(_goldPriceCtrl, 'قیمت هر گرم طلای 24 عیار', _unit,
            Icons.diamond, isDark,
            color: _goldColor),
        const SizedBox(height: 8),
        _inputField(_silverPriceCtrl, 'قیمت هر گرم نقره', _unit,
            Icons.diamond_outlined, isDark,
            color: _silverColor),
        if (_currency.isIranian) ...[
          // جفت «دارایی دلاری × قیمت دلار»: پیش‌تر فقط قیمت دلار فیلد داشت و
          // موجودی دلاری هیچ ورودی‌ای نداشت، پس این تبدیل همیشه صفر می‌ماند.
          // حالا هر دو با هم نمایش داده می‌شوند و واقعاً کار می‌کنند.
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _inputField(_dollarHoldingsCtrl, 'دارایی دلاری',
                    'دلار', Icons.attach_money, isDark,
                    color: _dollarColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: _inputField(_dollarPriceCtrl, 'قیمت هر دلار', _unit,
                    Icons.currency_exchange, isDark,
                    color: _dollarColor),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 4),
            child: Text(
                'اگر بخشی از دارایی‌تان دلار است، همین‌جا وارد کنید تا به $_unit '
                'تبدیل و به دارایی نقدی اضافه شود. اگر همهٔ دارایی به دلار است، '
                'واحد را از «تنظیمات › واحد حساب‌گرها» روی «دلار آمریکا» '
                'بگذارید (واحد پول فقط از همان‌جا عوض می‌شود).',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    color: TimeThemeKit.of(context).palette.textMuted,
                    height: 1.5)),
          ),
        ],
        if (_pricesUpdatedAt > 0) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.update,
                  size: 14, color: TimeThemeKit.of(context).palette.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                    'آخرین به‌روزرسانی قیمت‌ها: ${_formatUpdateDate(_pricesUpdatedAt)}',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 11),
                        color: TimeThemeKit.of(context).palette.textMuted)),
              ),
            ],
          ),
        ],
        if (_priceStaleDays() != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 16, color: Colors.orange.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _priceStaleDays()! < 0
                        ? 'قیمت روز طلا/نقره وارد نشده است؛ تا آن را وارد نکنید '
                            'نصاب محاسبه نمی‌شود (هیچ قیمت پیش‌فرضی جای آن را '
                            'نمی‌گیرد).'
                        : 'قیمت‌ها ${_priceStaleDays()} روز پیش به‌روز شده‌اند؛ '
                            'نصاب با قیمت قدیمی محاسبه می‌شود — با نرخ امروز '
                            'بازار به‌روز کنید.',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 11),
                        color: Colors.orange.shade800,
                        height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        _buildReferencePricesCard(isDark, accent),
        const SizedBox(height: 16),
        const SectionHeader(
            title: 'دارایی نقدی',
            icon: Icons.payments_outlined,
            accentColor: ZakatScreen._accent),
        _inputField(_cashCtrl, 'پول نقد', _unit, Icons.money, isDark,
            color: _cashColor),
        if (_prefillDropped) ...[
          const SizedBox(height: 6),
          Text(
            'مبلغی که از گزارش هزینه‌ها آمده بود، به واحد دیگری بود و وارد نشد. '
            'اگر همان مبلغ را می‌خواهید، واحد حساب‌گرها را از تنظیمات هم‌واحد '
            'کنید و دوباره امتحان کنید.',
            textDirection: TextDirection.rtl,
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 11),
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkWarning
                    : AppTheme.lightWarning,
                height: 1.5),
          ),
        ],
        const SizedBox(height: 8),
        _inputField(_bankCtrl, 'موجودی حساب بانکی', _unit,
            Icons.account_balance, isDark,
            color: _cashColor),
        const SizedBox(height: 8),
        _inputField(
            _savingsCtrl, 'پس‌انداز', _unit, Icons.savings_outlined, isDark,
            color: _cashColor),
        const SizedBox(height: 16),
        const SectionHeader(
            title: 'طلا و نقره',
            icon: Icons.diamond_outlined,
            accentColor: ZakatScreen._accent),
        Row(
          children: [
            Expanded(
                flex: 3,
                child: _inputField(_goldWeightCtrl, 'وزن طلا (گرم)', 'گرم',
                    Icons.diamond, isDark,
                    color: _goldColor)),
            const SizedBox(width: 8),
            Expanded(
                flex: 2,
                child: _inputField(
                    _goldKaratCtrl, 'عیار', '', Icons.star_outline, isDark)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
                flex: 3,
                child: _inputField(_silverWeightCtrl, 'وزن نقره (گرم)', 'گرم',
                    Icons.diamond_outlined, isDark,
                    color: _silverColor)),
            const SizedBox(width: 8),
            Expanded(
                flex: 2,
                child: _inputField(
                    _silverFinenessCtrl, 'عیار نقره', '‰', Icons.star, isDark)),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Text(
              'عیار نقره (خالصی از 1000)؛ وزن خالص = وزن × عیار ÷ 1000.',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  color: TimeThemeKit.of(context).palette.textMuted)),
        ),
        const SizedBox(height: 16),
        const SectionHeader(
            title: 'دارایی تجاری',
            icon: Icons.storefront_outlined,
            accentColor: ZakatScreen._accent),
        _inputField(_businessCtrl, 'کالای تجارت', _unit, Icons.store, isDark,
            color: _tradeColor),
        const SizedBox(height: 16),
        const SectionHeader(
            title: 'زکات اموال خاص',
            icon: Icons.category_outlined,
            accentColor: ZakatScreen._accent),
        _inputField(_kanzCtrl, 'کنز/دفینه (گنج دوران جاهلیت)', _unit,
            Icons.temple_hindu, isDark,
            color: const Color(0xFFBF360C)),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Text('زکات گنج جاهلیت: یک‌پنجم (20٪) فوراً.',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  color: TimeThemeKit.of(context).palette.textMuted)),
        ),
        const SizedBox(height: 8),
        _inputField(
            _friendlyDebtCtrl,
            'دین مرجوه (قوی/قابل وصول) — شامل طلب‌های قابل وصول',
            _unit,
            Icons.schedule,
            isDark,
            color: _tradeColor),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Text(
              'زکاتش هر سال همین حالا واجب است (با نصاب و حول، مانند پول نقد).',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  color: TimeThemeKit.of(context).palette.textMuted)),
        ),
        const SizedBox(height: 8),
        _inputField(_uglyDebtCtrl, 'دین غیرمرجوه (ضعیف/بدون امید وصول)',
            _unit, Icons.hourglass_disabled, isDark,
            color: _tradeColor),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Text(
              'زکاتش فقط پس از وصول، برای یک سال واجب می‌شود (اکنون واجب نیست).',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  color: TimeThemeKit.of(context).palette.textMuted)),
        ),
        const SizedBox(height: 8),
        _inputField(
            _honeyCtrl, 'عسل (کیلوگرم)', 'کیلوگرم', Icons.spa_outlined, isDark,
            color: const Color(0xFFF9A825)),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Text(
              'نصاب: ده قِرَب ≈ 62 کیلوگرم؛ زکاتش عُشر (10٪) — حنابله و احناف.',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  color: TimeThemeKit.of(context).palette.textMuted)),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
                child: _inputField(
                    _horseCtrl, 'تعداد اسب', 'رأس', Icons.pets, isDark,
                    color: const Color(0xFF5E35B1))),
            const SizedBox(width: 8),
            Expanded(
                child: _inputField(
                    _horsePriceCtrl, 'قیمت هر اسب', _unit, Icons.pets, isDark,
                    color: const Color(0xFF5E35B1))),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Text(
              'نصاب اسب: پنج رأس؛ زکاتش ربع عُشر (2.5٪) ارزش است — مبنای حنفی (جمهور/شافعی/مالکی زکات اسب ندارند).',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  color: TimeThemeKit.of(context).palette.textMuted)),
        ),
        const SizedBox(height: 16),
        const SectionHeader(
            title: 'زکات دام (انعام)',
            icon: Icons.pets,
            accentColor: ZakatScreen._accent),
        Padding(
          padding: const EdgeInsets.only(bottom: 4, right: 4),
          child: Text(
              'نصاب: گوسفند/بز 40 رأس، گاو 30 رأس، شتر 5 رأس — فقط دام سائمه و با گذشت حول',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  color: TimeThemeKit.of(context).palette.textMuted)),
        ),
        Row(
          children: [
            Expanded(
                child: _livestockInputField(_sheepCtrl, 'گوسفند', '🐑', isDark,
                    color: const Color(0xFF8D6E63))),
            const SizedBox(width: 8),
            Expanded(
                child: _livestockInputField(_goatCtrl, 'بز', '🐐', isDark,
                    color: const Color(0xFF8D6E63))),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
                child: _livestockInputField(
                    _cowCtrl, 'گاو/گوساله', '🐄', isDark,
                    color: const Color(0xFF8D6E63))),
            const SizedBox(width: 8),
            Expanded(
                child: _livestockInputField(_camelCtrl, 'شتر', '🐪', isDark,
                    color: const Color(0xFF8D6E63))),
          ],
        ),
        const SizedBox(height: 8),
        _buildLivestockTableToggle(isDark),
        if (_showLivestockTable) ...[
          const SizedBox(height: 8),
          _buildLivestockTable(isDark),
        ],
        const SizedBox(height: 8),
        Material(
          color: TimeThemeKit.of(context).palette.surfaceAlt,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: TimeThemeKit.of(context).palette.outline),
          ),
          child: CheckboxListTile(
            value: _grazing,
            onChanged: (v) => setState(() {
              _grazing = v ?? false;
              _result = null;
            }),
            activeColor: accent,
            title: Text('دام سائمه (چرانیده در چراگاه) است',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    fontWeight: FontWeight.w600,
                    color: TimeThemeKit.of(context).palette.textPrimary)),
            subtitle: Text(
                'سوم (چرا در مرتع) شرط زکات دام است — مگر در مذهب مالکی.',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    color: TimeThemeKit.of(context).palette.textMuted)),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ),
        const SizedBox(height: 16),
        const SectionHeader(
            title: 'زکات کشاورزی',
            icon: Icons.agriculture_outlined,
            accentColor: ZakatScreen._accent),
        Padding(
          padding: const EdgeInsets.only(bottom: 4, right: 4),
          child: Text(
              'زکات از خودِ محصول برداشت‌شده پرداخت می‌شود (کیلوگرم) — حول شرط نیست. بارانی/جوی: 10٪ — آبی/چاه: 5٪ — نصاب: 5 وسق ≈ 653 کیلوگرم (فقط گندم، جو، خرما و انگور — مذهب شافعی)',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  color: TimeThemeKit.of(context).palette.textMuted)),
        ),
        _buildCropTypeDropdown(isDark),
        const SizedBox(height: 8),
        _inputField(_agriAmountCtrl, 'مقدار محصول برداشت‌شده', 'کیلوگرم',
            Icons.eco, isDark,
            color: AppTheme.success),
        const SizedBox(height: 8),
        _buildIrrigationTypeDropdown(isDark),
        const SizedBox(height: 8),
        _inputField(
            _agriPriceCtrl,
            'قیمت هر کیلوگرم (اختیاری — برای نمایش معادل پولی)',
            _unit,
            Icons.price_change_outlined,
            isDark,
            color: AppTheme.success),
        const SizedBox(height: 12),
        _buildAdvancedToggle(isDark, accent),
        if (_showAdvanced) ...[
          const SizedBox(height: 8),
          _inputField(_otherCtrl, 'سایر اموال زکات‌پذیر', _unit,
              Icons.more_horiz, isDark,
              color: _tradeColor),
          const SizedBox(height: 8),
          _inputField(_debtsCtrl, 'بدهی‌ها و تعهدات', _unit,
              Icons.receipt_long, isDark,
              color: _tradeColor),
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 4),
            child: Text('فقط بدهی‌های واقعی و نزدیک را وارد کنید.',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    color: TimeThemeKit.of(context).palette.textMuted)),
          ),
        ],
        const SizedBox(height: 20),
        _buildHawlSection(context, isDark, accent),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _calculate,
                icon: const Icon(Icons.calculate_outlined, size: 20),
                label: const Text('محاسبه زکات'),
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: TimeThemeKit.of(context).palette.card,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 16),
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              onPressed: _clearAll,
              icon: const Icon(Icons.refresh),
              tooltip: 'پاک کردن',
              style: IconButton.styleFrom(
                backgroundColor: TimeThemeKit.of(context).palette.surfaceAlt,
              ),
            ),
          ],
        ),
        if (_result != null) ...[
          const SizedBox(height: 20),
          ZakatResultCard(
            result: _result!,
            isDark: isDark,
            accent: accent,
            selectedCropType: _selectedCropType,
            onSharePdf: () => _shareResultPdf(_result!),
          ),
        ],
        const SizedBox(height: 16),
        _buildDisclaimer(isDark),
      ],
    );
  }

  Widget _buildMadhabSelector(bool isDark, Color accent) {
    final onPrimary = dsOnAccent(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('مذهب فقهی برای نصاب نقدی',
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 13),
                fontWeight: FontWeight.w700,
                color: accent)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ZakatMadhab.values.map((m) {
            final sel = _madhab == m;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _madhab = m;
                  _result = null;
                });
                _saveFiqhSettings();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: sel
                      ? accent
                      : (isDark
                          ? AppTheme.darkSurfaceAlt
                          : AppTheme.lightSurfaceAlt),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: sel
                          ? accent
                          : (isDark
                              ? AppTheme.darkOutline
                              : AppTheme.lightOutline),
                      width: sel ? 2 : 1),
                ),
                child: Text(
                  zakatMadhabLabel(m),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 11),
                      fontWeight: FontWeight.w700,
                      color: sel
                          ? onPrimary
                          : TimeThemeKit.of(context).palette.textPrimary),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 4),
        Text(
            'جماهیر، شافعی و مالکی: نصاب نقدی = نصاب طلا؛ حنابله و احناف: اقل نصابین.',
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 11),
                color: TimeThemeKit.of(context).palette.textMuted)),
      ],
    );
  }

  Widget _buildNisabBasisSelector(bool isDark, Color accent) {
    final onPrimary = dsOnAccent(context);
    const entries = <(ZakatNisabBasis, String)>[
      (ZakatNisabBasis.auto, 'خودکار'),
      (ZakatNisabBasis.gold, 'طلا'),
      (ZakatNisabBasis.silver, 'نقره'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('مبنای نصاب نقدی',
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 13),
                fontWeight: FontWeight.w700,
                color: accent)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: entries.map((e) {
            final sel = _nisabBasis == e.$1;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _nisabBasis = e.$1;
                  _result = null;
                });
                _saveFiqhSettings();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: sel
                      ? accent
                      : (isDark
                          ? AppTheme.darkSurfaceAlt
                          : AppTheme.lightSurfaceAlt),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: sel
                          ? accent
                          : (isDark
                              ? AppTheme.darkOutline
                              : AppTheme.lightOutline),
                      width: sel ? 2 : 1),
                ),
                child: Text(
                  e.$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 11),
                      fontWeight: FontWeight.w700,
                      color: sel
                          ? onPrimary
                          : TimeThemeKit.of(context).palette.textPrimary),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 4),
        Text(
            'خودکار: بر اساس مذهب. طلا: 85 گرم؛ نقره: 595 گرم (مبنای حنفی، '
            'نصاب پایین‌تر و شمول بیشتر).',
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 11),
                color: TimeThemeKit.of(context).palette.textMuted)),
      ],
    );
  }

  Widget _inputField(TextEditingController ctrl, String label, String suffix,
      IconData icon, bool isDark,
      {Color? color}) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      inputFormatters: const [LatinGroupingFormatter()],
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        suffixStyle: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 11),
            color: TimeThemeKit.of(context).palette.textMuted),
        prefixIcon: Icon(icon,
            size: 20,
            color: color ?? TimeThemeKit.of(context).palette.textMuted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 15),
          fontWeight: FontWeight.w600),
    );
  }

  Widget _livestockInputField(
      TextEditingController ctrl, String label, String emoji, bool isDark,
      {Color? color}) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        suffixText: 'رأس',
        suffixStyle: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 11),
            color: TimeThemeKit.of(context).palette.textMuted),
        prefixIcon: SizedBox(
            width: 36,
            child: Center(
                child: Text(emoji, style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 19))))),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 15),
          fontWeight: FontWeight.w600),
    );
  }

  Widget _buildAdvancedToggle(bool isDark, Color accent) {
    return AppCard(
      onTap: () => setState(() => _showAdvanced = !_showAdvanced),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: TimeThemeKit.of(context).palette.surfaceAlt,
      child: Row(
        children: [
          Icon(Icons.tune,
              size: 18, color: TimeThemeKit.of(context).palette.textMuted),
          const SizedBox(width: 8),
          Text('تنظیمات پیشرفته',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 13),
                  fontWeight: FontWeight.w600,
                  color: TimeThemeKit.of(context).palette.textSecondary)),
          const Spacer(),
          Icon(_showAdvanced ? Icons.expand_less : Icons.expand_more,
              color: TimeThemeKit.of(context).palette.textMuted),
        ],
      ),
    );
  }

  Future<void> _shareResultPdf(ZakatResult result) async {
    try {
      final bytes = await buildZakatReportPdf(result: result);
      await shareToolReportPdf(
        bytes: bytes,
        fileName: 'zakat_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      AppLogger.warning('zakat_screen', 'error: $e');
      if (mounted) _showMessage('ساخت PDF گزارش زکات ممکن نشد؛ دوباره تلاش کنید.');
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  /// در مذهب شافعی زکات فقط بر چهار محصول واجب است: گندم، جو، خرما و انگور.
  /// نصاب هر چهار محصول 5 وسق است؛ وسق معیار حجمی است (60 صاع) و وزن
  /// تقریبی آن بسته به چگالی محصول اندکی متفاوت است — معادل رایج
  /// 5 وسق ≈ 653 کیلوگرم برای همه محاسبه می‌شود.
  static const Map<String, double> _cropNisabKg = {
    'گندم': 653.0,
    'جو': 653.0,
    'خرما': 653.0,
    'انگور (کشمش)': 653.0,
  };

  Widget _buildCropTypeDropdown(bool isDark) {
    const accent = AppTheme.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: TimeThemeKit.of(context).palette.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.agriculture, size: 20, color: AppTheme.success),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<String>(
              value: _selectedCropType,
              isExpanded: true,
              underline: const SizedBox(),
              dropdownColor: isDark
                  ? TimeThemeKit.of(context).palette.surfaceAlt
                  : Colors.white,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 14),
                  color: TimeThemeKit.of(context).palette.textPrimary),
              items: _cropNisabKg.entries
                  .map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(e.key),
                          Text(
                            'نصاب ≈ ${NumberFormat.formatPlain(e.value)} کگ',
                            style: TextStyle(
                                fontSize: AppTheme.scaledFontSize(context, 11),
                                color: accent,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      )))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCropType = value;
                    _result = null;
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLivestockTableToggle(bool isDark) {
    return AppCard(
      onTap: () => setState(() => _showLivestockTable = !_showLivestockTable),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: TimeThemeKit.of(context).palette.surfaceAlt,
      borderColor: TimeThemeKit.of(context).palette.outline,
      child: Row(
        children: [
          const Icon(Icons.table_chart_outlined,
              size: 18, color: Color(0xFF8D6E63)),
          const SizedBox(width: 8),
          // Expanded, not a bare Text + Spacer: at 360dp (and with the user's
          // font scale up) the title is wider than the row and the chevron
          // used to be pushed off the edge.
          Expanded(
            child: Text(
              'جدول کامل زکات دام (شتر / گاو / گوسفند)',
              textDirection: TextDirection.rtl,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 13),
                  fontWeight: FontWeight.w600,
                  color: TimeThemeKit.of(context).palette.textSecondary),
            ),
          ),
          Icon(_showLivestockTable ? Icons.expand_less : Icons.expand_more,
              color: TimeThemeKit.of(context).palette.textMuted),
        ],
      ),
    );
  }

  Widget _buildLivestockTable(bool isDark) {
    Widget section(String title, IconData icon, List<(String, String)> rows) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: const Color(0xFF8D6E63)),
                const SizedBox(width: 6),
                Text(title,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 13),
                        fontWeight: FontWeight.w700,
                        color: TimeThemeKit.of(context).palette.textPrimary)),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: TimeThemeKit.of(context).palette.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: TimeThemeKit.of(context).palette.outline),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: i == 0
                          ? BoxDecoration(
                              color: const Color(0xFF8D6E63)
                                  .withValues(alpha: 0.12),
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(10)))
                          : null,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 96,
                            child: Text(rows[i].$1,
                                textDirection: TextDirection.rtl,
                                style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize:
                                        AppTheme.scaledFontSize(context, 12),
                                    fontWeight: i == 0
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: TimeThemeKit.of(context)
                                        .palette
                                        .textPrimary)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(rows[i].$2,
                                textDirection: TextDirection.rtl,
                                style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize:
                                        AppTheme.scaledFontSize(context, 12),
                                    fontWeight: i == 0
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: TimeThemeKit.of(context)
                                        .palette
                                        .textSecondary)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFF8D6E63).withValues(alpha: 0.05),
      borderColor: const Color(0xFF8D6E63).withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          section('گوسفند و بز (غنم)', Icons.pets_outlined, const [
            ('تعداد', 'زکات'),
            ('40 تا 120', '1 گوسفند یا بز'),
            ('121 تا 200', '2 گوسفند یا بز'),
            ('201 تا 300', '3 گوسفند یا بز'),
            ('301 تا 400', '4 گوسفند یا بز'),
            ('401 تا 500', '5 گوسفند یا بز'),
            ('به‌ازای هر 100', '1 گوسفند یا بز بیشتر'),
          ]),
          section('گاو و گوساله (بقر)', Icons.agriculture_outlined, const [
            ('تعداد', 'زکات'),
            ('30 تا 39', '1 گوساله یک‌ساله (تابع)'),
            ('40 تا 59', '1 گاو دو ساله (مسنّه)'),
            ('60 تا 69', '2 گوساله یک‌ساله'),
            ('70 تا 79', '1 گوساله یک‌ساله + 1 گاو دو ساله'),
            ('80 تا 89', '2 گاو دو ساله'),
            ('90 تا 99', '3 گوساله یک‌ساله'),
            ('100 تا 109', '2 گوساله یک‌ساله + 1 گاو دو ساله'),
            ('110 تا 119', '2 گاو دو ساله + 1 گوساله یک‌ساله'),
            (
              'از 120 به بالا',
              'هر 30 = 1 گوساله یک‌ساله یا هر 40 = 1 گاو دو ساله'
            ),
          ]),
          section('شتر (ابل)', Icons.emoji_nature_outlined, const [
            ('تعداد', 'زکات'),
            ('5 تا 9', '1 گوسفند'),
            ('10 تا 14', '2 گوسفند'),
            ('15 تا 19', '3 گوسفند'),
            ('20 تا 24', '4 گوسفند'),
            ('25 تا 35', '1 بنت مخاض (شتر یک‌ساله)'),
            ('36 تا 45', '1 بنت لبون (شتر دو ساله)'),
            ('46 تا 60', '1 حِقّه (شتر سه ساله)'),
            ('61 تا 75', '1 جذعه (شتر چهار ساله)'),
            ('76 تا 90', '2 بنت لبون (شتر دو ساله)'),
            ('91 تا 120', '2 حِقّه (شتر سه ساله)'),
            ('121 تا 129', '3 بنت لبون'),
            ('130 تا 139', '2 بنت لبون + 1 حِقّه'),
            ('140 تا 149', '1 بنت لبون + 2 حِقّه'),
            ('150 تا 159', '3 حِقّه'),
            ('160 تا 169', '4 بنت لبون'),
            ('170 تا 179', '3 بنت لبون + 1 حِقّه'),
            ('180 تا 189', '2 بنت لبون + 2 حِقّه'),
            ('190 تا 199', '1 بنت لبون + 3 حِقّه'),
            ('از 200 به بالا', 'هر 40 = 1 بنت لبون یا هر 50 = 1 حِقّه'),
          ]),
        ],
      ),
    );
  }

  Widget _buildIrrigationTypeDropdown(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: TimeThemeKit.of(context).palette.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.water_drop, size: 20, color: AppTheme.success),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<String>(
              value: _selectedIrrigationType,
              isExpanded: true,
              underline: const SizedBox(),
              dropdownColor: isDark
                  ? TimeThemeKit.of(context).palette.surfaceAlt
                  : Colors.white,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 14),
                  color: TimeThemeKit.of(context).palette.textPrimary),
              items: const [
                DropdownMenuItem(
                    value: 'آبی', child: Text('آبی (آبیاری با آب)')),
                DropdownMenuItem(
                    value: 'بارانی',
                    child: Text('بارانی / جوی (آبیاری با باران)')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedIrrigationType = value);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferencePricesCard(bool isDark, Color accent) {
    // TGJU اعداد بازار ایران را به تومان می‌دهد؛ برای واحدهای دیگر منبعی
    // نداریم و ساختنِ عدد از خودمان بدتر از نبودنش است.
    final canFetchLive = _currency == AppCurrency.toman;
    return AppCard(
      padding: const EdgeInsets.all(14),
      color: accent.withValues(alpha: 0.06),
      borderColor: accent.withValues(alpha: 0.15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 18, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text('قیمت‌های مرجع',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w700,
                        color: accent)),
              ),
              if (canFetchLive)
                FilledButton.icon(
                  onPressed: _fetchingLivePrices ? null : _fetchLivePrices,
                  icon: _fetchingLivePrices
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.cloud_download_outlined, size: 16),
                  label: Text(
                      _fetchingLivePrices ? 'دریافت...' : 'دریافت قیمت روز',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 11))),
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: TimeThemeKit.of(context).palette.card,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text('ملاک شرعی: طلا 85 گرم (24 عیار) یا نقره 595 گرم',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  fontWeight: FontWeight.w700,
                  color: accent)),
          Text(
              'قیمت پیش‌فرضی در برنامه ذخیره نشده است: نصاب فقط با قیمت روز '
              'محاسبه می‌شود. عدد ثابت با گذشت زمان کهنه می‌شود و «زکات واجب '
              'است یا نه» را بی‌صدا برعکس می‌کند.',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  color: TimeThemeKit.of(context).palette.textSecondary,
                  height: 1.5)),
          Text(
              canFetchLive
                  ? 'قیمت‌ها را با نرخ روز منطقه خود به‌روز کنید'
                  : 'دریافت آنلاین قیمت فقط برای تومان است.',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  color: TimeThemeKit.of(context).palette.textMuted,
                  height: 1.5)),
        ],
      ),
    );
  }

  bool _fetchingLivePrices = false;

  void _showPriceSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ));
  }

  /// Fetches today's gold/silver/dollar prices via [zakatPriceProvider].
  ///
  /// [ZakatPriceState.refreshFailed], not `saved != null`, decides success:
  /// a failed refresh keeps the previously stored prices, so checking only
  /// for a saved set reported success and filled the form with old figures.
  Future<void> _fetchLivePrices() async {
    if (_fetchingLivePrices) return;
    // TGJU اعداد بازار ایران را به تومان می‌دهد؛ برای واحدهای دیگر دکمه هم
    // نمایش داده نمی‌شود و این نگهبان فقط برای اطمینان است.
    if (_currency != AppCurrency.toman) return;
    setState(() => _fetchingLivePrices = true);
    try {
      await ref.read(zakatPriceProvider.notifier).refreshLive();
      if (!mounted) return;
      final priceState = ref.read(zakatPriceProvider);
      final saved = priceState.saved;
      if (priceState.refreshFailed) {
        if (saved != null) {
          // Old figures stay in the store, but they are not today's prices —
          // leave the form untouched rather than pass them off as fresh.
          _showPriceSnack(
              'دریافت قیمت آنلاین ناموفق بود؛ قیمت‌های نمایش‌داده‌شده به‌روز نیستند');
        } else {
          // هیچ عددی جای قیمت روز نمی‌نشیند — نه قیمت ثابت قدیمی و نه نرخ
          // ساختگی. فیلد خالی می‌ماند و بنر «نصاب قابل محاسبه نیست» راه
          // درست را نشان می‌دهد.
          _showPriceSnack(
              'اتصال برقرار نشد؛ قیمت روز را دستی وارد کنید تا نصاب محاسبه شود');
        }
        return;
      }
      if (saved != null) {
        setState(() {
          _goldPriceCtrl.text = NumberFormat.formatPlain(saved.goldPerGram);
          _silverPriceCtrl.text = NumberFormat.formatPlain(saved.silverPerGram);
          _dollarPriceCtrl.text = NumberFormat.formatPlain(saved.dollarPrice);
        });
        _showPriceSnack('قیمت‌های امروز از سایت tgju دریافت شد');
        return;
      }
      throw Exception('no prices');
    } catch (e) {
      AppLogger.warning('zakat_screen', 'live price fetch failed: $e');
      if (!mounted) return;
      _showPriceSnack(
          'اتصال برقرار نشد؛ قیمت روز را دستی وارد کنید تا نصاب محاسبه شود');
    } finally {
      if (mounted) setState(() => _fetchingLivePrices = false);
    }
  }

  /// Opens a dialog to edit today's gold/silver/dollar market prices and
  /// persists them so the nisab calculation stays accurate next time.
  Future<void> _editTodayPrices() async {
    final goldCtrl = TextEditingController(text: _goldPriceCtrl.text);
    final silverCtrl = TextEditingController(text: _silverPriceCtrl.text);
    final dollarCtrl = TextEditingController(text: _dollarPriceCtrl.text);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accent = ZakatScreen._accent;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit_calendar_outlined, color: accent),
            SizedBox(width: 10),
            Expanded(child: Text('ویرایش قیمت روز طلا و نقره')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  'قیمت امروز بازار را وارد کنید؛ نصاب شرعی با همین قیمت‌ها محاسبه می‌شود و تا دفعه بعد ذخیره می‌ماند.',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 12),
                      color: TimeThemeKit.of(context).palette.textSecondary,
                      height: 1.5)),
              const SizedBox(height: 12),
              _inputField(goldCtrl, 'قیمت هر گرم طلای 24 عیار', _unit,
                  Icons.diamond, isDark,
                  color: _goldColor),
              const SizedBox(height: 8),
              _inputField(silverCtrl, 'قیمت هر گرم نقره', _unit,
                  Icons.diamond_outlined, isDark,
                  color: _silverColor),
              if (_currency.isIranian) ...[
                const SizedBox(height: 8),
                _inputField(dollarCtrl, 'قیمت هر دلار', _unit,
                    Icons.currency_exchange, isDark,
                    color: _dollarColor),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('انصراف'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('ذخیره قیمت‌ها'),
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: TimeThemeKit.of(context).palette.card,
            ),
          ),
        ],
      ),
    );

    if (ok != true) {
      goldCtrl.dispose();
      silverCtrl.dispose();
      dollarCtrl.dispose();
      return;
    }

    final gold = NumberFormat.parse(goldCtrl.text);
    final silver = NumberFormat.parse(silverCtrl.text);
    final dollar = NumberFormat.parse(dollarCtrl.text);
    setState(() {
      _goldPriceCtrl.text = goldCtrl.text;
      _silverPriceCtrl.text = silverCtrl.text;
      _dollarPriceCtrl.text = dollarCtrl.text;
      _pricesUpdatedAt = DateTime.now().millisecondsSinceEpoch;
      _result = null;
    });
    goldCtrl.dispose();
    silverCtrl.dispose();
    dollarCtrl.dispose();
    await ZakatPriceStore.save(
      goldPerGram: gold,
      silverPerGram: silver,
      dollarPrice: dollar,
      currencyCode: _currency.code,
    );
  }

  String _formatUpdateDate(int ts) {
    final jalali = Jalali.fromDateTime(DateTime.fromMillisecondsSinceEpoch(ts));
    return DateFormatters.formatShamsi(jalali.day, jalali.month, jalali.year);
  }

  /// Days since the market prices were last updated, or -1 when the user
  /// never entered any (fallback defaults are in effect). Null when fresh —
  /// the window is the single shared [ZakatPriceState.staleAfter] so this
  /// screen badge and the price state can never disagree. Prices older than
  /// that window can move the nisab noticeably, so the UI warns instead of
  /// silently mis-stating it.
  int? _priceStaleDays() {
    if (_pricesUpdatedAt <= 0) return -1;
    final age = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(_pricesUpdatedAt));
    return age > ZakatPriceState.staleAfter ? age.inDays : null;
  }

  Widget _buildDisclaimer(bool isDark) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      color: TimeThemeKit.of(context).palette.surfaceAlt,
      child: Row(
        children: [
          Icon(Icons.info_outline,
              size: 16, color: TimeThemeKit.of(context).palette.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(ZakatContent.disclaimer,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    color: TimeThemeKit.of(context).palette.textMuted,
                    height: 1.5)),
          ),
        ],
      ),
    );
  }
}

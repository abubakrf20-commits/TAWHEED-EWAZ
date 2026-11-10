import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/models/app_currency.dart';
import 'package:tawheeed/shared/services/currency_store.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/shared/widgets/number_input_formatters.dart';
import 'package:tawheeed/features/education/presentation/widgets/education_widgets.dart';
import 'package:tawheeed/features/education/presentation/widgets/education_hero_header.dart';
import 'package:tawheeed/core/design_system/components/components.dart' hide SectionHeader;
/// Zakat al-Fitr (فطریه) calculator tab inside the fasting section.
/// Features:
///  - number of household members
///  - selectable staple food (قوت غالب) with editable per-kg price
///  - in-kind (جنسی) vs cash (نقدی) modes
///  - per-person sa' amount (2.5 / 2.75 / 3 kg)
///  - saved last price per food
///  - rulings + recipients reference
class FitrZakatTab extends StatefulWidget {
  const FitrZakatTab({super.key});

  static Color get _accent => TopicHues.fasting;

  @override
  State<FitrZakatTab> createState() => _FitrZakatTabState();
}

class _FitrZakatTabState extends State<FitrZakatTab> {
  static const _defaultSaKg = 3.0;

  final _membersCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController();
  String _selectedFood = 'گندم';
  double _saKg = _defaultSaKg;
  bool _cashMode = false;
  bool _calcTouched = false;

  /// واحد پولی که قیمت قوت غالب و مبلغ نقدی با آن بیان می‌شود. همان واحد
  /// مشترک ابزارهای مالی است، پس اگر کاربر زکاتش را به افغانی حساب کند،
  /// فطریه هم افغانی است.
  AppCurrency _currency = AppCurrency.toman;

  String get _unit => _currency.unit;
  /// قیمت پیش‌فرض قوت غالب به واحد انتخاب‌شده؛ `null` یعنی این واحد عدد
  /// ایرانیِ پیش‌فرضی ندارد و کاربر خودش قیمت بازارش را می‌زند.
  double? get _defaultPrice =>
      _currency.isIranian ? _defaultPrices[_selectedFood] : null;

  static const Map<String, double> _defaultPrices = {
    'گندم': 20000,
    'برنج': 90000,
    'خرما': 60000,
    'کشمش': 100000,
    'جو': 18000,
    'آرد': 25000,
  };

  static const Map<String, IconData> _foodIcons = {
    'گندم': Icons.grass,
    'برنج': Icons.rice_bowl,
    'خرما': Icons.eco,
    'کشمش': Icons.circle_outlined,
    'جو': Icons.grain,
    'آرد': Icons.flatware_outlined,
  };

  static const List<String> _foods = [
    'گندم',
    'برنج',
    'خرما',
    'کشمش',
    'جو',
    'آرد',
  ];

  @override
  void initState() {
    super.initState();
    _priceCtrl.addListener(_onInputChanged);
    _membersCtrl.addListener(_onInputChanged);
    _loadSavedPrice();
    _loadSavedSa();
    _loadCurrency();
    // The unit is chosen only in Settings now; this tab stays open behind it
    // and must follow the change instead of keeping the unit it opened with.
    CurrencyStore.calculators.notifier.addListener(_onStoreCurrencyChanged);
  }

  @override
  void dispose() {
    CurrencyStore.calculators.notifier
        .removeListener(_onStoreCurrencyChanged);
    _priceCtrl.removeListener(_onInputChanged);
    _membersCtrl.removeListener(_onInputChanged);
    _membersCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _onStoreCurrencyChanged() {
    final next = CurrencyStore.calculators.notifier.value;
    if (!mounted || next == _currency) return;
    // A price typed for the old unit means something else in the new one, so
    // it is dropped rather than silently relabelled.
    setState(() {
      _currency = next;
      _priceCtrl.clear();
    });
    _loadSavedPrice();
  }

  /// Edits never hide the result — while it is showing it recomputes live.
  void _onInputChanged() {
    if (_calcTouched && mounted) setState(() {});
  }

  /// کلید ذخیرهٔ قیمت، **به‌تفکیک واحد**: ۲۰٬۰۰۰ تومان به‌عنوان ۲۰٬۰۰۰ دلار
  /// معنای دیگری دارد. تومان کلید قدیمی را نگه می‌دارد تا قیمت‌های ذخیره‌شدهٔ
  /// نسخه‌های قبل پیدا شوند؛ بقیهٔ واحدها کلید خودشان را دارند.
  static String _priceKey(String food, AppCurrency currency) =>
      currency == AppCurrency.toman
          ? 'fitr_zakat_price_$food'
          : 'fitr_zakat_price_${food}_${currency.code}';

  Future<void> _loadCurrency() async {
    final c = await CurrencyStore.calculators.load();
    if (!mounted || c == _currency) return;
    setState(() => _currency = c);
    await _loadSavedPrice();
  }

  Future<void> _loadSavedPrice() async {
    final code = _currency.code;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getDouble(_priceKey(_selectedFood, _currency));
      if (!mounted || code != _currency.code) return;
      setState(() {
        if (saved != null && saved > 0) {
          _priceCtrl.text = NumberFormat.formatPlain(saved);
          return;
        }
        // قیمت پیش‌فرض بازار ایران فقط برای واحدهای ایرانی معنا دارد؛
        // برای بقیه فیلد خالی می‌ماند تا کاربر قیمت واقعی خودش را بزند.
        final fallback = _defaultPrice;
        _priceCtrl.text =
            fallback == null ? '' : NumberFormat.formatPlain(fallback);
      });
    } catch (e) {
      AppLogger.warning('fitr_zakat_tab', 'price load failed: $e');
      if (mounted) {
        final fallback = _defaultPrice;
        setState(() {
          _priceCtrl.text =
              fallback == null ? '' : NumberFormat.formatPlain(fallback);
        });
      }
    }
  }

  Future<void> _savePrice(double price) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_priceKey(_selectedFood, _currency), price);
    } catch (e) {
      AppLogger.warning('fitr_zakat_tab', 'price save failed: $e');
    }
  }

  /// Remembers the sa' weight the user pays per staple (their marja's value),
  /// defaulting to the conservative 3 kg. Avoids hardcoding fiqh-specific
  /// per-food weights while still making the choice stick across switches.
  ///
  /// A food with nothing saved falls back to the default rather than keeping
  /// [_saKg]: switching from a staple the reader had tuned to 3.5 kg used to
  /// carry that 3.5 into a food they never touched, so the page showed a weight
  /// that belonged to the previous food — a wrong answer that looked deliberate.
  Future<void> _loadSavedSa() async {
    final food = _selectedFood;
    double? saved;
    try {
      final prefs = await SharedPreferences.getInstance();
      saved = prefs.getDouble('fitr_zakat_sa_$food');
    } catch (e) {
      AppLogger.warning('fitr_zakat_tab', 'sa load failed: $e');
    }
    if (!mounted || food != _selectedFood) return;
    final next = (saved != null && saved > 0) ? saved : _defaultSaKg;
    if (next == _saKg) return;
    setState(() => _saKg = next);
  }

  Future<void> _saveSa(String food, double sa) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('fitr_zakat_sa_$food', sa);
    } catch (e) {
      AppLogger.warning('fitr_zakat_tab', 'sa save failed for $food: $e');
    }
  }

  void _selectFood(String food) {
    if (food == _selectedFood) return;
    setState(() {
      _selectedFood = food;
    });
    _loadSavedPrice();
    _loadSavedSa();
  }

  int get _members => NumberFormat.parse(_membersCtrl.text).round();

  double get _price => NumberFormat.parse(_priceCtrl.text);

  double get _totalKg => _members * _saKg;

  double get _totalCash => _totalKg * _price;

  void _calculate() {
    FocusScope.of(context).unfocus();
    setState(() {
      _calcTouched = true;
      if (_price > 0) _savePrice(_price);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = FitrZakatTab._accent;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        EducationHeroHeader(
          icon: Icons.redeem_outlined,
          title: 'زکات فطر',
          subtitle: 'فطریه — واجب پایان ماه رمضان، به جای صاع از قوت غالب',
          accentColor: accent,
        ),
        const SizedBox(height: 12),
        _buildIntroCard(isDark, accent),
        const SizedBox(height: 16),
        SectionHeader(
          title: 'حسابگر زکات فطر',
          icon: Icons.calculate_outlined,
          accentColor: accent,
        ),
        const SizedBox(height: 8),
        _buildCalculatorCard(isDark, accent),
        if (_calcTouched) ...[
          const SizedBox(height: 12),
          _buildResultCard(isDark, accent),
        ],
        const SizedBox(height: 16),
        _buildRulingsSection(isDark, accent),
        const SizedBox(height: 16),
        _buildRecipientsSection(accent),
        const SizedBox(height: 16),
        _buildTimeSection(isDark, accent),
        const SizedBox(height: 12),
        InfoBox(
          text:
              'این ابزار جنبهٔ راهنمایی دارد؛ برای مقدار دقیق بر اساس قوت غالب منطقهٔ خود و نظر علمای مورد اعتماد، با فقیه مشورت کنید.',
          color: accent,
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  //  Intro card
  // ═══════════════════════════════════════════
  Widget _buildIntroCard(bool isDark, Color accent) {
    final t = TimeThemeKit.of(context).palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A1C3A) : const Color(0xFFF3E5F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.volunteer_activism, size: 22, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text('فطریه چیست؟',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 15),
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'زکات فطر یک واجب مالی است که در پایان ماه رمضان، هر مسلمان برای خود و افراد تحت تکفلش (همسر، فرزندان، واجب‌النفقه‌ها) می‌پردازد. مقدار آن یک صاع از قوت غالب منطقه است؛ اگر صاع به‌صورت پول پرداخت شود، قیمت همان مقدار حساب می‌شود.',
            textDirection: TextDirection.rtl,
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 13),
                color: t.textSecondary,
                height: 1.6),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  Calculator card
  // ═══════════════════════════════════════════
  Widget _buildCalculatorCard(bool isDark, Color accent) {
    final t = TimeThemeKit.of(context).palette;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: t.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Members ──
          _fieldLabel(
              'تعداد افراد خانواده (شامل خودتان)', Icons.group_outlined),
          const SizedBox(height: 8),
          TextField(
            controller: _membersCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: 'مثلاً 4',
              suffixText: 'نفر',
              prefixIcon: const Icon(Icons.people_alt_outlined, size: 20),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 15),
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),

          // ── Food selection ──
          _fieldLabel('قوت غالب / نوع ماده', Icons.grass),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _foods.map((food) {
              final selected = food == _selectedFood;
              return InkWell(
                onTap: () => _selectFood(food),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? accent
                        : t.surfaceMuted,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? accent
                          : t.outline.withValues(alpha: isDark ? 0.3 : 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_foodIcons[food],
                          size: 15,
                          color: selected
                              ? Colors.white
                              : t.textMuted),
                      const SizedBox(width: 6),
                      Text(food,
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 12),
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? Colors.white
                                  : t.textPrimary)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // ── Sa' amount ──
          _fieldLabel('مقدار هر نفر (صاع)', Icons.square_foot),
          const SizedBox(height: 8),
          Row(
            children: [2.5, 2.75, 3.0].map((sa) {
              final selected = sa == _saKg;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    onTap: () {
                      setState(() => _saKg = sa);
                      _saveSa(_selectedFood, sa);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? accent.withValues(alpha: 0.15)
                            : t.surfaceMuted,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? accent
                              : t.outline.withValues(alpha: isDark ? 0.3 : 0.5),
                          width: selected ? 1.5 : 0.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            sa == sa.roundToDouble()
                                ? sa.toStringAsFixed(0)
                                : sa.toStringAsFixed(2),
                            style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: AppTheme.scaledFontSize(context, 15),
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? dsContentColor(context, accent)
                                    : t.textPrimary),
                          ),
                          Text('کیلوگرم',
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize:
                                      AppTheme.scaledFontSize(context, 10),
                                  color: t.textMuted)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // ── Price ──
          _fieldLabel(
              'قیمت هر کیلوگرم $_selectedFood', Icons.payments_outlined),
          const SizedBox(height: 8),
          TextField(
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: const [LatinGroupingFormatter()],
            decoration: InputDecoration(
              hintText: 'قیمت روز',
              suffixText: _unit,
              prefixIcon: const Icon(Icons.currency_exchange, size: 20),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 15),
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),

          // ── Payment mode ──
          _fieldLabel('نحوه پرداخت', Icons.payment),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _modeChip(
                    isDark: isDark,
                    accent: accent,
                    icon: Icons.agriculture,
                    label: 'جنسی (کالا)',
                    selected: !_cashMode,
                    onTap: () => setState(() => _cashMode = false)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _modeChip(
                    isDark: isDark,
                    accent: accent,
                    icon: Icons.payments_outlined,
                    label: 'نقدی ($_unit)',
                    selected: _cashMode,
                    onTap: () => setState(() => _cashMode = true)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Calculate ──
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _calculate,
              icon: const Icon(Icons.calculate_outlined, size: 20),
              label: Text('محاسبه زکات فطر',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 15),
                      fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text, IconData icon) {
    final t = TimeThemeKit.of(context).palette;
    return Row(
      children: [
        Icon(icon, size: 16, color: t.textMuted),
        const SizedBox(width: 6),
        Text(text,
            textDirection: TextDirection.rtl,
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12),
                fontWeight: FontWeight.w600,
                color: t.textSecondary)),
      ],
    );
  }

  Widget _modeChip({
    required bool isDark,
    required Color accent,
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final t = TimeThemeKit.of(context).palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.15)
              : t.surfaceMuted,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? accent
                : t.outline.withValues(alpha: isDark ? 0.3 : 0.5),
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 20,
                color: selected
                    ? dsContentColor(context, accent)
                    : t.textMuted),
            const SizedBox(height: 4),
            Text(label,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? dsContentColor(context, accent)
                        : t.textPrimary)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  Result card
  // ═══════════════════════════════════════════
  Widget _buildResultCard(bool isDark, Color accent) {
    final t = TimeThemeKit.of(context).palette;
    final warning = isDark ? AppTheme.darkWarning : AppTheme.lightWarning;
    final members = _members;
    final kg = _totalKg;
    final cash = _totalCash;
    final hasPrice = _price > 0;

    if (members <= 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: warning.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: warning),
            const SizedBox(width: 10),
            Expanded(
              child: Text('تعداد افراد باید حداقل 1 نفر باشد.',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 13),
                      color: t.textPrimary)),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A1C3A) : const Color(0xFF7B1FA2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.check_circle,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Text('زکات فطر شما',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 16),
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ],
            ),
            const SizedBox(height: 16),
            if (_cashMode && hasPrice) ...[
              Center(
                child: Text(NumberFormat.formatPlain(cash),
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 36),
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
              Center(
                child: Text('$_unit (نقدی)',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        color: Colors.white.withValues(alpha: 0.7))),
              ),
            ] else ...[
              Center(
                child: Text(
                    '${kg == kg.roundToDouble() ? kg.toInt().toString() : kg.toStringAsFixed(2)} کیلوگرم',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 32),
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
              Center(
                child: Text(
                    _cashMode && !hasPrice
                        ? 'برای محاسبه نقدی، قیمت روز را وارد کنید'
                        : '$_selectedFood — پرداخت جنسی',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        color: Colors.white.withValues(alpha: 0.7))),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _resRow('تعداد افراد', '$members نفر'),
                  _resRow('صاع هر نفر', '${_saKg.toStringAsFixed(2)} کیلوگرم'),
                  _resRow('مقدار کل جنسی',
                      '${kg == kg.roundToDouble() ? kg.toInt().toString() : kg.toStringAsFixed(2)} کیلوگرم'),
                  if (_cashMode && hasPrice)
                    _resRow('مبلغ کل نقدی',
                        '${NumberFormat.formatPlain(cash)} $_unit'),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'بهترین زمان پرداخت: صبح عید فطر، پیش از نماز عید.',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  color: Colors.white.withValues(alpha: 0.8),
                  height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  color: Colors.white.withValues(alpha: 0.8))),
          const Spacer(),
          Text(value,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  Rulings section
  // ═══════════════════════════════════════════
  Widget _buildRulingsSection(bool isDark, Color accent) {
    const rulings = [
      {
        'title': 'حکم',
        'text':
            'زکات فطر بر هر مسلمانِ صاحبِ قوتِ بیش از نیاز خود و خانواده‌اش، برای خود و واجب‌النفقه‌هایش واجب است. جنین در ماه آخر هم در برخی مذاهب مستحب است.',
        'icon': Icons.gavel_outlined,
      },
      {
        'title': 'مقدار',
        'text':
            'مقدار یک صاع از قوت غالب منطقه است (معادل تقریبی 2.5 تا 3 کیلوگرم گندم، برنج، خرما، کشمش یا جو). صاع با توجه به وزن هر ماده کمی متفاوت است.',
        'icon': Icons.square_foot,
      },
      {
        'title': 'پرداخت نقدی',
        'text':
            'بسیاری از فقها پرداخت ارزش (قیمت) صاع را به پول جایز میدانند؛ مخصوصاً وقتی برای نیازمند مفیدتر است. در صورتی که به «جنسی» پایبند باشید، خود کالا را پرداخت میکنید.',
        'icon': Icons.payments_outlined,
      },
      {
        'title': 'حکمت',
        'text':
            'فلسفه زکات فطر، طهارت روزهدار از لغو و بیهودهگویی و بینیاز کردن فقیران در روز عید است.',
        'icon': Icons.tips_and_updates_outlined,
      },
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'احکام زکات فطر',
          icon: Icons.auto_stories_outlined,
          accentColor: accent,
        ),
        const SizedBox(height: 8),
        ...rulings.map((r) => RulingCard(
              title: (r['title'] ?? '') as String,
              body: (r['text'] ?? '') as String,
              icon: r['icon'] as IconData,
              iconColor: accent,
            )),
      ],
    );
  }

  // ═══════════════════════════════════════════
  //  Recipients section
  // ═══════════════════════════════════════════
  Widget _buildRecipientsSection(Color accent) {
    final t = TimeThemeKit.of(context).palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'مصارف زکات فطر',
          icon: Icons.handshake_outlined,
          accentColor: accent,
          subtitle: 'مصارف هشتگانه زکات',
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: t.outline),
          ),
          child: Column(
            children: [
              ...<String>[
                'فقرا (کسانی که درآمد کافی ندارند)',
                'مساکین (نیازمندان شدیدتر)',
                'عاملان زکات (کارگزاران جمع‌آوری)',
                'تألیف قلوب (نو مسلمانان برای دلگرمی)',
                'آزادی بردگان و اسیران',
                'بدهکارانِ ناتوان از پرداخت',
                'در راه خدا (فی سبیل الله)',
                'در راه ماندگان (ابن سبیل)',
              ].map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 15, color: accent),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(item,
                                textDirection: TextDirection.rtl,
                                style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize:
                                        AppTheme.scaledFontSize(context, 13),
                                    color: t.textSecondary,
                                    height: 1.4))),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  //  Time section
  // ═══════════════════════════════════════════
  Widget _buildTimeSection(bool isDark, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'زمان پرداخت',
          icon: Icons.schedule,
          accentColor: accent,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _timeItem(
                'بهترین زمان',
                'صبح عید فطر، پیش از نماز عید',
                Icons.wb_sunny_outlined,
                accent,
              ),
              const SizedBox(height: 8),
              _timeItem(
                'وقت جواز',
                'برخی از علما از چند روز قبل از عید پرداخت را جایز دانسته اند؛ وقت اصلی از غروب آخرین روز رمضان تا شب عید فطر است.',
                Icons.schedule,
                accent,
              ),
              const SizedBox(height: 8),
              _timeItem(
                'قضا',
                'اگر پرداخت به تأخیر بیفتد، باز هم واجب است و باید بدون تعلل قضا شود',
                Icons.update,
                accent,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _timeItem(String title, String text, IconData icon, Color accent) {
    final t = TimeThemeKit.of(context).palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 13),
                      fontWeight: FontWeight.w700,
                      color: dsContentColor(context, accent))),
              const SizedBox(height: 2),
              Text(text,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 12),
                      color: t.textSecondary,
                      height: 1.5)),
            ],
          ),
        ),
      ],
    );
  }
}

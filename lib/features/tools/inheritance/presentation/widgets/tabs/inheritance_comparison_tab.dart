import 'package:tawheeed/shared/models/app_currency.dart';
import 'package:tawheeed/shared/widgets/currency_aware_state.dart';
import 'package:flutter/material.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/shared/widgets/number_input_formatters.dart';

import 'package:tawheeed/features/tools/inheritance/domain/inheritance_calculator.dart';
import 'package:tawheeed/features/tools/inheritance/domain/madhhab_comparison.dart';
import 'package:tawheeed/features/tools/inheritance/data/inheritance_content.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/inheritance_palette.dart';

class InheritanceComparisonTab extends StatefulWidget {
  const InheritanceComparisonTab({super.key});

  @override
  State<InheritanceComparisonTab> createState() =>
      _InheritanceComparisonTabState();
}

class _InheritanceComparisonTabState
    extends State<InheritanceComparisonTab>
    with CurrencyAwareState<InheritanceComparisonTab> {

  /// عدد پیش‌فرض ترکه در مقیاس تومان انتخاب شده است؛ اگر واحد عوض شود و
  /// کاربر هنوز همان عدد را دست نزده باشد، پاک می‌شود تا نتیجه‌ای مثل
  /// «یک میلیارد دلار» ساخته نشود.
  @override
  void onCurrencyChanged(AppCurrency next) {
    if (_estateCtrl.text == '1,000,000,000') _estateCtrl.clear();
    setState(() => _results = null);
  }

  static const Color _accent = InheritancePalette.accent;

  final _estateCtrl = TextEditingController(text: '1,000,000,000');
  final _funeralCtrl = TextEditingController();
  final _debtCtrl = TextEditingController();
  final _willCtrl = TextEditingController();
  final _willCtrl2 = TextEditingController();
  final _willCtrl3 = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isMale = true;
  bool _showExpenses = false;
  bool _heirsConsentExceedThird = false;

  final Map<HeirType, int> _counts = {
    for (final t in HeirType.values) t: 0,
  };

  Map<Madhab, InheritanceResult>? _results;

  static const List<(HeirType, String, IconData)> _options = [
    (HeirType.husband, 'شوهر', Icons.man),
    (HeirType.wife, 'همسر', Icons.woman),
    (HeirType.son, 'پسر', Icons.boy),
    (HeirType.daughter, 'دختر', Icons.girl),
    (HeirType.father, 'پدر', Icons.elderly),
    (HeirType.mother, 'مادر', Icons.elderly_woman),
    (
      HeirType.maternalGrandmother,
      'مادربزرگ مادری (مادرِ مادر)',
      Icons.elderly_woman
    ),
    (
      HeirType.paternalGrandmother,
      'مادربزرگ پدری (مادرِ پدر)',
      Icons.elderly_woman
    ),
    (HeirType.grandfather, 'پدربزرگ پدری (پدرِ پدر)', Icons.elderly),
    (HeirType.grandson, 'پسرِ پسر', Icons.boy),
    (HeirType.granddaughter, 'دخترِ پسر', Icons.girl),
    (HeirType.fullBrother, 'برادر (پدری و مادری)', Icons.diversity_1),
    (HeirType.fullSister, 'خواهر (پدری و مادری)', Icons.diversity_1),
    (HeirType.paternalBrother, 'برادر پدری', Icons.diversity_1),
    (HeirType.paternalSister, 'خواهر پدری', Icons.diversity_1),
    (HeirType.maternalBrother, 'برادر مادری', Icons.diversity_1),
    (HeirType.maternalSister, 'خواهر مادری', Icons.diversity_1),
    (HeirType.nephewFull, 'پسرِ برادرِ پدری و مادری', Icons.diversity_1),
    (HeirType.nephewPaternal, 'پسرِ برادرِ پدری', Icons.diversity_1),
    (HeirType.paternalUncle, 'عمو (برادر پدر)', Icons.elderly),
    (HeirType.paternalUncleSon, 'پسر عمو (پسر برادر پدر)', Icons.diversity_1),
    (HeirType.nieceSon, 'پسرِ خواهر', Icons.boy),
    (HeirType.nieceFull, 'دخترِ برادرِ پدری و مادری', Icons.girl),
    (HeirType.niecePaternal, 'دخترِ برادرِ پدری', Icons.girl),
    (HeirType.maternalUncle, 'دایی (برادرِ مادر)', Icons.elderly),
    (HeirType.maternalAunt, 'خاله (خواهرِ مادر)', Icons.elderly_woman),
    (HeirType.paternalAunt, 'عمه (خواهرِ پدر)', Icons.elderly_woman),
    (HeirType.uncleDaughter, 'دخترِ عمو', Icons.girl),
  ];

  int _maxCount(HeirType type) {
    switch (type) {
      case HeirType.husband:
        return 1;
      case HeirType.wife:
        return 4;
      case HeirType.father:
      case HeirType.mother:
      case HeirType.grandfather:
      case HeirType.maternalGrandmother:
      case HeirType.paternalGrandmother:
        return 1;
      default:
        return 99;
    }
  }

  List<(HeirType, String, IconData)> get _visibleOptions {
    return _options.where((o) {
      if (o.$1 == HeirType.husband && _isMale) return false;
      if (o.$1 == HeirType.wife && !_isMale) return false;
      return true;
    }).toList();
  }

  @override
  void dispose() {
    _estateCtrl.dispose();
    _funeralCtrl.dispose();
    _debtCtrl.dispose();
    _willCtrl.dispose();
    _willCtrl2.dispose();
    _willCtrl3.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// The current form state as an InheritanceInput — one mapping consumed by
  /// both the compareMadhhabs engine call and the blocking-diff pass, so the
  /// two can never disagree.
  InheritanceInput _currentInput() {
    return InheritanceInput(
      estate: NumberFormat.parse(_estateCtrl.text),
      funeralExpenses: NumberFormat.parse(_funeralCtrl.text),
      debts: NumberFormat.parse(_debtCtrl.text),
      willAmount: NumberFormat.parse(_willCtrl.text),
      willAmount2: NumberFormat.parse(_willCtrl2.text),
      willAmount3: NumberFormat.parse(_willCtrl3.text),
      heirsConsentExceedThird: _heirsConsentExceedThird,
      husband: (_counts[HeirType.husband] ?? 0),
      wife: (_counts[HeirType.wife] ?? 0),
      son: (_counts[HeirType.son] ?? 0),
      daughter: (_counts[HeirType.daughter] ?? 0),
      father: (_counts[HeirType.father] ?? 0),
      mother: (_counts[HeirType.mother] ?? 0),
      maternalGrandmother: (_counts[HeirType.maternalGrandmother] ?? 0),
      paternalGrandmother: (_counts[HeirType.paternalGrandmother] ?? 0),
      grandfather: (_counts[HeirType.grandfather] ?? 0),
      fullBrother: (_counts[HeirType.fullBrother] ?? 0),
      fullSister: (_counts[HeirType.fullSister] ?? 0),
      paternalBrother: (_counts[HeirType.paternalBrother] ?? 0),
      paternalSister: (_counts[HeirType.paternalSister] ?? 0),
      maternalBrother: (_counts[HeirType.maternalBrother] ?? 0),
      maternalSister: (_counts[HeirType.maternalSister] ?? 0),
      grandson: (_counts[HeirType.grandson] ?? 0),
      granddaughter: (_counts[HeirType.granddaughter] ?? 0),
      nephewFull: (_counts[HeirType.nephewFull] ?? 0),
      nephewPaternal: (_counts[HeirType.nephewPaternal] ?? 0),
      paternalUncle: (_counts[HeirType.paternalUncle] ?? 0),
      paternalUncleSon: (_counts[HeirType.paternalUncleSon] ?? 0),
      nieceSon: (_counts[HeirType.nieceSon] ?? 0),
      nieceFull: (_counts[HeirType.nieceFull] ?? 0),
      niecePaternal: (_counts[HeirType.niecePaternal] ?? 0),
      maternalUncle: (_counts[HeirType.maternalUncle] ?? 0),
      maternalAunt: (_counts[HeirType.maternalAunt] ?? 0),
      paternalAunt: (_counts[HeirType.paternalAunt] ?? 0),
      uncleDaughter: (_counts[HeirType.uncleDaughter] ?? 0),
    );
  }

  void _compare() {
    final estate = NumberFormat.parse(_estateCtrl.text);
    if (estate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('لطفاً مبلغ کل ترکه را به درستی وارد کنید.')),
      );
      return;
    }
    final selected = _counts.entries.where((e) => e.value > 0).toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً حداقل یک وارث را انتخاب کنید.')),
      );
      return;
    }

    // Single source of results: the shared compareMadhhabs engine over the
    // full comparison list (5 fiqh madhhabs + the civil-law codes). The old
    // hand-rolled `for (final madhab in Madhab.values)` loop recomputed every
    // code with the heirs and OVERWROTE the engine's fiqh results.
    final results = <Madhab, InheritanceResult>{};
    for (final c in compareMadhhabs(_currentInput(),
            madhhabs: MadhhabComparison.comparisonMadhhabs)
        .results) {
      results[c.madhab] = c;
    }
    setState(() => _results = results);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!InheritanceContent.isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? InheritancePalette.accentDark : _accent;
    final onPrimary = dsOnAccent(context);

    return ListView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(
          DsSpacing.page, 12, DsSpacing.page, 40),
      children: [
        // Header
        TabIntroCard(
          icon: Icons.compare_arrows,
          accent: accent,
          title: 'مقایسه مذاهب',
          subtitle: 'نتیجه محاسبه ارث در مذاهب فقهی',
        ),
        const SizedBox(height: 12),

        // Estate input
        TextField(
          controller: _estateCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: const [LatinGroupingFormatter()],
          decoration: InputDecoration(
            labelText: 'مبلغ کل ترکه ($unit)',
            suffixText: unit,
            prefixIcon: const Icon(Icons.account_balance_wallet, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 15),
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),

        // Expenses / debts / will toggle
        GestureDetector(
          onTap: () => setState(() => _showExpenses = !_showExpenses),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: TimeThemeKit.of(context).palette.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _accent.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Icon(
                  _showExpenses ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: accent,
                ),
                const SizedBox(width: 8),
                Icon(Icons.money_off, size: 18, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'کسر هزینه‌های کفن، دیون و وصیت‌ها',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 13),
                        fontWeight: FontWeight.w700,
                        color: TimeThemeKit.of(context).palette.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_showExpenses) ...[
          const SizedBox(height: 8),
          _inputField(_funeralCtrl, 'هزینه‌های تجهیز و تکفین', unit,
              Icons.local_hospital, isDark,
              color: accent),
          const SizedBox(height: 8),
          _inputField(
              _debtCtrl, 'دیون (بدهی‌ها)', unit, Icons.receipt_long, isDark,
              color: accent),
          const SizedBox(height: 8),
          _inputField(_willCtrl, 'وصیت اول (حداکثر ثلث)', unit,
              Icons.description_outlined, isDark,
              color: accent),
          const SizedBox(height: 8),
          _inputField(_willCtrl2, 'وصیت دوم', unit,
              Icons.description_outlined, isDark,
              color: accent),
          const SizedBox(height: 8),
          _inputField(_willCtrl3, 'وصیت سوم', unit,
              Icons.description_outlined, isDark,
              color: accent),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => setState(
                () => _heirsConsentExceedThird = !_heirsConsentExceedThird),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: TimeThemeKit.of(context).palette.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    _heirsConsentExceedThird
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    size: 22,
                    color: _heirsConsentExceedThird
                        ? accent
                        : TimeThemeKit.of(context).palette.textMuted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'آیا وراث با پرداخت وصیت بیش از یک‌سوم موافقت کرده‌اند؟',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 12),
                          fontWeight: FontWeight.w600,
                          color: TimeThemeKit.of(context).palette.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 4),
            child: Text(
              'هزینه‌های کفن و دفن، دیون و مجموع وصیت‌ها (تا سقف یک‌سوم، مگر با موافقت وراث) پیش از تقسیم ارث کسر می‌شود.',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  color: TimeThemeKit.of(context).palette.textMuted),
            ),
          ),
        ],
        const SizedBox(height: 12),

        // Gender selector
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _accent.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isMale = true;
                      // «شوهر» فقط برای متوفی زن معتبر است — با تعویض به مرد پاک شود.
                      _counts[HeirType.husband] = 0;
                    });
                    // نتیجهٔ نمایشدادهشده به جنسیت قبلی تعلق دارد؛ بازمحاسبه کن.
                    if (_results != null) _compare();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                        color: _isMale ? accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.man,
                              size: 18,
                              color: _isMale
                                  ? onPrimary
                                  : accent),
                          const SizedBox(width: 6),
                          Text('متوفی مرد',
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize:
                                      AppTheme.scaledFontSize(context, 13),
                                  fontWeight: FontWeight.w700,
                                  color: _isMale
                                      ? onPrimary
                                      : accent)),
                        ]),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isMale = false;
                      // «همسر» فقط برای متوفی مرد معتبر است — با تعویض به زن پاک شود.
                      _counts[HeirType.wife] = 0;
                    });
                    // نتیجهٔ نمایشدادهشده به جنسیت قبلی تعلق دارد؛ بازمحاسبه کن.
                    if (_results != null) _compare();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                        color: !_isMale ? accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.woman,
                              size: 18,
                              color: !_isMale
                                  ? onPrimary
                                  : accent),
                          const SizedBox(width: 6),
                          Text('متوفی زن',
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize:
                                      AppTheme.scaledFontSize(context, 13),
                                  fontWeight: FontWeight.w700,
                                  color: !_isMale
                                      ? onPrimary
                                      : accent)),
                        ]),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Heirs
        ..._visibleOptions.map((o) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: (_counts[o.$1] ?? 0) > 0
                        ? accent.withValues(alpha: 0.12)
                        : TimeThemeKit.of(context).palette.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(o.$3,
                      size: 20,
                      color: (_counts[o.$1] ?? 0) > 0
                          ? accent
                          : TimeThemeKit.of(context).palette.textMuted),
                ),
                title: Text(o.$2,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w600,
                        color: TimeThemeKit.of(context).palette.textPrimary)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: Colors.red),
                      tooltip: '${o.$2} — کاهش',
                      onPressed: (_counts[o.$1] ?? 0) > 0
                          ? () => setState(
                              () => _counts[o.$1] = (_counts[o.$1] ?? 0) - 1)
                          : null,
                    ),
                    SizedBox(
                      width: 30,
                      child: Center(
                        child: Text('${_counts[o.$1]}',
                            style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: AppTheme.scaledFontSize(context, 16),
                                fontWeight: FontWeight.bold,
                                color: TimeThemeKit.of(context).palette.textPrimary)),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.add_circle_outline,
                          color: (_counts[o.$1] ?? 0) < _maxCount(o.$1)
                              ? accent
                              : TimeThemeKit.of(context).palette.textMuted
                                  .withValues(alpha: 0.3)),
                      tooltip: '${o.$2} — افزایش',
                      onPressed: (_counts[o.$1] ?? 0) < _maxCount(o.$1)
                          ? () => setState(
                              () => _counts[o.$1] = (_counts[o.$1] ?? 0) + 1)
                          : null,
                    ),
                  ],
                ),
              ),
            )),
        const SizedBox(height: 16),

        // Compare button
        FilledButton.icon(
          onPressed: _compare,
          icon: const Icon(Icons.compare_arrows, size: 20),
          label: const Text('مقایسه مذاهب'),
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

        // Results — grouped by similarity
        if (_results != null) ...[
          const SizedBox(height: 20),
          ..._buildBlockingDiffs(isDark, accent),
          ..._buildGroupedResults(isDark, accent),
        ],

        // ── بخش اطلاعات مذاهب ──
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.mosque_outlined, size: 20, color: accent),
                  const SizedBox(width: 8),
                  Text('معرفی مذاهب فقهی',
                      style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 14),
                          fontWeight: FontWeight.w700,
                          color: accent,
                          fontFamily: AppTheme.fontFamily)),
                ],
              ),
              const SizedBox(height: 12),
              ...Madhab.values.map((madhab) {
                final info = InheritanceContent.madhabInfo[madhab] ?? const {};
                const colors = InheritancePalette.madhabColors;
                final c = colors[madhab] ?? accent;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: TimeThemeKit.of(context).palette.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: c.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6)),
                            child: Text((info['name'] ?? ''),
                                style: TextStyle(
                                    fontSize:
                                        AppTheme.scaledFontSize(context, 12),
                                    fontWeight: FontWeight.w700,
                                    color: c,
                                    fontFamily: AppTheme.fontFamily)),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        Text('مؤسس: ${info['founder']}',
                            style: TextStyle(
                                fontSize: AppTheme.scaledFontSize(context, 11),
                                color: TimeThemeKit.of(context).palette.textSecondary,
                                fontFamily: AppTheme.fontFamily)),
                        const SizedBox(height: 4),
                        Text((info['description'] ?? ''),
                            style: TextStyle(
                                fontSize: AppTheme.scaledFontSize(context, 11),
                                color: TimeThemeKit.of(context).palette.textSecondary,
                                fontFamily: AppTheme.fontFamily,
                                height: 1.6)),
                        const SizedBox(height: 4),
                        Text('اصول: ${info['keyPrinciple']}',
                            style: TextStyle(
                                fontSize: AppTheme.scaledFontSize(context, 11),
                                color: c,
                                fontFamily: AppTheme.fontFamily,
                                fontWeight: FontWeight.w600)),
                        if (info['regions'] != null) ...[
                          const SizedBox(height: 4),
                          Text('مناطق: ${info['regions']}',
                              style: TextStyle(
                                  fontSize:
                                      AppTheme.scaledFontSize(context, 10),
                                  color: TimeThemeKit.of(context).palette.textMuted,
                                  fontFamily: AppTheme.fontFamily)),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),

        // ── بخش اختلافات فقهی ──
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: TimeThemeKit.of(context).palette.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: TimeThemeKit.of(context).palette.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.compare_arrows, size: 20, color: accent),
                  const SizedBox(width: 8),
                  Text('اختلافات فقهی در مسائل ارث',
                      style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 14),
                          fontWeight: FontWeight.w700,
                          color: accent,
                          fontFamily: AppTheme.fontFamily)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                  'نکته مهم: اختلافات بالا در مسائل پیچیده ارث است. در اکثر مسائل اصلی، چهار مذهب اتفاق نظر دارند.',
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 11),
                      color: TimeThemeKit.of(context).palette.textMuted,
                      fontFamily: AppTheme.fontFamily,
                      height: 1.5)),
              const SizedBox(height: 12),
              ...InheritanceContent.fiqhDifferences.map((diff) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text((diff['title'] ?? ''),
                            style: TextStyle(
                                fontSize: AppTheme.scaledFontSize(context, 12),
                                fontWeight: FontWeight.w700,
                                color: accent,
                                fontFamily: AppTheme.fontFamily)),
                      ),
                      const SizedBox(height: 6),
                      _diffRow('حنفی', (diff['hanafi'] ?? ''),
                          InheritancePalette.fard),
                      _diffRow('مالکی', (diff['maliki'] ?? ''),
                          AppTheme.success),
                      _diffRow('شافعی', (diff['shafii'] ?? ''),
                          InheritancePalette.accent),
                      _diffRow('حنبلی', (diff['hanbali'] ?? ''),
                          AppTheme.warning),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
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
        prefixIcon:
            Icon(icon, size: 20, color: color ?? TimeThemeKit.of(context).palette.textMuted),
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

  Widget _diffRow(String label, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3, right: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                      text: '$label: ',
                      style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 11),
                          fontWeight: FontWeight.w700,
                          color: color,
                          fontFamily: AppTheme.fontFamily)),
                  TextSpan(
                      text: text,
                      style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 11),
                          color: TimeThemeKit.of(context).palette.textSecondary,
                          fontFamily: AppTheme.fontFamily,
                          height: 1.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Cross-madhab heir blocking differences (the engine's unique value):
  /// for every selected heir that inherits under SOME madhabs but is
  /// blocked under OTHERS, name both camps. Empty when all five agree.
  List<Widget> _buildBlockingDiffs(bool isDark, Color accent) {
    if (_results == null || _results!.isEmpty) return [];
    final diffs = crossMadhabBlockingDiffs(_currentInput());
    if (diffs.isEmpty) return [];

    return [
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: isDark ? 0.12 : 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.rule, size: 18, color: accent),
              const SizedBox(width: 8),
              Text('تفاوت حجب میان مذاهب',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 14),
                      fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 8),
            for (final d in diffs)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${d.label}: ارث می‌برد در ${d.inherits.map(madhabLabel).join('، ')}'
                  ' — محجوب در ${d.blocked.map(madhabLabel).join('، ')}',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 12.5),
                      height: 1.5),
                ),
              ),
          ],
        ),
      ),
    ];
  }

  /// Build grouped comparison: madhabs with identical results are shown
  /// once under "جمهور" (consensus), only differences are highlighted.
  List<Widget> _buildGroupedResults(bool isDark, Color accent) {
    if (_results == null || _results!.isEmpty) return [];

    // Create a signature for each result to detect identical ones.
    String resultSignature(InheritanceResult r) {
      final sharesStr = r.shares
          .map((s) =>
              '${s.type}:${s.fraction.toArString()}:${s.amount.toStringAsFixed(0)}')
          .join('|');
      return '${r.method}:$sharesStr';
    }

    // Group madhabs by their result signature.
    final groups = <String, List<Madhab>>{};
    final sigResults = <String, InheritanceResult>{};
    for (final entry in _results!.entries) {
      final sig = resultSignature(entry.value);
      groups.putIfAbsent(sig, () => []).add(entry.key);
      sigResults[sig] = entry.value;
    }

    final widgets = <Widget>[];

    // If all 4 madhabs agree, show a single consensus card.
    if (groups.length == 1) {
      final sig = groups.keys.first;
      final result = sigResults[sig];
      if (result != null) widgets.add(_consensusCard(result, isDark, accent));
      return widgets;
    }

    // Find the consensus group (the one with most madhabs).
    final sortedGroups = groups.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    for (final group in sortedGroups) {
      final madhabs = group.value;
      final result = sigResults[group.key];
      if (result == null) continue;

      if (madhabs.length >= 3) {
        // Consensus: 3 or 4 madhabs agree
        widgets
            .add(_consensusCard(result, isDark, accent, extraMadhabs: madhabs));
      } else {
        // Minority opinion: show each madhab separately
        for (final madhab in madhabs) {
          widgets.add(_comparisonCard(madhab, result, isDark, accent));
        }
      }
    }

    return widgets;
  }

  Widget _consensusCard(InheritanceResult result, bool isDark, Color accent,
      {List<Madhab>? extraMadhabs}) {
    final allMadhabs = extraMadhabs ?? _results!.keys.toList();
    final labels = allMadhabs.map(madhabLabel).join('، ');
    final isFullConsensus =
        _results!.isNotEmpty && allMadhabs.length >= _results!.length;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    final warning = isDark ? AppTheme.darkWarning : AppTheme.lightWarning;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TimeThemeKit.of(context).palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(
                  isFullConsensus ? 'جمهور' : 'اکثریت',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 14),
                      fontWeight: FontWeight.w700,
                      color: accent),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(
                    isFullConsensus ? '' : '($labels)',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 11),
                        fontWeight: FontWeight.w600,
                        color: TimeThemeKit.of(context).palette.textSecondary),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: result.method == 'normal'
                        ? success.withValues(alpha: 0.14)
                        : warning.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(result.methodLabel,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 10),
                        fontWeight: FontWeight.w600,
                        color: result.method == 'normal'
                            ? success
                            : warning)),
              ),
            ],
          ),
          if (!isFullConsensus) ...[
            const SizedBox(height: 4),
            Text('مذاهب $labels',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 10),
                    color: TimeThemeKit.of(context).palette.textMuted)),
          ],
          const SizedBox(height: 10),
          ...result.shares.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Text(heirLabel(s.type),
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 12),
                            color: TimeThemeKit.of(context).palette.textPrimary)),
                    const SizedBox(width: 8),
                    Text(s.fraction.toArString(),
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 12),
                            fontWeight: FontWeight.w700,
                            color: accent)),
                    const Spacer(),
                    Text(NumberFormat.formatMoney(s.amount, unit),
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 12),
                            fontWeight: FontWeight.w600,
                            color: TimeThemeKit.of(context).palette.textSecondary)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _comparisonCard(
      Madhab madhab, InheritanceResult result, bool isDark, Color accent) {
    const colors = InheritancePalette.madhabColors;
    final madhabColor = colors[madhab] ?? accent;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    final warning = isDark ? AppTheme.darkWarning : AppTheme.lightWarning;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TimeThemeKit.of(context).palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: madhabColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: madhabColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(madhabLabel(madhab),
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w700,
                        color: madhabColor)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: result.method == 'normal'
                        ? success.withValues(alpha: 0.14)
                        : warning.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(result.methodLabel,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 10),
                        fontWeight: FontWeight.w600,
                        color: result.method == 'normal'
                            ? success
                            : warning)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...result.shares.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Text(heirLabel(s.type),
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 12),
                            color: TimeThemeKit.of(context).palette.textPrimary)),
                    const SizedBox(width: 8),
                    Text(s.fraction.toArString(),
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 12),
                            fontWeight: FontWeight.w700,
                            color: madhabColor)),
                    const Spacer(),
                    Text(NumberFormat.formatMoney(s.amount, unit),
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 12),
                            fontWeight: FontWeight.w600,
                            color: TimeThemeKit.of(context).palette.textSecondary)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

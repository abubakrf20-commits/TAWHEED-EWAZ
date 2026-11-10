import 'package:tawheeed/shared/models/app_currency.dart';
import 'package:tawheeed/shared/widgets/currency_aware_state.dart';
import 'package:flutter/material.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/shared/widgets/number_input_formatters.dart';

import 'package:tawheeed/features/tools/inheritance/domain/inheritance_calculator.dart';
import 'package:tawheeed/features/tools/inheritance/domain/madhab_calculator.dart';
import 'package:tawheeed/features/tools/inheritance/domain/madhab_rules.dart';
import 'package:tawheeed/features/tools/inheritance/domain/detailed_solution.dart';
import 'package:tawheeed/features/tools/inheritance/domain/blocked_heirs.dart';
import 'package:tawheeed/features/tools/inheritance/data/inheritance_content.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/inheritance_amount_input.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/heir_catalog.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tawheeed/features/tools/inheritance/domain/inheritance_share_text.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/widgets/inheritance_pie_chart.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/widgets/inheritance_share_card.dart';
import 'package:tawheeed/shared/services/share_service.dart';
import 'package:tawheeed/shared/services/share_widget_as_image.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/widgets/munasakhat_sheet_content.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/widgets/inheritance_report_pdf.dart';
import 'package:tawheeed/features/tools/shared/pdf_report_util.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/inheritance_palette.dart';
part 'inheritance_result_card.dart';

class InheritanceCalculatorTab extends StatefulWidget {
  const InheritanceCalculatorTab({super.key});

  @override
  State<InheritanceCalculatorTab> createState() =>
      _InheritanceCalculatorTabState();
}

class _InheritanceCalculatorTabState
    extends State<InheritanceCalculatorTab>
    with CurrencyAwareState<InheritanceCalculatorTab> {

  /// عدد پیش‌فرض ترکه در مقیاس تومان انتخاب شده است؛ اگر واحد عوض شود و
  /// کاربر هنوز همان عدد را دست نزده باشد، پاک می‌شود تا نتیجه‌ای مثل
  /// «یک میلیارد دلار» ساخته نشود.
  @override
  void onCurrencyChanged(AppCurrency next) {
    if (_estateCtrl.text == '1,000,000,000') _estateCtrl.clear();
    setState(() {
      _result = null;
    });
  }

  static const Color _accent = InheritancePalette.accent;

  final _estateCtrl = TextEditingController(text: '1,000,000,000');
  final _debtCtrl = TextEditingController();
  final _funeralCtrl = TextEditingController();
  final _willCtrl = TextEditingController();
  final _willCtrl2 = TextEditingController();
  final _willCtrl3 = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isMale = true;
  bool _heirsConsentExceedThird = false;
  bool _applyMandatoryWill = false;
  int _orphanGrandsons = 0;
  int _orphanGranddaughters = 0;
  Madhab _selectedMadhab = Madhab.jumhur;

  final Map<HeirType, int> _counts = {
    for (final t in HeirType.values) t: 0,
  };

  /// Heirs that the current selection would exclude (محجوب): recomputed from
  /// the real حجب engine after every selection / madhab change so the tiles
  /// show a red icon while the user is still picking (before pressing «محاسبه»).
  Set<HeirType> _blockedPreview = {};

  InheritanceResult? _result;
  DetailedSolution? _solution;
  List<BlockedHeir>? _blockedHeirs;
  InheritanceInput? _lastInput;
  bool _showExpenses = true;
  bool _showDetailed = false;
  bool _showFractionCalc = false;

  /// Marks every heir that would receive nothing under the current selection,
  /// using the exact same حجب engine that [_calculate] runs — so the red
  /// preview can never disagree with the computed shares. For heirs not yet
  /// selected we ask "would this heir be blocked if present?" by adding it to
  /// the scenario for the check.
  Set<HeirType> _computeBlockedPreview() {
    final calculator = getCalculator(_selectedMadhab);
    final base = Map<HeirType, int>.from(_counts);
    final blocked = <HeirType>{};
    for (final t in HeirType.values) {
      final scenario = Map<HeirType, int>.from(base);
      if (scenario[t] == 0) scenario[t] = 1;
      if (calculator
          .blockedHeirs(InheritanceInput.fromCounts(scenario,
              madhab: _selectedMadhab))
          .contains(t)) {
        blocked.add(t);
      }
    }
    return blocked;
  }

  void _setCount(HeirType type, int value) {
    _counts[type] = value;
    final preview = _computeBlockedPreview();
    setState(() => _blockedPreview = preview);
  }

  @override
  void dispose() {
    _estateCtrl.dispose();
    _debtCtrl.dispose();
    _funeralCtrl.dispose();
    _willCtrl.dispose();
    _willCtrl2.dispose();
    _willCtrl3.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final estateParse = parseEstate(_estateCtrl.text);
    if (!estateParse.ok) {
      _showMessage(estateParse.error!);
      return;
    }
    final estate = estateParse.value;
    final selected = _counts.entries.where((e) => e.value > 0).toList();
    if (selected.isEmpty) {
      _showMessage('لطفاً حداقل یک وارث را انتخاب کنید.');
      return;
    }
    if (_isMale && (_counts[HeirType.husband] ?? 0) > 0) {
      _showMessage('متوفی مرد است — گزینه "شوهر" برای متوفی مرد مجاز نیست.');
      return;
    }
    if (!_isMale && (_counts[HeirType.wife] ?? 0) > 0) {
      _showMessage('متوفی زن است — گزینه "همسر" برای متوفی زن مجاز نیست.');
      return;
    }
    if ((_counts[HeirType.husband] ?? 0) > 1) {
      _showMessage('تعداد شوهر نمی‌تواند بیشتر از 1 باشد.');
      return;
    }
    if ((_counts[HeirType.wife] ?? 0) > 4) {
      _showMessage('تعداد همسر نمی‌تواند بیشتر از 4 باشد.');
      return;
    }
    if ((_counts[HeirType.father] ?? 0) > 1) {
      _showMessage('تعداد پدر نمی‌تواند بیشتر از 1 باشد.');
      return;
    }
    if ((_counts[HeirType.mother] ?? 0) > 1) {
      _showMessage('تعداد مادر نمی‌تواند بیشتر از 1 باشد.');
      return;
    }

    // NumberFormat.parse maps unreadable text to 0 and accepts negatives, so the
    // deduction fields go through the tested parser instead: a negative debt
    // or a will larger than the estate silently produced nonsense shares.
    final deductions = parseDeductions(
      funeralText: _funeralCtrl.text,
      debtText: _debtCtrl.text,
      willText: _willCtrl.text,
      will2Text: _willCtrl2.text,
      will3Text: _willCtrl3.text,
      estate: estate,
    );
    if (!deductions.ok) {
      _showMessage(deductions.error!);
      return;
    }
    final funeral = deductions.funeral;
    final debt = deductions.debts;
    final will = deductions.will1;
    final will2 = deductions.will2;
    final will3 = deductions.will3;

    final input = InheritanceInput(
      estate: estate,
      funeralExpenses: funeral,
      debts: debt,
      willAmount: will,
      willAmount2: will2,
      willAmount3: will3,
      heirsConsentExceedThird: _heirsConsentExceedThird,
      applyMandatoryWill: _applyMandatoryWill,
      orphanGrandsons: _orphanGrandsons,
      orphanGranddaughters: _orphanGranddaughters,
      madhab: _selectedMadhab,
      husband: (_counts[HeirType.husband] ?? 0),
      wife: (_counts[HeirType.wife] ?? 0),
      son: (_counts[HeirType.son] ?? 0),
      daughter: (_counts[HeirType.daughter] ?? 0),
      father: (_counts[HeirType.father] ?? 0),
      mother: (_counts[HeirType.mother] ?? 0),
      maternalGrandmother: (_counts[HeirType.maternalGrandmother] ?? 0),
      paternalGrandmother: (_counts[HeirType.paternalGrandmother] ?? 0),
      greatMaternalGrandmother:
          (_counts[HeirType.greatMaternalGrandmother] ?? 0),
      paternalGreatGrandmotherFather:
          (_counts[HeirType.paternalGreatGrandmotherFather] ?? 0),
      paternalGreatGrandmotherMother:
          (_counts[HeirType.paternalGreatGrandmotherMother] ?? 0),
      grandfather: (_counts[HeirType.grandfather] ?? 0),
      greatGrandfather: (_counts[HeirType.greatGrandfather] ?? 0),
      fullBrother: (_counts[HeirType.fullBrother] ?? 0),
      fullSister: (_counts[HeirType.fullSister] ?? 0),
      paternalBrother: (_counts[HeirType.paternalBrother] ?? 0),
      paternalSister: (_counts[HeirType.paternalSister] ?? 0),
      maternalBrother: (_counts[HeirType.maternalBrother] ?? 0),
      maternalSister: (_counts[HeirType.maternalSister] ?? 0),
      grandson: (_counts[HeirType.grandson] ?? 0),
      granddaughter: (_counts[HeirType.granddaughter] ?? 0),
      greatGrandson: (_counts[HeirType.greatGrandson] ?? 0),
      greatGranddaughter: (_counts[HeirType.greatGranddaughter] ?? 0),
      nephewFull: (_counts[HeirType.nephewFull] ?? 0),
      nephewPaternal: (_counts[HeirType.nephewPaternal] ?? 0),
      nephewSonFull: (_counts[HeirType.nephewSonFull] ?? 0),
      nephewSonPaternal: (_counts[HeirType.nephewSonPaternal] ?? 0),
      paternalUncle: (_counts[HeirType.paternalUncle] ?? 0),
      paternalUnclePaternal: (_counts[HeirType.paternalUnclePaternal] ?? 0),
      paternalUncleSon: (_counts[HeirType.paternalUncleSon] ?? 0),
      paternalUncleSonPaternal:
          (_counts[HeirType.paternalUncleSonPaternal] ?? 0),
      paternalUncleGrandson: (_counts[HeirType.paternalUncleGrandson] ?? 0),
      paternalUncleGrandsonPaternal:
          (_counts[HeirType.paternalUncleGrandsonPaternal] ?? 0),
      fatherUncleFull: (_counts[HeirType.fatherUncleFull] ?? 0),
      fatherUnclePaternal: (_counts[HeirType.fatherUnclePaternal] ?? 0),
      fatherCousinFull: (_counts[HeirType.fatherCousinFull] ?? 0),
      fatherCousinPaternal: (_counts[HeirType.fatherCousinPaternal] ?? 0),
      nieceSon: (_counts[HeirType.nieceSon] ?? 0),
      nieceFull: (_counts[HeirType.nieceFull] ?? 0),
      niecePaternal: (_counts[HeirType.niecePaternal] ?? 0),
      maternalUncle: (_counts[HeirType.maternalUncle] ?? 0),
      maternalAunt: (_counts[HeirType.maternalAunt] ?? 0),
      paternalAunt: (_counts[HeirType.paternalAunt] ?? 0),
      uncleDaughter: (_counts[HeirType.uncleDaughter] ?? 0),
    );

    final calculator = getCalculator(_selectedMadhab);
    setState(() {
      _result = calculator.calculate(input);
      _solution = calculateDetailedSolution(input);
      _blockedHeirs = analyzeBlockedHeirs(input, result: _result!);
      _lastInput = input;
      _showDetailed = false;
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
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text(msg, style: TextStyle(fontFamily: AppTheme.fontFamily))),
    );
  }

  Future<void> _shareResultText(InheritanceResult result) async {
    final estate = NumberFormat.parse(_estateCtrl.text);
    try {
      await SharePlus.instance.share(ShareParams(
        text: buildInheritanceShareText(result: result, estate: estate),
      ));
    } catch (e) {
      AppLogger.warning('inheritance_calculator_tab', 'error: $e');
      if (mounted) _showMessage('اشتراک‌گذاری متن ممکن نشد؛ دوباره تلاش کنید.');
    }
  }

  Future<void> _shareResultImage(InheritanceResult result) async {
    final estate = NumberFormat.parse(_estateCtrl.text);
    try {
      // Portrait card shared as a mobile-like vertical image (same capture
      // path as the دعا / حصن المسلم share cards), with the app logo footer
      // and the Telegram channel block attached as the share caption.
      await shareWidgetAsImage(
        context,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: InheritanceShareCard(result: result, estate: estate),
        ),
        fileName: 'inheritance_${DateTime.now().millisecondsSinceEpoch}.png',
        width: 420,
        pixelRatio: 5.0,
        text: ShareService.channelBlock,
      );
    } catch (e) {
      AppLogger.warning('inheritance_calculator_tab', 'error: $e');
      if (mounted) _showMessage('ساخت تصویر ممکن نشد؛ متن را به‌جای آن بفرستید.');
    }
  }

  Future<void> _shareResultPdf(InheritanceResult result) async {
    try {
      final bytes = await buildInheritanceReportPdf(
        result: result,
        estate: result.estate,
        unit: unit,
        blockedHeirs: _blockedHeirs,
        namedProblem: _solution?.namedProblems.isEmpty ?? true
            ? null
            : _solution?.namedProblems.first.fullName,
      );
      await shareToolReportPdf(
        bytes: bytes,
        fileName: 'inheritance_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      AppLogger.warning('inheritance_calculator_tab', 'error: $e');
      if (mounted) _showMessage('ساخت PDF ممکن نشد؛ دوباره تلاش کنید.');
    }
  }

  void _clearAll() {
    _estateCtrl.text = '1,000,000,000';
    _debtCtrl.clear();
    _funeralCtrl.clear();
    _willCtrl.clear();
    _willCtrl2.clear();
    _willCtrl3.clear();
    setState(() {
      for (final t in HeirType.values) {
        _counts[t] = 0;
      }
      _blockedPreview = {};
      _result = null;
      _solution = null;
      _blockedHeirs = null;
      _lastInput = null;
      _selectedMadhab = Madhab.jumhur;
      _heirsConsentExceedThird = false;
      _applyMandatoryWill = false;
      _orphanGrandsons = 0;
      _orphanGranddaughters = 0;
      _isMale = true;
      _showExpenses = true;
      _showDetailed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!InheritanceContent.isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? InheritancePalette.accentDark : _accent;

    return ListView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(
          DsSpacing.page, 12, DsSpacing.page, 40),
      children: [
        _buildIntroCard(isDark),
        const SizedBox(height: 12),
        _buildMadhabSelector(isDark, accent),
        const SizedBox(height: 12),
        _buildSectionHeader('مبلغ ترکه', isDark),
        const SizedBox(height: 8),
        _inputField(_estateCtrl, 'مبلغ کل ترکه ($unit)', unit,
            Icons.account_balance_wallet, isDark,
            color: accent),
        const SizedBox(height: 12),
        _buildExpensesToggle(isDark, accent),
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
                color:
                    TimeThemeKit.of(context).palette.surfaceAlt,
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
        GestureDetector(
          onTap: () =>
              setState(() => _applyMandatoryWill = !_applyMandatoryWill),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color:
                  TimeThemeKit.of(context).palette.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _applyMandatoryWill
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 22,
                      color: _applyMandatoryWill
                          ? accent
                          : TimeThemeKit.of(context).palette.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'آیا وصیت واجبه (به نوه‌های پسرِ فوت‌شده) اعمال شود؟',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 12),
                            fontWeight: FontWeight.w600,
                            color: TimeThemeKit.of(context).palette.textPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(right: 32),
                  child: Text(
                    'اگر پسر متوفی پیش از او فوت کرده و فرزندانی از خود گذاشته، به آن‌ها به‌اندازه سهم پدرشان (حداکثر یک‌سوم) وصیت اجباری داده می‌شود و از سهم سایر وراث کسر می‌گردد.',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 11),
                        color: TimeThemeKit.of(context).palette.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_applyMandatoryWill) ...[
          const SizedBox(height: 8),
          _orphanStepper('نوه پسرِ پسرِ فوت‌شده (یتیم)', _orphanGrandsons,
              (v) => setState(() => _orphanGrandsons = v), isDark, accent),
          const SizedBox(height: 8),
          _orphanStepper('نوه دخترِ پسرِ فوت‌شده (یتیم)', _orphanGranddaughters,
              (v) => setState(() => _orphanGranddaughters = v), isDark, accent),
        ],
        const SizedBox(height: 16),
        _buildGenderSelector(isDark, accent),
        const SizedBox(height: 12),
        _buildSectionHeader('انتخاب ورثه', isDark),
        const SizedBox(height: 8),
        ...visibleHeirOptions(isMale: _isMale)
            .map((o) => _heirTile(o, isDark, accent)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _calculate,
                icon: const Icon(Icons.calculate_outlined, size: 20),
                label: const Text('محاسبه میراث'),
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
                backgroundColor:
                    TimeThemeKit.of(context).palette.surfaceAlt,
              ),
            ),
          ],
        ),
        if (_result != null) ...[
          const SizedBox(height: 20),
          _buildResultCard(_result!, isDark, accent),
        ],
        // ── Munasakhat entry ──
        const SizedBox(height: 16),
        _buildSectionHeader('مناسخات (ارث چند مرحله‌ای)', isDark),
        const SizedBox(height: 8),
        _buildMunasakhatEntry(accent),
        const SizedBox(height: 16),
        _buildDisclaimer(isDark),
      ],
    );
  }

  Widget _buildFractionCalc(
      InheritanceResult result, bool isDark, Color accent) {
    final base = result.baseAsl;
    final asl = result.correctedAsl;
    final rows = result.shares
        .where((s) => s.shareType != ShareType.mandatoryWill)
        .toList();

    // سهم هر وارث بر مبنای اصل مسأله (بعد از عول/رد)
    final unitsOf = <InheritanceShare, int>{
      for (final s in rows) s: s.fraction.n * (asl ~/ s.fraction.d),
    };

    // تصحیح: پایه‌ای که سهم هر فرد عدد کامل شود
    var displayAsl = asl;
    for (final s in rows) {
      final u = (unitsOf[s] ?? 0);
      if (s.count > 1 && u % s.count != 0) {
        displayAsl =
            _fractionLcm(displayAsl, asl * s.count ~/ _fractionGcd(u, s.count));
      }
    }
    final dispUnitsOf = <InheritanceShare, int>{
      for (final s in rows) s: (unitsOf[s] ?? 0) * (displayAsl ~/ asl),
    };

    String methodLine;
    switch (result.method) {
      case 'awl':
        methodLine =
            'مجموع فرض‌ها بیش از کل ترکه بود؛ اصل مسأله از $base به $asl «عول» یافت و همه سهم‌ها به نسبت کاهش یافت.';
      case 'radd':
        methodLine =
            'پس از فرض‌ها باقی‌مانده‌ای ماند و عصبه‌ای نبود؛ بر اساس قاعده «رد» به صاحبان فرض برگشت و اصل مسأله $asl شد.';
      case 'distantKindred':
        methodLine =
            'وارث اصلی‌ای نبود؛ ترکه به نزدیک‌ترین خویشاوند دور (ذوی‌الأرحام) رسید و اصل مسأله $asl است.';
      case 'baytMal':
        methodLine =
            'پس از فرض‌ها باقی‌مانده‌ای ماند و صاحب فرضِ قابلِ «رد» یا عصبه‌ای یا ذی‌رحمی حاضر نبود؛ '
            'باقی‌مانده به بیت‌المال تعلق می‌گیرد و اصل مسأله $asl است.';
      default:
        methodLine = base == asl
            ? 'اصل مسأله $asl است و کسری برای تصحیح نبود.'
            : 'پس از تصحیح، اصل مسأله از $base به $asl شد.';
    }
    if (displayAsl != asl) {
      methodLine +=
          '\nبرای تقسیم سهم‌ها بین افراد، اصل مسأله به $displayAsl تصحیح شد.';
    }

    TextStyle headerStyle({Color? color}) => TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 11),
          fontWeight: FontWeight.w700,
          color: color ?? TimeThemeKit.of(context).palette.textMuted,
        );
    TextStyle cellStyle() => TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 11.5),
          color: TimeThemeKit.of(context).palette.textPrimary,
        );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TimeThemeKit.of(context).palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: TimeThemeKit.of(context).palette.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('اصل مسأله = $base',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 13),
                  fontWeight: FontWeight.w700,
                  color: accent)),
          const SizedBox(height: 6),
          Text(methodLine,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  color: TimeThemeKit.of(context).palette.textSecondary,
                  height: 1.5)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(flex: 3, child: Text('وارث', style: headerStyle())),
              Expanded(child: Text('تعداد', style: headerStyle())),
              Expanded(flex: 2, child: Text('سهم', style: headerStyle())),
              Expanded(flex: 2, child: Text('واحد اصل', style: headerStyle())),
              Expanded(
                  flex: 2, child: Text('سهم هر فرد', style: headerStyle())),
            ],
          ),
          const Divider(height: 16),
          for (final s in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                      flex: 3,
                      child: Text(heirLabel(s.type), style: cellStyle())),
                  Expanded(child: Text('${s.count}', style: cellStyle())),
                  Expanded(
                      flex: 2,
                      child: Text(s.fraction.toArString(), style: cellStyle())),
                  Expanded(
                      flex: 2,
                      child: Text('${dispUnitsOf[s]}/$displayAsl',
                          style: cellStyle())),
                  Expanded(
                      flex: 2, child: Text('$displayAsl', style: cellStyle())),
                  Expanded(
                      flex: 2,
                      child: Text(
                          s.count > 1
                              ? Frac((dispUnitsOf[s] ?? 0), s.count)
                                  .toArString()
                              : '${dispUnitsOf[s]}',
                          style: cellStyle())),
                ],
              ),
            ),
          const Divider(height: 16),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Text('جمع سهام',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 11.5),
                        fontWeight: FontWeight.w700,
                        color: accent)),
              ),
              const Spacer(),
              Text('$displayAsl از $displayAsl',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 11.5),
                      fontWeight: FontWeight.w700,
                      color: accent)),
            ],
          ),
          if (result.mandatoryWillAmount > 0) ...[
            const SizedBox(height: 8),
            Text(
              'وصیت واجبه (مبلغ ${result.mandatoryWillAmount.toInt()}) پیش از توزیع کسر شد و جداگانه به نوه‌های یتیم می‌رسد؛ از اصل مسأله بالا بیرون است.',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11.5),
                  color: InheritancePalette.purpleMid,
                  height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBlockedHeirs(
      List<BlockedHeir> heirs, bool isDark, Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: TimeThemeKit.of(context).palette.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: TimeThemeKit.of(context).palette.textMuted.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.block, size: 18, color: TimeThemeKit.of(context).palette.textMuted),
              const SizedBox(width: 8),
              Text('محجوبان (محروم‌شدگان از ارث)',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 13),
                      fontWeight: FontWeight.w700,
                      color: TimeThemeKit.of(context).palette.textPrimary)),
            ],
          ),
          const SizedBox(height: 8),
          for (final h in heirs)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.close, size: 14, color: AppTheme.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${heirLabel(h.type)} (${h.count}) — ${h.reason}',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 11.5),
                          color: TimeThemeKit.of(context).palette.textMuted,
                          height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailedSolution(DetailedSolution s, bool isDark, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final step in s.steps) ...[
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
                Text(step.title,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 13.5),
                        fontWeight: FontWeight.w700,
                        color: accent)),
                const SizedBox(height: 8),
                ...step.lines.map((l) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $l',
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 12),
                              color: TimeThemeKit.of(context).palette.textSecondary,
                              height: 1.6)),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _heirResultCard(InheritanceShare s, bool isDark, Color accent) {
    final showCount = s.count > 1 &&
        (s.type == HeirType.wife ||
            s.type == HeirType.son ||
            s.type == HeirType.daughter ||
            s.type == HeirType.fullBrother ||
            s.type == HeirType.fullSister ||
            s.type == HeirType.paternalBrother ||
            s.type == HeirType.paternalSister ||
            s.type == HeirType.maternalBrother ||
            s.type == HeirType.maternalSister);

    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;

    Color shareTypeColor;
    String shareTypeText;
    switch (s.shareType) {
      case ShareType.fard:
        shareTypeColor = InheritancePalette.fard;
        shareTypeText = 'فرض';
      case ShareType.asaba:
        shareTypeColor = success;
        shareTypeText = 'تعصیب';
      case ShareType.radd:
        shareTypeColor = InheritancePalette.highlight;
        shareTypeText = 'رد';
      case ShareType.hajb:
        shareTypeColor = TimeThemeKit.of(context).palette.textMuted;
        shareTypeText = 'حجب';
      case ShareType.mandatoryWill:
        shareTypeColor = InheritancePalette.purpleMid;
        shareTypeText = 'وصیت واجبه';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(s.fraction.toArString(),
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 15),
                        fontWeight: FontWeight.w700,
                        color: accent)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  heirLabel(s.type) + (showCount ? ' (${s.count})' : ''),
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 14),
                      fontWeight: FontWeight.w700,
                      color: TimeThemeKit.of(context).palette.textPrimary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: shareTypeColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(shareTypeText,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 11),
                        fontWeight: FontWeight.w700,
                        color: shareTypeColor)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(NumberFormat.formatMoney(s.amount, unit),
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 18),
                  fontWeight: FontWeight.w700,
                  color: accent)),
          const SizedBox(height: 8),
          Divider(height: 1, color: TimeThemeKit.of(context).palette.outline),
          const SizedBox(height: 8),
          Text(s.reason,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 12.5),
                  color: TimeThemeKit.of(context).palette.textSecondary,
                  height: 1.6)),
        ],
      ),
    );
  }

  // ── Madhab / legal code selector ──
  Widget _buildMadhabSelector(bool isDark, Color accent) {
    final onPrimary = dsOnAccent(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader('انتخاب مذهب فقهی / قانون', isDark),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: Madhab.values.map((m) {
            final isSelected = _selectedMadhab == m;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedMadhab = m;
                  _blockedPreview = _computeBlockedPreview();
                });
                // Recompute immediately when a result is already on screen
                // (the site's one-click madhab/law switching).
                if (_result != null) {
                  _calculate();
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? accent
                      : TimeThemeKit.of(context).palette.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? accent
                        : TimeThemeKit.of(context).palette.outline,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      MadhabRules.isLegalCode(m)
                          ? Icons.account_balance
                          : Icons.mosque_outlined,
                      size: 16,
                      color: isSelected
                          ? onPrimary
                          : TimeThemeKit.of(context).palette.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      madhabLabel(m),
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 11),
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? onPrimary
                            : TimeThemeKit.of(context).palette.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Expenses toggle ──
  Widget _buildExpensesToggle(bool isDark, Color accent) {
    return GestureDetector(
      onTap: () => setState(() => _showExpenses = !_showExpenses),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: TimeThemeKit.of(context).palette.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.receipt_long,
                size: 18, color: TimeThemeKit.of(context).palette.textMuted),
            const SizedBox(width: 8),
            Text('کسر هزینه‌ها، دیون و وصیت',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    fontWeight: FontWeight.w600,
                    color: TimeThemeKit.of(context).palette.textSecondary)),
            const Spacer(),
            Icon(_showExpenses ? Icons.expand_less : Icons.expand_more,
                color: TimeThemeKit.of(context).palette.textMuted),
          ],
        ),
      ),
    );
  }

  // ── Widget builders ──
  Widget _buildIntroCard(bool isDark) {
    return TabIntroCard(
      icon: Icons.account_tree_outlined,
      accent: InheritancePalette.accentOn(isDark),
      title: 'محاسبه میراث',
      subtitle: 'سهم هر وارث با ذکر دلیل شرعی (بر پایه فقه اهل سنت)',
    );
  }

  Widget _buildGenderSelector(bool isDark, Color accent) {
    final onPrimary = dsOnAccent(context);
    return Container(
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
                if (_result != null) _calculate();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _isMale ? accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.man,
                        size: 18,
                        color: _isMale ? onPrimary : accent),
                    const SizedBox(width: 6),
                    Text('متوفی مرد',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          fontWeight: FontWeight.w700,
                          color:
                              _isMale ? onPrimary : accent,
                        )),
                  ],
                ),
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
                if (_result != null) _calculate();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_isMale ? accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.woman,
                        size: 18,
                        color:
                            !_isMale ? onPrimary : accent),
                    const SizedBox(width: 6),
                    Text('متوفی زن',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          fontWeight: FontWeight.w700,
                          color:
                              !_isMale ? onPrimary : accent,
                        )),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                  color: _accent, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 13),
                  fontWeight: FontWeight.w700,
                  color: _accent)),
        ],
      ),
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

  Widget _orphanStepper(String label, int count, ValueChanged<int> onChanged,
      bool isDark, Color accent) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: count > 0
                ? accent.withValues(alpha: 0.12)
                : TimeThemeKit.of(context).palette.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.child_care,
              size: 20,
              color: count > 0 ? accent : TimeThemeKit.of(context).palette.textMuted),
        ),
        title: Text(label,
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 14),
                fontWeight: FontWeight.w600,
                color: TimeThemeKit.of(context).palette.textPrimary)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
              tooltip: '$label — کاهش',
              onPressed: count > 0 ? () => onChanged(count - 1) : null,
            ),
            Container(
              width: 30,
              alignment: Alignment.center,
              child: Text('$count',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 16),
                      fontWeight: FontWeight.bold,
                      color: TimeThemeKit.of(context).palette.textPrimary)),
            ),
            IconButton(
              icon: Icon(Icons.add_circle_outline,
                  color: count > 0 ? accent : TimeThemeKit.of(context).palette.textMuted),
              tooltip: '$label — افزایش',
              onPressed: () => onChanged(count + 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heirTile(HeirOption option, bool isDark, Color accent) {
    final type = option.type;
    final label = option.label;
    final icon = option.icon;
    final count = (_counts[type] ?? 0);
    final maxCount = option.maxCount;
    final atMax = count >= maxCount;
    final blocked = _blockedPreview.contains(type);
    final selected = count > 0;
    // A relationship that can only exist once (پدر، شوهر، جدّه) shows a check
    // instead of a digit — «۲ پدر» is never a case the user can build.
    final showCount = maxCount > 1;
    final iconColor = blocked
        ? AppTheme.error
        : (selected ? accent : TimeThemeKit.of(context).palette.textMuted);
    final iconBg = blocked
        ? (selected
            ? AppTheme.error.withValues(alpha: 0.15)
            : TimeThemeKit.of(context).palette.surfaceAlt)
        : (selected
            ? accent.withValues(alpha: 0.12)
            : TimeThemeKit.of(context).palette.surfaceAlt);
    return Card(
      margin: EdgeInsets.only(bottom: 8, right: option.indent * 14.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon,
              size: 20,
              color: selected
                  ? iconColor
                  : iconColor.withValues(alpha: blocked ? 0.45 : 1.0)),
        ),
        title: Text(label,
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 14),
                fontWeight: FontWeight.w600,
                color: blocked && !selected
                    ? TimeThemeKit.of(context).palette.textMuted
                    : TimeThemeKit.of(context).palette.textPrimary)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
              tooltip: '$label — کاهش',
              onPressed: count > 0 ? () => _setCount(type, count - 1) : null,
            ),
            Container(
              width: 30,
              alignment: Alignment.center,
              child: Text(showCount ? '$count' : (count > 0 ? '✓' : '0'),
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 16),
                      fontWeight: FontWeight.bold,
                      color: TimeThemeKit.of(context).palette.textPrimary)),
            ),
            IconButton(
              icon: Icon(Icons.add_circle_outline,
                  color: !atMax
                      ? (count > 0 ? accent : TimeThemeKit.of(context).palette.textMuted)
                      : TimeThemeKit.of(context).palette.textMuted.withValues(alpha: 0.3)),
              tooltip: '$label — افزایش',
              onPressed: !atMax ? () => _setCount(type, count + 1) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _br(String l, String v, Color accent,
      {bool bold = false, Color? valColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 12.5),
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                  color: TimeThemeKit.of(context).palette.textSecondary)),
          Text(v,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 12.5),
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                  color: valColor ?? accent)),
        ],
      ),
    );
  }

  Widget _buildDisclaimer(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TimeThemeKit.of(context).palette.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline,
              size: 16, color: TimeThemeKit.of(context).palette.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(InheritanceContent.disclaimer,
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

  /// The entry to the مناسخات sheet: one flat kit row, one tap to the form.
  Widget _buildMunasakhatEntry(Color accent) {
    final t = TimeThemeKit.of(context).palette;
    return AppCard(
      radius: 16,
      padding: const EdgeInsets.all(12),
      borderColor: accent.withValues(alpha: .18),
      onTap: () => _openMunasakhatSheet(context, accent),
      child: Row(
        children: [
          IconTile(
              icon: Icons.account_tree_outlined, color: accent, iconSize: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('محاسبه مناسخات',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w600,
                        color: t.textPrimary)),
                const SizedBox(height: 2),
                Text(
                    'وقتی وارثی پیش از دریافت سهم خود فوت کند؛ سهمش به ورثهٔ او می‌رسد.',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        color: t.textMuted,
                        height: 1.5)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_left_rounded, size: 20, color: t.textMuted),
        ],
      ),
    );
  }

  void _openMunasakhatSheet(BuildContext context, Color accent) {
    final startMadhab = _selectedMadhab;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                    child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: TimeThemeKit.of(context).palette.textMuted,
                            borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text('محاسبه مناسخات',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 18),
                        fontWeight: FontWeight.bold,
                        color: accent)),
                const SizedBox(height: 6),
                Text(
                    'در هر مرحله متوفی را یکی از ورثهٔ مرحلهٔ پیش قرار دهید؛ سهم او جدا شده و به ورثهٔ خودش می‌رسد.',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 11),
                        color: TimeThemeKit.of(context).palette.textMuted,
                        height: 1.5)),
                const SizedBox(height: 16),
                // مناسخات — شیت محتوای مناسخات
                MunasakhatSheetContent(
                  accent: accent,
                  initialMadhab: startMadhab,
                  onClose: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static int _fractionGcd(int a, int b) {
    while (b != 0) {
      final t = b;
      b = a % b;
      a = t;
    }
    return a == 0 ? 1 : a;
  }

  static int _fractionLcm(int a, int b) {
    if (a == 0) return b;
    if (b == 0) return a;
    return a ~/ _fractionGcd(a, b) * b;
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/core/theme/tool_identity.dart';
import 'package:tawheeed/features/personal/finance/finance_models.dart';
import 'package:tawheeed/features/personal/finance/finance_providers.dart';
import 'package:tawheeed/features/personal/presentation/widgets/care_sheet_kit.dart';
import 'package:tawheeed/features/personal/presentation/widgets/care_widgets.dart'
    show CareChip;
import 'package:tawheeed/features/worship/kaffara/kaffara_choice_store.dart';
import 'package:tawheeed/features/worship/kaffara/kaffara_models.dart';
import 'package:tawheeed/features/worship/kaffara/kaffara_providers.dart';
import 'package:tawheeed/shared/models/app_currency.dart';
import 'package:tawheeed/shared/services/currency_store.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// Accent for the whole kaffara surface — kept from `ToolIdentity.kaffara` so
/// the tile, the header and every element inside the page share ONE hue.
const Color kaffaraAccent = ToolIdentity.kaffara;

/// The four Sunni madhhabs, in display order.
const List<(String, String)> _madhhabs = [
  ('hanafi', 'حنفی'),
  ('maliki', 'مالکی'),
  ('shafi', 'شافعی'),
  ('hanbali', 'حنبلی'),
];

/// «کفاره و فدیه» — a calculator over reviewed, four-madhhab rule data only.
///
/// The page explains a category once (summary, steps/options, conditions) and
/// then shows ONLY the school's own difference, so the same three paragraphs
/// are no longer repeated under every chip. It never states a ruling of its
/// own: every quantity comes from `assets/data/kaffara_rules.json`, and the
/// only figures produced are the rule's quantities multiplied by what the user
/// types in — in the currency chosen in Settings.
class KaffaraScreen extends ConsumerStatefulWidget {
  const KaffaraScreen({super.key});

  @override
  ConsumerState<KaffaraScreen> createState() => _KaffaraScreenState();
}

class _KaffaraScreenState extends ConsumerState<KaffaraScreen> {
  final Map<String, double> _values = {};
  Obligation? _added;

  /// A choice made in this screen; falls back to the app's Asr-madhhab
  /// setting when the screen opens.
  String? _madhhabOverride;

  /// Price the food by the served meal instead of by the kilogram. The reader
  /// usually knows what one plate costs, not what a kilo of it costs.
  bool _pricePerMeal = false;

  @override
  void initState() {
    super.initState();
    // Settings may never have been opened in this process; without this the
    // page prints the default unit while the user has chosen another.
    unawaited(CurrencyStore.calculators.load());
    unawaited(_restoreMadhhab());
  }

  /// Opens on the school the reader picked last time, instead of sending them
  /// back to the Asr-madhhab default on every visit. The stored value only
  /// fills the gap: a tap made while it is loading still wins.
  Future<void> _restoreMadhhab() async {
    final saved = await KaffaraChoiceStore.loadMadhhab();
    if (!mounted || saved == null || _madhhabOverride != null) return;
    if (!_madhhabs.any((option) => option.$1 == saved)) return;
    setState(() => _madhhabOverride = saved);
  }

  @override
  Widget build(BuildContext context) {
    final category = ref.watch(kaffaraCategoryProvider);
    final madhhab =
        _madhhabOverride ?? ref.watch(kaffaraMadhhabProvider) ?? 'shafi';
    final debug = ref.watch(kaffaraDebugProvider).value ?? false;
    final rulesAsync = ref.watch(kaffaraRulesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        accent: kaffaraAccent,
        title: 'کفاره و فدیه',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'بازگشت',
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: rulesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => FailureView(
            id: 'kaffara_rules',
            title: 'خواندن داده‌های حکم ممکن نشد',
            detail: 'قوانین کفاره عوض نشده‌اند؛ فقط خواندنشان ناموفق بود.',
            onRetry: () => ref.invalidate(kaffaraRulesProvider),
            error: error,
            layout: FailureLayout.page,
          ),
          data: (rules) => ValueListenableBuilder<AppCurrency>(
            valueListenable: CurrencyStore.calculators.notifier,
            builder: (context, currency, _) =>
                _body(rules, category, madhhab, debug, currency.unit),
          ),
        ),
      ),
    );
  }

  Widget _body(
    List<KaffaraRule> rules,
    KaffaraCategory category,
    String madhhab,
    bool debug,
    String unit,
  ) {
    final matching = [
      for (final rule in rules)
        if (rule.category == category &&
            rule.variants.containsKey(madhhab) &&
            rule.isSelectable(debug: debug))
          rule,
    ];
    final rule = matching.isEmpty ? null : matching.first;
    final variant = rule?.variants[madhhab];

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
      children: [
        // The page is read in four moves — موضوع، حکم، مذهب، نتیجه — so each
        // one is announced instead of the whole thing being one column of
        // cards the reader has to sort out themselves.
        const SectionHeader(
          title: 'موضوع',
          accent: kaffaraAccent,
          description:
              'کفاره و فدیه بر پایهٔ مذاهب چهارگانهٔ اهل سنت؛ هر عدد از '
              'دادهٔ تأییدشده می‌آید و در برنامه ساخته نمی‌شود.',
        ),
        _CategoryChips(category: category),
        if (debug)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: CareNotice(
              icon: Icons.construction_outlined,
              text: 'نسخهٔ آزمایشی (debug): پیش‌نویس‌های تأییدنشده هم دیده '
                  'می‌شوند. در نسخهٔ نهایی فقط دادهٔ تأییدشده انتخاب‌شدنی است.',
              accent: kaffaraAccent,
            ),
          ),
        const SizedBox(height: 10),
        if (rule == null || variant == null)
          _missingRule()
        else
          _ruleBody(rule, variant, unit),
      ],
    );
  }

  Widget _missingRule() {
    final t = TimeThemeKit.of(context).palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const DuotoneIconTile(
            accent: kaffaraAccent,
            icon: Icons.menu_book_outlined,
            size: 64,
          ),
          const SizedBox(height: 14),
          Text(
            'این حکم هنوز در برنامه موجود نیست',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 15),
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'دادهٔ این دسته (یا این مذهب) تأیید نشده است، بنابراین برنامه هیچ '
            'مقدار و شرایطی از خود نمی‌سازد. در صورت نیاز به عالم مراجعه کنید.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 11.5),
              height: 1.55,
              color: t.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ruleBody(KaffaraRule rule, KaffaraVariant variant, String unit) {
    final t = TimeThemeKit.of(context).palette;
    final values = <String, double>{
      for (final input in variant.inputs)
        input.key: _values[input.key] ?? input.defaultValue,
    };
    final result = computeKaffara(
      variant: variant,
      values: values,
      pricePerMeal: _pricePerMeal,
    );
    final valid = kaffaraInputsValid(variant: variant, values: values);
    final canPricePerMeal =
        !_pricePerMeal || variant.components.any((c) => c.mealGrams > 0);
    final mealBasisAvailable = variant.components.any((c) => c.mealGrams > 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!rule.reviewed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: CareNotice(
              icon: Icons.fact_check_outlined,
              text: 'این داده هنوز تأیید نهایی نشده است'
                  '${rule.draftNote.isEmpty ? '' : '؛ ${rule.draftNote}'}',
              accent: kaffaraAccent,
            ),
          ),
        // ── What it is (once, for every school) ──
        const SectionHeader(
          title: 'حکم و شرایط',
          accent: kaffaraAccent,
          margin: EdgeInsets.only(bottom: 8),
        ),
        _SummaryCard(rule: rule),
        const SizedBox(height: 12),

        // ── Which school ──
        const SectionHeader(
          title: 'مذهب',
          accent: kaffaraAccent,
          description: 'پیش‌فرض از تنظیمات اوقات عصر خوانده می‌شود؛ اینجا '
              'آزادانه عوضش کنید.',
          margin: EdgeInsets.only(bottom: 8),
        ),
        _MadhhabSelector(
          selected:
              _madhhabOverride ?? ref.watch(kaffaraMadhhabProvider) ?? 'shafi',
          onTap: (m) {
            setState(() => _madhhabOverride = m);
            unawaited(KaffaraChoiceStore.saveMadhhab(m));
            _reset();
          },
        ),
        const SizedBox(height: 10),

        // ── This school's own difference, and nothing repeated ──
        if (variant.description.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: kaffaraAccent.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: kaffaraAccent.withValues(alpha: .28),
                width: .6,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.balance_outlined,
                    size: 16, color: kaffaraAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    variant.description,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 11.5),
                      height: 1.65,
                      color: t.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // ── The numbers ──
        AppCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.calculate_outlined,
                      size: 16, color: kaffaraAccent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'حساب',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 12.5),
                        fontWeight: FontWeight.w700,
                        color: kaffaraAccent,
                      ),
                    ),
                  ),
                  Text(
                    'واحد: $unit',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 10.5),
                      color: t.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final input in variant.inputs)
                _InputField(
                  input: input,
                  value: _values[input.key],
                  unit: unit,
                  pricePerMeal: _pricePerMeal && canPricePerMeal,
                  onChanged: (value) =>
                      setState(() => _values[input.key] = value),
                ),
              if (mealBasisAvailable) ...[
                const SizedBox(height: 4),
                Text(
                  'قیمت غذا را چطور می‌دانید؟',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 10.5),
                    color: t.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    CareChip(
                      label: 'قیمت هر کیلو',
                      selected: !_pricePerMeal,
                      accent: kaffaraAccent,
                      onTap: () => setState(() => _pricePerMeal = false),
                    ),
                    CareChip(
                      label: 'قیمت هر وعده',
                      selected: _pricePerMeal,
                      accent: kaffaraAccent,
                      onTap: () => setState(() => _pricePerMeal = true),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Text(
                'واحد پول از «تنظیمات ← واحد پول» خوانده می‌شود.',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 9.5),
                  color: t.textMuted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // ── The answer ──
        _ResultCard(
          total: valid ? result.total : null,
          unit: unit,
          lines: result.lines,
          meals: result.meals,
          fastingDays: result.fastingDays,
          noMoney: result.hasNoMoney,
          hint:
              valid ? null : 'برای دیدن مبلغ، همهٔ مقدارهای لازم را وارد کنید.',
        ),

        if (rule.sources.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'منبع: ${rule.sources.join(' · ')}',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 10),
              color: t.textMuted,
              height: 1.5,
            ),
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: valid ? () => _copy(rule, result, unit) : null,
                icon: const Icon(Icons.copy_all_outlined, size: 17),
                label: const Text('کپی'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: result.total == null || _added != null
                    ? null
                    : () => _addToLedger(rule, result, unit),
                style: FilledButton.styleFrom(
                  // The same hue as the rest of the page: this button used to
                  // be savings-green inside an amber section.
                  backgroundColor: kaffaraAccent,
                  foregroundColor: dsOnAccent(context),
                ),
                icon:
                    const Icon(Icons.account_balance_wallet_outlined, size: 17),
                label: Text(
                  _added == null ? 'افزودن به دفتر مالی' : 'افزوده شد',
                ),
              ),
            ),
          ],
        ),
        if (_added != null) ...[
          const SizedBox(height: 8),
          CareSheetSubmit(
            label: 'ثبت پرداخت',
            accent: kaffaraAccent,
            onPressed: _markPaid,
          ),
        ],
      ],
    );
  }

  void _reset() => setState(() {
        _values.clear();
        _added = null;
      });

  String _summary(KaffaraRule rule, KaffaraResult result, String unit) {
    final lines = [
      for (final line in result.lines)
        if (line.money != null)
          '${line.labelFa}: ${NumberFormat.formatMoney(line.money!, unit)}'
        else if (line.meals > 0)
          '${line.labelFa}: ${NumberFormat.grouped(line.meals)} وعده'
        else
          '${line.labelFa}: ${NumberFormat.grouped(line.quantity)} ${line.unit}'
              .trim(),
    ];
    return [
      rule.titleFa,
      ...lines,
      if (result.total != null)
        'جمع برآوردی: ${NumberFormat.formatMoney(result.total!, unit)}',
    ].join('\n');
  }

  Future<void> _copy(
      KaffaraRule rule, KaffaraResult result, String unit) async {
    await Clipboard.setData(ClipboardData(text: _summary(rule, result, unit)));
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('متن برآورد کپی شد')),
    );
  }

  Future<void> _addToLedger(
    KaffaraRule rule,
    KaffaraResult result,
    String unit,
  ) async {
    final total = result.total;
    if (total == null) return;
    final obligation =
        await ref.read(financeStoreProvider.notifier).addObligation(
              kind: ObligationKind.other,
              direction: ObligationDirection.pay,
              title: rule.titleFa,
              amount: total,
              dueDate: DateTime.now(),
              note: _summary(rule, result, unit),
            );
    if (!mounted) return;
    setState(() {
      _added = obligation;
    });
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
          content: Text('در دفتر مالی ثبت شد؛ پرداختش را همان‌جا ثبت کنید.')),
    );
  }

  Future<void> _markPaid() async {
    final added = _added;
    if (added == null) return;
    await ref.read(financeStoreProvider.notifier).updateObligation(
          added.copyWith(
            status: ObligationStatus.paid,
            paidDate: DateTime.now(),
            paidAmount: added.amount,
          ),
        );
    if (!mounted) return;
    setState(() => _added = null);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('پرداخت در دفتر مالی ثبت شد')),
    );
  }
}

/// The explanation block: what the expiation is, the steps (or the choices),
/// and the conditions. Read once per category instead of under every school.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.rule});

  final KaffaraRule rule;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const DuotoneIconTile(
                accent: kaffaraAccent,
                icon: Icons.menu_book_outlined,
                size: 30,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  rule.titleFa,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 14),
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (rule.summaryFa.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              rule.summaryFa,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 11.5),
                height: 1.75,
                color: t.textSecondary,
              ),
            ),
          ],
          if (rule.steps.isNotEmpty) ...[
            const SizedBox(height: 12),
            _MiniHeading(
              icon: rule.stepsAreOptions
                  ? Icons.alt_route_outlined
                  : Icons.format_list_numbered_outlined,
              text: rule.stepsAreOptions ? 'گزینه‌ها' : 'ترتیب انجام',
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < rule.steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: kaffaraAccent.withValues(alpha: .12),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        rule.stepsAreOptions ? '•' : NumberFormat.en(i + 1),
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 9.5),
                          fontWeight: FontWeight.w700,
                          color: kaffaraAccent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        rule.steps[i],
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 11),
                          height: 1.6,
                          color: t.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (rule.conditions.isNotEmpty) ...[
            const SizedBox(height: 10),
            const _MiniHeading(
              icon: Icons.rule_outlined,
              text: 'شرایط و نکته‌ها',
            ),
            const SizedBox(height: 6),
            for (final condition in rule.conditions)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 5, left: 2),
                      child: Icon(Icons.circle, size: 4, color: kaffaraAccent),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        condition,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 11),
                          height: 1.6,
                          color: t.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _MiniHeading extends StatelessWidget {
  const _MiniHeading({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: kaffaraAccent),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 11),
            fontWeight: FontWeight.w700,
            color: kaffaraAccent,
          ),
        ),
      ],
    );
  }
}

/// The seven kaffara topics, as a wrapped chip grid.
class _CategoryChips extends ConsumerWidget {
  const _CategoryChips({required this.category});

  final KaffaraCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A Wrap, not a horizontal scroll: with six topics the last chip used to
    // sit off-screen with nothing hinting that more existed.
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final chip in KaffaraCategory.chips)
          CareChip(
            label: chip.labelFa,
            selected: chip == category,
            accent: kaffaraAccent,
            onTap: () {
              ref.read(kaffaraCategoryProvider.notifier).state = chip;
            },
          ),
      ],
    );
  }
}

/// Four-madhhab selector with a soft «مذهب» label.
class _MadhhabSelector extends StatelessWidget {
  const _MadhhabSelector({required this.selected, required this.onTap});

  final String selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    // The «مذهب» label lives in the section header above, so the selector is
    // only the chips — one heading per step, not two.
    //
    // Wrap, not a Row of Expanded chips: four chips cannot fit a 320dp phone
    // at 1.3 text scale (the labels alone outrun each cell), and a chip that
    // wraps to a second line never overflows.
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final option in _madhhabs)
          CareChip(
            label: option.$2,
            selected: selected == option.$1,
            accent: kaffaraAccent,
            onTap: () => onTap(option.$1),
          ),
      ],
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.input,
    required this.value,
    required this.unit,
    required this.pricePerMeal,
    required this.onChanged,
  });

  final KaffaraInput input;
  final double? value;
  final String unit;
  final bool pricePerMeal;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    if (input.type == KaffaraInputType.price) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextFormField(
          initialValue: value == null || value == 0
              ? ''
              : NumberFormat.formatPlain(value!),
          keyboardType: TextInputType.number,
          onChanged: (text) => onChanged(NumberFormat.parse(text)),
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 13),
            color: t.textPrimary,
          ),
          decoration: InputDecoration(
            // The unit comes from Settings, never from the rule file: the
            // field used to say «تومان» for a reader whose unit is a dollar.
            labelText: pricePerMeal ? 'قیمت هر وعدهٔ آماده' : input.labelFa,
            hintText:
                input.placeholder.isEmpty ? 'وارد کنید' : input.placeholder,
            suffixText: unit.isEmpty ? null : unit,
            isDense: true,
            filled: true,
            fillColor: t.surfaceAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: t.outline, width: .5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: t.outline, width: .5),
            ),
          ),
        ),
      );
    }
    final current = value ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              input.labelFa,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12),
                color: t.textSecondary,
              ),
            ),
          ),
          IconButton(
            tooltip: 'یکی کمتر',
            visualDensity: VisualDensity.compact,
            onPressed:
                current > input.min ? () => onChanged(current - 1) : null,
            icon: const Icon(Icons.remove_circle_outline, size: 20),
          ),
          Text(
            NumberFormat.grouped(current),
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 12),
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
            ),
          ),
          IconButton(
            tooltip: 'یکی بیشتر',
            visualDensity: VisualDensity.compact,
            onPressed:
                current < input.max ? () => onChanged(current + 1) : null,
            icon: const Icon(Icons.add_circle_outline, size: 20),
          ),
          if (input.unit.isNotEmpty)
            Text(
              input.unit,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 10),
                color: t.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.total,
    required this.unit,
    required this.lines,
    required this.meals,
    required this.fastingDays,
    required this.noMoney,
    this.hint,
  });

  final double? total;
  final String unit;
  final List<KaffaraLine> lines;
  final double meals;
  final double fastingDays;
  final bool noMoney;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    // The answer is the one solid band on the page — the same flat accent
    // surface every rebuilt tool page ends on. A tinted panel with a border
    // read as a warning banner rather than as the result of the calculation.
    final ink = dsOnAccent(context);
    final soft = ink.withValues(alpha: .85);
    final faint = ink.withValues(alpha: .7);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dsContentColor(context, kaffaraAccent),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            noMoney ? 'این مذهب مبلغی تعیین نمی‌کند' : 'مبلغ برآوردی',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 11),
              fontWeight: FontWeight.w700,
              color: ink.withValues(alpha: .9),
            ),
          ),
          const SizedBox(height: 6),
          if (noMoney)
            Text(
              'پاسخ این مذهب قضاست، نه پرداخت؛ خط‌های زیر همان تکلیف را '
              'نشان می‌دهند.',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 11),
                height: 1.6,
                color: soft,
              ),
            )
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                total == null ? '—' : NumberFormat.formatMoney(total!, unit),
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 23),
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
            ),
          if (hint != null) ...[
            const SizedBox(height: 6),
            Text(
              hint!,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 10.5),
                color: soft,
              ),
            ),
          ],
          if (meals > 0 || fastingDays > 0) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (meals > 0)
                  _FactChip(
                    icon: Icons.restaurant_outlined,
                    text: 'خوراک ${NumberFormat.grouped(meals)} وعده',
                  ),
                if (fastingDays > 0)
                  _FactChip(
                    icon: Icons.nights_stay_outlined,
                    text: 'روزه ${NumberFormat.grouped(fastingDays)} روز',
                  ),
              ],
            ),
          ],
          if (lines.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '${line.labelFa} · '
                                '${NumberFormat.grouped(line.quantity)} ${line.unit}'
                            .trim(),
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 10.5),
                          color: soft,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      line.money == null
                          ? (line.fastingDays > 0 ? 'قضا' : '—')
                          : NumberFormat.formatMoney(line.money!, unit),
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 10.5),
                        fontWeight: FontWeight.w700,
                        color: line.money == null ? faint : ink,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _FactChip extends StatelessWidget {
  const _FactChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    // Drawn ON the solid answer band, so the chip is the band's ink at 16 %,
    // not the section hue over it.
    final ink = dsOnAccent(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: ink),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 10),
              fontWeight: FontWeight.w600,
              color: ink,
            ),
          ),
        ],
      ),
    );
  }
}

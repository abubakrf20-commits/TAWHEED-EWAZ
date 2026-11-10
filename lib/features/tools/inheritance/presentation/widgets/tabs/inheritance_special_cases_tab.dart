import 'package:tawheeed/shared/widgets/currency_aware_state.dart';
import 'package:flutter/material.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/shared/widgets/number_input_formatters.dart';

import 'package:tawheeed/features/tools/inheritance/domain/inheritance_calculator.dart';
import 'package:tawheeed/features/tools/inheritance/domain/madhab_rules.dart';
import 'package:tawheeed/features/tools/inheritance/domain/special_cases.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/inheritance_palette.dart';

enum _SpecialMode { unbornChild, missingPerson, intersex, bondman }

class InheritanceSpecialCasesTab extends StatefulWidget {
  const InheritanceSpecialCasesTab({super.key});

  @override
  State<InheritanceSpecialCasesTab> createState() =>
      _InheritanceSpecialCasesTabState();
}

class _InheritanceSpecialCasesTabState
    extends State<InheritanceSpecialCasesTab>
    with CurrencyAwareState<InheritanceSpecialCasesTab> {
  static const Color _accent = InheritancePalette.accent;

  final _estateCtrl = TextEditingController(text: '1,000,000,000');
  final Map<HeirType, int> _counts = {
    for (final t in HeirType.values) t: 0,
  };
  Madhab _madhab = Madhab.jumhur;
  _SpecialMode _mode = _SpecialMode.unbornChild;
  HeirType _missingType = HeirType.son;
  PregnancyRelation _pregnancyRelation = PregnancyRelation.wife;
  IntersexMode _intersexMode = IntersexMode.disclosed;
  HeirType _intersexType = HeirType.son;
  HeirType _bondmanType = HeirType.son;
  double _freeFraction = 0.5;
  SpecialCaseResult? _result;
  BondmanCase? _bondmanResult;

  static const List<(HeirType, String)> _heirs = [
    (HeirType.husband, 'شوهر'),
    (HeirType.wife, 'همسر'),
    (HeirType.son, 'پسر'),
    (HeirType.daughter, 'دختر'),
    (HeirType.father, 'پدر'),
    (HeirType.mother, 'مادر'),
    (HeirType.grandfather, 'پدربزرگ'),
    (HeirType.paternalGrandmother, 'مادربزرگ (مادرِ پدر)'),
    (HeirType.fullBrother, 'برادر اشقی'),
    (HeirType.fullSister, 'خواهر اشقی'),
    (HeirType.paternalBrother, 'برادر پدری'),
    (HeirType.paternalSister, 'خواهر پدری'),
    (HeirType.maternalBrother, 'برادر مادری'),
    (HeirType.maternalSister, 'خواهر مادری'),
    (HeirType.grandson, 'پسرِ پسر'),
    (HeirType.granddaughter, 'دخترِ پسر'),
  ];

  static const List<(HeirType, String)> _missingOptions = [
    (HeirType.son, 'پسر'),
    (HeirType.daughter, 'دختر'),
    (HeirType.father, 'پدر'),
    (HeirType.mother, 'مادر'),
    (HeirType.fullBrother, 'برادر اشقی'),
    (HeirType.fullSister, 'خواهر اشقی'),
    (HeirType.husband, 'شوهر'),
    (HeirType.wife, 'همسر'),
  ];

  static const List<(HeirType, String)> _intersexOptions = [
    (HeirType.son, 'پسر'),
    (HeirType.grandson, 'پسرِ پسر'),
    (HeirType.greatGrandson, 'پسرِ پسرِ پسر'),
    (HeirType.fullBrother, 'برادر اشقی'),
    (HeirType.paternalBrother, 'برادر پدری'),
    (HeirType.maternalBrother, 'برادر مادری'),
    (HeirType.nephewFull, 'پسرِ برادرِ اشقی'),
    (HeirType.nephewPaternal, 'پسرِ برادرِ پدری'),
    (HeirType.paternalUncle, 'عمو'),
    (HeirType.paternalUncleSon, 'پسرعمو'),
  ];

  static const List<(PregnancyRelation, String)> _pregnancyOptions = [
    (PregnancyRelation.wife, 'همسر متوفی'),
    (PregnancyRelation.sonWife, 'همسر پسر متوفی'),
    (PregnancyRelation.grandsonWife, 'همسر پسرِ پسرِ متوفی'),
    (PregnancyRelation.mother, 'مادر متوفی'),
    (PregnancyRelation.motherFromAnotherHusband, 'مادر متوفی از همسر دیگر'),
    (PregnancyRelation.fathersWife, 'همسر پدر متوفی'),
    (PregnancyRelation.fullBrotherWife, 'همسر برادر اشقی متوفی'),
    (PregnancyRelation.paternalBrotherWife, 'همسر برادر پدری متوفی'),
    (PregnancyRelation.grandfatherWife, 'همسر پدربزرگ متوفی'),
  ];

  @override
  void dispose() {
    _estateCtrl.dispose();
    super.dispose();
  }

  bool get _bondmanAllowed => MadhabRules.baseMadhab(_madhab) == Madhab.hanbali;

  InheritanceInput _buildInput() {
    int c(HeirType t) => (_counts[t] ?? 0);
    return InheritanceInput(
      estate: NumberFormat.parse(_estateCtrl.text),
      madhab: _madhab,
      husband: c(HeirType.husband),
      wife: c(HeirType.wife),
      son: c(HeirType.son),
      daughter: c(HeirType.daughter),
      father: c(HeirType.father),
      mother: c(HeirType.mother),
      grandfather: c(HeirType.grandfather),
      paternalGrandmother: c(HeirType.paternalGrandmother),
      fullBrother: c(HeirType.fullBrother),
      fullSister: c(HeirType.fullSister),
      paternalBrother: c(HeirType.paternalBrother),
      paternalSister: c(HeirType.paternalSister),
      maternalBrother: c(HeirType.maternalBrother),
      maternalSister: c(HeirType.maternalSister),
      grandson: c(HeirType.grandson),
      granddaughter: c(HeirType.granddaughter),
    );
  }

  void _compute() {
    final estate = NumberFormat.parse(_estateCtrl.text);
    if (estate <= 0) {
      _showMessage('لطفاً مبلغ کل ترکه را به درستی وارد کنید.');
      return;
    }
    final input = _buildInput();
    try {
      switch (_mode) {
        case _SpecialMode.unbornChild:
          setState(() {
            _result = calculatePregnancyCase(input, _pregnancyRelation);
            _bondmanResult = null;
          });
        case _SpecialMode.missingPerson:
          setState(() {
            _result = calculateSpecialCase(input, SpecialCaseKind.missingPerson,
                pendingType: _missingType);
            _bondmanResult = null;
          });
        case _SpecialMode.intersex:
          setState(() {
            _result =
                calculateIntersexCase(input, _intersexType, _intersexMode);
            _bondmanResult = null;
          });
        case _SpecialMode.bondman:
          if (!_bondmanAllowed) {
            _showMessage(
                'میراث «العبد المبعض» (بندهٔ مشاع) فقط در مذهب حنبلی جاری است؛ مذهب را تغییر دهید.');
            return;
          }
          if ((_counts[_bondmanType] ?? 0) <= 0) {
            _showMessage(
                'ابتدا وارثِ بنده (رقیق) را با علامت + در فهرست وارثان اضافه کنید.');
            return;
          }
          setState(() {
            _result = null;
            _bondmanResult = calculateBondmanCase(input, _bondmanType,
                freeFraction: _freeFraction);
          });
      }
    } catch (e) {
      AppLogger.warning('inheritance_special_cases_tab', 'error: $e');
      _showMessage('محاسبه انجام نشد؛ مقدارهای واردشده را بررسی کنید.');
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg, style: TextStyle(fontFamily: AppTheme.fontFamily))));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? InheritancePalette.accentDark : _accent;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          DsSpacing.page, 12, DsSpacing.page, 40),
      children: [
        _header(isDark, accent),
        const SizedBox(height: 12),
        _madhabSelector(isDark, accent),
        const SizedBox(height: 12),
        _modeSelector(isDark, accent),
        if (_mode == _SpecialMode.unbornChild) ...[
          const SizedBox(height: 12),
          _pregnancySelector(isDark, accent),
        ],
        if (_mode == _SpecialMode.missingPerson) ...[
          const SizedBox(height: 12),
          _dropdownSelector(
              label: 'فرد مفقود کیست؟',
              icon: Icons.person_search_outlined,
              value: _missingType,
              options: _missingOptions,
              onChanged: (v) => setState(() => _missingType = v)),
        ],
        if (_mode == _SpecialMode.intersex) ...[
          const SizedBox(height: 12),
          _intersexModeToggle(isDark, accent),
          const SizedBox(height: 12),
          _dropdownSelector(
              label: 'نوع خنثی',
              icon: Icons.self_improvement_outlined,
              value: _intersexType,
              options: _intersexOptions,
              onChanged: (v) => setState(() => _intersexType = v)),
        ],
        if (_mode == _SpecialMode.bondman) ...[
          const SizedBox(height: 12),
          _bondmanTypeSelector(isDark, accent),
          const SizedBox(height: 12),
          _bondmanFractionSlider(isDark, accent),
          if (!_bondmanAllowed) ...[
            const SizedBox(height: 8),
            _noteBox(
                'میراث «العبد المبعض» (بندهٔ مشاع) فقط در مذهب حنبلی (و قوانین بر پایهٔ آن) جاری است.',
                isDark),
          ],
        ],
        const SizedBox(height: 12),
        _inputField(_estateCtrl, 'مبلغ کل ترکه ($unit)',
            Icons.account_balance_wallet, isDark),
        const SizedBox(height: 16),
        Text('وارثان حاضر',
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 14),
                fontWeight: FontWeight.w700,
                color: accent)),
        const SizedBox(height: 8),
        ..._heirs.map((h) => _heirTile(h.$1, h.$2, isDark, accent)),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _compute,
          icon: const Icon(Icons.calculate_outlined, size: 20),
          label: const Text('محاسبه حالت خاص'),
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
        if (_result != null) ...[
          const SizedBox(height: 20),
          _resultCard(_result!, isDark, accent),
        ],
        if (_bondmanResult != null) ...[
          const SizedBox(height: 20),
          _bondmanResultCard(_bondmanResult!, isDark, accent),
        ],
      ],
    );
  }

  Widget _noteBox(String text, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: InheritancePalette.highlight.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: InheritancePalette.highlight.withValues(alpha: 0.4)),
      ),
      child: Text(text,
          style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 12),
              fontWeight: FontWeight.w600,
              color: InheritancePalette.note,
              height: 1.5)),
    );
  }

  Widget _header(bool isDark, Color accent) {
    return TabIntroCard(
      icon: Icons.pregnant_woman,
      accent: accent,
      title: 'حالات خاص',
      subtitle: 'حمل، مفقود، خنثی و رقیق — با سناریوها و ذخیره احتیاطی',
    );
  }

  Widget _madhabSelector(bool isDark, Color accent) {
    final onPrimary = dsOnAccent(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('مذهب فقهی',
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 13),
                fontWeight: FontWeight.w700,
                color: accent)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: Madhab.values.map((m) {
            final sel = _madhab == m;
            return GestureDetector(
              onTap: () => setState(() => _madhab = m),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: sel
                      ? accent
                      : TimeThemeKit.of(context).palette.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: sel
                          ? accent
                          : TimeThemeKit.of(context).palette.outline,
                      width: sel ? 2 : 1),
                ),
                child: Text(
                  madhabLabel(m),
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
      ],
    );
  }

  Widget _modeSelector(bool isDark, Color accent) {
    final kinds = [
      (_SpecialMode.unbornChild, 'حمل (نوزاد در رحم)', Icons.pregnant_woman),
      (_SpecialMode.missingPerson, 'مفقود', Icons.person_search_outlined),
      (_SpecialMode.intersex, 'خنثی', Icons.self_improvement_outlined),
      (_SpecialMode.bondman, 'بندهٔ مبعض (رقیق)', Icons.handshake_outlined),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('نوع حالت خاص',
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 13),
                fontWeight: FontWeight.w700,
                color: accent)),
        const SizedBox(height: 8),
        ...kinds.map((k) {
          final sel = _mode == k.$1;
          return GestureDetector(
            onTap: () => setState(() {
              _mode = k.$1;
              if (k.$1 == _SpecialMode.bondman) _madhab = Madhab.hanbali;
            }),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: sel
                    ? accent.withValues(alpha: 0.1)
                    : TimeThemeKit.of(context).palette.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: sel ? accent : TimeThemeKit.of(context).palette.outline,
                    width: sel ? 2 : 1),
              ),
              child: Row(
                children: [
                  Icon(k.$3,
                      size: 20,
                      color: sel ? accent : TimeThemeKit.of(context).palette.textMuted),
                  const SizedBox(width: 10),
                  Text(k.$2,
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          fontWeight: FontWeight.w600,
                          color: TimeThemeKit.of(context).palette.textPrimary)),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _dropdownSelector({
    required String label,
    required IconData icon,
    required HeirType value,
    required List<(HeirType, String)> options,
    required ValueChanged<HeirType> onChanged,
  }) {
    return DropdownButtonFormField<HeirType>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: Icon(icon, size: 20),
      ),
      items: options
          .map((o) => DropdownMenuItem(value: o.$1, child: Text(o.$2)))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  Widget _pregnancySelector(bool isDark, Color accent) {
    return DropdownButtonFormField<PregnancyRelation>(
      initialValue: _pregnancyRelation,
      decoration: InputDecoration(
        labelText: 'چه کسی حامله است؟',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(Icons.pregnant_woman, size: 20),
      ),
      items: _pregnancyOptions
          .map((o) => DropdownMenuItem(value: o.$1, child: Text(o.$2)))
          .toList(),
      onChanged: (v) {
        if (v != null) setState(() => _pregnancyRelation = v);
      },
    );
  }

  Widget _intersexModeToggle(bool isDark, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('شیوهٔ برخورد با خنثی',
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 13),
                fontWeight: FontWeight.w700,
                color: accent)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _toggleChip(
                  _intersexMode == IntersexMode.disclosed,
                  'امید انکشاف (دو سناریو)',
                  Icons.compare_arrows,
                  accent,
                  isDark,
                  () => setState(() => _intersexMode = IntersexMode.disclosed)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _toggleChip(
                  _intersexMode == IntersexMode.undisclosed,
                  'بدون انکشاف (مالکی)',
                  Icons.check_circle_outline,
                  accent,
                  isDark,
                  () =>
                      setState(() => _intersexMode = IntersexMode.undisclosed)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _toggleChip(bool sel, String label, IconData icon, Color accent,
      bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: sel
              ? accent.withValues(alpha: 0.12)
              : TimeThemeKit.of(context).palette.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: sel ? accent : TimeThemeKit.of(context).palette.outline, width: sel ? 2 : 1),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 20, color: sel ? accent : TimeThemeKit.of(context).palette.textMuted),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    fontWeight: FontWeight.w600,
                    color: TimeThemeKit.of(context).palette.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _bondmanTypeSelector(bool isDark, Color accent) {
    final present = _heirs.where((h) => (_counts[h.$1] ?? 0) > 0).toList();
    if (present.isEmpty) {
      return _noteBox(
          'برای محاسبهٔ رقیق ابتدا وارثِ بنده را با + اضافه کنید.', isDark);
    }
    return DropdownButtonFormField<HeirType>(
      initialValue: present.any((p) => p.$1 == _bondmanType)
          ? _bondmanType
          : present.first.$1,
      decoration: InputDecoration(
        labelText: 'وارثِ بندهٔ مبعض',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(Icons.handshake_outlined, size: 20),
      ),
      items: present
          .map((o) => DropdownMenuItem(value: o.$1, child: Text(o.$2)))
          .toList(),
      onChanged: (v) {
        if (v != null) setState(() => _bondmanType = v);
      },
    );
  }

  Widget _bondmanFractionSlider(bool isDark, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('بخش آزاد بنده (رقیق)',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    fontWeight: FontWeight.w700,
                    color: accent)),
            Text('${(_freeFraction * 100).round()}٪',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 14),
                    fontWeight: FontWeight.w800,
                    color: accent)),
          ],
        ),
        Slider(
          value: _freeFraction,
          min: 0.1,
          divisions: 9,
          label: '${(_freeFraction * 100).round()}٪',
          onChanged: (v) => setState(() => _freeFraction = v),
        ),
        Text(
            'رقیق به اندازهٔ بخشِ آزادش ارث می‌برد و مابقی سهمش به مولایش می‌رسد.',
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 11),
                color: TimeThemeKit.of(context).palette.textMuted)),
      ],
    );
  }

  Widget _inputField(
      TextEditingController ctrl, String label, IconData icon, bool isDark) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      inputFormatters: const [LatinGroupingFormatter()],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: TimeThemeKit.of(context).palette.textMuted),
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

  Widget _heirTile(HeirType type, String label, bool isDark, Color accent) {
    final count = (_counts[type] ?? 0);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
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
              onPressed: count > 0
                  ? () => setState(() => _counts[type] = count - 1)
                  : null,
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
              onPressed: () => setState(() => _counts[type] = count + 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultCard(SpecialCaseResult r, bool isDark, Color accent) {
    final reserve = reservedForSpecialCase(r);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.explanation,
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 12.5),
                      color: TimeThemeKit.of(context).palette.textSecondary,
                      height: 1.6)),
              if (reserve > 0) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('مبلغ احتیاطی (نگهداری تا روشن‌شدن وضعیت)',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 12.5),
                            fontWeight: FontWeight.w700,
                            color: TimeThemeKit.of(context).palette.textPrimary)),
                    Text(NumberFormat.formatMoney(reserve, unit),
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 16),
                            fontWeight: FontWeight.w700,
                            color: InheritancePalette.highlight)),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final sc in r.scenarios) ...[
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
                Text(sc.label,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w700,
                        color: accent)),
                const SizedBox(height: 6),
                Text(
                    'سهم شخص موردبحث: ${NumberFormat.formatMoney(sc.pendingShare, unit)}',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 12.5),
                        fontWeight: FontWeight.w600,
                        color: TimeThemeKit.of(context).palette.textSecondary)),
                const SizedBox(height: 8),
                ...sc.result.shares.map((s) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              '${heirLabel(s.type)} (${s.fraction.toArString()})',
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize:
                                      AppTheme.scaledFontSize(context, 12),
                                  color: TimeThemeKit.of(context).palette.textPrimary)),
                          Text(NumberFormat.formatMoney(s.amount, unit),
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize:
                                      AppTheme.scaledFontSize(context, 12),
                                  fontWeight: FontWeight.w700,
                                  color: accent)),
                        ],
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _bondmanResultCard(BondmanCase r, bool isDark, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('میراث «العبد المبعض» (رقیق) — مذهب حنبلی',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 14),
                      fontWeight: FontWeight.w700,
                      color: accent)),
              const SizedBox(height: 6),
              Text(
                  'وارث: ${heirLabel(r.type)} (${r.count} نفر) — بخشِ آزاد: ${(r.freeFraction * 100).round()}٪',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 12.5),
                      color: TimeThemeKit.of(context).palette.textSecondary,
                      height: 1.6)),
              const SizedBox(height: 10),
              _bondmanRow(
                  'سهم کامل در تقسیم',
                  NumberFormat.formatMoney(_bondmanFullShare(r), unit),
                  isDark,
                  accent),
              _bondmanRow('مبلغ ارث‌برده (بخش آزاد)',
                  NumberFormat.formatMoney(r.inheritedAmount, unit), isDark, accent,
                  highlight: true),
              _bondmanRow('مبلغ نگهداری‌شده برای مولا',
                  NumberFormat.formatMoney(r.withheldAmount, unit), isDark, accent),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final s in r.result.shares)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${heirLabel(s.type)} (${s.fraction.toArString()})',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        color: TimeThemeKit.of(context).palette.textPrimary)),
                Text(NumberFormat.formatMoney(s.amount, unit),
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        fontWeight: FontWeight.w700,
                        color: accent)),
              ],
            ),
          ),
      ],
    );
  }

  double _bondmanFullShare(BondmanCase r) =>
      r.inheritedAmount + r.withheldAmount;

  Widget _bondmanRow(String label, String value, bool isDark, Color accent,
      {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12.5),
                    color: TimeThemeKit.of(context).palette.textPrimary)),
          ),
          Text(value,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 14),
                  fontWeight: FontWeight.w800,
                  color: highlight ? InheritancePalette.highlight : accent)),
        ],
      ),
    );
  }
}

import 'package:tawheeed/shared/widgets/currency_aware_state.dart';
import 'package:flutter/material.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/shared/widgets/number_input_formatters.dart';

import 'package:tawheeed/features/tools/inheritance/domain/inheritance_calculator.dart';
import 'package:tawheeed/features/tools/inheritance/domain/mandatory_will.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/inheritance_palette.dart';

class InheritanceMandatoryWillTab extends StatefulWidget {
  const InheritanceMandatoryWillTab({super.key});

  @override
  State<InheritanceMandatoryWillTab> createState() =>
      _InheritanceMandatoryWillTabState();
}

class _InheritanceMandatoryWillTabState
    extends State<InheritanceMandatoryWillTab>
    with CurrencyAwareState<InheritanceMandatoryWillTab> {
  static const Color _accent = InheritancePalette.accent;

  final _estateCtrl = TextEditingController(text: '1,000,000,000');
  final Map<HeirType, int> _counts = {
    for (final t in HeirType.values) t: 0,
  };
  final Madhab _madhab = Madhab.jumhur;
  MandatoryWillLaw _law = mandatoryWillLaws.first;
  DeceasedChildGender _deceasedChildGender = DeceasedChildGender.male;
  MandatoryWillResult? _result;

  static const List<(HeirType, String)> _heirs = [
    (HeirType.husband, 'شوهر'),
    (HeirType.wife, 'همسر'),
    (HeirType.son, 'پسر'),
    (HeirType.daughter, 'دختر'),
    (HeirType.father, 'پدر'),
    (HeirType.mother, 'مادر'),
    (HeirType.fullBrother, 'برادر اشقی'),
    (HeirType.fullSister, 'خواهر اشقی'),
    (HeirType.grandson, 'پسرِ پسر (فرزندِ پسرِ متوفایِ فوت‌شده)'),
    (HeirType.granddaughter, 'دخترِ پسر (فرزندِ پسرِ متوفایِ فوت‌شده)'),
  ];

  @override
  void dispose() {
    _estateCtrl.dispose();
    super.dispose();
  }

  void _compute() {
    final estate = NumberFormat.parse(_estateCtrl.text);
    if (estate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('لطفاً مبلغ کل ترکه را به درستی وارد کنید.',
              style: TextStyle(fontFamily: AppTheme.fontFamily))));
      return;
    }
    int c(HeirType t) => (_counts[t] ?? 0);
    final input = InheritanceInput(
      estate: estate,
      madhab: _madhab,
      husband: c(HeirType.husband),
      wife: c(HeirType.wife),
      son: c(HeirType.son),
      daughter: c(HeirType.daughter),
      father: c(HeirType.father),
      mother: c(HeirType.mother),
      fullBrother: c(HeirType.fullBrother),
      fullSister: c(HeirType.fullSister),
      grandson: c(HeirType.grandson),
      granddaughter: c(HeirType.granddaughter),
    );
    setState(() {
      _result = calculateMandatoryWill(input, _law,
          deceasedChildGender: _deceasedChildGender);
    });
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
        _lawSelector(isDark, accent),
        const SizedBox(height: 12),
        _genderSelector(isDark, accent),
        const SizedBox(height: 12),
        _inputField(_estateCtrl, 'مبلغ کل ترکه ($unit)',
            Icons.account_balance_wallet, isDark),
        const SizedBox(height: 16),
        Text('وارثان و نوه‌های یتیم',
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
          label: const Text('محاسبه وصیت واجبه'),
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
      ],
    );
  }

  Widget _header(bool isDark, Color accent) {
    return TabIntroCard(
      icon: Icons.volunteer_activism,
      accent: accent,
      title: 'وصیت واجبه',
      subtitle: 'وصیت اجباری به نوه‌های یتیم بر اساس قوانین 11 کشور',
    );
  }

  Widget _lawSelector(bool isDark, Color accent) {
    return DropdownButtonFormField<MandatoryWillLaw>(
      initialValue: _law,
      decoration: InputDecoration(
        labelText: 'کشور (قانون)',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(Icons.public, size: 20),
      ),
      items: mandatoryWillLaws
          .map((l) => DropdownMenuItem(
                value: l,
                child: Text(l.country),
              ))
          .toList(),
      onChanged: (v) => setState(() => _law = v ?? _law),
    );
  }

  Widget _genderSelector(bool isDark, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('فرزندِ فوت‌شده',
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 13),
                fontWeight: FontWeight.w700,
                color: accent)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _genderChip(
                  _deceasedChildGender == DeceasedChildGender.male,
                  'پسر (حکمِ پسر واقعی)',
                  Icons.male,
                  accent,
                  isDark, () {
                setState(() => _deceasedChildGender = DeceasedChildGender.male);
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _genderChip(
                  _deceasedChildGender == DeceasedChildGender.female,
                  'دختر (حکمِ دختر واقعی)',
                  Icons.female,
                  accent,
                  isDark, () {
                setState(
                    () => _deceasedChildGender = DeceasedChildGender.female);
              }),
            ),
          ],
        ),
      ],
    );
  }

  Widget _genderChip(bool sel, String label, IconData icon, Color accent,
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
              color: sel ? accent : TimeThemeKit.of(context).palette.outline,
              width: sel ? 2 : 1),
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

  Widget _resultCard(MandatoryWillResult r, bool isDark, Color accent) {
    if (!r.applies) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: InheritancePalette.highlight.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: InheritancePalette.highlight.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: InheritancePalette.note),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'در این ترکه نوه‌ی یتیم (فرزندِ پسرِ فوت‌شده) وجود ندارد؛ بنابراین وصیت واجبه جاری نیست.',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12.5),
                    color: TimeThemeKit.of(context).palette.textSecondary,
                    height: 1.6),
              ),
            ),
          ],
        ),
      );
    }
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
              Text('مرجع قانونی: ${r.law.codeName}',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 12),
                      color: TimeThemeKit.of(context).palette.textSecondary)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('مبلغ وصیت واجبه (حداکثر 1/3 ترکه)',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          fontWeight: FontWeight.w700,
                          color: TimeThemeKit.of(context).palette.textPrimary)),
                  Text(NumberFormat.formatMoney(r.mandatoryAmount, unit),
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 16),
                          fontWeight: FontWeight.w700,
                          color: InheritancePalette.highlight)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
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
              Text('سهم نوه‌های یتیم (مذکر دو برابر مؤنث)',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 13.5),
                      fontWeight: FontWeight.w700,
                      color: accent)),
              const SizedBox(height: 8),
              for (final o in r.orphans)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                          '${heirLabel(o.type)} (${o.count} نفر، ${o.fraction.toArString()} از وصیت)',
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 12),
                              color: TimeThemeKit.of(context).palette.textPrimary)),
                      Text(NumberFormat.formatMoney(o.amount, unit),
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 12.5),
                              fontWeight: FontWeight.w700,
                              color: accent)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
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
              Text('توزیع باقی‌مانده ترکه بین سایر وراث',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 13.5),
                      fontWeight: FontWeight.w700,
                      color: accent)),
              const SizedBox(height: 8),
              for (final s in r.remainingResult.shares)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
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
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/widgets/currency_aware_state.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/shared/widgets/number_input_formatters.dart';

import 'package:tawheeed/features/tools/inheritance/domain/inheritance_calculator.dart';
import 'package:tawheeed/features/tools/inheritance/domain/madhab_calculator.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/heir_catalog.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/inheritance_amount_input.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/widgets/gender_toggle.dart';

/// The heirs a مناسخات chain realistically needs, shown first; the rest of the
/// catalog sits behind «وراث دورتر».
const Set<HeirType> _nearHeirs = {
  HeirType.husband,
  HeirType.wife,
  HeirType.son,
  HeirType.daughter,
  HeirType.father,
  HeirType.mother,
  HeirType.grandfather,
  HeirType.paternalGrandmother,
  HeirType.maternalGrandmother,
  HeirType.grandson,
  HeirType.granddaughter,
  HeirType.fullBrother,
  HeirType.fullSister,
  HeirType.paternalBrother,
  HeirType.paternalSister,
  HeirType.maternalBrother,
  HeirType.maternalSister,
  HeirType.nephewFull,
  HeirType.nephewPaternal,
  HeirType.paternalUncleSon,
};

/// One stage of the chain as the user is building it.
class _StageDraft {
  final Map<HeirType, int> counts = {
    for (final t in HeirType.values) t: 0,
  };
  final TextEditingController name = TextEditingController();

  /// Gender of THIS deceased. For stage 1 the user says it; from stage 2 on it
  /// follows from the heir of the previous stage who died ([fromHeir]).
  bool isMale = true;

  /// Which heir of the previous stage this deceased was — null for stage 1 and
  /// for a stage whose linkage has not been chosen yet.
  HeirType? fromHeir;

  bool showDistant = false;

  int countOf(HeirType t) => counts[t] ?? 0;

  /// The heirs actually entered for this deceased, in catalog order.
  List<HeirType> get entered => [
        for (final o in kHeirOptions)
          if (countOf(o.type) > 0) o.type,
      ];

  void dispose() => name.dispose();
}

/// مناسخات (multi-stage inheritance) form.
///
/// Every stage after the first names its deceased by PICKING one of the
/// previous stage's heirs, and that pick is handed to the engine as a
/// [HeirType] — so no share is ever matched by guessing at a typed label, and
/// an unresolvable link stops the calculation instead of approximating it.
class MunasakhatSheetContent extends StatefulWidget {
  final Color accent;

  /// Opened on the madhab the calculator tab is already set to — the chain must
  /// not silently recompute the same heirs under a different law.
  final Madhab initialMadhab;
  final VoidCallback onClose;

  const MunasakhatSheetContent(
      {super.key,
      required this.accent,
      this.initialMadhab = Madhab.jumhur,
      required this.onClose});

  @override
  State<MunasakhatSheetContent> createState() => _MunasakhatSheetContentState();
}

class _MunasakhatSheetContentState extends State<MunasakhatSheetContent>
    with CurrencyAwareState<MunasakhatSheetContent> {
  final _estateCtrl = TextEditingController(text: '100,000,000');
  late Madhab _madhab = widget.initialMadhab;
  final List<_StageDraft> _stages = [_StageDraft()];

  MunasakhatCase? _result;
  String? _error;

  Color get _a => widget.accent;

  @override
  void dispose() {
    _estateCtrl.dispose();
    for (final s in _stages) {
      s.dispose();
    }
    super.dispose();
  }

  // ── state changes ──

  void _addStage() {
    setState(() {
      _stages.add(_StageDraft());
      _result = null;
      _error = null;
    });
  }

  void _removeStage(int i) {
    if (_stages.length <= 1) return;
    setState(() {
      _stages[i].dispose();
      _stages.removeAt(i);
      // A stage that lost its predecessor's link can no longer be chained.
      if (i < _stages.length) _stages[i].fromHeir = null;
      _invalidateLinksFrom(i - 1);
      _result = null;
      _error = null;
    });
  }

  /// Drops every link (and everything hanging off it) whose chosen heir is no
  /// longer present in the stage it came from.
  void _invalidateLinksFrom(int i) {
    for (int j = i + 1; j < _stages.length; j++) {
      final link = _stages[j].fromHeir;
      if (link == null) continue;
      if (_stages[j - 1].countOf(link) == 0) _stages[j].fromHeir = null;
    }
  }

  void _setGender(int i, bool isMale) {
    setState(() {
      _stages[i].isMale = isMale;
      // Both spouses go: the one that is now impossible must not stay counted
      // behind a hidden row.
      _stages[i].counts[HeirType.husband] = 0;
      _stages[i].counts[HeirType.wife] = 0;
      _result = null;
      _error = null;
    });
  }

  void _setLink(int i, HeirType heir) {
    setState(() {
      final s = _stages[i];
      s.fromHeir = heir;
      s.isMale = heirIsMale(heir);
      s.counts[HeirType.husband] = 0;
      s.counts[HeirType.wife] = 0;
      _result = null;
      _error = null;
    });
  }

  void _setCount(int i, HeirType t, int v) {
    setState(() {
      _stages[i].counts[t] = v.clamp(0, heirMaxCount(t));
      _invalidateLinksFrom(i);
      _result = null;
      _error = null;
    });
  }

  /// The label the row the user tapped shows (the shared catalog's wording), so
  /// a chip never renames an heir behind a different wording.
  String _pickLabel(HeirType t) => heirOptionOf(t)?.label ?? heirLabel(t);

  /// The label the engine carries for a stage — the picked relation, or the
  /// optional name for the first deceased.
  String _deceasedLabel(int i, _StageDraft s) {
    final link = s.fromHeir;
    if (link != null) return 'متوفی ${i + 1} (${_pickLabel(link)})';
    final name = s.name.text.trim();
    return name.isEmpty ? 'متوفی ${i + 1}' : name;
  }

  // ── calculation ──

  void _compute() {
    final estate = parseEstate(_estateCtrl.text);
    if (!estate.ok) {
      setState(() {
        _error = estate.error;
        _result = null;
      });
      return;
    }
    for (int i = 0; i < _stages.length; i++) {
      if (i > 0 && _stages[i].fromHeir == null) {
        setState(() {
          _error =
              'مرحله ${i + 1}: مشخص کنید متوفی کدام وارثِ مرحلهٔ $i بوده است.';
          _result = null;
        });
        return;
      }
      if (_stages[i].entered.isEmpty) {
        setState(() {
          _error = 'مرحله ${i + 1} هیچ وارثی ندارد؛ وارثان متوفی را وارد کنید.';
          _result = null;
        });
        return;
      }
    }
    try {
      final stagesData = <(String, InheritanceInput)>[
        for (final (i, s) in _stages.indexed)
          (
            _deceasedLabel(i, s),
            InheritanceInput.fromCounts(s.counts,
                estate: i == 0 ? estate.value : 0, madhab: _madhab),
          ),
      ];
      final caseResult = calculateMunasakhat(
        'مناسخات',
        stagesData,
        calculator: (input) => getCalculator(input.madhab).calculate(input),
        inheritedFromHeir: [for (final s in _stages) s.fromHeir],
        strictLinkage: true,
      );
      setState(() {
        _result = caseResult;
        _error = null;
      });
    } on MunasakhatLinkageException catch (e) {
      AppLogger.warning('munasakhat_sheet_content', e.toString());
      final link = _stages[e.stageIndex].fromHeir;
      setState(() {
        _result = null;
        _error = link == null
            ? 'مرحله ${e.stageIndex + 1} به هیچ سهمی از مرحلهٔ پیشین نرسید.'
            : '«${_pickLabel(link)}» در مرحلهٔ ${e.stageIndex} سهم نمی‌بَد (محجوب '
                'است یا وارثی ندارد)؛ پس سهمی هم به وارثانش نمی‌رسد. این پیوند را '
                ' عوض کنید.';
      });
    } catch (e) {
      AppLogger.warning('munasakhat_sheet_content', 'error: $e');
      setState(() {
        _result = null;
        _error = 'محاسبه انجام نشد؛ مقدارهای واردشده را بررسی کنید.';
      });
    }
  }

  // ── build ──

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _estateField(),
        const SizedBox(height: 12),
        const SectionHeader(title: 'مذهب فقهی', margin: EdgeInsets.zero),
        const SizedBox(height: DsSpacing.rowGap),
        Wrap(
          spacing: DsSpacing.gap,
          runSpacing: DsSpacing.gap,
          children: [
            for (final m in Madhab.values)
              _chip(
                key: ValueKey('madhab-${m.name}'),
                label: madhabLabel(m),
                selected: _madhab == m,
                onTap: () {
                  setState(() {
                    _madhab = m;
                    _result = null;
                    _error = null;
                  });
                },
              ),
          ],
        ),
        const SizedBox(height: 14),
        for (final (i, s) in _stages.indexed) _stageCard(i, s),
        const SizedBox(height: DsSpacing.gap),
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: _addStage,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('افزودن مرحله'),
                style: TextButton.styleFrom(
                    foregroundColor: dsContentColor(context, _a)),
              ),
            ),
            const SizedBox(width: DsSpacing.gap),
            Expanded(
              child: FilledButton.icon(
                onPressed: _compute,
                icon: const Icon(Icons.calculate_outlined, size: 18),
                label: const Text('محاسبه'),
                style: FilledButton.styleFrom(
                    backgroundColor: _a,
                    foregroundColor: t.card,
                    padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          _errorBox(_error!),
        ],
        if (_result != null) ...[
          const SizedBox(height: 14),
          _resultView(_result!),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: widget.onClose,
          icon: const Icon(Icons.close, size: 16),
          label: const Text('بستن'),
          style: OutlinedButton.styleFrom(
              foregroundColor: t.textMuted,
              side: BorderSide(color: t.textMuted.withValues(alpha: .3))),
        ),
      ],
    );
  }

  /// The estate of the FIRST deceased — every later stage's estate is what the
  /// engine carries off the previous stage, so nothing else is asked for.
  Widget _estateField() {
    return TextField(
      controller: _estateCtrl,
      keyboardType: TextInputType.number,
      inputFormatters: const [LatinGroupingFormatter()],
      onChanged: (_) {
        if (_result != null || _error != null) {
          setState(() {
            _result = null;
            _error = null;
          });
        }
      },
      style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 15),
          fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: 'مبلغ ترکهٔ مرحلهٔ اول',
        suffixText: unit,
        suffixStyle: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 11),
            color: TimeThemeKit.of(context).palette.textMuted),
        prefixIcon: Icon(Icons.account_balance_wallet,
            size: 20, color: dsContentColor(context, _a)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _stageCard(int i, _StageDraft s) {
    final t = TimeThemeKit.of(context).palette;
    final link = s.fromHeir;
    final option = link == null ? null : heirOptionOf(link);
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.gap),
      child: AppCard(
        key: ValueKey('stage-card-$i'),
        radius: 16,
        borderColor: _a.withValues(alpha: link == null && i > 0 ? .45 : .18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconTile(
                  icon: option?.icon ??
                      (i == 0 ? Icons.person_outline : Icons.account_tree),
                  color: _a,
                  size: 30,
                  iconSize: 16,
                ),
                const SizedBox(width: DsSpacing.rowGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('مرحله ${i + 1}',
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 13),
                              fontWeight: FontWeight.w700,
                              color: dsContentColor(context, _a))),
                      const SizedBox(height: 2),
                      Text(
                        i == 0
                            ? 'متوفی اول'
                            : link == null
                                ? 'یکی از ورثهٔ مرحلهٔ $i را انتخاب کنید'
                                : '${_pickLabel(link)} · ${s.isMale ? 'مرد' : 'زن'}',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 11),
                            color: t.textMuted),
                      ),
                    ],
                  ),
                ),
                if (i == 0)
                  GenderToggle(
                      isMale: s.isMale, onChanged: (v) => _setGender(i, v)),
                if (_stages.length > 1)
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        size: 20, color: _dangerColor(context)),
                    tooltip: 'حذف این مرحله',
                    onPressed: () => _removeStage(i),
                  ),
              ],
            ),
            if (i == 0) ...[
              const SizedBox(height: DsSpacing.rowGap),
              _nameField(s),
            ],
            if (i > 0) ...[
              const SizedBox(height: 10),
              _linkPicker(i),
            ],
            if (i == 0 || link != null) ...[
              const SizedBox(height: 10),
              _heirRows(i, s),
            ],
          ],
        ),
      ),
    );
  }

  Widget _nameField(_StageDraft s) {
    return TextField(
      controller: s.name,
      onChanged: (_) {
        if (_result != null) setState(() => _result = null);
      },
      style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 12),
          fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: TimeThemeKit.of(context).palette.surfaceAlt,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        hintText: 'نام یا رابطهٔ متوفی (اختیاری)',
        hintStyle: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 11),
            color: TimeThemeKit.of(context).palette.textMuted),
      ),
    );
  }

  /// The picker the chain runs on: the heirs entered for the previous stage.
  Widget _linkPicker(int i) {
    final t = TimeThemeKit.of(context).palette;
    final candidates = _stages[i - 1].entered;
    if (candidates.isEmpty) {
      return Text(
          'مرحلهٔ $i هنوز وارثی ندارد — ابتدا ورثهٔ مرحلهٔ پیشین را وارد کنید.',
          style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 11),
              color: t.textMuted));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('متوفی این مرحله کدام وارث بود؟',
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 11),
                fontWeight: FontWeight.w600,
                color: t.textSecondary)),
        const SizedBox(height: DsSpacing.rowGap),
        Wrap(
          spacing: DsSpacing.gap,
          runSpacing: DsSpacing.gap,
          children: [
            for (final h in candidates)
              _chip(
                key: ValueKey('link-$i-${h.name}'),
                label: _stages[i - 1].countOf(h) > 1
                    ? '${_pickLabel(h)} (${_stages[i - 1].countOf(h)})'
                    : _pickLabel(h),
                icon: heirOptionOf(h)?.icon,
                selected: _stages[i].fromHeir == h,
                onTap: () => _setLink(i, h),
              ),
          ],
        ),
      ],
    );
  }

  Widget _heirRows(int i, _StageDraft s) {
    final visible = visibleHeirOptions(isMale: s.isMale);
    bool near(HeirOption o) => _nearHeirs.contains(o.type);
    final distant = visible.where((o) => !near(o));
    return Column(
      children: [
        for (final o in visible.where(near)) _heirRow(i, o),
        if (distant.isNotEmpty) _distantToggle(i, s, distant.length),
        if (s.showDistant)
          for (final o in distant) _heirRow(i, o),
      ],
    );
  }

  Widget _heirRow(int i, HeirOption o) {
    final t = TimeThemeKit.of(context).palette;
    final count = _stages[i].countOf(o.type);
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.rowGap),
      child: Row(
        // The stepper keeps its full width, so a long relation name wraps onto
        // the label's own lines instead of pushing the controls off the row.
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(o.label,
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    fontWeight: count > 0 ? FontWeight.w700 : FontWeight.w400,
                    color: count > 0 ? t.textPrimary : t.textSecondary)),
          ),
          ValueStepper(
              key: ValueKey('count-$i-${o.type.name}'),
              value: count,
              max: o.maxCount,
              color: _a,
              onChanged: (v) => _setCount(i, o.type, v)),
        ],
      ),
    );
  }

  Widget _distantToggle(int i, _StageDraft s, int hidden) {
    final t = TimeThemeKit.of(context).palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.rowGap),
      child: TextButton.icon(
        onPressed: () => setState(() => s.showDistant = !s.showDistant),
        icon: Icon(s.showDistant ? Icons.expand_less : Icons.expand_more,
            size: 18, color: t.textMuted),
        label: Text(
            s.showDistant
                ? 'وراث دورتر را ببند'
                : 'وراث دورتر ($hidden خویشاوند)',
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 11.5),
                color: t.textMuted)),
      ),
    );
  }

  /// One selectable pill — the same flat recipe the madhab and linkage pickers
  /// use, so a choice always reads the same way.
  Widget _chip({
    Key? key,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    final t = TimeThemeKit.of(context).palette;
    final ink = dsContentColor(context, _a);
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: _a.withValues(alpha: selected ? .18 : .05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: _a.withValues(alpha: selected ? .55 : .2),
              width: selected ? 1.4 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: selected ? ink : t.textMuted),
              const SizedBox(width: 5),
            ],
            Text(label,
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? ink : t.textSecondary)),
          ],
        ),
      ),
    );
  }

  Color _dangerColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppTheme.darkError
          : AppTheme.lightError;

  Widget _errorBox(String message) {
    final danger = _dangerColor(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: danger.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: danger.withValues(alpha: .3))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 16, color: danger),
          const SizedBox(width: DsSpacing.rowGap),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 11.5),
                    color: danger,
                    height: 1.5)),
          ),
        ],
      ),
    );
  }

  Widget _resultView(MunasakhatCase result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
            title: 'نتیجهٔ مناسخات',
            count: '${result.stages.length} مرحله',
            margin: EdgeInsets.zero),
        const SizedBox(height: DsSpacing.gap),
        // An approximate linkage is never silent: a stage that fell back to the
        // equal-split estimate is listed here, so its numbers are not acted on.
        if (result.warnings.isNotEmpty) _warningsCard(result.warnings),
        for (final (i, stage) in result.stages.indexed) _stageResult(i, stage),
      ],
    );
  }

  Widget _warningsCard(List<String> warnings) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.gap),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 16, color: scheme.onErrorContainer),
                const SizedBox(width: DsSpacing.rowGap),
                Expanded(
                  child: Text('هشدار: پیوند برخی مرحله‌ها تقریبی است',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 11.5),
                          fontWeight: FontWeight.w700,
                          color: scheme.onErrorContainer)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            for (final w in warnings)
              Text('• $w',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 11),
                      color: scheme.onErrorContainer,
                      height: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _stageResult(int i, MunasakhatStage stage) {
    final t = TimeThemeKit.of(context).palette;
    final link = i > 0 && i < _stages.length ? _stages[i].fromHeir : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.gap),
      child: AppCard(
        key: ValueKey('stage-result-$i'),
        radius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('مرحله ${i + 1} · ${stage.deceasedLabel}',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12.5),
                    fontWeight: FontWeight.w700,
                    color: dsContentColor(context, _a))),
            const SizedBox(height: 2),
            Text(
                link == null
                    ? 'ترکه: ${NumberFormat.formatMoney(stage.result.estate, unit)}'
                    : 'سهم منتقل‌شده از «${_pickLabel(link)}» در مرحلهٔ $i: '
                        '${NumberFormat.formatMoney(stage.result.estate, unit)}',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    color: t.textMuted)),
            const SizedBox(height: DsSpacing.gap),
            for (final s in stage.result.shares) _shareRow(s),
            for (final w in stage.result.warnings)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('• $w',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 10.5),
                        color: t.textSecondary,
                        height: 1.5)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _shareRow(InheritanceShare s) {
    final t = TimeThemeKit.of(context).palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    s.count > 1
                        ? '${heirLabel(s.type)} (${s.count} نفر)'
                        : heirLabel(s.type),
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 11.5),
                        fontWeight: FontWeight.w600,
                        color: t.textPrimary)),
                Text('${s.fraction.toArString()} از ترکه',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 10),
                        color: t.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: DsSpacing.gap),
          Text(NumberFormat.formatPlain(s.amount),
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  fontWeight: FontWeight.w700,
                  color: dsContentColor(context, _a))),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/core/constants/date_constants.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/tools/calculator/data/calculator_tools.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/shared/utils/shamsi_date_picker.dart';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/features/tools/calculator/domain/unit_conversion.dart';

/// Panel for the «درصد» calculator: X٪ از Y و نسبت.
class PercentPanel extends StatefulWidget {
  const PercentPanel({super.key, required this.accent});
  final Color accent;

  @override
  State<PercentPanel> createState() => _PercentPanelState();
}

class _PercentPanelState extends State<PercentPanel> {
  final _valueCtrl = TextEditingController();
  final _percentCtrl = TextEditingController();
  String? _result;

  @override
  void dispose() {
    _valueCtrl.dispose();
    _percentCtrl.dispose();
    super.dispose();
  }

  void _calc() {
    HapticFeedback.lightImpact();
    final v = _parseNumber(_valueCtrl.text);
    final p = _parseNumber(_percentCtrl.text);
    setState(() {
      if (v == null || p == null) {
        _result = 'لطفاً مقادیر را درست وارد کنید';
      } else {
        final amount = CalculatorTools.percentOf(v, p);
        _result =
            '${CalculatorTools.format(p)}٪ از ${CalculatorTools.format(v)} = ${CalculatorTools.format(amount)}\n'
            'افزایش: ${CalculatorTools.format(v)} + ${CalculatorTools.format(p)}٪ = ${CalculatorTools.format(CalculatorTools.percentIncrease(v, p))}\n'
            'کاهش: ${CalculatorTools.format(v)} − ${CalculatorTools.format(p)}٪ = ${CalculatorTools.format(CalculatorTools.percentDecrease(v, p))}';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final textColor = t.textPrimary;
    final mutedColor = t.textMuted;

    return ListView(
      padding: const EdgeInsets.all(DsSpacing.page),
      children: [
        Text('درصد از عدد', style: TextStyle(color: mutedColor, fontSize: AppTheme.scaledFontSize(context, 14))),
        const SizedBox(height: 12),
        _InputField(ctrl: _valueCtrl, label: 'عدد', hint: 'مثلاً 200'),
        const SizedBox(height: 10),
        _InputField(ctrl: _percentCtrl, label: 'درصد', hint: 'مثلاً 15'),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: widget.accent),
          onPressed: _calc,
          icon: const Icon(Icons.calculate_outlined),
          label: const Text('محاسبه'),
        ),
        if (_result != null) ...[
          const SizedBox(height: 16),
          AppCard(
            padding: const EdgeInsets.all(14),
            color: widget.accent.withValues(alpha: 0.10),
            borderColor: widget.accent.withValues(alpha: 0.3),
            child: Text(
              _result!,
              style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 17),
                fontWeight: FontWeight.bold,
                color: textColor,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Panel for the «تخفیف» calculator: قیمت، درصد تخفیف → مبلغ نهایی.
class DiscountPanel extends StatefulWidget {
  const DiscountPanel({super.key, required this.accent});
  final Color accent;

  @override
  State<DiscountPanel> createState() => _DiscountPanelState();
}

class _DiscountPanelState extends State<DiscountPanel> {
  final _priceCtrl = TextEditingController();
  final _percentCtrl = TextEditingController();
  String? _result;

  @override
  void dispose() {
    _priceCtrl.dispose();
    _percentCtrl.dispose();
    super.dispose();
  }

  void _calc() {
    HapticFeedback.lightImpact();
    final p = _parseNumber(_priceCtrl.text);
    final d = _parseNumber(_percentCtrl.text);
    setState(() {
      if (p == null || d == null) {
        _result = 'لطفاً مقادیر را درست وارد کنید';
      } else {
        _result =
            'تخفیف: ${CalculatorTools.formatMoney(CalculatorTools.discountAmount(p, d))}\n'
            'مبلغ نهایی: ${CalculatorTools.formatMoney(CalculatorTools.finalPrice(p, d))}';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final textColor = t.textPrimary;
    final mutedColor = t.textMuted;

    return ListView(
      padding: const EdgeInsets.all(DsSpacing.page),
      children: [
        Text('محاسبهٔ تخفیف',
            style: TextStyle(color: mutedColor, fontSize: AppTheme.scaledFontSize(context, 14))),
        const SizedBox(height: 12),
        _InputField(
            ctrl: _priceCtrl, label: 'قیمت اولیه', hint: 'مثلاً 500000'),
        const SizedBox(height: 10),
        _InputField(ctrl: _percentCtrl, label: 'درصد تخفیف', hint: 'مثلاً 20'),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: widget.accent),
          onPressed: _calc,
          icon: const Icon(Icons.percent),
          label: const Text('محاسبه'),
        ),
        if (_result != null) ...[
          const SizedBox(height: 16),
          AppCard(
            padding: const EdgeInsets.all(14),
            color: widget.accent.withValues(alpha: 0.10),
            borderColor: widget.accent.withValues(alpha: 0.3),
            child: Text(
              _result!,
              style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 16),
                fontWeight: FontWeight.bold,
                color: textColor,
                fontFamily: AppTheme.fontFamily,
                height: 1.8,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Panel for the «سن» calculator: تولد → سن (سال/ماه/روز).
class AgePanel extends StatefulWidget {
  const AgePanel({super.key, required this.accent});
  final Color accent;

  @override
  State<AgePanel> createState() => _AgePanelState();
}

class _AgePanelState extends State<AgePanel> {
  DateTime? _birth;
  String? _result;

  Future<void> _pick() async {
    final picked = await ShamsiDatePicker.show(context);
    if (picked == null) return;
    final now = DateTime.now();
    if (picked.isAfter(now)) {
      setState(() {
        _birth = null;
        _result = 'تاریخ تولد نمی‌تواند در آینده باشد';
      });
      return;
    }
    setState(() {
      _birth = picked;
      final age = CalculatorTools.ageFrom(picked, now);
      final j = Jalali.fromDateTime(picked);
      final days = CalculatorTools.totalDaysBetween(picked, now);
      final nextBd = CalculatorTools.daysToNextBirthday(picked, now);
      _result =
          'تولد: ${CalculatorTools.en(j.day)} ${_monthName(j.month)} ${CalculatorTools.en(j.year)}\n'
          'سن: ${CalculatorTools.en(age.years)} سال و ${CalculatorTools.en(age.months)} ماه و ${CalculatorTools.en(age.days)} روز\n'
          'مجموع: ${CalculatorTools.en(CalculatorTools.totalMonths(picked, now))} ماه | ${CalculatorTools.en((days / 7).floor())} هفته | ${CalculatorTools.en(days)} روز\n'
          'تولد بعدی: ${CalculatorTools.en(nextBd)} روز دیگر';
    });
  }

  static String _monthName(int m) => DateConstants.persianMonths[m - 1];

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final textColor = t.textPrimary;
    final mutedColor = t.textMuted;

    return ListView(
      padding: const EdgeInsets.all(DsSpacing.page),
      children: [
        Text('محاسبهٔ سن', style: TextStyle(color: mutedColor, fontSize: AppTheme.scaledFontSize(context, 14))),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: widget.accent,
            side: BorderSide(color: widget.accent.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: _pick,
          icon: const Icon(Icons.cake_outlined),
          label: const Text('انتخاب تاریخ تولد (شمسی)'),
        ),
        if (_birth != null) ...[
          const SizedBox(height: 12),
          Text(
            'تولد: ${_birth!.year}/${_birth!.month}/${_birth!.day}',
            style: TextStyle(color: mutedColor, fontSize: AppTheme.scaledFontSize(context, 13)),
          ),
        ],
        if (_result != null) ...[
          const SizedBox(height: 16),
          AppCard(
            padding: const EdgeInsets.all(14),
            color: widget.accent.withValues(alpha: 0.10),
            borderColor: widget.accent.withValues(alpha: 0.3),
            child: Text(
              _result!,
              style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 16),
                fontWeight: FontWeight.bold,
                color: textColor,
                fontFamily: AppTheme.fontFamily,
                height: 1.8,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Panel for the «تبدیل واحد» calculator.
class UnitPanel extends StatefulWidget {
  const UnitPanel({super.key, required this.accent});
  final Color accent;

  @override
  State<UnitPanel> createState() => _UnitPanelState();
}

/// «تبدیل واحد» — nine categories (incl. مساحت، سرعت و «محلی ★»), recents,
/// and editable local-unit bases. Maths lives in
/// `calculator/domain/unit_conversion.dart` (unit-tested); this widget only
/// collects input and shows results.
class _UnitPanelState extends State<UnitPanel> {
  UnitCategory _category = UnitCategory.length;
  final _valueCtrl = TextEditingController();
  String _from = 'متر';
  String _to = 'کیلومتر';
  String? _result;
  Map<String, double> _localBases = {};
  List<String> _recents = [];
  bool _loaded = false;

  static const _catKey = 'calc_unit_category';
  static const _localKey = 'calc_unit_local_bases';
  static const _recentKey = 'calc_unit_recents';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void dispose() {
    _valueCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final catIdx = prefs.getInt(_catKey) ?? 0;
      final basesJson = prefs.getString(_localKey);
      final recents = prefs.getStringList(_recentKey) ?? const [];
      if (!mounted) return;
      setState(() {
        _category = UnitCategory
            .values[catIdx.clamp(0, UnitCategory.values.length - 1)];
        if (basesJson != null) {
          final decoded = jsonDecode(basesJson);
          if (decoded is Map) {
            _localBases = {
              for (final e in decoded.entries)
                if (e.value is num)
                  e.key as String: (e.value as num).toDouble(),
            };
          }
        }
        // Seed any shipped default the user has not set yet.
        for (final u in defaultLocalUnits) {
          _localBases.putIfAbsent(u.name, () => u.defaultBaseKg);
        }
        _recents = recents.take(6).toList();
        _loaded = true;
      });
      _resetUnits();
    } catch (e) {
      // A failed prefs read only falls back to the shipped defaults.
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _savePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_catKey, _category.index);
      await prefs.setString(_localKey, jsonEncode(_localBases));
      await prefs.setStringList(_recentKey, _recents);
    } catch (_) {
      // A failed preference write only loses the remembered state.
    }
  }

  void _resetUnits() {
    // Unconditional per-category defaults — the existing unit_panel tests pin
    // this behavior (switching to زمان always lands on ساعت → دقیقه), and it
    // is friendlier than carrying a length unit into a time conversion.
    final pair = switch (_category) {
      UnitCategory.length => ('متر', 'کیلومتر'),
      UnitCategory.mass => ('کیلوگرم', 'گرم'),
      UnitCategory.area => ('متر مربع', 'کیلومتر مربع'),
      UnitCategory.volume => ('لیتر', 'میلی‌لیتر'),
      UnitCategory.temperature => ('سانتی‌گراد', 'فارنهایت'),
      UnitCategory.speed => ('کیلومتر بر ساعت', 'متر بر ثانیه'),
      UnitCategory.time => ('ساعت', 'دقیقه'),
      UnitCategory.data => ('گیگابایت', 'مگابایت'),
      UnitCategory.local => ('من (تبریز)', 'کیلوگرم'),
    };
    _from = pair.$1;
    _to = pair.$2;
  }

  List<String> get _units => switch (_category) {
        UnitCategory.length => unitLengthToMeter.keys.toList(),
        UnitCategory.area => unitAreaToSquareMeter.keys.toList(),
        UnitCategory.speed => unitSpeedToMeterPerSecond.keys.toList(),
        UnitCategory.mass => unitMassToKg.keys.toList(),
        UnitCategory.volume => unitVolumeToLiter.keys.toList(),
        UnitCategory.temperature => CalculatorTools.temperatureUnits,
        UnitCategory.time => unitTimeToSecond.keys.toList(),
        UnitCategory.data => unitDataToByte.keys.toList(),
        UnitCategory.local => [
            ...defaultLocalUnits.map((u) => u.name),
            'کیلوگرم',
          ],
      };

  void _calc() {
    HapticFeedback.lightImpact();
    final v = _parseNumber(_valueCtrl.text);
    setState(() {
      if (v == null) {
        _result = 'لطفاً مقدار را درست وارد کنید';
        return;
      }
      final out = convertUnits(
        category: _category,
        value: v,
        from: _from,
        to: _to,
        localBasesKg: _localBases,
      );
      if (out == null) {
        _result = 'مبنای یکی از واحدها وارد نشده؛ با «ویرایش مبنا» کامل کنید.';
        return;
      }
      final line =
          '${CalculatorTools.format(v)} $_from = ${CalculatorTools.format(out)} $_to';
      _result = line;
      // Recent conversions: newest first, deduped, capped at 6.
      _recents
        ..remove(line)
        ..insert(0, line);
      if (_recents.length > 6) _recents.removeLast();
      _savePrefs();
    });
  }

  Future<void> _editLocalBase(String unit) async {
    final ctrl = TextEditingController(
        text: _localBases[unit] == null
            ? ''
            : CalculatorTools.format(_localBases[unit] ?? 0));
    final t = TimeThemeKit.of(context).palette;
    final note =
        defaultLocalUnits.where((u) => u.name == unit).firstOrNull;
    final saved = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.elevated,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHandle(),
              Text(
                'مبنای $unit (کیلوگرم)',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: t.textPrimary,
                ),
              ),
              if (note != null && note.note.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  note.note,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    color: t.textMuted,
                  ),
                ),
              ],
              Text(
                'مقدار پیش‌فرض تأیید نشده است؛ مبنای درست را از منبع معتبر '
                'خودتان وارد کنید.',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 10,
                  color: DsStatus.warning(context),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'هر ۱ $unit چند کیلوگرم است؟',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: t.card,
                ),
                onSubmitted: (_) {
                  final v = double.tryParse(
                      NumberFormat.normalizeDigits(ctrl.text.trim()));
                  if (v != null && v > 0) {
                    Navigator.of(sheetContext).pop(v);
                  }
                },
              ),
              const SizedBox(height: 12),
              FilledButton(
                style:
                    FilledButton.styleFrom(backgroundColor: widget.accent),
                onPressed: () {
                  final v = double.tryParse(
                      NumberFormat.normalizeDigits(ctrl.text.trim()));
                  if (v != null && v > 0) {
                    Navigator.of(sheetContext).pop(v);
                  }
                },
                child: const Text('ذخیره مبنا'),
              ),
            ],
          ),
        ),
      ),
    );
    if (saved == null || !mounted) return;
    setState(() {
      _localBases[unit] = saved;
      _result = null;
    });
    _savePrefs();
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final textColor = t.textPrimary;
    final mutedColor = t.textMuted;
    final units = _units;
    final needsBase = _category == UnitCategory.local &&
        (_from == 'کیلوگرم'
            ? false
            : (_localBases[_from] == null || _localBases[_to] == null));

    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(DsSpacing.page),
      children: [
        Text('تبدیل واحد',
            style: TextStyle(
                color: mutedColor,
                fontSize: AppTheme.scaledFontSize(context, 14))),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final cat in UnitCategory.values)
              ChoiceChip(
                label: Text(cat.titleFa),
                selected: _category == cat,
                selectedColor: widget.accent.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  color: _category == cat ? widget.accent : mutedColor,
                  fontWeight:
                      _category == cat ? FontWeight.bold : FontWeight.normal,
                  fontFamily: AppTheme.fontFamily,
                ),
                side: BorderSide(
                  color: _category == cat
                      ? widget.accent.withValues(alpha: 0.6)
                      : Colors.transparent,
                ),
                onSelected: (_) {
                  setState(() {
                    _category = cat;
                    _resetUnits();
                    _result = null;
                  });
                  _savePrefs();
                },
              ),
          ],
        ),
        const SizedBox(height: 14),
        _InputField(ctrl: _valueCtrl, label: 'مقدار', hint: 'مثلاً 10'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _from,
                decoration: InputDecoration(
                  labelText: 'از',
                  labelStyle: TextStyle(color: mutedColor),
                  filled: true,
                  fillColor: t.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: [
                  for (final u in units)
                    DropdownMenuItem(value: u, child: Text(u)),
                ],
                onChanged: (v) => setState(() => _from = v ?? _from),
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.arrow_forward, color: mutedColor),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _to,
                decoration: InputDecoration(
                  labelText: 'به',
                  labelStyle: TextStyle(color: mutedColor),
                  filled: true,
                  fillColor: t.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: [
                  for (final u in units)
                    DropdownMenuItem(value: u, child: Text(u)),
                ],
                onChanged: (v) => setState(() => _to = v ?? _to),
              ),
            ),
          ],
        ),
        if (_category == UnitCategory.local &&
            _from != 'کیلوگرم' &&
            _to != 'کیلوگرم') ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _editLocalBase(_from),
            icon: const Icon(Icons.tune_rounded, size: 16),
            label: Text(
              needsBase ? 'مبنا را وارد کنید: $_from' : 'ویرایش مبنای $_from',
              style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 11),
            ),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: widget.accent),
          onPressed: _calc,
          icon: const Icon(Icons.swap_horiz),
          label: const Text('تبدیل'),
        ),
        if (_result != null) ...[
          const SizedBox(height: 16),
          AppCard(
            padding: const EdgeInsets.all(14),
            color: widget.accent.withValues(alpha: 0.10),
            borderColor: widget.accent.withValues(alpha: 0.3),
            child: Text(
              _result!,
              style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 17),
                fontWeight: FontWeight.bold,
                color: textColor,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ),
        ],
        if (_recents.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'تبدیل‌های اخیر',
            style: TextStyle(
                color: mutedColor,
                fontSize: AppTheme.scaledFontSize(context, 12)),
          ),
          const SizedBox(height: 6),
          for (final recent in _recents.where((r) => r != _result))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _result = recent),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: t.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    recent,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      color: t.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// Panel for the «قسط قرض الحسنه» calculator: مبلغ و مدت → قسط ماهانه.
class QardHasanPanel extends StatefulWidget {
  const QardHasanPanel({super.key, required this.accent});
  final Color accent;

  @override
  State<QardHasanPanel> createState() => _QardHasanPanelState();
}

class _QardHasanPanelState extends State<QardHasanPanel> {
  final _amountCtrl = TextEditingController();
  final _monthsCtrl = TextEditingController();
  String? _result;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _monthsCtrl.dispose();
    super.dispose();
  }

  void _calc() {
    HapticFeedback.lightImpact();
    final amount = _parseNumber(_amountCtrl.text);
    final months = _parseInt(_monthsCtrl.text);
    setState(() {
      if (amount == null || months == null || amount <= 0 || months <= 0) {
        _result = 'لطفاً مقادیر را درست وارد کنید';
        return;
      }
      final m = CalculatorTools.qardHasanMonthlyPayment(amount, months);
      if (m == null) {
        _result = 'لطفاً مقادیر را درست وارد کنید';
        return;
      }
      _result = 'قسط ماهانه: ${CalculatorTools.formatMoney(m)}\n'
          'تعداد قسط: ${CalculatorTools.en(months)}\n'
          'بازپرداخت کل: ${CalculatorTools.formatMoney(amount)}\n'
          'سود پرداختی: 0 (قرض الحسنه بدون سود است)';
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final textColor = t.textPrimary;
    final mutedColor = t.textMuted;

    return ListView(
      padding: const EdgeInsets.all(DsSpacing.page),
      children: [
        Text('محاسبهٔ قسط قرض الحسنه',
            style: TextStyle(color: mutedColor, fontSize: AppTheme.scaledFontSize(context, 14))),
        const SizedBox(height: 4),
        Text(
            'قرض الحسنه سودی ندارد و هر قسط برابر مبلغ تقسیم بر تعداد اقساط است.',
            style: TextStyle(color: mutedColor, fontSize: AppTheme.scaledFontSize(context, 12))),
        const SizedBox(height: 12),
        _InputField(
            ctrl: _amountCtrl,
            label: 'مبلغ قرض الحسنه',
            hint: 'مثلاً 50000000'),
        const SizedBox(height: 10),
        _InputField(ctrl: _monthsCtrl, label: 'مدت (ماه)', hint: 'مثلاً 36'),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: widget.accent),
          onPressed: _calc,
          icon: const Icon(Icons.request_quote_outlined),
          label: const Text('محاسبه'),
        ),
        if (_result != null) ...[
          const SizedBox(height: 16),
          AppCard(
            padding: const EdgeInsets.all(14),
            color: widget.accent.withValues(alpha: 0.10),
            borderColor: widget.accent.withValues(alpha: 0.3),
            child: Text(
              _result!,
              style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 16),
                fontWeight: FontWeight.bold,
                color: textColor,
                fontFamily: AppTheme.fontFamily,
                height: 1.8,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.ctrl,
    required this.label,
    required this.hint,
  });

  final TextEditingController ctrl;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final mutedColor = t.textMuted;
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textDirection: TextDirection.ltr,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: mutedColor),
        hintText: hint,
        filled: true,
        fillColor: t.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

/// Parses a tool-panel amount, first folding Persian/Arabic digits and the
/// Persian separators (٬ ٫) to their Latin forms. Returns `null` for anything
/// unreadable so the panels can still show «enter valid values».
double? _parseNumber(String text) {
  final s = NumberFormat.normalizeDigits(text.trim())
      .replaceAll('٬', '')
      .replaceAll('٫', '.');
  return double.tryParse(s);
}

/// [_parseNumber] for integer-only inputs (e.g. a number of months).
int? _parseInt(String text) =>
    int.tryParse(NumberFormat.normalizeDigits(text.trim()));

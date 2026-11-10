import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal/family_faith/family_faith_providers.dart';
import 'package:tawheeed/features/personal/family_faith/presentation/family_faith_style.dart';
import 'package:tawheeed/features/personal/family_faith/savings/savings_models.dart';
import 'package:tawheeed/features/personal/presentation/widgets/care_sheet_kit.dart';
import 'package:tawheeed/features/personal/presentation/widgets/care_widgets.dart'
    show CareChip;
import 'package:tawheeed/shared/services/currency_store.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

Future<void> showGoalSheet(BuildContext context, {SavingsGoal? goal}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _GoalSheet(goal: goal),
  );
}

class _GoalSheet extends ConsumerStatefulWidget {
  const _GoalSheet({this.goal});

  final SavingsGoal? goal;

  @override
  ConsumerState<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends ConsumerState<_GoalSheet> {
  late final TextEditingController _title;
  late final TextEditingController _target;
  late final TextEditingController _note;
  late String _iconKey;
  late String _accentKey;
  DateTime? _targetDate;
  bool _remindWeekly = false;

  bool get _editing => widget.goal != null;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.goal?.title ?? '');
    _target = TextEditingController(
      text: widget.goal == null
          ? ''
          : NumberFormat.formatPlain(widget.goal!.targetAmount),
    );
    _iconKey = widget.goal?.iconKey ?? 'savings';
    _accentKey = widget.goal?.accentKey ?? 'gold';
    _targetDate = widget.goal?.targetDate;
    _remindWeekly = widget.goal?.remindWeekly ?? false;
    _note = TextEditingController(text: widget.goal?.note ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _target.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final unit = CurrencyStore.calculators.current.unit;
    final insets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: AppCard(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CareSheetTitle(
                    title: _editing ? 'ویرایش هدف' : 'هدف تازه',
                    subtitle: 'مبلغ هدف را خودتان تعیین کنید؛ برنامه فقط جمع می‌زند.',
                  ),
                  CareField(controller: _title, label: 'عنوان هدف', hint: 'مثلاً سفر'),
                  CareField(
                    controller: _target,
                    label: 'مبلغ هدف ($unit)',
                    hint: 'مثلاً ۲۰,۰۰۰,۰۰۰',
                    keyboardType: TextInputType.number,
                    digitsOnly: true,
                    ltr: true,
                  ),
                  Text(
                    'نماد',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 11),
                      color: t.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final key in const [
                        'savings',
                        'home',
                        'car',
                        'travel',
                        'education',
                        'gift',
                        'health',
                      ])
                        IconButton(
                          tooltip: key,
                          onPressed: () => setState(() => _iconKey = key),
                          style: IconButton.styleFrom(
                            backgroundColor: _iconKey == key
                                ? familySavingsColor.withValues(alpha: .16)
                                : t.surfaceAlt,
                          ),
                          icon: Icon(
                            savingsIconFor(key),
                            size: 18,
                            color: _iconKey == key
                                ? dsContentColor(context, familySavingsColor)
                                : t.textMuted,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'رنگ جار',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 11),
                      color: t.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in kSavingsAccentPalette.entries)
                        GestureDetector(
                          onTap: () => setState(() => _accentKey = entry.key),
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: entry.value,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _accentKey == entry.key
                                    ? t.textPrimary
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: _accentKey == entry.key
                                ? const Icon(Icons.check,
                                    size: 16, color: Colors.white)
                                : null,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: CareDateButton(
                          label: 'تاریخ هدف (اختیاری)',
                          date: _targetDate,
                          accent: familySavingsColor,
                          onPicked: (date) => setState(() => _targetDate = date),
                        ),
                      ),
                      if (_targetDate != null)
                        IconButton(
                          tooltip: 'پاک کردن',
                          onPressed: () => setState(() => _targetDate = null),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                    ],
                  ),
                  CareSwitchRow(
                    label: 'یادآوری هفتگی واریز',
                    value: _remindWeekly,
                    accent: familySavingsColor,
                    onChanged: (value) => setState(() => _remindWeekly = value),
                  ),
                  CareField(
                    controller: _note,
                    label: 'یادداشت (اختیاری)',
                    maxLines: 2,
                  ),
                  CareSheetSubmit(
                    label: _editing ? 'ذخیرهٔ تغییرات' : 'ساختن هدف',
                    accent: familySavingsColor,
                    onPressed: _save,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final target = NumberFormat.parse(_target.text);
    if (title.isEmpty || target <= 0) return;
    final store = ref.read(savingsStoreProvider.notifier);
    if (_editing) {
      await store.updateGoal(widget.goal!.copyWith(
        title: title,
        targetAmount: target,
        targetDate: _targetDate,
        iconKey: _iconKey,
        accentKey: _accentKey,
        remindWeekly: _remindWeekly,
        note: _note.text.trim(),
      ));
    } else {
      await store.addGoal(
        title: title,
        targetAmount: target,
        targetDate: _targetDate,
        iconKey: _iconKey,
        accentKey: _accentKey,
        remindWeekly: _remindWeekly,
        note: _note.text.trim(),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }
}

/// Deposit or withdrawal sheet. [presets] come from the preset store; the chips
/// fill the amount so a common amount is one tap.
Future<void> showDepositSheet(
  BuildContext context,
  SavingsGoal goal, {
  bool withdraw = false,
  List<double> presets = const [100000, 500000, 1000000],
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DepositSheet(
      goal: goal,
      withdraw: withdraw,
      presets: presets,
    ),
  );
}

class _DepositSheet extends ConsumerStatefulWidget {
  const _DepositSheet({
    required this.goal,
    required this.withdraw,
    required this.presets,
  });

  final SavingsGoal goal;
  final bool withdraw;
  final List<double> presets;

  @override
  ConsumerState<_DepositSheet> createState() => _DepositSheetState();
}

class _DepositSheetState extends ConsumerState<_DepositSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final unit = CurrencyStore.calculators.current.unit;
    final insets = MediaQuery.of(context).viewInsets.bottom;
    // Withdrawal is the one destructive action on a goal, so it wears the
    // error colour instead of a muted grey the user reads as «disabled».
    final accent = widget.withdraw
        ? Theme.of(context).colorScheme.error
        : familySavingsColor;
    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: AppCard(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CareSheetTitle(
                    title: widget.withdraw
                        ? 'برداشت از «${widget.goal.title}»'
                        : 'واریز به «${widget.goal.title}»',
                    subtitle: widget.withdraw
                        ? 'برداشت از موجودی همین قلک کم می‌شود.'
                        : 'هر روز یا هر ماه، هر چقدر که راحت‌اید.',
                  ),
                  if (!widget.withdraw)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final preset in widget.presets)
                          CareChip(
                            label: NumberFormat.formatMoney(preset, unit),
                            selected: false,
                            accent: familySavingsColor,
                            onTap: () => setState(() {
                              _amount.text = NumberFormat.formatPlain(preset);
                            }),
                          ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  CareField(
                    controller: _amount,
                    label: 'مبلغ ($unit)',
                    hint: 'مثلاً ۵۰۰,۰۰۰',
                    keyboardType: TextInputType.number,
                    digitsOnly: true,
                    ltr: true,
                  ),
                  CareDateButton(
                    label: 'تاریخ',
                    date: _date,
                    accent: accent,
                    onPicked: (date) => setState(() => _date = date),
                  ),
                  const SizedBox(height: 8),
                  CareField(
                    controller: _note,
                    label: 'یادداشت (اختیاری)',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 6),
                  CareSheetSubmit(
                    label: widget.withdraw ? 'برداشت' : 'واریز',
                    accent: accent,
                    onPressed: _save,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final amount = NumberFormat.parse(_amount.text);
    if (amount <= 0) return;
    final store = ref.read(savingsStoreProvider.notifier);
    bool ok = true;
    if (widget.withdraw) {
      ok = await store.withdraw(
        goal: widget.goal,
        amount: amount,
        date: _date,
        note: _note.text.trim(),
      );
    } else {
      await store.addDeposit(
        goal: widget.goal,
        amount: amount,
        date: _date,
        note: _note.text.trim(),
      );
    }
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('موجودی این هدف کمتر از مبلغ برداشت است.')),
      );
      return;
    }
    Navigator.of(context).pop();
  }
}

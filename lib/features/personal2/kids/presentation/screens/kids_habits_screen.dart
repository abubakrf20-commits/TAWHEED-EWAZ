import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal2/kids/data/kids_dao.dart';
import 'package:tawheeed/features/personal2/kids/domain/kid_logic.dart';
import 'package:tawheeed/features/personal2/kids/presentation/providers/kids_providers.dart';
import 'package:tawheeed/features/personal2/shared/parent_lock.dart';
import 'package:tawheeed/features/personal2/shared/personal2_style.dart';
import 'package:tawheeed/features/personal2/shared/template_store.dart';
import 'package:tawheeed/shared/widgets/app_empty_state.dart';

/// One icon offered in the add/edit habit picker.
class _HabitIcon {
  const _HabitIcon(this.key, this.label, this.icon);
  final String key;
  final String label;
  final IconData icon;
}

/// «عادت‌ها» — every child's habits with star values, plus the parent's manual
/// star adjustment (which requires the PIN and a note, per the brief).
class KidsHabitsScreen extends ConsumerWidget {
  const KidsHabitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(kidsHomeProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: SectionAppBar(
          title: 'عادت‌ها',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'بازگشت',
            onPressed: () => context.pop(),
          ),
          actions: home.maybeWhen(
            data: (d) => d.children.isEmpty
                ? const []
                : [
                    IconButton(
                      tooltip: 'افزودن عادت',
                      icon: const Icon(Icons.add),
                      onPressed: () => _addHabit(context, ref),
                    ),
                  ],
            orElse: () => const [],
          ),
        ),
        body: SafeArea(
          child: home.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => FailureView(
              id: 'kids_habits_load',
              title: 'عادت‌ها باز نشدند',
              detail: 'عادت‌ها و ستاره‌های ثبت‌شده پاک نشده‌اند؛ فقط '
                  'خواندنشان ناموفق بود.',
              onRetry: () => ref.invalidate(kidsHomeProvider),
              layout: FailureLayout.page,
              error: e,
            ),
            data: (data) => data.children.isEmpty
                ? const AppEmptyState(
                    icon: Icons.child_care_outlined,
                    message: 'فرزندی ثبت نشده',
                    subtitle: 'از دفتر کودک، اولین فرزند را اضافه کنید تا '
                        'عادت‌هایش اینجا بیاید.',
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                        DsSpacing.page, 12, DsSpacing.page, 40),
                    children: [
                      for (final child in data.children)
                        _childBlock(context, ref, child, data),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _childBlock(
    BuildContext context,
    WidgetRef ref,
    KidRecord child,
    KidsHomeState data,
  ) {
    return Consumer(
      builder: (context, ref, _) {
        final t = TimeThemeKit.of(context).palette;
        final day = ref.watch(kidDayProvider(child.id));
        final weekly = ref.watch(kidWeeklyProvider(child.id));
        final color = KidColors.of(child.colorKey);

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(title: child.name, accent: color),
              const SizedBox(height: 6),
              day.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => FailureView(
                  id: 'kid_habits_${child.id}',
                  title: 'عادت‌های امروز خوانده نشد',
                  onRetry: () => ref.invalidate(kidDayProvider(child.id)),
                  layout: FailureLayout.inline,
                  error: e,
                ),
                data: (state) {
                  if (state == null) return const Text('—');
                  if (state.habits.isEmpty) {
                    return AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'عادتی ندارد.',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12,
                              color: t.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () => _addHabit(context, ref),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('افزودن عادتی برای این فرزند'),
                          ),
                        ],
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final habit in state.habits)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _habitRow(
                            context,
                            ref,
                            child,
                            state,
                            habit,
                            weekly,
                          ),
                        ),
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _adjustStars(context, ref, state, color),
                        icon: const Icon(Icons.stars_rounded, size: 18),
                        label: Text(
                          'اصلاح ستاره‌ها (موجودی: ${state.balance})',
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _habitRow(
    BuildContext context,
    WidgetRef ref,
    KidRecord child,
    KidDayState state,
    HabitSpec habit,
    AsyncValue<WeeklySummary?> weekly,
  ) {
    final t = TimeThemeKit.of(context).palette;
    final color = KidColors.of(child.colorKey);
    final log = state.logForHabit(habit.id);
    final doneToday = log != null &&
        (log.status == KidLogStatus.approved ||
            log.status == KidLogStatus.pending);

    final summary = weekly.maybeWhen(
      data: (s) => s,
      orElse: () => null,
    );
    HabitCompletion? completion;
    if (summary != null) {
      for (final c in summary.habits) {
        if (c.habit.id == habit.id) {
          completion = c;
          break;
        }
      }
    }
    final weeklyRatio = completion?.ratio ?? 0;
    final weeklyDone = completion?.doneDays ?? 0;
    final weeklyScheduled = completion?.scheduledDays ?? 0;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _HabitPlant(
            growth: weeklyRatio,
            bloomed: doneToday,
            color: color,
            outline: t.outline,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        habit.title,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: doneToday ? t.primary : t.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (doneToday)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Icon(
                          Icons.check_circle,
                          color: t.primary,
                          size: 18,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    // Audit fix (merge follow-up): a long «X ★ · (Y از Z روز)»
                    // line overflowed this Row by ~75px at narrow widths —
                    // the text is now flexible and elides instead.
                    Expanded(
                      child: Text(
                        '${habit.stars} ★ · '
                        '($weeklyDone از $weeklyScheduled روز)',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11,
                          color: t.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (weeklyScheduled > 0) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: weeklyRatio,
                      minHeight: 6,
                      backgroundColor: t.outline.withValues(alpha: 0.3),
                      color: weeklyRatio >= 1 ? AppTheme.success : color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'نرخ انجام هفتگی: ${(weeklyRatio * 100).round()}%',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 10),
                      color: t.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'ویرایش عادتی',
                icon: const Icon(Icons.edit_outlined, size: 20),
                color: t.primary,
                onPressed: () => _editHabit(context, ref, child.id, habit),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip:
                    habit.active ? 'غیرفعال کردن عادتی' : 'فعال کردن عادتی',
                icon: Icon(
                  habit.active
                      ? Icons.delete_outline_rounded
                      : Icons.restore_rounded,
                  size: 20,
                ),
                color: habit.active ? AppTheme.error : AppTheme.success,
                onPressed: () => _toggleHabit(context, ref, child.id, habit),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'کپی عادتی به همه فرزندان',
                icon: const Icon(
                  Icons.content_copy_outlined,
                  size: 20,
                ),
                color: t.textSecondary,
                onPressed: () =>
                    _copyHabitToAllChildren(context, ref, child, habit),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Star adjustment: PIN first, then a signed amount AND a note (both
  /// required, both recorded in the append-only ledger).
  Future<void> _adjustStars(
    BuildContext context,
    WidgetRef ref,
    KidDayState state,
    Color color,
  ) async {
    final allowed = await ParentLock.requirePin(
      context,
      reason: 'برای اصلاح ستاره‌ها رمز والدین را وارد کنید',
    );
    if (!allowed || !context.mounted) return;

    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final t = TimeThemeKit.of(context).palette;
    var positive = true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.elevated,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: t.elevated,
            ),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SheetHandle(),
                Text(
                  'اصلاح ستاره‌های ${state.kid.name}',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('افزودن')),
                    ButtonSegment(value: false, label: Text('کاهش')),
                  ],
                  selected: {positive},
                  onSelectionChanged: (s) =>
                      setSheetState(() => positive = s.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'تعداد ستاره',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'دلیل (الزامی)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: color),
                  onPressed: () async {
                    final amount = int.tryParse(amountCtrl.text.trim());
                    final note = noteCtrl.text.trim();
                    // Both are required: a ledger row without a reason is
                    // exactly the unexplained number a parent later argues with.
                    if (amount == null || amount <= 0 || note.isEmpty) return;
                    final delta = positive ? amount : -amount;
                    // Never let a deduction push the balance below zero — the
                    // brief's "never negative via redemption" rule applies to
                    // manual corrections too.
                    final spendable = state.balance;
                    final safeDelta =
                        delta < 0 && -delta > spendable ? -spendable : delta;
                    if (safeDelta == 0) return;
                    await ref.read(kidsDaoProvider).adjustStars(
                          kidId: state.kid.id,
                          delta: safeDelta,
                          note: note,
                          dayKey: state.dayKey,
                        );
                    if (!sheetContext.mounted) return;
                    Navigator.of(sheetContext).pop();
                    ref.invalidate(kidDayProvider(state.kid.id));
                    ref.invalidate(kidsHomeProvider);
                  },
                  child: const Text('ثبت در دفتر'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Days of the week offered for a weekly schedule, Saturday-first.
  ///
  /// Bit 0 = شنبه … bit 6 = جمعه, matching [HabitSpec.weekdayMask].
  static const Map<String, int> _weekdayBits = {
    'ش': 1 << 0,
    'ی': 1 << 1,
    'د': 1 << 2,
    'س': 1 << 3,
    'چ': 1 << 4,
    'پ': 1 << 5,
    'ج': 1 << 6,
  };

  /// One icon offered in the add/edit habit picker.
  static const List<_HabitIcon> _habitIcons = [
    _HabitIcon('star', 'ستاره', Icons.star_rounded),
    _HabitIcon('book', 'کتاب', Icons.menu_book_rounded),
    _HabitIcon('brush', 'مسواک', Icons.brush_rounded),
    _HabitIcon('home', 'خانه', Icons.home_rounded),
    _HabitIcon('broom', 'پاکسازی', Icons.cleaning_services_rounded),
    _HabitIcon('heart', 'مهربانی', Icons.favorite_rounded),
    _HabitIcon('bag', 'کیف مدرسه', Icons.backpack_rounded),
    _HabitIcon('moon', 'خواب', Icons.nights_stay_rounded),
  ];

  /// Add a new habit for one child, behind the parent PIN gate.
  ///
  /// Phase 1 of the roadmap: the button is only shown when at least one child
  /// is registered. Phase 4: bundled templates pre-fill the form.
  Future<void> _addHabit(BuildContext context, WidgetRef ref) async {
    final allowed = await ParentLock.requirePin(
      context,
      reason: 'برای افزودن عادت رمز والدین را وارد کنید',
    );
    if (!allowed || !context.mounted) return;

    final children = ref.read(kidsHomeProvider).maybeWhen(
          data: (d) => d.children.toList(),
          orElse: () => const <KidRecord>[],
        );
    if (children.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ابتدا یک فرزند اضافه کنید')),
      );
      return;
    }

    // Load bundled templates for the template picker (phase 4).
    final templates = await ref.read(personal2TemplatesProvider.future);
    if (!context.mounted) return;

    String? kidId = children.first.id;
    final titleCtrl = TextEditingController();
    var stars = 2;
    var schedule = HabitSchedule.daily;
    var weekdayMask = 0x7F;
    var iconKey = 'star';
    String? templateKey;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TimeThemeKit.of(context).palette.elevated,
      builder: (sheetContext) {
        final t = TimeThemeKit.of(sheetContext).palette;
        final selectedKid = kidId == null
            ? children.first
            : children.firstWhere((c) => c.id == kidId);
        final color = KidColors.of(selectedKid.colorKey);

        return StatefulBuilder(
          builder: (sheetContext, setSheetState) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(color: t.elevated),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SheetHandle(),
                  Text(
                    'افزودن عادت',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 16),
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Child selector — only when more than one child exists.
                  if (children.length > 1) ...[
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        'برای کدام فرزند؟',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 12),
                          color: t.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in children)
                          FilterChip(
                            avatar: CircleAvatar(
                              radius: 10,
                              backgroundColor: KidColors.of(c.colorKey),
                              child: Text(
                                c.name.isNotEmpty ? c.name[0] : '',
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                            label: Text(c.name),
                            selected: kidId == c.id,
                            onSelected: (_) =>
                                setSheetState(() => kidId = c.id),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                  // Template picker (phase 4).
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      'قالب پیشنهادی (اختیاری)',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        color: t.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      FilterChip(
                        label: const Text('بدون قالب'),
                        selected: templateKey == null,
                        onSelected: (selected) {
                          if (selected) {
                            setSheetState(() {
                              templateKey = null;
                              titleCtrl.clear();
                              stars = 2;
                              iconKey = 'star';
                            });
                          }
                        },
                      ),
                      for (final tmpl in templates.habits)
                        FilterChip(
                          label: Text(tmpl.titleFa),
                          selected: templateKey == tmpl.key,
                          onSelected: (selected) {
                            if (selected) {
                              setSheetState(() {
                                templateKey = tmpl.key;
                                titleCtrl.text = tmpl.titleFa;
                                stars = tmpl.defaultStars;
                                iconKey = tmpl.iconKey;
                                schedule = HabitSchedule.daily;
                                weekdayMask = 0x7F;
                              });
                            }
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Title.
                  TextField(
                    controller: titleCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'عنوان عادتی',
                      hintText: 'مثلاً مسواک زدن',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Star value (1..5).
                  Row(
                    children: [
                      Text(
                        'ارزش (ستاره)',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 12),
                          color: t.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      for (final s in [1, 2, 3, 4, 5])
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: IconButton(
                            icon: Icon(
                              s <= stars ? Icons.star : Icons.star_border,
                              color: Personal2Colors.kidsStars,
                              size: 20,
                            ),
                            onPressed: () => setSheetState(() => stars = s),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Schedule.
                  SegmentedButton<HabitSchedule>(
                    segments: const [
                      ButtonSegment(
                        value: HabitSchedule.daily,
                        label: Text('هر روز'),
                        icon: Icon(Icons.repeat_rounded),
                      ),
                      ButtonSegment(
                        value: HabitSchedule.weekdays,
                        label: Text('روزهای مشخص'),
                        icon: Icon(Icons.calendar_today_rounded),
                      ),
                      ButtonSegment(
                        value: HabitSchedule.oneTime,
                        label: Text('یک‌باره'),
                        icon: Icon(Icons.event_rounded),
                      ),
                    ],
                    selected: {schedule},
                    onSelectionChanged: (s) =>
                        setSheetState(() => schedule = s.first),
                  ),
                  if (schedule == HabitSchedule.weekdays) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        'روزهای هفته',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 12),
                          color: t.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final entry in _weekdayBits.entries)
                          FilterChip(
                            label: Text(entry.key),
                            selected: (weekdayMask & entry.value) != 0,
                            onSelected: (selected) => setSheetState(() {
                              if (selected) {
                                weekdayMask |= entry.value;
                              } else {
                                weekdayMask &= ~entry.value;
                              }
                            }),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Icon.
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      'آیکون',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        color: t.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final choice in _habitIcons)
                        GestureDetector(
                          onTap: () =>
                              setSheetState(() => iconKey = choice.key),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: iconKey == choice.key
                                  ? color.withValues(alpha: 0.18)
                                  : t.surfaceMuted,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: iconKey == choice.key
                                    ? color
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Icon(choice.icon,
                                size: 20,
                                color: iconKey == choice.key
                                    ? color
                                    : t.textSecondary),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(false),
                          child: const Text('لغو'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            final title = titleCtrl.text.trim();
                            if (title.isEmpty || kidId == null) return;
                            Navigator.of(sheetContext).pop(true);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: color,
                          ),
                          child: const Text('اضافه کردن'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!context.mounted) return;
    if (confirmed != true || kidId == null) return;

    final title = titleCtrl.text.trim();
    if (title.isEmpty) return;

    final id = 'habit_${DateTime.now().microsecondsSinceEpoch}';
    final ok = await ref.read(kidsDaoProvider).saveHabit(
          id: id,
          kidId: kidId!,
          title: title,
          stars: stars,
          schedule: schedule,
          weekdayMask: weekdayMask,
          iconKey: iconKey,
          templateKey: templateKey,
        );

    if (!ok || !context.mounted) return;
    ref.invalidate(kidDayProvider(kidId!));
    ref.invalidate(kidsHomeProvider);
  }

  /// Edit an existing habit, pre-filled from [habit]. Phase 2 of the roadmap.
  Future<void> _editHabit(
    BuildContext context,
    WidgetRef ref,
    String kidId,
    HabitSpec habit,
  ) async {
    final allowed = await ParentLock.requirePin(
      context,
      reason: 'برای ویرایش عادتی رمز والدین را وارد کنید',
    );
    if (!allowed || !context.mounted) return;

    final children = ref.read(kidsHomeProvider).maybeWhen(
          data: (d) => d.children.toList(),
          orElse: () => const <KidRecord>[],
        );
    final templates = await ref.read(personal2TemplatesProvider.future);
    if (!context.mounted) return;

    final titleCtrl = TextEditingController(text: habit.title);
    var stars = habit.stars;
    var schedule = habit.schedule;
    var weekdayMask = habit.weekdayMask;
    var iconKey = habit.iconKey;
    final templateKey = habit.templateKey;

    // Resolve template label for display.
    String? templateLabel;
    if (habit.templateKey != null) {
      for (final tmpl in templates.habits) {
        if (tmpl.key == habit.templateKey) {
          templateLabel = tmpl.titleFa;
          break;
        }
      }
    }

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TimeThemeKit.of(context).palette.elevated,
      builder: (sheetContext) {
        final t = TimeThemeKit.of(sheetContext).palette;
        final sourceChild = children.firstWhere((c) => c.id == kidId);
        final color = KidColors.of(sourceChild.colorKey);

        return StatefulBuilder(
          builder: (sheetContext, setSheetState) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(color: t.elevated),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SheetHandle(),
                  Text(
                    'ویرایش عادتی',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 16),
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Template info (phase 4).
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      'قالب: ${templateLabel ?? 'بدون قالب'}',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        color: t.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Title.
                  TextField(
                    controller: titleCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'عنوان عادتی',
                      hintText: 'مثلاً مسواک زدن',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Star value (1..5).
                  Row(
                    children: [
                      Text(
                        'ارزش (ستاره)',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 12),
                          color: t.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      for (final s in [1, 2, 3, 4, 5])
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: IconButton(
                            icon: Icon(
                              s <= stars ? Icons.star : Icons.star_border,
                              color: Personal2Colors.kidsStars,
                              size: 20,
                            ),
                            onPressed: () => setSheetState(() => stars = s),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Schedule.
                  SegmentedButton<HabitSchedule>(
                    segments: const [
                      ButtonSegment(
                        value: HabitSchedule.daily,
                        label: Text('هر روز'),
                        icon: Icon(Icons.repeat_rounded),
                      ),
                      ButtonSegment(
                        value: HabitSchedule.weekdays,
                        label: Text('روزهای مشخص'),
                        icon: Icon(Icons.calendar_today_rounded),
                      ),
                      ButtonSegment(
                        value: HabitSchedule.oneTime,
                        label: Text('یک‌باره'),
                        icon: Icon(Icons.event_rounded),
                      ),
                    ],
                    selected: {schedule},
                    onSelectionChanged: (s) =>
                        setSheetState(() => schedule = s.first),
                  ),
                  if (schedule == HabitSchedule.weekdays) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        'روزهای هفته',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 12),
                          color: t.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final entry in _weekdayBits.entries)
                          FilterChip(
                            label: Text(entry.key),
                            selected: (weekdayMask & entry.value) != 0,
                            onSelected: (selected) => setSheetState(() {
                              if (selected) {
                                weekdayMask |= entry.value;
                              } else {
                                weekdayMask &= ~entry.value;
                              }
                            }),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Icon.
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      'آیکون',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        color: t.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final choice in _habitIcons)
                        GestureDetector(
                          onTap: () =>
                              setSheetState(() => iconKey = choice.key),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: iconKey == choice.key
                                  ? color.withValues(alpha: 0.18)
                                  : t.surfaceMuted,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: iconKey == choice.key
                                    ? color
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Icon(choice.icon,
                                size: 20,
                                color: iconKey == choice.key
                                    ? color
                                    : t.textSecondary),
                          ),
                        ),
                    ],
                  ),
                  // ویرایش فقط برای همین فرزند اعمال می‌شود. برای کپی به سایر
                  // فرزندان از دکمهٔ کپی در ردیف عادت استفاده کنید.
                  if (children.length > 1) ...[
                    const SizedBox(height: 14),
                    Text(
                      'این تغییر فقط برای ${sourceChild.name} اعمال '
                      'می‌شود.',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 11),
                        color: Colors.black54,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(false),
                          child: const Text('لغو'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            final title = titleCtrl.text.trim();
                            if (title.isEmpty) return;
                            Navigator.of(sheetContext).pop(true);
                          },
                          style: FilledButton.styleFrom(backgroundColor: color),
                          child: const Text('ذخیره تغییرات'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!context.mounted) return;
    if (confirmed != true) return;

    final title = titleCtrl.text.trim();
    if (title.isEmpty) return;

    // Editing is scoped to the child whose habit was tapped. The helper is the
    // single source of truth for the edit target; `.single` fails fast if the
    // scoping ever regresses (e.g. an edit silently fans out to siblings again).
    final targetKidId = habitEditTargetKidIds(
      kidId,
      children.map((c) => c.id).toList(),
    ).single;

    // ویرایش فقط برای همین فرزند ثبت می‌شود؛ هرگز به سایر فرزندان
    // کپی نمی‌شود (کپی به همه در دکمهٔ مخصوص ردیف عادت است).
    final ok = await ref.read(kidsDaoProvider).saveHabit(
          id: habit.id,
          kidId: targetKidId,
          title: title,
          stars: stars,
          schedule: schedule,
          weekdayMask: weekdayMask,
          iconKey: iconKey,
          templateKey: templateKey,
        );

    if (!ok || !context.mounted) return;
    ref.invalidate(kidDayProvider(targetKidId));
    ref.invalidate(kidsHomeProvider);
  }

  /// Soft-delete or restore a habit behind the parent PIN gate. Phase 3 of
  /// the roadmap.
  ///
  /// Soft delete keeps the habit's logs and star history — only `active` is
  /// flipped to 0 — so nothing a parent or child already earned is lost.
  Future<void> _toggleHabit(
    BuildContext context,
    WidgetRef ref,
    String kidId,
    HabitSpec habit,
  ) async {
    final allowed = await ParentLock.requirePin(
      context,
      reason: habit.active
          ? 'برای غیرفعال کردن عادتی رمز والدین را وارد کنید'
          : 'برای فعال کردن عادتی رمز والدین را وارد کنید',
    );
    if (!allowed || !context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          habit.active ? 'غیرفعال کردن عادتی' : 'فعال کردن عادتی',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 16),
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          habit.active
              ? 'عادتی «${habit.title}» غیرفعال می‌شود و در لیست عادتهای '
                  'امروز نشان داده نمی‌شود. تاریخچه ستاره‌هایش باقی می‌ماند.'
              : 'عادتی «${habit.title}» دوباره فعال می‌شود و در لیست عادتهای '
                  'امروز نمایش داده می‌شود.',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('لغو'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: habit.active ? AppTheme.error : AppTheme.success,
            ),
            child: Text(habit.active ? 'غیرفعال شود' : 'فعال شود'),
          ),
        ],
      ),
    );

    if (!context.mounted) return;
    if (confirmed != true) return;

    final ok = await ref.read(kidsDaoProvider).setHabitActive(
          habit.id,
          !habit.active,
        );

    if (!ok || !context.mounted) return;
    ref.invalidate(kidDayProvider(kidId));
    ref.invalidate(kidsHomeProvider);
  }

  /// Copy a habit to all other children. Phase 7 of the roadmap.
  ///
  /// Creates a new habit row per other child with the same title/stars/schedule
  /// so each child tracks their own completion independently.
  Future<void> _copyHabitToAllChildren(
    BuildContext context,
    WidgetRef ref,
    KidRecord sourceChild,
    HabitSpec habit,
  ) async {
    final allowed = await ParentLock.requirePin(
      context,
      reason: 'برای کپی کردن عادتی به همه فرزندان رمز والدین را وارد کنید',
    );
    if (!allowed || !context.mounted) return;

    final children = ref.read(kidsHomeProvider).maybeWhen(
          data: (d) => d.children.toList(),
          orElse: () => const <KidRecord>[],
        );
    final otherChildren =
        children.where((c) => c.id != sourceChild.id).toList();
    if (otherChildren.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فرزند دیگری برای کپی وجود ندارد')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'کپی عادتی به همه فرزندان',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 16),
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'عادتی «${habit.title}» برای ${otherChildren.length} فرزند دیگر '
          'کپی شود؟ هر فرزند وضعیت جداگانه‌ای دارد.',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('لغو'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('کپی شود'),
          ),
        ],
      ),
    );

    if (!context.mounted) return;
    if (confirmed != true) return;

    var allOk = true;
    for (final c in otherChildren) {
      final id =
          'habit_${DateTime.now().microsecondsSinceEpoch}_${c.id.hashCode}';
      final ok = await ref.read(kidsDaoProvider).saveHabit(
            id: id,
            kidId: c.id,
            title: habit.title,
            stars: habit.stars,
            schedule: habit.schedule,
            weekdayMask: habit.weekdayMask,
            iconKey: habit.iconKey,
            templateKey: habit.templateKey,
          );
      if (!ok) allOk = false;
    }

    if (!allOk || !context.mounted) return;
    for (final c in otherChildren) {
      ref.invalidate(kidDayProvider(c.id));
    }
    ref.invalidate(kidsHomeProvider);
  }
}


/// «باغ عادت» — each habit is a plant whose height follows the week's
/// completion ratio; finishing it today opens a small flower.
class _HabitPlant extends StatelessWidget {
  const _HabitPlant({
    required this.growth,
    required this.bloomed,
    required this.color,
    required this.outline,
  });

  final double growth;
  final bool bloomed;
  final Color color;
  final Color outline;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 32,
        height: 32,
        child: CustomPaint(
          painter: _PlantPainter(
            growth: growth.isFinite ? growth.clamp(0.0, 1.0) : 0.0,
            bloomed: bloomed,
            color: color,
            outline: outline,
          ),
        ),
      );
}

class _PlantPainter extends CustomPainter {
  const _PlantPainter({
    required this.growth,
    required this.bloomed,
    required this.color,
    required this.outline,
  });

  final double growth;
  final bool bloomed;
  final Color color;
  final Color outline;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;
    final soil = h * .76;
    final leafInk = Paint()..color = color.withValues(alpha: .85);

    final pot = RRect.fromLTRBR(
      w * .26,
      soil,
      w * .74,
      h * .96,
      const Radius.circular(3),
    );
    canvas.drawRRect(pot, Paint()..color = color.withValues(alpha: .18));
    canvas.drawRRect(
      pot,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Even a zero-week habit keeps a tiny sprout.
    final top = soil - h * (.12 + .52 * growth);
    canvas.drawLine(
      Offset(w * .5, soil),
      Offset(w * .5, top),
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    final leaf = w * (.09 + .07 * growth);
    final mid = soil - (soil - top) * .55;
    canvas.drawOval(
      Rect.fromLTRB(w * .5 - leaf * 2, mid - leaf, w * .5, mid + leaf),
      leafInk,
    );
    final upper = soil - (soil - top) * .82;
    canvas.drawOval(
      Rect.fromLTRB(w * .5, upper - leaf, w * .5 + leaf * 2, upper + leaf),
      leafInk,
    );

    if (bloomed) {
      final petal = w * .075;
      const petals = <Offset>[
        Offset(-1, 0),
        Offset(1, 0),
        Offset(0, -1),
        Offset(0, 1),
      ];
      for (final offset in petals) {
        canvas.drawCircle(
          Offset(w * .5 + offset.dx * petal, top + offset.dy * petal),
          petal,
          Paint()..color = color.withValues(alpha: .55),
        );
      }
      canvas.drawCircle(Offset(w * .5, top), petal * .8, Paint()..color = color);
    } else {
      canvas.drawCircle(
        Offset(w * .5, top),
        w * .055,
        Paint()..color = color.withValues(alpha: .55),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PlantPainter old) =>
      old.growth != growth || old.bloomed != bloomed || old.color != color;
}

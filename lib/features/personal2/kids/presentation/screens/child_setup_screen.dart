import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal2/kids/data/kids_dao.dart';
import 'package:tawheeed/features/personal2/kids/domain/kid_logic.dart';
import 'package:tawheeed/features/personal2/kids/presentation/providers/kids_providers.dart';
import 'package:tawheeed/features/personal2/shared/personal2_style.dart';
import 'package:tawheeed/features/personal2/shared/template_store.dart';
import 'package:tawheeed/features/personal2/shared/parent_lock.dart';
import 'package:tawheeed/shared/widgets/app_empty_state.dart';

/// «تنظیمات کودک» — name, colour, habits (from templates), schedules and the
/// prayer configuration. The brief's child-setup screen, plus the habit list
/// that the parent edits later.
class ChildSetupScreen extends ConsumerStatefulWidget {
  const ChildSetupScreen({super.key, required this.kidId});

  final String kidId;

  @override
  ConsumerState<ChildSetupScreen> createState() => _ChildSetupScreenState();
}

class _ChildSetupScreenState extends ConsumerState<ChildSetupScreen> {
  @override
  Widget build(BuildContext context) {
    final day = ref.watch(kidDayProvider(widget.kidId));
    final templates = ref.watch(personal2TemplatesProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: SectionAppBar(
          title: 'تنظیمات کودک',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'بازگشت',
            onPressed: () => context.pop(),
          ),
        ),
        body: SafeArea(
          child: day.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => FailureView(
              id: 'child_setup_load',
              title: 'تنظیمات این فرزند باز نشد',
              detail: 'تنظیمات ذخیره‌شده پاک نشده‌اند؛ فقط خواندنشان ناموفق '
                  'بود.',
              onRetry: () => ref.invalidate(kidDayProvider(widget.kidId)),
              layout: FailureLayout.page,
              error: e,
            ),
            data: (state) => state == null
                ? const AppEmptyState(
                    icon: Icons.person_off_outlined,
                    message: 'این فرزند پیدا نشد',
                    subtitle: 'ممکن است از دفتر کودک حذف شده باشد.',
                  )
                : _body(context, state, templates.value),
          ),
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    KidDayState state,
    Personal2Templates? templates,
  ) {
    final t = TimeThemeKit.of(context).palette;
    final color = KidColors.of(state.kid.colorKey);

    return ListView(
      padding: const EdgeInsets.fromLTRB(DsSpacing.page, 12, DsSpacing.page, 40),
      children: [
        AppCard(
          child: Row(
            children: [
              DuotoneIconTile(
                accent: color,
                icon: Icons.child_care_rounded,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.kid.name,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${state.scheduled.length} عادت · '
                      '${state.prayerConfig.enabled.length} نماز',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11,
                        color: t.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _editChild(context, ref, state),
                child: const Text('ویرایش'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionHeader(title: 'عادت‌های این کودک', accent: color),
        const SizedBox(height: 8),
        if (state.habits.isEmpty)
          AppCard(
            child: Text(
              'هنوز عادتی انتخاب نشده. از فهرست پیشنهادی یکی را اضافه کنید.',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                color: t.textSecondary,
              ),
            ),
          )
        else
          for (final habit in state.habits)
            _habitRow(context, ref, state, habit, color),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: templates == null
              ? null
              : () => _addHabits(context, ref, state, templates),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('افزودن از پیشنهادها'),
        ),
        const SizedBox(height: 18),
        SectionHeader(title: 'نماز', accent: color),
        const SizedBox(height: 8),
        _prayerCard(context, ref, state, color),
      ],
    );
  }

  Widget _habitRow(
    BuildContext context,
    WidgetRef ref,
    KidDayState state,
    HabitSpec habit,
    Color color,
  ) {
    final t = TimeThemeKit.of(context).palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            DuotoneIconTile(
              accent: color,
              icon: KidIcons.of(habit.iconKey),
              size: 32,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.title,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: t.textPrimary,
                    ),
                  ),
                  Text(
                    _scheduleLabel(habit),
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 10,
                      color: t.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${habit.stars} ★',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 11,
                color: t.textSecondary,
              ),
            ),
            Switch(
              value: habit.active,
              onChanged: (v) async {
                await ref
                    .read(kidsDaoProvider)
                    .setHabitActive(habit.id, v);
                ref.invalidate(kidDayProvider(widget.kidId));
                ref.invalidate(kidsHomeProvider);
              },
            ),
          ],
        ),
      ),
    );
  }

  static String _scheduleLabel(HabitSpec habit) {
    switch (habit.schedule) {
      case HabitSchedule.daily:
        return 'هر روز';
      case HabitSchedule.oneTime:
        return 'یک‌بار';
      case HabitSchedule.weekdays:
        const letters = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];
        final days = [
          for (var i = 0; i < 7; i++)
            if ((habit.weekdayMask & (1 << i)) != 0) letters[i],
        ];
        return days.length == 7 ? 'هر روز' : days.join('، ');
    }
  }

  Widget _prayerCard(
    BuildContext context,
    WidgetRef ref,
    KidDayState state,
    Color color,
  ) {
    final t = TimeThemeKit.of(context).palette;
    final cfg = state.prayerConfig;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final prayer in KidPrayer.values)
            SwitchListTile.adaptive(
              dense: true,
              contentPadding: EdgeInsets.zero,
              activeThumbColor: color,
              title: Text(
                prayer.titleFa,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  color: t.textPrimary,
                ),
              ),
              value: cfg.enabled.contains(prayer),
              onChanged: (v) => _savePrayer(
                ref,
                state,
                enabled: v
                    ? {...cfg.enabled, prayer}
                    : ({...cfg.enabled}..remove(prayer)),
              ),
            ),
          const Divider(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  'ستارهٔ هر نماز',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    color: t.textSecondary,
                  ),
                ),
              ),
              _starsStepper(
                value: cfg.starsPerPrayer,
                onChanged: (v) => _savePrayer(ref, state, starsPerPrayer: v),
              ),
            ],
          ),
          SwitchListTile.adaptive(
            dense: true,
            contentPadding: EdgeInsets.zero,
            activeThumbColor: color,
            title: Text(
              'ثبت بعد از وقت هم پذیرفته شود',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                color: t.textPrimary,
              ),
            ),
            value: cfg.lateAllowed,
            onChanged: (v) => _savePrayer(ref, state, lateAllowed: v),
          ),
          if (cfg.lateAllowed)
            Text(
              'ثبت بعد از وقت ${(cfg.lateFactor * 100).round()}٪ ستاره می‌گیرد.',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 10,
                color: t.textMuted,
              ),
            ),
          SwitchListTile.adaptive(
            dense: true,
            contentPadding: EdgeInsets.zero,
            activeThumbColor: color,
            title: Text(
              'نیاز به تأیید والدین',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                color: t.textPrimary,
              ),
            ),
            value: cfg.requiresApproval,
            onChanged: (v) => _savePrayer(ref, state, requiresApproval: v),
          ),
          const SizedBox(height: 4),
          Text(
            'این ابزار زمان نماز را از برنامه می‌خواند و هیچ حکم شرعی‌ای صادر '
            'نمی‌کند؛ ثبت، گزارش خود کودک است.',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 10,
              height: 1.7,
              color: t.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _starsStepper({required int value, required ValueChanged<int> onChanged}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove_circle_outline, size: 20),
          onPressed: value > 1 ? () => onChanged(value - 1) : null,
        ),
        Text('$value', style: TextStyle(fontFamily: AppTheme.fontFamily)),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add_circle_outline, size: 20),
          onPressed: value < 5 ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }

  Future<void> _savePrayer(
    WidgetRef ref,
    KidDayState state, {
    Set<KidPrayer>? enabled,
    int? starsPerPrayer,
    bool? lateAllowed,
    bool? requiresApproval,
  }) async {
    final cfg = state.prayerConfig;
    await ref.read(kidsDaoProvider).savePrayerConfig(
          kidId: state.kid.id,
          enabled: enabled ?? cfg.enabled,
          starsPerPrayer: starsPerPrayer ?? cfg.starsPerPrayer,
          lateAllowed: lateAllowed ?? cfg.lateAllowed,
          lateFactor: cfg.lateFactor,
          requiresApproval: requiresApproval ?? cfg.requiresApproval,
        );
    ref.invalidate(kidDayProvider(widget.kidId));
    ref.invalidate(kidsHomeProvider);
  }

  /// The habit picker: templates as multi-select with a star stepper each.
  Future<void> _addHabits(
    BuildContext context,
    WidgetRef ref,
    KidDayState state,
    Personal2Templates templates,
  ) async {
    final chosen = <String>{};
    final stars = <String, int>{
      for (final h in templates.habits) h.key: h.defaultStars,
    };
    final t = TimeThemeKit.of(context).palette;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.elevated,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Container(
          height: MediaQuery.of(sheetContext).size.height * .78,
          decoration: BoxDecoration(
            color: t.elevated,
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              const SheetHandle(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'انتخاب عادت',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: t.textPrimary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final dao = ref.read(kidsDaoProvider);
                        var sort = state.habits.length;
                        for (final key in chosen) {
                          final tpl = templates.habits.firstWhere((h) => h.key == key);
                          await dao.saveHabit(
                            id: 'hab_${state.kid.id}_${tpl.key}',
                            kidId: state.kid.id,
                            title: tpl.titleFa,
                            stars: stars[tpl.key] ?? tpl.defaultStars,
                            schedule: HabitSchedule.daily,
                            iconKey: tpl.iconKey,
                            templateKey: tpl.key,
                            sort: sort++,
                          );
                        }
                        if (!sheetContext.mounted) return;
                        Navigator.of(sheetContext).pop();
                        ref.invalidate(kidDayProvider(widget.kidId));
                        ref.invalidate(kidsHomeProvider);
                      },
                      child: const Text('افزودن'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
                  itemCount: templates.habits.length,
                  itemBuilder: (context, i) {
                    final tpl = templates.habits[i];
                    final selected = chosen.contains(tpl.key);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: AppCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        borderColor:
                            selected ? KidColors.of(state.kid.colorKey) : null,
                        onTap: () => setSheetState(() {
                          if (selected) {
                            chosen.remove(tpl.key);
                          } else {
                            chosen.add(tpl.key);
                          }
                        }),
                        child: Row(
                          children: [
                            Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
                              size: 20,
                              color: selected
                                  ? KidColors.of(state.kid.colorKey)
                                  : t.textMuted,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                tpl.titleFa,
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 13,
                                  color: t.textPrimary,
                                ),
                              ),
                            ),
                            if (selected)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(
                                        Icons.remove_circle_outline,
                                        size: 18),
                                    onPressed: () => setSheetState(() {
                                      final v = stars[tpl.key] ?? 1;
                                      if (v > 1) stars[tpl.key] = v - 1;
                                    }),
                                  ),
                                  Text('${stars[tpl.key]}'),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.add_circle_outline,
                                        size: 18),
                                    onPressed: () => setSheetState(() {
                                      final v = stars[tpl.key] ?? 1;
                                      if (v < 5) stars[tpl.key] = v + 1;
                                    }),
                                  ),
                                ],
                              )
                            else
                              Text(
                                '${tpl.defaultStars} ★',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 11,
                                  color: t.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editChild(
    BuildContext context,
    WidgetRef ref,
    KidDayState state,
  ) async {
    final nameCtrl = TextEditingController(text: state.kid.name);
    final yearCtrl = TextEditingController(
      text: state.kid.birthYear?.toString() ?? '',
    );
    var colorKey = state.kid.colorKey;
    final t = TimeThemeKit.of(context).palette;

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
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'نام',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: yearCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: const InputDecoration(
                    labelText: 'سال تولد (اختیاری)',
                    counterText: '',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final key in KidColors.keys)
                      GestureDetector(
                        onTap: () => setSheetState(() => colorKey = key),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: KidColors.of(key),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorKey == key
                                  ? t.textPrimary
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () => _confirmArchive(sheetContext, ref, state),
                    icon: const Icon(Icons.archive_outlined, size: 16),
                    label: Text(
                      'بایگانی کودک (داده‌ها میمانند)',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          await ref.read(kidsDaoProvider).upsertKid(
                                id: state.kid.id,
                                name: nameCtrl.text.trim(),
                                birthYear: int.tryParse(yearCtrl.text.trim()),
                                colorKey: colorKey,
                              );
                          if (!sheetContext.mounted) return;
                          Navigator.of(sheetContext).pop();
                          ref.invalidate(kidDayProvider(widget.kidId));
                          ref.invalidate(kidsHomeProvider);
                        },
                        child: const Text('ذخیره'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _confirmDelete(sheetContext, ref, state),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: DsStatus.danger(context),
                        ),
                        child: const Text('حذف همهٔ داده‌ها'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Non-destructive removal: the child disappears from the home list but
  /// their star history is kept, which is the default the DAO already models.
  /// Reversible only by a parent who knows the PIN, so a child cannot hide a
  /// sibling's record on a whim.
  Future<void> _confirmArchive(
    BuildContext context,
    WidgetRef ref,
    KidDayState state,
  ) async {
    final allowed = await ParentLock.requirePin(
      context,
      reason: 'برای بایگانی کودک رمز والدین را وارد کنید',
    );
    if (!allowed) return;
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('بایگانی این کودک؟'),
        content: Text(
          '${state.kid.name} از فهرست فرزندان پنهان می‌شود، ولی عادت‌ها، '
          'ستاره‌ها و گزارش‌ها پاک نمی‌شوند.',
          style: TextStyle(fontFamily: AppTheme.fontFamily, height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('بایگانی'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await ref.read(kidsDaoProvider).archiveKid(state.kid.id);
    if (!ok) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('بایگانی انجام نشد؛ دوباره تلاش کنید.')),
        );
      }
      return;
    }
    ref.invalidate(kidsHomeProvider);
    ref.invalidate(kidsHouseholdStreakProvider);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    if (context.mounted) context.pop();
  }

  /// The brief's hard requirement: a per-child «delete everything», with an
  /// explicit confirmation that says exactly what disappears.
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    KidDayState state,
  ) async {
    // Destructive and irreversible: prove the parent with the PIN before
    // even showing the confirm dialog. A child who reaches this screen must
    // not be able to wipe a sibling's entire history without the PIN.
    final allowed = await ParentLock.requirePin(
      context,
      reason: 'برای حذف همهٔ داده‌های کودک رمز والدین را وارد کنید',
    );
    if (!allowed) return;
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف همهٔ داده‌های این کودک؟'),
        content: Text(
          'نام، عادت‌ها، ستاره‌ها، جایزه‌ها و گزارش‌های ${state.kid.name} برای '
          'همیشه پاک می‌شود. این کار برگشت‌پذیر نیست.',
          style: TextStyle(fontFamily: AppTheme.fontFamily, height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: DsStatus.danger(dialogContext),
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(kidsDaoProvider).deleteEverythingForKid(state.kid.id);
    ref.invalidate(kidsHomeProvider);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    if (context.mounted) context.pop();
  }
}

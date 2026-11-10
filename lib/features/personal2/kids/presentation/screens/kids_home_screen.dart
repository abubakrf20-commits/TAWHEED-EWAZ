import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal2/kids/data/kids_dao.dart';
import 'package:tawheeed/features/personal2/kids/presentation/providers/kids_providers.dart';
import 'package:tawheeed/features/personal2/shared/mini_charts.dart';
import 'package:tawheeed/features/personal2/shared/parent_lock.dart';
import 'package:tawheeed/features/personal2/shared/personal2_style.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/shared/widgets/app_empty_state.dart';
import 'package:tawheeed/shared/widgets/latin_time_picker.dart';

/// «دفتر عادت کودک» — the parent's home for the kids tool.
///
/// Structure from the brief: a flat summary card, the children list, and three
/// shortcuts. No hub page and no Home-tab entry: this is reached from the
/// personal tools section, and it lives on the same route family.
class KidsHomeScreen extends ConsumerWidget {
  const KidsHomeScreen({super.key});

  static const Color accent = Personal2Colors.kids;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(kidsHomeProvider);
    // Side-effect provider: keeps the evening nudges scheduled for the next
    // week and rewrites tonight's text when the day's counts change.
    ref.watch(kidEveningSyncProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: SectionAppBar(
          title: 'دفتر عادت کودک',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'بازگشت',
            onPressed: () => context.pop(),
          ),
          actions: [
            IconButton(
              tooltip: 'قفل والدین',
              icon: const Icon(Icons.lock_outline),
              onPressed: () => _openLockSheet(context, ref),
            ),
            IconButton(
              tooltip: 'یادآورها',
              icon: const Icon(Icons.notifications_none_rounded),
              onPressed: () => showKidReminderSheet(context, ref),
            ),
            IconButton(
              tooltip: 'افزودن فرزند',
              icon: const Icon(Icons.add),
              onPressed: () => _addChild(context, ref),
            ),
          ],
        ),
        body: SafeArea(
          child: home.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => FailureView(
              id: 'kids_home_load',
              title: 'دفتر کودک باز نشد',
              detail: 'دفترها، ستاره‌ها و کارهای ثبت‌شده پاک نشده‌اند؛ فقط '
                  'خواندنشان ناموفق بود.',
              onRetry: () => ref.invalidate(kidsHomeProvider),
              layout: FailureLayout.page,
              error: e,
            ),
            data: (data) => data.children.isEmpty
                ? _empty(context, ref)
                : _content(context, ref, data),
          ),
        ),
      ),
    );
  }

  Widget _empty(BuildContext context, WidgetRef ref) {
    final t = TimeThemeKit.of(context).palette;
    return ListView(
      padding: const EdgeInsets.fromLTRB(DsSpacing.page, 20, DsSpacing.page, 40),
      children: [
        AppEmptyState(
          icon: Icons.child_care_rounded,
          accent: accent,
          message: 'هنوز فرزندی اضافه نشده',
          subtitle: 'برای شروع یک فرزند اضافه کنید و عادت‌هایش را انتخاب کنید.',
          actionLabel: 'افزودن فرزند',
          onAction: () => _addChild(context, ref),
        ),
        const SizedBox(height: 16),
        Text(
          'همهٔ داده‌ها فقط روی همین دستگاه می‌ماند؛ هیچ عکسی از کودک ذخیره '
          'نمی‌شود و این بخش به اینترنت دسترسی ندارد.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 12,
            height: 1.7,
            color: t.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _content(BuildContext context, WidgetRef ref, KidsHomeState data) {
    final t = TimeThemeKit.of(context).palette;
    final (done, total) = data.householdHabits;
    final (pDone, pTotal) = data.householdPrayers;
    final streak = ref.watch(kidsHouseholdStreakProvider).value ?? 0;

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(kidsHomeProvider),
      child: ListView(
        // The brief's performance rule: lazy lists only. This is a ListView
        // builder with a handful of children today, but a family of six must
        // not build every card up front.
        padding: const EdgeInsets.fromLTRB(DsSpacing.page, 12, DsSpacing.page, 40),
        children: [
          _heroCard(context, done, total, pDone, pTotal, streak),
          if (data.approvalCount > 0) ...[
            const SizedBox(height: 10),
            _approvalCard(context, ref, data),
          ],
          const SizedBox(height: 16),
          const SectionHeader(title: 'فرزندان', accent: accent),
          const SizedBox(height: 8),
          for (final child in data.children)
            _childCard(context, ref, child, data),
          const SizedBox(height: 16),
          _shortcuts(context, ref),
          const SizedBox(height: 14),
          Text(
            'داده‌ها روی همین دستگاه می‌مانند · بدون شبکه · بدون عکس کودک',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11,
              color: t.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  /// The flat hero (solid dark band, no gradient — the brief bans gradients in
  /// these tools even though the vault header uses one).
  Widget _heroCard(BuildContext context, int done, int total, int pDone, int pTotal,
      int streak) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dsContentColor(context, accent),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'امروز در خانه',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              color: Colors.white.withValues(alpha: .85),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$done از $total عادت',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 22),
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          // A Wrap, not a Row: at 320 dp with large text the two chips need
          // more width than the card has, and a Row can only overflow there.
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _heroChip(Icons.mosque_rounded, 'نماز $pDone از $pTotal'),
              _heroChip(Icons.star_rounded, '${done * 2} ستارهٔ امروز'),
              if (streak > 0)
                _heroChip(
                  Icons.local_fire_department_rounded,
                  'رشتهٔ ${NumberFormat.ltrIsolated('$streak')} روزه',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 11,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _approvalCard(BuildContext context, WidgetRef ref, KidsHomeState data) {
    final t = TimeThemeKit.of(context).palette;
    final warning = DsStatus.warning(context);
    return AppCard(
      borderColor: warning.withValues(alpha: .45),
      child: Row(
        children: [
          Icon(Icons.pending_actions_rounded, color: warning, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${data.approvalCount} مورد منتظر تأیید شماست',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: t.textPrimary,
              ),
            ),
          ),
          FilledButton.tonal(
            onPressed: () => _openApprovals(context),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: const Text('بررسی'),
          ),
        ],
      ),
    );
  }

  Widget _childCard(
    BuildContext context,
    WidgetRef ref,
    KidRecord child,
    KidsHomeState data,
  ) {
    final t = TimeThemeKit.of(context).palette;
    final color = KidColors.of(child.colorKey);
    final totals = data.todayTotals[child.id] ?? (0, 0, 0, 0);
    final (hDone, hTotal, pDone, pTotal) = totals;
    final ratio = (hTotal + pTotal) == 0
        ? 0.0
        : (hDone + pDone) / (hTotal + pTotal);
    final age = child.ageAt(data.now);

    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.gap),
      child: AppCard(
        borderColor: color.withValues(alpha: .30),
        child: Column(
          children: [
            Row(
              children: [
                MiniRing(
                  progress: ratio,
                  color: color,
                  semanticLabel: 'پیشرفت امروز ${child.name}',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        child.name,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: t.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          if (age != null) '$age ساله',
                          '$hDone از $hTotal عادت',
                          'نماز $pDone از $pTotal',
                        ].join(' · '),
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11,
                          color: t.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => context.push(
                      RouteNames.kidsChildMode,
                      extra: child.id,
                    ),
                    style: FilledButton.styleFrom(backgroundColor: color),
                    icon: const Icon(Icons.emoji_emotions_rounded, size: 18),
                    label: const Text('حالت کودک'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'تنظیمات کودک',
                  onPressed: () => context.push(
                    RouteNames.kidsChildSetup,
                    extra: child.id,
                  ),
                  icon: const Icon(Icons.tune_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _shortcuts(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: _shortcut(
            context,
            Icons.checklist_rounded,
            'عادت‌ها',
            () => context.push(RouteNames.kidsHabits),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _shortcut(
            context,
            Icons.card_giftcard_rounded,
            'جایزه‌ها',
            () => context.push(RouteNames.kidsRewards),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _shortcut(
            context,
            Icons.insights_rounded,
            'گزارش',
            () => context.push(RouteNames.kidsReport),
          ),
        ),
      ],
    );
  }

  Widget _shortcut(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    final t = TimeThemeKit.of(context).palette;
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 12),
      onTap: onTap,
      child: Column(
        children: [
          DuotoneIconTile(accent: accent, icon: icon, size: 34),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: t.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────

  Future<void> _addChild(BuildContext context, WidgetRef ref) async {
    final id = await showAddChildSheet(context, ref);
    if (id == null) return;
    ref.invalidate(kidsHomeProvider);
    if (!context.mounted) return;
    context.push(RouteNames.kidsChildSetup, extra: id);
  }

  Future<void> _openApprovals(BuildContext context) async {
    // Approvals are a parent action, so they go through the PIN gate. With no
    // PIN configured the call resolves true immediately (nothing to protect).
    final allowed = await ParentLock.requirePin(
      context,
      reason: 'برای تأیید کارها رمز والدین را وارد کنید',
    );
    if (!allowed || !context.mounted) return;
    context.push(RouteNames.kidsApprovals);
  }

  Future<void> _openLockSheet(BuildContext context, WidgetRef ref) async {
    await showParentLockSheet(context, ref);
    ref.invalidate(kidsHomeProvider);
  }
}

/// Adds a child (name, birth year, colour) and returns the new id.
///
/// Kept as a function rather than a screen because it is two fields and the
/// brief's setup screen is the one that carries the long form.
Future<String?> showAddChildSheet(BuildContext context, WidgetRef ref) async {
  final nameCtrl = TextEditingController();
  final yearCtrl = TextEditingController();
  var colorKey = 'orange';
  final t = TimeThemeKit.of(context).palette;

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: t.elevated,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        Future<void> submit() async {
          final name = nameCtrl.text.trim();
          if (name.isEmpty) return;
          final year = int.tryParse(yearCtrl.text.trim());
          final id = 'kid_${DateTime.now().microsecondsSinceEpoch}';
          final ok = await ref.read(kidsDaoProvider).upsertKid(
                id: id,
                name: name,
                birthYear: year,
                colorKey: colorKey,
              );
          if (!sheetContext.mounted) return;
          Navigator.of(sheetContext).pop(ok ? id : null);
        }

        return Padding(
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
                  'افزودن فرزند',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nameCtrl,
                  textInputAction: TextInputAction.next,
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
                const SizedBox(height: 10),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    'رنگ',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      color: t.textSecondary,
                    ),
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
                          width: 34,
                          height: 34,
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
                          child: colorKey == key
                              ? const Icon(Icons.check,
                                  size: 16, color: Colors.white)
                              : null,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'بدون عکس؛ فقط رنگ و حرف اول نام.',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    color: t.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: submit,
                  style: FilledButton.styleFrom(backgroundColor: KidsHomeScreen.accent),
                  child: const Text('افزودن'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// Sets / changes / removes the parent PIN from inside the kids tool.
Future<void> showParentLockSheet(BuildContext context, WidgetRef ref) async {
  final t = TimeThemeKit.of(context).palette;
  final pinSet = await ParentLock.isPinSet();
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: t.elevated,
    builder: (sheetContext) => Container(
      decoration: BoxDecoration(
        color: t.elevated,
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHandle(),
          Row(
            children: [
              const Icon(Icons.lock_outline, color: KidsHomeScreen.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                'قفل والدین',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: t.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            pinSet
                ? 'رمز والدین فعال است. تأیید جایزه‌ها، تغییر ستاره‌ها و خروج از '
                    'حالت کودک با همین رمز انجام می‌شود. رمز از رمز «اطلاعات من» '
                    'استفاده می‌کند.'
                : 'هنوز رمزی تنظیم نشده است. بدون رمز، هر کسی می‌تواند کارها را '
                    'تأیید کند. رمز والدین از همان رمز «اطلاعات من» استفاده می‌کند.',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
              height: 1.8,
              color: t.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              // The vault screen is where a PIN is set; sending the parent
              // there keeps ONE code path (and one "forgot PIN" story).
              context.push(RouteNames.personalInfo);
            },
            style: FilledButton.styleFrom(backgroundColor: KidsHomeScreen.accent),
            child: Text(pinSet ? 'مدیریت رمز' : 'تنظیم رمز'),
          ),
          const SizedBox(height: 8),
          Text(
            'بازیابی رمز فراموش‌شده از مسیر «اطلاعات من» انجام می‌شود؛ این ابزار '
            'هیچ راه پشتیبانِ دیگری ندارد.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11,
              color: t.textMuted,
            ),
          ),
        ],
      ),
    ),
  );
}

/// «یادآورها» — the settings the database has always had and no screen showed.
///
/// Only the evening summary is offered, because it is the only nudge this tool
/// actually schedules; showing a switch that changes nothing is the defect this
/// sheet exists to avoid.
Future<void> showKidReminderSheet(BuildContext context, WidgetRef ref) async {
  final dao = ref.read(kidsDaoProvider);
  final settings = await dao.settings();
  if (!context.mounted) return;

  var enabled = settings.eveningSummaryEnabled;
  var minutes = settings.eveningSummaryMinutes;
  var dayStart = settings.dayStartMinutes;
  var quietStart = settings.quietStartMinutes;
  var quietEnd = settings.quietEndMinutes;

  KidSettingsRecord withValues() => KidSettingsRecord(
        dayStartMinutes: dayStart,
        showSiblingComparison: settings.showSiblingComparison,
        parentPinEnabled: settings.parentPinEnabled,
        eveningSummaryEnabled: enabled,
        eveningSummaryMinutes: minutes,
        approvalsNudgeEnabled: settings.approvalsNudgeEnabled,
        quietStartMinutes: quietStart,
        quietEndMinutes: quietEnd,
      );

  Future<void> save() async {
    await dao.saveSettings(withValues());
    ref.invalidate(kidsHomeProvider);
    ref.invalidate(kidEveningSyncProvider);
  }

  String clock(int value) =>
      '${(value ~/ 60).toString().padLeft(2, '0')}:'
      '${(value % 60).toString().padLeft(2, '0')}';

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: TimeThemeKit.of(context).palette.surface,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        final t = TimeThemeKit.of(sheetContext).palette;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'یادآورها',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'یک یادآوری ملایم، نه گزارش خودکار: متن آنچه ثبت شده را '
                  'می‌گوید و هیچ‌چیز را به کودک نسبت نمی‌دهد.',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    height: 1.7,
                    color: t.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: KidsHomeScreen.accent,
                  title: Text(
                    'خلاصهٔ شب',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      color: t.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'هر شب ساعت ${clock(minutes)}',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      color: t.textMuted,
                    ),
                  ),
                  value: enabled,
                  onChanged: (value) async {
                    setSheetState(() => enabled = value);
                    await save();
                  },
                ),
                if (enabled)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'ساعت یادآوری',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12,
                            color: t.textSecondary,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showLatinTimePicker(
                            sheetContext,
                            initialTime: TimeOfDay(
                              hour: minutes ~/ 60,
                              minute: minutes % 60,
                            ),
                            title: 'ساعت یادآوری',
                          );
                          if (picked == null) return;
                          minutes = picked.hour * 60 + picked.minute;
                          setSheetState(() {});
                          await save();
                        },
                        child: Text(clock(minutes)),
                      ),
                    ],
                  ),
                const Divider(height: 18),
                Text(
                  'مرز روز و سکوت',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                _TimeRow(
                  label: 'شروع روز ثبت عادت',
                  value: dayStart,
                  display: clock,
                  onPick: (picked) async {
                    dayStart = picked;
                    setSheetState(() {});
                    await save();
                  },
                  pickTime: sheetContext,
                ),
                _TimeRow(
                  label: 'آغاز بازهٔ سکوت',
                  value: quietStart,
                  display: clock,
                  onPick: (picked) async {
                    quietStart = picked;
                    setSheetState(() {});
                    await save();
                  },
                  pickTime: sheetContext,
                ),
                _TimeRow(
                  label: 'پایان بازهٔ سکوت',
                  value: quietEnd,
                  display: clock,
                  onPick: (picked) async {
                    quietEnd = picked;
                    setSheetState(() {});
                    await save();
                  },
                  pickTime: sheetContext,
                ),
                const SizedBox(height: 6),
                Text(
                  'یادآوری‌ها در بازهٔ سکوت شب ارسال نمی‌شوند؛ اگر ساعت انتخابی '
                  'داخل آن باشد، به پایان بازه منتقل می‌شود. تغییر «شروع روز» '
                  'مرز ثبت عادتهای شبانه را جابهجا میکند.',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 10,
                    height: 1.7,
                    color: t.textMuted,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}


/// One editable HH:mm row in «یادآورها» — only wired to settings that really
/// change behaviour (day boundary and quiet hours).
class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.label,
    required this.value,
    required this.display,
    required this.onPick,
    required this.pickTime,
  });

  final String label;
  final int value;
  final String Function(int) display;
  final Future<void> Function(int) onPick;
  final BuildContext pickTime;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
              color: t.textSecondary,
            ),
          ),
        ),
        TextButton(
          onPressed: () async {
            final picked = await showLatinTimePicker(
              pickTime,
              initialTime: TimeOfDay(
                hour: (value ~/ 60) % 24,
                minute: value % 60,
              ),
              title: label,
            );
            if (picked == null) return;
            await onPick(picked.hour * 60 + picked.minute);
          },
          child: Text(display(value)),
        ),
      ],
    );
  }
}

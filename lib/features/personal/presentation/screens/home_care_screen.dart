import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/features/personal/care_engine/care_engine.dart';
import 'package:tawheeed/features/personal/care_engine/care_models.dart';
import 'package:tawheeed/features/personal/care_engine/care_season_plan.dart';
import 'package:tawheeed/features/personal/care_engine/care_templates.dart';
import 'package:tawheeed/features/personal/presentation/widgets/care_defaults_sheet.dart';
import 'package:tawheeed/features/personal/presentation/providers/care_providers.dart';
import 'package:tawheeed/features/personal/presentation/widgets/care_car_sheets.dart';
import 'package:tawheeed/features/personal/presentation/widgets/care_home_sheets.dart';
import 'package:tawheeed/features/personal/presentation/widgets/care_sheet_kit.dart';
import 'package:tawheeed/features/personal/presentation/widgets/care_widgets.dart';

/// «خانه» — services, bills, warranties and subscriptions.
///
/// Entry point is the existing «اطلاعات من» section only; the page opens with
/// four scrollable tab chips. No hub, no clock work, every list is lazy.
class HomeCareScreen extends ConsumerStatefulWidget {
  const HomeCareScreen({super.key, this.nowOverride});

  /// Pins «now» for the golden baselines. Production never passes it.
  final DateTime? nowOverride;

  @override
  ConsumerState<HomeCareScreen> createState() => _HomeCareScreenState();
}

class _HomeCareScreenState extends ConsumerState<HomeCareScreen> {
  static const _accent = careHomeColor;
  int _tab = 0;
  bool _addingHome = false;

  DateTime get _now => widget.nowOverride ?? DateTime.now();

  static const _tabs = [
    'سرویس‌ها',
    'قبض‌ها',
    'گارانتی',
    'اشتراک‌ها',
    'هزینه‌های خانه',
    'قسط‌های خانه',
  ];

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final async = ref.watch(careStoreProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: CareScreenAppBar(
        title: 'خانه',
        onBack: () => context.pop(),
        onHistory: () => context.push('/personal-info/home/history'),
        onSettings: () =>
            showCareSettingsSheet(context, kind: CareAssetKind.home),
      ),
      body: SafeArea(
        child: switch (async) {
          AsyncData(:final value) => _buildBody(value),
          AsyncError(:final error) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'خواندن اطلاعات ممکن نشد.',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 13),
                      color: t.textSecondary,
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(careStoreProvider),
                    child: const Text('تلاش دوباره'),
                  ),
                  Text(
                    '$error',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 10),
                      color: t.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  Widget _buildBody(CareSnapshot snapshot) {
    final t = TimeThemeKit.of(context).palette;
    final homes = snapshot.assetsOf(CareAssetKind.home);
    if (homes.isEmpty) {
      return CareEmptyState(
        accent: _accent,
        icon: Icons.home_outlined,
        title: 'هنوز خانه‌ای ثبت نشده',
        body: 'سرویس پکیج، کولر، قبض‌ها، گارانتی لوازم و اشتراک‌ها را یک‌جا '
            'پیگیری کنید و سررسیدشان را یادآوری بگیرید.',
        actionLabel: 'افزودن خانه',
        onAction: _addHome,
      );
    }

    final selectedId = ref.watch(selectedHomeProvider);
    final home = homes.firstWhere(
      (a) => a.id == selectedId,
      orElse: () => homes.first,
    );
    final records = snapshot.recordsOf(home.id);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
      children: [
        if (homes.length > 1) ...[
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: homes.length,
              separatorBuilder: (_, index) => const SizedBox(width: 6),
              itemBuilder: (_, i) => CareChip(
                label: homes[i].name,
                selected: homes[i].id == home.id,
                accent: _accent,
                onTap: () =>
                    ref.read(selectedHomeProvider.notifier).state = homes[i].id,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _tabs.length,
            separatorBuilder: (_, index) => const SizedBox(width: 6),
            itemBuilder: (_, i) => CareChip(
              label: _tabs[i],
              selected: _tab == i,
              accent: _accent,
              onTap: () => setState(() => _tab = i),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...switch (_tab) {
          0 => _buildServices(snapshot, home),
          1 => _buildBills(snapshot, home),
          2 => _buildWarranties(snapshot, home),
          3 => _buildSubscriptions(snapshot),
          4 => _buildHomeExpenses(snapshot, home),
          _ => _buildHomeInstallments(snapshot, home),
        },
        if (records.isNotEmpty) ...[
          const SizedBox(height: 16),
          SectionHeader(title: 'فعالیت‌های اخیر', accent: _accent),
          for (final record in records.take(4))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const DuotoneIconTile(
                      accent: _accent,
                      icon: Icons.receipt_long_outlined,
                      size: 34,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.title.isEmpty ? 'سرویس' : record.title,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 13),
                              fontWeight: FontWeight.w600,
                              color: t.textPrimary,
                            ),
                          ),
                          Text(
                            careJalali(record.date),
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 10.5),
                              color: t.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (record.cost != null)
                      Text(
                        careMoney(record.cost!),
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          fontWeight: FontWeight.w700,
                          color: careHomeColor,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: 16),
        Text(
          'اطلاعات این بخش فقط روی همین دستگاه ذخیره می‌شود و در پشتیبان‌گیری '
          'برنامه هست.',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 10.5),
            color: t.textMuted,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  // ── services ─────────────────────────────────────────────────────
  List<Widget> _buildServices(CareSnapshot snapshot, CareAsset home) {
    final templates = ref.watch(careTemplatesProvider).value;
    // The pack shown is the one whose own windows say so — not a month table.
    // A closed, fully-scheduled pack is not a call to action, so it goes away.
    final plan = templates == null
        ? null
        : careNextSeasonPlan(
            templates: templates,
            tasks: snapshot.tasksOf(home.id),
            now: _now,
          );
    final shownPlan = plan != null &&
            !(plan.state == CareSeasonState.missed && plan.isComplete)
        ? plan
        : null;
    final statuses = snapshot
        .tasksOf(home.id)
        .where((t) => t.active)
        .map((task) => careStatusOf(task, _now,
            currentKm: snapshot.currentKm(home.id),
            readings: snapshot.readingsOf(home.id)))
        .toList()
      ..sort((a, b) => b.progress.compareTo(a.progress));
    final records = snapshot.recordsOf(home.id);
    final yearCost = careYearCost(records, const [], _now);
    final t = TimeThemeKit.of(context).palette;

    return [
      if (shownPlan != null) ...[
        _SeasonBanner(
          plan: shownPlan,
          onAdd: () async {
            final added = await ref
                .read(careStoreProvider.notifier)
                .addSeasonPack(home.id, shownPlan.pack);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(added == 0
                  ? 'همهٔ موارد این بسته از قبل اضافه شده‌اند.'
                  : '$added مورد به سرویس‌ها اضافه شد.'),
            ));
          },
        ),
        const SizedBox(height: 10),
      ],
      if (shownPlan != null && shownPlan.missing.isNotEmpty) ...[
        const SizedBox(height: 8),
        SectionHeader(
          title: 'فهرست «${shownPlan.pack.titleFa}»',
          count: '${shownPlan.missing.length}',
          accent: _accent,
        ),
        for (final template in shownPlan.missing)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  DuotoneIconTile(
                    accent: _accent,
                    icon: careIconFor(template.iconKey),
                    size: 38,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          template.titleFa,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 13),
                            fontWeight: FontWeight.w600,
                            color: t.textPrimary,
                          ),
                        ),
                        Text(
                          template.intervalLabel,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 10.5),
                            color: t.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'افزودن',
                    onPressed: () => _addTemplateTask(snapshot, home, template),
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                  ),
                ],
              ),
            ),
          ),
      ],
      if (statuses.isNotEmpty) ...[
        const SizedBox(height: 16),
        SectionHeader(title: 'پیشرفت دسته‌بندی‌شده', accent: _accent),
        ..._categoryProgress(snapshot, home, _accent, t),
      ],
      if (statuses.isEmpty)
        Text(
          'سرویسی تعریف نشده است.',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 12),
            color: TimeThemeKit.of(context).palette.textMuted,
          ),
        ),
      for (final status in statuses)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: CareTaskRow(
            status: status,
            accent: _accent,
            onTap: () => _openTask(snapshot, home, status.task),
            trailing: IconButton(
              tooltip: 'انجام شد',
              onPressed: () => _quickComplete(snapshot, home, status.task),
              icon: Icon(
                Icons.check_circle_outline,
                color: careLevelColor(context, status.level),
              ),
            ),
          ),
        ),
      CareInlineAdd(
        label: 'افزودن سرویس',
        accent: _accent,
        onTap: () => _pickTemplate(snapshot, home, templates),
      ),
      if (records.isNotEmpty) ...[
        const SizedBox(height: 16),
        const SectionHeader(title: 'هزینهٔ سالانه', accent: _accent),
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const DuotoneIconTile(
                    accent: _accent,
                    icon: Icons.payments_outlined,
                    size: 44,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'هزینهٔ سالانهٔ المنزل',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 13),
                            fontWeight: FontWeight.w700,
                            color: t.textPrimary,
                          ),
                        ),
                        Text(
                          'تعمیرات، نگهداری، لوازم و خدمات انجام‌شده',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 10.5),
                            color: t.textMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          careMoney(yearCost),
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 16),
                            fontWeight: FontWeight.w800,
                            color: _accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () => showCareDefaultsSheet(
            context,
            ref,
          ),
          icon: const Icon(Icons.tune_rounded, size: 15),
          label: Text(
            'تنظیم پیش‌فرض‌ها',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11,
              color: TimeThemeKit.of(context).palette.textMuted,
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _categoryProgress(
    CareSnapshot snapshot,
    CareAsset home,
    Color accent,
    AppPalette t,
  ) {
    final tasks = snapshot.tasksOf(home.id).where((t) => t.active).toList();
    final categories = <String, List<CareTask>>{};
    for (final task in tasks) {
      categories.putIfAbsent(task.categoryKey, () => []).add(task);
    }

    final categoryNames = {
      'service': 'سرویس‌ها',
      'bills': 'قبض‌ها',
      'warranty': 'گارانتی‌ها',
      'subscriptions': 'اشتراک‌ها',
      'general': 'عمومی',
    };

    return categories.entries.map((entry) {
      final key = entry.key;
      final items = entry.value;
      // A binary «has ever been done» made every category jump to 100% after
      // one service and stay there forever. Use the engine's real cycle
      // progress instead: a task just done is fresh (1), an overdue one is 0.
      // The category score is the average freshness of its tasks.
      final statuses = [
        for (final task in items) careStatusOf(task, _now),
      ];
      final progress = statuses.isEmpty
          ? 0.0
          : statuses.fold<double>(
                  0,
                  (sum, s) => sum + (1 - s.progress.clamp(0.0, 1.0))) /
              statuses.length;

      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  categoryNames[key] ?? key,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    fontWeight: FontWeight.w600,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '${(progress * 100).round()}%',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 10),
                      fontWeight: FontWeight.w700,
                      color: dsContentColor(context, accent),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            CareProgressBar(
              progress: progress,
              color: accent,
            ),
          ],
        ),
      );
    }).toList();
  }

  Future<void> _openTask(
      CareSnapshot snapshot, CareAsset home, CareTask task) async {
    final action = await showCareTaskSheet(context,
        asset: home, task: task, snapshot: snapshot);
    if (action == 'complete' && mounted) {
      await _complete(snapshot, home, [task.id]);
    }
  }

  Future<void> _quickComplete(
      CareSnapshot snapshot, CareAsset home, CareTask task) async {
    await _complete(snapshot, home, [task.id]);
  }

  Future<void> _complete(
    CareSnapshot snapshot,
    CareAsset home,
    List<String> ids,
  ) async {
    final result = await showCompleteServiceSheet(
      context,
      asset: home,
      snapshot: snapshot,
      initialTaskIds: ids,
    );
    if (result != null && mounted) showCompletionSnack(context, result);
  }

  Future<void> _pickTemplate(
    CareSnapshot snapshot,
    CareAsset home,
    CareTemplates? templates,
  ) async {
    if (templates == null) return;
    final existing = snapshot
        .tasksOf(home.id)
        .map((t) => t.templateKey)
        .toSet();
    final available = templates.homeDefaults
        .where((t) => !existing.contains(t.key))
        .toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('همهٔ سرویس‌های پیشنهادی اضافه شده‌اند.'),
      ));
      return;
    }
    await showCareSheet<void>(
      context,
      child: _TemplatePicker(
        templates: available,
        note: templates.note,
        onPick: (template) async {
          await ref
              .read(careStoreProvider.notifier)
              .addTemplateTask(home.id, template);
          if (!mounted) return;
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Future<void> _addTemplateTask(
    CareSnapshot snapshot,
    CareAsset home,
    CareTemplate template,
  ) async {
    await ref.read(careStoreProvider.notifier).addTemplateTask(home.id, template);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('«${template.titleFa}» به سرویس‌ها اضافه شد.'),
    ));
  }

  // ── bills ────────────────────────────────────────────────────────
  List<Widget> _buildBills(CareSnapshot snapshot, CareAsset home) {
    final bills = snapshot.billsOf(home.id).where((b) => b.active).toList();
    final now = _now;
    return [
      if (bills.isEmpty)
        Text(
          'قبضی ثبت نشده است.',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 12),
            color: TimeThemeKit.of(context).palette.textMuted,
          ),
        ),
      for (final bill in bills) ...[
        _BillCard(
          bill: bill,
          snapshot: snapshot,
          now: now,
          onEdit: () =>
              showBillSheet(context, assetId: home.id, bill: bill),
          onPay: (periodKey, dueDate) => showPayBillSheet(
            context,
            bill: bill,
            periodKey: periodKey,
            dueDate: dueDate,
          ),
        ),
        const SizedBox(height: 8),
      ],
      CareInlineAdd(
        label: 'افزودن قبض',
        accent: _accent,
        onTap: () => showBillSheet(context, assetId: home.id),
      ),
    ];
  }

  // ── warranties ───────────────────────────────────────────────────
  List<Widget> _buildWarranties(CareSnapshot snapshot, CareAsset home) {
    final warranties = snapshot.warrantiesOf(home.id).toList()
      ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    final now = _now;
    return [
      if (warranties.isEmpty)
        Text(
          'گارانتی‌ای ثبت نشده است.',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 12),
            color: TimeThemeKit.of(context).palette.textMuted,
          ),
        ),
      for (final warranty in warranties)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _WarrantyCard(
            warranty: warranty,
            daysLeft: careWarrantyDaysLeft(warranty, now),
            onTap: () => showWarrantySheet(
              context,
              assetId: home.id,
              warranty: warranty,
            ),
            onDelete: () => _confirmDeleteWarranty(warranty),
          ),
        ),
      CareInlineAdd(
        label: 'افزودن گارانتی',
        accent: _accent,
        onTap: () => showWarrantySheet(context, assetId: home.id),
      ),
    ];
  }

  Future<void> _confirmDeleteWarranty(Warranty warranty) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف گارانتی؟'),
        content: Text('«${warranty.itemName}» حذف شود؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(careStoreProvider.notifier).deleteWarranty(warranty.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('گارانتی حذف شد.')),
      );
    }
  }

  // ── subscriptions ────────────────────────────────────────────────
  List<Widget> _buildSubscriptions(CareSnapshot snapshot) {
    final subs = snapshot.subscriptions.where((s) => s.active).toList()
      ..sort((a, b) => a.nextChargeDate.compareTo(b.nextChargeDate));
    final total = careSubscriptionsMonthlyTotal(subs);
    return [
      AppCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const DuotoneIconTile(
              accent: _accent,
              icon: Icons.autorenew_outlined,
              size: 44,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'جمع ماهانه',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 11),
                      color: TimeThemeKit.of(context).palette.textMuted,
                    ),
                  ),
                  Text(
                    careMoney(total),
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 16),
                      fontWeight: FontWeight.w800,
                      color: TimeThemeKit.of(context).palette.textPrimary,
                    ),
                  ),
                  Text(
                    'اشتراک سالانه تقسیم بر ۱۲',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 10),
                      color: TimeThemeKit.of(context).palette.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      if (subs.isEmpty)
        Text(
          'اشتراکی ثبت نشده است.',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 12),
            color: TimeThemeKit.of(context).palette.textMuted,
          ),
        ),
      for (final sub in subs)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppCard(
            padding: const EdgeInsets.all(12),
            onTap: () => showSubscriptionSheet(context, subscription: sub),
            child: Row(
              children: [
                const DuotoneIconTile(
                  accent: _accent,
                  icon: Icons.subscriptions_outlined,
                  size: 38,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sub.name,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          fontWeight: FontWeight.w600,
                          color: TimeThemeKit.of(context).palette.textPrimary,
                        ),
                      ),
                      Text(
                        'شارژ بعدی: ${careJalali(sub.nextChargeDate)}',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 10.5),
                          color: TimeThemeKit.of(context).palette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${careMoney(sub.amount)}'
                  '${sub.period == SubscriptionPeriod.yearly ? ' / سال' : ''}',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    fontWeight: FontWeight.w600,
                    color: TimeThemeKit.of(context).palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      CareInlineAdd(
        label: 'افزودن اشتراک',
        accent: _accent,
        onTap: () => showSubscriptionSheet(context),
      ),
    ];
  }

  // ── home expenses ──────────────────────────────────────────────────
  List<Widget> _buildHomeExpenses(CareSnapshot snapshot, CareAsset home) {
    final t = TimeThemeKit.of(context).palette;
    final expenses = snapshot
        .recordsOf(home.id)
        .where((r) => r.taskId == null) // manual expense entries only
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final total = expenses.fold<double>(
      0, (sum, r) => sum + (r.cost ?? 0));

    return [
      AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const DuotoneIconTile(
                  accent: _accent,
                  icon: Icons.receipt_long_outlined,
                  size: 44,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'جمع هزینه‌های خانه',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          fontWeight: FontWeight.w700,
                          color: t.textPrimary,
                        ),
                      ),
                      Text(
                        careMoney(total),
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 16),
                          fontWeight: FontWeight.w800,
                          color:
                              TimeThemeKit.of(context).palette.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      if (expenses.isEmpty)
        Text(
          'هزینه‌ای ثبت نشده است.',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 12),
            color: TimeThemeKit.of(context).palette.textMuted,
          ),
        ),
      for (final expense in expenses)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _ExpenseCard(
            record: expense,
            onTap: () => _editExpense(context, home, expense),
            onDelete: () => _confirmDeleteExpense(expense),
          ),
        ),
      CareInlineAdd(
        label: 'افزودن هزینه خانه',
        accent: _accent,
        onTap: () => _addExpense(context, home),
      ),
    ];
  }

  Future<void> _addExpense(BuildContext context, CareAsset home) async {
    final result = await showAddHomeExpenseSheet(
      context,
      homeId: home.id,
    );
    if (result != null && mounted) {
      await ref.read(careStoreProvider.notifier).saveRecord(result);
    }
  }

  Future<void> _editExpense(
    BuildContext context,
    CareAsset home,
    CareRecord expense,
  ) async {
    final result = await showEditHomeExpenseSheet(
      context,
      homeId: home.id,
      expense: expense,
    );
    if (result != null && mounted) {
      await ref.read(careStoreProvider.notifier).saveRecord(result);
    }
  }

  Future<void> _confirmDeleteExpense(CareRecord expense) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف هزینه؟'),
        content: Text('«${expense.title}» حذف شود؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(careStoreProvider.notifier).deleteRecord(expense.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هزینه حذف شد.')),
      );
    }
  }

  // ── home installments ──────────────────────────────────────────────
  List<Widget> _buildHomeInstallments(CareSnapshot snapshot, CareAsset home) {
    final t = TimeThemeKit.of(context).palette;
    // Only an explicit installment TYPE belongs here. Matching Persian words
    // in the title pulled ordinary household bills into this tab (and dropped
    // legitimately typed installments whose title happened to differ).
    const installmentTypes = {'mortgage', 'installment', 'home_loan'};
    final installments = snapshot
        .billsOf(home.id)
        .where((b) => installmentTypes.contains(b.type))
        .toList()
      ..sort((a, b) => a.dueDay.compareTo(b.dueDay));

    final totalMonthly = installments.fold<double>(
      0, (sum, b) => sum + (b.expectedAmount ?? 0));

    return [
      if (installments.isEmpty)
        Text(
          'قسطی ثبت نشده است.',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 12),
            color: TimeThemeKit.of(context).palette.textMuted,
          ),
        ),
      if (totalMonthly > 0)
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const DuotoneIconTile(
                accent: _accent,
                icon: Icons.payment_outlined,
                size: 44,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'جمع قسط‌های ماهانه',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 13),
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary,
                      ),
                    ),
                    Text(
                      careMoney(totalMonthly),
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 16),
                        fontWeight: FontWeight.w800,
                        color:
                            TimeThemeKit.of(context).palette.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 8),
      for (final installment in installments)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _InstallmentCard(
            installment: installment,
            payments: snapshot.paymentsOf(installment.id),
            now: _now,
            onTap: () => showBillSheet(
              context,
              assetId: home.id,
              bill: installment,
            ),
            onPay: (periodKey, dueDate) => showPayBillSheet(
              context,
              bill: installment,
              periodKey: periodKey,
              dueDate: dueDate,
            ),
          ),
        ),
      CareInlineAdd(
        label: 'افزودن قسط خانه',
        accent: _accent,
        onTap: () => showBillSheet(
          context,
          assetId: home.id,
          initialType: 'installment',
        ),
      ),
    ];
  }

  Future<void> _addHome() async {
    if (_addingHome) return;
    _addingHome = true;
    try {
      final templates = await ref.read(careTemplatesProvider.future);
      if (!mounted) return;
      await showCareSheet<void>(
        context,
        child: _AddHomeSheet(templates: templates),
      );
    } finally {
      _addingHome = false;
    }
  }
}

class _AddHomeSheet extends ConsumerStatefulWidget {
  const _AddHomeSheet({required this.templates});
  final CareTemplates templates;

  @override
  ConsumerState<_AddHomeSheet> createState() => _AddHomeSheetState();
}

class _AddHomeSheetState extends ConsumerState<_AddHomeSheet> {
  final _name = TextEditingController();
  late final Map<String, bool> _selected = {
    for (final t in widget.templates.homeDefaults) t.key: true,
  };
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final chosen = widget.templates.homeDefaults
        .where((t) => _selected[t.key] == true)
        .toList();
    await ref
        .read(careStoreProvider.notifier)
        .addHome(name: _name.text, templates: chosen);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CareSheetTitle(
          title: 'افزودن خانه',
          subtitle: 'سرویس‌های پیشنهادی را انتخاب کنید؛ بعداً هم می‌توانید '
              'اضافه یا ویرایش کنید.',
        ),
        CareField(controller: _name, label: 'نام خانه', hint: 'خانه'),
        for (final template in widget.templates.homeDefaults)
          CareSelectRow(
            selected: _selected[template.key] == true,
            title: template.titleFa,
            subtitle: template.intervalLabel,
            icon: careIconFor(template.iconKey),
            accent: careHomeColor,
            onChanged: (v) => setState(() => _selected[template.key] = v),
          ),
        if (widget.templates.note.isNotEmpty)
          CareNotice(text: widget.templates.note, accent: careHomeColor),
        CareSheetSubmit(
          label: 'ساخت خانه',
          accent: careHomeColor,
          busy: _busy,
          onPressed: _save,
        ),
      ],
    );
  }
}

class _SeasonBanner extends StatelessWidget {
  const _SeasonBanner({required this.plan, required this.onAdd});

  final CareSeasonPlan plan;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final pack = plan.pack;
    final open = plan.state == CareSeasonState.inWindow;
    final accent = open ? careHomeColor : t.textMuted;
    final action = plan.actionLabel;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: careHomeColor.withValues(alpha: open ? .07 : .04),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: careHomeColor.withValues(alpha: open ? .22 : .14),
            width: .5),
      ),
      child: Row(
        children: [
          DuotoneIconTile(
            accent: careHomeColor,
            icon: careForSeasonIcon(pack.iconKey),
            size: 42,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pack.titleFa,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        plan.isComplete
                            ? 'هر ${plan.total} مورد ثبت شده'
                            : plan.statusLabel,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 10.5),
                          color: open ? careHomeColor : t.textMuted,
                          fontWeight: open ? FontWeight.w600 : null,
                        ),
                      ),
                    ),
                    if (!plan.isComplete) ...[
                      Text(
                        ' · ',
                        style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 10.5),
                          color: t.textMuted,
                        ),
                      ),
                      Text(
                        NumberFormat.fraction(plan.scheduled, plan.total),
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 10.5),
                          color: t.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: onAdd,
              style: TextButton.styleFrom(foregroundColor: accent),
              child: Text(
                action,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Icon(Icons.check_circle_outline,
                size: 20, color: careHomeColor.withValues(alpha: .7)),
        ],
      ),
    );
  }
}

IconData careForSeasonIcon(String key) =>
    key == 'snow' ? Icons.ac_unit : Icons.wb_sunny_outlined;

class _TemplatePicker extends StatelessWidget {
  const _TemplatePicker({
    required this.templates,
    required this.note,
    required this.onPick,
  });

  final List<CareTemplate> templates;
  final String note;
  final ValueChanged<CareTemplate> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CareSheetTitle(title: 'افزودن سرویس'),
        for (final template in templates)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: DuotoneIconTile(
              accent: careHomeColor,
              icon: careIconFor(template.iconKey),
              size: 34,
            ),
            title: Text(
              template.titleFa,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12),
              ),
            ),
            subtitle: Text(
              template.intervalLabel,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 10.5),
              ),
            ),
            onTap: () => onPick(template),
          ),
        if (note.isNotEmpty) CareNotice(text: note, accent: careHomeColor),
      ],
    );
  }
}

class _BillCard extends StatelessWidget {
  const _BillCard({
    required this.bill,
    required this.snapshot,
    required this.now,
    required this.onEdit,
    required this.onPay,
  });

  final Bill bill;
  final CareSnapshot snapshot;
  final DateTime now;
  final VoidCallback onEdit;
  final void Function(String periodKey, DateTime dueDate) onPay;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final payments = snapshot.paymentsOf(bill.id);
    final period = careNextUnpaidBillPeriod(bill, now, payments);
    final level = careBillLevel(period.dueDate, now);
    final recent = careRecentBillPayments(bill, payments);
    final maxAmount = recent.fold<double>(
        0, (m, p) => (p.amount ?? 0) > m ? (p.amount ?? 0) : m);
    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              DuotoneIconTile(
                accent: careHomeColor,
                icon: careIconFor(bill.type),
                size: 38,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bill.title,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 13),
                        fontWeight: FontWeight.w600,
                        color: t.textPrimary,
                      ),
                    ),
                    Text(
                      'سررسید ${careJalali(period.dueDate)}'
                      '${bill.expectedAmount == null ? '' : ' · ${careMoney(bill.expectedAmount!)}'}',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 10.5),
                        color: t.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              CareStatusChip(level: level),
            ],
          ),
          if (recent.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 26,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final payment in recent)
                    Padding(
                      padding: const EdgeInsets.only(left: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            width: 8,
                            height: maxAmount <= 0
                                ? 3
                                : ((payment.amount ?? 0) / maxAmount * 22)
                                    .clamp(3.0, 22.0),
                            decoration: BoxDecoration(
                              color: careHomeColor.withValues(alpha: .45),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${jalaliParts(payment.paidDate).month}',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 8),
                              color: t.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => onPay(period.key, period.dueDate),
                    child: const Text('پرداخت شد'),
                  ),
                ],
              ),
            ),
          ] else
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () => onPay(period.key, period.dueDate),
                child: const Text('پرداخت شد'),
              ),
            ),
          if (bill.attachmentPaths.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: bill.attachmentPaths.length,
                separatorBuilder: (_, index) => const SizedBox(width: 6),
                itemBuilder: (_, i) => CareAttachmentThumb(
                  relativePath: bill.attachmentPaths[i],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WarrantyCard extends StatelessWidget {
  const _WarrantyCard({
    required this.warranty,
    required this.daysLeft,
    required this.onTap,
    required this.onDelete,
  });

  final Warranty warranty;
  final int daysLeft;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final level = daysLeft < 0
        ? CareStatusLevel.overdue
        : daysLeft <= 30
            ? CareStatusLevel.urgent
            : daysLeft <= 60
                ? CareStatusLevel.near
                : CareStatusLevel.good;
    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      onLongPress: onDelete,
      child: Row(
        children: [
          const DuotoneIconTile(
            accent: careHomeColor,
            icon: Icons.verified_outlined,
            size: 38,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  warranty.itemName,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    fontWeight: FontWeight.w600,
                    color: t.textPrimary,
                  ),
                ),
                Text(
                  [
                    if (warranty.store.isNotEmpty) warranty.store,
                    'انقضا ${careJalali(warranty.expiryDate)}',
                  ].join(' · '),
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 10.5),
                    color: t.textMuted,
                  ),
                ),
                if (warranty.receiptPaths.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: warranty.receiptPaths.length,
                      separatorBuilder: (_, index) => const SizedBox(width: 5),
                      itemBuilder: (_, i) => CareAttachmentThumb(
                        relativePath: warranty.receiptPaths[i],
                        size: 34,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          CareStatusChip(
            level: level,
            label: daysLeft < 0 ? 'گذشته' : '$daysLeft روز',
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Home Expense card (هزینه‌های خانه)
// ═══════════════════════════════════════════════════════════════════

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({
    required this.record,
    required this.onTap,
    required this.onDelete,
  });

  final CareRecord record;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const DuotoneIconTile(
                accent: careHomeColor,
                icon: Icons.money_outlined,
                size: 32,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            record.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 13),
                              fontWeight: FontWeight.w600,
                              color: t.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: onDelete,
                          child: const Icon(
                            Icons.delete_outline,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          careMoney(record.cost ?? 0),
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 14),
                            fontWeight: FontWeight.w700,
                            color: careHomeColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          careJalali(record.date),
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 11),
                            color: t.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Home Installment card (قسط‌های خانه)
// ═══════════════════════════════════════════════════════════════════

class _InstallmentCard extends StatelessWidget {
  const _InstallmentCard({
    required this.installment,
    required this.payments,
    required this.now,
    required this.onTap,
    required this.onPay,
  });

  final Bill installment;
  final List<BillPayment> payments;
  final DateTime now;
  final VoidCallback onTap;
  final void Function(String periodKey, DateTime dueDate) onPay;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final period = careNextUnpaidBillPeriod(installment, now, payments);
    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const DuotoneIconTile(
                accent: careHomeColor,
                icon: Icons.payment_outlined,
                size: 32,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      installment.title,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 13),
                        fontWeight: FontWeight.w600,
                        color: t.textPrimary,
                      ),
                    ),
                    Text(
                      'قسط خانه / وام ساختمان',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 10.5),
                        color: t.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                careMoney(installment.expectedAmount ?? 0),
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 14),
                  fontWeight: FontWeight.w800,
                  color: careHomeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'سررسید ${careJalali(period.dueDate)}',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 10.5),
                  color: t.textMuted,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => onPay(period.key, period.dueDate),
                icon: const Icon(Icons.payment_outlined, size: 15),
                label: const Text('پرداخت شد'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

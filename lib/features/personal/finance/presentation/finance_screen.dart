import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal/finance/finance_engine.dart';
import 'package:tawheeed/features/personal/finance/finance_models.dart';
import 'package:tawheeed/features/personal/finance/finance_providers.dart';
import 'package:tawheeed/features/personal/finance/finance_reminder_planner.dart';
import 'package:tawheeed/features/personal/finance/finance_settings.dart';
import 'package:tawheeed/features/personal/finance/presentation/debt_sheets.dart';
import 'package:tawheeed/features/personal/finance/presentation/finance_sheets.dart';
import 'package:tawheeed/features/personal/finance/presentation/finance_style.dart';
import 'package:tawheeed/features/personal/finance/presentation/finance_widgets.dart';
import 'package:tawheeed/features/personal/presentation/widgets/care_sheet_kit.dart';
import 'package:tawheeed/features/personal/presentation/widgets/care_widgets.dart';
import 'package:tawheeed/shared/services/currency_store.dart';
import 'package:tawheeed/shared/widgets/currency_aware_state.dart';
import 'package:tawheeed/shared/services/share_service.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/shared/utils/arabic_search.dart';

/// «دفتر مالی» — one page, two tabs: cheques/installments and the debt ledger.
///
/// No hub and no dashboard: this page IS the tool, reached from the single
/// «دفتر مالی» tile in «اطلاعات من».
class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key, this.nowOverride});

  /// Test seam: pins «today» for the timeline buckets and the goldens.
  final DateTime? nowOverride;

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen>
    with CurrencyAwareState<FinanceScreen> {
  DateTime get _now => widget.nowOverride ?? DateTime.now();
  String get _unit => CurrencyStore.calculators.current.unit;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final async = ref.watch(financeStoreProvider);
    final tab = ref.watch(financeTabProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: t.primary,
        iconTheme: IconThemeData(color: t.primary),
        title: Text(
          'دفتر مالی',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w700,
            color: t.primary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'بازگشت',
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'اشتراک‌گذاری خلاصه',
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: () {
              final snap = async.value;
              if (snap == null) return;
              final text = financeSummaryText(
                snap,
                _now,
                CurrencyStore.calculators.current.unit,
                dateText: financeJalaliDate(_now),
              );
              ShareService.shareText(text);
            },
          ),
          IconButton(
            tooltip: 'افزودن',
            icon: const Icon(Icons.add),
            onPressed: () => showFinanceAddMenu(context),
          ),
          IconButton(
            tooltip: 'تنظیمات یادآوری',
            icon: const Icon(Icons.tune),
            onPressed: () => showFinanceReminderSettings(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: switch (async) {
          AsyncData(:final value) => _buildBody(value, tab),
          AsyncError(:final error) => _ErrorBody(
              message: '$error',
              onRetry: () => ref.invalidate(financeStoreProvider),
            ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  Widget _buildBody(FinanceSnapshot snapshot, int tab) {
    final now = _now;
    final unit = _unit;
    final breakdown = financeKindBreakdown(snapshot, now);
    final total = financePayableWithin(snapshot, now);
    final receivable = financePayableWithin(
      snapshot,
      now,
      direction: ObligationDirection.receive,
    );
    final overdueCount = financeActive(snapshot)
        .where((o) =>
            o.direction == ObligationDirection.pay &&
            financeDay(o.dueDate).isBefore(financeDay(now)))
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
      children: [
        FinanceHero(
          total: total,
          breakdown: breakdown,
          receivable: receivable,
          overdueCount: overdueCount,
          unit: unit,
          onTapOverdue: () => ref.read(financeTabProvider.notifier).state = 0,
        ),
        const SizedBox(height: 10),
        if (total > 0 || receivable > 0) ...[
          _MoneyFlowCard(
            snapshot: snapshot,
            now: now,
            payable: total,
            receivable: receivable,
            unit: unit,
          ),
          const SizedBox(height: 10),
        ],
        if (overdueCount > 0) ...[
          _AgingCard(snapshot: snapshot, now: now, unit: unit),
          const SizedBox(height: 10),
        ],
        _TabSwitch(
          index: tab,
          onChanged: (i) => ref.read(financeTabProvider.notifier).state = i,
        ),
        const SizedBox(height: 10),
        if (tab == 0) ..._obligationsTab(snapshot, now, unit),
        if (tab == 1) ..._debtTab(snapshot, unit),
      ],
    );
  }

  List<Widget> _obligationsTab(
    FinanceSnapshot snapshot,
    DateTime now,
    String unit,
  ) {
    final t = TimeThemeKit.of(context).palette;
    final filter = ref.watch(financeFilterProvider);
    final rows = snapshot.obligations.where((o) {
      if (!filter.includePaid && !o.status.isActive) return false;
      if (filter.kinds.isNotEmpty && !filter.kinds.contains(o.kind)) {
        return false;
      }
      final query = normalizeSearchKey(filter.query);
      if (query.isEmpty) return true;
      final haystack = normalizeSearchKey('${o.title} ${o.counterparty}');
      return haystack.contains(query);
    }).toList();

    final grouped = financeTimeline(rows, now);
    final months = financeMonthlyTotals(snapshot, now);

    if (snapshot.obligations.isEmpty) {
      return [
        CareEmptyState(
          accent: financeInstallmentColor,
          icon: Icons.account_balance_wallet_outlined,
          title: 'هنوز چیزی ثبت نشده',
          body: 'چک، قسط یا هر تعهد دیگری را اضافه کنید تا سررسیدها و '
              'یادآوری‌ها یک‌جا دیده شوند.',
          actionLabel: 'افزودن',
          onAction: () => showFinanceAddMenu(context),
        ),
      ];
    }

    return [
      _FilterBar(
        filter: filter,
        onChanged: (f) => ref.read(financeFilterProvider.notifier).state = f,
      ),
      const SizedBox(height: 8),
      if (grouped.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'موردی با این فیلترها پیدا نشد.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 11),
              color: t.textMuted,
            ),
          ),
        ),
      for (final entry in grouped.entries) ...[
        SectionHeader(
          title: entry.key.labelFa,
          accent: entry.key == FinanceBucket.overdue
              ? t.primary
              : financeInstallmentColor,
        ),
        for (final o in entry.value)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: FinanceTimelineRow(
              obligation: o,
              now: now,
              unit: unit,
              onTogglePaid: () => _togglePaid(o),
              onTap: () => _editObligation(o),
            ),
          ),
        const SizedBox(height: 4),
      ],
      const SizedBox(height: 6),
      AppCard(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'پیش‌نمایش ماه‌های آینده',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12),
                fontWeight: FontWeight.w700,
                color: t.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            FinanceMonthBars(totals: months, unit: unit),
          ],
        ),
      ),
    ];
  }

  List<Widget> _debtTab(FinanceSnapshot snapshot, String unit) {
    final t = TimeThemeKit.of(context).palette;
    final totals = debtTotals(snapshot);
    final people = snapshot.persons.toList()
      ..sort((a, b) =>
          debtPersonNet(snapshot, b.id).abs().compareTo(
                debtPersonNet(snapshot, a.id).abs(),
              ));

    if (snapshot.persons.isEmpty) {
      return [
        DebtSummaryCard(totals: totals, unit: unit),
        const SizedBox(height: 10),
        CareEmptyState(
          accent: financeLedgerColor,
          icon: Icons.handshake_outlined,
          title: 'دفتر دَین خالی است',
          body: 'برای هر شخص یک خط ثبت کنید: چه کسی، چقدر، و چه زمانی. '
              'پرداخت‌های جزئی هم در همان صفحه ثبت می‌شوند.',
          actionLabel: 'افزودن شخص',
          onAction: () => showPersonSheet(context),
        ),
      ];
    }

    return [
      DebtSummaryCard(totals: totals, unit: unit),
      const SizedBox(height: 8),
      for (final person in people)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: DebtPersonRow(
            person: person,
            net: debtPersonNet(snapshot, person.id),
            openCount: snapshot
                .entriesOfPerson(person.id)
                .where((e) => !debtIsSettled(e, snapshot.paymentsOf(e.id)))
                .length,
            unit: unit,
            onTap: () => context.push(RouteNames.personalFinancePerson(person.id)),
          ),
        ),
      const SizedBox(height: 4),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Text(
          'این دفتر فقط مبلغ، تاریخ و یادداشت را نگه می‌دارد و هیچ محاسبهٔ '
          'سودی انجام نمی‌دهد.',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 9),
            color: t.textMuted,
            height: 1.6,
          ),
        ),
      ),
    ];
  }

  Future<void> _togglePaid(Obligation o) async {
    final store = ref.read(financeStoreProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    if (o.isPaid) {
      await store.updateObligation(o.copyWith(
        status: ObligationStatus.pending,
        paidDate: null,
        paidAmount: null,
      ));
      return;
    }
    final input = await showMarkPaidSheet(context, obligation: o);
    if (input == null) return;
    final undo = await store.markPaid(
      o,
      paidDate: input.date,
      paidAmount: input.amount,
      note: input.note,
    );
    if (undo == null || !mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: const Text('پرداخت ثبت شد'),
        action: SnackBarAction(
          label: 'بازگردانی',
          onPressed: () => store.undoPaid(undo),
        ),
      ),
    );
  }

  Future<void> _editObligation(Obligation o) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: TimeThemeKit.of(context).palette.elevated,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('ویرایش'),
              onTap: () => Navigator.of(ctx).pop('edit'),
            ),
            ListTile(
              leading: const Icon(Icons.schedule_outlined),
              title: const Text('به تعویق انداختن'),
              onTap: () => Navigator.of(ctx).pop('postpone'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('حذف'),
              onTap: () => Navigator.of(ctx).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    final store = ref.read(financeStoreProvider.notifier);
    switch (action) {
      case 'edit':
        await showObligationSheet(context, kind: o.kind, existing: o);
      case 'postpone':
        final date = await showPostponeSheet(context, obligation: o);
        if (date != null) await store.postpone(o, date);
      case 'delete':
        final ok = await confirmFinanceDelete(
          context,
          title: 'حذف تعهد',
          body: '«${o.title}» حذف شود؟',
          confirmLabel: 'حذف',
        );
        if (ok) await store.deleteObligation(o.id);
    }
  }
}

class _TabSwitch extends StatelessWidget {
  const _TabSwitch({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  static const _labels = ['چک و قسط', 'دَین و طلب'];

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(i),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: index == i ? t.card : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _labels[i],
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 11),
                      fontWeight: index == i ? FontWeight.w700 : null,
                      color: index == i ? t.textPrimary : t.textMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.filter, required this.onChanged});

  final FinanceFilter filter;
  final ValueChanged<FinanceFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          onChanged: (v) => onChanged(filter.copyWith(query: v)),
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 11),
            color: t.textPrimary,
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'جستجو در عنوان و طرف حساب',
            hintStyle: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 10),
              color: t.textMuted,
            ),
            prefixIcon: Icon(Icons.search, size: 17, color: t.textMuted),
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
        const SizedBox(height: 8),
        SizedBox(
          height: 30,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final kind in ObligationKind.values)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: CareChip(
                    label: kind.labelFa,
                    selected: filter.kinds.contains(kind),
                    accent: financeKindColor(kind),
                    onTap: () {
                      final kinds = {...filter.kinds};
                      if (!kinds.remove(kind)) kinds.add(kind);
                      onChanged(filter.copyWith(kinds: kinds));
                    },
                  ),
                ),
              CareChip(
                label: 'پرداخت‌شده‌ها',
                selected: filter.includePaid,
                accent: financeLoanColor,
                onTap: () =>
                    onChanged(filter.copyWith(includePaid: !filter.includePaid)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Person page: entries, payments and the polite-reminder entry point.
class DebtPersonScreen extends ConsumerStatefulWidget {
  const DebtPersonScreen({super.key, required this.personId});

  final String personId;

  @override
  ConsumerState<DebtPersonScreen> createState() => _DebtPersonScreenState();
}

class _DebtPersonScreenState extends ConsumerState<DebtPersonScreen>
    with CurrencyAwareState<DebtPersonScreen> {
  String get _unit => CurrencyStore.calculators.current.unit;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final snapshot = ref.watch(financeStoreProvider).value;
    final person = snapshot?.personById(widget.personId);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: t.primary,
        iconTheme: IconThemeData(color: t.primary),
        title: Text(
          person?.name ?? 'شخص',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w700,
            color: t.primary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'بازگشت',
          onPressed: () => context.pop(),
        ),
        actions: [
          if (person != null)
            IconButton(
              tooltip: 'افزودن مورد',
              icon: const Icon(Icons.add),
              onPressed: () => showEntrySheet(context, person: person),
            ),
          if (person != null)
            IconButton(
              tooltip: 'ویرایش',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showPersonSheet(context, person: person),
            ),
        ],
      ),
      body: SafeArea(
        child: snapshot == null || person == null
            ? const Center(child: CircularProgressIndicator())
            : _body(snapshot, person),
      ),
    );
  }

  Widget _body(FinanceSnapshot snapshot, Person person) {
    final t = TimeThemeKit.of(context).palette;
    final unit = _unit;
    final net = debtPersonNet(snapshot, person.id);
    final entries = snapshot.entriesOfPerson(person.id);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
      children: [
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              DuotoneIconTile(
                accent: financeLedgerColor,
                icon: net >= 0 ? Icons.south_west : Icons.north_east,
                size: 36,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      net >= 0 ? 'در مجموع طلب شما' : 'در مجموع بدهی شما',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 10),
                        color: t.textMuted,
                      ),
                    ),
                    FinanceAmount(
                      value: net.abs(),
                      unit: unit,
                      size: 15,
                      color: net >= 0
                          ? dsContentColor(context, AppTheme.lightSuccess)
                          : dsContentColor(context, AppTheme.lightError),
                    ),
                  ],
                ),
              ),
              if (person.phone.isNotEmpty)
                IconButton(
                  tooltip: 'شماره تماس',
                  icon: const Icon(Icons.call_outlined),
                  onPressed: () => ShareService.copyText(context, person.phone),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (entries.isEmpty)
          CareEmptyState(
            accent: financeLedgerColor,
            icon: Icons.receipt_outlined,
            title: 'موردی ثبت نشده',
            body: 'اولین دَین یا طلب این شخص را ثبت کنید؛ پرداخت‌ها بعداً '
                'به همین مورد اضافه می‌شوند.',
            actionLabel: 'افزودن مورد',
            onAction: () => showEntrySheet(context, person: person),
          )
        else
          for (final entry in entries) ...[
            _EntryCard(
              entry: entry,
              payments: snapshot.paymentsOf(entry.id),
              unit: unit,
            ),
            const SizedBox(height: 6),
          ],
      ],
    );
  }
}

class _EntryCard extends ConsumerWidget {
  const _EntryCard({
    required this.entry,
    required this.payments,
    required this.unit,
  });

  final DebtEntry entry;
  final List<DebtPayment> payments;
  final String unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = TimeThemeKit.of(context).palette;
    final remaining = debtRemaining(entry, payments);
    final settled = debtIsSettled(entry, payments);
    final directionColor = dsContentColor(
      context,
      entry.direction == DebtDirection.owedToMe
          ? AppTheme.lightSuccess
          : AppTheme.lightError,
    );

    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(financeDirectionIcon(entry.direction),
                  size: 15, color: directionColor),
              const SizedBox(width: 5),
              Text(
                entry.direction.labelFa,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 10),
                  color: directionColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (settled)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: t.surfaceAlt,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    entry.closed ? 'بسته‌شده' : 'تسویه‌شده',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 9),
                      color: t.textMuted,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              FinanceAmount(value: entry.amount, unit: unit, size: 12),
              const SizedBox(width: 6),
              if (!settled)
                Text(
                  'باقی: ${NumberFormat.formatMoney(remaining, unit)}',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 9),
                    color: t.textMuted,
                  ),
                ),
            ],
          ),
          if (entry.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                entry.note,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 10),
                  color: t.textSecondary,
                ),
              ),
            ),
          if (payments.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final p in payments)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    Icon(Icons.check, size: 12, color: t.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      financeJalaliDate(p.date),
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 9),
                        color: t.textMuted,
                      ),
                    ),
                    const Spacer(),
                    FinanceAmount(
                      value: p.amount,
                      unit: unit,
                      size: 9,
                      color: t.textSecondary,
                      weight: FontWeight.w500,
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              if (!settled)
                TextButton.icon(
                  onPressed: () => showPaymentSheet(
                    context,
                    entry: entry,
                    remaining: remaining,
                  ),
                  icon: const Icon(Icons.add, size: 15),
                  label: Text(
                    'ثبت پرداخت',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 10),
                    ),
                  ),
                ),
              if (!settled && entry.direction == DebtDirection.owedToMe)
                TextButton.icon(
                  onPressed: () {
                    final person =
                        ref.read(financeStoreProvider).value?.personById(
                              entry.personId,
                            );
                    if (person == null) return;
                    showPoliteMessageSheet(
                      context,
                      person: person,
                      entry: entry,
                      remaining: remaining,
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline, size: 15),
                  label: Text(
                    'یادآوری مؤدبانه',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 10),
                    ),
                  ),
                ),
              if (settled)
                TextButton.icon(
                  onPressed: () async {
                    await ref
                        .read(financeStoreProvider.notifier)
                        .reopen(entry);
                  },
                  icon: const Icon(Icons.replay_outlined, size: 15),
                  label: Text(
                    'بازگشایی',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 10),
                    ),
                  ),
                ),
              const Spacer(),
              IconButton(
                tooltip: 'ویرایش',
                icon: const Icon(Icons.edit_outlined, size: 17),
                onPressed: () async {
                  final person =
                      ref.read(financeStoreProvider).value?.personById(
                            entry.personId,
                          );
                  if (person == null) return;
                  await showEntrySheet(context, person: person, entry: entry);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: t.textMuted),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 11),
                color: t.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: onRetry, child: const Text('تلاش دوباره')),
          ],
        ),
      ),
    );
  }
}

/// «تنظیمات یادآوری» برای دفتر مالی: فعال/غیرفعال، ساعت، ساعات خاموش و
/// یادآوری بدهی‌های عقب‌افتاده.
Future<void> showFinanceReminderSettings(
  BuildContext context,
  WidgetRef ref,
) async {
  final settings = await ref.read(financeSettingsProvider.future);
  if (!context.mounted) return;

  var enabled = settings.enabled;
  var hour = settings.hour;
  var quietStart = settings.quietStart;
  var quietEnd = settings.quietEnd;
  var overdue = settings.overdueReminderEnabled;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: TimeThemeKit.of(context).palette.elevated,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        final t = TimeThemeKit.of(sheetContext).palette;
        final accent = financeInstallmentColor;

        Future<void> save() async {
          final next = FinanceReminderSettings(
            enabled: enabled,
            hour: hour,
            quietStart: quietStart,
            quietEnd: quietEnd,
            overdueReminderEnabled: overdue,
          );
          await FinanceSettingsStore.save(next);
          ref.invalidate(financeSettingsProvider);
          await ref.read(financeStoreProvider.notifier).refreshReminders();
          if (!sheetContext.mounted) return;
          Navigator.of(sheetContext).pop();
        }

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: AppCard(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SheetHandle(),
                    Text(
                      'تنظیمات یادآوری مالی',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 16),
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    CareSwitchRow(
                      label: 'یادآوری‌های مالی فعال باشند',
                      value: enabled,
                      accent: accent,
                      onChanged: (v) => setSheetState(() => enabled = v),
                    ),
                    const SizedBox(height: 12),
                    CareSwitchRow(
                      label: 'یادآوری بدهی‌های عقب‌افتاده',
                      value: overdue,
                      accent: accent,
                      onChanged: (v) => setSheetState(() => overdue = v),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'ساعت یادآوری',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 12),
                              color: t.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 70,
                          child: TextField(
                            controller: TextEditingController(
                              text: hour.toString().padLeft(2, '0'),
                            ),
                            keyboardType: TextInputType.number,
                            maxLength: 2,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 13),
                              color: t.textPrimary,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(),
                              counterText: '',
                            ),
                            onChanged: (v) {
                              final h = int.tryParse(v);
                              if (h != null && h >= 0 && h <= 23) {
                                setSheetState(() => hour = h);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'ساعت شروع خاموشی',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 12),
                              color: t.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 70,
                          child: TextField(
                            controller: TextEditingController(
                              text: quietStart.toString().padLeft(2, '0'),
                            ),
                            keyboardType: TextInputType.number,
                            maxLength: 2,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 13),
                              color: t.textPrimary,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(),
                              counterText: '',
                            ),
                            onChanged: (v) {
                              final h = int.tryParse(v);
                              if (h != null && h >= 0 && h <= 23) {
                                setSheetState(() => quietStart = h);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'ساعت پایان خاموشی',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 12),
                              color: t.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 70,
                          child: TextField(
                            controller: TextEditingController(
                              text: quietEnd.toString().padLeft(2, '0'),
                            ),
                            keyboardType: TextInputType.number,
                            maxLength: 2,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 13),
                              color: t.textPrimary,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(),
                              counterText: '',
                            ),
                            onChanged: (v) {
                              final h = int.tryParse(v);
                              if (h != null && h >= 0 && h <= 23) {
                                setSheetState(() => quietEnd = h);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    CareSheetSubmit(
                      label: 'ذخیره تنظیمات',
                      accent: accent,
                      onPressed: save,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}


/// «جریان پول» — a donut of what leaves vs. what comes in over the next 30
/// days, plus the shape of the due dates bucketed into the next four weeks.
class _MoneyFlowCard extends StatelessWidget {
  const _MoneyFlowCard({
    required this.snapshot,
    required this.now,
    required this.payable,
    required this.receivable,
    required this.unit,
  });

  final FinanceSnapshot snapshot;
  final DateTime now;
  final double payable;
  final double receivable;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final outColor = isDark ? AppTheme.darkError : AppTheme.lightError;
    final inColor = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;

    // Four 7-day buckets so a cluster of due dates is visible at a glance.
    final today = financeDay(now);
    final buckets = List<double>.filled(4, 0);
    for (final o in financeActive(snapshot)) {
      final delta = financeDay(o.dueDate).difference(today).inDays;
      if (delta < 0 || delta >= 28) continue;
      buckets[(delta / 7).floor()] += o.amount;
    }

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'جریان پول',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 12),
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              MiniDonutChart(
                size: 86,
                thickness: 11,
                slices: [
                  DonutSlice(label: 'پرداختنی', value: payable, color: outColor),
                  DonutSlice(label: 'دریافتنی', value: receivable, color: inColor),
                ],
                center: Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 22,
                  color: t.textMuted,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _flowRow(context, 'پرداختنی', payable, outColor),
                    const SizedBox(height: 8),
                    _flowRow(context, 'دریافتنی', receivable, inColor),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'فشار سررسید در ۴ هفتهٔ آینده',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 10.5),
              color: t.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          MiniLineChart(values: buckets, color: financeLedgerColor, height: 46),
        ],
      ),
    );
  }

  Widget _flowRow(
    BuildContext context,
    String label,
    double amount,
    Color color,
  ) {
    final t = TimeThemeKit.of(context).palette;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11,
              color: t.textSecondary,
            ),
          ),
        ),
        Flexible(
          child: Text(
            NumberFormat.formatMoney(amount, unit),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}


/// «گزارش پیریِ معوق» — how long the payable items have been overdue, in
/// three bands. The number alone («۲ عقب‌افتاده») says nothing about whether
/// the trouble is fresh or months old.
class _AgingCard extends StatelessWidget {
  const _AgingCard({
    required this.snapshot,
    required this.now,
    required this.unit,
  });

  final FinanceSnapshot snapshot;
  final DateTime now;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final today = financeDay(now);
    final overdue = financeActive(
      snapshot,
      direction: ObligationDirection.pay,
    ).where((o) => financeDay(o.dueDate).isBefore(today)).toList();

    // Semantic inks straight from the theme tokens (no cross-feature import):
    // fresh lateness warns, anything older errors.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final warn = isDark ? AppTheme.darkWarning : AppTheme.lightWarning;
    final err = isDark ? AppTheme.darkError : AppTheme.lightError;
    final bands = <(String, List<Obligation>, Color)>[
      ('۱ تا ۷ روز', [], warn),
      ('۸ تا ۳۰ روز', [], err),
      ('بیش از ۳۰ روز', [], err),
    ];
    for (final o in overdue) {
      final late = financeDaysBetween(o.dueDate, today);
      if (late <= 7) {
        bands[0].$2.add(o);
      } else if (late <= 30) {
        bands[1].$2.add(o);
      } else {
        bands[2].$2.add(o);
      }
    }

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'پیریِ معوق',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 12),
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < bands.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _band(context, bands[i])),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _band(
    BuildContext context,
    (String, List<Obligation>, Color) band,
  ) {
    final t = TimeThemeKit.of(context).palette;
    final (label, items, color) = band;
    final sum = items.fold<double>(0, (s, o) => s + o.amount);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .35), width: .6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 10),
              color: t.textMuted,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            NumberFormat.ltrIsolated('${items.length}'),
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 16),
              fontWeight: FontWeight.w800,
              color: dsContentColor(context, color),
            ),
          ),
          if (sum > 0)
            Text(
              NumberFormat.formatMoney(sum, unit),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 10),
                color: t.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

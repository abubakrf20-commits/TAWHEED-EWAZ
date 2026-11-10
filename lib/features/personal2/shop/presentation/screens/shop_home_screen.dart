import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/core/utils/jalali_format.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop_domain.dart';
import 'package:tawheeed/features/personal2/shop/presentation/providers/shop_providers.dart';
import 'package:tawheeed/features/personal2/shop/presentation/providers/shop_stage3_loaders.dart';
import 'package:tawheeed/features/personal2/shop/presentation/screens/shop_customers_tab.dart';
import 'package:tawheeed/features/personal2/shop/presentation/screens/shop_more_sheet.dart';
import 'package:tawheeed/features/personal2/shop/presentation/screens/shop_products_tab.dart';
import 'package:tawheeed/features/personal2/shop/presentation/screens/shop_report_tab.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// «حساب مغازه» — the tool shell: an internal bottom bar
/// («امروز | کالاها | مشتریان | گزارش») with a centered primary FAB
/// «فروش جدید». No hub page: the entry lives in the personal tools section.
class ShopHomeScreen extends StatefulWidget {
  const ShopHomeScreen({super.key});

  @override
  State<ShopHomeScreen> createState() => _ShopHomeScreenState();
}

class _ShopHomeScreenState extends State<ShopHomeScreen> {
  static const Color accent = Color(0xFF0E7C86);


  int _tab = 0;

  static const _tabs = ['امروز', 'کالاها', 'مشتریان', 'گزارش'];

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          foregroundColor: t.primary,
          iconTheme: IconThemeData(color: t.primary),
          title: Text(
            'حساب مغازه',
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
              tooltip: 'بیشتر',
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => ShopMoreSheet.show(context),
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => openPos(context),
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: const StadiumBorder(),
          icon: const Icon(Icons.point_of_sale_rounded, size: 20),
          label: Text(
            'فروش جدید',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        bottomNavigationBar: _bottomBar(context, t),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: IndexedStack(
              key: ValueKey(_tab),
              index: _tab,
              children: [
                const _TodayTab(),
                const ShopProductsTab(),
                const ShopCustomersTab(),
                const ShopReportTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The internal bottom bar with the FAB's notch — a BottomAppBar so the
  /// centered FAB docks into it. The tool's own tabs, NOT the app shell's.
  Widget _bottomBar(BuildContext context, AppPalette t) {
    return BottomAppBar(
      color: t.surface,
      elevation: 0,
      shape: const CircularNotchedRectangle(),
      notchMargin: 6,
      child: Row(
        children: [
          for (var i = 0; i < _tabs.length; i++)
            Expanded(
              child: _tabButton(context, i),
            ),
        ],
      ),
    );
  }

  Widget _tabButton(BuildContext context, int index) {
    final t = TimeThemeKit.of(context).palette;
    final selected = _tab == index;
    // The FAB's notch sits in the middle; tabs 1 and 2 flank it, so shift
    // their icons inward to keep the row balanced.
    final shifted = index == 1 || index == 2;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _tab = index),
      child: Padding(
        padding: EdgeInsets.only(
          top: 8,
          bottom: 6,
          left: shifted ? 14 : 0,
          right: shifted ? 14 : 0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              switch (index) {
                0 => Icons.today_rounded,
                1 => Icons.inventory_2_outlined,
                2 => Icons.people_outline_rounded,
                _ => Icons.assessment_outlined,
              },
              size: 20,
              color: selected ? accent : t.textMuted,
            ),
            const SizedBox(height: 2),
            // FittedBox, not a wrapping Text: four labels share one 320 dp bar
            // with the FAB notch, so at large text the word must shrink to fit
            // rather than grow a third line and push the bar out of its box.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _tabs[index],
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? accent : t.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// «امروز» — the dashboard v1.
class _TodayTab extends ConsumerStatefulWidget {
  const _TodayTab();

  @override
  ConsumerState<_TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends ConsumerState<_TodayTab> {
  /// The eye toggle. Starts unset; the first loaded settings row seeds it
  /// with the privacy default («پنهان کردن مبالغ»).
  bool? _hidden;

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(shopHomeProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(shopHomeProvider),
      child: home.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        // One sentence is not a failure surface: say what failed AND that the
        // shop's data is still there, then offer the retry.
        error: (e, _) => FailureView(
          id: 'shop_home_load',
          title: 'فروشگاه باز نشد',
          detail: 'داده‌های فروشگاه شما پاک نشده‌اند؛ '
              'فقط خواندنشان ناموفق بود.',
          onRetry: () => ref.invalidate(shopHomeProvider),
          error: e,
          layout: FailureLayout.page,
        ),
        data: (state) {
          final hidden = _hidden ?? state.isHiddenDefault;
          return ListView(
            padding:
                const EdgeInsets.fromLTRB(DsSpacing.page, 12, DsSpacing.page, 110),
            children: [
              _hero(context, state, hidden),
              const SizedBox(height: 12),
              if (state.todaySalesTotal > 0) ...[
                _paymentDonut(context, state),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      context,
                      Icons.receipt_long_rounded,
                      'طلب مشتریان',
                      hidden ? '••••' : NumberFormat.groupDigits('${state.totalReceivable}'),
                      const Color(0xFF2E8B3D),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _statCard(
                      context,
                      Icons.warning_amber_rounded,
                      'موجودی کم',
                      '${state.lowStock.length}',
                      const Color(0xFFC9462C),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _Stage3Stat(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'صندوق',
                      future:
                          ref.read(shopStage3LoadersProvider).cashExpected(),
                      color: const Color(0xFF2F6FB5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Stage3Stat(
                      icon: Icons.local_shipping_outlined,
                      label: 'بدهی به تأمین‌کنندگان',
                      future:
                          ref.read(shopStage3LoadersProvider).payablesTotal(),
                      color: const Color(0xFFC9462C),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _Stage3Stat(
                      icon: Icons.receipt_long_outlined,
                      label: 'چک سررسید ۷ روز',
                      future:
                          ref.read(shopStage3LoadersProvider).chequesDue(),
                      color: const Color(0xFFD9922B),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Stage3Stat(
                      icon: Icons.receipt_outlined,
                      label: 'هزینهٔ امروز',
                      future:
                          ref.read(shopStage3LoadersProvider).expenseToday(),
                      color: const Color(0xFF8D6E63),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _quickActions(context),
              const SizedBox(height: 12),
              if (state.lowStock.isNotEmpty ||
                  state.overdueCustomers > 0) ...[
                _alerts(context, state),
                const SizedBox(height: 12),
              ],
              _recent(context, state, hidden),
            ],
          );
        },
      ),
    );
  }

  /// «خلاصهٔ روز» donut — the same payment mix as the hero's segmented bar,
  /// but readable as proportions with exact percentages next to it.
  Widget _paymentDonut(BuildContext context, ShopHomeState state) {
    final t = TimeThemeKit.of(context).palette;
    final mix = _mixSlices(state);
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          MiniDonutChart(
            slices: [
              for (final slice in mix)
                DonutSlice(
                  label: slice.$1,
                  value: slice.$2,
                  color: slice.$3,
                ),
            ],
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  NumberFormat.ltrIsolated('${state.todayInvoiceCount}'),
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 16),
                    fontWeight: FontWeight.w800,
                    color: t.textPrimary,
                  ),
                ),
                Text(
                  'فاکتور',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 9,
                    color: t.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ترکیب پرداخت امروز',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                for (final slice in mix)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: slice.$3,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            slice.$1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 11,
                              color: t.textSecondary,
                            ),
                          ),
                        ),
                        Text(
                          NumberFormat.ltrIsolated(
                              '${(slice.$2 * 100).round()}%'),
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: t.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Solid dark-teal hero — flat, no gradient.
  Widget _hero(BuildContext context, ShopHomeState state, bool hidden) {
    final mix = _mixSlices(state);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B3F45),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'فروش امروز',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: .8),
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'پنهان کردن مبالغ',
                icon: Icon(
                  hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 20,
                  color: Colors.white.withValues(alpha: .8),
                ),
                onPressed: () => setState(() => _hidden = !(hidden)),
              ),
            ],
          ),
          Text(
            hidden ? '••••••' : NumberFormat.groupDigits('${state.todaySalesTotal}'),
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 26),
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${state.todayInvoiceCount} فاکتور · ${jalaliLabelFa(state.now)}',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11,
              color: Colors.white.withValues(alpha: .75),
            ),
          ),
          const SizedBox(height: 12),
          // Segmented bar by payment method with a legend.
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              // Expanded(flex), not FractionallySizedBox-in-Row: a
              // FractionallySizedBox sizes itself off its parent constraints,
              // and a Row hands its children unbounded width — the layout
              // guard test caught that as w=Infinity. Flex takes the Row's
              // real width and splits it.
              child: Row(
                children: [
                  for (final slice in mix)
                    Expanded(
                      flex: (slice.$2 * 1000).round().clamp(1, 100000),
                      child: Container(color: slice.$3),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: [
              for (final slice in mix)
                _legendDot(slice.$1, slice.$3),
            ],
          ),
        ],
      ),
    );
  }

  /// (label, fraction, color) for the segmented bar. Empty day → one full
  /// neutral track.
  List<(String, double, Color)> _mixSlices(ShopHomeState state) {
    const cash = Color(0xFF2E8B3D);
    const card = Color(0xFF2F6FB5);
    const credit = Color(0xFFC9462C);
    final byMethod = state.todayByMethod;
    final total = state.todaySalesTotal;
    if (total <= 0) return const [('امروز هنوز فروشی ثبت نشده', 1.0, Color(0x33FFFFFF))];
    final cashAmt = byMethod[PaymentMethod.cash] ?? 0;
    final cardAmt = byMethod[PaymentMethod.card] ?? 0;
    final creditAmt = byMethod[PaymentMethod.other] ?? 0;
    return [
      if (cashAmt > 0) ('نقد', cashAmt / total, cash),
      if (cardAmt > 0) ('کارت', cardAmt / total, card),
      if (creditAmt > 0) ('نسیه', creditAmt / total, credit),
    ];
  }

  Widget _legendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 10,
              color: Colors.white.withValues(alpha: .85),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statCard(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    final t = TimeThemeKit.of(context).palette;
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          DuotoneIconTile(accent: color, icon: icon, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    color: t.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _quick(
            context,
            Icons.payments_rounded,
            'دریافت وجه',
            () => context.push(RouteNames.shopCustomers),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _quick(
            context,
            Icons.add_box_rounded,
            'کالای جدید',
            () => context.push(RouteNames.shopProducts),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _quick(
            context,
            Icons.receipt_rounded,
            'فروش‌های امروز',
            () => context.push(RouteNames.shopReport),
          ),
        ),
      ],
    );
  }

  Widget _quick(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    final t = TimeThemeKit.of(context).palette;
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 10),
      onTap: onTap,
      child: Column(
        children: [
          DuotoneIconTile(accent: const Color(0xFF0E7C86), icon: icon, size: 30),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: t.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _alerts(BuildContext context, ShopHomeState state) {
    final t = TimeThemeKit.of(context).palette;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.overdueCustomers > 0)
            _alertRow(
              context,
              Icons.schedule_rounded,
              '${state.overdueCustomers} مشتری با بدهی بیش از ۳۰ روز',
              const Color(0xFFC9462C),
              onTap: () => context.push(RouteNames.shopCustomers),
            ),
          if (state.lowStock.isNotEmpty)
            for (final p in state.lowStock.take(3))
              _alertRow(
                context,
                Icons.inventory_2_outlined,
                'کم‌موجودی: ${p.name}',
                const Color(0xFFD9922B),
                onTap: () => context.push(RouteNames.shopProducts),
              ),
          if (state.lowStock.isEmpty && state.overdueCustomers == 0)
            Text(
              'هشداری نیست.',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                color: t.textMuted,
              ),
            ),
        ],
      ),
    );
  }

  Widget _alertRow(
    BuildContext context,
    IconData icon,
    String text,
    Color color, {
    VoidCallback? onTap,
  }) {
    final t = TimeThemeKit.of(context).palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                color: t.textPrimary,
              ),
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_left_rounded, size: 18, color: t.textMuted),
        ],
      ),
    );
  }

  Widget _recent(BuildContext context, ShopHomeState state, bool hidden) {
    final t = TimeThemeKit.of(context).palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'آخرین تراکنش‌ها', accent: Color(0xFF0E7C86)),
        const SizedBox(height: 4),
        if (state.recentInvoices.isEmpty)
          AppCard(
            child: Text(
              'هنوز فروشی ثبت نشده. با «فروش جدید» شروع کنید.',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                color: t.textMuted,
              ),
            ),
          )
        else
          for (final inv in state.recentInvoices.take(6))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: AppCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                onTap: () => openPos(context, invoiceId: inv.id),
                child: Row(
                  children: [
                    DuotoneIconTile(
                      accent: inv.isReturn
                          ? const Color(0xFFC9462C)
                          : const Color(0xFF0E7C86),
                      icon: inv.isReturn
                          ? Icons.undo_rounded
                          : Icons.receipt_rounded,
                      size: 30,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'فاکتور ${inv.number}',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: t.textPrimary,
                            ),
                          ),
                          Text(
                            _clockLabel(inv.date),
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
                      (hidden)
                          ? '••••'
                          : NumberFormat.groupDigits('${inv.total}'),
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  static String _clockLabel(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

/// Opens the POS. [invoiceId] re-opens a past invoice's receipt.
void openPos(BuildContext context, {String? invoiceId}) {
  context.push(RouteNames.shopPos, extra: invoiceId);
}

/// The stage-3 dashboard stat cards, each loading its own number lazily
/// (never at app start — the brief's first-frame rule).
class _Stage3Stat extends StatelessWidget {
  const _Stage3Stat({
    required this.icon,
    required this.label,
    required this.future,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Future<int> future;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return AppCard(
      child: FutureBuilder<int>(
        future: future,
        builder: (context, snap) {
          final value = snap.data;
          return Row(
            children: [
              DuotoneIconTile(accent: color, icon: icon),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 9,
                        color: t.textMuted,
                      ),
                    ),
                    Text(
                      snap.connectionState != ConnectionState.done
                          ? '…'
                          : NumberFormat.groupDigits('${value ?? 0}'),
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}


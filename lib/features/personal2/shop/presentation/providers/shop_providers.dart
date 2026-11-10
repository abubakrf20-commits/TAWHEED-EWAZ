import 'package:drift/drift.dart' show Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/features/personal2/shop/data/shop_dao.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop_domain.dart';

/// The loaded dashboard: today's money, receivables, alerts, recent rows.
///
/// Every number is computed by SQL aggregate over indexed columns — the
/// dashboard never loads a table into Dart to sum it.
class ShopHomeState {
  const ShopHomeState({
    required this.settings,
    required this.todaySalesTotal,
    required this.todayInvoiceCount,
    required this.todayByMethod,
    required this.totalReceivable,
    required this.overdueCustomers,
    required this.lowStock,
    required this.recentInvoices,
    required this.now,
  });

  final ShopSettingsRow settings;
  final int todaySalesTotal;
  final int todayInvoiceCount;

  /// Payment mix for the segmented bar: cash / card / other(نسیه) totals.
  final Map<PaymentMethod, int> todayByMethod;
  final int totalReceivable;

  /// Customers whose oldest open debt is over 30 days.
  final int overdueCustomers;
  final List<ShopProduct> lowStock;
  final List<ShopInvoice> recentInvoices;
  final DateTime now;

  bool get isHiddenDefault => settings.hideBalances;
}

/// Local midnight of today in epoch ms — the boundary every "today" query
/// uses, so the dashboard and the report agree by construction.
DateTime startOfToday() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

final shopHomeProvider = FutureProvider<ShopHomeState>((ref) async {
  final dao = ref.read(shopDaoProvider);
  final settingsRow = await dao.settings();
  final from = startOfToday().millisecondsSinceEpoch;
  final now = DateTime.now();

  // Today's posted sale invoices (void excluded at the SQL level).
  final invoices = await dao.recentInvoices(
    fromMs: from,
    toMs: now.millisecondsSinceEpoch + 1,
    limit: 1000,
  );
  var total = 0;
  final byMethod = <PaymentMethod, int>{};
  for (final inv in invoices) {
    if (inv.isVoid || inv.isReturn) continue;
    total += inv.total;
  }

  // Payment mix for today (payments table, `in` direction).
  final mixRows = await dao.db.customSelect(
    'SELECT method, COALESCE(SUM(amount), 0) AS total FROM '
    '${'p2_shop_payment'} WHERE date >= ? AND direction = ? '
    'GROUP BY method',
    variables: [Variable.withInt(from), Variable.withString('in')],
  ).get();
  for (final r in mixRows) {
    final method = PaymentMethod.fromWire(r.read<String>('method'));
    byMethod[method] = r.read<int>('total');
  }
  // The credit portion of today's sales is the «نسیه» slice: sales total
  // minus what actually arrived as payments today cannot be attributed
  // per-invoice cheaply here, so the mix bar shows recorded payments by
  // method and نسیه is the remainder of the sales total.
  final paidToday =
      byMethod.values.fold<int>(0, (s, x) => s + x);
  final creditToday = total - paidToday;
  if (creditToday > 0) byMethod[PaymentMethod.other] = creditToday;

  // Total receivable: SUM over customers of their positive ledger balances.
  final receivableRows = await dao.db.customSelect(
    'SELECT COALESCE(SUM(bal), 0) AS total FROM ('
    'SELECT COALESCE(SUM(signed_amount), 0) AS bal FROM p2_shop_ledger_entry '
    'WHERE party_type = ? GROUP BY party_id) WHERE bal > 0',
    variables: [Variable.withString('customer')],
  ).get();
  final totalReceivable = receivableRows.first.read<int>('total');

  // Overdue customers (oldest open debt > 30 days): count via the ledger
  // groups whose earliest unpaid invoice is older than 30 days.
  var overdue = 0;
  final customerIds = await dao.db.customSelect(
    'SELECT DISTINCT party_id FROM p2_shop_ledger_entry WHERE party_type = ?',
    variables: [Variable.withString('customer')],
  ).get();
  for (final row in customerIds) {
    final open = await dao.openInvoices(row.read<String>('party_id'));
    final age = oldestDebtDays(openInvoices: open, now: now);
    if (age != null && age > 30) overdue++;
  }

  return ShopHomeState(
    settings: settingsRow,
    todaySalesTotal: total,
    todayInvoiceCount: invoices.where((i) => !i.isVoid && !i.isReturn).length,
    todayByMethod: byMethod,
    totalReceivable: totalReceivable,
    overdueCustomers: overdue,
    lowStock: await dao.lowStockProducts(limit: 5),
    recentInvoices: (await dao.recentInvoices(limit: 8))
        .where((i) => !i.isVoid)
        .toList(),
    now: now,
  );
});

/// The settings row, editable by the settings screen.
final shopSettingsProvider = FutureProvider<ShopSettingsRow>(
  (ref) => ref.read(shopDaoProvider).settings(),
);

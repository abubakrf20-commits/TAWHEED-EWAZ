/// Pure domain logic for the stage-3 shop additions: purchases with moving
/// average, supplier FIFO/aging, the cheque state machine, cash-day math and
/// the report computations.
///
/// Same contract as the stage-2 core (docs/SHOP_DOMAIN.md): integers only,
/// rounding defined once (re-exported from shop_domain.dart), pure Dart, and
/// every rule here pinned by a test. Supplier ledger sign: + = the SHOP owes
/// the supplier.
library;

import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop_domain.dart';

export 'package:tawheeed/features/personal2/shop/domain/shop_domain.dart'
    show roundHalfUpDiv, lineTotalOf, roundingAdjustment, agingBuckets;

// ═══════════════════════════════════════════════════════════════════
// PURCHASES — extra-cost allocation and moving average
// ═══════════════════════════════════════════════════════════════════

/// One purchase line as the poster sees it.
class PurchaseLine {
  const PurchaseLine({
    required this.productId,
    required this.name,
    required this.qtyMilli,
    required this.unitCost,
    this.discount = 0,
    this.trackStock = true,
  });

  final String productId;
  final String name;

  /// Milli-units, positive.
  final int qtyMilli;

  /// Cost per ONE unit, before allocation and before this line's discount.
  final int unitCost;
  final int discount;
  final bool trackStock;

  int get lineTotal {
    final gross = lineTotalOf(qtyMilli: qtyMilli, unitPrice: unitCost);
    return gross - discount;
  }
}

/// Allocates [extraCost] across [lines] proportionally to line value, with
/// the largest-remainder rule so the parts sum to the whole EXACTLY
/// (an unallocated rial is a books-don't-close bug).
///
/// Returns one allocation per line, same order. Zero when [extraCost] is 0
/// or every line is worthless.
List<int> allocateExtraCosts(int extraCost, List<PurchaseLine> lines) {
  if (extraCost <= 0 || lines.isEmpty) {
    return List<int>.filled(lines.length, 0);
  }
  final values = lines.map((l) => l.lineTotal).toList();
  final total = values.fold<int>(0, (s, v) => s + v);
  if (total <= 0) {
    // Nothing to weight by: split evenly, largest remainder again.
    return _largestRemainder(extraCost, List<int>.filled(lines.length, 1));
  }
  return _largestRemainder(extraCost, values);
}

/// Largest-remainder allocation of [total] over [weights]: each part is
/// floor(total * w / Σw), then the leftover units go to the largest
/// fractional remainders (ties by index, deterministic).
List<int> _largestRemainder(int total, List<int> weights) {
  final sumW = weights.fold<int>(0, (s, w) => s + w);
  if (sumW <= 0) return List<int>.filled(weights.length, 0);
  final floors = <int>[];
  final remainders = <(int, double)>[];
  var used = 0;
  for (var i = 0; i < weights.length; i++) {
    final exact = total * weights[i] / sumW;
    final floor = exact.floor();
    floors.add(floor);
    used += floor;
    remainders.add((i, exact - floor));
  }
  var leftover = total - used;
  remainders.sort((a, b) {
    final byFrac = b.$2.compareTo(a.$2);
    return byFrac != 0 ? byFrac : a.$1.compareTo(b.$1);
  });
  final out = [...floors];
  for (var i = 0; leftover > 0 && i < remainders.length; i++, leftover--) {
    out[remainders[i].$1] += 1;
  }
  return out;
}

/// The landed cost per ONE unit (per 1000 milli) after allocation:
/// `(lineTotal + allocatedExtra) × 1000 / qtyMilli`, round-half-up. The ×1000
/// is the milli conversion — without it every landed cost silently divided by
/// the milli factor (caught by the moving-average test: 100500 came out 101).
int landedUnitCost({
  required int lineTotal,
  required int allocatedExtra,
  required int qtyMilli,
}) {
  if (qtyMilli <= 0) return 0;
  return roundHalfUpDiv((lineTotal + allocatedExtra) * 1000, qtyMilli);
}

/// The moving average after a purchase lands (SHOP_DOMAIN.md §Stage3):
/// `(oldQty*oldAvg + inQty*landed) / (oldQty + inQty)`; when the books' stock
/// is ≤ 0 the new cost IS the landed cost.
int avgCostAfterPurchase({
  required int currentStockMilli,
  required int currentAvgCost,
  required int inboundQtyMilli,
  required int landedUnitCost,
}) {
  if (inboundQtyMilli <= 0) return currentAvgCost;
  if (currentStockMilli <= 0) return landedUnitCost;
  return roundHalfUpDiv(
    currentStockMilli * currentAvgCost +
        inboundQtyMilli * landedUnitCost,
    currentStockMilli + inboundQtyMilli,
  );
}

/// The suggested sell price after a purchase: the new average cost with the
/// shop's margin, snapped to the rounding step.
int suggestedSellPrice({
  required int newAvgCost,
  required int marginPercent,
  required int roundingStep,
}) {
  if (newAvgCost <= 0) return 0;
  final raw = newAvgCost + roundHalfUpDiv(newAvgCost * marginPercent, 100);
  final step = roundingStep <= 1 ? 1 : roundingStep;
  return roundHalfUpDiv(raw, step) * step;
}

/// Margin percent of sell over cost, or null when the cost is 0.
int? marginPercentOf({required int cost, required int sell}) {
  if (cost <= 0) return null;
  return roundHalfUpDiv((sell - cost) * 100, cost);
}

/// A suggested-sell-price row for the post-purchase sheet.
class SellPriceSuggestion {
  const SellPriceSuggestion({
    required this.productId,
    required this.newAvgCost,
    required this.currentSellPrice,
    required this.suggestedSellPrice,
  });

  final String productId;
  final int newAvgCost;
  final int currentSellPrice;
  final int suggestedSellPrice;

  bool get marginNegative =>
      currentSellPrice > 0 && currentSellPrice < newAvgCost;
}

// ═══════════════════════════════════════════════════════════════════
// SUPPLIERS — FIFO allocation and aging (same maths as the customer side)
// ═══════════════════════════════════════════════════════════════════

/// One unpaid purchase on the supplier's book.
class OpenPurchase {
  const OpenPurchase({
    required this.purchaseId,
    required this.number,
    required this.date,
    required this.dueDate,
    required this.remaining,
  });

  final String purchaseId;
  final String number;
  final DateTime date;
  final DateTime? dueDate;
  final int remaining;
}

/// Allocates a supplier payment FIFO (oldest purchase first). The
/// allocation maths is the customer allocator; this wrapper just maps the
/// types so both sides share one tested implementation.
AllocationResult allocateSupplierPayment({
  required int payment,
  required List<OpenPurchase> openPurchases,
}) =>
    allocateFifo(
      payment: payment,
      openInvoices: [
        for (final p in openPurchases)
          OpenInvoice(
            invoiceId: p.purchaseId,
            number: p.number,
            date: p.date,
            remaining: p.remaining,
          ),
      ],
    );

/// Supplier aging from open purchases — buckets by the PURCHASE date (the
/// debt's birthday), matching the customer rule.
List<int> supplierAgingBuckets({
  required List<OpenPurchase> openPurchases,
  required DateTime now,
}) =>
    agingBucketsOf(
      openInvoices: [
        for (final p in openPurchases)
          OpenInvoice(
            invoiceId: p.purchaseId,
            number: p.number,
            date: p.date,
            remaining: p.remaining,
          ),
      ],
      now: now,
    );

/// Purchases whose due date falls within [days] — «سررسید نزدیک».
List<OpenPurchase> dueWithin({
  required List<OpenPurchase> openPurchases,
  required DateTime now,
  int days = 7,
}) {
  final end = now.add(Duration(days: days));
  return openPurchases
      .where((p) =>
          p.dueDate != null &&
          !p.dueDate!.isBefore(now) &&
          !p.dueDate!.isAfter(end))
      .toList();
}

// ═══════════════════════════════════════════════════════════════════
// CHEQUES — the state machine (SHOP_DOMAIN.md §Stage3)
// ═══════════════════════════════════════════════════════════════════

enum ChequeDirection { received('received'), issued('issued');

  const ChequeDirection(this.wire);
  final String wire;

  static ChequeDirection fromWire(String? value) {
    for (final d in ChequeDirection.values) {
      if (d.wire == value) return d;
    }
    return ChequeDirection.received;
  }
}

enum ChequeStatus {
  pending('pending', 'در جریان'),
  deposited('deposited', 'واگذارشده به بانک'),
  cleared('cleared', 'وصول شد'),
  bounced('bounced', 'برگشت خورد'),
  cancelled('cancelled', 'ابطال'),
  endorsed('endorsed', 'خرج چک');

  const ChequeStatus(this.wire, this.titleFa);
  final String wire;
  final String titleFa;

  static ChequeStatus fromWire(String? value) {
    for (final s in ChequeStatus.values) {
      if (s.wire == value) return s;
    }
    return ChequeStatus.pending;
  }
}

/// The allowed transitions. Anything not listed is refused — the state
/// machine is closed, not convention. Direction-aware rules (endorsed is
/// received-only; issued cannot be deposited) live in [canTransition].
const Map<ChequeStatus, Set<ChequeStatus>> chequeTransitions = {
  // received AND issued share the pending key; [canTransition] narrows the
  // issued side (no endorsed, no deposited).
  ChequeStatus.pending: {
    ChequeStatus.deposited,
    ChequeStatus.cleared,
    ChequeStatus.bounced,
    ChequeStatus.endorsed,
    ChequeStatus.cancelled,
  },
  ChequeStatus.deposited: {
    ChequeStatus.cleared,
    ChequeStatus.bounced,
    ChequeStatus.cancelled,
  },
  ChequeStatus.cleared: {},
  ChequeStatus.bounced: {},
  ChequeStatus.endorsed: {},
  ChequeStatus.cancelled: {},
};

/// Whether [from] → [to] is legal. Direction-aware: `endorsed` only exists on
/// received cheques.
bool canTransition({
  required ChequeDirection direction,
  required ChequeStatus from,
  required ChequeStatus to,
}) {
  if (to == ChequeStatus.endorsed && direction != ChequeDirection.received) {
    return false;
  }
  if (direction == ChequeDirection.issued) {
    // Issued cheques cannot be endorsed or deposited.
    if (to == ChequeStatus.endorsed || to == ChequeStatus.deposited) {
      return false;
    }
    if (from == ChequeStatus.pending) {
      return to == ChequeStatus.cleared ||
          to == ChequeStatus.bounced ||
          to == ChequeStatus.cancelled;
    }
    return false;
  }
  return chequeTransitions[from]?.contains(to) ?? false;
}

/// The bookkeeping effect of one legal transition — what the DAO writes.
enum ChequeEffect {
  /// Nothing moves (واگذاری به بانک): the money leaves «در جریان» for the
  /// bank bucket, but no ledger row changes.
  stateOnly,

  /// BOUNCE on a received cheque taken as payment: reverse the customer's
  /// payment (balance restored) + audit.
  reverseCustomerPayment,

  /// BOUNCE on an issued cheque: the supplier's balance rises again (the
  /// payment that settled it reverses) + audit.
  reverseSupplierPayment,

  /// CANCEL of a received cheque that WAS a payment: same reversal as a
  /// bounce (the customer still owes).
  reverseCustomerPaymentCancel,
}

ChequeEffect effectOf({
  required ChequeDirection direction,
  required ChequeStatus to,
  required bool wasUsedAsPayment,
}) {
  switch (to) {
    case ChequeStatus.bounced:
      return direction == ChequeDirection.received
          ? ChequeEffect.reverseCustomerPayment
          : ChequeEffect.reverseSupplierPayment;
    case ChequeStatus.cancelled:
      if (direction == ChequeDirection.received && wasUsedAsPayment) {
        return ChequeEffect.reverseCustomerPaymentCancel;
      }
      return ChequeEffect.stateOnly;
    default:
      return ChequeEffect.stateOnly;
  }
}

/// «چک در جریان» — received cheques not yet cleared/bounced/endorsed/
/// cancelled, plus issued ones still pending. The dashboard's totals.
int inFlightTotal({
  required int receivedPending,
  required int issuedPending,
}) =>
    receivedPending + issuedPending;

/// Cheques due within [days] from [now] (the reminder window: 7/3/0).
bool dueSoon({
  required DateTime dueDate,
  required DateTime now,
  int days = 7,
}) {
  final end = now.add(Duration(days: days));
  return !dueDate.isBefore(now) && !dueDate.isAfter(end);
}

// ═══════════════════════════════════════════════════════════════════
// CASH DAY (صندوق)
// ═══════════════════════════════════════════════════════════════════

/// The expected drawer cash for a day — the ONLY formula, shared by the
/// dashboard and verifyIntegrity:
/// opening + cash-in − cash-out ± adjustments. Only method=cash counts.
int expectedCash({
  required int openingCash,
  required int cashIn,
  required int cashOut,
  required int adjustments,
}) {
  final total = openingCash + cashIn - cashOut + adjustments;
  // A drawer cannot go below zero through honest arithmetic; a negative
  // expectation means an outflow was recorded without an opening — surface
  // it as 0 and let the difference expose it rather than hiding the sign.
  return total < 0 ? 0 : total;
}

/// The difference at close: counted − expected. Zero is good; anything else
/// is RECORDED, never auto-corrected (SHOP_DOMAIN.md §Stage3).
int cashDifference({required int countedCash, required int expectedCash}) =>
    countedCash - expectedCash;

/// The Jalali day key a cash day belongs to (local midnight epoch of the
/// day's START) — the same boundary every "today" query uses.
DateTime cashDayStart(DateTime instant) {
  final local = instant.toLocal();
  return DateTime(local.year, local.month, local.day);
}

// ═══════════════════════════════════════════════════════════════════
// EXPENSES
// ═══════════════════════════════════════════════════════════════════

/// The default expense categories (editable in the tool).
const List<String> defaultExpenseCategories = [
  'اجاره',
  'برق',
  'آب و گاز',
  'تلفن و اینترنت',
  'حقوق',
  'حمل و نقل',
  'تعمیرات',
  'بسته‌بندی',
  'سایر',
];

/// The next Jalali occurrence of a recurring rule's day-of-month, month-end
/// safe: a rule on روز ۳۰ in a ۲۹-day month lands on the month's last day.
DateTime nextRecurringOccurrence({
  required int dayOfMonth,
  required DateTime now,
}) {
  final j = _toJalali(now);
  for (var monthOffset = 0; monthOffset < 13; monthOffset++) {
    var month = j.month + monthOffset;
    var year = j.year;
    while (month > 12) {
      month -= 12;
      year += 1;
    }
    final monthLen = _jalaliMonthLength(year, month);
    final day = dayOfMonth > monthLen ? monthLen : dayOfMonth;
    final candidate = _fromJalali(year, month, day);
    // The occurrence's day is "active" through its end: a reminder set for
    // day 24 still fires at 18:00 on day 24.
    final dayEnd = candidate.add(const Duration(days: 1));
    if (dayEnd.isAfter(now)) {
      return candidate;
    }
  }
  // Unreachable for any realistic clock.
  return now;
}

/// Whether the recurring rule should remind NOW: the target day arrived and
/// this period's reminder has not been marked.
bool shouldRemindRecurring({
  required int dayOfMonth,
  required DateTime now,
  required String lastRemindedKey,
}) {
  final occurrence = nextRecurringOccurrence(dayOfMonth: dayOfMonth, now: now);
  final key = '${occurrence.year}-${occurrence.month}';
  if (lastRemindedKey == key) return false;
  final j = _toJalali(now);
  final isTargetMonth = j.year == occurrence.year && j.month == occurrence.month;
  return isTargetMonth && j.day >= _toJalali(occurrence).day;
}

/// The period key a reminder marks («1404-08»).
String recurringPeriodKey(DateTime forDate) {
  final j = _toJalali(forDate);
  return '${j.year}-${j.month}';
}

// ── Jalali conversion via shamsi_date (the app's own dependency — the
// same one the kids tool uses). A hand-rolled algorithm was tried here and
// produced wrong months; the shared package is the single source of truth.

({int year, int month, int day}) _toJalali(DateTime g) {
  final j = Jalali.fromDateTime(g);
  return (year: j.year, month: j.month, day: j.day);
}

DateTime _fromJalali(int jy, int jm, int jd) =>
    Jalali(jy, jm, jd).toDateTime();

int _jalaliMonthLength(int year, int month) =>
    Jalali(year, month).monthLength;

// ═══════════════════════════════════════════════════════════════════
// REPORTS — computed from immutable rows via SQL aggregates (the caller
// hands in the aggregate results; this file only shapes them)
// ═══════════════════════════════════════════════════════════════════

/// The period report's core figures (SHOP_DOMAIN.md §Reports).
class ReportFigures {
  const ReportFigures({
    required this.grossSales,
    required this.returnTotal,
    required this.discountTotal,
    required this.cogs,
    required this.expenseTotal,
  });

  /// Σ posted sale invoice totals (before returns).
  final int grossSales;
  final int returnTotal;
  final int discountTotal;

  /// Σ item cost snapshots of the period's sales.
  final int cogs;
  final int expenseTotal;

  /// Net sales = sales − returns − discounts.
  int get netSales => grossSales - returnTotal - discountTotal;

  /// برآورد سود ناخالص.
  int get grossProfit => netSales - cogs;

  /// برآورد سود خالص.
  int get netProfit => grossProfit - expenseTotal;

  /// Stock valuation: Σ qty × avgCost.
  static int stockValuation(Iterable<({int stockMilli, int avgCost})> items) =>
      items.fold(
          0,
          (s, i) =>
              s + roundHalfUpDiv(i.stockMilli * i.avgCost, 1000));

  /// Potential sales value: Σ qty × sellPrice.
  static int potentialSalesValue(
          Iterable<({int stockMilli, int sellPrice})> items) =>
      items.fold(
          0,
          (s, i) =>
              s + roundHalfUpDiv(i.stockMilli * i.sellPrice, 1000));
}

/// Slow movers: products with no sale in [days] (tracked, active).
List<String> slowMovers({
  required List<({String id, int? lastSoldAtMs})> products,
  required DateTime now,
  required int days,
}) {
  final cutoff = now.subtract(Duration(days: days)).millisecondsSinceEpoch;
  return [
    for (final p in products)
      if (p.lastSoldAtMs == null || p.lastSoldAtMs! < cutoff) p.id,
  ];
}

/// Period comparison: this vs previous.
class PeriodComparison {
  const PeriodComparison({required this.current, required this.previous});

  final int current;
  final int previous;

  /// Percent change, or null when the previous period had nothing to compare.
  int? get percentChange {
    if (previous == 0) return null;
    return roundHalfUpDiv((current - previous) * 100, previous.abs());
  }
}

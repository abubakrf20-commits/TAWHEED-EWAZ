/// Pure domain logic for «حساب مغازه» — the accounting core.
///
/// THE two rules that make this file accounting rather than arithmetic:
///  • MONEY is `int` (the app's smallest displayed unit). No `double` exists
///    in any money path — not in the models, not in the maths, not in the
///    tests' expected values.
///  • QUANTITY is `int` milli-units (thousandths): 0.5 kg = 500.
///
/// Every rule here is also stated in docs/SHOP_DOMAIN.md; this file is where
/// the tests hold it. Nothing imports Flutter or the database: the caller
/// hands in records, this file computes, and the DAO writes — which is what
/// makes the property-style invariant tests possible.
///
/// RELIGIOUS SCOPE: trade records only. No interest/usury calculation of any
/// kind exists anywhere in this feature.
library;

import 'package:tawheeed/shared/utils/number_format.dart';

/// ─────────────────────────────────────────────────────────────────
/// Fixed-point arithmetic — the ONLY place rounding is defined.
/// ─────────────────────────────────────────────────────────────────

/// Round-half-up of [numerator] / [denominator], on the absolute value with
/// the sign re-applied.
///
/// Round-half-up (نه round-half-even، نه banker's): 0.5 rounds AWAY from
/// zero. The sign is handled by symmetry so a sale line of −1500.5 and its
/// void reversal round to exactly opposite integers — `void` restores the
/// prior state exactly, which the tests pin.
int roundHalfUpDiv(int numerator, int denominator) {
  assert(denominator > 0, 'denominator must be positive');
  if (numerator >= 0) {
    return (2 * numerator + denominator) ~/ (2 * denominator);
  }
  return -roundHalfUpDiv(-numerator, denominator);
}

/// Line total: round-half-up of `qtyMilli * unitPrice / 1000`.
///
/// 0.333 kg × 2,500 = 832.5 → 833. The multiplication happens in int64 —
/// a 60,000-milli (60 kg) line at a 9,999,999,999 price is still ~6e14,
/// far below the 9.2e18 int64 ceiling, so no intermediate overflow is
/// possible for any realistic shop entry.
int lineTotalOf({required int qtyMilli, required int unitPrice}) {
  assert(qtyMilli != 0, 'a line with zero quantity must be dropped earlier');
  return roundHalfUpDiv(qtyMilli * unitPrice, 1000);
}

/// Rounds [amount] to the nearest [step] (round-half-up), returning the
/// adjustment to ADD to reach it.
///
/// `step == 0` means «none»: the adjustment is always 0. 1,456 with step
/// 100 → rounded 1,500 → adjustment +44.
int roundingAdjustment(int amount, int step) {
  if (step <= 1) return 0;
  final rounded = roundHalfUpDiv(amount, step) * step;
  return rounded - amount;
}

/// One cart line, immutable — what the POS builds and the poster validates.
class CartLine {
  const CartLine({
    required this.productId,
    required this.name,
    required this.unitName,
    required this.qtyMilli,
    required this.unitPrice,
    this.discount = 0,
    this.trackStock = true,
    this.avgCost = 0,
  });

  final String productId;
  final String name;
  final String unitName;

  /// Milli-units, always positive on a sale line (returns are separate
  /// documents, not negative lines).
  final int qtyMilli;

  /// Price per ONE unit (per 1000 milli).
  final int unitPrice;

  /// Stored as an amount, never a percent.
  final int discount;

  final bool trackStock;

  /// The product's avgCost at cart time; the poster re-reads it inside the
  /// transaction, so this is display-only.
  final int avgCost;

  int get lineTotal {
    final gross = lineTotalOf(qtyMilli: qtyMilli, unitPrice: unitPrice);
    return gross - discount;
  }
}

/// A payment recorded with the sale.
class SalePayment {
  const SalePayment({
    required this.method,
    required this.amount,
  });

  final PaymentMethod method;

  /// Always positive; `direction` is implied by the document.
  final int amount;
}

enum PaymentMethod {
  cash('cash', 'نقد'),
  card('card', 'کارت'),
  transfer('transfer', 'انتقال'),
  cheque('cheque', 'چک'),
  other('other', 'سایر');

  const PaymentMethod(this.wire, this.titleFa);
  final String wire;
  final String titleFa;

  static PaymentMethod fromWire(String? value) {
    for (final m in PaymentMethod.values) {
      if (m.wire == value) return m;
    }
    return PaymentMethod.cash;
  }
}

enum CreditLimitMode {
  off('off'),
  warn('warn'),
  block('block');

  const CreditLimitMode(this.wire);
  final String wire;

  static CreditLimitMode fromWire(String? value) {
    for (final m in CreditLimitMode.values) {
      if (m.wire == value) return m;
    }
    return CreditLimitMode.warn;
  }
}

/// The verdict on a sale's credit portion. Returned by [evaluateSale] so the
/// UI can warn (and require a confirmation) or block, per the settings.
enum CreditVerdict { ok, requiresCustomer, warnOverLimit, blockedOverLimit }

/// Everything the poster needs to know about a sale, computed BEFORE any
/// write: totals, rounding, credit portion and the credit-limit verdict.
class SaleEvaluation {
  const SaleEvaluation({
    required this.lines,
    required this.subtotal,
    required this.discountTotal,
    required this.roundingAdj,
    required this.total,
    required this.paidTotal,
    required this.creditPortion,
    required this.verdict,
    this.problem,
  });

  final List<CartLine> lines;
  final int subtotal;
  final int discountTotal;
  final int roundingAdj;
  final int total;
  final int paidTotal;

  /// `total - paidTotal`. Positive = on credit. Never negative: overpayment
  /// beyond the total is refused at validation (a prepayment is a customer
  /// ledger entry, not a negative invoice field).
  final int creditPortion;
  final CreditVerdict verdict;

  /// Persian, user-facing reason when the sale cannot post.
  final String? problem;

  bool get canPost =>
      verdict != CreditVerdict.blockedOverLimit &&
      verdict != CreditVerdict.requiresCustomer &&
      problem == null;
}

/// Computes the whole sale without touching the database.
///
/// [customerBalance] is the customer's current ledger sum (+ = owes). The
/// limit check compares the balance AFTER this sale's credit portion lands.
SaleEvaluation evaluateSale({
  required List<CartLine> lines,
  required List<SalePayment> payments,
  required int roundingStep,
  required CreditLimitMode creditMode,
  int? customerBalance,
  int? customerCreditLimit,
  bool hasCustomer = false,
}) {
  // Drop zero-quantity lines: they are UI noise, and a zero line would make
  // the invoice's arithmetic lie by adding a row that changes nothing.
  final usable = [
    for (final l in lines)
      if (l.qtyMilli > 0) l,
  ];
  if (usable.isEmpty) {
    return const SaleEvaluation(
      lines: [],
      subtotal: 0,
      discountTotal: 0,
      roundingAdj: 0,
      total: 0,
      paidTotal: 0,
      creditPortion: 0,
      verdict: CreditVerdict.ok,
      problem: 'سبد خالی است.',
    );
  }
  for (final l in usable) {
    if (l.unitPrice < 0 || l.discount < 0) {
      return SaleEvaluation(
        lines: usable,
        subtotal: 0,
        discountTotal: 0,
        roundingAdj: 0,
        total: 0,
        paidTotal: 0,
        creditPortion: 0,
        verdict: CreditVerdict.ok,
        problem: 'قیمت یا تخفیف منفی مجاز نیست.',
      );
    }
    if (l.discount >
        lineTotalOf(qtyMilli: l.qtyMilli, unitPrice: l.unitPrice)) {
      return SaleEvaluation(
        lines: usable,
        subtotal: 0,
        discountTotal: 0,
        roundingAdj: 0,
        total: 0,
        paidTotal: 0,
        creditPortion: 0,
        verdict: CreditVerdict.ok,
        problem: 'تخفیف «${l.name}» از مبلغ سطر بیشتر است.',
      );
    }
  }

  final subtotal = usable.fold<int>(0, (s, l) => s + l.lineTotal + l.discount);
  final discountTotal = usable.fold<int>(0, (s, l) => s + l.discount);
  final exactTotal = subtotal - discountTotal;
  final adj = roundingAdjustment(exactTotal, roundingStep);
  final total = exactTotal + adj;

  final paidTotal = payments.fold<int>(0, (s, p) => s + p.amount);
  if (paidTotal > total) {
    return SaleEvaluation(
      lines: usable,
      subtotal: subtotal,
      discountTotal: discountTotal,
      roundingAdj: adj,
      total: total,
      paidTotal: paidTotal,
      creditPortion: 0,
      verdict: CreditVerdict.ok,
      problem: 'پرداخت بیشتر از مبلغ قابل پرداخت است؛ پیش‌پرداخت از صفحهٔ '
          'مشتری ثبت می‌شود.',
    );
  }
  final credit = total - paidTotal;

  var verdict = CreditVerdict.ok;
  String? problem;
  if (credit > 0 && !hasCustomer) {
    verdict = CreditVerdict.requiresCustomer;
    problem = 'برای فروش نسیه اول مشتری را انتخاب کنید.';
  } else if (credit > 0 && creditMode != CreditLimitMode.off) {
    final balanceAfter = (customerBalance ?? 0) + credit;
    if (customerCreditLimit != null &&
        customerCreditLimit > 0 &&
        balanceAfter > customerCreditLimit) {
      verdict = creditMode == CreditLimitMode.block
          ? CreditVerdict.blockedOverLimit
          : CreditVerdict.warnOverLimit;
    }
  }

  return SaleEvaluation(
    lines: usable,
    subtotal: subtotal,
    discountTotal: discountTotal,
    roundingAdj: adj,
    total: total,
    paidTotal: paidTotal,
    creditPortion: credit,
    verdict: verdict,
    problem: problem,
  );
}

/// ─────────────────────────────────────────────────────────────────
/// Receivables — FIFO allocation and aging
/// ─────────────────────────────────────────────────────────────────

/// One open invoice as the allocator sees it: the credit portion still
/// unpaid, oldest first.
class OpenInvoice {
  const OpenInvoice({
    required this.invoiceId,
    required this.number,
    required this.date,
    required this.remaining,
  });

  final String invoiceId;
  final String number;

  /// Epoch ms — allocation and aging both read this.
  final DateTime date;

  /// Credit portion not yet covered by allocations.
  final int remaining;
}

/// Where one payment lands. The preview list is exactly this, shown before
/// the parent confirms.
class AllocationSlice {
  const AllocationSlice({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.amount,
  });

  final String invoiceId;
  final String invoiceNumber;
  final int amount;
}

/// The result of allocating one inbound payment FIFO.
class AllocationResult {
  const AllocationResult({
    required this.slices,
    required this.advance,
  });

  /// Oldest first. Every slice ≤ its invoice's remaining.
  final List<AllocationSlice> slices;

  /// What could not land on any invoice: a prepayment/advance that stays on
  /// the customer's ledger as a negative (بستانکار). Zero when fully consumed.
  final int advance;

  int get allocated => slices.fold<int>(0, (s, x) => s + x.amount);
}

/// Allocates [payment] FIFO across [openInvoices] (given in any order; sorted
/// here by date then invoice id so the result is deterministic).
AllocationResult allocateFifo({
  required int payment,
  required List<OpenInvoice> openInvoices,
}) {
  assert(payment > 0, 'a payment is positive; direction lives elsewhere');
  final sorted = [...openInvoices]..sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.invoiceId.compareTo(b.invoiceId);
    });

  var left = payment;
  final slices = <AllocationSlice>[];
  for (final inv in sorted) {
    if (left <= 0) break;
    if (inv.remaining <= 0) continue;
    final take = left < inv.remaining ? left : inv.remaining;
    slices.add(AllocationSlice(
      invoiceId: inv.invoiceId,
      invoiceNumber: inv.number,
      amount: take,
    ));
    left -= take;
  }
  return AllocationResult(slices: slices, advance: left);
}

/// The aging bucket labels, in display order.
const List<(String, int)> agingBuckets = [
  ('۰ تا ۳۰ روز', 30),
  ('۳۱ تا ۶۰ روز', 60),
  ('۶۱ تا ۹۰ روز', 90),
  ('بیش از ۹۰ روز', 1 << 40),
];

/// Aging buckets computed FIFO from open invoices' remaining credit portions.
///
/// An invoice's age is measured from ITS date to [now] — the money is as old
/// as the sale that created it, not as old as the last payment.
List<int> agingBucketsOf({
  required List<OpenInvoice> openInvoices,
  required DateTime now,
}) {
  final buckets = List<int>.filled(agingBuckets.length, 0);
  for (final inv in openInvoices) {
    if (inv.remaining <= 0) continue;
    final days = now.difference(inv.date).inDays;
    final age = days < 0 ? 0 : days;
    for (var i = 0; i < agingBuckets.length; i++) {
      if (age <= agingBuckets[i].$2) {
        buckets[i] += inv.remaining;
        break;
      }
    }
  }
  return buckets;
}

/// Days since the OLDEST open invoice — the «بدهی قدیمی» chip.
int? oldestDebtDays({
  required List<OpenInvoice> openInvoices,
  required DateTime now,
}) {
  DateTime? oldest;
  for (final inv in openInvoices) {
    if (inv.remaining <= 0) continue;
    if (oldest == null || inv.date.isBefore(oldest)) oldest = inv.date;
  }
  if (oldest == null) return null;
  final days = now.difference(oldest).inDays;
  return days < 0 ? 0 : days;
}

/// ─────────────────────────────────────────────────────────────────
/// Stock
/// ─────────────────────────────────────────────────────────────────

enum StockMovementType {
  opening('opening', 'افتتاحیه'),
  sale('sale', 'فروش'),
  saleReturn('sale_return', 'برگشت فروش'),
  adjustment('adjustment', 'تعدیل'),
  purchase('purchase', 'خرید'),
  purchaseReturn('purchase_return', 'برگشت خرید');

  const StockMovementType(this.wire, this.titleFa);
  final String wire;
  final String titleFa;

  /// The sign a movement of this type carries (the caller supplies the
  /// magnitude; returns/adjustments can go either way).
  bool get isOutbound => this == StockMovementType.sale;
}

/// Running-average cost after applying one inbound movement.
///
/// avgCost_new = (|currentStock| * avgCost + inboundQty * unitCost)
///               / (|currentStock| + inboundQty),  rounded half-up.
/// With zero prior stock the inbound cost IS the new average. Outbound
/// movements never change avgCost.
int avgCostAfter({
  required int currentStockMilli,
  required int currentAvgCost,
  required int inboundQtyMilli,
  required int inboundUnitCost,
}) {
  if (inboundQtyMilli <= 0) return currentAvgCost;
  final stockAbs =
      currentStockMilli < 0 ? -currentStockMilli : currentStockMilli;
  final totalQty = stockAbs + inboundQtyMilli;
  if (totalQty <= 0) return currentAvgCost;
  return roundHalfUpDiv(
    stockAbs * currentAvgCost + inboundQtyMilli * inboundUnitCost,
    totalQty,
  );
}

/// Whether the product counts as low-stock: at/below its own minimum, or the
/// tool's default when it has none. Untracked products are never low-stock.
bool isLowStock({
  required bool trackStock,
  required int stockMilli,
  required int? minStockMilli,
  required int lowStockDefaultUnits,
}) {
  if (!trackStock) return false;
  final floorMilli = (minStockMilli ?? lowStockDefaultUnits * 1000);
  return stockMilli <= floorMilli;
}

/// Formats milli-units for the UI: 1500 → «۱٫۵» when fractional, else «1500».
/// Latin digits per the product standard; the caller adds the unit symbol.
String qtyMilliToText(int milli) {
  // Work on the magnitude and apply the sign once: Dart's `~/` truncates
  // toward zero, so -1500 ~/ 1000 is already -1 and naively prefixing a sign
  // produced «--1.5» (caught by the round-trip test).
  final sign = milli < 0 ? '-' : '';
  final abs = milli < 0 ? -milli : milli;
  if (abs % 1000 == 0) return '$sign${abs ~/ 1000}';
  final whole = abs ~/ 1000;
  final fracText = (abs % 1000).toString().padLeft(3, '0');
  final trimmed = fracText.replaceAll(RegExp(r'0+$'), '');
  return '$sign$whole.$trimmed';
}

/// Parses user quantity input («1.5», «1,5», «۱٫۵») into milli-units, or null
/// when it is not a valid non-negative quantity.
int? parseQtyToMilli(String input) {
  // The Arabic decimal separator (٫) is what a Persian keyboard produces, and
  // a comma is the Latin habit; both normalize to '.'. A negative parse is
  // allowed — adjustment screens enter them — and positivity is enforced by
  // the sale layer, not the parser.
  var text = input
      .trim()
      .replaceAll(',', '.')
      .replaceAll('٫', '.')
      .replaceAll('٬', '.');
  text = _faToAsciiDigits(text);
  if (text.isEmpty) return null;
  // Sign applies to the WHOLE quantity: parsing «-1.5» as -(1) + 0.5 would
  // yield -500 instead of -1500 (caught by the round-trip test).
  final isNegative = text.startsWith('-');
  if (isNegative) text = text.substring(1);
  if (text.isEmpty) return null;
  final parts = text.split('.');
  final whole = int.tryParse(parts[0].isEmpty ? '0' : parts[0]);
  if (whole == null) return null;
  var milli = 0;
  if (parts.length == 2) {
    final fracRaw = parts[1];
    if (fracRaw.length > 3) return null; // sub-milli precision is noise
    final frac = int.tryParse(fracRaw.padRight(3, '0'));
    if (frac == null || frac < 0) return null;
    milli = frac;
  } else if (parts.length > 2) {
    return null;
  }
  final magnitude = whole * 1000 + milli;
  return isNegative ? -magnitude : magnitude;
}

/// Persian/Arabic-Indic digits → ASCII (the shared normalizer handles search;
/// quantity parsing needs the same tolerance locally).
String _faToAsciiDigits(String input) {
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  const ar = '٠١٢٣٤٥٦٧٨٩';
  final out = StringBuffer();
  for (final ch in input.runes) {
    final c = String.fromCharCode(ch);
    final faIdx = fa.indexOf(c);
    if (faIdx >= 0) {
      out.write(faIdx);
      continue;
    }
    final arIdx = ar.indexOf(c);
    if (arIdx >= 0) {
      out.write(arIdx);
      continue;
    }
    out.write(c);
  }
  return out.toString();
}

/// ─────────────────────────────────────────────────────────────────
/// Reminder message templates (polite, editable; the app never sends)
/// ─────────────────────────────────────────────────────────────────

/// Builds the polite reminder text from one of three shipped variants.
///
/// The amount is the customer's balance (what they owe); the app opens the
/// system share sheet — it never sends anything itself.
String reminderMessage({
  required int variant,
  required String customerName,
  required int balance,
  required String oldestDateFa,
  required String shopName,
  String unit = 'تومان',
}) {
  // Grouped and in the user's unit: the reminder was the one shop path that
  // printed «1250000» and a hardcoded currency word.
  final amountText = NumberFormat.grouped(balance);
  switch (variant % 3) {
    case 0:
      return 'با سلام و احترام\n'
          '$customerName عزیز،\n'
          'به‌طور خلاصه ماندهٔ حساب شما نزد $shopName مبلغ $amountText $unit '
          'است (قدیمی‌ترین سند: $oldestDateFa). در صورت تسویه یا هرگونه '
          'پرسش، خوشحال می‌شویم با ما در تماس باشید.\n'
          'با سپاس — $shopName';
    case 1:
      return '$customerName گرامی، روز بخیر.\n'
          'یادآوری مهربانانه: ماندهٔ فعلی حساب شما $amountText $unit است '
          '(قدیمی‌ترین سند: $oldestDateFa). اگر قبلاً تسویه کرده‌اید، همین '
          'پیام را نادیده بگیرید.\n'
          'احتراماً — $shopName';
    default:
      return 'سلام علیکم\n'
          '$customerName عزیز؛ در جریان باشید ماندهٔ حساب شما نزد $shopName '
          '$amountText $unit ثبت شده است (قدیمی‌ترین سند: $oldestDateFa). '
          'وقت تسویه به دستتان رسیده باشد ممنون می‌شویم.\n'
          'با احترام — $shopName';
  }
}

/// One price after a bulk change: a percent (``+10`` → +10 %) or an absolute
/// per-unit delta, then snapped to the shop's [roundingStep] exactly the way
/// [suggestedSellPrice] snaps (500 → 1,000 step = 1,000).
///
/// The result may be negative for a large negative delta; callers skip those
/// rows instead of writing a negative price, so the function stays pure and
/// there is one arithmetic definition for the DAO and the sheet's preview.
int bulkPriceAfter({
  required int price,
  required int delta,
  required bool percent,
  required int roundingStep,
}) {
  final raw =
      percent ? price + roundHalfUpDiv(price * delta, 100) : price + delta;
  final step = roundingStep <= 1 ? 1 : roundingStep;
  return roundHalfUpDiv(raw, step) * step;
}

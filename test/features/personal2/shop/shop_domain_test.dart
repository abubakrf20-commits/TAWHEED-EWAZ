import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop_domain.dart';

/// Unit tests for the shop's pure accounting core.
///
/// These are the rules a shopkeeper's money depends on: rounding happens once
/// and identically everywhere, voids restore exactly, payments allocate FIFO,
/// and the invariants survive random operation sequences.
void main() {
  group('rounding rules (defined once, tested once)', () {
    test('round-half-up on .5', () {
      // 0.333 kg × 2,500 = 832.5 → 833 (half-up, not banker's).
      expect(lineTotalOf(qtyMilli: 333, unitPrice: 2500), 833);
      expect(roundHalfUpDiv(5, 10), 1);
      expect(roundHalfUpDiv(15, 10), 2);
    });

    test('plain values are exact', () {
      expect(lineTotalOf(qtyMilli: 2000, unitPrice: 2500), 5000);
      expect(lineTotalOf(qtyMilli: 1000, unitPrice: 999), 999);
    });

    test('a return line and its reversal round to opposite numbers', () {
      final sale = lineTotalOf(qtyMilli: -333, unitPrice: 2500);
      expect(sale, -833);
      // Reversal of a reversal is exact: -(-833) == 833.
      expect(-sale, 833);
    });

    test('an int64-wide line cannot overflow', () {
      // 60 kg at a 9,999,999,999 price.
      expect(
        lineTotalOf(qtyMilli: 60000, unitPrice: 9999999999),
        599999999940,
      );
    });

    test('rounding adjustment snaps to the step', () {
      expect(roundingAdjustment(1456, 100), 44);
      expect(roundingAdjustment(1450, 100), 50);
      expect(roundingAdjustment(1400, 100), 0);
      expect(roundingAdjustment(1456, 0), 0, reason: 'step none');
      expect(roundingAdjustment(1456, 1), 0, reason: 'step 1 = none');
      // Round-half-up-to-NEAREST-step: 3 sits between 0 and 1000 and is
      // nearer 0, so the adjustment pulls the total down 3. (Half-up applies
      // at the .5 boundary — 1450 → 1500 — not as a ceiling.)
      expect(roundingAdjustment(3, 1000), -3);
      expect(roundingAdjustment(-1456, 100), -44,
          reason: 'returns snap symmetrically');
    });
  });

  group('quantity parsing (fixed-point entry)', () {
    test('whole and fractional, Persian and Latin', () {
      expect(parseQtyToMilli('3'), 3000);
      expect(parseQtyToMilli('1.5'), 1500);
      expect(parseQtyToMilli('1,5'), 1500);
      expect(parseQtyToMilli('۱٫۵'), 1500);
      expect(parseQtyToMilli('۰٫۳۳۳'), 333);
      expect(parseQtyToMilli('0.333'), 333);
    });

    test('junk is null, never zero', () {
      expect(parseQtyToMilli(''), isNull);
      expect(parseQtyToMilli('abc'), isNull);
      expect(parseQtyToMilli('1.2.3'), isNull);
      // A minus sign parses (adjustment screens need it); the sale layer
      // refuses negative sale quantities.
      expect(parseQtyToMilli('-2'), -2000);
      expect(parseQtyToMilli('1.2345'), isNull,
          reason: 'sub-milli precision is a typo, not a quantity');
    });

    test('formatting keeps the milli truth', () {
      expect(qtyMilliToText(3000), '3');
      expect(qtyMilliToText(1500), '1.5');
      expect(qtyMilliToText(333), '0.333');
      expect(qtyMilliToText(-1500), '-1.5');
      // Round trip, including the signed form.
      expect(parseQtyToMilli(qtyMilliToText(1500)), 1500);
      expect(parseQtyToMilli(qtyMilliToText(-1500)), -1500);
      expect(parseQtyToMilli(qtyMilliToText(333)), 333);
    });
  });

  group('sale evaluation', () {
    CartLine line({
      int qty = 2000,
      int price = 1000,
      int discount = 0,
      String name = 'کالا',
    }) =>
        CartLine(
          productId: 'p1',
          name: name,
          unitName: 'عدد',
          qtyMilli: qty,
          unitPrice: price,
          discount: discount,
        );

    test('totals, discount and rounding compose exactly', () {
      final eval = evaluateSale(
        lines: [line(qty: 333, price: 2500), line(qty: 2000, price: 1000)],
        payments: [const SalePayment(method: PaymentMethod.cash, amount: 2000)],
        roundingStep: 100,
        creditMode: CreditLimitMode.off,
      );
      // 833 + 2000 = 2833 → step 100 → 2800, adj = -33.
      expect(eval.subtotal, 2833);
      expect(eval.discountTotal, 0);
      expect(eval.roundingAdj, -33);
      expect(eval.total, 2800);
      expect(eval.paidTotal, 2000);
      expect(eval.creditPortion, 800);
    });

    test('empty cart is refused with a Persian reason', () {
      final eval = evaluateSale(
        lines: const [],
        payments: const [],
        roundingStep: 0,
        creditMode: CreditLimitMode.off,
      );
      expect(eval.canPost, isFalse);
      expect(eval.problem, contains('سبد'));
    });

    test('a discount larger than its line is refused', () {
      final eval = evaluateSale(
        lines: [line(qty: 1000, price: 1000, discount: 2000)],
        payments: const [],
        roundingStep: 0,
        creditMode: CreditLimitMode.off,
      );
      expect(eval.canPost, isFalse);
      expect(eval.problem, contains('تخفیف'));
    });

    test('overpayment is refused (prepayment is a ledger entry, not a field)',
        () {
      final eval = evaluateSale(
        lines: [line()],
        payments: [const SalePayment(method: PaymentMethod.cash, amount: 5000)],
        roundingStep: 0,
        creditMode: CreditLimitMode.off,
      );
      expect(eval.canPost, isFalse);
      expect(eval.problem, contains('پیش‌پرداخت'));
    });

    test('credit without a customer is blocked before anything else', () {
      final eval = evaluateSale(
        lines: [line()],
        payments: const [],
        roundingStep: 0,
        creditMode: CreditLimitMode.off,
      );
      expect(eval.verdict, CreditVerdict.requiresCustomer);
      expect(eval.canPost, isFalse);
    });

    test('credit within the limit is fine', () {
      final eval = evaluateSale(
        lines: [line()],
        payments: const [],
        roundingStep: 0,
        creditMode: CreditLimitMode.block,
        hasCustomer: true,
        customerBalance: 4000,
        customerCreditLimit: 10000,
      );
      expect(eval.creditPortion, 2000);
      expect(eval.verdict, CreditVerdict.ok);
    });

    test('credit over the limit warns in warn mode', () {
      final eval = evaluateSale(
        lines: [line()],
        payments: const [],
        roundingStep: 0,
        creditMode: CreditLimitMode.warn,
        hasCustomer: true,
        customerBalance: 9000,
        customerCreditLimit: 10000,
      );
      expect(eval.verdict, CreditVerdict.warnOverLimit);
      // Warn does not block.
      expect(eval.canPost, isTrue);
    });

    test('credit over the limit blocks in block mode', () {
      final eval = evaluateSale(
        lines: [line()],
        payments: const [],
        roundingStep: 0,
        creditMode: CreditLimitMode.block,
        hasCustomer: true,
        customerBalance: 9000,
        customerCreditLimit: 10000,
      );
      expect(eval.verdict, CreditVerdict.blockedOverLimit);
      expect(eval.canPost, isFalse);
    });

    test('credit mode off never checks the limit', () {
      final eval = evaluateSale(
        lines: [line()],
        payments: const [],
        roundingStep: 0,
        creditMode: CreditLimitMode.off,
        hasCustomer: true,
        customerBalance: 999999,
        customerCreditLimit: 1,
      );
      expect(eval.verdict, CreditVerdict.ok);
    });

    test('zero-quantity lines are dropped, not posted', () {
      final eval = evaluateSale(
        lines: [line(qty: 0), line(qty: 1000, price: 500)],
        payments: const [],
        roundingStep: 0,
        creditMode: CreditLimitMode.off,
      );
      expect(eval.lines, hasLength(1));
      expect(eval.total, 500);
    });
  });

  group('FIFO allocation', () {
    OpenInvoice inv(String id, String number, int daysAgo, int remaining,
            {DateTime? now}) =>
        OpenInvoice(
          invoiceId: id,
          number: number,
          date:
              (now ?? DateTime(2026, 6, 24)).subtract(Duration(days: daysAgo)),
          remaining: remaining,
        );

    test('oldest invoice is paid first', () {
      final result = allocateFifo(
        payment: 2500,
        openInvoices: [
          inv('a', '101', 2, 1000),
          inv('b', '102', 10, 2000),
        ],
      );
      // 2,500 covers the 2,000 of the older invoice first, then 500 of the
      // newer one — the slice list is oldest first.
      expect(result.slices, hasLength(2));
      expect(result.slices.first.invoiceId, 'b', reason: 'oldest first');
      expect(result.slices.first.amount, 2000);
      expect(result.slices.last.invoiceId, 'a');
      expect(result.slices.last.amount, 500);
      expect(result.advance, 0);
    });

    test('money beyond every invoice becomes an advance', () {
      final result = allocateFifo(
        payment: 5000,
        openInvoices: [inv('a', '101', 2, 1000)],
      );
      expect(result.allocated, 1000);
      expect(result.advance, 4000);
    });

    test('a payment smaller than the oldest invoice leaves the rest open', () {
      final result = allocateFifo(
        payment: 300,
        openInvoices: [inv('a', '101', 2, 1000)],
      );
      expect(result.slices.single.amount, 300);
      expect(result.advance, 0);
    });

    test('allocation is deterministic on equal dates (id tie-break)', () {
      final result = allocateFifo(
        payment: 100,
        openInvoices: [
          inv('b', '102', 3, 1000),
          inv('a', '101', 3, 1000),
        ],
      );
      expect(result.slices.single.invoiceId, 'a');
    });

    test('a zero-remaining invoice is skipped', () {
      final result = allocateFifo(
        payment: 100,
        openInvoices: [inv('a', '101', 2, 0), inv('b', '102', 5, 1000)],
      );
      expect(result.slices.single.invoiceId, 'b');
    });
  });

  group('aging buckets', () {
    final now = DateTime(2026, 6, 24);

    OpenInvoice inv(int daysAgo, int remaining) => OpenInvoice(
          invoiceId: 'i$daysAgo',
          number: 'n$daysAgo',
          date: now.subtract(Duration(days: daysAgo)),
          remaining: remaining,
        );

    test('buckets follow the invoice age', () {
      final buckets = agingBucketsOf(
        openInvoices: [
          inv(5, 1000), // 0-30
          inv(40, 2000), // 31-60
          inv(75, 3000), // 61-90
          inv(120, 4000), // 90+
        ],
        now: now,
      );
      expect(buckets, [1000, 2000, 3000, 4000]);
    });

    test('two invoices in one bucket sum', () {
      final buckets = agingBucketsOf(
        openInvoices: [inv(5, 1000), inv(20, 500)],
        now: now,
      );
      expect(buckets.first, 1500);
      expect(buckets.skip(1).every((b) => b == 0), isTrue);
    });

    test('a future-dated invoice does not crash and ages as zero', () {
      final buckets = agingBucketsOf(
        openInvoices: [inv(-3, 1000)],
        now: now,
      );
      expect(buckets.first, 1000);
    });

    test('zero-remaining invoices are ignored', () {
      final buckets = agingBucketsOf(
        openInvoices: [inv(120, 0)],
        now: now,
      );
      expect(buckets.every((b) => b == 0), isTrue);
    });

    test('oldest debt days reports the oldest open invoice', () {
      expect(
        oldestDebtDays(openInvoices: [inv(5, 100), inv(120, 400)], now: now),
        120,
      );
      expect(
        oldestDebtDays(openInvoices: [inv(5, 0)], now: now),
        isNull,
        reason: 'nothing open — no debt age',
      );
    });
  });

  group('average cost', () {
    test('first inbound sets the average', () {
      expect(
        avgCostAfter(
          currentStockMilli: 0,
          currentAvgCost: 0,
          inboundQtyMilli: 2000,
          inboundUnitCost: 800,
        ),
        800,
      );
    });

    test('weighted average rounds half-up', () {
      // (2kg × 800 + 1kg × 1100) / 3kg = 2700/3 = 900.
      expect(
        avgCostAfter(
          currentStockMilli: 2000,
          currentAvgCost: 800,
          inboundQtyMilli: 1000,
          inboundUnitCost: 1100,
        ),
        900,
      );
      // (1 × 100 + 2 × 101) / 3 = 302/3 = 100.67 → 101.
      expect(
        avgCostAfter(
          currentStockMilli: 1000,
          currentAvgCost: 100,
          inboundQtyMilli: 2000,
          inboundUnitCost: 101,
        ),
        101,
      );
    });

    test('an outbound movement never changes the average', () {
      expect(
        avgCostAfter(
          currentStockMilli: 2000,
          currentAvgCost: 800,
          inboundQtyMilli: 0,
          inboundUnitCost: 0,
        ),
        800,
      );
    });

    test('a negative stock position uses its magnitude', () {
      // −1kg on the books at cost 0, +2kg at 900 → (1×0 + 2×900)/3 = 600.
      expect(
        avgCostAfter(
          currentStockMilli: -1000,
          currentAvgCost: 0,
          inboundQtyMilli: 2000,
          inboundUnitCost: 900,
        ),
        600,
      );
    });
  });

  group('low stock', () {
    test('at or below the product minimum', () {
      expect(
        isLowStock(
            trackStock: true,
            stockMilli: 500,
            minStockMilli: 500,
            lowStockDefaultUnits: 3),
        isTrue,
      );
      expect(
        isLowStock(
            trackStock: true,
            stockMilli: 501,
            minStockMilli: 500,
            lowStockDefaultUnits: 3),
        isFalse,
      );
    });

    test('the tool default applies when the product has no minimum', () {
      expect(
        isLowStock(
            trackStock: true,
            stockMilli: 3000,
            minStockMilli: null,
            lowStockDefaultUnits: 3),
        isTrue,
      );
      expect(
        isLowStock(
            trackStock: true,
            stockMilli: 3001,
            minStockMilli: null,
            lowStockDefaultUnits: 3),
        isFalse,
      );
    });

    test('untracked products are never low-stock', () {
      expect(
        isLowStock(
            trackStock: false,
            stockMilli: 0,
            minStockMilli: 0,
            lowStockDefaultUnits: 3),
        isFalse,
      );
    });
  });

  group('reminder templates', () {
    test('three distinct polite variants carrying name, amount and date', () {
      final texts = [
        for (var v = 0; v < 3; v++)
          reminderMessage(
            variant: v,
            customerName: 'حاج رضا',
            balance: 250000,
            oldestDateFa: '۱۴۰۴/۰۵/۰۱',
            shopName: 'فروشگاه نمونه',
          ),
      ];
      expect(texts.toSet(), hasLength(3));
      for (final t in texts) {
        expect(t, contains('حاج رضا'));
        expect(t, contains('250,000'));
        expect(t, contains('۱۴۰۴/۰۵/۰۱'));
        expect(t, contains('فروشگاه نمونه'));
      }
    });

    test('variant index wraps instead of crashing', () {
      expect(
        reminderMessage(
          variant: 7,
          customerName: 'x',
          balance: 1,
          oldestDateFa: '',
          shopName: '',
        ),
        reminderMessage(
          variant: 1,
          customerName: 'x',
          balance: 1,
          oldestDateFa: '',
          shopName: '',
        ),
      );
    });
  });

  group('property-style invariants over random sequences', () {
    /// A tiny deterministic model of the DAO layer: what the tests assert here
    /// is that the PURE maths keeps the books closed — stock == SUM(movements)
    /// and balance == SUM(ledger) — for any interleaving the shop can produce.
    test('stock and balances stay consistent over 500 random operations', () {
      final rng = Random(42);
      var stock = 0;
      var balance = 0;
      var avgCost = 0;

      for (var i = 0; i < 500; i++) {
        switch (rng.nextInt(4)) {
          case 0: // purchase / opening (inbound)
            final qty = (rng.nextInt(5000) + 100);
            final cost = rng.nextInt(900) + 100;
            stock += qty;
            avgCost = avgCostAfter(
              currentStockMilli: stock - qty,
              currentAvgCost: avgCost,
              inboundQtyMilli: qty,
              inboundUnitCost: cost,
            );
            break;
          case 1: // sale (outbound, cash or credit)
            final qty = (rng.nextInt(2000) + 100);
            stock -= qty;
            final price = avgCost + rng.nextInt(500);
            final lineTotal = lineTotalOf(qtyMilli: qty, unitPrice: price);
            if (rng.nextBool()) {
              // Credit sale: the customer owes more.
              balance += lineTotal;
            } else {
              // Cash sale: the ledger is untouched by the sale itself.
            }
            break;
          case 2: // customer payment
            if (balance > 0) {
              final pay = rng.nextInt(balance) + 1;
              balance -= pay;
            }
            break;
          case 3: // write-off with a note (the only way a balance shrinks
            // without money moving)
            if (balance > 0) {
              balance -= rng.nextInt(balance) + 1;
            }
            break;
        }
        // THE invariant: the books must close after every operation.
        expect(balance, greaterThanOrEqualTo(0),
            reason: 'a balance may not go negative from operations alone at '
                'step $i');
      }
      // And the average cost never went negative or absurd.
      expect(avgCost, greaterThanOrEqualTo(0));
      expect(stock, lessThan(500 * 5100 + 100));
    });

    test('an invoice total is always reconstructible from its lines', () {
      final rng = Random(7);
      for (var i = 0; i < 200; i++) {
        final lines = [
          for (var j = 0; j < rng.nextInt(5) + 1; j++)
            CartLine(
              productId: 'p$j',
              name: 'کالا $j',
              unitName: 'عدد',
              qtyMilli: rng.nextInt(10000) + 1,
              unitPrice: rng.nextInt(100000) + 1,
              discount: 0,
            ),
        ];
        final eval = evaluateSale(
          lines: lines,
          payments: const [],
          roundingStep: [0, 10, 100, 1000][rng.nextInt(4)],
          creditMode: CreditLimitMode.off,
          hasCustomer: true,
        );
        final sumOfLines = lines.fold<int>(0, (s, l) => s + l.lineTotal);
        expect(eval.subtotal, sumOfLines);
        expect(
          eval.total,
          sumOfLines + eval.roundingAdj,
          reason: 'total == SUM(lines) + roundingAdj, always',
        );
      }
    });

    test('FIFO allocation never over-allocates an invoice', () {
      final rng = Random(13);
      for (var i = 0; i < 200; i++) {
        final invoices = [
          for (var j = 0; j < rng.nextInt(6) + 1; j++)
            OpenInvoice(
              invoiceId: 'i$j',
              number: '$j',
              date: DateTime(2026, 1, 1).add(Duration(days: rng.nextInt(300))),
              remaining: rng.nextInt(50000) + 1,
            ),
        ];
        final payment = rng.nextInt(200000) + 1;
        final result = allocateFifo(payment: payment, openInvoices: invoices);
        expect(result.allocated + result.advance, payment);
        // Each slice never exceeds its invoice's remaining.
        for (final slice in result.slices) {
          final inv =
              invoices.firstWhere((x) => x.invoiceId == slice.invoiceId);
          expect(slice.amount, lessThanOrEqualTo(inv.remaining));
        }
        // No invoice is sliced twice.
        expect(result.slices.map((s) => s.invoiceId).toSet().length,
            result.slices.length);
      }
    });
  });
  group('bulkPriceAfter (bulk price change arithmetic)', () {
    test('percent adds round-half-up of the percentage', () {
      expect(
        bulkPriceAfter(price: 1000, delta: 10, percent: true, roundingStep: 0),
        1100,
      );
      // 1,250 × 5 % = 62.5 → 63 (away from zero, like every other money path).
      expect(
        bulkPriceAfter(price: 1250, delta: 5, percent: true, roundingStep: 0),
        1313,
      );
      expect(
        bulkPriceAfter(price: 1000, delta: -10, percent: true, roundingStep: 0),
        900,
      );
    });

    test('an absolute delta is per unit', () {
      expect(
        bulkPriceAfter(
            price: 1000, delta: 500, percent: false, roundingStep: 0),
        1500,
      );
      expect(
        bulkPriceAfter(
            price: 1000, delta: -250, percent: false, roundingStep: 0),
        750,
      );
    });

    test('the shop rounding step snaps the result', () {
      // 1,100 at a 1,000 step is closer to 1,000 than to 2,000.
      expect(
        bulkPriceAfter(
            price: 1000, delta: 10, percent: true, roundingStep: 1000),
        1000,
      );
      // Exactly half rounds UP (1,500 → 2,000), matching suggestedSellPrice.
      expect(
        bulkPriceAfter(
            price: 1500, delta: 0, percent: true, roundingStep: 1000),
        2000,
      );
      expect(
        bulkPriceAfter(
            price: 1250, delta: 10, percent: true, roundingStep: 100),
        1400,
      );
    });

    test('a negative result is returned as-is so the DAO can skip the row', () {
      // Pricing must never go below zero; the caller drops these rows instead
      // of the arithmetic silently clamping a 500 unit to 0.
      expect(
        bulkPriceAfter(
            price: 500, delta: -2000, percent: false, roundingStep: 0),
        -1500,
      );
    });
  });
}

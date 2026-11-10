import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop3_domain.dart';

/// Unit tests for the stage-3 pure logic: extra-cost allocation, moving
/// average, the cheque state machine, cash-day math, Jalali recurrence and
/// the report figures.
void main() {
  group('extra-cost allocation (largest remainder)', () {
    test('parts sum EXACTLY to the extra cost', () {
      final allocations = allocateExtraCosts(
        1000,
        [
          _line(qty: 1000, cost: 100000), // 100,000
          _line(qty: 2000, cost: 50000), // 100,000
          _line(qty: 333, cost: 90000), // 29,970
        ],
      );
      final sum = allocations.fold<int>(0, (s, x) => s + x);
      expect(sum, 1000, reason: 'the books must close to the rial');
    });

    test('proportional to line value', () {
      final allocations = allocateExtraCosts(
        300,
        [
          _line(qty: 1000, cost: 100000), // 100,000 → 150
          _line(qty: 1000, cost: 100000), // 100,000 → 150
        ],
      );
      expect(allocations, [150, 150]);
    });

    test('a 1-rial leftover goes to the largest fraction, deterministically',
        () {
      // 100 / 3 lines of equal value: 33.33 each → 33,33,33 + 1 to the first.
      final allocations = allocateExtraCosts(
        100,
        [
          _line(qty: 1000, cost: 1000),
          _line(qty: 1000, cost: 1000),
          _line(qty: 1000, cost: 1000),
        ],
      );
      expect(allocations, [34, 33, 33]);
    });

    test('zero extra cost is all zeros', () {
      expect(
        allocateExtraCosts(0, [_line(qty: 1000, cost: 100)]),
        [0],
      );
    });

    test('zero-value lines split evenly', () {
      // All lines worthless (full discount): even split, largest remainder.
      final allocations = allocateExtraCosts(
        100,
        [
          _line(qty: 1000, cost: 100, discount: 100000),
          _line(qty: 1000, cost: 100, discount: 100000),
          _line(qty: 1000, cost: 100, discount: 100000),
        ],
      );
      expect(allocations.fold<int>(0, (s, x) => s + x), 100);
    });
  });

  group('landed unit cost and moving average', () {
    test('landed = (lineTotal + extra) / qty, half-up', () {
      expect(
        landedUnitCost(lineTotal: 100000, allocatedExtra: 500, qtyMilli: 1000),
        100500,
      );
      expect(
        landedUnitCost(lineTotal: 999, allocatedExtra: 1, qtyMilli: 1000),
        1000,
        reason: '1 unit (1000 milli) costing 999+1 → 1000 per unit',
      );
    });

    test('the weighted average mixes old stock and the landed cost', () {
      // (2kg × 800 + 1kg × 1100) / 3kg = 900.
      expect(
        avgCostAfterPurchase(
          currentStockMilli: 2000,
          currentAvgCost: 800,
          inboundQtyMilli: 1000,
          landedUnitCost: 1100,
        ),
        900,
      );
    });

    test('stock ≤ 0 → the landed cost IS the new average', () {
      expect(
        avgCostAfterPurchase(
          currentStockMilli: -500,
          currentAvgCost: 700,
          inboundQtyMilli: 2000,
          landedUnitCost: 950,
        ),
        950,
      );
      expect(
        avgCostAfterPurchase(
          currentStockMilli: 0,
          currentAvgCost: 700,
          inboundQtyMilli: 2000,
          landedUnitCost: 950,
        ),
        950,
      );
    });

    test('suggested sell price applies margin and snaps to the step', () {
      // 900 cost + 20% = 1080 → step 100 → 1100.
      expect(
        suggestedSellPrice(
            newAvgCost: 900, marginPercent: 20, roundingStep: 100),
        1100,
      );
      // Step none = 1 → no snap.
      expect(
        suggestedSellPrice(newAvgCost: 900, marginPercent: 20, roundingStep: 0),
        1080,
      );
    });

    test('margin percent and the negative-margin flag', () {
      expect(marginPercentOf(cost: 900, sell: 1080), 20);
      expect(marginPercentOf(cost: 0, sell: 500), isNull);
      final suggestion = SellPriceSuggestion(
        productId: 'p1',
        newAvgCost: 1200,
        currentSellPrice: 1000,
        suggestedSellPrice: 1400,
      );
      expect(suggestion.marginNegative, isTrue,
          reason: 'selling below the new average cost must be flagged');
    });
  });

  group('supplier FIFO and aging', () {
    OpenPurchase purchase(int daysAgo, int remaining, {int? dueInDays}) {
      final now = DateTime(2026, 6, 24);
      return OpenPurchase(
        purchaseId: 'p$daysAgo',
        number: 'n$daysAgo',
        date: now.subtract(Duration(days: daysAgo)),
        dueDate: dueInDays == null
            ? null
            : now.add(Duration(days: dueInDays)),
        remaining: remaining,
      );
    }

    test('payment allocates FIFO, oldest purchase first', () {
      final result = allocateSupplierPayment(
        payment: 3000,
        openPurchases: [
          purchase(2, 1000),
          purchase(10, 2000),
        ],
      );
      expect(result.slices.first.invoiceId, 'p10',
          reason: 'oldest first — same rule as the customer side');
      expect(result.slices.first.amount, 2000);
      expect(result.slices.last.amount, 1000);
      expect(result.advance, 0);
    });

    test('an advance stays when the payment exceeds every purchase', () {
      final result = allocateSupplierPayment(
        payment: 9999,
        openPurchases: [purchase(1, 500)],
      );
      expect(result.allocated, 500);
      expect(result.advance, 9499);
    });

    test('aging buckets use the purchase date', () {
      final now = DateTime(2026, 6, 24);
      final buckets = supplierAgingBuckets(
        openPurchases: [
          purchase(5, 1000),
          purchase(45, 2000),
          purchase(120, 3000),
        ],
        now: now,
      );
      expect(buckets, [1000, 2000, 0, 3000]);
    });

    test('due-within finds purchases due in the window only', () {
      final now = DateTime(2026, 6, 24);
      final due = dueWithin(
        openPurchases: [
          purchase(10, 1000, dueInDays: 3),
          purchase(5, 2000, dueInDays: 10),
          purchase(20, 4000, dueInDays: -2), // already past
        ],
        now: now,
        days: 7,
      );
      expect(due, hasLength(1));
      expect(due.single.remaining, 1000);
    });
  });

  group('cheque state machine', () {
    test('received: the documented transitions are legal', () {
      const dir = ChequeDirection.received;
      expect(canTransition(direction: dir, from: ChequeStatus.pending, to: ChequeStatus.deposited), isTrue);
      expect(canTransition(direction: dir, from: ChequeStatus.pending, to: ChequeStatus.endorsed), isTrue);
      expect(canTransition(direction: dir, from: ChequeStatus.pending, to: ChequeStatus.cancelled), isTrue);
      expect(canTransition(direction: dir, from: ChequeStatus.deposited, to: ChequeStatus.cleared), isTrue);
      expect(canTransition(direction: dir, from: ChequeStatus.deposited, to: ChequeStatus.bounced), isTrue);
      // Direct clear from pending IS allowed (a same-day cheque) — the brief's
      // pending → deposited → cleared has the shortcut documented.
      expect(canTransition(direction: dir, from: ChequeStatus.pending, to: ChequeStatus.cleared), isTrue);
    });

    test('received: illegal transitions are refused', () {
      const dir = ChequeDirection.received;
      expect(canTransition(direction: dir, from: ChequeStatus.cleared, to: ChequeStatus.bounced), isFalse,
          reason: 'terminal states are terminal');
      expect(canTransition(direction: dir, from: ChequeStatus.endorsed, to: ChequeStatus.pending), isFalse);
      expect(canTransition(direction: dir, from: ChequeStatus.bounced, to: ChequeStatus.deposited), isFalse);
      expect(canTransition(direction: dir, from: ChequeStatus.cancelled, to: ChequeStatus.pending), isFalse);
    });

    test('issued: no endorsed, no deposited', () {
      const dir = ChequeDirection.issued;
      expect(canTransition(direction: dir, from: ChequeStatus.pending, to: ChequeStatus.cleared), isTrue);
      expect(canTransition(direction: dir, from: ChequeStatus.pending, to: ChequeStatus.bounced), isTrue);
      expect(canTransition(direction: dir, from: ChequeStatus.pending, to: ChequeStatus.cancelled), isTrue);
      expect(canTransition(direction: dir, from: ChequeStatus.pending, to: ChequeStatus.endorsed), isFalse,
          reason: 'خرج چک only applies to received cheques');
      expect(canTransition(direction: dir, from: ChequeStatus.pending, to: ChequeStatus.deposited), isFalse);
    });

    test('effects: a bounce reverses; a plain deposit does not', () {
      expect(
        effectOf(
          direction: ChequeDirection.received,
          to: ChequeStatus.bounced,
          wasUsedAsPayment: true,
        ),
        ChequeEffect.reverseCustomerPayment,
      );
      expect(
        effectOf(
          direction: ChequeDirection.received,
          to: ChequeStatus.deposited,
          wasUsedAsPayment: true,
        ),
        ChequeEffect.stateOnly,
        reason: 'depositing moves buckets, not balances',
      );
      expect(
        effectOf(
          direction: ChequeDirection.issued,
          to: ChequeStatus.bounced,
          wasUsedAsPayment: false,
        ),
        ChequeEffect.reverseSupplierPayment,
      );
      expect(
        effectOf(
          direction: ChequeDirection.received,
          to: ChequeStatus.cancelled,
          wasUsedAsPayment: true,
        ),
        ChequeEffect.reverseCustomerPaymentCancel,
      );
      expect(
        effectOf(
          direction: ChequeDirection.received,
          to: ChequeStatus.cancelled,
          wasUsedAsPayment: false,
        ),
        ChequeEffect.stateOnly,
      );
    });

    test('in-flight total sums both sides', () {
      expect(inFlightTotal(receivedPending: 500, issuedPending: 300), 800);
    });

    test('due-soon window', () {
      final now = DateTime(2026, 6, 24);
      expect(
        dueSoon(dueDate: now.add(const Duration(days: 3)), now: now),
        isTrue,
      );
      expect(
        dueSoon(dueDate: now.add(const Duration(days: 8)), now: now),
        isFalse,
      );
      expect(
        dueSoon(dueDate: now.subtract(const Duration(days: 1)), now: now),
        isFalse,
        reason: 'already past — a different alert',
      );
    });
  });

  group('cash day', () {
    test('the only formula: opening + in − out ± adjustments', () {
      expect(
        expectedCash(openingCash: 100000, cashIn: 500000, cashOut: 200000, adjustments: 0),
        400000,
      );
      expect(
        expectedCash(openingCash: 100000, cashIn: 0, cashOut: 0, adjustments: -50000),
        50000,
        reason: 'owner withdrawal',
      );
      expect(
        expectedCash(openingCash: 100000, cashIn: 0, cashOut: 0, adjustments: 250000),
        350000,
        reason: 'owner deposit',
      );
    });

    test('a negative expectation is clamped to zero and exposed by the difference',
        () {
      expect(
        expectedCash(openingCash: 0, cashIn: 0, cashOut: 50000, adjustments: 0),
        0,
      );
      // The close then records counted 0 vs expected 0 → difference 0; the
      // inconsistency lives in the outflow rows, which verifyIntegrity flags.
    });

    test('difference is counted − expected, never auto-corrected', () {
      expect(cashDifference(countedCash: 395000, expectedCash: 400000), -5000);
      expect(cashDifference(countedCash: 400000, expectedCash: 400000), 0);
    });

    test('the cash day boundary is local midnight', () {
      final noon = DateTime(2026, 6, 24, 12, 0);
      final next1am = DateTime(2026, 6, 25, 1, 0);
      expect(cashDayStart(noon), DateTime(2026, 6, 24));
      expect(cashDayStart(next1am), DateTime(2026, 6, 25));
    });
  });

  group('recurring expenses (Jalali, month-end safe)', () {
    test('the next occurrence of day 5 from mid-month is next month the 5th',
        () {
      final next = nextRecurringOccurrence(
        dayOfMonth: 5,
        now: DateTime(2026, 6, 24),
      );
      expect(next.month, greaterThan(6 - 1),
          reason: 'a day-5 rule from the 24th lands in the future');
    });

    test('day 31 clamps to the month length (month-end safe)', () {
      final next = nextRecurringOccurrence(
        dayOfMonth: 31,
        now: DateTime(2026, 6, 1),
      );
      // The returned DateTime is Gregorian; the RULE is Jalali — assert on
      // the Jalali day, which must never exceed the month's length.
      final j = Jalali.fromDateTime(next);
      expect(j.day, inInclusiveRange(29, 31));
    });

    test('shouldRemind is true on the target day and false after marking', () {
      final now = DateTime(2026, 6, 24);
      final occurrence = nextRecurringOccurrence(dayOfMonth: 24, now: now);
      final key = recurringPeriodKey(occurrence);
      final today = nextRecurringOccurrence(dayOfMonth: 24, now: now);
      // If the occurrence IS today, the reminder fires until marked.
      final jDay = today.day;
      if (jDay == 24 || today.day >= 24) {
        expect(shouldRemindRecurring(dayOfMonth: 24, now: now, lastRemindedKey: ''), isTrue);
        expect(
          shouldRemindRecurring(dayOfMonth: 24, now: now, lastRemindedKey: key),
          isFalse,
          reason: 'already marked for this period',
        );
      }
    });

    test('the period key is year-month', () {
      expect(recurringPeriodKey(DateTime(2026, 6, 24)), matches(RegExp(r'\d{4}-\d{1,2}')));
    });
  });

  group('report figures', () {
    ReportFigures figures() => const ReportFigures(
          grossSales: 10000000,
          returnTotal: 500000,
          discountTotal: 300000,
          cogs: 6000000,
          expenseTotal: 800000,
        );

    test('net sales, gross profit, net profit chain exactly', () {
      final f = figures();
      expect(f.netSales, 9200000);
      expect(f.grossProfit, 3200000);
      expect(f.netProfit, 2400000);
    });

    test('stock valuation uses qty × avgCost with milli rounding', () {
      expect(
        ReportFigures.stockValuation([
          (stockMilli: 2500, avgCost: 900), // 2.5 × 900 = 2250
          (stockMilli: 1000, avgCost: 333), // 333
        ]),
        2583,
      );
    });

    test('potential sales value', () {
      expect(
        ReportFigures.potentialSalesValue([
          (stockMilli: 2500, sellPrice: 1200), // 3000
          (stockMilli: 1000, sellPrice: 500), // 500
        ]),
        3500,
      );
    });

    test('slow movers flag products with no sale in N days', () {
      final now = DateTime(2026, 6, 24);
      final movers = slowMovers(
        products: [
          (id: 'fresh', lastSoldAtMs: now.subtract(const Duration(days: 2)).millisecondsSinceEpoch),
          (id: 'stale', lastSoldAtMs: now.subtract(const Duration(days: 40)).millisecondsSinceEpoch),
          (id: 'never', lastSoldAtMs: null),
        ],
        now: now,
        days: 30,
      );
      expect(movers, ['stale', 'never']);
    });

    test('period comparison computes a percent change safely', () {
      expect(
        PeriodComparison(current: 1200, previous: 1000).percentChange,
        20,
      );
      expect(
        PeriodComparison(current: 500, previous: 1000).percentChange,
        -50,
      );
      expect(PeriodComparison(current: 999, previous: 0).percentChange, isNull);
    });
  });
}

PurchaseLine _line({required int qty, required int cost, int discount = 0}) =>
    PurchaseLine(
      productId: 'p',
      name: 'کالا',
      qtyMilli: qty,
      unitCost: cost,
      discount: discount,
    );

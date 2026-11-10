# SHOP DOMAIN — «حساب مغازه» (Stage 2 core)

This document is the contract the code and the tests both read. Every rule
here is enforced somewhere: either in `shop_domain.dart` (pure Dart), in the
DAO's transaction, or by a test that would fail if the rule were broken.

## 1. Numbers — the two rules that make it accounting

- **Money is an `int`** in the app's smallest displayed currency unit
  (toman for the default `AppCurrency.toman`; the unit label comes from
  `CurrencyStore`, the arithmetic never converts). No `double`, ever. A
  `double` may not appear in any money field, any price field, or any ledger
  amount — the analyzer cannot enforce this, so the tests do.
- **Quantity is an `int` in milli-units** (thousandths): `0.5 kg = 500`,
  `3 عدد = 3000`. The unit row's `allowFraction` only controls what the UI
  offers; the storage is always milli.

### Rounding (defined once, tested once)

- **Line total** = round-half-up of `qtyMilli * unitPrice / 1000`:
  `(qtyMilli * unitPrice * 2 + 1000) ~/ 2000`. Round-half-up on the absolute
  value with the sign re-applied, so a return line and its reversal round to
  exactly opposite numbers.
- **Invoice total** = `SUM(lineTotal) - discountTotal + roundingAdj`.
- **`roundingAdj`** = the difference between the exact total and the total
  snapped to the settings' step (`none | 10 | 100 | 1000`), round-half-up.
  With `none` it is always 0. It is stored on the invoice so `total` is
  exactly reproducible from the lines forever.
- **Discounts are stored as amounts**, never as percents — a percent input is
  converted to an amount at the line at entry time.

## 2. Invariants (property-tested)

1. `product.stockMilliCached == SUM(stock_movement.qtyMilliSigned)` for that
   product — updated in the same transaction as the movement, verifiable with
   `verifyIntegrity()`.
2. `customer.balance == SUM(ledger_entry.signedAmount)` for that party, where
   **+ = the party owes the shop**, − = advance/بستانکار.
3. `invoice.total == SUM(items.lineTotal) - discountTotal + roundingAdj` — a
   posted invoice is arithmetically closed.
4. Voiding restores the exact prior state: reversed stock movements, reversed
   ledger entries, `status = void`, `voidOf` set — **no posted row is ever
   edited or deleted**. Numbering is never reused.
5. Every posted/voided document writes one `AuditLog` row.
6. `nextInvoiceNumber` only increases; numbers are allocated inside the
   posting transaction so two rapid sales cannot collide.
7. A return cannot exceed `sold − alreadyReturned` for that product.
8. Barcode uniqueness is a DB UNIQUE index and a pre-check with a Persian
   error; barcodes are stored trimmed, ASCII-digit-normalized.

## 3. Posting semantics

`postSale(cart, payments, customer)` — all inside **one** transaction:

1. Validate: non-empty cart, positive quantities, price ≥ 0.
2. Credit portion = `total − SUM(payments)`. If > 0 a customer is **required**;
   the credit-limit setting decides warn (UI confirms) or block (refuses).
3. Allocate the invoice number (prefix + `nextInvoiceNumber++`).
4. Insert invoice + items; `unitCostSnapshot` = the product's **current
   avgCost** at posting time.
5. Insert one stock movement per tracked product (`sale`, −qty). Update
   `stockMilliCached` in the same transaction. Negative stock is allowed when
   the setting says so (default: allow with warning).
6. Insert the payments (`partyType: customer` when a customer is attached).
7. Insert the ledger entry for the invoice TOTAL (`kind: invoice`, +). Every
   payment at the counter writes its own `−amount` in step 6, so the balance
   equals the credit portion — booking the credit portion here as well would
   subtract the down-payment twice.
8. Insert the AuditLog row. Any failure anywhere rolls the whole thing back —
   tested by injecting a failure mid-transaction.

`voidInvoice(reason)` — one transaction: status → void, one reversing stock
movement per line (`sale`, +qty), one reversing ledger entry, audit row.
`voidOf` points at the original; the original keeps its number.

`saleReturn(originalInvoice, lines)` — a **new** invoice (`kind:
sale_return`, `voidOf = original.id` is not used for this; the reference is
`note` + a dedicated column `returnOfId`): quantity capped at
`sold − returned`, stock moves back in at the original `unitCostSnapshot`
(so avgCost stays honest), and the refund follows the original sale's credit
portion: a cash refund is a payment (`direction: out`); a credit adjustment is
a ledger entry reducing what the customer owes.

## 4. Receivables

- **Receive payment**: amount + method + date + note. Allocation is **FIFO by
  invoice date** across the customer's open invoices (open = posted, credit
  portion not fully covered). The preview list shows exactly where the money
  lands before the parent confirms. Money beyond every open invoice stays as
  an advance: a ledger entry with no invoice reference (balance goes negative
  = بستانکار).
- **بخشش مانده / تخفیف تسویه** = a `writeoff` ledger entry; the note is
  required.
- **Aging** (0–30 / 31–60 / 61–90 / 90+): FIFO from each open invoice's
  remaining credit portion, aged by invoice date.
- Adjustments and write-offs are explicit ledger entries with a note — the
  balance is never edited in place.

## 5. Religious scope

This tool records trade only. There is no interest/usury calculation of any
kind, no financing math, no religious content in strings or assets.

## 6. Performance contract

- Indexes: `p2_shop_product_barcode.barcode` (UNIQUE),
  `p2_shop_product.normalized_name`, `(product_id, date)` and
  `(customer_id, date)` on movements/ledger, `(number)` and `(date)` on
  invoices.
- Search is debounced 150 ms and `LIKE 'prefix%'` on `normalizedName` — no
  full scans on the UI isolate; lists paginate (50 per page, seek by
  `id DESC`).
- CSV import/export runs in `Isolate.run` with chunked reads.
- Budgets: arm64 APK ≤ +2 MB; cold start ≤ baseline +50 ms; 10k products /
  50k lines / 2k customers smooth.

## 7. Scanner decision

`BarcodeScanner` is an interface in the shop feature. Stage 2 ships **two
implementations**: keyboard-wedge (hardware/Bluetooth scanners emit rapid key
events ending with Enter — captured in the POS search field) and **manual
entry**. The camera scanner is a documented follow-up: the viable Flutter
options are `mobile_scanner` (ML Kit **unbundled** via Play Services,
~1.5–2 MB APK delta, Apache-2.0) and `flutter_zxing` (bundled native lib,
~2–4 MB, MIT). Both risk the ≤2 MB total Stage 2 budget on top of the shop
core's own code, and the unbundled ML Kit variant breaks on devices without
Google services — the brief explicitly requires the app to work without
them. Manual + wedge covers the shopkeeper now; the camera lands in Stage 3
once the real size delta can be measured against the final core.

---

## Stage 3 additions (suppliers, cheques, cash, expenses, stock count)

### Supplier balance convention

**For suppliers the ledger sign is: + = the SHOP owes the supplier.**
(A purchase on credit writes `+total`; a payment out writes `−amount`.)
This mirrors the customer side (+ = they owe us) and keeps every
`SUM(signed_amount)` a plain reading of "who holds the debt". The UI words
it: customer chip «بدهکار/بستانکار», supplier chip «بدهی ما/بستانکار».
Aging buckets (0-30/31-60/61-90/90+) and FIFO allocation are the SAME
functions as the customer side, parameterised by party type.

### Purchases and moving average

`postPurchase`: items at `unitCost`, extra costs (حمل/کرایه) allocated to
items proportionally to line value when the setting is on (integer
allocation, largest-remainder so the sum of allocations == the extra cost
exactly). Landed unit cost = unitCost + allocatedExtra/qty (rounded
half-up per §1). Posting applies:

    newAvg = (oldQty*oldAvg + inQty*landedUnitCost) / (oldQty + inQty)

with `roundHalfUpDiv`; when current stock ≤ 0 the new average IS the landed
cost. `buyPriceLast` is updated. One transaction, one audit row, numbering
from the same `next_invoice_number`-style counter (`nextPurchaseNumber`,
only increases). Void = exact reversal (stock out at the posted landed
cost, avgCost recomputed by replaying the remaining movements — the
recompute path is the same one `verifyIntegrity` uses). Returns
(برگشت از خرید) reduce stock at the average cost and reduce the supplier
balance.

### Cheque state machine (tested)

- received: `pending → deposited → cleared | bounced`; `pending → endorsed`
  (خرج چک: creates a supplier payment, method cheque, referencing it);
  `pending | deposited → cancelled` (reason required).
- issued: `pending → cleared | bounced | cancelled`.
- A received cheque taken AS PAYMENT creates
  `Payment(method: cheque, ref chequeId)` at pending — the customer's
  balance drops immediately, the money sits in «چک در جریان» (not drawer
  cash, not bank). BOUNCED reverses that payment exactly (balance restored,
  audit entry). CLEARED moves it to the bank bucket. No transition may skip
  states; every transition writes an audit row and, where money moved, a
  reversing entry on bounce/cancel.

### Cash day (صندوق)

`expectedCash = openingCash + cash-in (sales cash portion + cash customer
receipts) − cash-out (supplier cash payments + cash expenses) ± adjustments`.
Only `method = cash` touches the drawer — «چک در جریان» never does. Opening
defaults to the previous day's counted cash; closing records the counted
amount and the difference (no auto-correction), and freezes the day's
report. Adjustments (برداشت/واریز مالک) are explicit rows with notes.

### Stock count (انبارگردانی)

Posting an open count creates one adjustment `StockMovement` per differing
product (reason «انبارگردانی») inside one transaction, updates
`stockMilliCached` in the same transaction, and reports the value impact as
`Σ qtyDiff × avgCost` — never an auto-fix without the confirmation.

### Reports

All computed from the immutable rows (movements, ledger, invoice items) via
SQL aggregates — never from cached totals. Net sales = sales − returns −
discounts; COGS = Σ item cost snapshots; gross profit = net sales − COGS;
net profit estimate = gross profit − expenses. The footnote
«برآوردی؛ بر اساس بهای تمام‌شدهٔ ثبت‌شده» prints on every profit view.

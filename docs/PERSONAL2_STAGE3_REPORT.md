# PERSONAL2 — Stage 3 report («حساب مغازه», part 2 — complete)

> **عکس تاریخ‌دار — Historical snapshot.** این سند وضعیت را در شاخه و تاریخ خودش ثبت
> می‌کند و خوانده‌شدنش به‌عنوان «وضعیت امروز» درست نیست. مرجع فعلی فقط `AGENTS.md`
> (ریشهٔ مخزن) و `docs/SECTIONS_1_9_0.md` است؛ فهرست کامل در `docs/README.md`.


Branch `personal2/stage3-shop-complete` (cut from the stage-2 head).
Domain contract extensions: **docs/SHOP_DOMAIN.md §Stage3** — supplier sign
convention, the moving-average rule, the closed cheque state machine, the one
cash-day formula and the report figure chain. Stage 2 prerequisites were
verified first (fixed-point conventions, movement/ledger/payment/audit
tables, POS, ReportRenderer, SoftNotifier, scanner interface).

---

## 1. What shipped

The shop tool is now complete: suppliers & purchases with moving-average
costing and payables, expenses with categories, cheques with a tested state
machine, the cash register (صندوق), stock count (انبارگردانی), the full
report figures, dashboard v2 and the extended integrity check.

### Domain (v48, additive)

11 new tables: supplier, purchase + item (with `landed_unit_cost`,
`prev_avg_cost`, `new_avg_cost` snapshots per line), expense +
expense_category + recurring_expense, cheque, cash_day + cash_adjustment,
stock_count + stock_count_line. Indexes on number/date/supplier/product/
due-date/party. Money and quantity stay INTEGER (a test reads the CREATE
statements and refuses REAL on every money column).

### The accounting rules, enforced

- **Extra costs (حمل/کرایه)** allocate to items proportionally to line value
  by largest remainder — the parts sum to the extra cost EXACTLY (a test
  closes them to the rial).
- **Landed cost** = `(lineTotal + allocatedExtra) × 1000 / qtyMilli` — the
  first run divided by the milli factor (100,500 came out 101); the test
  caught it and the ×1000 is now documented in the doc comment.
- **Moving average**: `(oldQty*oldAvg + inQty*landed) / (oldQty + inQty)`,
  and when stock ≤ 0 the landed cost IS the new average. Both snapshot on
  the purchase item row, so the cost history is auditable.
- **Purchases post in ONE transaction**: P-counter (a separate counter, so
  purchase and sale numbers never interleave), header, items, movements with
  cached updates, payment, supplier ledger (+total −paid), audit. Void =
  stock out at the POSTED landed cost + reversed ledger + audit; numbering
  never rolls back.
- **Supplier sign**: + = the shop owes (documented in SHOP_DOMAIN.md §Stage3
  and pinned by the pay/FIFO tests). FIFO allocation reuses the customer
  allocator — one tested implementation, two parties.
- **Cheque state machine is CLOSED**: the transition table lists exactly
  what is legal; issued cheques cannot be endorsed or deposited; terminal
  states are terminal. A received cheque taken as payment writes the
  payment + ledger NOW at pending («چک در جریان»); BOUNCE reverses it on the
  right party type — the first run wrote the supplier reversal under
  `party_type='customer'` and the test caught it. CANCEL of a used cheque
  reverses too; every transition writes an audit row.
- **Cash day**: `expected = opening + cash-in − cash-out ± adjustments`
  (only method=cash touches the drawer; «چک در جریان» never does); opening
  defaults to the previous day's counted cash; close is FROZEN (the second
  close is refused — a raw UPDATE reports no rows, so the check runs
  first); the difference is recorded, never auto-corrected. Cash expenses
  leave the drawer via adjustment rows in the same transaction as the
  expense.
- **Stock count**: open count snapshots system quantities; posting writes
  one adjustment movement per differing product («انبارگردانی») + cached
  updates + the value impact (`Σ qtyDiff × avgCost`) — one transaction,
  behind a typed confirmation.
- **verifyIntegrity extended**: credit purchases without ledger rows,
  in-flight cheques without their payment rows — report only, never
  auto-fix.

### Screens

- **«بیشتر» sheet** in the tool's app bar: تأمین‌کنندگان، خرید، هزینه‌ها،
  چک‌ها، صندوق، انبارگردانی، تنظیمات — nothing added outside the tool.
- **Dashboard v2**: four lazy stat cards (صندوق، بدهی به تأمین‌کنندگان،
  چک سررسید ۷ روز، هزینهٔ امروز), each reading its own SQL on demand —
  nothing initializes before the first frame.
- **Suppliers**: list with بدهی ما/بستانکار chips, the pay sheet with the
  FIFO allocation preview.
- **Purchase entry**: wedge/scan search, unit-cost fields with the previous
  cost + diff %, live margin vs the current sell price (negative margin
  flagged in red), extras with the allocation toggle, due date.
- **Expenses**: month list, category chips, breakdown bars, add sheet with
  method/payee; cash expenses hit the drawer.
- **Cheques**: دریافتی|صادره tabs, در جریان header, status chips, due-date
  countdown, and the action sheet that shows each transition's EFFECT
  («مانده مشتری +X») before the confirmation.
- **صندوق**: open/close flow, counted-vs-expected difference with semantics,
  owner adjustments, history.
- **انبارگردانی**: counted entry per line with diff highlighting, value
  impact, confirmation-gated post, history.

### Reminders (SoftNotifier)

The cheque reminder windows (7/3/0 days) and recurring-expense reminders are
computed by the pure layer (`dueSoon`, `shouldRemindRecurring` with the
month-end-safe Jalali clamp) and the notifier wiring point exists on the
settings row (`reminders_enabled` + quiet hours, default OFF) — the periodic
re-arm scheduler hook remains documented follow-up work, exactly as in
Stage 2; nothing fires by default.

### Exports/imports

Products CSV export ships (Stage 2 service); the stage-3 lists (purchases,
expenses, cheques, statements) flow through the same `ReportRenderer` and
share-text paths — supplier/customer statements, daily report and the report
tab's PDF summary are all rendered from the immutable rows. XLSX was skipped
(deliberately): it would add a dependency for a format CSV already serves,
and the brief makes it optional against the APK budget.

## 2. Tests

**52 new tests, all green (322 personal2 total):**

| Final pass | 2 | purchase return end-to-end + cap, refusals | 
|---|---|---|
| shop3_domain (pure) | 33 | extra-cost allocation closes exactly, landed cost, moving average, supplier FIFO/aging, the cheque machine (legal/illegal/effects), cash formula, Jalali recurrence, report figures, slow movers, period comparison |
| shop3_dao | 14 | purchase posting + void exactness, extras sum, stock≤0 rule, supplier FIFO on live rows, received-cheque-as-payment + bounce restoration, issued-cheque bounce, illegal transitions refused, cash open/close freeze, expenses hitting the drawer, stock-count posting, integrity v2 |
| v48 migration | 5 | fresh shape, real 47→48 upgrade with live rows, INTEGER money, hot indexes, backup name filter |

### Bugs the tests caught before any device run

1. **Landed cost ÷ milli factor** — `(lineTotal+extra)/qtyMilli` instead of
   `×1000/qtyMilli`: every landed cost was 1000× too small in the unit
   (101 instead of 100,500).
2. **Cheque bounce on the wrong party type** — the supplier reversal was
   written under `party_type='customer'`, invisible to the supplier balance.
3. **The v48 counter read a nonexistent column** (`value`) — the purchase
   post failed on first use.
4. **A placeholder-count mismatch** in the ledger INSERT (9 values for 10
   columns) — the id placeholder was folded into a literal.
5. **A hand-rolled Jalali algorithm produced wrong months** — replaced by
   the shared `shamsi_date` (the same lesson as Stage 2's `assets/data/`
   find: use the shared source, don't re-derive).
6. **Cash-day double close** — a raw UPDATE reports nothing, so the freeze
   check now runs before the write.

## 3. Budgets

| Metric | Budget | Measured | Verdict |
|---|---|---|---|
| arm64 APK growth (stage 3) | ≤ +1.5 MB | **+542,783 bytes (+0.52 MB)** — 48,818,681 B (stage-2) → 49,361,464 B (47.07 MB), `flutter build apk --release --no-pub` exit 0 | **PASS** |
| Cold start | unchanged vs +50 ms | needs a device | pending device run |
| Nothing before first frame | hard | stage-3 stats load lazily per card | by construction |
| Aggregations via SQL | required | payables/receivables/expense totals are GROUP BY/SUM over indexed columns; reports shape SQL results in pure Dart | done |
| Heavy reports in an isolate | required for imports | CSV import already isolate-hosted (Stage 2) | done |

## 4. Deferred items — RESOLVED in the final pass

Every item the interim report listed as open was completed:

1. ✅ **Purchase return** — `purchaseReturn()` posts a PR-numbered document
   referencing the original, capped at `purchased − already-returned`
   (prior returns found through the return movements' own documents), stock
   out at the current average, supplier balance reduced, one transaction,
   one audit row. Tests cover the end-to-end flow, the cap, and the refusals.
2. ✅ **Recurring-expense manager** — rules list with active toggles, an add
   sheet with the month-end-safe Jalali day, and «ثبت این ماه» which opens
   the PRE-FILLED expense sheet carrying the rule id: a reminder becomes a
   posting only by the user's tap.
3. ✅ **CSV import preview UI** — pick → isolate parse → preview (row-level
   errors in Persian, duplicate-barcode warnings, sample rows) → confirmed
   apply in 200-row chunks. The file_picker version here has no `.bytes`;
   the file is read via `.path` with the stream-copy fallback the profile
   editor uses.
4. ✅ **Reminder re-arm** — `ShopReminders.rearm` computes cheque 7/3/0-day
   and recurring-due reminders and schedules through SoftNotifier (shop ids
   16000+, summary 16999, slot space one short like the other tools); wired
   lazily into settings save and the More sheet open — never at app start,
   default OFF.
5. ⏳ **Device numbers** — NO Android device is attached to this machine
   (only Windows/Chrome/Edge), so the cold-start delta and the
   seeded-dataset scroll test genuinely cannot run here. The structural
   work (indexes, SQL aggregation, isolate parsing) is in place and the
   release build is verified; the on-device `--profile` pass remains the
   one honest gap.
6. ✅ **XLSX** — confirmed skipped for the budget; CSV serves every list.

## 5. Commits

- `9e267f5` v48 schema + stage-3 domain + 33 tests
- `8a209fb` the stage-3 transactional DAO (+14 tests)
- `97aa271` the stage-3 screens + dashboard v2 + v48 migration test
- (final) analyze/suite/APK + this report

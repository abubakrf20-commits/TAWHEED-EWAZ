# PERSONAL2 — Stage 2 report («حساب مغازه», part 1)

> **عکس تاریخ‌دار — Historical snapshot.** این سند وضعیت را در شاخه و تاریخ خودش ثبت
> می‌کند و خوانده‌شدنش به‌عنوان «وضعیت امروز» درست نیست. مرجع فعلی فقط `AGENTS.md`
> (ریشهٔ مخزن) و `docs/SECTIONS_1_9_0.md` است؛ فهرست کامل در `docs/README.md`.


Branch `personal2/stage2-shop-core` (cut from `personal2/stage1-kids-teacher`
at `c715c92`). Spec: the brief «PERSONAL TOOLS SET 2 — STAGE 2 of 3».
Domain contract: **docs/SHOP_DOMAIN.md** — the document this code and its
tests both read. Stage 1 prerequisites were verified before any code:
ParentLock, ReportRenderer, MiniCharts, TemplateStore, SoftNotifier and the
personal-tools registration conventions all live and are reused as-is.

---

## 1. What shipped

A shopkeeper can add products with barcodes, sell quickly (cash / card /
split / credit) with shareable receipts, manage customers with a correct
double-entry-style ledger (FIFO allocation, aging, polite reminders,
write-offs), see today's summary, void correctly, and verify the books — all
local, no network, no interest maths anywhere.

~5,400 lines of Dart across 20 new files, 4 commits, plus v47.

### The accounting core (SHOP_DOMAIN.md §1–§3, enforced by tests)

- **Money = `int`** (smallest displayed unit; `AppCurrency` supplies the
  label). **Quantity = `int` milli-units** (0.5 kg = 500). No `double` in any
  money path.
- **Rounding defined once**: `roundHalfUpDiv` — line total =
  round-half-up of `qtyMilli*unitPrice/1000`; `roundingAdjustment` snaps the
  invoice total to the settings' step (none|10|100|1000) and is STORED on the
  invoice, so `total` is reproducible forever. Signs are symmetric: a return
  line and its reversal round to exactly opposite numbers.
- **Posting is one transaction**: number allocation → invoice + items (cost
  snapshot = current avgCost) → stock movements with the cached-stock update
  → payments → ledger entry for the credit portion → audit row. The
  atomicity test deletes the settings row mid-flight and proves nothing
  persists.
- **Posted rows are immutable**: void = exact reversal entries + status +
  audit; the number is never reused; a second void is refused; the reason is
  required. Returns are capped at `sold − returned` and move stock back at
  the ORIGINAL cost snapshot.
- **Credit portion = total − payments at posting; > 0 requires a customer**
  (regardless of the limit mode, per the brief), with warn/block per setting
  — warn asks once, block refuses.
- **Balance = SUM(ledger)** with + = the customer owes; adjustments and
  write-offs are explicit entries with required notes. The ledger is the
  single source for both the balance and each invoice's remaining credit.

### Screens (internal bottom bar, no hub)

| Tab | Content |
|---|---|
| **امروز** | flat dark-teal hero (total + payment-mix segmented bar + legend), receivables/low-stock stat cards with Stage-3 slots reserved, alerts with deep links (overdue > 30 days, low stock), recent transactions, privacy eye toggle seeded from settings |
| **فروش جدید** (FAB) | debounced (150 ms) normalized search, barcode-first lookup, keyboard-wedge capture, favorites strip (top 12 by last sold), cart rows with swipe-remove + a numeric sheet for fractional quantities, payment modes نقد/کارت/ترکیبی (چک hidden until Stage 3), split-payments sheet, customer chip with live balance, hold/resume carts, receipt from the POSTED rows with image/PDF/text share |
| **کالاها** | search, filters (کم‌موجود/بدون موجودی/غیرفعال), margin preview, add/edit with barcode + opening stock + avgCost seeding, CSV export, bulk price change with batch undo |
| **مشتریان** | balance chips (بدهکار/بستانکار semantics), filters incl. دیرکرد, opening balance, detail screen with FIFO receive preview, aging buckets, running-balance ledger, three editable polite reminder templates (system share only), write-off, statement export |
| **گزارش** | minimal: today/7-day/month totals, invoice count, average ticket, payment mix, top-5 products, PDF summary |

Shop settings: info + receipt footer, numbering (prefix + next, only
increasing), rounding step, negative-stock policy, credit-limit mode,
price-edit permission, low-stock default, privacy default, integrity check
(`verifyIntegrity` — recompute and REPORT, never auto-fix), and the
ParentLock-guarded typed-confirmation wipe inside one transaction.

### Scanner decision (brief §SCANNER)

`BarcodeScanner` interface + two shipped implementations: **keyboard-wedge**
(hardware/Bluetooth scanners are keyboards; `WedgeBuffer` detects fast bursts
ending in Enter, min length 4, discards over-long human input) and **manual
entry**. The camera scanner is a documented follow-up: `mobile_scanner`
(ML Kit unbundled, ~1.5–2 MB, needs Play Services) and `flutter_zxing`
(bundled, ~2–4 MB) both risk the ≤2 MB stage budget on top of the core, and
the brief requires the app to work without Google services. Numbers and the
Stage-3 plan: SHOP_DOMAIN.md §7. Beep-on-scan is also deferred (no suitable
short asset; vibration ships, dual-tick distinguishes a failed lookup).

## 2. Tests

**115 new tests, all green** (270 total across personal2):

| Suite | Count | Catches |
|---|---|---|
| shop_domain (pure) | 40 | rounding, fixed-point parse/format, FIFO, aging, avgCost, low stock, reminder templates, **property-style invariants over 500 random ops and 200 random FIFO allocations** |
| shop_dao (in-memory SQLite) | 18 | posting atomicity (failure mid-transaction), void exactness, numbering, barcode uniqueness, warn/block, FIFO on live rows, integrity, held carts, bulk price undo |
| v47 migration | 5 | fresh shape, upgrade 46→47 with live rows, **INTEGER-not-REAL money columns**, index presence, backup name filter |
| wedge buffer | 7 | scanner burst heuristic, reset, over-long discard, callback |
| shop CSV | 10 | dialect, validation errors, Persian digits, quoted commas, duplicates, isolate wrapper |
| shop backup round-trip | 1 | export → restore with Persian text and the balance invariant |
| goldens + layout | 25 | day/night (dashboard, POS cart, customers) + 24 layout pumps at 320/360/412 × 1.0/1.3 RTL |

### Real bugs the tests caught before any device ran

1. **The v47 onUpgrade block was missing** — the tables existed on fresh
   installs only; every upgrading device would have crashed. (Same class of
   bug as the Stage-1 `assets/data/` find; the migration test earns its keep
   every stage.)
2. **Invoice numbering** — the settings row was never seeded, so every post
   allocated «1» and the second sale died on the number's UNIQUE index.
3. **Wedge over-long burst** — the expiry flag stopped digits but Enter still
   fired a "scan" of the user's typed text.
4. **FractionallySizedBox directly inside a Row** — unbounded constraints
   (w=Infinity) on the dashboard's payment-mix bar; now `Expanded(flex)`.
5. **`--1.5` and `-1.5 → -500`** — the fixed-point formatter/parser sign
   handling (Stage-2 domain tests, first run).
6. **Persian decimal separator (٫ U+066B)** didn't parse at all.

## 3. Budgets

| Metric | Budget | Measured | Verdict |
|---|---|---|---|
| arm64 APK growth | ≤ +2 MB | **+318,858 bytes (+0.30 MB)** — 48,499,823 B (stage-1) → 48,818,681 B (46.55 MB), `flutter build apk --release --no-pub` exit 0 | **PASS** |
| Cold start | ≤ +50 ms | needs a device (no phone attached) | pending device run |
| Nothing before first frame | hard | all providers lazy; dashboard is a FutureProvider read on demand | by construction |
| Search latency | debounced 150 ms, indexed prefix queries | `LIKE 'prefix%'` on normalized_name + barcode UNIQUE lookup | by construction |
| CSV import in isolate | required | `Isolate.run` + 200-row chunked transactions | done |

`flutter build apk --release --no-pub` exit 0; the delta above leaves ~1.7 MB
of the stage budget unspent — enough headroom for the Stage-3 camera scanner
decision to be made on real numbers.

## 4. Open questions / deferred

1. **Camera scanner** — deliberately not shipped (§SCANNER above); the
   interface is the contract Stage 3 implements.
2. **Reminders** — settings fields and the SoftNotifier integration points
   exist (`reminders_enabled`, quiet hours, ids 16000+ free); the daily
   re-arm scheduler hook is Stage 3 work alongside the cheque module.
   Nothing fires by default.
3. **CSV import UI** — the parser, validator, preview data model and chunked
   writer are shipped and tested; the file-picker sheet with the row-level
   error preview screen lands in Stage 3 (the brief's preview UI). Export is
   wired into the products tab today.
4. **Price history timeline** on product detail — the `priceChange` table
   records batches with undo; the dedicated timeline view is Stage 3 polish.
5. **Device performance numbers** (10k products / 50k lines / 2k customers)
   need the `--profile` device run; the structural work (indexes, seek
   pagination, debounce, isolates) is in place.
6. **Unit seeding** uses a fixed Persian list (عدد، کیلوگرم، گرم، بسته،
   کارتن، لیتر، متر); the units editor UI is Stage 3.

## 5. Commits

- `119c9fe` v47 schema + fixed-point domain + 40 unit tests
- `99102b4` the transactional DAO (+18 tests)
- `51002a9` the stage-2 screens + registration
- `2ef8762` wedge over-long-burst fix
- `c21a892` CSV isolate service + goldens + backup round-trip (+35 tests)
- (final) analyze/suite/APK measurement + this report

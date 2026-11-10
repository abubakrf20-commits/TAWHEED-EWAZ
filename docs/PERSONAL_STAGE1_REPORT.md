# Personal tools — stage 1 report

> **عکس تاریخ‌دار — Historical snapshot.** این سند وضعیت را در شاخه و تاریخ خودش ثبت
> می‌کند و خوانده‌شدنش به‌عنوان «وضعیت امروز» درست نیست. مرجع فعلی فقط `AGENTS.md`
> (ریشهٔ مخزن) و `docs/SECTIONS_1_9_0.md` است؛ فهرست کامل در `docs/README.md`.


«خودرو» and «خانه» on the shared care engine, inside the existing «اطلاعات من»
section. Branch `personal/stage1-care`, schema **45**. Nothing was added to
Home or More, and there is no hub page.

- Inventory and plan: `docs/PERSONAL_TOOLS_INVENTORY.md`
- Engine contract: `docs/CARE_ENGINE.md`

---

## 1. What the user sees

**اطلاعات من → خودرو**

- Empty state: «هنوز خودرویی ثبت نشده» + «افزودن خودرو».
- Adding a car stores make/model/colour/plate/fuel, then offers the 15
  suggested services; picks become tasks with editable intervals.
- Header card: display name, plate, current km, days since the last reading,
  «ثبت کیلومتر».
- Two stat cards: «هزینهٔ امسال» (Jalali year, records + fuel) and
  «مصرف سوخت» (l/100 km, or «داده کافی نیست»).
- «سررسیدهای بعدی»: one row per active task, worst first, with band chip,
  progress bar and the limiting dimension first («۸۰۰ km یا ۲۰ روز»).
- «ثبت سرویس انجام‌شده» (one or several tasks at once), «ثبت سوخت»,
  «افزودن خودرو», plus the last four records.
- App bar: history, settings, back. A tap on a care reminder opens the exact
  task sheet.

**اطلاعات من → خانه**

Four tab chips: «سرویس‌ها», «قبض‌ها», «گارانتی», «اشتراک‌ها».

- Services: a season banner (winter/summer pack) that adds the missing items in
  one tap, then the same task rows.
- Bills: the next unpaid period per bill with its band; «پرداخت شد» records a
  payment against the period key; the last payments render as small bars.
- Warranties: item, store, serial, purchase date, computed (and editable)
  expiry, days left, receipt photos.
- Subscriptions: name, amount, period, next charge, monthly total.
- A one-line disclosure: this data lives only on the device and is included in
  the app's backup.

Both pages are flat: `AppCard` (radius 22, 0.5 dp border), duotone tiles, the
tool's identity colour (`#3A5BA0` car, `#0F7B6C` home), semantic bands from the
theme tokens. No gradient, blur or glow anywhere.

## 2. The editable defaults (all `reviewed: false`)

Source: `assets/data/care_templates.json` — note shown under the picker:
«پیشنهادی؛ طبق دفترچهٔ خودرو یا راهنمای سازنده تنظیم کنید.»

### Car (15)

| item | schedule | km | days | window |
| --- | --- | --- | --- | --- |
| روغن موتور | both | 5,000 | 180 | — |
| فیلتر روغن | both | 5,000 | 180 | — |
| فیلتر هوا | both | 15,000 | 365 | — |
| فیلتر کابین | both | 10,000 | 365 | — |
| لنت ترمز جلو | distance | 30,000 | — | — |
| لنت ترمز عقب | distance | 50,000 | — | — |
| تسمه تایم | both | 60,000 | 1,460 | — |
| جابه‌جایی لاستیک | distance | 10,000 | — | — |
| تعویض لاستیک | both | 40,000 | 1,825 | — |
| باتری | time | — | 1,095 | — |
| ضدیخ | time | — | 730 | — |
| بیمه شخص ثالث | time | — | 365 | — |
| بیمه بدنه | time | — | 365 | — |
| معاینه فنی | time | — | 365 | — |
| عوارض و مالیات سالانه | time | — | 365 | — |

### Home (7)

| item | schedule | days | Jalali window |
| --- | --- | --- | --- |
| سرویس پکیج و شوفاژ | time | 365 | 7/1 – 7/30 |
| سرویس کولر | time | 365 | 2/1 – 2/31 |
| فیلتر تصفیهٔ آب | time | 180 | — |
| فیلتر هود | time | 90 | — |
| شارژ کپسول آتش‌نشانی | time | 365 | — |
| باتری دتکتور دود | time | 365 | — |
| تمیزکاری دودکش | time | 365 | 8/1 – 9/30 |

Season packs: `winter` = پکیج، دودکش، کپسول، دتکتور · `summer` = کولر، هود،
آب، کپسول.

**These numbers are suggestions, not authority.** Every item is stored with
`reviewed:false`, the report lists them so the owner can correct them once, and
the picker states the source explicitly instead of implying the app knows the
car.

## 3. Notifications

| | |
| --- | --- |
| channel | `care_reminders_v1` — «یادآوری ابزارهای شخصی» |
| id range | **13000–13999**, documented in `notification_ids.dart` |
| id formula | `13000 + day-of-year`, one grouped event per day ⇒ one id per day |
| payloads | `care_car_task_<id>`, `care_home_bill_<id>`, `care_<kind>_warranty_<id>`, `care_home_subscription_<id>`, `care_day_<yyyy-MM-dd>` |
| cancellation | by payload prefix `care_` only — never an id sweep |
| window | 30 days |
| daily cap | 3 items per grouped notification (setting) |
| quiet hours | default 22:00–07:00; **suppress**, never shift |
| categories | service / bills / warranty / subscriptions, each switchable |
| tap | deep link to the exact screen, cold start included |

Delivery goes through the app's single `NotificationService`; there is no
second plugin instance and no new Android permission.

## 4. Storage and backup

- 9 tables (`care_asset`, `care_task`, `care_record`,
  `care_odometer_reading`, `care_fuel_log`, `care_bill`, `care_bill_payment`,
  `care_warranty`, `care_subscription`) + 4 indexes, raw SQL with
  `IF NOT EXISTS`, created in `onCreate`, in `beforeOpen` and in the v45
  migration step.
- **No codegen**: no `build_runner` run; no `.g.dart` edited.
- Backup is a whole-file `VACUUM INTO`, so the care tables travel automatically;
  the wipe is `sqlite_master`-driven, so they are emptied too. Attachments live
  under `<documents>/app_data/attachments/care/`, which the wipe already
  deletes.
- Attachments: system photo picker (`file_picker`), private copy,
  max 1600 px long side, JPEG q80, EXIF stripped, relative paths, deleted with
  the record.

### Deliberate deviation

Dates are stored as **`yyyy-MM-dd` calendar days**, not UTC instants. A due
date is a day; storing an instant would make «today» depend on the timezone the
row was written in. The repository converts at the boundary.

## 5. Tests and numbers

| | |
| --- | --- |
| new source | 17 Dart files, ~7,700 lines under `lib/features/personal` |
| new tests | 6 files + 6 goldens, 113 tests under `test/features/personal` (+5 schema tests) |
| engine suite | 62 tests (bands, three schedule types, prediction guards, seasonal, fuel, Jalali cost, bill keys, subscriptions, warranty, due items) |
| templates | 15 tests against the **shipped** JSON |
| planner | 17 tests (horizon, quiet hours, categories, grouping, cap, payloads, ids) |
| storage | 12 round-trip/cascade tests + 5 schema-v45 tests |
| layout | 12 pump tests (320/360/412 dp × 1.0/1.3) + 6 goldens — **no overflow at 320 dp / scale 1.3**, including a page with history, fuel and two tasks |
| `flutter analyze lib` | 0 issues |
| `tools/quality_check.py --strict` | 7/7 at zero |

Measured on this machine (Windows, debug VM, `flutter test`):

| measurement | result |
| --- | --- |
| template JSON | 5,357 B / 22 defaults parsed in **~150–165 µs**; parsed once per process and memoized, so it is never on a frame |
| `CareDueItemsProvider.upcoming` (22 tasks, 2 assets, 40 records, 10 readings, 4 bills, 3 warranties, 3 subscriptions → 11 due items in 30 d) | **~3.9–4.6 ms** per call in the debug VM, i.e. ~90–200 µs per task |
| one `careStatusOf` (time-only task, no odometer) | **~90 µs** |
| **calibration of the same VM** | one plain `DateTime.difference(...).inDays` costs **~29 µs** here |

That last row matters: the engine makes roughly three day-differences per task,
so its cost is essentially the VM's own `DateTime` cost, not engine work. These
are **unoptimized debug-VM** numbers from `flutter test` — no AOT figures and no
device profile exist for this stage, because no Android device was attached.
What is safe to say: the whole snapshot evaluation is a sub-millisecond AOT job
(~22 tasks), it runs once per screen load and once per reminder sync, and the
template JSON is parsed once and cached, so neither is on the rebuild path.

## 6. Bugs found and fixed while testing (worth knowing)

1. **`careNextUnpaidBillPeriod` could return a PAID period.** It advanced one
   day past a due date, which re-entered the same month, so the loop spun on
   the same key and the guard returned the paid period as if it were unpaid.
   It now advances to the **start of the next period** (month, pair or custom
   span). Covered by a test.
2. **`CareTemplate.intervalLabel` never grouped kilometres.** The regex was
   written with escaped backslashes inside a raw string, so it matched a
   literal `\B` and did nothing. It now uses the shared
   `NumberFormat.formatPlain`, the same formatter the status rows use.
3. **`_WarrantySheet` read `widget` in a field initializer** — a compile error;
   the purchase date is now initialized in `initState`.
4. **The reptile of duplicate `_` parameters** in four `separatorBuilder`s and
   one `errorBuilder` (Dart 3.7 rejects repeated wildcards in some positions) —
   renamed to real parameters.

## 7. Open questions for the owner

1. **Intervals.** The 15 + 7 defaults are generic. If you want them to match a
   specific car (e.g. تسمه تایم 90,000 km for a particular engine), say the
   model and I will change the JSON — the tests read the shipped file.
2. **Bimonthly bills.** The period key is `<year>-<month>/b` on the pair's first
   month. If you would rather see «مرداد و شهریور» in the bill row, that is a
   label change, not a data change.
3. **Quiet hours** default to 22:00–07:00 and only *suppress*. A 09:00
   preference with quiet hours active means a reminder that lands at 23:00 is
   dropped rather than moved to 07:00. Confirm this is the wanted behaviour.
4. **Warranty lead** is 60 days for anything expiring later than 30 days out,
   30 days otherwise; the reminder is one notification, not a weekly nag.
5. **Cost double-counting.** `completeTasks` writes the cost on the **first**
   record of a multi-task completion only, so a combined «روغن + فیلتر» shows
   one price. If you want per-line prices, the completion sheet needs one cost
   field per selected task.
6. **iOS.** The engine and the store are platform-neutral; the picker,
   attachments and notifications are not yet wrapped for iOS.

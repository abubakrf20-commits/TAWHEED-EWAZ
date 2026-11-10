# Care engine — the shared contract

`lib/features/personal/care_engine/` is pure Dart. It has no Flutter import, no
Drift, no `dart:io`, no clock of its own: every function takes `now` as a
parameter, which is what makes the whole feature testable to the day.

Stage 1 ships two tools on top of it («خودرو», «خانه»). Stage 2/3 add tools by
feeding the same models, not by copying the math.

---

## 1. Entities (`care_models.dart`)

| Type | Purpose | Notes |
| --- | --- | --- |
| `CareAsset` | a car or a home | `meta` is JSON: car `make/model/color/plate/fuelType`, home `nickname`. Open schema — a new field is not a migration. |
| `CareTask` | one recurring piece of upkeep | `scheduleType` is `time`, `distance` or `both`; `window` makes it seasonal; `active` hides it without deleting history |
| `CareRecord` | one completed service / expense | keeps a **snapshot of the task title**, so history stays readable after a rename or a delete |
| `OdometerReading`, `FuelLog` | car telemetry | highest km across all three sources is «current km» |
| `Bill`, `BillPayment` | household bills | the payment carries a **stable period key** |
| `Warranty` | a purchase with an expiry | `expiryDate` is stored, not recomputed, so it stays editable |
| `Subscription` | a recurring paid service | `monthlyAmount` divides a yearly price by 12 |
| `CareSnapshot` | everything one page needs | plus `assetsOf/tasksOf/recordsOf/...` and `currentKm()` |

**Dates are calendar days** (`yyyy-MM-dd`), not UTC instants. A due date is a
day, not a moment: storing an instant makes «due today» depend on the timezone
the record was written in. The repository converts at the boundary
(`careDateToStore` / `careDateFromStore`) and drops any time component.

## 2. Status (`careStatusOf`)

```
time fraction     = elapsed days / interval days
distance fraction = (current km − last-done km) / interval km
progress          = max(time, distance)      // neither can hide the other
```

Anchors: the last completion; else `firstDueDate − interval`; else `createdAt`.

Bands (fixed by the brief):

| progress | level |
| --- | --- |
| `< 0.65` | good («خوب») |
| `0.65 … < 0.9` | near («نزدیک») |
| `0.9 … 1.0` | urgent («فوری») |
| `> 1.0` | overdue («دیر») |

A distance-only task with no odometer reading reports `progress == 0` and no
`kmRemaining` — inventing a number would be worse than showing «—».

### Seasonal tasks

A `CareWindow` is a **Jalali** month/day range. `careWindowDates(window, date)`
resolves it inside the Jalali year of `date`, and a window that wraps the new
year (e.g. 12/20 → 1/10) ends in the following year.

`SeasonalState` is `before`, `inWindow`, `missed` or `before` (next cycle) after
a completion inside the current window. Progress inside the window is
elapsed/window-length, then mapped into `0.65 + 0.35·f` so a task inside its
window never reads as «good» and never as overdue until it is missed.

### Prediction

`carePredictedDueDate` needs **two readings spanning at least 7 days**, both
inside the last 60 days, with a positive km pace. One reading says nothing
about pace. The result feeds `CareStatus.predictedDueDate` and the reminder
provider's due date.

## 3. Money and consumables

- `careFuelConsumption` — the standard full-to-full method: litres burned
  between two full tanks (including partial fills inside the span) over that
  distance, × 100. Fewer than two full tanks → `null`, and the card shows
  «داده کافی نیست».
- `careYearCost` — records + fuel inside the **Jalali** year of `now`.
- `careSubscriptionsMonthlyTotal` — monthly items at face value, yearly / 12.

## 4. Bills

`careBillPeriod(bill, date)` returns the period covering (or next after) a date:

| recurrence | key | due date |
| --- | --- | --- |
| `monthly` | `1404-07` | `dueDay` of the Jalali month, clamped to the month length |
| `bimonthly` | `1404-07/b` | `dueDay` of the pair's first month, pairs counted from `firstDueDate` on a linear month axis |
| `custom` | `d<index>` | anchor + `index × customDays` (+ `dueDay − 1`) |

`careNextUnpaidBillPeriod` walks forward over paid keys, advancing to the
**start of the next period** (see §8 — a due-date cursor loops on the same key
once the due day has passed).

`careBillLevel` is day-based: `> 7` good, `≤ 7` near, `≤ 3` urgent, negative
overdue. `careRecentBillPayments` returns the last N, oldest first, for the
consumption bars.

## 5. Warranties

`careWarrantyExpiry(purchase, months)` adds months on the **Jalali** calendar
and clamps the day to the target month's length. The result is stored, so the
user can correct it without the app overwriting the correction.

## 6. Due items — the reminder contract

```dart
abstract class DueItemsProvider {
  List<CareDueItem> upcoming({
    required CareSnapshot snapshot,
    required DateTime now,
    Duration horizon = const Duration(days: 30),
  });
}
```

`CareDueItemsProvider` is the default implementation. It emits, per active
asset (plus subscriptions, which are asset-free):

| category | source | remind date | payload |
| --- | --- | --- | --- |
| `service` | active tasks | `due − remindBeforeDays` (the due date itself inside a window) | `care_car_task_<id>` / `care_home_task_<id>` |
| `bills` | the next unpaid period | `due − 3 days` | `care_<kind>_bill_<id>` |
| `warranty` | expiry within 60 days | `expiry − 60` or `− 30` | `care_<kind>_warranty_<id>` |
| `subscriptions` | active subscriptions | `next charge − 2 days` | `care_home_subscription_<id>` |

Items come back sorted by due date. **No UI consumes this in stage 1** — the
reminder scheduler does, and later stages will.

## 7. Reminder planning and delivery

`CareReminderPlanner.plan` (pure) applies, in order: the enabled switch, the
category switches, quiet hours (suppress, never shift), the 30-day horizon, a
reminder that already passed today, and one-notification-per-day grouping with
a `dailyCap` on the number of items named.

`CareReminderScheduler` only maps those events onto the app's single
`NotificationService`:

- channel `care_reminders_v1` / «یادآوری ابزارهای شخصی»;
- ids `13000 + day-of-year`, so the range is fixed at 13000–13999 regardless of
  how many tasks exist (one event per day ⇒ one id per day, no collisions);
- cancellation is by payload prefix `care_`, never by an id sweep, so azan
  (100–524), reminders (1000–1999) and tasks (10000–10999) are untouchable;
- a tap deep-links to the exact screen (`CarScreen(initialTaskId:)` or the home
  page), with a cold-start buffer when the notification launched the app.

## 8. Invariants worth not breaking

1. **Combined tasks take `max`, never an average.** Averaging lets a task with
   a huge km interval hide behind its time interval.
2. **`careNextUnpaidBillPeriod` advances by period, not by day.** Advancing one
   day past a due date re-enters the same month, so the loop returns a *paid*
   period as if it were unpaid (this bug existed and is now covered by a test).
3. **`careWindowDates` handles a wrapping window.** `end <= start` means next
   year, not an empty window.
4. **Prediction refuses thin data.** Two readings, ≥ 7 days apart, ≤ 60 days
   old.
5. **The engine never reads the clock.** A test pins any day — including a
   Jalali month boundary — and gets a deterministic answer.

## 9. Test map

| File | Covers |
| --- | --- |
| `test/features/personal/care_engine/care_engine_test.dart` | bands 0.64/0.65/0.9/1.0/1.01, time/distance/both, prediction guards, seasonal states, fuel math, Jalali-year cost, bill keys (monthly/bimonthly/custom), next-unpaid, bill levels, subscriptions, warranty clamping, due-item categories/payloads/horizon |
| `test/features/personal/care_engine/care_templates_test.dart` | the SHIPPED JSON: unique keys, valid intervals, `reviewed:false`, approved note, pack references, malformed input |
| `test/features/personal/services/care_reminder_planner_test.dart` | horizon, quiet hours, category switches, grouping, cap, payload shape, id range |
| `test/features/personal/data/care_repository_test.dart` | every entity round trip, completion/undo atomicity, cascade deletes, day-granular dates |
| `test/core/database/app_database_schema_v45_test.dart` | fresh schema, v44 upgrade keeps existing rows, retryable migration, backup round trip |
| `test/features/personal/presentation/care_screens_test.dart` | both pages at 320/360/412 dp × 1.0/1.3, empty states, actions |
| `test/features/personal/presentation/care_golden_test.dart` | 6 baselines: car day/night/empty, home day/night/empty |

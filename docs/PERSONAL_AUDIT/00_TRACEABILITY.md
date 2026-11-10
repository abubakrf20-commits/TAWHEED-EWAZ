# PERSONAL AUDIT — 00 TRACEABILITY

Audit branch `personal/audit-and-polish` (base: release/1.8.0 @ e53cd46).
Every REQUIRED-SCOPE item → status → evidence. **No earlier report or commit
message was trusted**; every row was verified against the working tree.

Statuses: DONE / PARTIAL / MISSING / WRONG / FALSE CLAIM (old report says it
exists but the code does not).

## A) Care engine + «خودرو» + «خانه»

| Item | Status | Evidence | Notes |
|---|---|---|---|
| CareAsset/CareTask/CareRecord/Odometer/Fuel/Bill/Warranty/Subscription tables | DONE | `lib/features/personal/data/care_tables.dart` (v45), `care_dao.dart` | raw-SQL on the v45 precedent |
| Schedule types time/distance/both | DONE (data) | `care_templates.dart` CareScheduleType | no UI consumes it yet |
| Templates from JSON, editable, reviewed:false | PARTIAL | `assets/data/care_templates.json` + `care_repository.templates()` | asset was unreachable until `assets/data/` was declared in pubspec (fixed in stage-2 commit `4f7b0c3`); no editor UI |
| **خودرو UI (all screens)** | **MISSING** | `find lib/features/personal -name "*screen*"` → empty | the entire «خودرو» family has ZERO user-visible surface; the data layer is complete but invisible |
| **خانه UI (tabs services/bills/warranties/subscriptions)** | **MISSING** | same evidence | same |
| Status levels good/near/urgent/overdue | MISSING | no `care_status` consumer outside engine | `care_engine/care_status.dart` exists, untested against UI |
| Predicted due date from odometer trend | MISSING | no implementation found | |
| Reminders (before/due/overdue + km threshold) | PARTIAL | `care_reminder_scheduler.dart` (channel «یادآوری ابزارهای شخصی», id 13000+) | scheduler exists; nothing triggers it because no UI creates care data |
| Registration as a tool entry | **FALSE CLAIM** | the v45 session reports claimed personal-tools registration; `more_registry.dart` has no care entry and `personal_info_screen` has none either | the engine is orphaned data |

## B) «دفتر مالی» + «دفتر دَین» + تبدیل واحد

| Item | Status | Evidence | Notes |
|---|---|---|---|
| **دفتر مالی (Obligation, installments, cheque/loan, timeline, reminders)** | **MISSING** | grep «دفتر مالی»/Obligation → no feature folder, no tables | not started |
| **دفتر دَین (Person/DebtEntry/payments, net balances, polite reminders)** | **MISSING** | grep «دفتر دین»/DebtEntry → nothing | not started |
| تبدیل واحد tab inside Calculator | PARTIAL | `calculator_tool_panels.dart` UnitPanel + `calculator_tools.dart` (Length/Mass/Volume/Temperature) | panel exists with its own mode slot |
| Unit categories Area + Speed | **MISSING** | `calculator_tools.dart` has no speed/area tables | spec requires them |
| **«محلی ★» local units (من/سیر/مثقال/نخود/خروار + editable base)** | **MISSING** | grep من/سیر/خروار in calculator → nothing | spec: ship the five defaults flagged unverified, editable bases, everything else empty |
| Recent conversions + favorite pairs | **MISSING** | no persistence in UnitPanel | |
| Segmented «حساب \| تبدیل واحد» with remembered tab | PARTIAL | calculator has a mode selector (`_CalcMode`) | does it remember the last tab? to verify in the build pass |

## C) صله رحم + کفاره و فدیه + قلک + قضایار

| Item | Status | Evidence |
|---|---|---|
| صله رحم (Relative/ContactLog, intervals, reminders, gift ideas) | **MISSING** | grep «صله رحم»/Relative → no feature, no tables |
| کفاره و فدیه (data-driven kaffara engine) | **MISSING** | grep «کفاره» → only incidental mentions in fasting/hajj content screens, no engine |
| قلک (SavingsGoal/Deposit, ETA, milestones) | **MISSING** | grep «قلک»/SavingsGoal → nothing |
| قضایار (counters per prayer, assisted estimate, rings) | **MISSING** | grep «قضایار» → nothing |

## D) «دفتر عادت کودک»

| Item | Status | Evidence |
|---|---|---|
| Data (Child/Habit/PrayerConfig/HabitLog/StarTxn/Reward/RewardRequest/Settings) | DONE | `lib/features/personal2/kids/data/kids_dao.dart`, v46 tables; 46 unit tests |
| Prayer chips tied to the REAL schedule | DONE | `child_mode_screen.dart` reads `prayerTimesProvider`; state machine unit-tested (locked/NOW/late/missed, midnight rollover) |
| Parent PIN (shared ParentLock) | DONE | `personal2/shared/parent_lock.dart` (PBKDF2 120k off-isolate, throttle) |
| Parent home / child setup / child mode / habits / rewards / approvals / weekly report | DONE | 7 screens; layout-guard tests at 320/360/412 × 1.0/1.3 RTL |
| Weekly/monthly report + share | PARTIAL | weekly DONE (chart+chips+bars+tip+image/PDF); **monthly variant MISSING** |
| Optional evening summary reminder | PARTIAL | settings fields exist; the re-arm scheduler ships with stage 3's `ShopReminders` pattern — kids-side wiring is the remaining bit |
| Registration | DONE (moved) | More page «ابزارها و پیشرفت» as `kids-habits` (commit `6e3648c`, user's call) |

## E) «دفتر مربی قرآن»

| Item | Status | Evidence |
|---|---|---|
| Data (ClassGroup/Student/Session/Attendance/LessonRecord, editable scales/tags) | DONE | `personal2/teacher/…`, v46; validated 1..604 / 1..15 |
| Attendance %, streak, progress math, juz via mushaf metadata, averages w/o ranking | DONE | `teacher_logic.dart` + 47 tests |
| Screens (class home, lesson sheet with read-only mushaf preview, profile, parent report, class mgmt) | DONE | 5 screens; preview-only tested (does not move `quran_last_page`) |
| Class-level reminders (start/unrecorded/weekly) | MISSING (deferred, documented) | settings fields exist; scheduler hook is the shared `ShopReminders` pattern — teacher-side wiring remaining |
| Registration | DONE (moved) | More `teacher-ledger` |

## F) «حساب مغازه»

| Item | Status | Evidence |
|---|---|---|
| Accounting core (integers, one transaction, immutable docs, audit) | DONE | `shop_domain.dart`/`shop3_domain.dart`, SHOP_DOMAIN.md; 73 pure tests + 32 DAO tests incl. atomicity |
| POS / customers / suppliers / purchases / expenses / cheques / cash / stock count | DONE | 12 screens + More sheet; stage-2/3 reports |
| Reports (net/gross/net profit, mix, top products, stock valuation, aging) | PARTIAL | figures + minimal tab DONE; **custom Jalali range picker, slow-movers screen, drill-downs MISSING** |
| CSV export of everything as ZIP + PDF/image statements | PARTIAL | products CSV + statements DONE; **full ZIP export MISSING** |
| XLSX | SKIPPED (documented) | budget |
| Registration | DONE (moved) | More `shop-ledger` |

## Known FALSE CLAIMS from earlier session reports

1. «care engine registered in personal tools» — FALSE: no entry ever existed.
2. «assets/data/care_templates.json loads» — was FALSE until stage-2 (the
   directory was undeclared in pubspec; fixed in `4f7b0c3`).
3. Stage-2 interim report's «status: partial» rows for unit conversion — the
   panel existed but Area/Speed/local units never did.

# Stage 3 — صله رحم، کفاره و فدیه، قلک، قضایار

> **عکس تاریخ‌دار — Historical snapshot.** این سند وضعیت را در شاخه و تاریخ خودش ثبت
> می‌کند و خوانده‌شدنش به‌عنوان «وضعیت امروز» درست نیست. مرجع فعلی فقط `AGENTS.md`
> (ریشهٔ مخزن) و `docs/SECTIONS_1_9_0.md` است؛ فهرست کامل در `docs/README.md`.


Working branch: `personal/stage3-family-faith`, cut from `personal/stage1-care`
(which carries stage 1 *and* stage 2 — 16 commits above `release/1.8.0`).

## Prerequisite check (done before any code)

| Needs | State |
| --- | --- |
| care engine + reminder conventions | `lib/features/personal/care_engine/**`, `services/care_reminder_{planner,scheduler}.dart` |
| personal-tool registration pattern | tiles inside «اطلاعات من» (`personal_info_screen.dart`), `VaultGuard` on the sub-routes |
| Jalali utils | `shared/utils/shamsi_date_picker.dart`, `hijri_utils.dart` |
| money field + formatters | `shared/utils/number_format.dart`, the finance money field in `finance_sheets.dart` |
| finance ledger (kaffara → obligation) | `finance_models.dart` `Obligation`, `DriftFinanceRepository.saveObligation` |
| backup/restore | `backup_service.dart` uses whole-file `VACUUM INTO` → new tables ride along with no registry edit |
| notification service | one service, reserved ranges documented in `shared/services/notification_ids.dart` |

Nothing was missing, so the work proceeds.

## What already exists for qaza/kaffara (searched, not assumed)

* `assets/content/sawm.json` → `qadaKaffarah[0..2]`: «قضا (وجوب و حکم)»,
  «کفاره» (Shafi'i: slave → 60 consecutive fasts → feeding 60 poor, one mudd
  ≈ 750 g each), «فدیه» (one mudd ≈ 750 g per missed day). **Text only, no
  structured amounts.**
* `assets/content/hajj.json` also mentions ihram kaffara; it stays outside the
  four categories the spec lists (`other` at most, and the text is narrative,
  not a computable component list).
* No qaza counter, no fidya table, no madhhab setting: the only madhhab-ish
  setting is `AppSettings.asrMethod` (`AsrMethod.shafi|hanafi`), and the app
  states Shafi'i as its default everywhere.

Consequence: the kaffara engine is **data-driven and review-gated**. The rule
file maps the app's own text verbatim; every rule ships `reviewed: false`, so
production shows the EmptyState until the owner approves. Drafts are visible
only behind a debug-only toggle.

## Layout

```
lib/features/personal/family_faith/
  data/family_faith_tables.dart        # schema 47, additive raw SQL
  data/family_faith_repository.dart    # relatives + contacts + gifts, savings, qaza
  relatives/relative_models.dart       # Relative, ContactLog, status math
  relatives/gift_ideas.dart            # model + parse + filter
  relatives/relative_reminder_{planner,scheduler}.dart
  savings/savings_models.dart          # goal/deposit + progress/ETA/milestones
  qaza/qaza_models.dart                # counters, log, estimate wizard math
  kaffara/kaffara_models.dart          # rule schema + engine (pure)
  family_faith_providers.dart          # one store per tool, fake-able repositories
  presentation/family_faith_style.dart # four identity colours
  presentation/relatives_screen.dart + relatives_sheets.dart + gift_sheet.dart
  presentation/kaffara_screen.dart
  presentation/savings_screen.dart + savings_sheets.dart
  presentation/qaza_screen.dart + qaza_sheets.dart
assets/data/gift_ideas.json            # 50 ideas, 6 occasions, 3 budgets
assets/data/kaffara_rules.json         # mapped from sawm.json, reviewed:false
```

## Conventions carried over

* Raw-SQL tables + `customSelect`; **no codegen**; `IF NOT EXISTS` everywhere.
* Day-granular `yyyy-MM-dd` storage; Jalali in the UI only.
* Boundaries: engines are pure Dart (no Flutter, no Drift) and unit-tested.
* Store pattern: persist first, republish second; reminders synced on every edit
  through an injectable scheduler interface so widget tests never touch the
  plugin.
* Flat design: `AppCard` (radius 22), `DuotoneIconTile`, tokens only. Identity
  colours: صله رحم `C0507A`, کفاره و فدیه `D9822B`, قلک `2E8B3D`, قضایار `6A5BA8`.

## Notification ranges (documented in `notification_ids.dart`)

| Range | Owner | Shape |
| --- | --- | --- |
| 15000–15399 | صله رحم | `15000 + day-of-year`, payload `family_relative_*` |
| 16000–16029 | قضایار | per-prayer, today / tomorrow / day-after, payload `family_qaza_*` |
| 16500–16999 | قلک | `16500 + stableSlot(goalId, 499)`, payload `family_saving_*` |

## Order of work (one small commit each)

1. plan + tables + models
2. relatives engine + gift catalogue asset
3. savings + qaza engines
4. kaffara engine + rule file + JSON schema test
5. relatives screens + gift sheet
6. kaffara screen + finances hook
7. savings + qaza screens
8. routes / tiles / notification ids / deep links / schema 47 migration
9. tests + goldens
10. report + `PROGRESS.md`

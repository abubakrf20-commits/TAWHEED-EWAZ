# Personal tools — stage 1 inventory and plan

> **عکس تاریخ‌دار — Historical snapshot.** این سند وضعیت را در شاخه و تاریخ خودش ثبت
> می‌کند و خوانده‌شدنش به‌عنوان «وضعیت امروز» درست نیست. مرجع فعلی فقط `AGENTS.md`
> (ریشهٔ مخزن) و `docs/SECTIONS_1_9_0.md` است؛ فهرست کامل در `docs/README.md`.


Scope: «خودرو» (car) and «خانه» (home) inside the existing **«اطلاعات من»**
section. A shared **care engine** underneath both, so stage 2 and 3 can add
tools without a second copy of the status math.

Date: 2026-11-02 · branch `personal/stage1-care` · schema **45**.

---

## 1. What already existed (nothing here was invented)

| Concern | Existing piece | Reused how |
| --- | --- | --- |
| Entry point | `lib/features/personal_info/presentation/screens/personal_info_screen.dart` — tile grid + sections | two new tiles in a new section «خودرو و خانه», same tile recipe as the rest |
| Lock / PIN | `VaultGuard` wrapping the personal-info routes | the two routes are registered inside the same guarded shell |
| Routing | `lib/app/router/app_router.dart`, `route_names.dart` | four new `GoRoute`s (tool + history, per tool) |
| Notifications | `lib/shared/services/notification_service.dart` (`scheduleExactReminder`, `refreshScheduleMode`, tap stream) | care reminders go through it; no second plugin instance |
| Notification ids | `notification_ids.dart` ranges (azan 100–524, reminders 1000–1999, tasks 10000–10999) | new range **13000–13999** documented there |
| Boot work | `lib/app/state/boot_coordinator.dart` | `_syncCareReminders()` after the existing reschedule pass |
| Tap plumbing | `lib/app/router/main_shell.dart` | `onCareTapped` registered next to the existing reminder handlers |
| Database | Drift `AppDatabase` (was 44) | schema **45**, tables created in `onCreate` *and* `beforeUpgrade`/`beforeOpen` |
| Design kit | `AppCard`, `DuotoneIconTile`, `SectionHeader`, `careLevelColor`-style tokens | every surface is flat: no gradient, no blur, no glow |
| Backup | `backup_service.dart` — whole-database `VACUUM INTO` + `sqlite_master`-driven wipe | the new tables travel automatically; attachments live under `<documents>/app_data/`, which the wipe already deletes |
| Money | `NumberFormat.formatMoney` + `CurrencyStore.calculators` | every amount |
| Dates | `shamsi_date` (already a dependency) | Jalali windows, bill period keys, warranty expiry |

## 2. What the section must NOT gain

- **No hub / dashboard page.** No «دفتر زندگی», no landing card with counters.
- **Nothing on Home, nothing in More.** The only new entry points are the two
  tiles in «اطلاعات من».
- **No new heavy package.** Only `image` moved from `dev_dependencies` to
  `dependencies` (decode + downscale + EXIF strip); the picker reuses
  `file_picker`, which the app already ships.

## 3. Plan (as executed)

1. **Engine first** — `care_engine/care_models.dart`, `care_engine.dart`,
   `care_templates.dart`. Pure Dart: no Flutter, no Drift, no `dart:io`, so an
   iOS build reads the same models.
2. **Editable defaults** — `assets/data/care_templates.json`, every item
   `reviewed: false`, with the note «پیشنهادی؛ طبق دفترچهٔ خودرو یا راهنمای
   سازنده تنظیم کنید» shown in the picker.
3. **Storage** — raw SQL tables (`care_tables.dart`) + one `CareRepository`
   interface with a Drift implementation. No codegen: no `build_runner` run,
   no `.g.dart` touched.
4. **Reminders** — pure planner (`care_reminder_planner.dart`) + a scheduler
   that only maps planner events onto `NotificationService`.
5. **UI** — the two screens, their sheets, one shared history screen, one
   `care_widgets.dart` kit. Every list is lazy; no `BackdropFilter`.
6. **Tests** — engine boundaries, templates integrity, planner behaviour,
   storage round trip + v44→v45 migration, layout at 320/360/412 dp × scale
   1.0/1.3, six golden baselines.
7. **Docs** — this inventory, `CARE_ENGINE.md` (contract), and
   `PERSONAL_STAGE1_REPORT.md` (defaults for review, ids, numbers, open
   questions).

## 4. File map

```
lib/features/personal/
  care_engine/   care_models.dart    entities, enums, snapshot helpers
                 care_engine.dart    status math, prediction, fuel, bills,
                                     subscriptions, warranty, due items
                 care_templates.dart defaults parser
  data/          care_tables.dart    9 tables + indexes (raw SQL)
                 care_repository.dart abstract store + Drift implementation
  services/      care_settings.dart  reminder preferences (SharedPreferences)
                 care_reminder_planner.dart  pure planning
                 care_reminder_scheduler.dart  planner → NotificationService
                 care_attachment_store.dart    private 1600px JPEG copies
  presentation/  providers/care_providers.dart
                 screens/car_screen.dart, home_care_screen.dart,
                         care_history_screen.dart
                 widgets/care_widgets.dart, care_sheet_kit.dart,
                         care_car_sheets.dart, care_home_sheets.dart
```

Tests: `test/features/personal/**` and
`test/core/database/app_database_schema_v45_test.dart`.

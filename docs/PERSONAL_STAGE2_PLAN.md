# Personal tools — stage 2 plan («دفتر مالی» + «تبدیل واحد»)

> **عکس تاریخ‌دار — Historical snapshot.** این سند وضعیت را در شاخه و تاریخ خودش ثبت
> می‌کند و خوانده‌شدنش به‌عنوان «وضعیت امروز» درست نیست. مرجع فعلی فقط `AGENTS.md`
> (ریشهٔ مخزن) و `docs/SECTIONS_1_9_0.md` است؛ فهرست کامل در `docs/README.md`.


Stage 1 is the prerequisite and it is present on `personal/stage1-care`
(7 commits, `b309af1`…`6accd53`). What stage 2 reuses, verified by reading the
code before writing any:

| piece | where | used for |
| --- | --- | --- |
| raw-SQL additive tables (`IF NOT EXISTS`) + `Drift…Repository` over `customSelect` | `lib/features/personal/data/care_tables.dart`, `care_repository.dart` | finance tables below, no codegen |
| date storage as `yyyy-MM-dd` days | `careDateToStore` / `careDateFromStore` | every finance date |
| private photo pipeline (picker → 1600 px JPEG q80, EXIF stripped, relative path) | `services/care_attachment_store.dart` | cheque photo |
| reminder conventions (pure planner + scheduler, reserved id range, payload-prefixed cancel, channel) | `services/care_reminder_{planner,scheduler}.dart` | finance reminders, range 14000–14999 |
| sheet kit (title, field, date button, select row, switch row, submit, notice) | `presentation/widgets/care_sheet_kit.dart` | both finance forms and the debt sheets |
| money helper (`careMoney` → `NumberFormat.formatMoney` with the user's currency) | `presentation/widgets/care_widgets.dart` | every amount |
| table consent in the personal-info screen (`_tile` + `_openSection`) | `personal_info/presentation/screens/personal_info_screen.dart` | ONE new «دفتر مالی» tile |

Backup/restore needs no new code: it is a whole-file `VACUUM INTO` plus a
recursive `app_data/` archive, and it copies whatever tables exist — the new
tables and the cheque photos travel automatically. User-edited local units are
therefore stored in **a table**, not in `SharedPreferences`, so they are inside
the same backup.

## What gets built

1. **Schema 45 → 46**, additive: `finance_plan`, `finance_obligation`,
   `finance_person`, `finance_debt_entry`, `finance_debt_payment`,
   `unit_local_override` + indexes on `(due_date, status)`, `(person_id)`,
   `(entry_id)`.
2. **`lib/features/personal/finance/`** — models, pure engine (Jalali month
   arithmetic with short-month clamping, plan generation, 30-day and 6-month
   totals, receivable separation, overdue, mark paid/undo, postpone, debt
   balances, polite-message builder from `assets/data/debt_message_templates.json`),
   repository, reminder planner + scheduler, providers, and the screens/sheets.
3. **«دفتر مالی» in «اطلاعات من»** — one tile, its own routes, same vault lock,
   no hub. Two tabs inside the page: «چک و قسط» and «دَین و طلب».
4. **Calculator «تبدیل واحد» tab** — a segmented control above the existing
   calculator, `assets/data/units.json` as the single source of factors,
   editable local units (defaults shipped `verified:false`), 6 significant
   digits on display, last-5 history and favourites. The calculator's own
   engine, history and styling are untouched.

## Deliberate choices

- **No fiqh**: the debt ledger stores amounts, dates and notes only. No
  interest, no rulings, no religious text.
- **Jalali months**, not 30-day steps: an installments plan on 31 فروردین
  falls on 31 اردیبهشت, then on 31 خرداد — and in a short month it lands on
  that month's last day, never on the 1st of the next one.
- **Local units are user data**: only the five defaults the spec names ship,
  marked «مبنای پیشفرض (قابل ویرایش)». A region the app does not know gets an
  empty «مبنا را وارد کنید» row; nothing is guessed.
- **One new tile**, not two: the ledger is the second tab of «دفتر مالی».

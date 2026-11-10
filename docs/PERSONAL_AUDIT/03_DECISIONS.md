# PERSONAL AUDIT — 03 DECISIONS

Every ambiguous product decision taken autonomously, with alternatives and
the way to change it.

## D-1 Unit converter: local-unit bases ship pre-filled but unverified
- **Decision:** the five documented units (من تبریز=۳kg، سیر=۷۵g،
  مثقال=۴٫۶۰۸g، نخود=۰٫۱۹۲g، خروار=۳۰۰kg) ship as editable defaults flagged
  unverified; the panel shows a persistent warning and a «ویرایش مبنا»
  button on the محلی category.
- **Alternatives:** (a) empty rows everywhere — safer textually but hostile
  to the common case; (b) hard-coded uneditable — violates the brief.
- **Change:** edit the bases in the panel (persisted in SharedPreferences
  `calc_unit_local_bases`, included in backup via preferences export).
  Any unit NOT in the five ships as an empty «مبنا را وارد کنید» row and
  returns null until filled — never guessed.

## D-2 Unit converter: recents cap at 6, stored in prefs
- **Decision:** the last 6 distinct conversion lines persist
  (`calc_unit_recents`) and are tappable to restore; the line currently
  shown in the result card is excluded from the list to avoid duplication.
- **Change:** delete the pref keys to reset.

## D-3 Unit converter: switching category resets from/to to per-category
defaults
- **Decision:** unconditional defaults (زمان → ساعت/دقیقه), pinned by the
  pre-existing unit_panel tests. The nicer «keep if valid» behavior was
  tried and reverted — the tests pin the simpler contract, and carrying a
  length unit into a time conversion is never wanted.
- **Change:** edit `_resetUnits` in calculator_tool_panels.dart and update
  the tests.

## D-4 Tools opened from More have no entry lock
- **Decision:** `VaultGuard` was removed from the kids/teacher/shop routes
  when the user moved them to the More grid. Their sensitive ACTIONS keep
  internal locks (ParentLock for approvals/star adjustments/data wipe, typed
  confirmation for shop reset).
- **Alternatives:** keeping the vault gate on the routes — rejected: a More
  tile that opens «اطلاعات من»'s PIN screen is confusing UX, and the user
  had previously removed the tool-lock section entirely (e878baa).
- **Change:** re-wrap the routes in `app_router.dart` with `VaultGuard`.

## D-5 Religious-data gaps stay empty
- کفاره و فدیه: NO `kaffara_rules.json` exists and none was authored from
  memory. When the tool is built it must ship the empty state
  «این حکم هنوز در برنامه موجود نیست» until reviewed rule data is provided.
- Prayer-window definitions in the kids tool come from the app's own
  schedule provider with the documented fallback boundaries — no fiqh text.

## D-6 Unit-converter file placement
- **Decision:** the converter domain lives in
  `lib/features/tools/calculator/domain/unit_conversion.dart` (it is
  calculator functionality, per the brief «تبدیل واحد tab inside the
  Calculator»), not under personal2 — the audit covers it but the code
  belongs to its feature.

## Items needing YOUR review
1. Local-unit default bases (D-1) — confirm or correct the five numbers.
2. Habit/reward templates, tajweed tags, grade scale (listed in the stage-1
   report) — still `reviewed:false`.
3. Care maintenance intervals in `care_templates.json` — still
   `reviewed:false`.
4. The 8 failing widget-palette tests on 1.8.0 (royal_blue contrast, preset
   count) — they belong to the parallel widgets session's in-flight work.

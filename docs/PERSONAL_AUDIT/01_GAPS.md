# PERSONAL AUDIT — 01 GAPS

Fix order: P0 → P1 → D0 → P2/D1 → P3/D2. IDs are stable and referenced from
CHECKPOINT.md progress entries.

## P0 — data loss / wrong accounting / crash / privacy

- **P0-1 (A)** Care engine orphaned: the v45 tables exist but no screen can
  create a CareAsset, so the reminder scheduler schedules nothing and the
  family is invisible. Not data loss yet — but any future schema change to
  v45 tables ships untested against real usage. → build the خودرو/خانه UI
  (the single largest P1; tracked as P1-A-UI).
- **P0-2 (all)** Backup: care + personal2 tables are included (sqlite_master
  enumeration) and round-trip tests exist for shop/kids — VERIFIED OK, no gap.

## P1 — missing core features

- **P1-A-UI (A)** خودرو + خانه screens: complete family missing. Effort: L.
- **P1-B-MALI (B)** دفتر مالی: entire tool missing. Effort: L.
- **P1-B-DEBT (B)** دفتر دَین: entire tool missing. Effort: L.
- **P1-C-ALL (C)** صله رحم / کفاره و فدیه / قلک / قضایار: four tools missing.
  Effort: XL. Kaffara is DATA-DRIVEN — with no reviewed `kaffara_rules.json`
  the correct ship is the empty state «این حکم هنوز در برنامه موجود نیست».
- **P1-F-REPORTS (F)** shop report drill-downs + custom Jalali range + slow
  movers screen + full ZIP export. Effort: M.
- **P1-D-MONTHLY (D)** kids monthly report variant. Effort: S.

## P2 — secondary features / weak states

- **P2-B-UNITS (B)** unit conversion: add Area + Speed categories, «محلی ★»
  (من/سیر/مثقال/نخود/خروار, unverified+editable), recent + favorite pairs,
  remembered tab. Effort: M. ← chosen as the first build item (self-contained,
  testable, completes tool B's calculator leg).
- **P2-E-REMINDERS (E)** teacher class reminders wiring. Effort: S.
- **P2-D-REMINDERS (D)** kids evening-summary wiring. Effort: S.

## P3 / D — polish

- D1: care templates editor UI (after P1-A-UI).
- D2: calculator unit panel RTL polish during P2-B-UNITS.

## Execution decision (03_DECISIONS.md carries the full reasoning)

The remaining context of this session cannot honestly build P1-A-UI +
P1-B-MALI + P1-B-DEBT + P1-C-ALL to the project's testing standard. Per the
brief's CHECKPOINT rule, this session delivers: complete PHASE 0/1 docs,
PHASE 2 verification, and the first build item **P2-B-UNITS** (completing the
unit converter), then a clean CHECKPOINT so "continue" picks up at P1-B-MALI.

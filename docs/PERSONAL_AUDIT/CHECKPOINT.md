# PERSONAL AUDIT — CHECKPOINT

> **2026-11-05 — this file's queue is superseded.** Stages 1–3 have since
> landed (care screens, finance/debt, the family four, shop, kids, teacher),
> and the live queue is **`docs/PERSONAL_TOOLS_ROADMAP.md`**, which records the
> verified status of every tool and the phased plan. Read that first; the
> sections below are the historical audit record only.

Updated: after the first audit build pass. Current group: **B (partially
done — unit conversion complete; دفتر مالی/دَین not started)**.

## Done this session

1. **PHASE 0** — `00_TRACEABILITY.md`: every REQUIRED-SCOPE item mapped to
   DONE/PARTIAL/MISSING with file-level evidence; three FALSE CLAIMS from
   earlier reports identified (care-engine registration, care templates
   loading, unit-conversion completeness).
2. **PHASE 1** — `01_GAPS.md`: the gap list with severities and the
   execution order (P0 → P1 → D0 → P2/D1 → P3/D2).
3. **PHASE 2 (partial)** — shared foundation verified: ParentLock,
   ReportRenderer, SoftNotifier, TemplateStore, MiniCharts, the money/number
   formatters and the search normalizer all have ONE implementation under
   `personal2/shared` and are consumed by D/E/F. Notification-ID ranges
   documented across SoftNotifier/kids/teacher/shop (14000/15000/16000+),
   no collisions (pinned by tests).
4. **First build item — P2-B-UNITS (unit converter completion)**:
   - `Area` + `Speed` categories added (new tables in
     `tools/calculator/domain/unit_conversion.dart`).
   - **«محلی ★» category**: the five documented units (من تبریز، سیر،
     مثقال، نخود، خروار) ship as editable, unverified bases; unset bases
     return null → the UI shows «مبنا را وارد کنید» (never guesses);
     kg is always available as the bridge.
   - Recent conversions (6, persisted, tappable, deduped against the
     result card) and a remembered category.
   - UnitPanel rebuilt on the shared domain (12 converter tests + the 8
     pre-existing panel tests green).

## RESOLVED (by the parallel sessions on release/1.8.0 and release/1.9.0)

- **P1-A-UI** — the parallel session's `personal/stage3-family-faith` built
  the full car/home care screens and transferred them via a4174bf/4c81639.
- **P1-B-MALI** — their finance feature (finance_engine/repository/scheduler/
  screens) covers installments, cheques and loans.
- **P1-B-DEBT** — their finance feature includes the debt book.
- **P1-C-ALL** — their family-faith feature covers قضایار، کفاره، صله رحم، قلک
  (kaffara is data-driven with the reviewed:false flag).
- The remaining P2/P3 items (report drill-downs, monthly kids report) are
  documented in the gap report for a future session.

## Remains (blocking)

- **The 1.9.0 release build fails on Kotlin widget compile errors** that are
  entirely in the parallel session's widget redesign files
  (PrayerVerticalBudget.kt references private constants from
  PrayerNativeViews.kt; PrayerMarkActivity references
  PrayerWidget.applyMarkAndRender). These files were merged into
  release/1.9.0 from the parallel session's branch and have cross-file
  visibility issues. NOT caused by any personal-tools change.
- **On-device `--profile` pass** — no Android device attached.

## Next session says "continue" → starts at P1-B-MALI with the same testing
standard (pure domain + DAO tests first, then the screens).

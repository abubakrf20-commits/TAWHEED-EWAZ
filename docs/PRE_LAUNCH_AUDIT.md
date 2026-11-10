# PRE-LAUNCH AUDIT — tawheeed (release/1.8.0)

> **عکس تاریخ‌دار — Historical snapshot.** این سند وضعیت را در شاخه و تاریخ خودش ثبت
> می‌کند و خوانده‌شدنش به‌عنوان «وضعیت امروز» درست نیست. مرجع فعلی فقط `AGENTS.md`
> (ریشهٔ مخزن) و `docs/SECTIONS_1_9_0.md` است؛ فهرست کامل در `docs/README.md`.


Generated during the comprehensive 10-pitle (home → more) audit, plus
cross-cutting finalization pass. Branch `release/1.8.0` (HEAD at merge line),
`version 1.8.0+10015`. Status: **ready for release** subject to the
user-side ops listed at the end; **no Android device was attached**, so
every finding below is proven by test / golden / binary, not on-device.

## Cross-cutting pass — 2026-10-15

1. **Home ↔ More one-source (`سنجش`- level):** already unified. `QuickActions`
   derives icon/title/accent from `kMoreItems` via `quickToMoreIds`; `MoreDuotone`
   is the single recipe used by More, About, chat-style rows. No active double
   source found. Left-over X: dues/hadith-specific font scaling is
   reader-scoped (`quranFontSize`, `showEnglishTranslation`) and intentionally
   lives under «فونت و نمایش» — not duplicated.
2. **Home card «طاعات روزانه» ↔ checklist:** dialogs already shared through
   `waship_item_dialogs.dart`; coefficients (`_WorshipPointsSection`) feed the
   shared provider. No further plumbing found (no sink: both read the same
   persisted keys).
3. **Performance:** three heavy surfaces exist (PDF reports for zakat/inheritance/hifz/ketabkhaneh,
   launched lazily), main lists are paginated via `loadMore` already. No new
   allocation without bounds was found. Protected(surface) — not touched.
4. **Final docs:** this file. `assets/changelog.md` stays empty by owner's
   explicit decision («فقط چیزی که خودم وارد میکنم»).
5. **Storage rules / privacy / account hybrid** — all tested by gsandboxed
   suites; no code changes needed.
6. **Quality and consistency gates (post cross-cutting):**
   * `python tools/quality_check.py --strict`: 7/7 zero.
   * `python tools/design_consistency.py`: OK (raw_color 262 ≤ budget,
     raw_size 0).
   * `flutter test --exclude-tags network`: **3887 passed, 0 failed.**
   * `flutter analyze lib test`: 0 errors / 0 warnings.
   * encoding guard green; no BOM or U+FFFD.

## Daste-by-daste summary

| دسته | status | main outcome |
|---|---|---|
| D1 Home | ✅ | `home/final-v3` 9-bug fix, kit row, ACL ring, quick access single-source |
| D2 Quran/mushaf | ✅ | Q1 dead QF audio, Q2 shared player, Q-glitch review, chrome row + rotate |
| D3 Prayer+adhan | ✅ | N1 offline map, N2 eight-sections harness; per-country auto default |
| D4 Adhkar/hadith/library | ✅ | Z1–Z4 (tasbih title, ratchet, favorites, hues) |
| D5 Tools & calendar | ✅ | اب۱ moon calendar caption |
| D6 Reminders & notifications | ✅ | ی۱ reserved-id comment map fixed |
| D7 Settings & cloud & account | ✅ | No actionable code defect; tests green |

## Known deferred items (by design, not defects)
- No Android device attached → on-device passes pending.
- Sentry stays OFF (no DSN in repo); privacy page names optional crash
  reporting — consistent with wiring but only active if DSN provided at build.
- Public privacy/terms URL + firestore.rules deploy + app-check =
  user ops (see `SECURITY_PRIVACY.md`).
- `shipping 1.8.0` account Google linking needs on-device pass.
- Release notes asset (`assets/changelog.md`) intentionally empty.

## Release verdict
Launch-ready at the code level. Install the latest APK set
(`1.8.0-d2888a6`) or rebuild from current HEAD following the doc in
`AGENTS.md` (clean detached worktree, four gitignored files copied in, no
dart-defines).
# MERGE_1_8_0_REPORT.md — collecting parallel work into release/1.8.0

> **عکس تاریخ‌دار — Historical snapshot.** این سند وضعیت را در شاخه و تاریخ خودش ثبت
> می‌کند و خوانده‌شدنش به‌عنوان «وضعیت امروز» درست نیست. مرجع فعلی فقط `AGENTS.md`
> (ریشهٔ مخزن) و `docs/SECTIONS_1_9_0.md` است؛ فهرست کامل در `docs/README.md`.


Line: `merge/release-1.8.0-all` → fast-forwarded `release/1.8.0`.
Base: release/1.7.2 @ 12517a8 + `1.8.0+10015` bump. Build from here.

## Merged (in order)

1. `fix/announcements-publish` — kept HEAD (Spark no-push design + admin
   edit); the branch's push-queue contradicts it. Decision recorded in the
   merge commit; push notifications need a separate approved design.
2. `fix/quran-mushaf-paging` — no-op (fix absorbed by later rework; kept
   custom-painted header, gesture-wins guards, forgiving physics).
3. `polish/announcements-rows` — substance already in HEAD; kept HEAD
   (branch push-snackbar would misfire on the no-push design).
4. `polish/suggestions-rows` — kept HEAD screen + branch long-text test.
5. `rescue/friday-clean` — Friday feature kept (card, Kahf id **406**,
   Jumu'ah time end to end). Dropped: dead extended-day loop, duplicate
   Kahf copies/cards, PNG-banner revert, stale UA/prompt simplifications.
   Open: hero countdown never got the Friday label (lost earlier).
6. `remove/recitation-companion` — user verdict enforced: prompter/lab
   stay deleted (12,883 lines), sherpa gone, version kept 1.8.0+10015.
7. `fix/document-photos-test` — no-op (only stale prompter fixes).
8. `more/redesign` — six-section page taken wholesale (prompter-free).
9. `home/polish-v2-ui` — approved mockup polish wins over Wave-3 kit
   home cards. Kept from release: Friday GPS guard, labels, kit
   ArcCountdown + more_screen timeline adapted to iqamahTime API.
10. `topic_hues_test` fix (SectionColors.prompter gone).
11. Suggestions test restored to release-tip (stale branch version).

## Deliberately NOT transferred

- `wip/shared-tree-collection` — the collected tree WIP reverts three
  committed audit fixes (dorar UA retry, prompter/lab `num?` copyWith,
  recitation wash + goldens, PreparingGate overflow). Only safe hunks
  considered; none taken (azkar haptics needs its owner's test).
- `freebuff/task-7cf24759` — C1-C7 duplicates merged polish; 3aab056
  re-integrates deleted-feature fixes; tip commits contradict the spec
  (iqamah line). Nothing taken from the branch itself — note that its
  `acbd00e` arc anchoring is the same change as `quran/redesign`'s `f0e3384`,
  which came in on the **third pass**, so that behaviour is in 1.8.0.
- `home/polish-v2` — tilawa stack lives in deleted space; home parts
  superseded. KEPT (AGENTS.md orders so).
- `integration/friday-on-2a12863` (duplicate), `release/1.7.1`,
  `phase1/redesign` (empty), `rescue/friday-work`, `wip/pre-audit-merge`
  (safety backups — kept).

## Verification

- `flutter analyze`: 0 errors (2 pre-existing mock_daos warnings).
- Full suite (excl. network): green except untracked foreign scratch
  `mushaf_palette_render_audit_test.dart` (not in git — owner's file).
- Release APK: built from release/1.8.0 (see below).

## Second pass — the rest of release/1.7.2 (2026-10-10)

The first pass based 1.8.0 on `release/1.7.2 @ 12517a8`, but that branch kept moving
and finished at `ef2ddb3`. Re-inventoried every branch with `rev-list` + patch-id
`git cherry` + content greps (patch-id alone mis-reports drifted files), then
cherry-picked the **11 commits still unique to `release/1.7.2`** — all applied clean,
no conflicts. They landed on `release/1.8.0` as `c1635ef`..`7ca44cc` (a concurrent
session applied the same set; the two trees were diffed and are content-identical, so
this pass adds only the go-forward docs):

| picked | what |
| --- | --- |
| `69b41e4` | WebView navigation confined to the opened origin (+ test) |
| `359b8ef` | `]!` lookup dropped from the digit-folding mapper |
| `bc18c5e` | armed native reminders listed on the phone-settings page |
| `0ccfb84` + `08a52b0` | consolidated mushaf text integrity guard |
| `9694cb1` | the six Phase-2 audit docs |
| `8b1525f` | M-1 — machine-specific `java.home` out of tracked gradle.properties |
| `7f4eca6` | G-1 — prayer location secure-storage only, legacy plaintext purged |
| `a651497` | password reset + in-app account deletion |
| `ec4f505` | privacy policy rewrite, terms of service, contact path |
| `cbb6848` | Sentry DSN release wiring (`docs/ERROR_TRACKING.md`, `tool/build_release.ps1`) |

Already contained, so not picked: `850efa0` (inheritance money guard + audio-library
download failures — came in with `home/polish-v2-ui`) and `ef2ddb3` (jalali fold — same
merge). Verified by grep, not by patch-id.

Branch audit after the picks: `phase1/redesign`, `home/polish-v2` (home C1–C7 came via
`home/polish-v2-ui`; tilawa is deleted space), `freebuff/task-5dec…` (`b8622f6`
document photos, `c133eee` v42 pin, `080cc52` tasbih sound all present),
`freebuff/d1632d5` quran unification (present) and `freebuff/https-prompter…`
(ancestor) are fully collected. `release/1.7.2` is now **frozen** — 0 unique commits.
`rescue/friday-work` / `wip/pre-audit-merge` stay as safety snapshots of *uncommitted*
work; `freebuff/task-7cf…` tips stay rejected (arc anchoring / iqamah line contradict
the merged home spec).

## Release APK from the completed 1.8.0 tip

Built from a clean detached worktree at `10fc74a` (`%TEMP%/opencode/rel-build-180`) with
the four gitignored files copied in (`android/key.properties`,
`android/app/release-key.jks`, `android/app/google-services.json`,
`assets/env/quran_api.env`) — so the binary carries no uncommitted WIP.
Gradle 173 s, `√ Built app-release.apk (45.9 MB)`, exit 0.

| file | bytes | sha1 |
| --- | --- | --- |
| `app-release.apk` (fat) | 48,086,195 (45.9 MB) | `fea6c1ec…` |
| `app-arm64-v8a-release.apk` | 31,815,578 | `7c97d845…` |
| `app-armeabi-v7a-release.apk` | 32,095,758 | `6f840fe9…` |

`version: 1.8.0+10015`. Durable copies: `Desktop/tawheeed-release-apks/1.8.0-10fc74a/`,
and the three APKs replace the stale `release/1.7.2` ones in the main tree's
`build/app/outputs/flutter-apk/`.

**Sentry is OFF in this build:** no `SENTRY_DSN` exists anywhere in the repo or the
gitignored env files, and `flutter build apk --release` passes none, so error reporting
silently disables itself. To ship with it, run
`pwsh -File tool/build_release.ps1` with `$env:SENTRY_DSN` set (see
`docs/ERROR_TRACKING.md`) — the user's, not the agent's, to create.

Verification of the transferred tree at this tip: `flutter analyze lib test` = 0 errors
(2 pre-existing `mock_daos.dart` override warnings), `flutter test --exclude-tags
network` = 3243 passed / 9 skipped / 0 failed, `quality_check.py --strict` = all 7 gates
0.

## Post-transfer defect: double-encoded notification text (fixed in `ba895ec`)

The first 1.8.0 APK (`1.8.0-10fc74a`) shipped reminders whose channel names,
titles and bodies arrived as meaningless letters («غŒط§ط¯ط¢ظˆط±ظ‡ط§» instead of
«یادآورها»). Root cause is not a font or a locale problem: the merge of
`rescue/friday-clean` wrote those files twice — UTF-8 Arabic/Persian bytes were
decoded as Windows **CP1256** and re-saved as UTF-8. Every string in the
affected files went through that transform, so the fix had to undo the bytes,
never retype them (religious text must stay byte-exact).

| file | lines repaired |
| --- | --- |
| `lib/shared/services/notification_service.dart` | 171 |
| `lib/features/prayer/presentation/screens/prayer_settings_screen.dart` | 99 |
| `lib/shared/services/notification_ids.dart` | 16 |
| `test/features/audio_library/audio_library_repository_test.dart` | 3 |

How the repair was proven faithful:
- repaired `notification_ids.dart` is **byte-identical** to its clean ancestor `ebc95da`;
- repaired `notification_service.dart` differs from clean `4fc94eb` by 11 lines, all of
  them legitimate merge code — and its 72 Persian/Arabic string literals are the
  **identical set** as the ancestor (nothing added, dropped or reworded);
- the Friday feature (`_FridayPrayerTimeCard`, `وقت نماز جمعه`, `setFridayPrayerTime`)
  survived untouched, so no merge work was lost;
- the audio-library test file was already corrupted at its own ancestor `5689ac1`, i.e.
  that one predates this merge.

New guard: `test/core/utils/text_encoding_guard_test.dart` rejects an Arabic letter
glued to a CP1256 residue character across `lib`, `test`, `assets` and `android`
(2,156 hits on the corrupted tree, 0 on the repaired one), and asserts the six strings
the user reported are Persian. The adjacency rule was chosen over a plain round-trip
because real Persian also fails the round trip — it would have "repaired" correct text
like `// بژ` and `'شک'`.

Full-tree rescan on `ba895ec`: one genuine leftover, `lib/features/quran/mushaf/qcf4/`
`qcf4_data_store.dart:131` (`// Corrupt cache â€” remove …`) — a comment inside the
protected mushaf bundle, reported rather than edited. **Closed in the third pass**
(`4a9f317`): comment-only, no behaviour change, and the tree is now at 0 guard hits.

### Release APK from the fixed tip (`ba895ec`)

Built in a clean detached worktree (`%TEMP%/opencode/rel-build-ba895ec`) with the four
gitignored files copied in, same flags as the previous 1.8.0 build (no dart-defines, so
Sentry stays OFF — no DSN exists). Gradle 461 s, `√ Built app-release.apk (45.9MB)`, exit 0.

| file | bytes | sha1 |
| --- | --- | --- |
| `app-release.apk` (fat) | 48,079,317 (45.9 MB) | `a841cdd6192a457edcae42ee63e39d9e0c2c88c7` |
| `app-arm64-v8a-release.apk` | 31,812,569 | `553075c35d0a2ba5bf6b7fb0d47ec8a5f8141d39` |
| `app-armeabi-v7a-release.apk` | 32,091,881 | `9aca9697f8ed68e8c3f39ac51f890944a1d00be9` |

`version: 1.8.0+10015` (unchanged — `pubspec.yaml` is protected). Durable copies:
`Desktop/tawheeed-release-apks/1.8.0-ba895ec/`. Deliberately **not** copied into the main
tree's `build/` because a concurrent session is building there.

End-to-end binary proof (scanned every `lib*.so` in both APKs): the garbled forms are
PRESENT and `الصَّلَاةُ خَيْرٌ مِّنَ النَّوْمِ` is MISSING in `1.8.0-10fc74a`; in
`1.8.0-ba895ec` all six repaired strings are FOUND and all four garbled forms ABSENT.

Verification at this tip: `flutter test --exclude-tags network` = 3245 passed /
9 skipped / 0 failed, `flutter analyze lib test` = 0 errors (2 pre-existing
`mock_daos.dart` override warnings), `quality_check.py --strict` = all 7 gates 0.

## Third pass — `quran/redesign` transferred, and the same bug's second wave (2026-10-10)

`quran/redesign` forked at `7ca44cc`, i.e. **before** `ba895ec`, so it still carried
mojibake files; merging it as-is would have re-shipped the gibberish on the home and
checklist screens. Merged with `git merge` as `0b62950` (parents `7d6cad7` + `b7cd904`)
after a `merge-tree` dry run, so its 5 commits are all ancestors of the new tip:

| commit | what it carries |
| --- | --- |
| `52dcbb9` | screen inventory + the quran redesign plan (docs) |
| `f0e3384` | **hero arc re-anchored on fajr** — the sweep runs most-recent-fajr → next fajr in six equal segments, fajr is dot 0; `prayer_clock.dart` phase logic follows. Same change as `freebuff`'s `acbd00e`, now in the line. |
| `1451b54` | one shared `NumberFormat.fraction()` — `«N از T»` wrapped in a U+2066…U+2069 LTR isolate, so two counters can never swap sides inside a Persian string |
| `4e59e41` | quran-download counters routed through it (the reversed counters on the offline sheet) |
| `b7cd904` | home + checklist counters routed through it |

### The 123 lines it brought in — repaired in `4a9f317`

Same defect class, same inverse byte transform (`line.encode('cp1256').decode('utf-8')`),
applied line by line and only where the recovered text contains Arabic letters or carries
the `â` / `آ«` / `آ»` residue — never by retyping:

| file | lines | examples restored |
| --- | --- | --- |
| `lib/features/checklist/presentation/screens/worship_checklist_screen.dart` | 45 | «طاعات روزانه», «افزودن الگوی چک‌لیست», «راهنمای طهارت», the four template packs and their items |
| `lib/features/home/presentation/widgets/daily_adhkar_box.dart` | 43 | «فضائل فجر», «اذکار صبح», «تایم‌لاین اعمال», «پیشرفت اذکار», `$h:$m دیگر` |
| `lib/features/home/presentation/screens/home_tab.dart` | 26 | «خانه», «رواتب (سنن مؤکده)», «راتبه فجر · 2 رکعت قبل», «تا $h:$m» |
| `lib/features/home/presentation/widgets/daily_stats.dart` | 8 | «خلاصه امروز», «$streak روز پیاپی», «$done از $total … درصد» |
| `lib/features/quran/mushaf/qcf4/qcf4_data_store.dart` | 1 | the last reported leftover — a **comment** line, no behaviour change |

Faithfulness: every Persian/Arabic literal present in the clean ancestor `7ca44cc` is
still present after the repair, diffed per file — **0 strings lost**. The whole-tree
adjacency scan now reports 4 hits, all of them documentation *quoting* the gibberish as
evidence (`AGENTS.md`, `CHANGELOG.md`, this report, the guard test's own docstring).

### Work the transferred commits left unfinished — completed in `caaf00f`

- `f0e3384`'s message says «the countdown label no longer carries the redundant
  (ساعت:دقیقه) hint», but the code still built `'تا … (دقیقه:ثانیه)'` while the branch's
  own `hero_card_test.dart` asserted «تا اذان فجر» — **the branch tip was red**. The
  parenthetical is gone; `showSeconds` still chooses the second/minute subscription, and
  the doc comment now says the number above carries the unit.
- `daily_stats_test.dart` and `rawatib_section_test.dart` still asserted bare `'2/5'` /
  `'0/7'`, which the isolate makes unfindable; both now assert
  `NumberFormat.fraction(n, m)` — the same contract the production widget uses.
- 12 expectations in `fraction_format_test.dart` hardcoded the invisible marks; they go
  through `NumberFormat.ltrIsolated(...)` instead, and the two production/test raw marks
  became `\u2066`/`\u2069` escapes. That clears all 14
  `text_direction_code_point_in_literal` warnings.

### Release APK from the integrated tip (`caaf00f`)

Built in a clean detached worktree (`%TEMP%/opencode/rel-build-caaf00f`) with the four
gitignored files copied in (`key.properties`, `android/app/release-key.jks`,
`google-services.json`, `assets/env/quran_api.env`), no dart-defines so Sentry stays OFF.
Gradle 155.0 s, `√ Built app-release.apk (45.9MB)`, exit 0.

| file | bytes | sha1 |
| --- | --- | --- |
| `app-release.apk` (fat) | 48,080,233 (45.9 MB) | `2d55ba9d017830cea241c850e3774b3c3b69873c` |
| `app-arm64-v8a-release.apk` | 31,812,941 | `94b48fda473527bf7dc12b442feb50113b6f3663` |
| `app-armeabi-v7a-release.apk` | 32,092,420 | `fbb56dedf1941f45cd05acb367b269536d624cce` |

`version: 1.8.0+10015` (unchanged — `pubspec.yaml` is protected). Durable copies +
`.sha1`: `Desktop/tawheeed-release-apks/1.8.0-caaf00f/`. Not copied into the main tree's
`build/`, where the concurrent session works.

Binary proof (`lib*.so` of the arm64 APKs, scanned with the same script against
`1.8.0-10fc74a`): at `caaf00f` all ten strings are **FOUND** — یادآورها، اذان فجر،
الصَّلَاةُ خَيْرٌ مِّنَ النَّوْمِ، خانه، خلاصه امروز، فضائل فجر، اذکار صبح، افزودن
الگوی چک‌لیست، طاعات روزانه، رواتب (سنن مؤکده) — and all five garbled forms **ABSENT**;
the pre-repair `1.8.0-10fc74a` build still carried «اذکار صبح» in its mojibake form and
was missing the Arabic sleep-versus-duha string entirely.

Verification at `caaf00f`: `flutter test --exclude-tags network` = **3252 passed /
9 skipped / 0 failed** (7 more than at `ba895ec` — the transferred formatter and hero
tests), `flutter analyze lib test` = **0 errors / 0 warnings** (97 pre-existing info
lints in untouched files), `quality_check.py --strict` = all 7 gates **0**.

### Where the tip lives

`release/1.8.0` has been fast-forwarded from `7d6cad7` onto this integrated line, so the
go-forward branch carries the transfer, the encoding repair and the finished formatter
work. Moving the branch needed one careful step: `test/features/home/presentation/widgets/`
`hero_card_test.dart` was modified but uncommitted by the concurrent session (a single
trailing blank line), and a fast-forward would have overwritten it. Its diff was saved to
`%TEMP%/opencode/parallel_herotest.patch`, the file restored to HEAD, `git merge --ff-only`
run, then the patch re-applied — their working-tree change is back byte for byte, and the
integration commits sit underneath it.

`integrate/quran-redesign` (and `fix/notification-text`) mirror the same tip as safety
refs; the release APK was built at `caaf00f`, one docs commit below it.


# Phase 5 — Phased fix plan (all findings, one table)

Severity scale per the audit prompt (P0 data-loss/crash/security-breach …
P3 polish). `D` tags are design debt, kept separate and **not fixed** under
the no-redesign rule.

| ID | Area | Type | Sev | File:line / evidence | Impact | Fix | Effort | Risk | Test | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| F-T2a | Hadith | UI bug | P1 | `hadith_books_screen.dart:626,987,1079,1157` — 4 transparent inner screens via `Navigator.push` outside `_ambient` | Black pages under any theme | Self-wrap each in `AmbientBackground` (quran-share precedent) | S | Low | Structural guard + suite | **Fixed Phase 6** |
| F-T2b | Duas share | UI bug | P1 | `dua_share_screen.dart:167` same class | Black share page | Same self-wrap | S | Low | Same | **Fixed Phase 6** |
| F-T2c | Adhkar share | UI bug | P1 | `adhkar_share_screen.dart:142` same class | Black share page | Same self-wrap | S | Low | Same | **Fixed Phase 6** |
| F-T2d | Dua-from-Quran share | UI bug | P1 | `dua_from_quran_share_screen.dart:138` same class | Black share page | Same self-wrap | S | Low | Same | **Fixed Phase 6** |
| F-T2e | Ketabkhaneh stats | UI bug | P1 | `reading_stats_screen.dart:22` same class | Black stats page | Same self-wrap | S | Low | Same | **Fixed Phase 6** |
| F-T1 | Qibla | Perf | P3 | `qibla_screen.dart:1620` static `Opacity(` (saveLayer at 1.0 too) | Tiny overdraw on small rows | Wrap only when faded | S | None (visual-identical) | Suite | **Fixed Phase 6** |
| F-L1 | Quran reader logs | Log volume | P2 | `quran_mushaf_view.dart:737,904,912` (fixed Phase 1) | Release file churn per page turn | info→debug | S | None | 45/45 | Done |
| F-L2 | Push logs | Privacy | P2 | `firebase_push_service.dart:54` (fixed Phase 1) | Token fragment in shareable log | info→debug | S | None | Analyze | Done |
| F-L3 | ~100× `operation failed` w/o `$e` | Log quality | P3 | ~40 files (audio 15, pomodoro 11, …) | Undiagnosable failure lines | Per-file enrichment w/ error + op name | M | Low but wide; protected files inside | None today | **Deferred batch** (needs per-site care + protected-file approval) |
| F-A1 | God files 1.4–2.6k lines | Arch | P2 | 8 files listed in `03_ARCHITECTURE_AUDIT.md` | Maintainability | Split | L | High (adjacent to recent/protected work) | Suite + goldens | **Roadmap** (do not split unapproved) |
| F-S1 | No `--obfuscate --split-debug-info` | Security/release | P2 | local + CI release builds | Store builds ship unobfuscated, no symbols | Enable + archive symbols + re-test native paths | S | Medium (verify reschedule/alarm stack readability) | Release build + install | **Package F, needs a release build** |
| F-D1 | ~40 legacy `blurRadius > 8` shadows | Design debt | P3/D2 | listed in `02_TABS_AUDIT.md` | GPU overdraw on weak phones; but *visual* | Shared shadow-token pass | M | **Visual change — user approval required** | Goldens re-pin | **Deferred** (approval-gated) |
| F-P1 | Single-round SHA-256 PIN hash | Security | P3 | `pin_lock_service.dart:186` | Device-local UI gate only; Keystore-backed | PBKDF2/Argon2 or platform-bound key | S | Medium (migration of verifiers) | PIN tests | **Roadmap** |
| F-V1..n | Device-only verifications | Perf/a11y/infra | P1–P2 | frame times, memory, battery, Doze/reboot, TalkBack, backup round-trip, OEM | Cannot claim release-ready without them | Device pass (Samsung A13-class + 2nd OEM) | M | — | Manual + adb plan | **Open, needs a phone** |

## Work packages
- **A (logs):** F-L1, F-L2 done; F-L3 deferred batch (defined, not built).
- **B (battery/perf):** F-T1 done. No measurable battery finding without a
  device — static patterns (timers disposed, sensors lifecycled, no polling
  alarms, `updatePeriodMillis=0` widgets) all clean.
- **C (UI, non-design):** F-T2a–F-T2e done (bug restoration, precedent-backed,
  pixel-neutral where an ambient already existed — inner pages had *none*).
  F-D1 explicitly excluded (visual).
- **D (arch):** nothing safe to fix (F-A1 roadmapped).
- **E (infra):** nothing broken found; verifications device-bound.
- **F (security/release):** F-S1 defined, needs a release build to verify —
  not executed in this pass (no local release build run; CI builds on `main`
  only).

## Deferred to roadmap (large / judgment-needed)
F-L3 batch · F-A1 splits · F-D1 shadow pass (visual approval) · F-P1 KDF ·
in-app update without Play · Data Safety/Bazaar-Myket packaging text ·
full license-screen cross-check · dependency advisory scan · TalkBack pass ·
device performance/reliability battery.

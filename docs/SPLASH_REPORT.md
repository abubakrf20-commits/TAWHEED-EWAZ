# Splash redesign — `splash/new-design`

> **عکس تاریخ‌دار — Historical snapshot.** این سند وضعیت را در شاخه و تاریخ خودش ثبت
> می‌کند و خوانده‌شدنش به‌عنوان «وضعیت امروز» درست نیست. مرجع فعلی فقط `AGENTS.md`
> (ریشهٔ مخزن) و `docs/SECTIONS_1_9_0.md` است؛ فهرست کامل در `docs/README.md`.


Branch tip `a608008` was the last code commit; `d982679` and this pass are docs.
Cut from `release/1.8.0` @ `c578e33`. Six commits carry the work:

| commit | what it carries |
| --- | --- |
| `31aa7a2` | the native field: `LaunchTheme`, `values-v31` `Theme.SplashScreen`, the coin at its real size, `MainActivity` exit fade |
| `676c6bb` | the launch re-timed: `runApp` before the init chain, deferred work after the first frame |
| `ce9cc06` | the Flutter field: painter, tokens, `SplashOrchestrator`, the router hand-off, 34 unit + widget tests |
| `2d0b04e` | eight golden baselines + the RTL harness fix |
| `5229ce4` | **after the first look on a device:** the system window carries no mark at all — the coin belongs to the Flutter frame alone |
| `400fb1e` · `a608008` | the coin 60 % larger and one centimetre above centre, and the eight baselines re-recorded for it |

## 1. What the launch looks like now

Three stages, one continuous picture:

1. **Native window** (before Dart exists). `LaunchTheme.windowBackground` is
   `res/drawable/launch_background.xml`, which is now the **field and nothing
   else**: a three-stop linear ramp `#24150E → #5F3E1E → #A8741F`. XML
   gradients take only three stops, and `5F3E1E` is the exact midpoint of the
   four-stop Flutter ramp, so stage 1 and stage 2 agree everywhere, not just at
   the centre line.
   On API 31+ the system splash window is mandatory and cannot be cancelled, so
   the app decides only what it contains — and the answer is nothing.
   `windowSplashScreenBackground` is the same `@drawable/launch_background`
   ramp, and `windowSplashScreenAnimatedIcon` is `@drawable/splash_icon_none`,
   a 1dp transparent shape. A transparent **drawable**, not `@null`: with no
   resource set the framework falls back to the launcher icon, which is the
   square mark this replaced. No icon background, no branding image, and
   **nothing to put a mark back on** — an icon there is a second logo at a size
   and a mask the OS chooses, before the app's own composition.
   `MainActivity.fadeOutSystemSplash()` still installs a 200ms alpha exit
   listener before `super.onCreate`, using the platform API only — no
   `core-splashscreen` dependency. Two API-surface facts that cost a build
   cycle: the accessor is `Activity.getSplashScreen()` (`Window.getSplashScreen()`
   is `@hide` and is absent from the platform stub jar), and
   `android.window.SplashScreenView` *is* the view to animate (a `FrameLayout`),
   so the fade is `splashView.animate().alpha(0f)` ending in `splashView.remove()`.
2. **First Flutter frame** — `SplashScreen` paints the same field and is the
   only thing that draws the coin, a centimetre over centre. It adds what the
   native layer cannot: thirteen fixed stars, the crescent at the top-end
   corner, the gold tagline, and the four decorative tiles.
3. **Hand-off** — the destination route fades in over the still-painted field
   in 250ms, or instantly under `lite` mode / reduce-motion.

**The logo is untouched.** `SplashAssets.logo` is one shared
`AssetImage('assets/icon_foreground.png')` — the app's own coin — drawn by a
plain `Image` with no `DecoratedBox`, no clip, no shadow, no ring, no glow, no
scale animation, no container. `test/features/splash/presentation/`
`splash_screen_test.dart` proves it by walking the coin's ancestor chain and
rejecting every box-like type up to the `CustomPaint` that draws the field.

### Design tokens (`lib/features/splash/presentation/splash_style.dart`)

| spec | token | value |
| --- | --- | --- |
| field 0 / 34 / 70 / 100 % | `SplashField.gradient` | `24150E · 4A3024 · 7A5016 · A8741F` |
| coin | `SplashSizes.logoSize(w)` | `clamp(0.784·w, 224, 320)` — 282dp on a 360dp phone, 320dp from ~410dp up; 60 % larger than the first cut of this design |
| coin position | `SplashSizes.logoLift` | centred horizontally, 63dp **above** the screen centre = 1 cm at 160dp/inch; floored at `logoTopFloor` 16dp from the top edge |
| tagline | `SplashSizes.taglineSize` | 14.5sp `FFEFB8`, 24dp under the coin's top edge + its box, scale capped at 1.3 |
| tiles | `SplashSizes.tile/radius/glyph` | 58×58, r19, fill `24150E`@50 %, 1dp `FFE296`@45 %, glyph 28dp `FFE9A8`, label 11.5sp `2A1A12` |
| crescent | `SplashSizes.moonDiameter` | 36dp `FFEFB8`, `Path.combine(difference)`, 26dp from the edge, 36dp + status inset from the top |
| stars | `_stars` | 13 fixed fractional positions in the upper 60 %, 1.0–1.4dp, every 4th `FFF0B8` @100 %, the rest white @65 % |
| timings | `SplashTiming` | floor 400ms · dots at 2s · hang guard 12s · cross-fade 250ms |

All of it is theme-independent on purpose: the splash never reads
`AppTheme.applyTheme`, the time-of-day phase, or dark mode. The two sizes off
the shared type scale (14.5, 11.5) are named constants, which is what
`type_scale_guard_test.dart` allows — the composition is fixed, so it cannot
ride a theme scale that this screen deliberately ignores.

## 2. Startup path, before and after

The critical change is *ordering*, not amount of work.

**Before** (`release/1.8.0` @ `c578e33`, `main()`):

```
install error handlers
await _bootstrapOnce()            ← Firebase · notifications · Quran corpus · dorar
  └ then runApp                   ← nothing on screen until all four land
      └ SplashScreen (650ms floor, 300ms for deep links)
```

**After**:

```
install error handlers
_bootstrapOnce():
  build AppBootstrap(phases: the same four)
  runApp(...)                     ← the field is on screen
  addPostFrameCallback:
    mark 'first-frame'
    bootstrap.start()             ← the same four, in parallel, now
    _startDeferredWork()          ← FCM end-of-frame, BackgroundScheduler, Sentry+PackageInfo
SplashScreen gate = max(400ms, init) → shell | onboarding
```

- The four phases are **the same list** the old `main()` awaited
  (`_startupPhases()` in `lib/main.dart`), and the doc comment there says why
  dropping one would let Home build over a half-loaded app (a first-build
  provider then caches the empty Quran corpus).
- `AppBootstrap` (`lib/app/state/app_bootstrap.dart`) is one `Future.wait`
  over `runStartupPhase`-guarded bodies: it never throws, and anything that
  escapes its own guard is logged as `AppBootstrap`.
- Deferred to after the first frame: the FCM token/subscription block, the
  `BackgroundScheduler` warm-up, and Sentry (which needs `PackageInfo`).
  `BootCoordinator`'s own 800ms post-frame permission delay is unchanged.
- The old 300ms deep-link shortcut is **gone**: the floor is now an
  unconditional 400ms, which is *slower* for a notification tap than before
  and faster for everything else. Deep-link **routing** is untouched —
  `MainActivity` still stashes `notification_payload` / `widget_shortcut` and
  `BootCoordinator` still consumes them after Home appears.

## 3. Metrics — not measured, and how to measure them

**No Android device is attached to this machine** (`adb devices` is empty), so
the `am start -W` baseline and after-numbers this task calls for do not exist
yet. Nothing in this report is a measured startup time; the visual proof is
golden + widget-test only, which is not a substitute for a device pass.

To fill the table below, install the old and new APKs and run, with the app
force-stopped between attempts:

```bash
adb shell am force-stop com.islamic.tawheeed
adb shell am start -W -n com.islamic.tawheeed/.MainActivity   # TotalTime / WaitTime
adb logcat -s flutter tawheeed:* | grep Startup               # the marks below
```

`_startupMark` writes `Startup <label>: <elapsed>ms` for `runApp`,
`first-frame`, `firebase-init`, `notifications-init`, `quran-data`,
`dorar-init`, `package-info`, `sentry-init`, and `SplashOrchestrator` writes
`gate released after Nms (init: ok|degraded)`. The two numbers that matter are
`first-frame` (what the user sees) and the gate line (what they wait for).

| metric | before (`c578e33`) | after (this branch) |
| --- | --- | --- |
| `am start -W` TotalTime | not measured | not measured |
| time to first frame | not measured — bounded below by all four init phases | not measured — bounded only by engine start |
| time to interactive Home | not measured | not measured |
| device matrix (A13 / A32 / API 24–26 / API 31+ / tablet) | not run | not run |

What *is* provable statically: after the change `runApp` no longer sits behind
four awaited phases, and the splash cannot outlive a wedged init by more than
the 12s hang guard, which the orchestrator tests cover with real timers.

## 4. Behaviour the tests pin

`test/features/splash/domain/splash_orchestrator_test.dart` — 15 tests, real
timers: the floor, the slower half wins, the two waits run in parallel not in
series, a throwing init still reaches Home, a wedged init is cut by the hang
guard, a wedged or throwing onboarding read still leaves, `false → onboarding`
while `null/true → shell`, a degraded init never overrides a real `false`, and
the dots fire exactly once and only past 2s.

`test/features/splash/presentation/splash_screen_test.dart` — 19 tests: the
branding and the four tiles, the coin is a plain `Image` of the shared
provider with no box-like ancestor, the coin is centred horizontally and
63dp (= 1 cm) above the screen centre with its top edge at
`(h − size)/2 − lift`, `logoSize` clamps at 224/320, the lift is pinned to
`160 / 2.54` so nobody re-derives a centimetre differently, one semantics label
for the whole frame and the tile labels absent from it, a short screen hides the
tiles and still shows the whole coin, the font scale is capped at 1.3 inside the
screen only, the dots appear only after 2s, the floor holds at 300ms and
releases by 500ms, a deep-link cold start still routes
Home, fresh install → onboarding, the stashed flag beats a stale settings row,
a missing flag falls back and is written back, and the hand-off duration is
250ms by default / `Duration.zero` in lite mode and under reduce-motion. The
harness carries the shipped locale wiring (`fa` + the three global delegates)
because a bare `MaterialApp` resolves `fa` back to `en` and mirrors the field.

`splash_prefs_hang_test.dart` (Phase-1 regression, kept) still passes: a hung
prefs channel must never wedge the splash.

`test/features/splash/presentation/splash_golden_test.dart` — 8 baselines at
320/360/412 × scale 1.0/1.3, the dots at a fixed half-cycle phase, and the
short screen. Like the More/Home/Calendar sets these render **tofu glyphs** —
no app font is loaded in the test binding — so they guard palette, geometry
and the coin's pixels, not Persian shaping.

Suite at this tip (`a608008` + docs): `flutter test --no-pub
--exclude-tags network` → **3479 passed / 9 skipped / 6 failed**, and none of
the six is from the splash. One is `type_scale_guard_test`, whose only
offender is the `tasbih_counter_widget.dart:1276` (`fontSize: 9.5`) literal
AGENTS.md already records. Five are `home_golden_test` (four full-page + the
reminders card) — the same unfrozen-`minute` harness drift AGENTS.md records:
that harness pins `ClockTicker.second` but not `minute`, so `HeroCard` prints
real wall-clock time and can only match the baseline it was recorded in. (The
hero golden is part of that set too and fails on a run whose minute disagrees
with its baseline — the previous landing measured seven reds for exactly this
reason.) `flutter analyze lib test` → 0 errors / 0 warnings (88 pre-existing
info lints, none in a splash file); `quality_check.py --strict` → 7/7 zero.

## 5. Removed

| gone | why |
| --- | --- |
| `res/drawable-v21/launch_background.xml` | the radial gold field + 174dp bitmap it replaced; `drawable/launch_background.xml` now serves every API this app supports (minSdk 24) |
| the 192dp coin item inside `res/drawable/launch_background.xml` | it is now a pure `<shape>` ramp. A mark on the pre-Flutter window is a second logo, and the OS decides its size |
| `res/drawable/splash_icon_288.xml` | the API 31+ canvas that carried the coin at 192dp inside the mask's safe zone — seen on a device, it read as its own splash screen in front of the real one |
| `res/drawable-nodpi/splash_logo.png` | 26,966B copy of the same coin, referenced only by the two drawables above. The Flutter side loads `assets/icon_foreground.png` |
| `res/drawable/splash_no_icon.xml` (first pass) → `splash_icon_none.xml` (now) | the same decision, reached twice: the first cut of this redesign deliberately un-hid the brand there, and the device look reversed it. The replacement differs in one way that matters — a transparent **drawable**, because `@null` falls back to the launcher icon |
| the old `SplashScreen` internals (`_FeatureItem`, the 650ms intro controller, the `_subtitleFade`/`_iconsSlide` animations, the radial `BoxDecoration`, the 300ms deep-link branch) | replaced by the painter + `SplashOrchestrator` |
| `await _bootstrapOnce()` before `runApp` | the four phases moved behind the first frame, same list, same guards |
| `SharedPreferences`-based timing inside the screen | the screen now asks `appBootstrapProvider` and the orchestrator, so the timing rule is unit-testable without a widget |

Kept deliberately: `assets/icon_foreground.png` in `pubspec.yaml` (the
launcher icon's adaptive foreground *and* the splash coin), the
`onboarding_done_v1` flag contract with `OnboardingScreen`, the
`notification_payload` / `widget_shortcut` stash in `MainActivity`, and
`BootCoordinator`'s routing role.

Not touched, still dead in the repo: `assets/logo3.png` and
`assets/logo_icon.png` — undeclared, unreferenced, and not mine to delete.

## 6. Open questions for the device pass

1. **Does the API 31+ window honour a drawable as `windowSplashScreenBackground`?**
   The attribute is documented as drawable-or-colour and AOSP resolves it with
   `getDrawable`, so the ramp should paint. Samsung/One UI is the unknown: if it
   ignores a non-colour value there, the fix is to put
   `@color/splash_field_mid` back on that one attribute (the pre-31
   `windowBackground` keeps the ramp either way) — not to put a mark back in the
   icon slot.
2. **Is the coin soft at the large end?** `assets/icon_foreground.png` is 512px,
   and the box is now up to 320dp — 960px at 3×. On an A32/411dp phone the coin
   is therefore upscaled ~1.9×. If the edge reads blurry on a device the answer
   is a larger source asset, not a smaller box; the app has no vector copy of
   the mark in the repo.
3. **Is 400ms the right floor on a real A13?** The floor is the only thing
   standing between the native field and Home; if `first-frame` lands at
   ~250ms and the gate at 400ms, 150ms is pure branding. Drop
   `SplashTiming.minimumShow` to 250ms if the user wants the launch snappier —
   one constant, and the orchestrator tests assert its value on purpose.
4. **The notification-tap regression**: a deep-link cold start used to leave
   at 300ms and now leaves at 400ms. If that is noticeable, restore the
   shortcut by having the orchestrator take a shorter `minShow` when a payload
   is stashed — the read already exists in `_readOnboardingDecision`.
5. **Persian shaping** has not been seen by any test: the goldens render tofu.
   Check the tagline on one phone at scale 1.3 and 2.0 (the cap makes 2.0 look
   like 1.3 — confirm that reads as intended, not as a broken setting).
6. **Warm resume** shows no splash by construction (the activity is not
   recreated), but confirm on a device with «Don't keep activities» off and
   the app killed from Recents.
7. **Is the coin now big enough, and is 1 cm the right lift?** The size and the
   offset came from a device look at the previous, smaller composition. The
   numbers are one constant each (`logoSize`'s 0.784/224/320 and `logoLift`), so
   a second look is a one-line change plus re-recording eight baselines.

## 7. Built artefacts

### The shipping build: `d982679`

`flutter build apk --release` at `d982679` — the tip that carries both halves of
the second pass (`5229ce4` the no-mark system window, `400fb1e` the bigger,
lifted coin, `a608008` the re-recorded goldens) — from a clean detached worktree
with the four gitignored files copied in (`android/key.properties`,
`android/app/release-key.jks`, `android/app/google-services.json`,
`assets/env/quran_api.env`), no dart-defines — Sentry stays OFF. `pub get` ran
first; a fresh worktree cannot build without the generated registrant. Gradle
`assembleRelease` took 753.8 s and exited 0, and **that exit is the native
check**: it is the only command here that links `@drawable/splash_icon_none` and
compiles `MainActivity.kt`. `version: 1.8.0+10015`.

| file | bytes | sha1 |
| --- | --- | --- |
| `app-release.apk` (fat) | 47,327,329 | `03e8b347526e0e7325f46a63d6adf068ecfa92e6` |
| `app-arm64-v8a-release.apk` | 31,436,675 | `f3689fcc9d63349236c0a2f04f82ccfbe0489955` |
| `app-armeabi-v7a-release.apk` | 31,688,778 | `f4133f375f7a9abec1de362d49f70c3b84405c14` |

Durable copies: `Desktop/tawheeed-release-apks/1.8.0-d982679/` + `SHA1SUMS.txt` +
`BINARY_PROOF.txt`. **Not** copied into the main tree's `build/`, where the
concurrent session writes its own artefacts.

Against the previous splash build (`1.8.0-84395a0`) the three files are
28,300 / 28,442 / 28,048 B **smaller** — the deleted `splash_logo.png` (26,966 B)
plus `splash_icon_288.xml`. Removing the mark from the system window costs
nothing; it gives a little back. Against `1.8.0-e577f2b` (48,098,369 B fat) the
splash line as a whole is 771,040 B down.

Proof inside the arm64 APK (`aapt2` / `keytool` / the table and UTF-16 probes
recorded in `BINARY_PROOF.txt`): `versionName 1.8.0`, `versionCode 2000010015`,
min 24 / target 36, V3 signature `CN=Tawheed, OU=Mobile, O=TawheedApp,
L=Tehran, ST=Tehran, C=IR`. `resources.arsc` names `splash_icon_none`,
`launch_background`, `splash_field_mid/top/bottom`, `LaunchTheme`, `NormalTheme`
and **no** `splash_icon_288`, `splash_logo` or `splash_no_icon`;
`assets/flutter_assets/assets/icon_foreground.png` — the coin the Flutter splash
draws, now the only logo in the launch — ships. `libapp.so` carries the tagline
«همراه شما در مسیر بندگی», «توحید» and the tile labels as UTF-16 at **both** byte
alignments, and for each of the seven probed strings the *computed* CP1256
mojibake form (`clean.encode('utf-8').decode('cp1256')`) is absent.

**A trap worth recording:** a regex over the whole `libapp.so` byte-wise UTF-16
decode reports 56 Arabic-letter↔residue adjacencies. That is not mojibake — Dart
stores strings length-prefixed, not NUL-terminated, so a raw decode invents
text out of machine data. Only the literal probe (both alignments) and the
computed-mojibake probe are valid here; the source-tree guard
`test/core/utils/text_encoding_guard_test.dart` is the one that reads files.

### The earlier builds of this line, superseded

`1.8.0-84395a0` (fat 47,355,629 / arm64 31,465,117 / armv7 31,716,826) and the
quran session's build of the **same code** at `7a2eb67`
(`1.8.0-7a2eb67`: 47,355,576 / 31,465,109 / 31,716,783 B — 53 / 8 / 43 bytes of
rebuild noise, either set installs the same app) both still put the coin in the
API 31+ system window through `splash_icon_288` + `splash_logo.png`. That is
exactly the second, square-icon page the user reported, so **those two sets are
not the build to install** — they predate `5229ce4`. Their in-APK proof said
`resources.arsc` carries `splash_icon_288` and `splash_logo`, which is now the
fingerprint of the old behaviour.

**What no build here proves:** they compile the Kotlin and pack the resources,
but nothing on this machine is an Android 12+ device, so the exit fade, whether
One UI paints a drawable as `windowSplashScreenBackground`, the sharpness of a
320dp coin from a 512px asset and the real launch time remain unverified — §3
and §6.

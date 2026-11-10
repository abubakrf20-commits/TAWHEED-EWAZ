# 07 — Device pass (POCO 2412DPC0AG, Android 16, arm64) — partial

Build verified on device: clean worktree `%TEMP%/opencode/ondevice-verify`
at `33703d3`, `flutter run --release`, installed as `com.islamic.tawheeed`
1.8.0+10015 (arm64-only, 30.8 MB) next to the older store build
`com.muath.manar`. Impeller/Vulkan backend active. Device disconnected
before the pass finished — open items are listed as finger steps, not claimed.

## Verified on the phone
- **Diagnostics screen renders live data correctly** (screenshot): notification
  permission ✓, exact alarms ✓, 126 scheduled alarms incl. «اذان مغرب ۵۹
  دقیقه بعد», **battery optimization NOT disabled** («رفع») and **GPS off**
  («فعال‌سازی») — the screen does its job on a real OEM skin (HyperOS).
- **Scheduler alive**: background engine logged `[prayer-notif] scheduled 58
  alerts` twice; foreground `MainActivity` resumed cleanly.
- **Old-app intel (out of scope, reported only):** the installed
  `com.muath.manar` store build shows a background-isolate crash dump,
  `[prayer-widget] sync failed: LocaleDataException` and a wrong-package
  `artUri (…//com.muath.manar/…)`. Current tree cannot produce that class:
  `intl`/`DateFormat` usage in `lib/` is **zero** (pure-Dart Jalali/digits),
  so the Locale crash has no code path left. Its `[prayer-widget]` tag no
  longer exists in the tree either.

## Device-found bugs in the current tree
- **D-VAULT (P1, FIXED `c177472`):** leaving «اطلاعات من» threw `Bad state:
  Using ref when unmounted` from `PersonalInfoScreenState.dispose`
  (`personal_info_screen.dart:79`) — and the throw **skipped `lock()`**,
  leaving the vault silently open. Fix: capture the notifier in `initState`,
  call the saved reference in `dispose`. Guard:
  `personal_info_screen_dispose_test` (unmount ⇒ no throw + vault false);
  personal_info scope 59/59. Protected-file edit, log-neutral, flagged.
- **D-SECSTORE (P3, observation):** `EncryptedSharedPreferences … Could not
  decrypt key — Falling back to custom ciphers` on this phone. App continues
  by design; the Keystore entry predates this install (first install Oct 3,
  possibly a differently-signed APK). No code change; re-check on a truly
  fresh install.
- Plugin `already registered` warnings + multi-engine geolocator lines are
  normal background-engine noise, not findings.

## NOT measured (phone disconnected first)
Cold start (`am start -W` ×3), black-background screenshots (hadith inner,
share screens, reading stats, sciences), frame times, memory, battery,
Doze/reboot, TalkBack, backup/restore round trip, tasbih-widget tap.

## Finger checklist (when the phone is back, ~15 min)
1. Cold start: `force-stop` + `am start -W …/.MainActivity` ×3, record
   TotalTime (target: fill `00_BASELINE_AND_LOGS.md` §8).
2. Walk (screenshot each): More → علوم اسلامی → first science → related link;
   More → hadith books → a book → a chapter; a dua → «ارسال دعا»; ketabkhaneh
   → stats. Expect the ambient glow, never black.
3. Tasbih widget: pin «تسبیح» widget, tap 3×, watch logcat for `dropped
   foreign tasbih broadcast` (must be ABSENT) and the count moving; open the
   app → today's tasbih total includes the taps. (Needs fresh build ONLY if
   the tip moved past `33703d3` in native code — Dart-only changes don't
   need a rebuild for this.)
4. Backup round trip: settings → «بازنشانی و انتقال» → export → (share sheet)
   save → delete one expendable item → import → verify it returns.
5. TalkBack smoke on Home + Settings + Quran reader (labels, order).

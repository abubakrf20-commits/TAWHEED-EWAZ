# SETTINGS_INVENTORY.md — every settings screen/row/control (branch `settings/redesign`)

> **عکس تاریخ‌دار — Historical snapshot.** این سند وضعیت را در شاخه و تاریخ خودش ثبت
> می‌کند و خوانده‌شدنش به‌عنوان «وضعیت امروز» درست نیست. مرجع فعلی فقط `AGENTS.md`
> (ریشهٔ مخزن) و `docs/SECTIONS_1_9_0.md` است؛ فهرست کامل در `docs/README.md`.


Source of truth for the redesign. Preference keys, defaults, ranges and side
effects below are TODAY's behavior and must not change — only presentation,
layout, grouping and the listed fixes change. Persian UI text stays Persian;
code/comments/commits in English.

Entity defaults: `lib/features/settings/domain/entities/app_settings.dart`
(all `const AppSettings(...)` defaults quoted as `D=`). Writers:
`settings_notifier.dart` (`_saveWith` read-modify-write + `_rescheduleAlarms`
where noted). SharedPrefs keys outside Drift are marked `(prefs)`.

Conventions used below — `Template` = the new-design template that applies:
`H` header (SettingsAppBar + SectionHeader), `R` SettingRow, `RSW` row+Switch,
`RCH` row+chevron/nav, `RV` row+value-chip, `STP` compact Stepper row,
`SLD` slider row, `SEG` segmented, `WARN` WarningCard, `CARD` per-topic card
(Prayer-A, account hero-lite, widget preview), `SHEET` bottom-sheet radio
list, `DLG` dialog, `SRCH` search registry entry.

---

## 0. Shared primitives (exist today)

- `SectionHeader` (design system): 4x18 gold bar + title 14/500 + count chip +
  trailing. NOTE (measured): title is `Flexible(flex:1)`, so a plain `Spacer`
  splits free space 50/50 and parks trailing mid-row — new code must use the
  fixed spacer (flex wins) or equivalent.
- `AppCard`: white, r22, 0.5px border; default padding `DsSpacing.page`.
- `SettingRow`: IconTile + title/sub + trailing (default chevron), 48dp.
- `IconTile` (old grey squircle — replaced by duotone Style-2 everywhere).
- `ValueStepper`: 48dp boxed buttons, clamp+dim, haptic; value box minWidth 56.
- `SliderRow`, `SwitchTile`, `SelectTile<T>` (sheet radio), `TimePickerTile`,
  `SettingsCard/Divider`, `SegmentedTabs`, `DuotoneIconTile` (home),
  `MoreDuotone` (more style-2), `RingView`.
- `NumberFormat`: `fraction` ("N از M"), `ltrIsolated` (U+2066/2069),
  `toLatin`/`normalizeDigits`, `formatPlain`, `en`, `parse`. NEW (this branch):
  `formatSigned` ("+2"/"−5" U+2212, isolated), `formatDegrees` ("18°",
  isolated), `formatMinutes`, plus search normalization reuse.
- Tokens: `AppPalette.heroGold/goldDark/emerald`, `HomeColors.done 2E8B3D`,
  value chip text `7A5410` on `FFF1D2` r9, pill fill `FBF3E8` border `EADFCC`,
  dividers `F3EADB`, theme danger/success via `AppColors`.

## 1. Main Settings (`/settings`, `settings_screen.dart`)

App bar: title «تنظیمات» + search ICON → replaced by top search FIELD (spec §9).
Loading: spinner while `settingsProvider.value == null`.

### 1.1 Appearance card — Template: SEG + chip row + RCH
| Row | Control | Key / write | Range / D | Side effects |
|---|---|---|---|---|
| theme mode سیستم/روشن/تاریک | segmented 3 | `themeMode` / `setThemeMode` | D=`light` | app ThemeMode rebuild |
| theme chips (6): زنده/طلایی/سحر/روز/غروب/شب | chip row (spec §c) | `accentPreset` / `setThemeKind` | D=`classic`→gold fallback | palette rebuild, live |
| فونت و نمایش / انتخاب فونت، اندازه و متن عربی | RCH | — | — | → `/settings/font` |

### 1.2 Prayer & adhan card — RCH + stepper row
| Row | Control | Key / write | Range / D | Side effects |
|---|---|---|---|---|
| تنظیمات اذان و اقامه / live summary | RCH | — | — | → prayer page |
| تنظیم تاریخ هجری / تطبیق با رویت هلال | signed Stepper + ±5/±1/5/1 quick buttons (keep!), unit روز | `hijriOffset` / `setHijriOffset` | −5…+5 step 1, D=2 | IslamicEvents + calendar/hijri dates |

### 1.3 Sounds card — 2× SLD (accents C9922F / D85A30)
| Row | Control | Key / write | Range / D | Side effects |
|---|---|---|---|---|
| صدای کلیک تسبیح / هنگام شمارش تسبیح و اذکار | slider 0–100 | (prefs) `azkar_sound_volume` / azkar notifier `setTasbihVolume` | 0…1, D=1.0 | click volume only |
| صدای هشدار / پومودور و پیش‌نمایش یادآوری‌ها | slider 0–100 | (prefs) `sound_alert_volume` / `AlertVolume.set` | 0…1, D=1.0 | pomodoro + reminder previews |

### 1.4 Scoring card — 6× STP (min 1/max 50; multiplier 25–300 step 25, LTR ٪)
| Row | Key / write | D |
|---|---|---|
| هر نماز واجب (فرض) / فرض یا قضای انجام‌شده | `fardhPoint` / patch | 10 |
| هر سنت و وتر / رواتب و وتر انجام‌شده | `sunnahPoint` / patch | 5 |
| نماز ضحی / نماز چاشت انجام‌شده | `duhaPoint` / patch | 5 |
| اذکار صبح و شام / هر دور اذکار صبح یا شام تکمیل‌شده | `adhkarPoint` / patch | 10 |
| تسبیح / انجام تسبیح (هر روز) | `tasbihPoint` / patch | 10 |
| طاعات (قرآن، صدقه، نماز شب و…) / ضریب امتیاز چک‌لیست طاعات | `worshipMultiplier` / patch (v/100) | 1.0 (=100٪) |
Side effects: scoring only.

### 1.5 Notifications & adhkar card — RCH ×3
تنظیمات اعلان‌ها و اذکار → notification settings; تشخیص تنظیمات گوشی →
diagnostics; پیوست‌های اطلاعات من (kDebugMode only) → attachment diagnostics.

### 1.6 Personal-tools lock card — RSW ×3 + WARN
Keys: (prefs) `tool_locks.enabled` StringList via `toolLocksProvider` /
`setToolLocked` + invalidate. Rows: هزینه‌ها، یادداشت‌های عبادت، دنگی —
subtitle locked/unlocked; no-PIN WARN + «تعیین رمز» → personalInfo. Period
excluded by design. Enforcement in `ToolLockGuard` (untouched).

### 1.7 Widgets card — RCH: تنظیم ویجت‌های صفحه اصلی / رنگ، شفافیت و ابعاد → widget settings.

### 1.8 Account card — RCH: حساب و نسخه‌پشتیبان ابری / ورود، آپلود و بازیابی پشتیبان (+ signed-in state) → account.

### 1.9 Backup card — action rows (BackupService direct, snackbars)
- auto daily row: subtitle live (default text else `آخرین پشتیبان: امروز/دیروز ساعت H:M` / Shamsi) + outline chip button «همین حالا» (spinner while busy).
- full ZIP row: password DLG (empty = plain, mismatch error, privacy banner) → SharePlus share.
- restore-auto row → destructive confirm DLG (+vault caveat) → invalidate settings+DB + `_postRestoreRepair` (**page's only alarm reschedule**: forceReschedule prayer+khatm, permission dialog if denied).
- restore-file row: SAF picker (.zip→same path, .json→prefs-filtered import + count snackbar).

### 1.10 Misc card — RCH ×4: battery optimization, suggestions, announcements, about (subtitle «نسخه و اطلاعات برنامه»).

### 1.11 Font page (`/settings/font`, from §1.1) — RCH + SLD + RSW ×4
فونت برنامه (SelectTile Vazirmatn/Amiri/Calibri(Bold), D=calibri); اندازه فونت
SLD 13–26 (writes appFontSize + fontScale=v/15, D=15.0/1.0); ساعت 12 ساعته
(use12Hour, D=true); نمایش متن عربی (showArabicText, D=true); نمایش دلیل
(showDaleel, D=true); فونت بزرگ‌تر عربی (largeArabicFont, D=false).

### 1.12 Search index (today: 16 entries, delegate+anchors) → replaced by
SettingsRegistry + top field (spec §9). Keep every keyword; add new rows.

## 2. Prayer & Adhan (`/prayer/settings`, `prayer_settings_screen.dart`) — Design A

### 2.1 Adhan sound card — RCH + 2 action rows (+ conditional file row)
| Row | Key / write | D | Side effects |
|---|---|---|---|
| صوت اذان / voice label (SHEET radio: الغامدی-کامل/تکبیر/فایل شخصی) | `azanSound` / `setAzanSound` | `takbir` | `_rescheduleAlarms` |
| پخش صدای اذان (تست) | — (preview svc) | — | none |
| تست اعلان اذان / زمان‌بندی…یک دقیقه بعد | — (scheduleTestAdhan) | — | real notification |
| انتخاب فایل اذان (iff custom; trailing باسم/بدون فایل) | `customAzanPath?` / SAF→`setCustomAzanPath` | null | `_rescheduleAlarms` |
Orphan (no UI, keep): `azanVolume` D=1.0 (baked into alarms).

### 2.2 Calculation card — RCH + radio rows + conditional sliders + RSW + RCH
| Row | Key / write | D | Side effects |
|---|---|---|---|
| روش محاسبه / `{label} — {description}` (SHEET 13 options) | `calculationMethod` / save-only | muslimWorldLeague | auto recompute (settings key) |
| مذهب عصر (SHEET حنفی/شافعی…) | `asrMethod` | shafi | auto recompute |
| قانون عرض بالا (SHEET 3) | `highLatitudeRule` | middleOfTheNight | auto recompute |
| زاویه فجر / زاویه عشاء (iff custom; SLD 10–21 step 0.5, pill °) | `customFajrAngle`/`customIshaAngle` | 18.0/17.0 | auto recompute |
| اصلاح ارتفاع مکان / تصحیح افق… (RSW) | `elevationCorrection` | false | auto recompute |
| جزئیات محاسبه / نمایش ورودی‌ها… (RCH → SHEET rows) | read-only | — | none |
Bidi risk (fixed by formatDegrees): `زاویه فجر 18° و عشاء 17°` in subtitles,
`N°` pills, `فجر +5، ظهر -3` details line.

### 2.3 Location card — RSW + RCH ×3 (manual only)
موقعیت خودکار/GPS (useLocation, D=true, auto recompute); جست‌وجوی شهر
(SHEET offline PlaceIndex + internet fallback → setUseLocation(false)+
setManualCoords+setCity+setTimezone); انتخاب از روی نقشه (→ mapPicker, same
contract); عرض/طول جغرافیایی (LTR numeric fields, lat −90…90, lng −180…180,
empty→0; setManualCoords+hasLocation).

### 2.4 Per-prayer card (THE Design-A card) — 5 blocks, hairline-separated
Header: SectionHeader + 10.5 description + independence note (keep text).
Per prayer (فجر/ظهر/عصر/مغرب/عشاء; icons+tints 5B4BC4/C9922F/C9822B/E2552E/5B4BC4):
- line 1: 32dp tile + name 13.5/500 + caption «پخش اذان» + Switch
  (`azanEnabledFor*`, all D=false; disable stops playback + `_rescheduleAlarms`).
- line 2: «تنظیم اذان» + signed STP (−70…+70 step 1, unit دقیقه) at start side;
  «اقامه» + STP (0…70 step 1, unit دقیقه) at end side.
  Keys: `fajrOffset/dhuhrOffset/asrOffset/maghribOffset/ishaOffset` (D=0,
  save-only, auto recompute); `iqamahOffsetFajr/Dhuhr/Asr/Maghrib/Isha`
  (D=30/25/25/10/25, +`_rescheduleAlarms`).
- Dim rule: keep today's logic (shift usable while it affects reminders/times,
  else dim).
- Orphan (no UI, keep): `sunriseOffset` D=0.

### 2.5 Prayer-notification card — RSW + conditional STP
یادآوری اوقات نماز (prayerNotifications, D=true; screen-level forceReschedule);
یادآوری قبل از اذان (prayerNotifMinutes 0…30 step 1, D=5; forceReschedule,
adhan untouched).

### 2.6 Global shift card — signed STP (−60…+60, D=0, helper text kept)
`globalPrayerOffset` + `_rescheduleAlarms` (only shift setter with one).

### 2.7 Friday card — RCH (+ conditional reset row)
وقت نماز جمعه / live `پیش‌فرض: وقت ظهر (HH:MM)` ⇔ custom (fridayPrayerTime?,
null=follow Dhuhr; showTimePicker → forceReschedule); conditional «بازگشت به
وقت ظهر» row when custom.

### 2.8 Silence card — WARN (DND) + RSW + conditional STPs
- DND WARN (granted green / denied orange + outline button → OS settings;
  re-check on resume — keep flow).
- بی‌صدا قبل از اقامه / خاموش کردن صدا… (silentBeforeIqamah D=false +
  `_rescheduleAlarms`; enable without grant → snackbar + open action).
- مدت زمان (دقیقه) (silentBeforeIqamahMinutes 1…60, D=15).
- ماندن بی‌صدا بعد از اقامه (silent_after_iqamah_tile; (prefs)
  `silent_after_iqamah_minutes` 0…120 D=0; best-effort forceReschedule).
- بی‌صدا در وقت نماز (silentDuringPrayer D=false); مدت زمان
  (silentDuration 1…60 D=10).

## 3. Widgets settings (`/settings/widget`) — preview CARD + SLD/SLD + rows
Preview (prayer/tasbih tabs, live data, contrast<4.5 WARN); bg/text colors
(6 swatches + picker + hex field, keys `widget_bg_color` D=#004F9E /
`widget_text_color` D=#FFFFFF); شفافیت SLD 0.2–1.0 step .05 (D=.95);
گوشه‌های گرد SLD 0–32 step 4 (D=20); manual sync row (+snackbar); add-widget
row (OS pin request + snackbars); help sheet; Save action (dirty-guarded,
discard DLG, persist+push+sync+haptic). Template: spec widgets section
(sliders + swatches 46dp + preview).

## 4. Notifications (`/settings/notifications`) — RSW/time/segmented rows
Exact-alarm WARN + button → diagnostics. اذکار صبح و شب: master RSW (recall
key `notif_azkar_master_recall`) + per-side RSW + anchored/fixed SEG +
TimePicker (morningAzkarTime D=06:00 anchored +45m post-fajr;
eveningAzkarTime D=20:00 hint +1h post-asr; manual flags
`notif_azkar_morning/evening_manual`). اذکار بعد از نماز: RSW
(`notif_post_prayer_enabled` D=true) + delay dropdown 5–60
(`notif_post_prayer_delay_minutes` D=10). Daily rows (RSW+time):
آیه (dailyVerse D=true 07:00), حدیث (dailyHadith D=true 18:00),
دعا (dailyDua D=false 12:00), قرآن (quranReminder D=false 08:00).
مناسبت‌ها RSW (`notif_islamic_events_enabled` D=true → monthly schedule).
Friday RSW+time (enabled D=true 07:00; kahf D=true 06:00; weekly arms).
سایر: snooze SEG 5/10/15 (D=10); destructive «لغو همه یادآوری‌ها» row +
confirm DLG (cancels all incl. native alarms, bumps cancelAllTick).
All toggles → `rescheduleAll()` (= forceReschedule + conditional schedules).

## 5. Account & cloud (`/settings/account`) — hero-lite CARD + rows + DLGs
Signed-out: info card + Google button (+ email form iff Firebase present;
reset-password link; friendly error map). Signed-in: header (avatar+email+
logout confirm DLG) + Drive upload row + Drive list (SHEET: Shamsi labels,
size·device, restore/delete per item + confirms + password DLG) + Firebase
upload row + Firebase list (same row actions) + red delete-account row +
confirm DLG. Empty/loading/error states kept. Offline/error WARNs kept.

## 6. Tool locks & PIN — RSW ×3 + WARN (+ personal-info vault screens untouched)
Keys: (prefs) `tool_locks.enabled` via toolLocksProvider/setToolLocked;
rows هزینه‌ها/یادداشت‌های عبادت/دنگی with lock subtitles; no-PIN WARN +
«تعیین رمز» → personalInfo. PIN screens, guards, lockout, reset flows in
personal_info stay exactly as-is (only the settings rows restyle).

## 7. About (`/settings/about`) — Design 1
- Compact hero (~200dp): gradient 5B3F31→4A3024→2A1A12, bottom r38, gold
  glow, in-hero app bar (back + «درباره توحید» cream 16/500), REAL
  `assets/logo2.png` at 78dp (verified), «توحید» 20/500 cream, version chip
  «نسخه 1.8.0» LTR gold-on-gold@20% (PackageInfo version), tagline
  «همراه عبادت روزانه» gold.
- Description AppCard (keep text).
- «امکانات برنامه» + 3-col grid (Style-2 tiles 58dp, own accents — reuse the
  real 15-item list from code; non-tappable): map old icons→filled/duotone
  weight per spec.
- «پشتیبانی و اطلاعات» rows: share (system sheet, EXISTING Play text kept),
  feedback→Telegram channel (kTelegramUrl, verified const), privacy (inline
  text → keep as in-app dialog content), update row (checker/installer flow
  incl. sha-pin + dialogs, kept).
- OMITTED with reasons: rating row (no Bazaar/Myket config; Play URL exists
  but spec says config-only → report, leave out), منابع و مجوزها page (no
  such page/asset; licenses via showLicensePage only if adopted — report),
  changelog (no local asset; update notes come from remote update.json),
  Terms screen (does not exist).
- Footer: «نسخه 1.8.0 (ساخت N)» LTR (versionCode) + © year توحید, 10.5 muted.

## 8. Duplicates & orphans (verified)
- ONE true duplicate: tasbih click volume — main sounds slider AND tasbih-tab
  sheet slider (same key `azkar_sound_volume`). DECISION: both stay (global
  settings vs in-context sheet); documented, single key, no divergence.
- Adhan sound: single-homed (prayer page only; main page deliberately
  excludes it). `azanVolume`: NO UI anywhere (keep setter+alarms wiring).
- `quranFontSize`/`showEnglishTranslation`: NO UI (keep fields).
- `sunriseOffset`: NO UI (keep engine wiring).
- `dailyWord*` (word-of-day scheduler), `quranThemeMode` (mushaf reader),
  `tafsirId` (mushaf sheets), `tasbihDhikrSource` (tasbih source),
  `widgetRefreshMinutes`: no settings UI (keep; out of scope).

## 9. RTL-bidi risk sites (all fixed by the shared formatters)
`+0/−5/+2` steppers & chips, `18°/17°` in calc subtitles, `فجر +5، ظهر -3`
details line, hijri `+N/−N روز` pill, `٪` pills (already LTR), lat/lng
`−90…90` error text. Safe already: UTC offsets, HH:MM, coords fields (LTR),
ValueStepper plain counts.

## 10. Routes (registry must resolve all of these)
`/settings` (main), `/settings/font`, `/prayer/settings`, `/prayer/map-picker`,
`/settings/notifications`, `/settings/notification-diagnostics`,
`/settings/widget`, `/settings/account`, `/settings/about`,
`/settings/suggestions`, `/settings/announcements`, `/personal-info`,
`/prayer/battery`, `/settings/prayer-times-share`(check name),
weather/lockouts: DnD OS settings (intent), SAF file picker (native).
Verify each during implementation; report unresolvable ones.

---

## SHORT PLAN

1. **Shared**: `SettingsNumberFormatters` (signed/degrees/minutes/fraction) +
   unit tests; `SettingsAppBar`, `SectionHeader`+desc, `AppCard` tweaks (if
   needed), `SettingRow` trailing value-chip + standard `SettingsSwitch`
   (42×24, emerald 2E8B3D/white, off D9CDBB/white), compact `SettingsStepper`
   (32h pill, 44dp targets, long-press repeat, Semantics), slider row,
   segmented, `WarningCard`, search field, `SettingsRegistry` + search
   (normalize+debounce+group+highlight), pref-key snapshot test. Commit.
2. **Main page** (Design 1: search field, 9 sections incl. theme chips,
   hijri stepper, sliders, scoring, locks, backup, misc). Widget+golden
   tests. Commit.
3. **Prayer & Adhan** (Design A incl. per-prayer card, DnD flow, pickers).
   Mock-scheduler reschedule test. Commit.
4. **Widgets / Notifications / Account+backup / Locks rows / Font page**:
   one commit each (or two), same components. Commit(s).
5. **About** (Design 1). Goldens both themes. Commit.
6. Full suite + goldens + analyze + gate; write `docs/SETTINGS_REPORT.md`;
   delete old widgets only after zero references; final summary. No push.

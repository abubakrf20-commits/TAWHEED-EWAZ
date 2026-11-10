# Tawheed — Architecture Notes

Living document produced by the phase-2 audit. It encodes the rules the code
is now expected to follow; `tools/quality_check.py` enforces the mechanical
subset of them in CI (report-only until the team flips it to `--strict`).

## Layering

```
presentation (screens/, widgets/)  →  may watch/read providers
presentation/providers/            →  state + orchestration (Riverpod)
domain/                            →  entities + repository interfaces
data/ (repositories, daos, datasources) → implementations
shared/ + core/                    →  cross-feature services and utils
```

- Screens and widgets must NOT declare providers. `_allBookmarkedIdsProvider`
  used to live inside `ketabkhaneh_screen.dart`; it now lives in
  `book_bookmark_provider.dart`. `quality_check.py` fails on new violations.
- A feature may import another feature's `presentation/providers`, never its
  private widgets.

## State management (Riverpod)

Codegen (`@riverpod` / `@Riverpod`) is the default for anything that holds
state or logic; plain providers are allowed only as thin DI/connection seams
(e.g. `notificationServiceProvider`, `service_providers.dart`).

Converted in phase 2 (names unchanged, so no call-site churn):
`azkarSettingsProvider`, `expenseListProvider`, `expenseBudgetProvider`,
`totalBalanceProvider`, `budgetStatusProvider`, `expensesInJalaliMonthProvider`,
`notesProvider`, `subtaskListProvider`, `readingStatsProvider`,
`readingTotalProvider`, `readingStreakProvider`, `azkarVersionProvider`,
`allBookmarkedIdsProvider`.

Lifecycle: family/autoDispose by default in codegen; use
`@Riverpod(keepAlive: true)` when a provider is invalidated explicitly
(`boot_coordinator` invalidates `readingStreakProvider`, `azkarVersionProvider`,
… — these must stay keepAlive or the invalidation is a no-op).

The four `ChangeNotifier` classes (`AudioLibraryPlayer`,
`QuranAudioController`, `QuranTranslationAudioController`,
`RuqyahAudioService`) stay on purpose — each is a thin adapter over the
`audioplayers` event model, owned by a provider. The "why" is documented at
every class declaration; do not convert without an adapter layer.

## Error handling

- `AppErrorBoundary.isBenignError` filters known-benign first-frame errors
  (render-flex overflow, image/font load failures) so they never blank the
  UI; fatal errors before the first completed frame swap in the retry UI via
  an end-of-frame `setState` (never during build/layout).
- Every `catch` in a critical path (shared/, core/services, prayer,
  settings services/data, quran download/offline bookkeeping) must log
  through `AppLogger.warning(tag, message)` before falling back. Catches
  whose comment documents an *expected* condition (missing platform channel
  in tests, legacy-format fallback) are exempt.
- Never swallow an exception you then silently compensate for (backup
  decrypt, expense load) without a log line — the log is the only way to
  distinguish "worked" from "always failing since v1.4".

## Null safety

- `Color.lerp(a, b, t)` is nullable: always `?? a` fallback, never `!`.
- Map/regex indexing: `map[key] ?? fallback` — never `!`. The inheritance
  tabs were converted (146 sites); do not reintroduce.
- Helpers live in `core/utils/jalali_format.dart` (the canonical Jalali
  label helpers) instead of per-feature copies.

## Dependency injection / testability

Infrastructure singletons are exposed as providers so boot flows can be
overridden in tests:

| provider | file |
|---|---|
| `notificationServiceProvider` / `dailyNotificationSchedulerProvider` | notification_settings_notifier.dart |
| `permissionServiceProvider`, `backupServiceProvider`, `azanServiceProvider` | shared/providers/service_providers.dart |
| `widgetSyncServiceProvider` | shared/services/widget_sync_service.dart |

Rule: if you add a `factory X() => _instance` singleton that boot code
touches, add a provider here and go through `ref.read(...)`.

Tests use hand-written fakes (`test/features/settings/presentation/
fake_notification_infra.dart`), not mockito — a fake's `noSuchMethod`
throws with the member name so an unstubbed production call fails loudly
instead of returning null.

## Memory / lifecycle

- Every `TextEditingController`/`AnimationController` created in a method
  needs a dispose: dialog helpers use `.whenComplete(ctrl.dispose)` or
  dispose after `await showDialog`.
- Stream subscriptions created in `init`-style methods are stored in fields
  and cancelled in `dispose` (see `audio_library_player`,
  `ruqyah_audio_service`).
- One-shot `Timer`s created outside the class lifetime must be fields and
  cancelled (widget_sync retry timer).

## Quality gates

`python3 tools/quality_check.py` (CI: report-only) checks:
silent catches without AppLogger, `]!` lookups, providers declared in
screen/widget files, hardcoded share footers (use `ShareService.appLine`),
and `Color.lerp(...)!`.

CI also prints instrumented line coverage after the test run; treat a
steady-state drop as a regression, not noise.

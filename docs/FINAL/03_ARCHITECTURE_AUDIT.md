# Phase 3 — Architecture audit (static)

## Layering
Feature-first (`lib/features/<name>/{data,domain,presentation,services}`) with
shared `core/` (theme, design system, database, utils) and `shared/`
(services, widgets). Drift DB under `lib/core/database/`. No layer
violations found in the sampled cross-imports (presentation reads providers,
services own platform channels). No finding.

## State management: uniform Riverpod
Zero non-Riverpod state imports (`get`/`bloc`/`provider`/`mobx`/`redux`
absent). Screens are `ConsumerStatefulWidget`/`ConsumerWidget`; generated
notifiers (`settings_notifier.g.dart`) coexist with hand-written providers.
One gate-backed invariant: **no providers declared inside screen/widget
files** (strict gate #3, green). No finding.

## Navigation
Typed GoRouter routes (`RouteNames` + `...Path(id)` helpers); detail routes
carry `_ambient` wrappers. Residual `Navigator.push` sites: ketabkhaneh (2),
duas (4), dua-detail (1), dua-from-quran (1), hadith (4), adhkar-category (1),
timeline card (1) — audited in Phase 2: opaque-scaffold targets are harmless;
transparent-scaffold targets are the T2–T5 black-bg findings (fixed F2a–F2e).
A source-scan guard pins the sciences; an equivalent guard is added for the
share screens in Phase 6. Deep links: no custom scheme/intent-filter deep
linking found in the manifest sample — router-only navigation (verified in
Phase 4 doc).

## Async correctness
`use_build_context_synchronously` is error-level and green. Sampled timers
all cancel in `dispose`. `unawaited` used for fire-and-forget chains.
No `setState`-after-`dispose` pattern found in the sampled live widgets
(timers guard `mounted` / cancel on dispose). No finding; full-lifecycle
proof needs runtime.

## Size / duplication / dead code
- Largest non-generated files: `quran_mushaf_view.dart` (2.6k),
  `settings_screen.dart` (1.9k), `evaluation_stats_widget.dart` (1.8k),
  `zakat_screen.dart` (1.8k), `ketabkhaneh_screen.dart` (1.7k),
  `notification_service.dart` (1.7k), `qibla_screen.dart` (1.6k),
  `hadith_books_screen.dart` (1.5k). Splitting them is churn adjacent to
  recent/protected work → recorded as P2 maintainability, **not split**.
- Dead code: only the three long-known orphans (weekly-stats widget,
  gradient button, `main_admin.dart`) + `flutter_svg`-era leftovers already
  removed. The strict gate + analyzer keep imports honest. No finding.
- `analysis_options.yaml`: strict (flutter_lints + `use_build_context_
  synchronously: error`, `avoid_print`, const/final/disposal rules),
  generated + vendored paths excluded with justification. No finding.

## Net
No P0/P1 architecture findings. One P2 (god-file sizes, do-not-split without
approval) carried to the phased plan.

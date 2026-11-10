#!/usr/bin/env python3
"""Design-consistency ratchet for the PART-2 unification pass.

Reproduces the marker table of ``docs/FINAL/00_SCREEN_AND_DESIGN_COVERAGE.md``
§0 (which files still carry raw colours, raw ``fontSize`` literals, heavy
shadows, ``Opacity(``, ``BackdropFilter(``, hard-coded ``TextDirection.ltr``)
and enforces it as a one-way ratchet:

  * palette / painter / token sources are **allowlisted** (their colours are
    the design, not a deviation);
  * every other file's counts are held to the budget measured at wave 0; a
    count that grows outside the allowlist fails the run;
  * a count that shrinks is reported so the budget can be lowered (the
    numbers may only go DOWN over the migration).

Usage
-----
    python tools/design_consistency.py            # check (exit 1 on growth)
    python tools/design_consistency.py --report   # same table, always exit 0
    python tools/design_consistency.py --budgets  # print the BUDGETS snippet

No third-party imports; runs on the plain Python that ships with the repo
tooling (``tools/quality_check.py`` uses the same style).
"""

from __future__ import annotations

import argparse
import fnmatch
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "lib"
TEST = ROOT / "test"

# ── what the design language allows to carry raw values ─────────────────────
# Palette sources, the kit's own token layer, the splash style (theme
# independent by design), the home token file (28 semantic hexes) and the
# frozen mushaf bundle (paper/ink maths + painters). Everything else must
# come from TimeThemeKit / TopicHues / AppTheme.
ALLOWLIST = (
    "lib/core/theme/*",
    "lib/core/design_system/components/share_card_palette.dart",
    "lib/core/theme/**",
    "lib/core/design_system/components/tokens.dart",
    "lib/features/splash/presentation/splash_style.dart",
    "lib/features/home/presentation/widgets/home_tokens.dart",
    "lib/features/quran/mushaf/**",
    # One palette module per feature, holding the colours a *reader* chooses
    # (the book reader's page, its highlighter swatches, a chart's series) or
    # a scoped identity table — the same precedent as `share_card_palette.dart`.
    # A feature's chosen colours are counted as one named source instead of
    # scattering literals across its screens; the number still shows up in the
    # `allowlisted` column, so relocating a literal here is visible in review.
    "lib/features/*/presentation/*_palette.dart",
    # The same idea under its older names: pre-existing per-feature colour
    # tables (the worship checklist's content hues, the dongi cost tiers, the
    # calendar's occasion hues, the notes' highlighter swatches). They are the
    # feature's colour source, so they are counted in the `allowlisted` column
    # rather than as scattered literals.
    "lib/features/worship/presentation/utils/worship_colors.dart",
    "lib/features/tools/dongi/presentation/dangi_colors.dart",
    "lib/features/tools/calendar/presentation/widgets/calendar_style.dart",
    "lib/features/notes/presentation/utils/note_colors.dart",
)

SKIP = (
    "lib/desine/**",  # the design reference package, excluded from analyze
)

# Fixed-layout surfaces. These are the only places a raw `fontSize` is correct:
# a PDF is a document rendered once at a fixed page size, and a `CustomPainter`
# draws on a fixed canvas — neither has a `BuildContext`, and neither may
# follow the reader's «اندازه فونت» setting (a PDF that reflows with the phone's
# text scale would be a bug, not a feature). Their sizes are reported as an
# informational counter instead of being charged to the ratchet, so a new raw
# size anywhere else still fails the run.
#
# The widget preview is the same failure mode with a context: it exists to show
# what the *native* dial paints, and the native dial's sizes come from the
# user's widget beautification settings (`countTextSize`, `scale`), never from
# the phone's text scale. Scaling it here would make the preview lie.
FIXED_LAYOUT = (
    "lib/features/**/*_pdf.dart",
    "lib/features/tools/shared/pdf_report_util.dart",
    "lib/features/hifz/presentation/screens/hifz_report_screen.dart",
    "lib/features/tools/moon/presentation/widgets/hilal_sky_panel.dart",
    "lib/features/adhkar/tasbih/presentation/widgets/tasbih_widget_preview.dart",
)

# ── budgets (measured at wave 0, 2026-10-12, release/1.8.0 @ 06d7fb3) ───────
# Non-allowlisted counts only. Lower them as the migration lands; never raise
# one — fix the code instead.
BUDGETS = {
    # 714 -> 653 (wave 1 share family) -> 606 (the rest of wave 1 + dsOnAccent)
    # -> 423 (the app-wide sweeps: dsOnAccent/dsShadow ternaries, the status
    # family and the duplicated identity hues) -> 300 (the inheritance palette:
    # 111 literals in 13 files became one allowlisted module; and the splash
    # allowlist below, which named a `screens/` path that has never existed, so
    # its 12 literals were being charged to the ratchet) -> 282 (the two last
    # share cards, `hadeeth_share_card` 13 and `dangi_settlement_share_card` 5,
    # moved onto `ShareCardPalette` + their own palettes, so every
    # `*_share_card/screen.dart` is now locked at zero by
    # `test/core/design_system/share_surfaces_source_lock_test.dart`) -> 275
    # (measured on the merged line: the release-side home/settings/widgets work
    # that landed after this branch forked removed literals of its own).
    "raw_color": 275,
    # 598 -> 525 (wave 1) -> 0: every screen/widget gets its sizes from
    # `AppTheme.scaledFontSize`, so the reader's font setting now actually
    # applies; the 59 sizes of the fixed-layout PDFs/painters are reported as
    # an informational counter instead (see FIXED_LAYOUT). The three sizes the
    # release's tasbih pill recipe hand-typed went through the scale at the
    # merge, so this stays 0.
    "raw_size": 0,
    "blur10": 45,
    "opacity": 1,
    "backdrop": 0,
    # 37 -> 38 on the merged line. This is the one budget the merge rule allows
    # to move, because neither added site is a defect: both are the app's
    # sanctioned bidi isolation of a Latin-digit run inside a Persian string
    # (`hero_card.dart`'s countdown/clock, `settings_components.dart`'s value
    # display). Undoing an isolation here re-opens the counters-swap-sides bug
    # AGENTS.md records for the fraction formatter. A *new* ltr that is not a
    # digit isolation still fails the run.
    "ltr": 38,
}

# Informational adoption counters (no budget: more kit/time-theme use is good,
# and `appcolors_files` may only go down).
APPDEFAULTS = {
    "appcolors_files": 0,
}

PATTERNS = {
    "raw_color": re.compile(r"Color\(0x"),
    # The trailing `[^\n,;()]*\d` (instead of a bare `\d`) also catches a
    # number on the CONTINUATION line (`fontSize:` / `cond ? 17 : 23`) while
    # still skipping `scaledFontSize(…)` calls, whose digits sit behind a
    # paren. Relative offsets off a user-controlled base (`_fontSize - 2`)
    # are not raw literals either and stay uncounted (the whitespace lives
    # INSIDE the lookahead: leaving it outside lets backtracking slip past
    # the guard). Single-line raw literals match exactly as before.
    "raw_size": re.compile(r"fontSize:(?!\s*[A-Za-z_][\w.]*\s*[-+*/])\s*[^\n,;()]*\d"),
    "blur10": re.compile(r"blurRadius:\s*(\d+(?:\.\d+)?)"),
    "opacity": re.compile(r"(?<![A-Za-z_])Opacity\("),
    "backdrop": re.compile(r"BackdropFilter\("),
    "ltr": re.compile(r"TextDirection\.ltr"),
    "appcolors": re.compile(r"AppColors\.|app_colors\.dart"),
    "kit_import": re.compile(r"design_system/components"),
    "time_theme": re.compile(r"core/theme/time_theme\.dart"),
}

LABELS = {
    "raw_color": "raw Color(0x…) outside the palette allowlist",
    "raw_size": "raw fontSize: <number> outside the allowlist",
    "blur10": "BoxShadow blurRadius >= 10 outside the allowlist",
    "opacity": "non-animated Opacity( outside the allowlist",
    "backdrop": "BackdropFilter( anywhere",
    "ltr": "hard-coded TextDirection.ltr outside the allowlist",
}


def is_allowed(rel: str) -> bool:
    return any(fnmatch.fnmatch(rel, pat) for pat in ALLOWLIST)


def is_skipped(rel: str) -> bool:
    return any(fnmatch.fnmatch(rel, pat) for pat in SKIP)


def is_fixed_layout(rel: str) -> bool:
    return any(fnmatch.fnmatch(rel, pat) for pat in FIXED_LAYOUT)


def dart_files() -> list[Path]:
    out = []
    for path in sorted(LIB.rglob("*.dart")):
        rel = path.relative_to(ROOT).as_posix()
        if rel.endswith(".g.dart") or is_skipped(rel):
            continue
        out.append(path)
    return out


def count_source(path: Path) -> dict[str, int]:
    src = path.read_text(encoding="utf-8", errors="ignore")
    out: dict[str, int] = {}
    for key, rx in PATTERNS.items():
        if key == "blur10":
            out[key] = sum(1 for m in rx.finditer(src) if float(m.group(1)) >= 10)
        else:
            out[key] = len(rx.findall(src))
    return out


def collect() -> tuple[dict[str, int], dict[str, int], dict[str, int]]:
    """(non-allowlisted counts, allowlisted counts, informational counters)."""
    checked = {k: 0 for k in LABELS}
    allowed = {k: 0 for k in LABELS}
    info = {
        "dart_files": 0,
        "screen_files": 0,
        "widget_files": 0,
        "kit_imports": 0,
        "time_theme_imports": 0,
        "appcolors_files": 0,
        "sheet_sites": 0,
        "dialog_sites": 0,
        "routes": 0,
        "golden_pngs": 0,
        "fixed_layout_sizes": 0,
        "fixed_layout_files": 0,
    }

    for path in dart_files():
        rel = path.relative_to(ROOT).as_posix()
        counts = count_source(path)
        if is_fixed_layout(rel):
            # only the size marker is exempt; colours still belong to a palette
            info["fixed_layout_sizes"] += counts["raw_size"]
            if counts["raw_size"]:
                info["fixed_layout_files"] += 1
            counts = dict(counts, raw_size=0)
        target = allowed if is_allowed(rel) else checked
        for key in LABELS:
            target[key] += counts[key]
        info["dart_files"] += 1
        if "/screens/" in rel:
            info["screen_files"] += 1
        if "/widgets/" in rel:
            info["widget_files"] += 1
        if counts["kit_import"]:
            info["kit_imports"] += 1
        if counts["time_theme"]:
            info["time_theme_imports"] += 1
        if counts["appcolors"]:
            info["appcolors_files"] += 1
        info["sheet_sites"] += len(
            re.findall(r"showModalBottomSheet\(", path.read_text(
                encoding="utf-8", errors="ignore"))
        )
        info["dialog_sites"] += len(
            re.findall(r"showDialog\(", path.read_text(
                encoding="utf-8", errors="ignore"))
        )

    router = LIB / "app" / "router" / "app_router.dart"
    if router.exists():
        info["routes"] = len(
            re.findall(r"path:\s*RouteNames", router.read_text(
                encoding="utf-8", errors="ignore"))
        )

    info["golden_pngs"] = sum(
        1 for p in TEST.rglob("*.png") if "failures" not in p.parts
    )
    return checked, allowed, info


def top_offenders(key: str, limit: int = 10) -> list[tuple[int, str]]:
    rows = []
    for path in dart_files():
        rel = path.relative_to(ROOT).as_posix()
        if is_allowed(rel):
            continue
        n = count_source(path)[key]
        if n:
            rows.append((n, rel))
    rows.sort(reverse=True)
    return rows[:limit]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--report", action="store_true",
                    help="print the table and exit 0 even if a budget is blown")
    ap.add_argument("--budgets", action="store_true",
                    help="print a BUDGETS snippet for the measured counts")
    args = ap.parse_args()

    checked, allowed, info = collect()

    if args.budgets:
        print("BUDGETS = {")
        for key in LABELS:
            print(f'    "{key}": {checked[key]},')
        print("}")
        print("APPDEFAULTS = {")
        for key, value in APPDEFAULTS.items():
            print(f'    "{key}": {info[key]},')
        print("}")
        return 0

    print("design-consistency marker table (docs/FINAL/00_..._COVERAGE.md §0)")
    print("-" * 72)
    # The `00` §0 marker command scans `*/screens/*` only; reproduce that
    # scope so the two numbers can be compared directly.
    screens_color = screens_size = screens = 0
    for path in dart_files():
        rel = path.relative_to(ROOT).as_posix()
        if "/screens/" not in rel or is_allowed(rel):
            continue
        screens += 1
        counts = count_source(path)
        if counts["raw_color"]:
            screens_color += counts["raw_color"]
        if counts["raw_size"]:
            screens_size += counts["raw_size"]
    print(f"  screens-only scope ({screens} files): "
          f"raw_color={screens_color}  raw_size={screens_size}")
    print("-" * 72)
    for key, label in LABELS.items():
        print(f"  {key:9} checked={checked[key]:5}   allowlisted={allowed[key]:5}"
              f"   budget={BUDGETS.get(key, 0):5}   {label}")
    print("-" * 72)
    print(f"  fixed-layout raw sizes (informational): {info['fixed_layout_sizes']}"
          f" in {info['fixed_layout_files']} PDF/painter files")
    print("-" * 72)
    for key in ("dart_files", "screen_files", "widget_files", "routes",
                "kit_imports", "time_theme_imports", "appcolors_files",
                "sheet_sites", "dialog_sites", "golden_pngs"):
        print(f"  {key:20} {info[key]}")
    print("-" * 72)

    failures = []
    shrunk = []
    for key in LABELS:
        budget = BUDGETS.get(key, 0)
        if checked[key] > budget:
            failures.append((key, checked[key], budget))
        elif checked[key] < budget:
            shrunk.append((key, checked[key], budget))

    if shrunk:
        print("lower these budgets (the ratchet only turns one way):")
        for key, got, budget in shrunk:
            print(f"  {key}: {budget} -> {got}")

    if failures:
        print("FAIL — growth outside the allowlist:")
        for key, got, budget in failures:
            print(f"  {key}: {got} > budget {budget}")
            for n, rel in top_offenders(key):
                print(f"      {n:4}  {rel}")
        return 0 if args.report else 1

    print("OK — no non-allowlisted design-consistency count above budget.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

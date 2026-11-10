#!/usr/bin/env python3
"""quality_check.py — phase-2 quality gates for the Tawheed codebase.

Report-only by default (exit 0); pass --strict to fail (exit 1) when a
threshold is breached, so CI can adopt gates gradually.

Checks (each maps to a phase-2 audit finding):
  1. silent catches in lib/            (no AppLogger in the catch body)
  2. bang-operator map/regex lookups   (`...]!`) outside allowed paths
  3. providers declared inside screen/ widget files (must live in providers/)
  4. duplicated share-footer literals  ('— برنامه توحید' not via ShareService)
  5. leftover Color.lerp(...)!         (null-assert on a nullable API)
  6. analysis lock                     (use_build_context_synchronously: error)
  7. bundled asset size budget         (L5: pubspec-declared assets <= 14MB)
  8. widget wiring                     (manifest receiver <-> class <-> provider xml <-> glance dep)
  9. bare failure surfaces             (error branch / page body that is one sentence)
 10. exception in user-facing copy     (`': $e'` outside a log call)
 11. amounts glued to a currency word  (needs NumberFormat/formatMoney)
 12. raw amount in a money screen     (`${amount.round()}` with no grouping)
 12. currency saved outside settings   (`CurrencyStore.*.save` in a tool)

Usage:
  python3 tools/quality_check.py           # report, always exit 0
  python3 tools/quality_check.py --strict  # exit 1 on any threshold breach
"""
from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "lib"

# Paths where the pattern is explicitly allowed (documented exceptions).
BANG_ALLOWED = {
    "lib/core/database",  # drift generated column accessors are non-null
    "lib/core/utils",
}
PROVIDER_SCREEN_DIRS = ("presentation/screens", "presentation/widgets")

# Files allowed to render a failure sentence without the shared panel.
#
# The teacher screens are untracked work from a parallel session: they are
# routed but not committed, so editing them here would mean committing someone
# else's half-finished feature. Delete these five lines the moment they land —
# they are the same defect, in the newest code, and the panel is one call away.
BARE_FAILURE_ALLOWED: set[str] = {
    "lib/features/personal2/teacher/presentation/screens/class_management_screen.dart",
    "lib/features/personal2/teacher/presentation/screens/lesson_sheet_screen.dart",
    "lib/features/personal2/teacher/presentation/screens/parent_report_screen.dart",
    "lib/features/personal2/teacher/presentation/screens/student_profile_screen.dart",
    "lib/features/personal2/teacher/presentation/screens/teacher_home_screen.dart",
}

# Thresholds (strict mode). Zero-debt baseline (2026-09, phase-2 audit):
# batch 2 de-silenced 176 catches and eliminated every true `]!` bang;
# batch 3 covered the remaining 118 catches (AppLogger) plus 4 documented
# comment-skip cases (admin_web = dart:io web build, day_journal_entry =
# domain purity). The gate is now "no new debt at all": re-introducing a
# silent catch or a `]!` bang fails --strict immediately.
THRESHOLDS = {
    "silent_catch": 0,
    "bang_index": 0,
    "provider_in_screen": 0,
    "footer_literal": 0,
    "lerp_bang": 0,
    "context_lint_lock": 0,
    "asset_budget": 0,
    "widget_integrity": 0,
    "bare_failure": 0,
    "exception_in_copy": 0,
    "currency_writer": 0,
    "raw_money": 0,
    "money_file_grouping": 0,
}

# L5 asset diet (2026-09): bundled-APK asset budget. Baseline after the
# phase-7 asset cleanup is 13.2MB (see doc/AUDIT_2026-09.md); the 14MB limit
# leaves ~0.8MB headroom. Only files actually declared in pubspec.yaml count
# toward the budget (download-on-demand DBs like hadith.db/books_data are
# excluded automatically because they are not listed). Anything that grows
# the APK must shrink elsewhere or bump the budget with justification.
ASSET_BUDGET_MB = 14.0


def dart_files():
    yield from sorted(LIB.rglob("*.dart"))


def _match_braces(text: str, open_at: int) -> int:
    """Index just past the `}` that closes the `{` at [open_at].

    Braces inside string literals and comments are skipped, so a `{` in a
    Persian message no longer truncates the body the way a regex did.
    """
    depth = 0
    i = open_at
    n = len(text)
    while i < n:
        c = text[i]
        if c in ("'", '"'):
            quote = c * 3 if text[i : i + 3] == c * 3 else c
            i += len(quote)
            while i < n:
                if text[i] == "\\":
                    i += 2
                    continue
                if text.startswith(quote, i):
                    i += len(quote)
                    break
                i += 1
            continue
        if text.startswith("//", i):
            nl = text.find("\n", i)
            i = n if nl == -1 else nl
            continue
        if text.startswith("/*", i):
            end = text.find("*/", i)
            i = n if end == -1 else end + 2
            continue
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    return n


def _catch_bodies(text: str):
    """Yield `(offset, body)` for every `catch` block, innermost included."""
    for m in re.finditer(r"catch\s*(?:\([^()]*\))?\s*\{", text):
        end = _match_braces(text, m.end() - 1)
        yield m.start(), text[m.end() : end - 1]


def check_silent_catch() -> list[str]:
    """`catch` blocks that swallow the error without logging it.

    A body that rethrows (or converts the error into another `throw`) is not
    silent — the failure reaches the caller — and a body whose first statement
    is a comment is a documented skip.
    """
    hits = []
    for f in dart_files():
        rel = f.relative_to(ROOT).as_posix()
        text = f.read_text(encoding="utf-8", errors="replace")
        for start, body in _catch_bodies(text):
            stripped = body.strip()
            if (
                "AppLogger" in body
                or re.search(r"\b(rethrow|throw)\b", body)
                or stripped.startswith("//")
            ):
                continue
            line = text.count("\n", 0, start) + 1
            hits.append(f"{rel}:{line}")
    return hits


def check_bang_index() -> list[str]:
    hits = []
    for f in dart_files():
        rel = f.relative_to(ROOT).as_posix()
        if any(rel.startswith(p) for p in BANG_ALLOWED):
            continue
        for i, line in enumerate(
            f.read_text(encoding="utf-8", errors="replace").splitlines(), 1
        ):
            if re.search(r"\]\s*!(?!=)", line) and "flutter" not in line:
                hits.append(f"{rel}:{i}")
    return hits


def check_provider_in_screen() -> list[str]:
    hits = []
    pat = re.compile(
        r"^(?:final\s+\w+Provider\s*=|@riverpod|@Riverpod)", re.M
    )
    for f in dart_files():
        rel = f.relative_to(ROOT).as_posix()
        if not any(d in rel for d in PROVIDER_SCREEN_DIRS):
            continue
        if rel.endswith("_test.dart"):
            continue
        text = f.read_text(encoding="utf-8", errors="replace")
        for m in pat.finditer(text):
            line = text.count("\n", 0, m.start()) + 1
            hits.append(f"{rel}:{line}")
    return hits


def check_footer_literal() -> list[str]:
    hits = []
    for f in dart_files():
        rel = f.relative_to(ROOT).as_posix()
        if "share_service.dart" in rel:
            continue
        for i, line in enumerate(
            f.read_text(encoding="utf-8", errors="replace").splitlines(), 1
        ):
            if "— برنامه توحید" in line and "appLine" not in line:
                hits.append(f"{rel}:{i}")
    return hits


def check_lerp_bang() -> list[str]:
    hits = []
    pat = re.compile(r"Color\.lerp\([^;]*\)!")
    for f in dart_files():
        rel = f.relative_to(ROOT).as_posix()
        text = f.read_text(encoding="utf-8", errors="replace")
        for m in pat.finditer(text):
            line = text.count("\n", 0, m.start()) + 1
            hits.append(f"{rel}:{line}")
    return hits


def check_bare_failure() -> list[str]:
    """Failure surfaces that are a bare sentence instead of a panel.

    `FailureView` owns the failure panel: a stable key, a title that names what
    failed, a sentence about what was *not* lost, and a retry. The 34 panels it
    replaced had drifted on eight properties, and the drift survived because
    none of them was findable by key — the only way to test one was to match
    Persian prose, so nobody did.

    Two shapes slip past the component and are caught here:

    * `error: (e, _) => Text('…')` — an error branch that renders a literal and
      offers no way forward. The reader is told something went wrong and is
      left standing there.
    * `Center(child: Text('…ممکن نشد'))` — the same thing one level up, where
      the failure *is* the page body.

    A snackbar is not a panel and is not matched: a failed tap is answered in
    place, and the retry is the tap itself.
    """
    pats = [
        re.compile(
            r"error:\s*\([^)]*\)\s*=>\s*(?:const\s+)?"
            r"(?:Center\(\s*child:\s*)?Text\("
        ),
        re.compile(
            r"Center\(\s*child:\s*(?:Padding\([^;]{0,120}?child:\s*)?Text\(\s*"
            r"'[^']*(?:ممکن نشد|خوانده نشد|بارگذاری نشد|دریافت نشد|ناموفق بود)"
        ),
    ]
    hits: list[str] = []
    seen: set[str] = set()
    for f in dart_files():
        rel = f.relative_to(ROOT).as_posix()
        if rel in BARE_FAILURE_ALLOWED:
            continue
        text = f.read_text(encoding="utf-8", errors="replace")
        for pat in pats:
            for m in pat.finditer(text):
                hit = f"{rel}:{text.count(chr(10), 0, m.start()) + 1}"
                if hit not in seen:
                    seen.add(hit)
                    hits.append(hit)
    return hits


def check_exception_in_copy() -> list[str]:
    """A user-facing string that interpolates the thrown object.

    `'خطا در بارگذاری: $e'` is not an error message; it is a fragment of a
    stack trace shown to someone who cannot act on it. The exception already
    reaches `AppLogger` at the catch site, and `FailureView(error: …)` shows it
    in debug builds. Anything else is noise in the reader's face.
    """
    hits = []
    # Only lines that both build UI copy *and* interpolate the exception. A log
    # call's message is the same string but never reaches a reader; excluding it
    # by token would miss `AppLogger.e(` whose message sits on the next line.
    sinks = ("Text(", "SnackBar", "showSnackBar", "_showMessage(", "AppSnackBar.")
    pat = re.compile(r"['\"][^'\"]{0,80}[:：]\s*\$\{?(?:e|error|_error|err)\b")
    # The same string parked in the field the screen renders is the same defect
    # one step removed: `_error = 'خطا: $e'` reaches the reader as surely as
    # `Text('خطا: $e')` does, and greps for the latter miss it entirely.
    field_pat = re.compile(
        r"(?:_?error(?:Message)?|_message)\s*[:=]\s*['\"][^'\"]{0,80}"
        r"[:：]\s*\$\{?(?:e|error|_error|err)\b"
    )
    for f in dart_files():
        rel = f.relative_to(ROOT).as_posix()
        for i, line in enumerate(
            f.read_text(encoding="utf-8", errors="replace").splitlines(), 1
        ):
            if field_pat.search(line) or (
                any(tok in line for tok in sinks) and pat.search(line)
            ):
                hits.append(f"{rel}:{i}")
    return hits


def check_context_lint_lock() -> list[str]:
    """`use_build_context_synchronously` must stay escalated to `error`.

    Phase 6 promoted it from a CI-ignored `info` to a build-breaking error;
    this gate stops the promotion from being quietly reverted later.
    """
    path = ROOT / "analysis_options.yaml"
    text = path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""
    if re.search(
        r"^\s*use_build_context_synchronously:\s*error\s*$", text, re.M
    ):
        return []
    return [
        "analysis_options.yaml: use_build_context_synchronously must remain `error`"
    ]


def check_currency_writer() -> list[str]:
    """Only the settings screen may write a currency.

    Two stores exist — `CurrencyStore.calculators` (the calculators' scale) and
    `CurrencyStore.ledger` (the expense ledger's label) — and both are read all
    over the app. Writing them from inside a tool is what made «واحد پول» have
    several sources of truth: the report screen used to rewrite the
    calculators' unit from a dialog, so trying a figure in زکات changed the
    label of every recorded expense, and a reader could not tell which screen
    had changed their setting.

    The rule is now one writer: the «واحد حساب‌گرها» / «واحد دفتر هزینه‌ها» rows
    in `settings_screen.dart`. A tool that wants a different unit sends the
    reader there; it never saves one itself. This gate is what keeps the next
    well-meaning dialog from quietly re-opening the second door.
    """
    allowed = (
        ROOT / "lib" / "features" / "settings" / "presentation" / "pages"
        / "settings_screen.dart"
    ).resolve()
    pattern = re.compile(r"CurrencyStore\.(?:calculators|ledger)\.save\(")
    hits = []
    for f in dart_files():
        if f.resolve() == allowed:
            continue
        text = f.read_text(encoding="utf-8", errors="replace")
        for m in pattern.finditer(text):
            line = text.count("\n", 0, m.start()) + 1
            hits.append(f"{f.relative_to(ROOT).as_posix()}:{line}")
    return hits


# Currency words that make a number an AMOUNT a reader will try to read as
# money. «گرم»، «دقیقه» and friends are not here: a weight is not grouped.
CURRENCY_WORDS = (
    "افغانی",
    "افغانۍ",
    "ریال",
    "تومان",
    "دلار",
    "کلدار",
    "روپیه",
    "درهم",
    "دینار",
    "یورو",
)

# Anything that groups an amount before it is printed. If one of these sits in
# the same literal, the number reached the reader grouped and the literal is
# the correct shape.
MONEY_FORMATTERS = (
    "NumberFormat.",
    "formatMoney(",
    "formatPlain(",
    "formatToman(",
    "formatGram(",
    "groupDigits(",
    "grouped(",
)

# One string literal as Dart writes it, single- or double-quoted, without
# crossing a newline: a literal that wraps is read line by line anyway.
_STRING_LITERAL = re.compile(r"'([^'\\\n]|\\.)*'|\"([^\"\\\n]|\\.)*\"")

# The two shapes an amount is glued in: `'${total} افغانی'` and
# `'تومان $total'`. Only ADJACENT pairs count: «اگر دارایی‌تان دلار است … به
# $_unit تبدیل می‌شود» mentions a currency and interpolates a unit word, and
# flagging that prose is how a gate teaches people to ignore it.
_INTERPOLATION = r"(?:\$\{[^}]*\}|\$[A-Za-z_][A-Za-z0-9_.]*)"
_MONEY_WORD = "(" + "|".join(CURRENCY_WORDS) + ")"
_MONEY_GLUE = re.compile(
    _INTERPOLATION + r"\s*" + _MONEY_WORD + "|" + _MONEY_WORD + r"\s*" + _INTERPOLATION
)

# The expression inside each interpolation, so a rule can look at what is being
# converted to text rather than at the sentence around it.
_INTERPOLATED_EXPR = re.compile(r"\$\{([^}]*)\}|\$([A-Za-z_][A-Za-z0-9_.]*)")


def check_raw_money() -> list[str]:
    """An amount glued to a currency word without the grouping formatter.

    «$amount افغانی» prints 4200000 as a bare run of digits; the same figure
    through `NumberFormat.formatMoney` prints 4,200,000 افغانی. The thousand
    separator is a product rule (`number_format.dart` owns it), and it is the
    one rule that silently disappears whenever a new screen concatenates a
    unit by hand — so a literal that puts an interpolation next to a currency
    word must show one of the formatters in the same literal. Only string
    literals are read: a comment or a field name can mention a unit freely.
    """
    hits: list[str] = []
    for f in dart_files():
        rel = f.relative_to(ROOT).as_posix()
        for i, line in enumerate(
            f.read_text(encoding="utf-8", errors="replace").splitlines(), 1
        ):
            if "$" not in line or not any(w in line for w in CURRENCY_WORDS):
                continue
            for m in _STRING_LITERAL.finditer(line):
                literal = m.group(0)
                if "$" not in literal:
                    continue
                if any(tok in literal for tok in MONEY_FORMATTERS):
                    continue
                if _MONEY_GLUE.search(literal) is None:
                    continue
                hits.append(f"{rel}:{i}")
                break
    return hits


# The screens where a printed number IS money: a wallet, a debt, a price, a
# due zakat. Inside these files every rendered amount must reach the reader
# through the grouping formatter, whatever the sentence around it looks like —
# `'${amount.round()}'` in a money screen is 4200000 on the screen, and the
# adjacency rule above cannot see it because no currency word sits beside it.
MONEY_FILE_PREFIXES = (
    "lib/features/tools/zakat/",
    "lib/features/tools/inheritance/",
    "lib/features/expenses/presentation/",
    "lib/features/personal2/shop/presentation/",
    "lib/features/personal/family_faith/",
    "lib/features/personal/finance/",
    "lib/features/worship/kaffara/",
)

# How a raw number becomes a string. Each of these prints digits as they are;
# a money screen that interpolates one of them has skipped the separator.
RAW_NUMBER_CONVERSIONS = (
    ".round()",
    ".ceil()",
    ".floor()",
    ".toInt()",
    "toStringAsFixed(",
    "NumberFormat.en(",
)

# Only a rendered string counts. A text field's initial value must stay
# ungrouped (`NumberFormat.parse` strips separators, and a comma in an editable
# amount is a trap), so controller assignments are deliberately not sinks.
MONEY_TEXT_SINKS = (
    "Text(",
    "label:",
    "subtitle:",
    "title:",
    "valueText:",
    "pdfRow(",
    "value:",
)


def check_money_file_grouping() -> list[str]:
    """A raw numeric conversion printed in a money screen.

    The adjacency gate (`check_raw_money`) only sees an amount that already
    carries a currency word. A money screen often prints the figure alone — a
    list row, a chip, a PDF cell — and `'${amount.round()}'` there is exactly
    the ungrouped 4200000 the thousand-separator rule exists to prevent. The
    formatters are read from the same literal, so a value that went through
    `NumberFormat.grouped` / `formatMoney` / `groupDigits` passes regardless of
    how the sentence is built.
    """
    hits: list[str] = []
    for f in dart_files():
        rel = f.relative_to(ROOT).as_posix()
        if not rel.startswith(MONEY_FILE_PREFIXES):
            continue
        for i, line in enumerate(
            f.read_text(encoding="utf-8", errors="replace").splitlines(), 1
        ):
            if "$" not in line:
                continue
            if not any(sink in line for sink in MONEY_TEXT_SINKS):
                continue
            if _prints_raw_money(line):
                hits.append(f"{rel}:{i}")
    return hits


def _prints_raw_money(line: str) -> bool:
    """True when a rendered line interpolates a raw numeric conversion.

    Kept out of the file walk so the rule itself can be probed on synthetic
    lines without writing a fixture Dart file.
    """
    if "$" not in line:
        return False
    if not any(sink in line for sink in MONEY_TEXT_SINKS):
        return False
    for m in _STRING_LITERAL.finditer(line):
        literal = m.group(0)
        if "$" not in literal:
            continue
        # A percentage is not an amount: it never takes a thousands
        # separator, so «۳۰٪» is correct as it stands.
        if "%" in literal or "\u066a" in literal:
            continue
        if any(tok in literal for tok in MONEY_FORMATTERS):
            continue
        if any(
            any(tok in expr for tok in RAW_NUMBER_CONVERSIONS)
            for expr in _interpolated_expressions(literal)
        ):
            return True
    return False


def _interpolated_expressions(literal: str) -> list[str]:
    """The `$name` / `${expr}` bodies inside one string literal.

    `findall` returns one tuple per match because the pattern has two groups;
    comparing a token against the tuple would only ever test whole-string
    equality, so the groups are flattened here once.
    """
    return [g1 or g2 for g1, g2 in _INTERPOLATED_EXPR.findall(literal)]


def check_asset_budget() -> list[str]:
    """L5 asset diet: bundled assets must stay under ASSET_BUDGET_MB.

    Budget entries are parsed live from pubspec.yaml so the gate can never
    drift from what actually ships: every `- assets/...` line contributes
    its on-disk size (directories contribute the sum of their files).
    Unbundled on-demand downloads (hadith.db, hadeeth_enc.db, library
    books) are excluded by design because they are not declared.
    """
    pubspec = ROOT / "pubspec.yaml"
    if not pubspec.exists():
        return ["pubspec.yaml: not found"]
    text = pubspec.read_text(encoding="utf-8", errors="replace")
    # Section = `assets:` header plus consecutive list/comment lines (comments
    # are legal between entries and must not terminate the capture).
    section = re.search(
        r"^[ \t]*assets:[ \t]*$(?:\r?\n[ \t]+(?:-[ \t]+|#).*$)+", text, re.M
    )
    if not section:
        return ["pubspec.yaml: no `assets:` section found"]

    entries = re.findall(
        r"^[ \t]+-[ \t]+(assets/\S+?)[ \t]*$", section.group(0), re.M
    )
    total = 0
    hits: list[str] = []
    for entry in entries:
        path = ROOT / entry
        if not path.exists():
            hits.append(f"{entry}: declared in pubspec but MISSING on disk")
            continue
        if path.is_dir():
            size = sum(p.stat().st_size for p in path.rglob("*") if p.is_file())
        else:
            size = path.stat().st_size
        total += size

    limit = int(ASSET_BUDGET_MB * 1024 * 1024)
    if total > limit:
        hits.append(
            f"bundled assets total {total / 1048576:.2f}MB > budget "
            f"{ASSET_BUDGET_MB:g}MB - shrink assets or raise ASSET_BUDGET_MB "
            "with justification"
        )
    return hits


def _strip_kotlin_comments(text: str) -> str:
    """Drop // and /* */ comments before a symbol scan.

    These scans look for CALLS, and the repo's own KDoc records what was
    retired (the live-leaves migration note names `AndroidRemoteViews`, and
    WidgetArt's doc names the Glance providers it replaced). Read literally,
    that prose looks like usage and fails the gate for a file that contains no
    such call — so every architecture scan reads comment-stripped text, the
    same idiom the Dart guards use.
    """
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return re.sub(r"//[^\n]*", "", text)


def _kotlin_parent_class(cls: str, kotlin_root: Path) -> str | None:
    """The superclass [cls] declares, or None when the file does not say."""
    files = list(kotlin_root.rglob(f"{cls}.kt"))
    if not files:
        return None
    src = files[0].read_text(encoding="utf-8", errors="replace")
    m = re.search(rf"\bclass\s+{re.escape(cls)}\b[^\n:]*:\s*([A-Za-z0-9_.]+)", src)
    return m.group(1).rsplit(".", 1)[-1] if m else None


def _is_widget_provider(cls: str, kotlin_root: Path) -> bool:
    """True when [cls] is, or inherits from, an Android widget provider.

    The manifest registers a concrete class, and a zero-override subclass of a
    provider is still a provider (PrayerWidgetVertical is PrayerWidget under
    its own component name). Demanding the literal `: AppWidgetProvider` on the
    subclass itself would reject the only way Android lets two placeable
    widgets share one renderer, so the chain is followed instead.
    """
    providers = {"GlanceAppWidgetReceiver", "AppWidgetProvider"}
    seen: set[str] = set()
    current: str | None = cls
    while current and current not in seen:
        if current in providers:
            return True
        seen.add(current)
        current = _kotlin_parent_class(current, kotlin_root)
    return False


def check_widget_integrity() -> list[str]:
    """Widget wiring: manifest receiver <-> class <-> provider xml <-> Glance dep.

    Added after the 2026-10-24 widget outage: a home-screen widget can die
    silently at runtime (the launcher swaps in its «couldn't load widget»
    view) while every Dart/Gradle check stays green. The statically
    provable wiring is locked here so a rename, a deleted class or a
    dependency drift fails --strict instead of failing on someone's
    launcher:

      * every manifest receiver carrying an appwidget-provider meta-data
        resolves to a real receiver class file,
      * that class extends GlanceAppWidgetReceiver / AppWidgetProvider and
        the receiver declares the APPWIDGET_UPDATE intent-filter,
      * its @xml provider info exists, carries android:initialLayout, and
        that layout exists,
      * updatePeriodMillis stays 0 (the no-OS-polling widget spec),
      * androidx.glance is declared in build.gradle.kts if and only if a
        widget source actually imports it.

    It also pins the architecture invariants that replaced the two blanket
    bans of 2026-10-24/25 (both were written from one MIUI device and locked
    the project out of the only design that keeps a clock exact without
    polling):

      * a live `AndroidRemoteViews` leaf exists ONLY in
        `WidgetLiveLeaves.kt`, behind `WidgetPrefs.KEY_LIVE_LEAVES`, so one
        hostile host cannot blank the card forever;
      * no `actionRunCallback` — the tasbih card taps through an explicit
        broadcast to its own receiver, and the activity trampoline stays
        registered as the opt-in fallback;
      * the prayer card's minute tick still exists AND is gated on the live
        leaves flag — ungated it would poll 1440 times a day for a clock that
        ticks itself;
      * `provideGlance` never runs the astronomical solver.
    """
    hits: list[str] = []
    manifest = ROOT / "android/app/src/main/AndroidManifest.xml"
    if not manifest.exists():
        return ["android/app/src/main/AndroidManifest.xml: not found"]
    text = manifest.read_text(encoding="utf-8", errors="replace")
    kotlin_root = ROOT / "android/app/src/main/kotlin"
    widget_sources = (
        sorted(kotlin_root.rglob("widget/*.kt")) if kotlin_root.exists() else []
    )

    receivers = re.findall(r"<receiver\b.*?</receiver>", text, re.S)
    widget_receivers = [r for r in receivers if "android.appwidget.provider" in r]
    if not widget_receivers:
        hits.append("AndroidManifest.xml: no appwidget-provider receivers found")

    for block in widget_receivers:
        open_tag = block.split(">", 1)[0]
        name_m = re.search(r'android:name="([^"]+)"', open_tag)
        res_m = re.search(r'android:resource="@xml/([\w.-]+)"', block)
        label = name_m.group(1) if name_m else "<unnamed receiver>"
        if "android.appwidget.action.APPWIDGET_UPDATE" not in block:
            hits.append(
                f"AndroidManifest.xml: {label} lacks the APPWIDGET_UPDATE intent-filter"
            )
        if not name_m:
            hits.append("AndroidManifest.xml: appwidget receiver without android:name")
            continue
        cls = name_m.group(1).rsplit(".", 1)[-1]
        class_files = list(kotlin_root.rglob(f"{cls}.kt"))
        if not class_files:
            hits.append(f"AndroidManifest.xml: {label} has no matching {cls}.kt")
        elif not _is_widget_provider(cls, kotlin_root):
            hits.append(
                f"{cls}.kt: {cls} must extend GlanceAppWidgetReceiver "
                "or AppWidgetProvider"
            )
        if not res_m:
            hits.append(
                f"AndroidManifest.xml: {label} lacks an @xml appwidget-provider "
                "meta-data"
            )
            continue
        info = ROOT / "android/app/src/main/res/xml" / f"{res_m.group(1)}.xml"
        if not info.exists():
            hits.append(f"missing provider info: res/xml/{res_m.group(1)}.xml")
            continue
        info_text = info.read_text(encoding="utf-8", errors="replace")
        layout_m = re.search(
            r'android:initialLayout="@layout/([\w.-]+)"', info_text
        )
        if not layout_m:
            hits.append(f"{info.name}: android:initialLayout missing")
        else:
            layout = (
                ROOT / "android/app/src/main/res/layout" / f"{layout_m.group(1)}.xml"
            )
            if not layout.exists():
                hits.append(
                    f"{info.name}: initialLayout {layout_m.group(1)}.xml missing "
                    "from res/layout"
                )
        period = re.search(r'android:updatePeriodMillis="(\d+)"', info_text)
        if period and period.group(1) != "0":
            hits.append(
                f"{info.name}: updatePeriodMillis={period.group(1)} violates "
                "the no-OS-polling widget spec (must be 0)"
            )

    gradle = ROOT / "android/app/build.gradle.kts"
    gradle_text = (
        gradle.read_text(encoding="utf-8", errors="replace") if gradle.exists() else ""
    )
    uses_glance = any(
        "import androidx.glance" in p.read_text(encoding="utf-8", errors="replace")
        for p in widget_sources
    )
    has_dep = "androidx.glance:glance-appwidget" in gradle_text
    if uses_glance and not has_dep:
        hits.append(
            "android/app/build.gradle.kts: widget sources import androidx.glance "
            "but glance-appwidget is not declared"
        )
    if has_dep and not uses_glance:
        hits.append(
            "android/app/build.gradle.kts: glance-appwidget declared but no widget "
            "source imports androidx.glance (leftover dependency)"
        )

    # ── Architecture invariants (rebuilt 2026-10-26) ──
    #
    # The two bans that used to live here («never AndroidRemoteViews», «never a
    # broadcast tap») were written from a single MIUI device and they locked the
    # project out of the only architecture that can keep a clock exact without
    # polling. They are now *containment* rules instead of bans: exactly one
    # file may embed a live RemoteViews, and it must sit behind a capability
    # flag with a fallback, so one hostile host can never blank the card forever.
    live_gateway = "widget/WidgetLiveLeaves.kt"
    for p in widget_sources:
        rel = p.relative_to(ROOT).as_posix()
        src = _strip_kotlin_comments(
            p.read_text(encoding="utf-8", errors="replace")
        )
        if "AndroidRemoteViews" in src and not rel.endswith(live_gateway):
            hits.append(
                f"{rel}: embeds a live RemoteViews directly — route it through "
                f"{live_gateway} so the capability flag and the fallback stay in "
                "one place"
            )
        if "actionRunCallback" in src:
            hits.append(
                f"{rel}: actionRunCallback needs the ActionCallbackReceiver "
                "service; tasbih taps use an explicit broadcast to the widget "
                "receiver instead"
            )

    gateway = kotlin_root / "widget" / "WidgetLiveLeaves.kt"
    if gateway.exists():
        gateway_text = gateway.read_text(encoding="utf-8", errors="replace")
        prefs_src = (kotlin_root / "widget" / "WidgetPrefs.kt")
        prefs_text = (
            prefs_src.read_text(encoding="utf-8", errors="replace")
            if prefs_src.exists()
            else ""
        )
        if "KEY_LIVE_LEAVES" not in prefs_text:
            hits.append(
                "WidgetPrefs.kt: the live-leaves capability flag is missing — a "
                "host that refuses a nested RemoteViews would blank the widget "
                "with no way back"
            )
        if "AndroidRemoteViews" in gateway_text and "KEY_LIVE_LEAVES" not in gateway_text:
            hits.append(
                f"{live_gateway}: embeds a live RemoteViews without documenting "
                "the capability flag it is gated by"
            )

    if "TasbihActionActivity" not in text:
        hits.append(
            "AndroidManifest.xml: the tasbih tap fallback is not registered — "
            "the delivery switch would have nothing to switch to"
        )

    # The tap path must be a broadcast by default: an activity costs a window,
    # an activity record and a lifecycle, which is most of a cold start.
    tasbih_widget = kotlin_root / "widget" / "TasbihGlanceWidget.kt"
    if tasbih_widget.exists():
        tasbih_text = tasbih_widget.read_text(encoding="utf-8", errors="replace")
        if "actionSendBroadcast" not in tasbih_text:
            hits.append(
                "TasbihGlanceWidget.kt: taps are no longer a broadcast — an "
                "activity trampoline per bead was the 30-second report"
            )
        if "useActivityTaps" not in tasbih_text:
            hits.append(
                "TasbihGlanceWidget.kt: the activity fallback is not gated by "
                "WidgetPrefs.useActivityTaps"
            )

    prayer = kotlin_root / "widget" / "PrayerWidget.kt"
    if prayer.exists():
        prayer_text = prayer.read_text(encoding="utf-8", errors="replace")
        # The minute tick is now the FALLBACK for a host without live leaves,
        # so it must (a) still exist and (b) be gated on that flag. An ungated
        # minute tick is 1440 wake-ups a day for a clock that ticks itself.
        if (
            "setInexactRepeating" not in prayer_text
            or "MINUTE_BACKSTOP_REQUEST_CODE" not in prayer_text
        ):
            hits.append(
                "android/app/src/main/kotlin/com/islamic/tawheeed/widget/"
                "PrayerWidget.kt: the minute tick lost its REPEATING backstop — "
                "a re-armed one-shot alarm chain dies with its first dropped "
                "delivery and the clock silently lags"
            )
        if "WidgetPrefs.liveLeaves" not in prayer_text:
            hits.append(
                "PrayerWidget.kt: the minute tick is no longer gated on "
                "WidgetPrefs.liveLeaves — it would poll every minute even when "
                "the clock ticks itself"
            )
        # The flag is only a fallback if the OFF branch renders a clock. A flag
        # that silently paints nothing is worse than no flag: the card would
        # lose its clock on exactly the hosts that needed the fallback.
        native_views = kotlin_root / "widget" / "PrayerNativeViews.kt"
        baked_layout = ROOT / "android/app/src/main/res/layout/widget_prayer_clock_baked.xml"
        if native_views.exists():
            native_text = native_views.read_text(encoding="utf-8", errors="replace")
            if "PrayerRemoteLeaves.enabled(" in native_text:
                if "widget_prayer_clock_baked" not in native_text:
                    hits.append(
                        "PrayerNativeViews.kt: the live clock leaf is gated but "
                        "no baked fallback is charged into the slot — a host "
                        "that refuses the leaf would show an empty box"
                    )
                elif not baked_layout.exists():
                    hits.append(
                        "android/app/src/main/res/layout/"
                        "widget_prayer_clock_baked.xml: the baked clock layout is "
                        "referenced but missing"
                    )
        # No heavy work in the render path.
        glance_widget = kotlin_root / "widget" / "PrayerGlanceWidget.kt"
        if glance_widget.exists():
            glance_text = glance_widget.read_text(encoding="utf-8", errors="replace")
            if "recomputeTimesIfStale" in glance_text:
                hits.append(
                    "PrayerGlanceWidget.kt: provideGlance runs the astronomical "
                    "solver — the render must be a pure read"
                )
    return hits


CHECKS = [
    ("silent_catch", "silent catches without AppLogger", check_silent_catch),
    ("bang_index", "`]!` index lookups", check_bang_index),
    (
        "provider_in_screen",
        "providers declared in screen/widget files",
        check_provider_in_screen,
    ),
    (
        "footer_literal",
        "hardcoded share footers (use ShareService.appLine)",
        check_footer_literal,
    ),
    ("lerp_bang", "Color.lerp(...)! null-assertions", check_lerp_bang),
    (
        "context_lint_lock",
        "use_build_context_synchronously locked at error",
        check_context_lint_lock,
    ),
    (
        "asset_budget",
        f"bundled asset size (pubspec-declared) <= {ASSET_BUDGET_MB:g}MB",
        check_asset_budget,
    ),
    (
        "widget_integrity",
        "widget wiring (receiver/class/provider xml/glance dep)",
        check_widget_integrity,
    ),
    (
        "bare_failure",
        "failure surfaces that are one sentence (use FailureView)",
        check_bare_failure,
    ),
    (
        "exception_in_copy",
        "exceptions interpolated into user-facing copy",
        check_exception_in_copy,
    ),
    (
        "currency_writer",
        "currency saved outside the settings screen",
        check_currency_writer,
    ),
    (
        "raw_money",
        "amounts glued to a currency word without grouping",
        check_raw_money,
    ),
    (
        "money_file_grouping",
        "raw amount printed in a money screen (needs grouping)",
        check_money_file_grouping,
    ),
]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--strict",
        action="store_true",
        help="exit 1 when a threshold is breached",
    )
    args = parser.parse_args()

    failed = False
    print("=== Tawheed quality check ===")
    for key, title, fn in CHECKS:
        hits = fn()
        limit = THRESHOLDS[key]
        status = "OK" if len(hits) <= limit else "OVER"
        if status == "OVER":
            failed = True
        print(f"[{status}] {title}: {len(hits)} (limit {limit})")
        for h in hits[:15]:
            print(f"        {h}")
        if len(hits) > 15:
            print(f"        ... and {len(hits) - 15} more")

    if failed and args.strict:
        print("\nSTRICT MODE: thresholds breached.")
        return 1
    if failed:
        print("\n(report-only: run with --strict to fail the build)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

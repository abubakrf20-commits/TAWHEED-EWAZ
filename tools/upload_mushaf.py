#!/usr/bin/env python3
"""Upload the built mushaf assets to the TAWHEED-EWAZ content repo.

Copies `tools/mushaf_build/` output into `TAWHEED-EWAZ/quran/`, verifies
completeness (604 WebP pages + mushaf.db + manifest.json), then commits and
pushes IN BATCHES of 100 pages (one commit + one push per batch) so a single
~150 MB push never times out or races other sessions.

Afterwards everything is downloadable from:
    https://raw.githubusercontent.com/abubakrf20-commits/TAWHEED-EWAZ/main/quran/

Usage:
    python tools/upload_mushaf.py            # verify + copy + batched commit/push
    python tools/upload_mushaf.py --no-push  # verify + copy + commits only
    python tools/upload_mushaf.py --check    # only verify build output
"""

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUILD_DIR = ROOT / "tools" / "mushaf_build"
REPO_DIR = ROOT / "TAWHEED-EWAZ"
DEST_DIR = REPO_DIR / "quran"

PAGE_COUNT = 604
BATCH_SIZE = 100


def run(cmd: list[str], cwd: Path | None = None, check: bool = True) -> subprocess.CompletedProcess:
    result = subprocess.run(
        cmd, cwd=cwd, capture_output=True, text=True, encoding="utf-8", errors="replace"
    )
    if check and result.returncode != 0:
        print(f"ERROR: {' '.join(cmd)}\n{result.stdout}\n{result.stderr}", file=sys.stderr)
        sys.exit(result.returncode)
    return result


def verify_source() -> None:
    pages = BUILD_DIR / "pages"
    missing = [
        f"{i:03d}.webp"
        for i in range(1, PAGE_COUNT + 1)
        if not (pages / f"{i:03d}.webp").is_file()
    ]
    if missing:
        print(f"ERROR: {len(missing)} page(s) missing from build output "
              f"(first: {missing[0]}). Run tools/build_mushaf.py first.", file=sys.stderr)
        sys.exit(1)
    for name in ("mushaf.db", "manifest.json"):
        if not (BUILD_DIR / name).is_file():
            print(f"ERROR: {name} missing from {BUILD_DIR}. Run tools/build_mushaf.py.",
                  file=sys.stderr)
            sys.exit(1)
    print(f"[ok] build output complete: {PAGE_COUNT} pages + mushaf.db + manifest.json")


def copy_files() -> None:
    dest_pages = DEST_DIR / "pages"
    dest_pages.mkdir(parents=True, exist_ok=True)
    copied = 0
    for i in range(1, PAGE_COUNT + 1):
        src = BUILD_DIR / "pages" / f"{i:03d}.webp"
        dst = dest_pages / f"{i:03d}.webp"
        if not dst.is_file() or dst.stat().st_size != src.stat().st_size:
            shutil.copy2(src, dst)
            copied += 1
    for name in ("mushaf.db", "manifest.json"):
        shutil.copy2(BUILD_DIR / name, DEST_DIR / name)
    print(f"[ok] copied {copied} new/changed page(s) + db + manifest -> {DEST_DIR}")


def current_branch() -> str:
    return run(["git", "rev-parse", "--abbrev-ref", "HEAD"], cwd=REPO_DIR).stdout.strip()


def push_with_retry(branch: str, attempts: int = 5) -> bool:
    """Push HEAD to origin/main; rebase over concurrent remote pushes."""
    for attempt in range(1, attempts + 1):
        run(["git", "fetch", "origin"], cwd=REPO_DIR, check=False)
        run(["git", "rebase", "origin/main"], cwd=REPO_DIR, check=False)
        result = run(["git", "push", "origin", f"{branch}:main"], cwd=REPO_DIR, check=False)
        if result.returncode == 0:
            return True
        print(f"    push rejected (attempt {attempt}/{attempts}) — retrying after sync")
    return False


def commit_and_push_batches(push: bool) -> None:
    branch = current_branch()

    # Batched pages: 001-100, 101-200, ... one commit (+ push) per batch.
    ranges = list(range(1, PAGE_COUNT + 1, BATCH_SIZE))
    for start in ranges:
        end = min(start + BATCH_SIZE - 1, PAGE_COUNT)
        paths = [str(DEST_DIR / "pages" / f"{i:03d}.webp") for i in range(start, end + 1)]
        run(["git", "add", *paths], cwd=REPO_DIR)
        status = run(["git", "status", "--porcelain", "--", f"quran/pages"],
                     cwd=REPO_DIR).stdout.strip()
        if not status:
            print(f"[skip] pages {start:03d}-{end:03d} already committed")
            continue
        run(["git", "commit", "-m", f"quran: mushaf pages {start:03d}-{end:03d}"],
            cwd=REPO_DIR)
        print(f"[ok] committed pages {start:03d}-{end:03d}")
        if push:
            if not push_with_retry(branch):
                print(f"ERROR: could not push pages {start:03d}-{end:03d}", file=sys.stderr)
                sys.exit(1)
            print(f"[ok] pushed pages {start:03d}-{end:03d}")

    # Database + manifest as their own small commit.
    run(["git", "add", str(DEST_DIR / "mushaf.db"), str(DEST_DIR / "manifest.json")],
        cwd=REPO_DIR)
    status = run(["git", "status", "--porcelain", "--",
                  "quran/mushaf.db", "quran/manifest.json"], cwd=REPO_DIR).stdout.strip()
    if status:
        try:
            version = json.loads((DEST_DIR / "manifest.json").read_text(
                encoding="utf-8")).get("version", "?")
        except Exception:
            version = "?"
        run(["git", "commit", "-m", f"quran: ayah bounds database + manifest v{version}"],
            cwd=REPO_DIR)
        print("[ok] committed mushaf.db + manifest.json")
        if push:
            if not push_with_retry(branch):
                print("ERROR: could not push db/manifest", file=sys.stderr)
                sys.exit(1)
            print("[ok] pushed mushaf.db + manifest.json")
    else:
        print("[skip] mushaf.db + manifest.json already committed")

    base = ("https://raw.githubusercontent.com/abubakrf20-commits/TAWHEED-EWAZ/"
            f"main/quran")
    print(f"\nAll done. The app fetches:")
    print(f"  {base}/pages/001.webp ... {base}/pages/604.webp")
    print(f"  {base}/mushaf.db")
    print(f"  {base}/manifest.json")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--no-push", action="store_true",
                        help="commit in batches but do not push")
    parser.add_argument("--check", action="store_true",
                        help="only verify build output, no copy/commit/push")
    args = parser.parse_args()

    if not (REPO_DIR / ".git").exists():
        print(f"ERROR: {REPO_DIR} is not a git repo.", file=sys.stderr)
        sys.exit(1)

    verify_source()
    if args.check:
        return
    copy_files()
    commit_and_push_batches(push=not args.no_push)


if __name__ == "__main__":
    main()

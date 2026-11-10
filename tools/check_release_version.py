#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Guard: compare the project's FROZEN versionCode against the code installed
on a connected device before a release build, so the "package appears invalid"
(INSTALL_FAILED_VERSION_DOWNGRADE) problem can never silently recur.

Why this exists
---------------
The phone carried versionCode 4007 / 1.5.2 while the repo's release branch had
2008 / 1.6.0 — two parallel version streams (a 2000-series used by the git
release branch, and a 4000-series produced by out-of-repo/OpenCode builds).
Trying to install the lower code produced INSTALL_FAILED_VERSION_DOWNGRADE,
which Android surfaces as "the package appears to be invalid".

Frozen numbering (decision 2026-10-17)
--------------------------------------
`pubspec.yaml`'s `+code` and any `--build-number` no longer take part. The ONE
number that ever moves is `FROZEN_VERSION_CODE` in
`android/app/build.gradle.kts`; it stays put through the whole development
cycle and is bumped by 1..10 only right before a publish. The universal APK
carries it verbatim; the ABI-split APKs carry it +1000 (armeabi-v7a) / +2000
(arm64-v8a), which is why a device may legitimately report a code up to 2000
above the frozen base.

Usage
-----
    python tools/check_release_version.py            # checks only
    python tools/check_release_version.py --fail     # exit(1) on downgrade
    python tools/check_release_version.py --fix      # bump FROZEN_VERSION_CODE by 1
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GRADLE = os.path.join(ROOT, "android", "app", "build.gradle.kts")
PACKAGE = "com.islamic.tawheeed"

# The highest code ever PUBLISHED to users: 1.7.1 = 2_000_010_013 (live
# app/update.json on TAWHEED-EWAZ). 1.7.0's direct build carried 2_000_004_000.
# Older out-of-repo installs carried tiny 4000/6000/8000-series codes.
PUBLISHED_FLOOR = 2_000_010_013
KNOWN_INSTALLED_CODES = {2003, 2005, 2006, 2007, 2008, 4007, 6009, 8010}

# The fixed offsets the ABI-split APKs add on top of the frozen base.
ABI_OFFSETS = (0, 1000, 2000)


def read_frozen_version_code() -> int | None:
    """The single source of truth: FROZEN_VERSION_CODE in build.gradle.kts."""
    text = open(GRADLE, encoding="utf-8").read()
    m = re.search(r"val FROZEN_VERSION_CODE\s*=\s*([\d_]+)", text)
    if not m:
        return None
    return int(m.group(1).replace("_", ""))


def adb() -> str | None:
    sdk = os.environ.get("LOCALAPPDATA", r"C:\Users\abubakr\AppData\Local")
    for cand in (
        os.path.join(sdk, "Android", "Sdk", "platform-tools", "adb.exe"),
        os.path.join(sdk, "Android", "sdk", "platform-tools", "adb.exe"),
        "adb",
    ):
        if cand == "adb" or os.path.exists(cand):
            return cand
    return None


def device_version_code(adb_path: str) -> int | None:
    try:
        out = subprocess.run(
            [adb_path, "shell", "cmd", "package", "list", "packages",
             "--show-versioncode", PACKAGE],
            capture_output=True, text=True, timeout=20,
        ).stdout
    except (subprocess.SubprocessError, OSError):
        return None
    m = re.search(r"versionCode:(\d+)", out)
    return int(m.group(1)) if m else None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--fail", action="store_true",
                    help="exit(1) if the frozen code would downgrade the device")
    ap.add_argument("--fix", action="store_true",
                    help="bump FROZEN_VERSION_CODE by 1 (publish-time ritual)")
    args = ap.parse_args()

    frozen = read_frozen_version_code()
    if frozen is None:
        print("ERROR: no 'val FROZEN_VERSION_CODE = ...' found in "
              "android/app/build.gradle.kts")
        return 2

    floor = max(KNOWN_INSTALLED_CODES | {PUBLISHED_FLOOR})
    dev_code = None
    adb_path = adb()
    if adb_path:
        try:
            dev_code = device_version_code(adb_path)
        except Exception:
            pass

    print(f"project: FROZEN_VERSION_CODE={frozen}  "
          f"(universal APK; splits = +1000/+2000)")
    print(f"floor:   {floor}  (highest published / ever installed code)")

    risk = False
    if dev_code is None:
        print("device:  not connected / package not installed — using known floor")
        if frozen < floor:
            risk = True
    else:
        print(f"device:  {PACKAGE} versionCode={dev_code}  "
              f"(adb: {os.path.basename(adb_path)})")
        # Same numbering line if the device sits at the base or at an ABI
        # offset above it — those are the split APKs this same base produced.
        if dev_code in {frozen + off for off in ABI_OFFSETS}:
            print(f"OK: device {dev_code} is on the frozen line {frozen} — "
                  f"an APK at or above it installs in place.")
            return 0
        if dev_code > frozen:
            risk = True
            print(f"DOWNGRADE RISK: the universal APK ({frozen}) is BELOW the "
                  f"device ({dev_code}).")
            print("  → bump FROZEN_VERSION_CODE by 1..10 before publishing, or")
            print(f"  → install the arm64 split ({frozen + 2000}) / use "
                  f"`adb install -r -d` for a dev-only downgrade.")
        else:
            print(f"OK: {frozen} > device {dev_code} — installs over it.")
            return 0

    if not risk:
        if frozen >= floor:
            print(f"OK: {frozen} >= {floor} — safe to install over everything seen.")
            return 0
        print(f"DOWNGRADE RISK: project {frozen} < floor {floor}")
        risk = True

    if args.fix:
        new_code = frozen + 1
        text = open(GRADLE, encoding="utf-8").read()
        new_text, n = re.subn(
            r"val FROZEN_VERSION_CODE\s*=\s*[\d_]+",
            f"val FROZEN_VERSION_CODE = {new_code:_}",
            text, count=1,
        )
        if n == 1:
            open(GRADLE, "w", encoding="utf-8", newline="").write(new_text)
            print(f"bumped FROZEN_VERSION_CODE to {new_code}")
            print("REMINDER: update the expectation in "
                  "test/android/version_code_scheme_test.dart and the manifest "
                  "revision/versionCode in content/app/update.json together.")
            return 0
        print("ERROR: could not rewrite android/app/build.gradle.kts")
        return 2
    if args.fail:
        return 1
    print("hint: bump FROZEN_VERSION_CODE (by 1..10) in "
          "android/app/build.gradle.kts, or run with --fix")
    return 1


if __name__ == "__main__":
    sys.exit(main())

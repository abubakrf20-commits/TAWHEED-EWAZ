#!/usr/bin/env python3
"""Measure the visual latency of one widget tap, frame by frame.

Why this exists
---------------
The `tap.render.done` log line measures how long *dispatch* took, and that
number was already 4–24 ms while the card was visibly frozen: the tap committed
and the launcher applied a RemoteViews that still held the old digits. The only
honest metric is "which frame first shows the new number", so this script reads
a `screenrecord --bugreport` clip and reports the frame index at which a region
of the screen actually changed.

`--bugreport` overlays a frame counter and a timestamp on every frame, which is
what makes the numbers absolute instead of guessed.

Usage
-----
    python tools/widget_tap_latency.py clip.mp4 --crop W:H:X:Y [--expect N]

`--crop` is the region that must change — normally just the digits, so a
spinner or a blinking cursor elsewhere cannot be mistaken for the tap landing.

Output is a table of `frame  pts_time  changed` plus the first changed frame and
the delta from the previous change, so a run of taps shows each one separately.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

SHOWINFO = re.compile(r"n:\s*(\d+).*?pts_time:\s*([0-9.]+)")


def run(cmd: list[str]) -> str:
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        sys.exit(f"command failed: {' '.join(cmd)}\n{proc.stderr[-2000:]}")
    return proc.stdout


def changed_frames(clip: Path, crop: str, threshold: float) -> list[tuple[int, float]]:
    """Frame indices (and timestamps) whose cropped region differs from the
    previous frame by more than `threshold`.

    `scene` scores the frame against the one before it; on a widget that only
    redraws digits the score jumps on exactly the frame the number changed.
    """
    out = run([
        "ffmpeg", "-hide_banner", "-nostats", "-loglevel", "info",
        "-i", str(clip),
        "-vf", f"crop={crop},select='gt(scene,{threshold})',showinfo",
        "-fps_mode", "passthrough",
        "-f", "null", "-",
    ])
    hits: list[tuple[int, float]] = []
    for line in out.splitlines():
        if "Parsed_showinfo" not in line:
            continue
        match = SHOWINFO.search(line)
        if match:
            hits.append((int(match.group(1)), float(match.group(2))))
    return hits


def frame_map(clip: Path) -> dict[int, float]:
    """frame index → presentation timestamp, for the whole clip."""
    out = run([
        "ffprobe", "-v", "error", "-select_streams", "v:0",
        "-show_entries", "frame=pts_time", "-of", "json", str(clip),
    ])
    frames = json.loads(out).get("frames", [])
    return {i: float(f["pts_time"]) for i, f in enumerate(frames) if "pts_time" in f}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("clip", type=Path)
    parser.add_argument("--crop", required=True, help="W:H:X:Y of the digits")
    parser.add_argument("--threshold", type=float, default=0.02)
    parser.add_argument("--expect", type=int, default=0,
                        help="how many taps were performed (sanity check)")
    args = parser.parse_args()

    if not args.clip.exists():
        sys.exit(f"no such clip: {args.clip}")

    frames = frame_map(args.clip)
    hits = changed_frames(args.clip, args.crop, args.threshold)
    if not hits:
        print("no frame in the crop changed — the card did not repaint")
        return 2

    print(f"{'frame':>6}  {'t (s)':>8}  {'Δ (ms)':>8}")
    previous: float | None = None
    for index, pts in hits:
        delta = "" if previous is None else f"{(pts - previous) * 1000:8.0f}"
        print(f"{index:6d}  {pts:8.3f}  {delta:>8}")
        previous = pts

    print()
    print(f"first change at frame {hits[0][0]} (t={hits[0][1]:.3f}s), "
          f"{len(hits)} change(s) in {len(frames)} frames")
    if args.expect and len(hits) < args.expect:
        print(f"WARNING: expected {args.expect} repaints, saw {len(hits)}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

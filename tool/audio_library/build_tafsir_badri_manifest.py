#!/usr/bin/env python3
"""Merge the تفسیر قرآن مولانا عبدالغنی بدری tracks into the live audio manifest.

These lectures are NOT re-hosted. Every `file` is the third-party URL exactly as
the source publishes it, so `AudioLibraryConfig.objectUrl()` returns it verbatim
(one documented absolute-URL passthrough) instead of re-pointing it at the
bucket. A relative key here would 404, and re-encoding would turn the literal
`%20` in `036-Ya%20Seen.mp3` into `%2520`.

The live manifest is the merge base, never the output: writing a lectures-only
file over the bucket root would delete يقین and the two نشید sections. So this
reads `index.json` as published, appends ONE speaker inside `lectures`,
recomputes that category's flat list, bumps `version`, and writes a NEW file
for the uploader to swap in.

Inputs (all credential-free):
  --input   TSV of `URL<TAB>Arabic title`, one track per line
  --sizes   JSON of URL -> bytes, written by probe_track_sizes.py
  --base    the live manifest as published at the bucket root

Usage:
  python build_tafsir_badri_manifest.py \
      --input tafsir_badri_tracks.tsv \
      --sizes tafsir_badri_sizes.json \
      --base  C:/Users/abubakr/Desktop/index.json \
      --out   C:/Users/abubakr/Desktop/index-v5.json

Ordering: surah folders carry the surah number, so the section follows the
canonical mushaf order. A surah split into parts numbers those parts in its
FILE stem (`...Al-Baqara3.mp3`, `...fosselat-1.mp3`), and that digit is the only
label consistent with the bytes: the source's own الذاريات rows are swapped
against their stems. So a split surah is ordered and titled by the stem digit,
and `sizeBytes` is a hard requirement — the track tile prints "<n> مگابایت" and
the speaker total folds the same field, so a zero reads as an empty file.
"""

import argparse
import json
import os
import re
import sys
import urllib.parse

HERE = os.path.dirname(os.path.abspath(__file__))

ID_PREFIX = "lec-tb"
SPEAKER_ID = "tafsir-badri"
SPEAKER_TITLE = "تفسیر قرآن مولانا عبدالغنی بدری"
CATEGORY_ID = "lectures"

# `036-Ya%20Seen.mp3` / `051-zariyat-2.mp3` / `002-Al-Baqara8.mp3`
_PART_RE = re.compile(r"[-_]?(\d+)\s*$")
# `013-Ar-Ra_d` / `114-An-Nas` — the surah number that fixes the section order
_FOLDER_NUM_RE = re.compile(r"^(\d+)")
_TRAILING_LABEL_RE = re.compile(r"\s+\d+\s*$")


def read_tracks(path):
    """Read the TSV: `URL<TAB>title`. Blank lines are skipped."""
    tracks = []
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.rstrip("\n")
            if not line.strip():
                continue
            parts = line.split("\t")
            url = parts[0].strip()
            title = parts[1].strip() if len(parts) > 1 else ""
            if not url or not title:
                raise ValueError("line %d needs both a URL and a title: %r"
                                 % (len(tracks) + 1, line))
            tracks.append((url, title))
    return tracks


def read_sizes(path):
    with open(path, encoding="utf-8") as fh:
        sizes = json.load(fh)
    if not isinstance(sizes, dict):
        raise ValueError("--sizes must be a URL -> bytes object")
    return {url: int(bytes_) for url, bytes_ in sizes.items()}


def part_of(url):
    """The part digit carried by the file stem, or None for a whole surah."""
    stem = os.path.splitext(os.path.basename(urllib.parse.urlsplit(url).path))[0]
    match = _PART_RE.search(stem)
    return int(match.group(1)) if match else None


def folder_of(url):
    """The `013-Ar-Ra_d` segment — the source of both the order and the group."""
    segments = [s for s in urllib.parse.urlsplit(url).path.split("/") if s]
    return segments[-2] if len(segments) >= 2 else ""


def group_and_order(tracks):
    """Group by surah folder, then order the parts by their stem digit.

    Returns folders in canonical order; inside a split folder every track must
    carry a distinct part digit, otherwise the source's own order is kept.
    """
    groups = {}
    for index, (url, title) in enumerate(tracks):
        groups.setdefault(folder_of(url), []).append((index, url, title))

    def folder_key(folder):
        match = _FOLDER_NUM_RE.match(folder)
        return (int(match.group(1)) if match else 10 ** 6, folder)

    ordered = []
    for folder in sorted(groups, key=folder_key):
        rows = groups[folder]
        digits = [part_of(url) for _, url, _ in rows]
        if len(rows) > 1 and all(d is not None for d in digits) \
                and len(set(digits)) == len(digits):
            rows = sorted(zip(digits, rows), key=lambda pair: pair[0])
            rows = [(digit, index, url, title)
                    for digit, (index, url, title) in rows]
            for digit, index, url, title in rows:
                ordered.append((url, title, digit))
        else:
            for index, url, title in rows:
                ordered.append((url, title, None))
    return ordered


def title_for(title, digit, split):
    """`البقرة` + part 3 -> `البقرة 3`; a whole surah keeps its own words."""
    if digit is None or not split:
        return title
    return "%s %d" % (_TRAILING_LABEL_RE.sub("", title), digit)


def build_tracks(tracks, sizes, problems):
    ordered = group_and_order(tracks)
    split_folders = {}
    for url, _, _ in ordered:
        split_folders[folder_of(url)] = split_folders.get(folder_of(url), 0) + 1

    out = []
    for index, (url, raw_title, digit) in enumerate(ordered, start=1):
        if not url.startswith("https://"):
            problems.append("%s: not an https URL" % url)
        size = sizes.get(url)
        if not size:
            problems.append("%s: no measured size" % url)
            size = 0
        out.append({
            "id": "%s-%02d" % (ID_PREFIX, index),
            "title": title_for(raw_title, digit, split_folders[folder_of(url)] > 1),
            "file": url,
            "sizeBytes": size,
        })
    return out


def merge(base, badri, problems):
    """Append the speaker to `lectures` and rebuild that category's flat list."""
    categories = json.loads(json.dumps(base))  # deep copy: the base is read-only
    lectures = None
    for category in categories.get("categories", []):
        if category.get("id") == CATEGORY_ID:
            lectures = category
            break
    if lectures is None:
        problems.append("the live manifest has no %r category" % CATEGORY_ID)
        return categories

    speakers = lectures.get("speakers") or []
    # Idempotent: a re-run replaces the section it published before.
    speakers = [s for s in speakers if s.get("id") != SPEAKER_ID]
    speakers.append({"id": SPEAKER_ID, "title": SPEAKER_TITLE, "tracks": badri})
    lectures["speakers"] = speakers

    flat = []
    for speaker in speakers:
        flat.extend(speaker["tracks"])
    lectures["tracks"] = flat

    version = int(base.get("version", 4))
    categories["version"] = version + 1
    return categories


def validate(manifest, problems):
    ids = set()
    files = set()
    for category in manifest.get("categories", []):
        speakers = category.get("speakers") or []
        for speaker in speakers:
            if not speaker["tracks"]:
                problems.append("%s/%s: a speaker with no tracks"
                                % (category["id"], speaker["id"]))
        concat = []
        for speaker in speakers:
            concat.extend(speaker["tracks"])
        flat = category.get("tracks") or []
        if speakers and [t["id"] for t in flat] != [t["id"] for t in concat]:
            problems.append("%s: flat tracks and sections disagree" % category["id"])
        for track in flat:
            if track["id"] in ids:
                problems.append("duplicate track id %s" % track["id"])
            ids.add(track["id"])
            if track["file"] in files:
                problems.append("duplicate object %s" % track["file"])
            files.add(track["file"])
            if int(track.get("sizeBytes") or 0) <= 0:
                problems.append("%s: no size, and the app would print 0 مگابایت"
                                % track["id"])
    return len(ids)


def main():
    ap = argparse.ArgumentParser(
        description="Merge the Tafsir Badri section into the live audio manifest.")
    ap.add_argument("--input", required=True, help="TSV: URL<TAB>Arabic title")
    ap.add_argument("--sizes", required=True, help="JSON: URL -> bytes")
    ap.add_argument("--base", required=True, help="the live index.json as published")
    ap.add_argument("--out", required=True, help="the new manifest to upload")
    args = ap.parse_args()

    try:
        tracks = read_tracks(args.input)
        sizes = read_sizes(args.sizes)
        with open(args.base, encoding="utf-8") as fh:
            base = json.load(fh)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print("ERROR: %s" % error, file=sys.stderr)
        return 1

    problems = []
    badri = build_tracks(tracks, sizes, problems)
    manifest = merge(base, badri, problems)
    total = validate(manifest, problems)

    if problems:
        for problem in problems:
            print("PROBLEM %s" % problem, file=sys.stderr)
        print("nothing written", file=sys.stderr)
        return 1

    with open(args.out, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(manifest, fh, ensure_ascii=False, indent=2)
        fh.write("\n")

    bytes_total = sum(t["sizeBytes"] for t in badri)
    print("wrote %s" % args.out)
    print("version %s -> %s" % (base.get("version"), manifest["version"]))
    print("tracks: live %d -> %d, section %d (%.1f MB)"
          % (total - len(badri), total, len(badri), bytes_total / (1024 * 1024)))
    return 0


if __name__ == "__main__":
    sys.exit(main())

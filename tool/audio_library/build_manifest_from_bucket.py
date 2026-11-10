#!/usr/bin/env python3
"""Build index.json for the audio library straight from a storage bucket.

Why this exists instead of reusing build_full_manifest.ps1: the PowerShell
pipeline derives keys by renaming files to ASCII slugs and reading local disk.
The ArvanCloud buckets are already populated, so the bucket is the only place
the truth lives. Reading it back also gives the exact byte sizes the manifest
advertises, and a listing is the only way to notice an upload that never landed.

Order comes from the mapping CSV, not from the key: lexicographic sorting puts
"10." before "2.", which would scramble a curriculum that is meant to be watched
in sequence.

The script never invents data. If a CSV row has no object, or an object is in
no CSV row, both are reported as drift and the run fails, because either one
means the manifest would advertise a track that cannot play or silently hide one
that can.

Usage:
    python build_manifest_from_bucket.py \
        --base-url https://yaqeen.s3.ir-thr-at1.arvanstorage.ir \
        --prefix yaqeen/ \
        --category-id yaqeen \
        --csv yaqeen_mapping.csv \
        --out index.json
"""

import argparse
import csv
import json
import re
import ssl
import sys
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

S3_NS = "{http://s3.amazonaws.com/doc/2006-03-01/}"

# Tracks are named "<n>. <title>.opus", but two of them use "<n>_<title>.opus".
# Both forms are accepted; the number only decides ordering, never the title.
TITLE_RE = re.compile(r"^\s*(\d+)\s*[._\-–—]\s*(.*?)\s*$")

# Persian/Arabic dictionary order, ported from
# lib/features/goals/domain/goal_query.dart (_persianAlphabet / _normalize /
# compareForDisplay) so a track list ordered here matches the order the app
# itself uses for its "alphabetical" sort.
#
# Sorting these strings by code point is wrong in a way a reader notices at once:
# ARABIC LETTER PEH (U+067E) and GAF (U+06AF) sit far above HEH (U+0647) and
# FARSI YEH (U+06CC), so a naive sort files every title starting with those
# letters at the end of the album. The rank has to be written out; there is no
# arithmetic that recovers it.
PERSIAN_ALPHABET = [
    "ا", "آ", "أ", "إ", "ٱ",
    "ب", "پ",
    "ت", "ث",
    "ج", "چ",
    "ح", "خ",
    "د", "ذ",
    "ر", "ز", "ژ",
    "س", "ش",
    "ص", "ض",
    "ط", "ظ",
    "ع", "غ",
    "ف", "ق",
    "ک", "گ",
    "ل", "م", "ن",
    "و", "ؤ",
    "ه", "ة", "ی", "ي", "ى", "ئ",
]
_PERSIAN_RANK = {ch: i for i, ch in enumerate(PERSIAN_ALPHABET)}

# Letters whose code points differ between the Arabic and Persian keyboards.
# Folding them means an Arabic title and a Persian spelling of the same word
# land next to each other instead of in different halves of the list. Values are
# characters, not code points, so the digit folds and the letter folds share one
# type and join() cannot choke on a title that happens to contain Arabic digits.
_FOLDS = {
    0x064A: "ی",  # ARABIC YEH    -> FARSI YEH
    0x0649: "ی",  # ALEF MAKSURA  -> FARSI YEH
    0x0643: "ک",  # ARABIC KAF    -> KEHEH
    0x0629: "ه",  # TEH MARBUTA   -> HEH
    0x0623: "ا",  # ALEF + HAMZA ABOVE -> ALEF
    0x0622: "ا",  # ALEF + MADDA ABOVE -> ALEF
    0x0625: "ا",  # ALEF + HAMZA BELOW -> ALEF
    0x06F0: "0", 0x06F1: "1", 0x06F2: "2", 0x06F3: "3", 0x06F4: "4",
    0x06F5: "5", 0x06F6: "6", 0x06F7: "7", 0x06F8: "8", 0x06F9: "9",
}
# Diacritics and tatweel are dropped rather than folded: a search for
# "مطالعه" must find "مُطالعه", or the list looks broken on the user's own words.
_DROP_RANGES = ((0x064B, 0x065F), (0x0670, 0x0670), (0x0640, 0x0640))


def normalize(text):
    out = []
    for ch in text:
        cp = ord(ch)
        if any(lo <= cp <= hi for lo, hi in _DROP_RANGES):
            continue
        out.append(_FOLDS.get(cp, ch))
    return "".join(out)


def collate_key(text):
    """Sort key placing Persian/Arabic letters first in dictionary order."""
    norm = normalize(text)
    for ch in norm:
        if ch in _PERSIAN_RANK:
            return (0, _PERSIAN_RANK[ch], norm, text)
    return (1, 0, norm, text)


def list_objects(base_url, prefix):
    """Yield (key, size) for every object under prefix, following pagination."""
    ctx = ssl.create_default_context()
    token = None
    while True:
        url = f"{base_url.rstrip('/')}/?list-type=2&max-keys=1000"
        if prefix:
            url += "&prefix=" + urllib.parse.quote(prefix)
        if token:
            url += "&continuation-token=" + urllib.parse.quote(token)
        with urllib.request.urlopen(url, context=ctx, timeout=60) as resp:
            root = ET.fromstring(resp.read())
        for obj in root.findall(S3_NS + "Contents"):
            key = obj.find(S3_NS + "Key").text
            if key.endswith("/"):
                continue
            yield key, int(obj.find(S3_NS + "Size").text)
        nxt = root.find(S3_NS + "NextContinuationToken")
        if nxt is None:
            return
        token = nxt.text


def read_csv_order(path):
    """Return [(original_filename, slug)] in file order, de-duplicated.

    The CSV is semicolon-separated: column 0 is the original (often Persian)
    file name, column 1 the ASCII slug. Only column 0 is needed here, but both
    are returned so callers can report which naming the bucket actually used.
    """
    rows = []
    with open(path, encoding="utf-8-sig", newline="") as fh:
        for raw in csv.reader(fh, delimiter=";"):
            cells = [c.strip() for c in raw if c.strip()]
            if not cells:
                continue
            original = cells[0]
            slug = cells[1] if len(cells) > 1 else ""
            rows.append((original, slug))
    return rows


def split_number(name):
    """(ordinal, title) from a bare file name, or (None, name) if unnumbered."""
    stem = re.sub(r"\.opus$", "", name, flags=re.IGNORECASE)
    m = TITLE_RE.match(stem)
    if not m:
        return None, stem.strip()
    return int(m.group(1)), m.group(2).strip()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base-url", required=True)
    ap.add_argument("--prefix", default="")
    ap.add_argument("--category-id", required=True)
    ap.add_argument("--csv", help="mapping CSV; required unless --order alphabetic")
    ap.add_argument(
        "--order",
        choices=["csv", "numeric", "alphabetic"],
        default="csv",
        help="csv: file order (curriculum). numeric: the N. prefix. "
             "alphabetic: Persian/Arabic dictionary order of the title.",
    )
    ap.add_argument("--id-prefix", default=None,
                    help="id prefix; defaults to --category-id")
    ap.add_argument("--out", required=True)
    ap.add_argument("--version", type=int, default=2)
    ap.add_argument(
        "--allow-drift",
        action="store_true",
        help="write the manifest even when the CSV and the bucket disagree",
    )
    args = ap.parse_args()

    if args.order != "alphabetic" and not args.csv:
        print("ERROR: --order %s needs --csv" % args.order, file=sys.stderr)
        return 2
    id_prefix = args.id_prefix or args.category_id

    listing = {}
    for key, size in list_objects(args.base_url, args.prefix):
        listing[key] = size

    if not listing:
        print("ERROR: bucket listing is empty - is the prefix right?", file=sys.stderr)
        return 2

    by_name = {k[len(args.prefix):]: (k, v) for k, v in listing.items()}
    missing, tracks = [], []
    used = set()

    if args.order == "alphabetic":
        # No CSV: titles come from the file names and the sequence is the
        # alphabet. Used for the Arabic nasheed, where the bucket holds 29
        # tracks but the mapping CSV only knows 11 -- refusing to invent an
        # album order for those, and letting the reader decide by name, is the
        # honest option.
        for name, (key, size) in by_name.items():
            used.add(key)
            _, title = split_number(name)
            tracks.append({"_title": title, "file": key, "sizeBytes": size})
        tracks.sort(key=lambda t: collate_key(t["_title"]))
    else:
        rows = read_csv_order(args.csv)
        for original, slug in rows:
            if original in by_name:
                key, size = by_name[original]
            elif slug and slug in by_name:
                key, size = by_name[slug]
            else:
                missing.append(original)
                continue
            used.add(key)
            ordinal, title = split_number(original)
            tracks.append(
                {
                    "_title": title,
                    "file": key,
                    "sizeBytes": size,
                    "_ordinal": ordinal,
                }
            )
        # Order by the number in the file name when every track has one,
        # otherwise keep CSV order. Mixed input would silently scramble the
        # sequence, so the numbers are only trusted when they are universal.
        if args.order == "numeric" or all(
            t["_ordinal"] is not None for t in tracks
        ):
            if not all(t["_ordinal"] is not None for t in tracks):
                print("ERROR: --order numeric but some file names carry no number",
                      file=sys.stderr)
                return 2
            tracks.sort(key=lambda t: t["_ordinal"])

    orphans = sorted(k for k in listing if k not in used)

    tracks = [
        {
            "id": f"{id_prefix}-{i + 1:02d}",
            "title": t["_title"],
            "file": t["file"],
            "sizeBytes": t["sizeBytes"],
        }
        for i, t in enumerate(tracks)
    ]

    ids = [t["id"] for t in tracks]
    files = [t["file"] for t in tracks]
    problems = []
    if missing:
        problems.append(f"{len(missing)} CSV row(s) with no object in the bucket:")
        problems += [f"    - {m}" for m in missing]
    if orphans:
        problems.append(f"{len(orphans)} object(s) in the bucket in no CSV row:")
        problems += [f"    - {o}" for o in orphans]
    if len(set(ids)) != len(ids):
        problems.append("duplicate track ids")
    if len(set(files)) != len(files):
        problems.append("duplicate object keys")
    zero = [t["file"] for t in tracks if t["sizeBytes"] <= 0]
    if zero:
        problems.append(f"zero-byte object(s): {zero}")

    total = sum(t["sizeBytes"] for t in tracks)
    print(f"objects in bucket : {len(listing)}")
    print(f"tracks in manifest: {len(tracks)}")
    print(f"total size        : {total:,} bytes ({total / 1048576:.1f} MiB)")
    non_ascii = sum(1 for t in tracks if any(ord(c) > 127 for c in t["file"]))
    if non_ascii:
        print(f"note              : {non_ascii} key(s) are non-ASCII (URL-encoded at request time)")

    if problems:
        print("\nDRIFT DETECTED", file=sys.stderr)
        for p in problems:
            print(p, file=sys.stderr)
        if not args.allow_drift:
            print("\nRefusing to write. Fix the drift or pass --allow-drift.", file=sys.stderr)
            return 1

    manifest = {
        "version": args.version,
        "categories": [{"id": args.category_id, "tracks": tracks}],
    }
    with open(args.out, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(manifest, fh, ensure_ascii=False, indent=2)
        fh.write("\n")
    print(f"\nwrote {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

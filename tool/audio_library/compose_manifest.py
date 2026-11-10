"""Compose the final multi-category index.json for the merged bucket.

The per-category generator handles one category at a time, which was enough
while the library was a single yaqeen bucket. The merged bucket holds three
categories, and the app fetches exactly one manifest, so the categories have to
be emitted together.

Category ids are fixed by AudioCategory.displayTitle and must not be invented
here: yaqeen, anasheed, lectures. Display titles are resolved on the app
side; only speaker titles are Persian literals (the app shows them verbatim).

Anything under sokhanrani/ that no speaker folder claims becomes the
«متفرقه» section INSIDE lectures. That is deliberate rather than a fallback:
the Behzad Faghihi lecture sits beside the Ziaei lectures under sokhanrani/,
and listing it as a Ziaei lecture would credit the wrong speaker. Falling out
of every speaker folder is exactly the signal that it is not part of them.

A section can also be hosted by somebody else. A track whose `file` is an
absolute URL appears in no bucket listing, so a run from the listing alone
would drop it and its whole tile — for the Badri tafsir that is 160 lectures.
carry_external() therefore re-attaches every hosted section from the published
manifest (the file already at --out is the default source, since overwriting it
is exactly where the loss happens).

Usage (from tool/audio_library):
  python compose_manifest.py --base-url <public base> --out index.json
  python compose_manifest.py --bucket t.audio --out index.json --previous <published copy>
"""

import argparse
import csv
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from build_manifest_from_bucket import collate_key, split_number  # noqa: E402
from merge_arvan_audio_buckets import (  # noqa: E402
    REGION, list_objects, make_client,
)

HERE = os.path.dirname(os.path.abspath(__file__))

# Order matters: the first group to claim an object wins, and leftover objects
# are reported so a mistyped prefix cannot silently swallow a track.
# "speaker" turns the group into a tappable section inside its category. The app
# renders a category's sections as speaker tiles and keeps the flattened tracks
# hidden until one is opened, so a category with speakers needs no flat list in
# the UI. Anasheed is split into two sections because the Arabic and Persian
# repertoires are distinct; every lectures folder is one section so the teacher
# is named once, at the section, instead of on the category.
#
# A new lecture folder is claimed by adding one entry here: the folder name
# under sokhanrani/ is the contract with whoever uploads the files (the
# Rahimi folder on the bucket is `rahemi/`; the `lec-gd`/`goudarzi` ids are
# kept so existing tests and any cached rows keep matching). "order"
# numeric reads the lesson number off the file name ("3. ..."), so no mapping
# CSV is needed; a file without a number is reported, never silently ordered.
# A folder with no files yet contributes no section — the tile appears on the
# first upload that fills it, with no code change.
GROUPS = [
    {"category": "yaqeen", "prefix": "yaqeen/", "idPrefix": "yaqeen",
     "csv": "yaqeen_mapping.csv", "order": "numeric"},
    {"category": "anasheed", "prefix": "عربی نشید/", "idPrefix": "an-ar",
     "csv": None, "order": "alphabetic",
     "speaker": ("arabic", "عربی")},
    {"category": "anasheed", "prefix": "فارسی نشید/", "idPrefix": "an-fa",
     "csv": "nasheed_farsi_mapping.csv", "order": "csv",
     "speaker": ("persian", "فارسی")},
    {"category": "lectures", "prefix": "sokhanrani/ziaei/", "idPrefix": "lec",
     "csv": "ziaei_mapping.csv", "order": "csv",
     "speaker": ("ziaei", "شیخ ضیایی")},
    {"category": "lectures", "prefix": "sokhanrani/rahemi/", "idPrefix": "lec-gd",
     "csv": None, "order": "numeric",
     "speaker": ("goudarzi", "شیخ محمد رحیمی")},
    {"category": "lectures", "prefix": "sokhanrani/bazmandegan/", "idPrefix": "lec-bz",
     "csv": None, "order": "numeric",
     "speaker": ("bazmandegan", "شیخ موسی بازماندگان")},
    # The folder spelling is not something the library should be able to get
    # wrong. The first real file was staged under `tafseer-badri/` while this
    # table and docs/AUDIO_LIBRARY_HOSTING.md said `tafsir-badri/`, and an
    # unclaimed spelling does not fail loudly: it drops into «متفرقه» under the
    # wrong speaker. Both spellings are therefore one group, so the section
    # appears (and numbers stay in one sequence) whichever the uploader picked;
    # `prefix` stays the documented spelling.
    #
    # Those files are NOT on the bucket: the source publishes them on its own
    # server, so build_tafsir_badri_manifest.py merges them as absolute URLs and
    # carry_external() keeps them through every run below. This group stays so
    # that, if the uploader ever does mirror the folder here, the section keeps
    # its id and its `lec-tb` sequence — and publishing both copies at once is
    # refused as a problem rather than served as two tiles.
    {"category": "lectures", "prefix": "sokhanrani/tafsir-badri/", "idPrefix": "lec-tb",
     "prefixAliases": ["sokhanrani/tafseer-badri/"],
     "csv": None, "order": "numeric",
     "speaker": ("tafsir-badri", "تفسیر قرآن مولانا عبدالغنی بدری")},
]
MISC_PREFIX = "sokhanrani/"
MISC_SPEAKER = ("misc", "متفرقه")
MISC_ID_PREFIX = "misc"
MANIFEST_KEY = "index.json"


def read_csv_order(path):
    rows = []
    with open(path, encoding="utf-8-sig", newline="") as fh:
        for raw in csv.reader(fh, delimiter=";"):
            cells = [c.strip() for c in raw if c.strip()]
            if cells:
                rows.append((cells[0], cells[1] if len(cells) > 1 else ""))
    return rows


def _prefixes(group):
    """Every folder spelling this group claims, the documented one first."""
    return [group["prefix"]] + list(group.get("prefixAliases", ()))


def _strip_prefix(key, prefixes):
    """Object name with the folder it actually lives in removed."""
    for prefix in prefixes:
        if key.startswith(prefix):
            return key[len(prefix):]
    return key


def build_group(group, listing):
    """Return (tracks, claimed_keys, problems) for one group.

    `listing` is the bucket's {key: (size, etag)} map, so the scoped view maps a
    prefix-stripped file name back to (key, size). Getting that pair the wrong
    way round silently writes the ETag into sizeBytes and the byte count into
    `file`, so it is built explicitly here rather than by tuple unpacking.
    """
    prefixes = _prefixes(group)
    label = " or ".join(prefixes)
    scoped, clashes = {}, []
    for key, value in listing.items():
        for prefix in prefixes:
            if not key.startswith(prefix):
                continue
            name = key[len(prefix):]
            if name in scoped:
                # The same file name under both spellings. Keeping the first
                # and dropping the second would lose a track silently, so the
                # clash is reported (and blocks publishing) while the second
                # key stays claimed, never leaking into «متفرقه».
                clashes.append((name, scoped[name][0], key))
            else:
                scoped[name] = (key, value[0])
            break
    tracks, problems, used_names = [], [], set()
    # The first spelling keeps the track, so its twin key would otherwise be
    # treated as unclaimed and fall into «متفرقه».
    claimed = {twin for _, _, twin in clashes}
    for name, kept, twin in clashes:
        problems.append(
            "%s: %s and %s share the name %s" % (label, kept, twin, name))

    if group["order"] == "alphabetic":
        for name, (key, size) in scoped.items():
            used_names.add(name)
            claimed.add(key)
            _, title = split_number(name)
            tracks.append({"_t": title, "file": key, "size": size})
        tracks.sort(key=lambda t: collate_key(t["_t"]))
    elif group["order"] == "numeric" and not group.get("csv"):
        # Lesson-numbered uploads with no mapping file: every object under
        # the prefix must carry a leading number ("3. ..."), mirroring
        # --order numeric of the per-category generator. An unnumbered file
        # is a problem, never silently appended — and it stays claimed so it
        # cannot leak into «متفرقه» under a wrong identity.
        numbered = []
        for name, (key, size) in scoped.items():
            used_names.add(name)
            claimed.add(key)
            ordinal, title = split_number(name)
            if ordinal is None:
                problems.append(
                    "%s: --order numeric but %s carries no number"
                    % (label, name))
                continue
            numbered.append((ordinal, title, key, size))
        numbered.sort(key=lambda e: (e[0], e[1]))
        tracks = [{"_t": e[1], "file": e[2], "size": e[3]} for e in numbered]
    elif group.get("csv"):
        rows = read_csv_order(os.path.join(HERE, group["csv"]))
        missing = []
        for original, slug in rows:
            hit = scoped.get(original) or (scoped.get(slug) if slug else None)
            if hit is None:
                missing.append(original)
                continue
            key, size = hit
            claimed.add(key)
            used_names.add(_strip_prefix(key, prefixes))
            ordinal, title = split_number(original)
            tracks.append({"_t": title, "file": key, "size": size,
                           "_o": ordinal})
        if missing:
            problems.append(
                "%s: %d CSV row(s) with no object: %s"
                % (label, len(missing), ", ".join(missing[:5])))
        if group["order"] == "numeric":
            if tracks and all(t["_o"] is not None for t in tracks):
                tracks.sort(key=lambda t: t["_o"])
            else:
                problems.append(
                    "%s: --order numeric but some names carry no number"
                    % label)

    # Compare like with like: `scoped` is keyed by the prefix-stripped name, so
    # comparing against full keys would report every object as unclaimed.
    orphans = sorted(k for k in scoped if k not in used_names)
    if orphans:
        problems.append("%s: %d object(s) claimed by no CSV row: %s"
                        % (label, len(orphans),
                           ", ".join(orphans[:5])))

    out = [{"id": "%s-%02d" % (group["idPrefix"], i + 1),
            "title": t["_t"], "file": t["file"], "sizeBytes": t["size"]}
           for i, t in enumerate(tracks)]
    return out, claimed, problems


def assemble(listing):
    """Pure manifest assembly from a bucket listing.

    Returns (categories, problems). main() only adds credentials and file
    output around this, so the grouping rules — which folder becomes which
    section, and what falls into «متفرقه» — stay testable offline.
    """
    claimed_all = set()
    categories, problems = [], []
    for group in GROUPS:
        tracks, used, probs = build_group(group, listing)
        claimed_all |= used
        print("  %-28s %3d tracks  %s"
              % (group["category"] + " / " + group["prefix"], len(tracks),
                 format(sum(t["sizeBytes"] for t in tracks), ",")))
        problems += probs
        existing = next((c for c in categories if c["id"] == group["category"]),
                        None)
        if existing is None:
            existing = {"id": group["category"], "tracks": [], "_speakers": []}
            categories.append(existing)
        # Two prefixes folded into one category keep their own id prefixes,
        # so appending cannot produce a duplicate track id.
        existing["tracks"].extend(tracks)
        speaker = group.get("speaker")
        if speaker and tracks:
            existing["_speakers"].append(
                {"id": speaker[0], "title": speaker[1], "tracks": tracks})
        elif speaker:
            # A folder with no files yet contributes no section: the tile
            # appears on the first upload that fills it, instead of an
            # empty tile that plays nothing.
            print("  %-28s %3d tracks  (section omitted until files arrive)"
                  % (group["category"] + " / " + group["prefix"], 0))

    # Leftovers under the lecture prefix belong to no speaker folder: they
    # form the «متفرقه» section INSIDE lectures, so the category tab stays
    # the single entry point for every lecture. Track ids keep the `misc-`
    # prefix, so files downloaded under the old top-level category keep
    # working after the move.
    leftovers = sorted(k for k in listing
                       if k.startswith(MISC_PREFIX) and k not in claimed_all)
    if leftovers:
        misc = []
        for i, key in enumerate(leftovers):
            size = listing[key][0]
            _, title = split_number(os.path.basename(key))
            misc.append({"id": "%s-%02d" % (MISC_ID_PREFIX, i + 1),
                         "title": title, "file": key, "sizeBytes": size})
        lectures = next((c for c in categories if c["id"] == "lectures"),
                        None)
        if lectures is None:
            lectures = {"id": "lectures", "tracks": [], "_speakers": []}
            categories.append(lectures)
        lectures["tracks"].extend(misc)
        lectures["_speakers"].append(
            {"id": MISC_SPEAKER[0], "title": MISC_SPEAKER[1], "tracks": misc})
        print("  %-28s %3d tracks  %s  (unclaimed under %s)"
              % ("lectures / " + MISC_SPEAKER[1], len(misc),
                 format(sum(t["sizeBytes"] for t in misc), ","), MISC_PREFIX))

    # index.json is a manifest, not a track. It lives at the bucket root, so it
    # must never be reported as an unaccounted-for object.
    stray = sorted(k for k in listing
                   if k not in claimed_all and k not in leftovers
                   and k != MANIFEST_KEY)
    if stray:
        problems.append("unclaimed outside %s: %s"
                        % (MISC_PREFIX, ", ".join(stray[:5])))

    total = sum(len(c["tracks"]) for c in categories)
    print("\ncategories: %s" % ", ".join(
        "%s=%d" % (c["id"], len(c["tracks"])) for c in categories))
    print("tracks total: %d" % total)

    ids = [t["id"] for c in categories for t in c["tracks"]]
    files = [t["file"] for c in categories for t in c["tracks"]]
    if len(set(ids)) != len(ids):
        problems.append("duplicate track ids")
    if len(set(files)) != len(files):
        problems.append("duplicate object keys")

    # Promote the collected groups into the section list, keeping the flat copy
    # as the concatenation of the sections so older clients that read only
    # "tracks" still see every file. A mismatch means a group leaked out of the
    # sections and would silently vanish from the UI.
    for cat in categories:
        speakers = cat.pop("_speakers", [])
        if not speakers:
            continue
        if [t["id"] for t in cat["tracks"]] != [
                t["id"] for s in speakers for t in s["tracks"]]:
            problems.append("%s: flat tracks and sections disagree" % cat["id"])
        cat["speakers"] = speakers
        print("  sections of %-9s %s" % (
            cat["id"], ", ".join("%s=%d" % (s["title"], len(s["tracks"]))
                                 for s in speakers)))
    return categories, problems


def is_hosted(track):
    """True when the bytes live on somebody else's server.

    `AudioLibraryConfig.objectUrl()` returns an absolute `file` verbatim, so the
    bucket neither holds nor sees these tracks.
    """
    return str(track["file"]).startswith(("http://", "https://"))


def carry_external(previous, categories, problems):
    """Re-attach every section whose files are hosted elsewhere.

    assemble() composes from a bucket listing alone, so without this the next
    index.json silently loses a third-party section — for the Badri tafsir that
    is 160 lectures and the tile that opens them. The published manifest is the
    only record of those files, so each hosted section is appended after the
    bucket's own sections and the flat list is rebuilt from the sections, which
    is the contract older clients read.

    Every mismatch is a problem, never a silent choice: a section id the bucket
    also produced means the same lecture exists twice under two files (only the
    uploader knows which is live), and a hosted track inside a section-less
    category has no identity to carry.
    """
    carried = 0
    by_id = {c["id"]: c for c in categories}
    for category in (previous or {}).get("categories", []):
        speakers = category.get("speakers") or []
        if not speakers:
            if any(is_hosted(t) for t in category.get("tracks") or []):
                problems.append(
                    "%s: a hosted track sits in a section-less category, so it "
                    "cannot be carried — give it a speaker" % category["id"])
            continue
        for speaker in speakers:
            tracks = speaker.get("tracks") or []
            hosted = [t for t in tracks if is_hosted(t)]
            if not hosted:
                continue
            target = by_id.get(category["id"])
            if target is None:
                problems.append("%s: the live section %s/%s cannot be carried, "
                                "the category is gone from this run"
                                % (category["id"], category["id"], speaker["id"]))
                continue
            into = target.get("speakers") or []
            if not into:
                problems.append("%s: this run has no sections, so the hosted "
                                "section %s has nowhere to go"
                                % (category["id"], speaker["id"]))
                continue
            if any(s["id"] == speaker["id"] for s in into):
                problems.append("%s/%s: hosted AND in the bucket — say which one "
                                "is live before publishing both"
                                % (category["id"], speaker["id"]))
                continue
            if len(hosted) != len(tracks):
                problems.append("%s/%s: a section mixes hosted and bucket files"
                                % (category["id"], speaker["id"]))
            into.append({"id": speaker["id"], "title": speaker["title"],
                         "tracks": hosted})
            target["speakers"] = into
            target["tracks"] = [t for s in into for t in s["tracks"]]
            carried += len(hosted)

    if carried:
        ids = [t["id"] for c in categories for t in c["tracks"]]
        files = [t["file"] for c in categories for t in c["tracks"]]
        if len(set(ids)) != len(ids):
            problems.append("duplicate track ids after carrying a hosted section")
        if len(set(files)) != len(files):
            problems.append("duplicate object keys after carrying a hosted section")
    return carried


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--bucket", required=True,
                    help="bucket name, e.g. t.audio")
    ap.add_argument("--out", required=True)
    ap.add_argument("--version", type=int, default=3)
    ap.add_argument("--previous",
                    help="the published index.json — the only record of a "
                         "section hosted on another server. Defaults to an "
                         "existing --out, because overwriting that file is "
                         "exactly where a hosted section gets lost.")
    args = ap.parse_args()

    endpoint = os.environ.get(
        "ARVAN_ENDPOINT", "https://s3.%s.arvanstorage.ir" % REGION)
    s3 = make_client(endpoint)
    if s3 is None:
        print("ERROR: credentials required to list the private bucket.",
              file=sys.stderr)
        return 3

    source = args.previous or (args.out if os.path.exists(args.out) else None)
    previous = None
    if source:
        try:
            with open(source, encoding="utf-8") as fh:
                previous = json.load(fh)
        except (OSError, ValueError) as error:
            print("ERROR: cannot read the previous manifest %s: %s"
                  % (source, error), file=sys.stderr)
            return 1

    listing = list_objects(args.bucket, s3=s3)
    print("bucket %s: %d objects, %s bytes"
          % (args.bucket, len(listing),
             format(sum(v[0] for v in listing.values()), ",")))

    categories, problems = assemble(listing)

    if previous is not None:
        print("hosted tracks carried from %s: %d"
              % (source, carry_external(previous, categories, problems)))

    if problems:
        print("\nPROBLEMS", file=sys.stderr)
        for p in problems:
            print("  " + p, file=sys.stderr)

    manifest = {"version": args.version, "categories": categories}
    with open(args.out, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(manifest, fh, ensure_ascii=False, indent=2)
        fh.write("\n")
    print("\nwrote %s" % args.out)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
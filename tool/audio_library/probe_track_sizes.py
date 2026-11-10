#!/usr/bin/env python3
"""Ask the audio host for every track's byte count, without any credentials.

The manifest's `sizeBytes` is user-visible: the track tile prints
"<n> مگابایت" and the download progress line prints "<n> MB", and a speaker's
total is the fold of the same field. A zero is therefore a lie on screen, not
a missing detail, so this prober refuses to write one.

Reads the same TSV the manifest builder reads (URL<TAB>title) and writes a JSON
map of URL -> bytes:

    python probe_track_sizes.py --input tafsir_badri_tracks.tsv \
        --out tafsir_badri_sizes.json

The host answers a plain HEAD with 200, Content-Type audio/mpeg and a real
Content-Length, so no Range request is needed. Every URL is sent verbatim: the
list carries a literal "%20" in one file name and hamza underscores in thirteen
folder names, and re-encoding either changes the object the host serves.
"""

import argparse
import concurrent.futures
import json
import os
import sys
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))

# The trampoline of a shared connection pool costs more than it saves here:
# HEAD on nginx is one round trip, so a modest pool over short-lived requests
# is what keeps 160 probes to a few seconds.
DEFAULT_WORKERS = 12
TIMEOUT_SECONDS = 30


def read_urls(path):
    """Return the track URLs in file order, duplicates removed but reported."""
    urls = []
    seen = {}
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.rstrip("\n")
            if not line.strip():
                continue
            url = line.split("\t")[0].strip()
            if not url:
                continue
            if url in seen:
                print(f"WARN duplicate URL, kept once: {url}", file=sys.stderr)
                continue
            seen[url] = True
            urls.append(url)
    return urls


def probe(url):
    """Return (url, bytes) or raise with the reason the host gave."""
    request = urllib.request.Request(url, method="HEAD")
    request.add_header("User-Agent", "curl/8")
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
            raw = response.headers.get("Content-Length")
    except urllib.error.HTTPError as error:
        raise RuntimeError(f"HTTP {error.code}") from error
    except (urllib.error.URLError, TimeoutError, OSError) as error:
        raise RuntimeError(f"transport: {error}") from error
    if raw is None or not str(raw).strip().isdigit():
        raise RuntimeError(f"no Content-Length (got {raw!r})")
    size = int(raw)
    if size <= 0:
        raise RuntimeError(f"declared an empty file ({size} bytes)")
    return url, size


def main():
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser(
        description="Probe each track URL's Content-Length into a sizes JSON map."
    )
    ap.add_argument("--input", required=True, help="TSV file: URL<TAB>Arabic title")
    ap.add_argument("--out", required=True, help="Output JSON: URL -> bytes")
    ap.add_argument("--workers", type=int, default=DEFAULT_WORKERS)
    args = ap.parse_args()

    urls = read_urls(args.input)
    if not urls:
        print("ERROR: no URLs found in input", file=sys.stderr)
        return 1
    print(f"probing {len(urls)} tracks with {args.workers} workers")

    sizes = {}
    failures = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = {pool.submit(probe, url): url for url in urls}
        for future in concurrent.futures.as_completed(futures):
            url = futures[future]
            try:
                key, size = future.result()
            except Exception as error:  # noqa: BLE001 - reported, never swallowed
                failures.append((url, str(error)))
                continue
            sizes[key] = size
            done = len(sizes)
            if done % 20 == 0 or done == len(urls):
                print(f"  {done}/{len(urls)} sized")

    if failures:
        print(f"\nERROR: {len(failures)} URL(s) answered no size:", file=sys.stderr)
        for url, reason in failures:
            print(f"  {reason}  {url}", file=sys.stderr)
        print("Nothing written — a manifest with holes would print 0 MB.", file=sys.stderr)
        return 1

    ordered = {url: sizes[url] for url in urls}
    with open(args.out, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(ordered, fh, ensure_ascii=False, indent=2)
        fh.write("\n")
    total = sum(ordered.values())
    print(f"wrote {args.out}: {len(ordered)} tracks, {total / (1024 * 1024):.1f} MB total")
    return 0


if __name__ == "__main__":
    sys.exit(main())

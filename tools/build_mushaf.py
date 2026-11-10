#!/usr/bin/env python3
"""Build mushaf assets: SVG-BR pages -> WebP images + SQLite ayah-bounds database."""

import hashlib
import io
import json
import re
import sqlite3
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import brotli
import resvg_py
from PIL import Image

BASE_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = BASE_DIR.parent
SVG_DIR = PROJECT_ROOT / "hafs" / "kfqc" / "svg-br"
SURAH_JSON_PATH = PROJECT_ROOT / "hafs" / "kfqc" / "json" / "surah.json"

OUTPUT_DIR = BASE_DIR / "mushaf_build"
PAGES_DIR = OUTPUT_DIR / "pages"
DB_PATH = OUTPUT_DIR / "mushaf.db"
MANIFEST_PATH = OUTPUT_DIR / "manifest.json"

TOTAL_PAGES = 604
RENDER_WIDTH = 900
WEBP_QUALITY = 75
BACKGROUND = "#FFFFFF"

TAG_RE = re.compile(r"<path\b[^>]*\bclass=\"ayahPolygon\"[^>]*>", re.IGNORECASE)
ATTR_RE = re.compile(r'\b([A-Za-z_:][-\w:.]*)="([^"]*)"')
VIEWBOX_RE = re.compile(
    r'viewBox\s*=\s*"\s*([-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?)\s+'
    r'([-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?)\s+'
    r'([-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?)\s+'
    r'([-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?)\s*"',
    re.IGNORECASE,
)
TOKEN_RE = re.compile(r"[MLZmlz]|[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?")


def load_surah_meta():
    with open(SURAH_JSON_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)
    return {int(entry["number"]): int(entry["ayahCount"]) for entry in data}


def parse_viewbox(svg):
    match = VIEWBOX_RE.search(svg)
    if not match:
        raise ValueError("viewBox not found")
    min_x, min_y, width, height = (float(g) for g in match.groups())
    return min_x, min_y, width, height


def parse_d_points(d):
    tokens = TOKEN_RE.findall(d)
    points = []
    i = 0
    n = len(tokens)
    while i < n:
        token = tokens[i]
        if token in ("M", "L", "m", "l"):
            if i + 2 >= n:
                raise ValueError(f"incomplete coordinate pair in d attribute: {d!r}")
            x = float(tokens[i + 1])
            y = float(tokens[i + 2])
            points.append((x, y))
            i += 3
        elif token in ("Z", "z"):
            i += 1
        else:
            raise ValueError(f"unexpected token {token!r} in d attribute: {d!r}")
    return points


def parse_d_subpaths(d):
    """Splits a polygon `d` at every M command into separate subpaths.

    Each subpath traces one contiguous band of the verse (typically one
    mushaf line); keeping them SEPARATE is what makes multi-line verses
    highlight as tight per-line rectangles instead of one giant block that
    covers neighbouring verses.
    """
    tokens = TOKEN_RE.findall(d)
    subpaths = []
    current = None
    i = 0
    n = len(tokens)
    while i < n:
        token = tokens[i]
        if token in ("M", "m"):
            current = []
            subpaths.append(current)
            if i + 2 >= n:
                raise ValueError(f"incomplete coordinate pair in d attribute: {d!r}")
            current.append((float(tokens[i + 1]), float(tokens[i + 2])))
            i += 3
        elif token in ("L", "l"):
            if current is None:
                raise ValueError(f"L before M in d attribute: {d!r}")
            if i + 2 >= n:
                raise ValueError(f"incomplete coordinate pair in d attribute: {d!r}")
            current.append((float(tokens[i + 1]), float(tokens[i + 2])))
            i += 3
        elif token in ("Z", "z"):
            i += 1
        else:
            raise ValueError(f"unexpected token {token!r} in d attribute: {d!r}")
    return [s for s in subpaths if s]


def _polygon_to_rects(points):
    """Splits a (possibly L-shaped) polygon into tight horizontal bands.

    A staircase polygon that spans 1.5 mushaf lines has a single path with a
    notch. Its bounding box would cover neighbouring verses. Slicing it at
    every distinct Y and sampling the interior at each band's mid-Y yields
    one tight rectangle per line band (e.g. an L becomes 2 rects).
    """
    if len(points) < 3:
        return []
    ys = sorted(set(y for _, y in points))
    rects = []
    n = len(points)
    for i in range(len(ys) - 1):
        y0, y1 = ys[i], ys[i + 1]
        # Skip inter-line gaps / tiny slivers (< 3px in 550px viewBox
        # ≈ 0.5% of page height). These are the thin horizontal bridges
        # between line bands in staircase polygons — not actual text.
        if y1 - y0 < 3.0:
            continue
        mid = (y0 + y1) / 2.0
        xs = []
        for j in range(n):
            x1, y1p = points[j]
            x2, y2p = points[(j + 1) % n]
            # edge straddles mid
            if (y1p <= mid < y2p) or (y2p <= mid < y1p):
                if y2p == y1p:
                    continue
                t = (mid - y1p) / (y2p - y1p)
                xs.append(x1 + t * (x2 - x1))
        xs.sort()
        for k in range(0, len(xs), 2):
            if k + 1 >= len(xs):
                break
            x0, x1 = xs[k], xs[k + 1]
            if abs(x1 - x0) < 0.5:
                continue
            rects.append(
                (min(x0, x1), y0, max(x0, x1), y1)
            )
    # fallback: degenerate thin polygon where sampling found nothing
    if not rects:
        xs = [p[0] for p in points]
        ys2 = [p[1] for p in points]
        rects.append((min(xs), min(ys2), max(xs), max(ys2)))
    return rects


def parse_ayah_bounds(svg):
    """Returns one (surah, ayah, box) tuple per horizontal band.

    A verse spanning several mushaf lines yields several rows, each hugging
    exactly its own line segment — the union of these rows is what the reader
    paints as the verse highlight. L-shaped (staircase) polygons are split
    into per-line tight rects so a 1.5-line ayah no longer highlights 2 full
    lines.
    """
    rows = []
    for tag_match in TAG_RE.finditer(svg):
        tag = tag_match.group(0)
        attrs = dict(ATTR_RE.findall(tag))
        try:
            surah = int(attrs["surah"])
            ayah = int(attrs["ayah"])
        except (KeyError, ValueError):
            raise ValueError(f"ayahPolygon tag missing/invalid surah or ayah: {tag!r}")
        d = attrs.get("d")
        if not d:
            raise ValueError(f"ayahPolygon tag missing d attribute: {tag!r}")
        for subpath in parse_d_subpaths(d):
            for box in _polygon_to_rects(subpath):
                rows.append((surah, ayah, box))
    return rows


def render_page_webp(svg):
    png_bytes = resvg_py.svg_to_bytes(
        svg_string=svg,
        width=RENDER_WIDTH,
        background=BACKGROUND,
    )
    image = Image.open(io.BytesIO(bytes(png_bytes)))
    if image.mode not in ("RGB", "L"):
        image = image.convert("RGB")
    buffer = io.BytesIO()
    image.save(buffer, format="WEBP", quality=WEBP_QUALITY)
    webp_bytes = buffer.getvalue()
    return webp_bytes, image.width, image.height


def init_db(db_path):
    conn = sqlite3.connect(db_path)
    conn.executescript(
        """
        DROP TABLE IF EXISTS ayah_bounds;
        CREATE TABLE ayah_bounds (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            page_number INTEGER NOT NULL,
            sura_number INTEGER NOT NULL,
            ayah_number INTEGER NOT NULL,
            min_x REAL NOT NULL,
            min_y REAL NOT NULL,
            max_x REAL NOT NULL,
            max_y REAL NOT NULL
        );
        CREATE INDEX idx_page ON ayah_bounds(page_number);
        CREATE INDEX idx_sura_ayah ON ayah_bounds(sura_number, ayah_number);
        """
    )
    return conn


def main():
    start_time = time.perf_counter()
    db_only = "--db-only" in sys.argv
    # v4: سبک‌سازی 1080->900، کیفیت 90->75 (≈35٪ حجم کمتر، decode سریع‌تر)
    manifest_version = 4
    print(f"Mushaf builder: {TOTAL_PAGES} pages -> {OUTPUT_DIR}"
          + ("  [db+manifest only]" if db_only else ""))

    if not SVG_DIR.is_dir():
        print(f"ERROR: SVG directory not found: {SVG_DIR}", file=sys.stderr)
        return 1

    try:
        ayah_counts = load_surah_meta()
    except Exception as exc:
        print(f"WARN: could not load surah metadata ({exc}); skipping validation")
        ayah_counts = {}

    PAGES_DIR.mkdir(parents=True, exist_ok=True)

    conn = init_db(DB_PATH)
    all_rows = []
    manifest_pages = {}
    failed_pages = {}
    warned_pages = []
    ok_count = 0

    for page_number in range(1, TOTAL_PAGES + 1):
        page_key = f"{page_number:03d}"
        try:
            br_path = SVG_DIR / f"{page_key}.svg.br"
            if not br_path.is_file():
                raise FileNotFoundError(f"missing source file: {br_path.name}")

            svg = brotli.decompress(br_path.read_bytes()).decode("utf-8")

            _, _, vb_w, vb_h = parse_viewbox(svg)
            if vb_w <= 0 or vb_h <= 0:
                raise ValueError(f"invalid viewBox dimensions: {vb_w}x{vb_h}")

            bound_rows = parse_ayah_bounds(svg)
            if not bound_rows:
                print(f"[{page_key}] WARN: no ayahPolygon elements found")

            for (surah, ayah, _box) in bound_rows:
                max_expected = ayah_counts.get(surah)
                if surah < 1 or surah > 114:
                    warned_pages.append((page_number, f"surah {surah} out of range"))
                elif max_expected is not None and not (1 <= ayah <= max_expected):
                    warned_pages.append(
                        (page_number, f"{surah}:{ayah} exceeds ayahCount {max_expected}")
                    )

            for (surah, ayah, box) in bound_rows:
                all_rows.append((page_number, surah, ayah, *box))

            webp_path = PAGES_DIR / f"{page_key}.webp"
            if db_only:
                # Reuse the existing rendered page for the manifest entry.
                webp_bytes = webp_path.read_bytes()
                out_w, out_h = Image.open(io.BytesIO(webp_bytes)).size
            else:
                webp_bytes, out_w, out_h = render_page_webp(svg)
                webp_path.write_bytes(webp_bytes)

            digest = hashlib.sha256(webp_bytes).hexdigest()[:16]
            manifest_pages[page_key] = {"hash": digest, "width": out_w, "height": out_h}

            ok_count += 1
            status = f"ok {out_w}x{out_h} segments={len(bound_rows)}"
        except Exception as exc:
            status = f"FAIL: {exc}"
            failed_pages[page_number] = str(exc)

        if page_number % 50 == 0 or page_number == TOTAL_PAGES:
            print(f"[{page_key}/{TOTAL_PAGES}] {status}")
        elif page_number in failed_pages:
            print(f"[{page_key}/{TOTAL_PAGES}] FAIL: {failed_pages[page_number]}")

    if all_rows:
        conn.executemany(
            "INSERT INTO ayah_bounds "
            "(page_number, sura_number, ayah_number, min_x, min_y, max_x, max_y) "
            "VALUES (?, ?, ?, ?, ?, ?, ?)",
            all_rows,
        )
    conn.commit()
    conn.close()

    manifest = {
        "version": manifest_version,
        "total_pages": TOTAL_PAGES,
        "render_width": RENDER_WIDTH,
        "webp_quality": WEBP_QUALITY,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "pages": manifest_pages,
    }
    with open(MANIFEST_PATH, "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
        f.write("\n")

    elapsed = time.perf_counter() - start_time
    print("-" * 60)
    print(f"Summary:")
    print(f"  pages rendered : {ok_count}/{TOTAL_PAGES}")
    print(f"  pages failed   : {len(failed_pages)}")
    if failed_pages:
        for page_number, err in sorted(failed_pages.items()):
            print(f"    - {page_number:03d}: {err}")
    print(f"  warnings       : {len(warned_pages)}")
    for page_number, msg in warned_pages[:10]:
        print(f"    - {page_number:03d}: {msg}")
    if len(warned_pages) > 10:
        print(f"    ... and {len(warned_pages) - 10} more")
    print(f"  ayah rows      : {len(all_rows)}")
    print(f"  database       : {DB_PATH}")
    print(f"  manifest       : {MANIFEST_PATH}")
    print(f"  images dir     : {PAGES_DIR}")
    print(f"  total time     : {elapsed:.2f}s")

    return 1 if failed_pages else 0


if __name__ == "__main__":
    sys.exit(main())

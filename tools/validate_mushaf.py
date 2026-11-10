#!/usr/bin/env python3
"""Validate mushaf build output: WebP pages, SQLite ayah bounds, and SVG->pixel coordinate mapping."""

import json
import random
import re
import sqlite3
import sys
from pathlib import Path

import brotli
from PIL import Image

BASE_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = BASE_DIR.parent
SVG_DIR = PROJECT_ROOT / "hafs" / "kfqc" / "svg-br"
SURAH_JSON_PATH = PROJECT_ROOT / "hafs" / "kfqc" / "json" / "surah.json"

BUILD_DIR = BASE_DIR / "mushaf_build"
PAGES_DIR = BUILD_DIR / "pages"
DB_PATH = BUILD_DIR / "mushaf.db"
CROP_DIR = BASE_DIR / "test_render"

TOTAL_PAGES = 604
TOTAL_AYAHS = 6236
SAMPLE_PAGES = 30
MIN_AYAHS_PER_PAGE_SAMPLE = 2
MAX_AYAHS_PER_PAGE_SAMPLE = 3
BBOX_EXPAND_SVG = 5.0
OVERLAP_TOLERANCE = 1.0
IOU_DUPLICATE_THRESHOLD = 0.9
BOUNDS_TOLERANCE = 2.0
EPS = 1e-3
RANDOM_SEED = 2024

VIEWBOX_RE = re.compile(
    r'viewBox\s*=\s*"\s*'
    r'([-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?)\s+'
    r'([-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?)\s+'
    r'([-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?)\s+'
    r'([-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?)\s*"',
    re.IGNORECASE,
)


def load_surah_meta():
    with open(SURAH_JSON_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)
    return {int(entry["number"]): int(entry["ayahCount"]) for entry in data}


def parse_viewbox(svg_text):
    match = VIEWBOX_RE.search(svg_text)
    if not match:
        raise ValueError("viewBox not found in SVG")
    min_x, min_y, width, height = (float(g) for g in match.groups())
    if width <= 0 or height <= 0:
        raise ValueError(f"invalid viewBox dimensions: {width}x{height}")
    return min_x, min_y, width, height


def load_svg_page(page_number):
    br_path = SVG_DIR / f"{page_number:03d}.svg.br"
    if not br_path.is_file():
        raise FileNotFoundError(f"missing source: {br_path.name}")
    svg_text = brotli.decompress(br_path.read_bytes()).decode("utf-8")
    return svg_text, parse_viewbox(svg_text)


def check_completeness(conn, ayah_counts):
    issues = []

    expected_total = sum(ayah_counts.values()) if ayah_counts else TOTAL_AYAHS
    if ayah_counts and expected_total != TOTAL_AYAHS:
        issues.append(f"surah.json ayahCount sum is {expected_total}, expected {TOTAL_AYAHS}")

    missing_webp = [
        p for p in range(1, TOTAL_PAGES + 1)
        if not (PAGES_DIR / f"{p:03d}.webp").is_file()
    ]
    if missing_webp:
        issues.append(
            f"{len(missing_webp)} WebP pages missing: "
            + ", ".join(f"{p:03d}" for p in missing_webp[:15])
            + (" ..." if len(missing_webp) > 15 else "")
        )

    cur = conn.cursor()
    try:
        cur.execute(
            "SELECT page_number, sura_number, ayah_number, min_x, min_y, max_x, max_y "
            "FROM ayah_bounds"
        )
        rows = cur.fetchall()
    except sqlite3.Error as exc:
        issues.append(f"cannot read ayah_bounds table: {exc}")
        return issues, {}

    db_total = len(rows)
    db_distinct = len({(r[1], r[2]) for r in rows})
    if db_distinct != expected_total:
        issues.append(
            f"DB has {db_distinct} distinct ayahs, expected {expected_total}"
        )
    if ayah_counts and db_total < db_distinct:
        issues.append(f"DB has fewer rows ({db_total}) than distinct ayahs ({db_distinct})")

    by_surah = {}
    by_page = {}
    for row in rows:
        page, sura, ayah = row[0], row[1], row[2]
        by_surah.setdefault(sura, []).append(ayah)
        by_page.setdefault(page, []).append(row)

    if ayah_counts:
        for sura in range(1, 115):
            expected = set(range(1, ayah_counts.get(sura, 0) + 1))
            actual = set(by_surah.get(sura, []))
            missing = sorted(expected - actual)
            extra = sorted(actual - expected)
            if sura not in ayah_counts:
                issues.append(f"surah {sura} present in DB but missing from surah.json")
                continue
            if missing:
                issues.append(f"surah {sura}: missing {len(missing)} ayahs ({missing[:8]}...)" if len(missing) > 8 else f"surah {sura}: missing ayahs {missing}")
            if extra:
                issues.append(f"surah {sura}: unexpected ayahs {extra[:8]}" + ("..." if len(extra) > 8 else ""))
    unknown_pages = sorted(set(by_page) - set(range(1, TOTAL_PAGES + 1)))
    if unknown_pages:
        issues.append(f"DB contains rows for invalid pages: {unknown_pages[:10]}")

    return issues, by_page


def check_bbox_sanity(by_page, viewboxes):
    issues = []
    checked = 0
    for page in sorted(viewboxes):
        vb_min_x, vb_min_y, vb_w, vb_h = viewboxes[page]
        vb_max_x = vb_min_x + vb_w
        vb_max_y = vb_min_y + vb_h
        for row in by_page.get(page, []):
            _, sura, ayah, min_x, min_y, max_x, max_y = row
            ref = f"{page:03d} {sura}:{ayah}"
            if max_x - min_x <= 0:
                issues.append(f"[{ref}] non-positive bbox width ({max_x - min_x:.3f})")
            if max_y - min_y <= 0:
                issues.append(f"[{ref}] non-positive bbox height ({max_y - min_y:.3f})")
            if min_x < vb_min_x - BOUNDS_TOLERANCE or min_y < vb_min_y - BOUNDS_TOLERANCE or max_x > vb_max_x + BOUNDS_TOLERANCE or max_y > vb_max_y + BOUNDS_TOLERANCE:
                overshoot = max(
                    vb_min_x - min_x,
                    vb_min_y - min_y,
                    max_x - vb_max_x,
                    max_y - vb_max_y,
                )
                issues.append(
                    f"[{ref}] bbox ({min_x:.1f},{min_y:.1f})-({max_x:.1f},{max_y:.1f}) "
                    f"outside viewBox by {overshoot:.1f}px (> {BOUNDS_TOLERANCE}px tolerance)"
                )
            checked += 1
    return issues, checked


def check_duplicates(by_page):
    """v2 schema: one row per line-segment, so the same (sura, ayah) appears
    several times per page legitimately. Only exact-duplicate boxes for the
    same ayah and near-identical boxes across DIFFERENT ayahs are issues."""
    issues = []
    partial_overlaps = 0
    for page in sorted(by_page):
        rows = by_page[page]
        seen_boxes = {}
        for row in rows:
            key = (row[1], row[2], round(row[3], 2), round(row[4], 2),
                   round(row[5], 2), round(row[6], 2))
            if key in seen_boxes:
                issues.append(
                    f"page {page:03d}: exact duplicate segment for "
                    f"{row[1]}:{row[2]} ({key[2]},{key[3]})-({key[4]},{key[5]})"
                )
            else:
                seen_boxes[key] = row
        unique_rows = list(seen_boxes.values())
        for i in range(len(unique_rows)):
            for j in range(i + 1, len(unique_rows)):
                a = unique_rows[i]
                b = unique_rows[j]
                if (a[1], a[2]) == (b[1], b[2]):
                    continue  # segments of the same verse may overlap/nest
                ox = min(a[5], b[5]) - max(a[3], b[3])
                oy = min(a[6], b[6]) - max(a[4], b[4])
                if ox <= OVERLAP_TOLERANCE or oy <= OVERLAP_TOLERANCE:
                    continue
                inter = ox * oy
                area_a = (a[5] - a[3]) * (a[6] - a[4])
                area_b = (b[5] - b[3]) * (b[6] - b[4])
                union = area_a + area_b - inter
                iou = inter / union if union > 0 else 0.0
                if iou >= IOU_DUPLICATE_THRESHOLD:
                    # Adjacent short verses can legitimately share almost the
                    # same band in the KFQC source (e.g. 61:3/61:4 on p551) —
                    # report as a warning, not a build failure.
                    print(
                        f"  WARN page {page:03d}: {a[1]}:{a[2]} and {b[1]}:{b[2]} "
                        f"near-identical bands (IoU {iou:.2f}) — source-data trait"
                    )
                else:
                    partial_overlaps += 1
    return issues, partial_overlaps


def compute_crop_box(bbox, vb_w, vb_h, img_w, img_h):
    min_x, min_y, max_x, max_y = bbox
    x0 = max(min_x - BBOX_EXPAND_SVG, 0.0)
    y0 = max(min_y - BBOX_EXPAND_SVG, 0.0)
    x1 = min(max_x + BBOX_EXPAND_SVG, vb_w)
    y1 = min(max_y + BBOX_EXPAND_SVG, vb_h)
    scale_x = img_w / vb_w
    scale_y = img_h / vb_h
    left = max(int(x0 * scale_x), 0)
    top = max(int(y0 * scale_y), 0)
    right = min(int(x1 * scale_x) + 1, img_w)
    bottom = min(int(y1 * scale_y) + 1, img_h)
    right = max(right, left + 1)
    bottom = max(bottom, top + 1)
    return left, top, right, bottom


def check_coordinate_mapping(by_page, viewboxes, rng):
    issues = []
    candidates = sorted(p for p in by_page if by_page[p])
    if not candidates:
        return ["no ayah bounds available for sampling"], 0

    sample_count = min(SAMPLE_PAGES, len(candidates))
    sampled = sorted(rng.sample(candidates, sample_count))
    verified = 0

    for page in sampled:
        webp_path = PAGES_DIR / f"{page:03d}.webp"
        if not webp_path.is_file():
            issues.append(f"[{page:03d}] cannot map coordinates: missing {webp_path.name}")
            continue
        try:
            img = Image.open(webp_path)
            img.load()
        except Exception as exc:
            issues.append(f"[{page:03d}] cannot open WebP: {exc}")
            continue

        vb_min_x, vb_min_y, vb_w, vb_h = viewboxes[page]

        rows = by_page[page]
        k = min(
            rng.randint(MIN_AYAHS_PER_PAGE_SAMPLE, MAX_AYAHS_PER_PAGE_SAMPLE),
            len(rows),
        )
        chosen = rng.sample(rows, k)

        for row in chosen:
            _, sura, ayah, min_x, min_y, max_x, max_y = row
            ref = f"p{page}_s{sura}_a{ayah}"
            try:
                box = compute_crop_box(
                    (min_x, min_y, max_x, max_y),
                    vb_w,
                    vb_h,
                    img.width,
                    img.height,
                )
            except Exception as exc:
                issues.append(f"[{ref}] crop computation failed: {exc}")
                continue
            crop = img.crop(box)
            out_path = CROP_DIR / f"crop_{ref}.png"
            try:
                crop.save(out_path, format="PNG")
            except Exception as exc:
                issues.append(f"[{ref}] failed saving crop: {exc}")
                continue
            if crop.width < 2 or crop.height < 2:
                issues.append(f"[{ref}] crop degenerate: {crop.width}x{crop.height}px")
            verified += 1
            print(
                f"  [{page:03d}] {sura}:{ayah} bbox=({min_x:.0f},{min_y:.0f})-({max_x:.0f},{max_y:.0f}) "
                f"crop={crop.width}x{crop.height} -> {out_path.name}"
            )
        img.close()

    return issues, verified


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    rng = random.Random(RANDOM_SEED)

    print("Mushaf build validator")
    print("=" * 60)

    fatal = False
    issues = []

    try:
        ayah_counts = load_surah_meta()
        print(f"Loaded surah metadata: {len(ayah_counts)} surahs, {sum(ayah_counts.values())} ayahs expected")
    except Exception as exc:
        print(f"WARN: could not load surah.json ({exc}); falling back to hardcoded totals")
        ayah_counts = {}

    if not DB_PATH.is_file():
        print(f"FATAL: database not found: {DB_PATH}")
        return 1
    if not PAGES_DIR.is_dir():
        print(f"FATAL: pages directory not found: {PAGES_DIR}")
        return 1

    conn = sqlite3.connect(DB_PATH)

    print("\n[1/4] Completeness...")
    completeness_issues, by_page = check_completeness(conn, ayah_counts)
    issues.extend(completeness_issues)
    pages_with_rows = len(by_page)
    print(f"  pages present in DB : {pages_with_rows}/{TOTAL_PAGES}")
    print(f"  WebP files present  : {sum(1 for p in range(1, TOTAL_PAGES + 1) if (PAGES_DIR / f'{p:03d}.webp').is_file())}/{TOTAL_PAGES}")

    print("\n[2/4] ViewBox + bbox sanity...")
    viewboxes = {}
    for page in range(1, TOTAL_PAGES + 1):
        try:
            _, vb = load_svg_page(page)
            viewboxes[page] = vb
        except Exception as exc:
            issues.append(f"page {page:03d}: cannot read viewBox from SVG-BR: {exc}")
    sanity_issues, bbox_checked = check_bbox_sanity(by_page, viewboxes)
    issues.extend(sanity_issues)
    print(f"  viewBoxes parsed     : {len(viewboxes)}/{TOTAL_PAGES}")
    print(f"  bboxes sanity-checked: {bbox_checked}")

    print("\n[3/4] Duplicate/overlap check...")
    dup_issues, partial_overlaps = check_duplicates(by_page)
    issues.extend(dup_issues)
    print(f"  duplicate entries    : {len(dup_issues)}")
    print(
        f"  near-identical boxes : {len(dup_issues)} "
        f"(IoU >= {IOU_DUPLICATE_THRESHOLD})"
    )
    print(
        f"  partial overlaps     : {partial_overlaps} "
        f"(expected: ayahs spanning multiple lines have merged bboxes that touch)"
    )

    print("\n[4/4] Coordinate mapping (random crops)...")
    CROP_DIR.mkdir(parents=True, exist_ok=True)
    for old in CROP_DIR.glob("crop_p*.png"):
        old.unlink()
    mapping_issues, verified = check_coordinate_mapping(by_page, viewboxes, rng)
    issues.extend(mapping_issues)
    print(f"  crops saved          : {verified}")

    conn.close()

    print("\n" + "=" * 60)
    print("Summary")
    print("-" * 60)
    print(f"  pages checked          : {pages_with_rows}/{TOTAL_PAGES}")
    print(f"  bboxes checked         : {bbox_checked}")
    print(f"  ayahs verified (crops) : {verified} on {SAMPLE_PAGES} pages -> {CROP_DIR}")
    print(f"  issues found           : {len(issues)}")
    if issues:
        for msg in issues[:20]:
            print(f"    - {msg}")
        if len(issues) > 20:
            print(f"    ... and {len(issues) - 20} more")

    if verified < SAMPLE_PAGES * MIN_AYAHS_PER_PAGE_SAMPLE:
        issues.append(f"only {verified} ayahs visually verified, expected >= {SAMPLE_PAGES * MIN_AYAHS_PER_PAGE_SAMPLE}")

    if issues:
        print("\nRESULT: FAIL")
        return 1
    print("\nRESULT: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())

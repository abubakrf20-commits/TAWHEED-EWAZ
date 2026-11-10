"""Build ayah_boxes.json: per-page verse highlight rectangles.

Source: hafs/kfqc/json/NNN.json — ayah polygons in each page's native SVG
space. A polygon is a space-separated "x,y" point list (an outline that may
trace several mushaf line bands for long verses). The polygon is rasterized
with Pillow and decomposed back into per-line rects in the rendered WebP
pixel space (build_kfqc_webp.py scale), then written to
assets/quran/mushaf/kfqc/ayah_boxes.json for the reader to draw whole-verse
highlights during playback / navigation.
"""
import json
import math
import os
import re

from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
JSON_DIR = os.path.join(ROOT, "hafs", "kfqc", "json")
SVG_DIR = os.path.join(ROOT, "hafs", "kfqc", "svg")
OUT = os.path.join(ROOT, "assets", "quran", "mushaf", "kfqc", "ayah_boxes.json")
TARGET_WIDTH = int(os.environ.get("KFQC_WIDTH", "1440"))
PAGES = 604


def scale_for(page: str) -> float:
    with open(os.path.join(SVG_DIR, f"{page}.svg"), "rb") as f:
        data = f.read().decode("utf-8", errors="replace")
    m = re.search(r'viewBox="\s*[\d.-]+\s+[\d.-]+\s+([\d.-]+)\s+[\d.-]+"', data)
    return TARGET_WIDTH / float(m.group(1))


def parse_polygon(polygon: str, scale: float):
    """Parse a polygon string into a list of point lists.

    The source json mixes two encodings: pages 1-2 use a plain "x,y x,y ..."
    coordinate list, later pages use an SVG path ("M x y L x y ... Z" with
    several subpaths, one per line band). Both are scaled to rendered px.
    """
    if not polygon:
        return []
    subpaths = []
    if polygon.lstrip().startswith("M"):
        # Split into M..Z subpaths, keeping each subpath's points separate so
        # PIL can fill them independently (a joined list would misconnect).
        parts = re.split(r"M\s*", polygon)
        for part in parts:
            if not part.strip():
                continue
            pts = []
            for num in re.findall(r"([\d.-]+)\s+([\d.-]+)", part):
                pts.append((float(num[0]) * scale, float(num[1]) * scale))
            if pts:
                subpaths.append(pts)
    else:
        pts = []
        for pair in polygon.split():
            x, y = pair.split(",")
            pts.append((float(x) * scale, float(y) * scale))
        subpaths.append(pts)
    return subpaths


def polygon_to_rects(polygon: str, scale: float):
    """Rasterize an ayah polygon and return per-line rects in rendered px."""
    subpaths = parse_polygon(polygon, scale)
    all_pts = [p for sub in subpaths for p in sub]
    if not all_pts:
        return []
    xs = [p[0] for p in all_pts]
    ys = [p[1] for p in all_pts]
    minx, maxx = int(math.floor(min(xs))), int(math.ceil(max(xs)))
    miny, maxy = int(math.floor(min(ys))), int(math.ceil(max(ys)))
    w = maxx - minx
    h = maxy - miny
    if w <= 0 or h <= 0:
        return [[minx, miny, maxx - minx, maxy - miny]]

    img = Image.new("1", (w, h), 0)
    draw = ImageDraw.Draw(img)
    for sub in subpaths:
        draw.polygon(
            [(round(px - minx), round(py - miny)) for px, py in sub], fill=1
        )
    px = img.load()

    def row_runs(y):
        runs = []
        x = 0
        while x < w:
            if px[x, y]:
                x0 = x
                while x < w and px[x, y]:
                    x += 1
                runs.append((x0, x - 1))
            x += 1
        return runs

    rects = []
    y = 0
    while y < h:
        runs = row_runs(y)
        if not runs:
            y += 1
            continue
        x0, x1 = runs[0][0], runs[0][1]
        y1 = y
        while y1 + 1 < h and row_runs(y1 + 1) == runs:
            y1 += 1
        rects.append([minx + x0, miny + y, x1 - x0 + 1, y1 - y + 1])
        y = y1 + 1
    return rects


def main():
    out = {}
    total_rects = 0
    empty = 0
    for i in range(1, PAGES + 1):
        page = f"{i:03d}"
        scale = scale_for(page)
        with open(os.path.join(JSON_DIR, f"{page}.json"), encoding="utf-8") as f:
            entries = json.load(f)
        ayahs = []
        for e in entries:
            rects = polygon_to_rects(e["polygon"], scale)
            if not rects:
                empty += 1
            total_rects += len(rects)
            ayahs.append({
                "s": e["surahNumber"],
                "a": e["ayahNumber"],
                "r": rects,
            })
        out[page] = ayahs
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
    print(f"wrote {OUT} ({os.path.getsize(OUT) / 1024:.0f} KB, "
          f"{total_rects} rects, {empty} ayahs without rects)")


if __name__ == "__main__":
    main()

"""Build the server-hosted KFQC mushaf pages for tools/server_upload/mushaf.

Two theme sets are rendered at KFQC_WIDTH (default 1260) logical pixels:
  * day/   — dark glyphs on a transparent background (the app paints any
             light background color behind them),
  * night/ — the same glyph silhouettes recolored light cream, so the app can
             switch to a dark background while staying readable.

The per-page WebP keeps an alpha channel (lossy + alpha). ayah_boxes.json is
rebuilt in the same pixel space (shared by both themes) together with a small
manifest.json for the app (page count, width, theme list).

Upload the whole mushaf/ directory to a static host (Nginx / S3 / rsync) and
point QF_MUSHAF_BASE in assets/env/quran_api.env at it.

Usage:  python tools/build_kfqc_pages.py
Env:    KFQC_WIDTH (default 1260), KFQC_QUALITY (default 75), JOBS (default 6)
"""
import io
import json
import multiprocessing as mp
import os
import re
import subprocess
import time

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SVG_DIR = os.path.join(ROOT, "hafs", "kfqc", "svg")
JSON_DIR = os.path.join(ROOT, "hafs", "kfqc", "json")
RESVG = os.path.join(ROOT, "tools", "resvg", "resvg.exe")
OUT_DIR = os.path.join(ROOT, "tools", "server_upload", "mushaf")
WIDTH = int(os.environ.get("KFQC_WIDTH", "1260"))
QUALITY = int(os.environ.get("KFQC_QUALITY", "75"))
ALPHA_QUALITY = int(os.environ.get("KFQC_ALPHA_QUALITY", "85"))
JOBS = int(os.environ.get("JOBS", "6"))
PAGES = 604

DAY_COLOR = (244, 232, 212, 255)  # night glyph tint (light cream)


def viewbox_width(page: str) -> float:
    with open(os.path.join(SVG_DIR, f"{page}.svg"), "rb") as f:
        data = f.read().decode("utf-8", errors="replace")
    m = re.search(r'viewBox="\s*[\d.-]+\s+[\d.-]+\s+([\d.-]+)\s+[\d.-]+"', data)
    return float(m.group(1))


def render_webps(args):
    page, = args
    svg = os.path.join(SVG_DIR, f"{page}.svg")
    if not os.path.exists(svg):
        return page, None
    tmp = os.path.join(ROOT, "tools", "server_upload", f"_tmp_{page}.png")
    subprocess.run(
        [RESVG, "-w", str(WIDTH), svg, tmp],
        check=True, capture_output=True,
    )
    im = Image.open(tmp).convert("RGBA")
    os.remove(tmp)

    day_buf = io.BytesIO()
    im.save(day_buf, "WEBP", quality=QUALITY, method=6, alpha_quality=ALPHA_QUALITY)

    alpha = im.split()[3]
    night = Image.new("RGBA", im.size, DAY_COLOR)
    night.putalpha(alpha)
    night_buf = io.BytesIO()
    night.save(night_buf, "WEBP", quality=QUALITY, method=6,
               alpha_quality=ALPHA_QUALITY)

    return page, (day_buf.getvalue(), night_buf.getvalue())


def parse_polygon(polygon, scale):
    """Return a list of point lists (SVG-path or CSV encodings, scaled)."""
    if not polygon:
        return []
    subpaths = []
    if polygon.lstrip().startswith("M"):
        for part in re.split(r"M\s*", polygon):
            if not part.strip():
                continue
            pts = [(float(a) * scale, float(b) * scale)
                   for a, b in re.findall(r"([\d.-]+)\s+([\d.-]+)", part)]
            if pts:
                subpaths.append(pts)
    else:
        pts = []
        for pair in polygon.split():
            x, y = pair.split(",")
            pts.append((float(x) * scale, float(y) * scale))
        subpaths.append(pts)
    return subpaths


def polygon_to_rects(polygon, scale):
    subpaths = parse_polygon(polygon, scale)
    all_pts = [p for sub in subpaths for p in sub]
    if not all_pts:
        return []
    xs = [p[0] for p in all_pts]
    ys = [p[1] for p in all_pts]
    minx, maxx = int(min(xs)), int(max(xs))
    miny, maxy = int(min(ys)), int(max(ys))
    w, h = maxx - minx, maxy - miny
    if w <= 0 or h <= 0:
        return [[minx, miny, maxx - minx, maxy - miny]]
    img = Image.new("1", (w, h), 0)
    from PIL import ImageDraw
    draw = ImageDraw.Draw(img)
    for sub in subpaths:
        draw.polygon([(round(px - minx), round(py - miny)) for px, py in sub],
                     fill=1)
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


def build_ayah_boxes():
    out = {}
    for i in range(1, PAGES + 1):
        page = f"{i:03d}"
        scale = WIDTH / viewbox_width(page)
        with open(os.path.join(JSON_DIR, f"{page}.json"), encoding="utf-8") as f:
            entries = json.load(f)
        out[page] = [
            {"s": e["surahNumber"], "a": e["ayahNumber"],
             "r": polygon_to_rects(e["polygon"], scale)}
            for e in entries
        ]
    return out


def main():
    os.makedirs(os.path.join(OUT_DIR, "day"), exist_ok=True)
    os.makedirs(os.path.join(OUT_DIR, "night"), exist_ok=True)

    print(f"rendering {PAGES} pages at width {WIDTH} (jobs={JOBS})…")
    t0 = time.time()
    pages = [f"{i:03d}" for i in range(1, PAGES + 1)]
    sizes = {}
    with mp.Pool(JOBS) as pool:
        for page, data in pool.imap_unordered(render_webps, [(p,) for p in pages]):
            if data is None:
                print(f"  !! missing {page}")
                continue
            day_bytes, night_bytes = data
            for theme, blob in (("day", day_bytes), ("night", night_bytes)):
                path = os.path.join(OUT_DIR, theme, f"{page}.webp")
                with open(path, "wb") as f:
                    f.write(blob)
            sizes[page] = {
                "day": len(day_bytes),
                "night": len(night_bytes),
            }
            if int(page) % 50 == 0:
                print(f"  {page} … {time.time()-t0:.0f}s")
    print(f"render done in {time.time()-t0:.0f}s")

    boxes = build_ayah_boxes()
    boxes_path = os.path.join(OUT_DIR, "ayah_boxes.json")
    with open(boxes_path, "w", encoding="utf-8") as f:
        json.dump(boxes, f, ensure_ascii=False, separators=(",", ":"))

    day_total = sum(v["day"] for v in sizes.values())
    night_total = sum(v["night"] for v in sizes.values())
    manifest = {
        "version": 2,
        "width": WIDTH,
        "pageCount": PAGES,
        "themes": ["day", "night"],
        "ayahBoxes": "ayah_boxes.json",
        "sizesMB": {
            "day": round(day_total / 1048576, 1),
            "night": round(night_total / 1048576, 1),
        },
        "generatedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    with open(os.path.join(OUT_DIR, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)

    print(f"day   : {day_total/1048576:.1f} MB  avg {day_total/PAGES/1024:.0f} KB/page")
    print(f"night : {night_total/1048576:.1f} MB  avg {night_total/PAGES/1024:.0f} KB/page")
    print(f"boxes : {os.path.getsize(boxes_path)/1024:.0f} KB")
    print(f"output: {OUT_DIR}")


if __name__ == "__main__":
    mp.freeze_support()
    main()
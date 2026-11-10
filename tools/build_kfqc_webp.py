"""Build KFQC Hafs mushaf pages (SVG -> PNG -> WebP) for the app.

Renders every standard mushaf page (001..604) from hafs/kfqc/svg at a width of
1440px, flattens the transparent background onto the app's mushaf cream, and
writes lossy WebP into assets/quran/mushaf/kfqc/NNN.webp.

Also computes the SVG viewBox so callers can scale the per-page ayah polygons
(native SVG space) into the rendered WebP space.
"""
import os
import re
import subprocess
import sys
import concurrent.futures as cf

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SVG_DIR = os.path.join(ROOT, "hafs", "kfqc", "svg")
OUT_DIR = os.path.join(ROOT, "assets", "quran", "mushaf", "kfqc")
RESVG = os.path.join(ROOT, "tools", "resvg", "resvg.exe")
TMP = os.path.join(os.environ.get("TEMP", ROOT), "opencode", "kfqc_build")
TARGET_WIDTH = int(os.environ.get("KFQC_WIDTH", "1440"))
QUALITY = int(os.environ.get("KFQC_QUALITY", "75"))
CREAM = (251, 243, 231)  # matches the app's MushafPalette cream.

PAGES = int(sys.argv[1]) if len(sys.argv) > 1 else 604


def viewbox_size(page: str):
    """Return (width, height) of the SVG's viewBox."""
    with open(os.path.join(SVG_DIR, f"{page}.svg"), "rb") as f:
        data = f.read().decode("utf-8", errors="replace")
    m = re.search(r'viewBox="\s*[\d.-]+\s+[\d.-]+\s+([\d.-]+)\s+([\d.-]+)"', data)
    if not m:
        raise ValueError(f"no viewBox on page {page}")
    return float(m.group(1)), float(m.group(2))


def build_one(page: str):
    os.makedirs(TMP, exist_ok=True)
    png = os.path.join(TMP, f"{page}.png")
    webp = os.path.join(OUT_DIR, f"{page}.webp")
    if os.path.exists(webp):
        return page, "cached"
    subprocess.run(
        [RESVG, "-w", str(TARGET_WIDTH), os.path.join(SVG_DIR, f"{page}.svg"), png],
        check=True,
        capture_output=True,
    )
    im = Image.open(png).convert("RGBA")
    bg = Image.new("RGB", im.size, CREAM)
    bg.paste(im, mask=im.getchannel("A"))
    bg.save(webp, "WEBP", quality=QUALITY, method=6)
    os.remove(png)
    return page, "ok"


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    pages = [f"{i:03d}" for i in range(1, PAGES + 1)]
    sizes = {}
    with cf.ThreadPoolExecutor(max_workers=6) as ex:
        for i, (page, status) in enumerate(
            ex.map(build_one, pages), start=1
        ):
            sizes[page] = os.path.getsize(os.path.join(OUT_DIR, f"{page}.webp"))
            if i % 50 == 0 or i == PAGES:
                print(f"{i}/{PAGES} done", flush=True)
    total = sum(sizes.values())
    print(f"TOTAL: {total / 1_048_576:.1f} MB across {PAGES} pages "
          f"(avg {total / PAGES / 1024:.1f} KB/page)")


if __name__ == "__main__":
    main()
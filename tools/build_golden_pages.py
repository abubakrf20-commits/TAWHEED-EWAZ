"""Combine the Golden Mushab (Madina print) 15 line-slices per page into 604
full-page PNGs and copy the original package into tools/mushaf_source/.

Source material lives in the adb-extracted fahadv3.zip (Golden Mushab app).
The output is NOT used by the app — it is kept separately so the owner can
upload the real mushaf pages to their own server later.
"""
import os
import shutil

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SRC = os.path.join(ROOT, "tools", "mushaf_source", "golden_mushab")
# Location of the adb-pulled fahadv3 extraction:
EXTRACTED = os.path.join(
    os.environ.get("TEMP", ROOT), "opencode", "golden", "fahad_extract", "fahadv3"
)
ZIP_SRC = os.path.join(
    os.environ.get("TEMP", ROOT), "opencode", "golden", "base_extract",
    "assets", "fahadv3.zip",
)

LINE_W, LINE_H = 1440, 232
LINES = 15


def build_pages():
    os.makedirs(os.path.join(SRC, "pages"), exist_ok=True)
    for i in range(1, 605):
        page_dir = os.path.join(EXTRACTED, str(i))
        out = os.path.join(SRC, "pages", f"{i:03d}.png")
        if os.path.exists(out):
            continue
        page = Image.new("RGBA", (LINE_W, LINE_H * LINES), (0, 0, 0, 0))
        for line in range(1, LINES + 1):
            p = os.path.join(page_dir, f"{line}.png")
            if not os.path.exists(p) or os.path.getsize(p) == 0:
                continue
            slice_img = Image.open(p).convert("RGBA")
            page.paste(slice_img, (0, (line - 1) * LINE_H))
        # The source slices are palette (P) PNGs; quantizing the composite
        # keeps files near the original size instead of ~2.4x larger RGBA.
        page = page.quantize(
            colors=256, method=Image.Quantize.FASTOCTREE,
            dither=Image.Dither.NONE,
        )
        page.save(out, optimize=True)
        if i % 100 == 0:
            print(f"{i}/604", flush=True)
    print("pages done")


def copy_zip():
    os.makedirs(SRC, exist_ok=True)
    dest = os.path.join(SRC, "fahadv3.zip")
    if not os.path.exists(dest):
        shutil.copy2(ZIP_SRC, dest)
        print(f"copied fahadv3.zip -> {dest}")


if __name__ == "__main__":
    build_pages()
    copy_zip()
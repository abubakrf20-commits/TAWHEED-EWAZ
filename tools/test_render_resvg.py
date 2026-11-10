"""Test resvg_py rendering of SVG-BR files."""
import brotli, resvg_py, os, sys, io, re
from PIL import Image
sys.stdout.reconfigure(encoding='utf-8')

os.makedirs("tools/test_render", exist_ok=True)

for page in [3, 50, 300, 604]:
    with open(f"hafs/kfqc/svg-br/{page:03d}.svg.br", "rb") as f:
        svg_bytes = f.read()
    svg_text = brotli.decompress(svg_bytes).decode("utf-8")
    
    target_w = 1080
    png_data = resvg_py.svg_to_bytes(svg_string=svg_text, width=target_w, background="#ffffff")
    img = Image.open(io.BytesIO(png_data))
    out_path = f"tools/test_render/page_{page:03d}.png"
    img.save(out_path)
    fsize = os.path.getsize(out_path)
    print(f"Page {page:03d}: {img.size[0]}x{img.size[1]}, {fsize:,} bytes")

# Also page 1 (ornamental)
with open(f"hafs/kfqc/svg-br/001.svg.br", "rb") as f:
    svg_bytes = f.read()
svg_text = brotli.decompress(svg_bytes).decode("utf-8")
png_data = resvg_py.svg_to_bytes(svg_string=svg_text, width=1080, background="#ffffff")
img = Image.open(io.BytesIO(png_data))
img.save("tools/test_render/page_001.png")
fsize = os.path.getsize("tools/test_render/page_001.png")
print(f"Page 001: {img.size[0]}x{img.size[1]}, {fsize:,} bytes")

print("\nDone! Check tools/test_render/")

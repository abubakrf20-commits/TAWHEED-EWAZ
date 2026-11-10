"""Test cairosvg rendering of SVG-BR files."""
import brotli, cairosvg, os, sys, io
from PIL import Image
sys.stdout.reconfigure(encoding='utf-8')

os.makedirs("tools/test_render", exist_ok=True)

for page in [1, 3, 50, 300, 604]:
    with open(f"hafs/kfqc/svg-br/{page:03d}.svg.br", "rb") as f:
        svg_bytes = f.read()
    svg_text = brotli.decompress(svg_bytes).decode("utf-8")
    
    # Remove the ayahPolygon paths (they have fill-opacity=0 anyway, but let's be clean)
    # Actually keep them - they're transparent so won't affect rendering
    
    # Render at width 1080 (standard mobile)
    png_data = cairosvg.svg2png(bytestring=svg_text.encode("utf-8"), output_width=1080)
    
    img = Image.open(io.BytesIO(png_data))
    out_path = f"tools/test_render/page_{page:03d}.png"
    img.save(out_path)
    fsize = os.path.getsize(out_path)
    print(f"Page {page:03d}: {img.size[0]}x{img.size[1]}, {fsize:,} bytes")

print("\nDone! Check tools/test_render/")

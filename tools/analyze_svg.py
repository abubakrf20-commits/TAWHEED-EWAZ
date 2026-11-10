import brotli, re, os

pages = [1, 50, 100, 200, 300, 400, 500, 604]
for p in pages:
    with open(f'hafs/kfqc/svg-br/{p:03d}.svg.br', 'rb') as f:
        dec = brotli.decompress(f.read()).decode('utf-8')
    groups = re.findall(r'<g[^>]*id="([^"]+)"', dec)
    imgs = re.findall(r'<image[^>]*', dec)
    texts = re.findall(r'<text[^>]*', dec)
    paths = len(re.findall(r'<path ', dec))
    print(f'page {p:3d}: {len(dec)/1024:.0f}KB, {paths} paths, groups={groups}, images={len(imgs)}, texts={len(texts)}')

# Show full structure of page 100
with open('hafs/kfqc/svg-br/100.svg.br', 'rb') as f:
    dec = brotli.decompress(f.read()).decode('utf-8')

print("\n=== Page 100 structure ===")
print(f'Total size: {len(dec)} bytes')
# Find all named groups
named = re.findall(r'id="([^"]+)"', dec)
print(f'Named IDs: {named}')
# Check for images
imgs = re.findall(r'<image[^>]*href="([^"]*)"[^>]*/>', dec)
if not imgs:
    imgs = re.findall(r'<image[^>]*xlink:href="([^"]*)"[^>]*/>', dec)
print(f'Image hrefs: {imgs[:5]}')
# Show ayah markers count
ayah_markers = dec.count('ayah_number')
print(f'ayah_number references: {ayah_markers}')
# Show the ayah marker section
start = dec.find('ayah_markers')
if start > 0:
    print(f'ayah_markers section starts at char {start}')
    snippet = dec[start:start+500]
    print(snippet[:300])

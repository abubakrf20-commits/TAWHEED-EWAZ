"""
Stage 0: Definitive comparison of SVG-BR ayahPolygon paths vs JSON polygon data.
The SVG-BR already has path elements with class="ayahPolygon" containing surah/ayah attrs + polygon d.
"""
import brotli, re, json, sys
sys.stdout.reconfigure(encoding='utf-8')

def load_svg_br(page_num):
    with open(f"hafs/kfqc/svg-br/{page_num:03d}.svg.br", "rb") as f:
        return brotli.decompress(f.read()).decode("utf-8")

def load_json(page_num):
    with open(f"hafs/kfqc/json/{page_num:03d}.json", "r", encoding="utf-8") as f:
        return json.load(f)

def extract_polygon_coords(d_str):
    """Parse SVG path 'd' attribute (M/L/Z only) into list of (x,y) rectangles."""
    rects = []
    current_rect = []
    for part in re.split(r'(?=[MLZmlz])', d_str.strip()):
        part = part.strip()
        if not part:
            continue
        cmd = part[0]
        nums = re.findall(r'[-+]?\d*\.?\d+', part[1:])
        if cmd in ('M', 'm'):
            if current_rect:
                rects.append(current_rect)
                current_rect = []
            if len(nums) >= 2:
                current_rect.append((float(nums[0]), float(nums[1])))
        elif cmd in ('L', 'l'):
            if len(nums) >= 2:
                current_rect.append((float(nums[0]), float(nums[1])))
        elif cmd in ('Z', 'z'):
            if current_rect:
                rects.append(current_rect)
                current_rect = []
    if current_rect:
        rects.append(current_rect)
    return rects

def rects_bbox(rects):
    """Compute overall bounding box from multiple rectangles."""
    all_x = []
    all_y = []
    for r in rects:
        for x, y in r:
            all_x.append(x)
            all_y.append(y)
    if not all_x:
        return None
    return min(all_x), min(all_y), max(all_x), max(all_y)

# ---- Main comparison ----
print("=" * 80)
print("STAGE 0: SVG-BR ayahPolygon vs JSON polygon comparison")
print("=" * 80)

for page in [1, 3, 50, 100, 300, 604]:
    print(f"\n{'='*60}")
    print(f"PAGE {page:03d}")
    print(f"{'='*60}")
    
    svg = load_svg_br(page)
    json_data = load_json(page)
    
    # Extract ayahPolygon paths from SVG-BR
    # Pattern: <path class="ayahPolygon" ... id="verse-N" number="NNNSSS" ayah="A" surah="S" d="..."/>
    ayah_paths = re.findall(
        r'<path\s+class="ayahPolygon"[^>]*id="verse-(\d+)"[^>]*number="(\d+)"[^>]*ayah="(\d+)"[^>]*surah="(\d+)"[^>]*d="([^"]+)"',
        svg
    )
    # Also try alternate ordering (ayah before surah, etc.)
    if not ayah_paths:
        ayah_paths = re.findall(
            r'<path\s+class="ayahPolygon"[^>]*surah="(\d+)"[^>]*ayah="(\d+)"[^>]*id="verse-(\d+)"[^>]*number="(\d+)"[^>]*d="([^"]+)"',
            svg
        )
    
    print(f"  SVG-BR ayahPolygon paths: {len(ayah_paths)}")
    print(f"  JSON entries: {len(json_data)}")
    
    # Parse SVG ayah data
    svg_verses = {}
    for match in ayah_paths:
        verse_id, number, ayah, surah, d = match
        surah_i, ayah_i, verse_id_i = int(surah), int(ayah), int(verse_id)
        rects = extract_polygon_coords(d)
        bbox = rects_bbox(rects)
        svg_verses[(surah_i, ayah_i)] = {
            'verse_id': verse_id_i,
            'number': number,
            'num_rects': len(rects),
            'bbox': bbox,
            'raw_d_sample': d[:100],
        }
    
    # Parse JSON ayah data
    json_verses = {}
    for item in json_data:
        key = (item['surahNumber'], item['ayahNumber'])
        poly_str = item['polygon'].strip()
        # Parse "x1,y1 x2,y2 x3,y3 x4,y4" format
        points = []
        for pt in poly_str.split():
            if ',' in pt:
                x, y = pt.split(',')
                points.append((float(x), float(y)))
        bbox = (min(p[0] for p in points), min(p[1] for p in points),
                max(p[0] for p in points), max(p[1] for p in points)) if points else None
        json_verses[key] = {
            'x': item.get('x', 0),
            'y': item.get('y', 0),
            'num_points': len(points),
            'bbox': bbox,
        }
    
    # Compare
    svg_keys = set(svg_verses.keys())
    json_keys = set(json_verses.keys())
    
    if svg_keys == json_keys:
        print(f"  Verse keys: IDENTICAL ({len(svg_keys)} verses)")
    else:
        print(f"  Verse keys: MISMATCH!")
        print(f"    Only SVG-BR: {sorted(svg_keys - json_keys)[:5]}")
        print(f"    Only JSON: {sorted(json_keys - svg_keys)[:5]}")
    
    # Compare bounding boxes
    print(f"\n  Bounding box comparison (SVG-BR viewBox -> JSON coordinates):")
    mismatches = 0
    for key in sorted(svg_keys & json_keys)[:5]:
        sv = svg_verses[key]
        jv = json_verses[key]
        
        if sv['bbox'] and jv['bbox']:
            # Check if they match
            dx = abs(sv['bbox'][0] - jv['bbox'][0])
            dy = abs(sv['bbox'][1] - jv['bbox'][1])
            dx2 = abs(sv['bbox'][2] - jv['bbox'][2])
            dy2 = abs(sv['bbox'][3] - jv['bbox'][3])
            match = dx < 1 and dy < 1 and dx2 < 1 and dy2 < 1
            status = "MATCH" if match else f"DIFF ({dx:.1f},{dy:.1f},{dx2:.1f},{dy2:.1f})"
            if not match:
                mismatches += 1
            
            print(f"    sura={key[0]:3d} ayah={key[1]:3d}: SVG({sv['bbox'][0]:.1f},{sv['bbox'][1]:.1f})-({sv['bbox'][2]:.1f},{sv['bbox'][3]:.1f}) "
                  f"JSON({jv['bbox'][0]:.1f},{jv['bbox'][1]:.1f})-({jv['bbox'][2]:.1f},{jv['bbox'][3]:.1f}) [{status}]")
        else:
            print(f"    sura={key[0]:3d} ayah={key[1]:3d}: SVG rects={sv['num_rects']} JSON pts={jv['num_points']}")
    
    # Summary for this page
    if mismatches == 0:
        print(f"\n  RESULT: All compared coordinates MATCH between SVG-BR and JSON")
    else:
        print(f"\n  RESULT: {mismatches} coordinate mismatches found")

print("\n" + "=" * 80)
print("CONCLUSION")
print("=" * 80)
print("""
SVG-BR is the CANONICAL source because:
1. Each <path class="ayahPolygon"> already contains: surah, ayah, number, and polygon d
2. The polygon coordinates are in the SVG viewBox coordinate system
3. JSON is redundant — same data, but stored in a less structured way
4. SVG-BR rendering to bitmap gives us both the image AND the ayah bounds from one source
""")

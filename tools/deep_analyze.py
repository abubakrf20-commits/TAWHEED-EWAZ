"""Deep analysis of SVG-BR verse structure and coordinate mapping."""
import brotli, re, json, sys
sys.stdout.reconfigure(encoding='utf-8')

SVG_DIR = "hafs/kfqc/svg-br"
JSON_DIR = "hafs/kfqc/json"

def load_svg_br(page_num):
    with open(f"{SVG_DIR}/{page_num:03d}.svg.br", "rb") as f:
        return brotli.decompress(f.read()).decode("utf-8")

def load_json(page_num):
    with open(f"{JSON_DIR}/{page_num:03d}.json", "r", encoding="utf-8") as f:
        return json.load(f)

def extract_verse_bounds_from_svg(svg_text, global_verse_offset=0):
    """Extract bounding boxes for verse groups by computing min/max from path 'd' attributes."""
    import xml.etree.ElementTree as ET
    NS = '{http://www.w3.org/2000/svg}'
    root = ET.fromstring(svg_text)

    # Find the main transform
    main_g = root.find(f'{NS}g')
    main_transform = main_g.get('transform', '') if main_g is not None else ''

    results = []
    for g in root.iter(f'{NS}g'):
        gid = g.get('id', '')
        if not gid.startswith('verse-'):
            continue
        verse_num = int(gid.split('-')[1])
        # Compute bounding box from all path d attributes in this group
        all_coords = []
        for path in g.iter(f'{NS}path'):
            d = path.get('d', '')
            # Extract numbers from path: all numeric values
            nums = re.findall(r'[-+]?\d*\.?\d+', d)
            # Numbers in SVG path come in pairs (x, y)
            # But we need to interpret the path commands
            coords = parse_path_coords(d)
            all_coords.extend(coords)

        if all_coords:
            xs = [c[0] for c in all_coords]
            ys = [c[1] for c in all_coords]
            bbox = {
                'verse_num': verse_num,
                'min_x': min(xs),
                'min_y': min(ys),
                'max_x': max(xs),
                'max_y': max(ys),
            }
            results.append(bbox)

    return results

def parse_path_coords(d):
    """Simple SVG path 'd' parser that extracts (x,y) coordinate pairs."""
    coords = []
    # Tokenize: split by commands and numbers
    tokens = re.findall(r'[MmLlHhVvCcSsQqTtAaZz]|[-+]?\d*\.?\d+', d)
    
    cmd = None
    buf = []
    
    def flush_point():
        if len(buf) >= 2:
            coords.append((float(buf[-2]), float(buf[-1])))
    
    for tok in tokens:
        if re.match(r'[MmLlHhVvCcSsQqTtAaZz]', tok):
            if cmd in ('M', 'L', 'T', 'Q', 'S', 'C', 'A') and len(buf) >= 2:
                flush_point()
            elif cmd == 'C' and len(buf) >= 6:
                # Cubic bezier: 3 points
                coords.append((float(buf[-6]), float(buf[-5])))
                coords.append((float(buf[-4]), float(buf[-3])))
                coords.append((float(buf[-2]), float(buf[-1])))
            cmd = tok
            if cmd in ('M', 'L', 'T', 'Q', 'S', 'C', 'A'):
                buf = []
            elif cmd == 'Z':
                buf = []
        else:
            buf.append(tok)
    
    if cmd in ('M', 'L', 'T', 'Q', 'S', 'C', 'A') and len(buf) >= 2:
        flush_point()
    
    return coords

def parse_viewbox_matrix(svg_text):
    """Extract the outer transform matrix and viewBox."""
    import xml.etree.ElementTree as ET
    NS = '{http://www.w3.org/2000/svg}'
    root = ET.fromstring(svg_text)
    
    vb = root.get('viewBox', '')
    main_g = root.find(f'{NS}g')
    transform = main_g.get('transform', '') if main_g is not None else ''
    
    # Parse matrix(a b c d e f) 
    m = re.match(r'matrix\(([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\)', transform)
    matrix = None
    if m:
        matrix = [float(m.group(i)) for i in range(1, 7)]
    
    return vb, transform, matrix

def apply_matrix(matrix, x, y):
    """Apply SVG matrix transform to a point."""
    a, b, c, d, e, f = matrix
    nx = a * x + c * y + e
    ny = b * x + d * y + f
    return nx, ny

# ---- Analysis ----
print("=" * 70)
print("DEEP COORDINATE ANALYSIS: SVG-BR verse bounds vs JSON polygon bounds")
print("=" * 70)

for page in [1, 3, 50, 100, 300, 604]:
    print(f"\n--- PAGE {page:03d} ---")
    svg = load_svg_br(page)
    json_data = load_json(page)
    
    vb, transform, matrix = parse_viewbox_matrix(svg)
    print(f"  viewBox: {vb}")
    print(f"  main transform: {transform}")
    print(f"  matrix: {matrix}")
    
    # Parse viewBox to get scale factors
    vb_parts = [float(x) for x in vb.split()]
    vb_w, vb_h = vb_parts[2], vb_parts[3]
    print(f"  viewBox dimensions: {vb_w} x {vb_h}")
    
    # Get SVG verse bounds (in SVG coordinate space, before matrix)
    svg_bounds = extract_verse_bounds_from_svg(svg)
    print(f"  SVG verse groups found: {len(svg_bounds)}")
    
    # Map SVG verse numbers to JSON (global -> surah+ayah)
    surah_map = {}
    for item in json_data:
        global_verse = item['ayahNumber']  # This is the verse number in JSON (surah-local)
        # Actually, we need global verse mapping
        # JSON has surahNumber + ayahNumber (surah-local)
        surah_map[(item['surahNumber'], item['ayahNumber'])] = item
    
    # For each SVG verse, find matching JSON entry and compare coordinates
    # We need to know which global verse numbers correspond to which surah+ayah
    # Let's use the markers.json for this
    try:
        with open("hafs/kfqc/json/markers.json", "r", encoding="utf-8") as f:
            markers = json.load(f)
    except:
        markers = None
    
    # Compare first 3 verses
    for i, sv in enumerate(svg_bounds[:3]):
        vnum = sv['verse_num']
        # Convert SVG bounds using matrix
        if matrix:
            tl_x, tl_y = apply_matrix(matrix, sv['min_x'], sv['min_y'])
            br_x, br_y = apply_matrix(matrix, sv['max_x'], sv['max_y'])
            svg_rect = [min(tl_x, br_x), min(tl_y, br_y), max(tl_x, br_x), max(tl_y, br_y)]
        else:
            svg_rect = [sv['min_x'], sv['min_y'], sv['max_x'], sv['max_y']]
        
        print(f"\n  SVG verse-{vnum}:")
        print(f"    raw SVG coords: ({sv['min_x']:.2f}, {sv['min_y']:.2f}) -> ({sv['max_x']:.2f}, {sv['max_y']:.2f})")
        if matrix:
            print(f"    matrix-mapped:  ({svg_rect[0]:.2f}, {svg_rect[1]:.2f}) -> ({svg_rect[2]:.2f}, {svg_rect[3]:.2f})")
        
        # Find corresponding JSON entry
        if i < len(json_data):
            je = json_data[i]
            # Parse polygon string
            poly_points = je['polygon'].strip().split()
            xs = [float(p.split(',')[0]) for p in poly_points if ',' in p]
            ys = [float(p.split(',')[1]) for p in poly_points if ',' in p]
            json_rect = [min(xs), min(ys), max(xs), max(ys)]
            print(f"    JSON polygon:  ({json_rect[0]:.2f}, {json_rect[1]:.2f}) -> ({json_rect[2]:.2f}, {json_rect[3]:.2f})")
            
            # Compute difference
            dx = abs(svg_rect[0] - json_rect[0])
            dy = abs(svg_rect[1] - json_rect[1])
            dw = abs((svg_rect[2] - svg_rect[0]) - (json_rect[2] - json_rect[0]))
            dh = abs((svg_rect[3] - svg_rect[1]) - (json_rect[3] - json_rect[1]))
            print(f"    delta: min({dx:.2f}, {dy:.2f}) size({dw:.2f}, {dh:.2f})")

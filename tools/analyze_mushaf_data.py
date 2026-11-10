"""Stage 0: Analyze & compare SVG-BR, JSON, and golden mushaf data."""
import brotli, json, os, re, sys
import xml.etree.ElementTree as ET

# Fix Windows encoding
sys.stdout.reconfigure(encoding='utf-8')

SAMPLES = [1, 2, 3, 50, 100, 150, 200, 300, 400, 500, 600, 604]
SVG_DIR = "hafs/kfqc/svg-br"
JSON_DIR = "hafs/kfqc/json"
GOLDEN_DIR = "tools/mushaf_source/golden_mushab/pages"

def load_svg_br(page_num: int) -> str:
    path = f"{SVG_DIR}/{page_num:03d}.svg.br"
    with open(path, "rb") as f:
        return brotli.decompress(f.read()).decode("utf-8")

def load_json(page_num: int) -> list:
    path = f"{JSON_DIR}/{page_num:03d}.json"
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)

def analyze_svg_br(svg_text: str, page_num: int) -> dict:
    """Extract verse elements, their bounding boxes, and line structure."""
    # Parse viewBox
    vb_match = re.search(r'viewBox="([^"]+)"', svg_text)
    viewBox = vb_match.group(1) if vb_match else None

    # Extract all id="verse-XXX" elements
    verse_ids = re.findall(r'id="(verse-\d+)"', svg_text)
    verse_numbers = sorted(set(int(v.split("-")[1]) for v in verse_ids))

    # Extract transform from main <g> that wraps content
    # The SVG has structure: <svg><g transform="matrix(...)"><g id="ayah_markers">...<g id="content">...</g>
    # We need to parse the XML properly
    root = ET.fromstring(svg_text)

    # Find content group and verse groups
    ns = {"svg": "http://www.w3.org/2000/svg", "ayah": "https://quranpedia.net"}

    content_groups = []
    ayah_groups = []

    for g in root.iter("{http://www.w3.org/2000/svg}g"):
        gid = g.get("id", "")
        if gid.startswith("verse-"):
            verse_num = int(gid.split("-")[1])
            # Get all paths in this group and compute bounding box
            paths = []
            for path in g.iter("{http://www.w3.org/2000/svg}path"):
                d = path.get("d", "")
                paths.append(d)

            # Get the transform of this group
            transform = g.get("transform", "none")

            ayah_groups.append({
                "verse_num": verse_num,
                "num_paths": len(paths),
                "transform": transform,
            })

    return {
        "viewBox": viewBox,
        "num_verses": len(verse_numbers),
        "verse_numbers": verse_numbers,
        "ayah_groups": ayah_groups,
    }

def analyze_json(json_data: list) -> dict:
    """Analyze the JSON ayah bounds."""
    verses = {}
    for item in json_data:
        key = (item["surahNumber"], item["ayahNumber"])
        if key not in verses:
            verses[key] = []
        verses[key].append(item)

    return {
        "num_entries": len(json_data),
        "num_unique_verses": len(verses),
        "verse_keys": sorted(verses.keys()),
        "sample_polygon_points": len(json_data[0]["polygon"].split()) if json_data else 0,
    }

# ---- Main Analysis ----
print("=" * 70)
print("STAGE 0: MUSHAF DATA ANALYSIS")
print("=" * 70)

for page in SAMPLES:
    print(f"\n{'='*60}")
    print(f"PAGE {page:03d}")
    print(f"{'='*60}")

    # 1. SVG-BR analysis
    try:
        svg = load_svg_br(page)
        svg_info = analyze_svg_br(svg, page)
        print(f"\n  SVG-BR:")
        print(f"    viewBox: {svg_info['viewBox']}")
        print(f"    verses with id: {svg_info['num_verses']}")
        print(f"    verse numbers: {svg_info['verse_numbers'][:10]}{'...' if len(svg_info['verse_numbers']) > 10 else ''}")
        print(f"    ayah <g> groups: {len(svg_info['ayah_groups'])}")
        for ag in svg_info['ayah_groups'][:3]:
            print(f"      verse-{ag['verse_num']:03d}: {ag['num_paths']} paths, transform={ag['transform'][:50]}")
    except Exception as e:
        print(f"  SVG-BR ERROR: {e}")

    # 2. JSON analysis
    try:
        json_data = load_json(page)
        j_info = analyze_json(json_data)
        print(f"\n  JSON:")
        print(f"    entries: {j_info['num_entries']}, unique verses: {j_info['num_unique_verses']}")
        print(f"    verse keys (sura,ayah): {j_info['verse_keys'][:10]}{'...' if len(j_info['verse_keys']) > 10 else ''}")
        # Show first entry
        if json_data:
            e = json_data[0]
            print(f"    sample: sura={e['surahNumber']} ayah={e['ayahNumber']} polygon_pts={len(e['polygon'].split())}")
    except Exception as e:
        print(f"  JSON ERROR: {e}")

    # 3. Golden mushaf analysis
    try:
        golden_path = f"{GOLDEN_DIR}/{page:03d}.png"
        from PIL import Image
        img = Image.open(golden_path)
        fsize = os.path.getsize(golden_path)
        print(f"\n  Golden PNG:")
        print(f"    size: {img.size}, mode: {img.mode}, filesize: {fsize:,} bytes")
    except Exception as e:
        print(f"  Golden PNG ERROR: {e}")

    # 4. Compare SVG-BR verses vs JSON verses
    if 'svg_info' in dir() and 'j_info' in dir():
        svg_verses = set(svg_info['verse_numbers'])
        json_verses = set(k[1] for k in j_info['verse_keys'])  # ayah numbers only
        surah_map = {}
        for item in json_data:
            surah_map[item['ayahNumber']] = item['surahNumber']

        # Check alignment by looking at surah info from JSON
        if svg_verses == json_verses:
            print(f"\n  ALIGNMENT: ✅ SVG-BR and JSON have same verse numbers")
        else:
            only_svg = svg_verses - json_verses
            only_json = json_verses - svg_verses
            print(f"\n  ALIGNMENT: ⚠️  MISMATCH")
            if only_svg:
                print(f"    Only in SVG-BR: {sorted(only_svg)[:10]}")
            if only_json:
                print(f"    Only in JSON: {sorted(only_json)[:10]}")

print("\n" + "=" * 70)
print("SUMMARY")
print("=" * 70)

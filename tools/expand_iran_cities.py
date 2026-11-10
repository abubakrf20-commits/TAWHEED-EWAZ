"""Merges the fnaysee Iran dataset (897 places) with the app's existing
curated iran_cities.dart (398 cities) into a single comprehensive file.

The existing entries always win on conflict (they are curated); dataset
entries are added when they don't already exist in the same province either
by exact name or by coordinate proximity (<2 km).
"""
import json
import math
import re
import sys

sys.stdout.reconfigure(encoding="utf-8", errors="backslashreplace")

ALISABET_CITIES = "tools/alisabet.json"
ALISABET_PROVINCES = "tools/alisabet_provinces.json"
FNAYSEE = "tools/fnaysee.json"
DART_SRC = "lib/features/prayer/data/iran_cities.dart"
DART_DST = "lib/features/prayer/data/iran_cities.dart"

# --------------------------------------------------------------------------
# 1. Load datasets (AliSabet: 1119 cities with coordinates; fnaysee: 897)
# --------------------------------------------------------------------------
ali_cities = json.load(open(ALISABET_CITIES, encoding="utf-8"))
ali_provinces = {
    p["id"]: p["name"] for p in json.load(open(ALISABET_PROVINCES, encoding="utf-8"))
}
print("alisabet cities:", len(ali_cities))

ds_cities = json.load(open(FNAYSEE, encoding="utf-8"))["DocumentElement"]["cities"]
print("fnaysee entries:", len(ds_cities))


def norm(s: str) -> str:
    return re.sub(r"\s+", " ", s.strip().replace("\u200c", " ")).strip()


# 2. Parse the existing dart file into {province: [(name, lat, lng)]}
src = open(DART_SRC, encoding="utf-8").read()
existing = {}  # province -> list of (name, lat, lng)
current_province = None
for line in src.splitlines():
    pm = re.search(r"IranProvince\(name: '([^']+)'", line)
    if pm:
        current_province = pm.group(1)
        existing.setdefault(current_province, [])
        continue
    cm = re.search(r"IranCity\('([^']+)',\s*([\d.]+),\s*([\d.]+)\)", line)
    if cm and current_province:
        existing[current_province].append(
            (cm.group(1), float(cm.group(2)), float(cm.group(3)))
        )

total_existing = sum(len(v) for v in existing.values())
print("existing entries:", total_existing, "in", len(existing), "provinces")


def hav(lat1, lng1, lat2, lng2):
    r = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp, dl = math.radians(lat2 - lat1), math.radians(lng2 - lng1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


# Province name normalization for the dataset (fix trailing spaces etc.)
def ds_province(p):
    return norm(p)


# Build a lookup of existing entries per province for dedupe.
existing_by_prov = {norm(p): v for p, v in existing.items()}

# Existing province display names (keep original spelling).
province_display = {norm(p): p for p in existing}

def add_city(name, prov, lat, lng):
    """Adds a city to the merged structure if it isn't already there (by name
    or proximity within the same province). Returns True when added."""
    name = norm(name)
    prov = norm(prov)
    if not name:
        return False
    bucket = existing_by_prov.setdefault(prov, [])
    if prov not in province_display:
        province_display[prov] = prov
        existing.setdefault(prov, [])
    if any(norm(n) == name for n, _, _ in bucket):
        return False
    # Only treat truly identical points (<0.5 km) as duplicates. County-style
    # names sometimes sit at their seat town's coordinates (e.g. سوادکوه شمالی
    # at شیرگاه); keeping both lets the resolver pick the real town name when
    # the user is exactly there.
    if any(hav(lat, lng, la, lo) < 0.5 for _, la, lo in bucket):
        return False
    bucket.append((name, lat, lng))
    return True


added = 0
skipped = 0
# 1) AliSabet dataset (most complete, 1119 cities with coordinates).
for c in ali_cities:
    prov = ali_provinces.get(int(c["provinceId"]), "")
    if not prov:
        skipped += 1
        continue
    if add_city(c["name"], prov, float(c["latitude"]), float(c["longitude"])):
        added += 1
    else:
        skipped += 1

# 2) fnaysee dataset (extra small towns not in AliSabet).
for c in ds_cities:
    if add_city(
        c["city"],
        ds_province(c["state"]),
        float(c["latitude"]),
        float(c["longitude"]),
    ):
        added += 1
    else:
        skipped += 1

print("added from datasets:", added)
print("skipped (duplicate/near-duplicate):", skipped)

# Dedupe each province's merged list: first by exact name, then by
# coordinate proximity (<0.5 km). Existing entries come first, so they win.
for prov, cities in existing.items():
        deduped = []
        for city in cities:
            if any(norm(city[0]) == norm(o[0]) for o in deduped):
                continue
            if any(hav(city[1], city[2], o[1], o[2]) < 0.5 for o in deduped):
                continue
            deduped.append(city)
        existing[prov] = deduped

final_total = sum(len(v) for v in existing.values())
print("final total entries:", final_total)

# --------------------------------------------------------------------------
# 3. Write the dart file
# --------------------------------------------------------------------------
lines = [
    "class IranProvince {",
    "  final String name;",
    "  final List<IranCity> cities;",
    "  const IranProvince({required this.name, required this.cities});",
    "}",
    "",
    "class IranCity {",
    "  final String name;",
    "  final double lat;",
    "  final double lng;",
    "  const IranCity(this.name, this.lat, this.lng);",
    "}",
    "",
    "const List<IranProvince> iranProvinces = [",
]

# Order provinces: keep the order of the original file, then new ones appended.
ordered_provinces = []
for p in existing_by_prov:
    if p not in ordered_provinces:
        ordered_provinces.append(p)

for prov in ordered_provinces:
    cities = existing[prov]
    lines.append(f"  IranProvince(name: '{province_display[prov]}', cities: [")
    for name, lat, lng in cities:
        lines.append(f"    IranCity('{name}', {lat:.4f}, {lng:.4f}),")
    lines.append("  ]),")

lines.append("];")
lines.append("")

open(DART_DST, "w", encoding="utf-8").write("\n".join(lines))
print("written:", DART_DST, "lines:", len(lines))

import json, sys
sys.stdout.reconfigure(encoding='utf-8')

with open('hafs/kfqc/json/surah.json', 'r', encoding='utf-8') as f:
    surah_data = json.load(f)
print("=== surah.json ===")
print(f"Type: {type(surah_data).__name__}, Length: {len(surah_data)}")
if isinstance(surah_data, list):
    for s in surah_data[:3]:
        print(f"  {s}")
elif isinstance(surah_data, dict):
    for k in list(surah_data.keys())[:3]:
        print(f"  {k}: {surah_data[k]}")

with open('hafs/kfqc/json/markers.json', 'r', encoding='utf-8') as f:
    markers = json.load(f)
print(f"\n=== markers.json ===")
print(f"Type: {type(markers).__name__}, Length: {len(markers)}")
if isinstance(markers, list):
    for m in markers[:3]:
        print(f"  {m}")
elif isinstance(markers, dict):
    for k in list(markers.keys())[:3]:
        print(f"  {k}: {markers[k]}")

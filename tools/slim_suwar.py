"""Slims qcf_quran_lite suwar.dart to only the fields the app uses.

The original surah entries carry huge `surahInfo` / `surahNames` tafsir blobs
that nothing in the app reads. This keeps id/name/aya/english/place/arabic.
"""
import json
import sys

src_path = sys.argv[1]
dst_path = sys.argv[2]

src = open(src_path, encoding="utf-8").read()
body = src.split("const List surah = [", 1)[1].rsplit("];", 1)[0]

KEEP = {"id", "name", "aya", "english", "place", "arabic"}
entries = []
current = {}
for raw_line in body.splitlines():
    line = raw_line.strip().rstrip(",")
    if line == "{":
        current = {}
        continue
    if line == "}":
        if current:
            entries.append(current)
        continue
    if ":" not in line:
        continue
    key, _, value = line.partition(":")
    key = key.strip().strip('"')
    value = value.strip()
    if key not in KEEP:
        continue
    if value.startswith('"'):
        # Keep as JSON string (re-encode safely).
        current[key] = json.loads(value)
    else:
        current[key] = int(value)

print("entries:", len(entries))
out_lines = ["const List surah = ["]
for e in entries:
    out_lines.append("  " + json.dumps(e, ensure_ascii=False) + ",")
out_lines.append("];")
out_lines.append("")
open(dst_path, "w", encoding="utf-8").write("\n".join(out_lines))
print("written:", dst_path)

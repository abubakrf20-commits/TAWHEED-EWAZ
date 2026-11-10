# -*- coding: utf-8 -*-
"""Build full hadith-id -> category mapping from hadeethenc.com."""
import json
import re
import sys
import time
import urllib.request

UA = {"User-Agent": "Mozilla/5.0"}
BASE = "https://hadeethenc.com/fa"


def fetch(url):
    return urllib.request.urlopen(urllib.request.Request(
        url, headers=UA), timeout=40).read().decode("utf-8", "ignore")


MAIN_NAMES = {
    1: "قرآن و علوم قرآنی",
    2: "حدیث و علوم حدیث",
    3: "عقیده",
    4: "فقه و اصول",
    5: "فضائل و آداب",
    6: "دعوت و احتساب",
    7: "سیرت و تاریخ",
}

# ── discover subcategories from each main page ───────────────────
subs = {}          # sub_id -> (main_id, name)
for mid, mname in MAIN_NAMES.items():
    html = fetch(f"{BASE}/browse/category/{mid}")
    for m in re.finditer(
            r'<a[^>]+href="(?:https://hadeethenc\.com)?'
            r'/fa/browse/category/(\d+)"[^>]*>([\s\S]*?)</a>', html):
        sid = int(m.group(1))
        if sid <= 7:
            continue
        label = re.sub(r"<[^>]+>", "", m.group(2)).strip()
        # strip trailing count "(12)"
        clean = re.sub(r"\s*\(\d+\)\s*$", "", label)
        if clean and "فارسی" not in clean and "-" not in clean[:4]:
            subs[sid] = (mid, clean)
    print(f"main {mid} {mname}: subs so far {len(subs)}")
    time.sleep(0.4)

print("\nsubcategories:")
for sid in sorted(subs):
    print(f"  {sid}: [{subs[sid][0]}] {subs[sid][1]}")

# ── collect hadith ids per subcategory ───────────────────────────
mapping = {}       # hadith_id -> {"main": int, "sub": int}
per_sub = {}
for sid, (mid, name) in sorted(subs.items()):
    html = fetch(f"{BASE}/browse/category/{sid}")
    ids = [int(x) for x in re.findall(r"/fa/browse/hadith/(\d+)", html)]
    ids = sorted(set(ids))
    per_sub[sid] = len(ids)
    for i in ids:
        mapping[i] = {"main": mid, "sub": sid}
    print(f"sub {sid} ({name}): {len(ids)}")
    time.sleep(0.4)

covered = len(mapping)
json.dump({"main": MAIN_NAMES, "subs": {str(k): v for k, v in subs.items()},
           "map": {str(k): v for k, v in mapping.items()},
           "per_sub": {str(k): v for k, v in per_sub.items()}},
          open("tools/_enc_cat_map.json", "w", encoding="utf-8"),
          ensure_ascii=False)
print(f"\nunique hadiths mapped: {covered}")

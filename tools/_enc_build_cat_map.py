# -*- coding: utf-8 -*-
"""Map every hadeethenc hadith id to its main category (1..7)."""
import json
import re
import sys
import urllib.request

CATS = {
    1: "قرآن و علوم قرآنی",
    2: "حدیث و علوم حدیث",
    3: "عقیده",
    4: "فقه و اصول",
    5: "فضائل و آداب",
    6: "دعوت و احتساب",
    7: "سیرت و تاریخ",
}

UA = {"User-Agent": "Mozilla/5.0"}


def fetch(url):
    return urllib.request.urlopen(urllib.request.Request(
        url, headers=UA), timeout=40).read().decode("utf-8", "ignore")


mapping = {}   # hadith_id -> cat_no
per_cat = {}
for cat in CATS:
    url = f"https://hadeethenc.com/fa/browse/category/{cat}"
    html = fetch(url)
    # JSON-LD ItemLists on category pages
    ids = []
    for m in re.finditer(
            r'<script type="application/ld\+json">([\s\S]*?)</script>', html):
        try:
            data = json.loads(m.group(1))
        except Exception:
            continue
        graph = data.get("@graph", [data])
        for node in graph:
            if node.get("@type") != "ItemList":
                continue
            for el in node.get("itemListElement", []):
                u = el.get("url", "") if isinstance(el, dict) else ""
                mm = re.search(r"/hadith/(\d+)", u)
                if mm:
                    ids.append(int(mm.group(1)))
    # fallback: direct links in HTML
    if not ids:
        ids = [int(x) for x in re.findall(r"/fa/browse/hadith/(\d+)", html)]
    ids = sorted(set(ids))
    per_cat[cat] = len(ids)
    print(f"cat {cat} {CATS[cat]}: {len(ids)} hadiths")
    for i in ids:
        mapping.setdefault(i, cat)  # keep first (main) category

print("\ntotal unique:", len(mapping))
json.dump({"cats": CATS, "map": {str(k): v for k, v in mapping.items()}},
          open("tools/_enc_cat_map.json", "w", encoding="utf-8"),
          ensure_ascii=False)
print("saved tools/_enc_cat_map.json")

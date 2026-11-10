# -*- coding: utf-8 -*-
"""Convert QuranEnc Arabic tafsir JSON files to sqlite .db.gz (schema: contents(sura, ayah, text))."""
import gzip
import json
import os
import re
import sqlite3
import sys

TAFSIR_DIR = os.path.join(os.path.dirname(__file__), "..", "TAWHEED-EWAZ", "tafsir")
CATALOG = os.path.join(os.path.dirname(__file__), "..", "TAWHEED-EWAZ", "quran-content.json")

# distinctive substring -> (latin id, display name)
MAPPING = [
    ("الواحدي", "asbab_nuzul", "أسباب النزول - الواحدي"),
    ("الشنقيطي", "adwa_albayan", "أضواء البيان - الشنقيطي"),
    ("البيضاوي", "baydawi", "أنوار التنزيل - البيضاوي"),
    ("إعراب القرآن", "irab_alquran", "إعراب القرآن"),
    ("التسهيل لعلوم", "tasheel", "التسهيل لعلوم التنزيل - ابن جزي"),
    ("تحرير المعنى", "tahrir_ashur", "تحرير المعنى - ابن عاشور"),
    ("الجلالين", "jalalain", "تفسير الجلالين - المحلي والسيوطي"),
    ("ابن كثير.json", "ibn_kathir", "تفسير القرآن العظيم - ابن كثير"),
    ("جامع البيان", "tabari", "جامع البيان - الطبري"),
    ("صفوة التفاسير", "safwa_tafasir", "صفوة التفاسير - الصابوني"),
    ("فتح القدير", "fath_qadir", "فتح القدير - الشوكاني"),
    ("مختصر تفسير ابن كثير", "mokhtasar_ibn_kathir", "مختصر تفسير ابن كثير - الصابوني"),
    ("معالم التنزيل", "baghawi", "معالم التنزيل - البغوي"),
]


def main():
    used_ids = set()
    new_entries = []
    for fn in os.listdir(TAFSIR_DIR):
        if not fn.endswith(".json.gz") or fn == "persian_translation.json.gz":
            continue
        path = os.path.join(TAFSIR_DIR, fn)
        with gzip.open(path, "rt", encoding="utf-8") as f:
            doc = json.load(f)
        title = (doc.get("meta") or {}).get("title") or fn
        match = None
        for key, tid, disp in MAPPING:
            if key in fn or key in title:
                match = (tid, disp)
                break
        if not match:
            print("!! no id mapping for:", fn)
            sys.exit(1)
        tid, disp = match
        if tid in used_ids:
            print("!! duplicate id:", tid)
            sys.exit(1)
        used_ids.add(tid)

        db_path = path[: -len(".json.gz")] + ".tmp.db"
        if os.path.exists(db_path):
            os.remove(db_path)
        con = sqlite3.connect(db_path)
        con.execute("CREATE TABLE contents (sura INTEGER, ayah INTEGER, text TEXT)")
        con.executemany(
            "INSERT INTO contents (sura, ayah, text) VALUES (?, ?, ?)",
            [(r["s"], r["a"], r["t"]) for r in doc["data"]],
        )
        con.commit()
        n = con.execute("SELECT COUNT(*) FROM contents").fetchone()[0]
        con.close()

        out_gz = os.path.join(TAFSIR_DIR, tid + ".db.gz")
        with open(db_path, "rb") as src, gzip.open(out_gz, "wb", compresslevel=9) as dst:
            dst.write(src.read())
        os.remove(db_path)
        os.remove(path)

        size_mb = round(os.path.getsize(out_gz) / (1024 * 1024), 2)
        new_entries.append(
            {
                "id": tid,
                "type": "tafsir",
                "name": disp,
                "fileName": tid + ".db",
                "compressed": True,
                "sizeMB": max(size_mb, 0.1),
            }
        )
        print(f"ok {tid}: {n} ayahs, {size_mb} MB gz  <-  {title}")

    with open(CATALOG, "r", encoding="utf-8") as f:
        catalog = json.load(f)
    existing_ids = {c["id"] for c in catalog["contents"]}
    added = [e for e in new_entries if e["id"] not in existing_ids]
    catalog["contents"].extend(added)
    with open(CATALOG, "w", encoding="utf-8") as f:
        json.dump(catalog, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"catalog: added {len(added)} entries")


if __name__ == "__main__":
    main()

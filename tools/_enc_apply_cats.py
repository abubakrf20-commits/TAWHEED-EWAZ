# -*- coding: utf-8 -*-
"""Add thematic categories to assets/hadeeth_enc.db from crawled mapping."""
import json
import sqlite3
import sys

MAP = json.load(open("tools/_enc_cat_map.json", encoding="utf-8"))
SUBS = {int(k): v for k, v in MAP["subs"].items()}
MAPPING = {int(k): v for k, v in MAP["map"].items()}
MAIN_NAMES = {int(k): v for k, v in MAP["main"].items()}

DB = r"assets\hadeeth_enc.db"

con = sqlite3.connect(DB)
cur = con.cursor()
cols = {r[1] for r in cur.execute("PRAGMA table_info(hadiths)")}
if "category" not in cols:
    cur.execute("ALTER TABLE hadiths ADD COLUMN category TEXT")
if "cat_main" not in cols:
    cur.execute("ALTER TABLE hadiths ADD COLUMN cat_main INTEGER")

updates = []
for hid, m in MAPPING.items():
    sub_name = SUBS[m["sub"]][1]
    updates.append((sub_name, m["main"], hid))
cur.executemany(
    "UPDATE hadiths SET category=?, cat_main=? WHERE id=?", updates)

n_categorized = cur.execute(
    "SELECT COUNT(*) FROM hadiths WHERE category IS NOT NULL").fetchone()[0]
total = cur.execute("SELECT COUNT(*) FROM hadiths").fetchone()[0]

# sanity: distribution
dist = cur.execute(
    "SELECT cat_main, category, COUNT(*) c FROM hadiths "
    "WHERE category IS NOT NULL GROUP BY cat_main, category "
    "ORDER BY c DESC LIMIT 8").fetchall()

cur.execute("DROP INDEX IF EXISTS idx_hadeeth_category")
cur.execute("CREATE INDEX idx_hadeeth_category ON hadiths(category)")
con.commit()
cur.execute("VACUUM")
ok = con.close()

print(f"categorized {n_categorized}/{total}")
print("top categories:", dist)

# verify integrity after vacuum
c2 = sqlite3.connect(DB)
print("integrity:", c2.execute("PRAGMA integrity_check").fetchone()[0])
import os
print("db size:", f"{os.path.getsize(DB):,}")

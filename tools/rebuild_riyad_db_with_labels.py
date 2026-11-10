# -*- coding: utf-8 -*-
"""Bake exact hadith numbering into the standalone riyad database.

Adds two columns to `hadiths` of ryadalsalihin.db:
  is_matn  INTEGER  1 = real numbered narration, 0 = bab intro (muqaddima)
  print_no INTEGER  the book's own printed number (1..1905), 0 for intro

Source of truth = assets/riyad_hadith_labels.json produced by
tools/generate_riyad_labels.py from the 6 source Word volumes.
Result overwrites TAWHEED-EWAZ/riyad/ryadalsalihin.db.gz.

Old app builds simply ignore the new columns; the bundled asset stays as a
fallback, so this is a purely additive upgrade.
"""
import gzip
import json
import os
import shutil
import sqlite3
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GZ = os.path.join(ROOT, "TAWHEED-EWAZ", "riyad", "ryadalsalihin.db.gz")
LABELS = os.path.join(ROOT, "assets", "riyad_hadith_labels.json")
WORK = os.path.join(ROOT, "tools", "_riyad_labels_work.db")


def main():
    with open(LABELS, encoding="utf-8") as f:
        data = json.load(f)
    flags, nums = data["flags"], data["nums"]
    total = len(flags)
    assert total == data["total"] == len(nums)
    n_hadith = sum(flags)

    with gzip.open(GZ, "rb") as fin:
        with open(WORK, "wb") as fout:
            shutil.copyfileobj(fin, fout)

    con = sqlite3.connect(WORK)
    cur = con.cursor()
    cols = {r[1] for r in cur.execute("PRAGMA table_info(hadiths)")}
    if "is_matn" not in cols:
        cur.execute("ALTER TABLE hadiths ADD COLUMN is_matn INTEGER")
    if "print_no" not in cols:
        cur.execute("ALTER TABLE hadiths ADD COLUMN print_no INTEGER")

    updates = [(flags[i], nums[i], i + 1) for i in range(total)]
    cur.executemany(
        "UPDATE hadiths SET is_matn=?, print_no=? "
        "WHERE book_id=18 AND hadith_number=?", updates)

    # ── verification ────────────────────────────────────────────
    n_rows, n_flagged, max_no = cur.execute(
        "SELECT COUNT(*), COALESCE(SUM(is_matn),0), MAX(print_no) "
        "FROM hadiths WHERE book_id=18").fetchone()
    assert n_rows == total, f"row mismatch: {n_rows} != {total}"
    assert n_flagged == n_hadith, f"flagged mismatch: {n_flagged} != {n_hadith}"
    assert max_no == max(nums), f"max print_no mismatch: {max_no}"
    bad = cur.execute(
        "SELECT COUNT(*) FROM hadiths WHERE book_id=18 "
        "AND (is_matn IS NULL OR print_no IS NULL)").fetchone()[0]
    assert bad == 0, f"{bad} rows without labels"
    sample = cur.execute(
        "SELECT hadith_number, is_matn, print_no FROM hadiths "
        "WHERE book_id=18 ORDER BY hadith_number LIMIT 3").fetchall()
    ok = cur.execute("PRAGMA integrity_check").fetchone()[0]
    assert ok == "ok", f"integrity: {ok}"
    con.commit()

    cur.execute("VACUUM")
    con.close()

    out_size = os.path.getsize(WORK)
    with open(WORK, "rb") as fin:
        with gzip.GzipFile(GZ, "wb", compresslevel=9,
                           mtime=0) as fout:  # deterministic output
            shutil.copyfileobj(fin, fout)
    os.remove(WORK)
    gz_size = os.path.getsize(GZ)

    print(f"rows={n_rows} flagged={n_flagged} intro={total - n_hadith} "
          f"max_print_no={max_no}")
    print(f"first rows (no, is_matn, print_no): {sample}")
    print(f"db={out_size:,} B  gz={gz_size:,} B  ->  {GZ}")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()

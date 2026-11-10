#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Optimizes the tafsir/translation SQLite databases for the TAWHEED-EWAZ repo.

Steps per database:
  1. Re-export `contents(sura, ayah, text)` into a fresh database (drops the
     unused `id`/AUTOINCREMENT column and `sqlite_sequence`).    2. Pick the page size (4096/8192/16384) that yields the smallest file.
  3. VACUUM the result.
  4. Write a `.db.gz` (gzip -9) copy — the repo hosts ONLY the `.gz`, and the
     app decompresses it on download (Persian text gzips to 8-25% of its size,
     so this cuts download traffic by ~80-90%).

Usage:  python tools/optimize_quran_dbs.py <src_dir> <out_dir>
  src_dir: folder with the original .db files (e.g. C:\\Users\\...\\TAFSEER)
  out_dir: folder that receives the optimized `.db` + `.db.gz` files
"""
import gzip
import os
import shutil
import sqlite3
import sys

# 16384 is the largest page size guaranteed to be supported by the default
# SQLite build (SQLITE_MAX_PAGE_SIZE defaults to 32768, and the Android
# sqlite3_flutter_libs build does not raise it).
PAGE_SIZES = [4096, 8192, 16384]


def reexport(src_path: str, dst_path: str, page_size: int) -> int:
    src = sqlite3.connect(src_path)
    dst = sqlite3.connect(dst_path)
    try:
        dst.execute(f"PRAGMA page_size = {page_size}")
        dst.execute("PRAGMA journal_mode = OFF")
        dst.execute("PRAGMA synchronous = OFF")
        dst.execute(
            "CREATE TABLE contents (sura INTEGER, ayah INTEGER, text TEXT)"
        )
        rows = src.execute("SELECT sura, ayah, text FROM contents ORDER BY sura, ayah")
        dst.executemany("INSERT INTO contents (sura, ayah, text) VALUES (?, ?, ?)", rows)
        dst.commit()
    finally:
        src.close()
        dst.close()
    # VACUUM to compact after the bulk insert.
    con = sqlite3.connect(dst_path)
    try:
        con.execute("VACUUM")
    finally:
        con.close()
    return os.path.getsize(dst_path)


def verify(path: str, src_path: str) -> None:
    """Spot-check row counts and a few texts against the source DB."""
    src = sqlite3.connect(src_path)
    dst = sqlite3.connect(path)
    try:
        n_src = src.execute("SELECT COUNT(*) FROM contents").fetchone()[0]
        n_dst = dst.execute("SELECT COUNT(*) FROM contents").fetchone()[0]
        assert n_src == n_dst, f"row count mismatch: {n_src} != {n_dst}"
        # Compare a few random-ish rows (first, last, middle).
        for key in [(1, 1), (2, 255), (36, 1), (114, 6)]:
            a = src.execute(
                "SELECT text FROM contents WHERE sura=? AND ayah=?", key
            ).fetchone()
            b = dst.execute(
                "SELECT text FROM contents WHERE sura=? AND ayah=?", key
            ).fetchone()
            assert a == b, f"text mismatch at {key}"
    finally:
        src.close()
        dst.close()
    print(f"    verified: {n_dst} rows, spot-checks OK")


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    src_dir, out_dir = sys.argv[1], sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)

    total_raw = 0
    total_opt = 0
    total_gz = 0
    for name in sorted(os.listdir(src_dir)):
        if not name.lower().endswith(".db"):
            continue
        src_path = os.path.join(src_dir, name)
        raw_size = os.path.getsize(src_path)
        print(f"== {name} (raw {raw_size:,} bytes)")

        best_size = None
        best_ps = None
        for ps in PAGE_SIZES:
            tmp = os.path.join(out_dir, f"_probe_{name}")
            size = reexport(src_path, tmp, ps)
            print(f"    page_size={ps}: {size:,}")
            if best_size is None or size < best_size:
                best_size, best_ps = size, ps
            os.remove(tmp)

        final = os.path.join(out_dir, name)
        reexport(src_path, final, best_ps)
        verify(final, src_path)
        opt_size = os.path.getsize(final)

        gz_path = final + ".gz"
        with open(final, "rb") as fsrc, gzip.open(gz_path, "wb", compresslevel=9) as fdst:
            shutil.copyfileobj(fsrc, fdst)
        gz_size = os.path.getsize(gz_path)

        total_raw += raw_size
        total_opt += opt_size
        total_gz += gz_size
        print(
            f"    -> best page_size={best_ps}  optimized={opt_size:,} "
            f"({opt_size/raw_size*100:.0f}%)  gz={gz_size:,} "
            f"({gz_size/raw_size*100:.0f}%)"
        )

    print(
        f"\nTOTAL: raw={total_raw:,}  optimized={total_opt:,} "
        f"({total_opt/total_raw*100:.0f}%)  gz={total_gz:,} "
        f"({total_gz/total_raw*100:.0f}%)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())

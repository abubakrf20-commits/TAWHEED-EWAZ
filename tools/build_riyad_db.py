# -*- coding: utf-8 -*-
"""Build the standalone ryadalsalihin.db from the merged hadith database.

Reads TAWHEED-EWAZ/hadith/hadith.db.gz (which contains book id 18 =
شرح ریاض الصالحین among the other books), extracts ONLY book 18 into a
fresh database that mirrors the source schema, runs integrity checks,
gzips it to TAWHEED-EWAZ/riyad/ryadalsalihin.db.gz and prints sizes.

Run:  python tools/build_riyad_db.py
"""
import gzip
import os
import shutil
import sqlite3
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_GZ = os.path.join(ROOT, "TAWHEED-EWAZ", "hadith", "hadith.db.gz")
OUT_DIR = os.path.join(ROOT, "TAWHEED-EWAZ", "riyad")
OUT_DB = os.path.join(OUT_DIR, "ryadalsalihin.db")
OUT_GZ = os.path.join(OUT_DIR, "ryadalsalihin.db.gz")

BOOK_ID = 18
EXPECTED_CHAPTERS = 366
EXPECTED_ENTRIES = 2078


def decompress(src_gz: str) -> str:
    tmp_db = os.path.join(tempfile.gettempdir(), "riyad_src_hadith.db")
    if os.path.exists(tmp_db):
        os.remove(tmp_db)
    with gzip.open(src_gz, "rb") as fin, open(tmp_db, "wb") as fout:
        shutil.copyfileobj(fin, fout, length=1 << 20)
    return tmp_db


def table_ddl(src: sqlite3.Connection, name: str) -> str:
    row = src.execute(
        "SELECT sql FROM sqlite_master WHERE type='table' AND name=?",
        (name,),
    ).fetchone()
    if not row:
        raise SystemExit(f"table {name} missing in source db")
    return row[0]


def main() -> None:
    src_path = decompress(SRC_GZ)
    src = sqlite3.connect(src_path)
    try:
        # Sanity: book 18 present in source.
        title = src.execute(
            "SELECT title_arabic FROM books WHERE id=?", (BOOK_ID,)
        ).fetchone()
        assert title and "ریاض" in title[0], f"book {BOOK_ID} missing: {title}"

        if os.path.exists(OUT_DB):
            os.remove(OUT_DB)
        os.makedirs(OUT_DIR, exist_ok=True)
        dst = sqlite3.connect(OUT_DB)
        dst.execute("ATTACH DATABASE ? AS src", (src_path,))

        for table in ("books", "chapters", "hadiths"):
            dst.execute(table_ddl(src, table))

        dst.execute(
            "INSERT INTO books SELECT * FROM src.books WHERE id=?", (BOOK_ID,)
        )
        dst.execute(
            "INSERT INTO chapters SELECT * FROM src.chapters WHERE book_id=?",
            (BOOK_ID,),
        )
        dst.execute(
            """INSERT INTO hadiths
               SELECT h.* FROM src.hadiths h
               JOIN src.chapters c ON h.chapter_id = c.id
               WHERE c.book_id=?""",
            (BOOK_ID,),
        )
        dst.commit()

        # ── Integrity checks ────────────────────────────────────────
        n_books, n_chaps, n_entries = dst.execute(
            "SELECT (SELECT COUNT(*) FROM books),"
            "       (SELECT COUNT(*) FROM chapters),"
            "       (SELECT COUNT(*) FROM hadiths)"
        ).fetchone()
        assert n_books == 1, n_books
        assert n_chaps == EXPECTED_CHAPTERS, f"chapters {n_chaps}"
        assert n_entries == EXPECTED_ENTRIES, f"entries {n_entries}"

        orphans = dst.execute(
            """SELECT COUNT(*) FROM hadiths h
               LEFT JOIN chapters c ON h.chapter_id=c.id WHERE c.id IS NULL"""
        ).fetchone()[0]
        assert orphans == 0, f"{orphans} orphan hadiths"

        empty_chaps = dst.execute(
            "SELECT COUNT(*) FROM chapters c LEFT JOIN hadiths h "
            "ON h.chapter_id=c.id WHERE h.id IS NULL"
        ).fetchone()[0]
        min_no, max_no = dst.execute(
            "SELECT MIN(hadith_number), MAX(hadith_number) FROM hadiths"
        ).fetchone()
        first_bab, last_bab = dst.execute(
            "SELECT name_arabic FROM chapters ORDER BY chapter_index "
            "LIMIT 1"
        ).fetchone()[0], dst.execute(
            "SELECT name_arabic FROM chapters ORDER BY chapter_index DESC "
            "LIMIT 1"
        ).fetchone()[0]
        ic = dst.execute("PRAGMA integrity_check").fetchone()[0]
        assert ic == "ok", ic

        print(f"books=1 chapters={n_chaps} entries={n_entries} "
              f"empty_chapters={empty_chaps}")
        print(f"hadith_number range: {min_no}..{max_no}")
        print(f"first bab: {first_bab}")
        print(f"last bab : {last_bab}")

        sample = dst.execute(
            """SELECT substr(h.arabic,1,80) FROM hadiths h
               JOIN chapters c ON h.chapter_id=c.id
               WHERE c.chapter_index=1 AND h.hadith_number=(
                   SELECT MIN(hadith_number) FROM hadiths h2
                   JOIN chapters c2 ON h2.chapter_id=c2.id
                   WHERE c2.chapter_index=1)"""
        ).fetchone()[0]
        print(f"first matn[:80]: {sample}")

        dst.execute("VACUUM")
        dst.commit()
        dst.close()

        raw_size = os.path.getsize(OUT_DB)
        with open(OUT_DB, "rb") as fin, gzip.GzipFile(
            OUT_GZ, "wb", compresslevel=9
        ) as fout:
            shutil.copyfileobj(fin, fout, length=1 << 20)
        gz_size = os.path.getsize(OUT_GZ)
        print(f"db : {raw_size:,} bytes ({raw_size/1048576:.1f} MiB)")
        print(f"gz : {gz_size:,} bytes ({gz_size/1048576:.1f} MiB)")
    finally:
        src.close()
        if os.path.exists(src_path):
            os.remove(src_path)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()

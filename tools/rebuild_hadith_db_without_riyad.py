# -*- coding: utf-8 -*-
"""Strip book 18 (شرح ریاض الصالحین) out of the shared hadith database.

The riyad section now downloads its own standalone ryadalsalihin.db.gz,
so keeping its ~8 MB of text inside hadith.db.gz just bloats the کتب حدیث
download. This script removes book 18 from a copy of the hosted database,
verifies that every remaining book keeps all its rows, regenerates
TAWHEED-EWAZ/hadith/hadith.db.gz and prints before/after sizes.

Run:  python tools/rebuild_hadith_db_without_riyad.py
"""
import gzip
import os
import shutil
import sqlite3
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GZ_PATH = os.path.join(ROOT, "TAWHEED-EWAZ", "hadith", "hadith.db.gz")

BOOK_ID = 18
EXPECTED_RIYAD_CHAPTERS = 366
EXPECTED_RIYAD_ENTRIES = 2078


def main() -> None:
    tmp_db = os.path.join(tempfile.gettempdir(), "hadith_strip_riyad.db")
    if os.path.exists(tmp_db):
        os.remove(tmp_db)
    with gzip.open(GZ_PATH, "rb") as fin, open(tmp_db, "wb") as fout:
        shutil.copyfileobj(fin, fout, length=1 << 20)

    old_gz_size = os.path.getsize(GZ_PATH)
    db = sqlite3.connect(tmp_db)
    try:
        before_books, before_chaps, before_entries = db.execute(
            "SELECT (SELECT COUNT(*) FROM books),"
            "       (SELECT COUNT(*) FROM chapters),"
            "       (SELECT COUNT(*) FROM hadiths)"
        ).fetchone()

        riyad_chaps, riyad_entries = db.execute(
            "SELECT (SELECT COUNT(*) FROM chapters WHERE book_id=?),"
            "       (SELECT COUNT(*) FROM hadiths WHERE book_id=?)",
            (BOOK_ID, BOOK_ID),
        ).fetchone()
        assert riyad_chaps == EXPECTED_RIYAD_CHAPTERS, riyad_chaps
        assert riyad_entries == EXPECTED_RIYAD_ENTRIES, riyad_entries

        # Per-book snapshot so we can prove nobody else lost a row.
        snapshot_before = dict(db.execute(
            "SELECT b.id,"
            "       (SELECT COUNT(*) FROM hadiths h WHERE h.book_id=b.id)"
            " FROM books b WHERE b.id != ?", (BOOK_ID,)))

        db.execute("DELETE FROM hadiths WHERE book_id=?", (BOOK_ID,))
        db.execute("DELETE FROM chapters WHERE book_id=?", (BOOK_ID,))
        db.execute("DELETE FROM books WHERE id=?", (BOOK_ID,))
        db.commit()

        after_books, after_chaps, after_entries = db.execute(
            "SELECT (SELECT COUNT(*) FROM books),"
            "       (SELECT COUNT(*) FROM chapters),"
            "       (SELECT COUNT(*) FROM hadiths)"
        ).fetchone()

        assert after_books == before_books - 1
        assert after_chaps == before_chaps - EXPECTED_RIYAD_CHAPTERS
        assert after_entries == before_entries - EXPECTED_RIYAD_ENTRIES

        snapshot_after = dict(db.execute(
            "SELECT b.id,"
            "       (SELECT COUNT(*) FROM hadiths h WHERE h.book_id=b.id)"
            " FROM books b"))
        assert snapshot_before == snapshot_after, "another book changed!"

        orphans = db.execute(
            """SELECT COUNT(*) FROM hadiths h
               LEFT JOIN chapters c ON h.chapter_id=c.id WHERE c.id IS NULL"""
        ).fetchone()[0]
        assert orphans == 0, f"{orphans} orphan hadiths"

        assert BOOK_ID not in snapshot_after
        ic = db.execute("PRAGMA integrity_check").fetchone()[0]
        assert ic == "ok", ic
        print(f"books {before_books}->{after_books}, "
              f"chapters {before_chaps}->{after_chaps}, "
              f"hadiths {before_entries}->{after_entries}")
        print(f"remaining book ids: {sorted(snapshot_after)}")

        db.execute("VACUUM")
        db.commit()
    finally:
        db.close()

    with open(tmp_db, "rb") as fin, gzip.GzipFile(
        GZ_PATH + ".tmp", "wb", compresslevel=9
    ) as fout:
        shutil.copyfileobj(fin, fout, length=1 << 20)
    os.replace(GZ_PATH + ".tmp", GZ_PATH)
    os.remove(tmp_db)

    new_gz_size = os.path.getsize(GZ_PATH)
    print(f"gz: {old_gz_size:,} -> {new_gz_size:,} bytes "
          f"({old_gz_size/1048576:.1f} -> {new_gz_size/1048576:.1f} MiB)")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()

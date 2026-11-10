"""
Convert hadith-json-main data to SQLite database for Flutter app.
Run: python tools/hadith_to_sqlite.py

Input:  hadith-json-main/db/by_book/**/*.json
Output: assets/hadith.db
"""

import os
import json
import sqlite3
import sys

BASE_DIR = os.path.join(os.path.dirname(__file__), '..', 'hadith-json-main', 'db', 'by_book')
OUTPUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'hadith.db')

# Book metadata (from books.ts)
BOOKS = [
    (1, "صحيح البخاري", "Sahih al-Bukhari", "the_9_books/bukhari.json", 7563),
    (2, "صحيح مسلم", "Sahih Muslim", "the_9_books/muslim.json", 3033),
    (3, "سنن النسائي", "Sunan al-Nasa'i", "the_9_books/nasai.json", 5758),
    (4, "سنن أبي داود", "Sunan Abi Dawud", "the_9_books/abudawud.json", 5274),
    (5, "جامع الترمذي", "Jami' al-Tirmidhi", "the_9_books/tirmidhi.json", 3956),
    (6, "سنن ابن ماجه", "Sunan Ibn Majah", "the_9_books/ibnmajah.json", 4341),
    (7, "موطأ مالك", "Muwatta Malik", "the_9_books/malik.json", 1862),
    (8, "مسند الإمام أحمد", "Musnad Ahmad", "the_9_books/ahmed.json", 1438),
    (9, "سنن الدارمي", "Sunan al-Darimi", "the_9_books/darimi.json", 3406),
    (10, "الأربعون النووية", "Forty Hadith of Nawawi", "forties/nawawi40.json", 42),
    (11, "الأربعون القدسية", "Forty Hadith Qudsi", "forties/qudsi40.json", 40),
    (12, "أربعون الدهلوي", "Forty Hadith of Shah Waliullah", "forties/shahwaliullah40.json", 40),
    (13, "رياض الصالحين", "Riyad as-Salihin", "other_books/riyad_assalihin.json", 1869),
    (14, "مشكاة المصابيح", "Mishkat al-Masabih", "other_books/mishkat_almasabih.json", 4627),
    (15, "الأدب المفرد", "Al-Adab Al-Mufrad", "other_books/aladab_almufrad.json", 1322),
    (16, "الشمائل المحمدية", "Shama'il Muhammadiyah", "other_books/shamail_muhammadiyah.json", 417),
    (17, "بلوغ المرام", "Bulugh al-Maram", "other_books/bulugh_almaram.json", 1432),
]


def create_db():
    if os.path.exists(OUTPUT):
        os.remove(OUTPUT)

    db = sqlite3.connect(OUTPUT)
    db.executescript("""
        PRAGMA journal_mode = WAL;
        PRAGMA encoding = 'UTF-8';

        CREATE TABLE books (
            id INTEGER PRIMARY KEY,
            title_arabic TEXT NOT NULL,
            title_english TEXT NOT NULL,
            hadith_count INTEGER
        );

        CREATE TABLE chapters (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            book_id INTEGER NOT NULL,
            chapter_index INTEGER,
            name_arabic TEXT,
            name_english TEXT,
            FOREIGN KEY (book_id) REFERENCES books(id)
        );

        CREATE TABLE hadiths (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            book_id INTEGER NOT NULL,
            hadith_number INTEGER,
            chapter_id INTEGER,
            arabic TEXT NOT NULL,
            narrator_english TEXT,
            text_english TEXT,
            FOREIGN KEY (book_id) REFERENCES books(id)
        );

        CREATE INDEX idx_hadiths_book ON hadiths(book_id);
        CREATE INDEX idx_hadiths_chapter ON hadiths(chapter_id);
        CREATE INDEX idx_chapters_book ON chapters(book_id);
    """)
    return db


def process_book(db, book_id, title_ar, title_en, filename, expected_count):
    filepath = os.path.join(BASE_DIR, filename)
    if not os.path.exists(filepath):
        print(f"  SKIP: {filename} not found")
        return 0

    with open(filepath, 'r', encoding='utf-8') as f:
        data = json.load(f)

    # Insert book
    db.execute(
        "INSERT INTO books (id, title_arabic, title_english, hadith_count) VALUES (?, ?, ?, ?)",
        (book_id, title_ar, title_en, expected_count)
    )

    # Insert chapters
    chapters = data.get('chapters', [])
    chapter_map = {}
    for ch in chapters:
        ch_id = ch.get('id', 0)
        name_ar = ch.get('arabic', '')
        name_en = ch.get('english', '')
        cursor = db.execute(
            "INSERT INTO chapters (book_id, chapter_index, name_arabic, name_english) VALUES (?, ?, ?, ?)",
            (book_id, ch_id, name_ar, name_en)
        )
        chapter_map[ch_id] = cursor.lastrowid

    # Insert hadiths
    hadiths = data.get('hadiths', [])
    count = 0
    for h in hadiths:
        chapter_idx = h.get('chapterId', 0)
        chapter_db_id = chapter_map.get(chapter_idx)

        english = h.get('english', {})
        narrator = english.get('narrator', '') if isinstance(english, dict) else ''
        text_en = english.get('text', '') if isinstance(english, dict) else ''

        db.execute(
            "INSERT INTO hadiths (book_id, hadith_number, chapter_id, arabic, narrator_english, text_english) VALUES (?, ?, ?, ?, ?, ?)",
            (
                book_id,
                h.get('idInBook', h.get('id', 0)),
                chapter_db_id,
                h.get('arabic', ''),
                narrator.strip(),
                text_en.strip(),
            )
        )
        count += 1

    return count


def main():
    print("=" * 50)
    print("  Hadith JSON → SQLite Converter")
    print("=" * 50)

    db = create_db()
    total = 0

    for book_id, title_ar, title_en, filename, expected in BOOKS:
        sys.stdout.write(f"\r  {title_en}...")
        sys.stdout.flush()
        count = process_book(db, book_id, title_ar, title_en, filename, expected)
        total += count

    db.commit()

    # Print stats
    print(f"\n\n{'=' * 50}")
    print(f"  DONE!")
    for row in db.execute("SELECT b.title_english, COUNT(h.id) FROM books b LEFT JOIN hadiths h ON h.book_id = b.id GROUP BY b.id"):
        print(f"    {row[0]}: {row[1]} hadiths")
    print(f"\n  Total hadiths: {total}")
    size_mb = os.path.getsize(OUTPUT) / (1024 * 1024)
    print(f"  Database size: {size_mb:.1f} MB")
    print(f"  Output: {OUTPUT}")
    print(f"{'=' * 50}")

    db.close()


if __name__ == '__main__':
    main()

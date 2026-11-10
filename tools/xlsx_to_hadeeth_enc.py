"""
Convert the HadeethEnc.com Persian Excel dump into a bundled SQLite
database for the Flutter app (موسوعه احادیث).

Run: python tools/xlsx_to_hadeeth_enc.py

Input : HadeethEnc.com_fa-v1.30.0 (1).xlsx  (official Persian download)
Output: assets/hadeeth_enc.db
"""

import os
import re
import sqlite3

import openpyxl

BASE_DIR = os.path.dirname(__file__)
PROJECT_DIR = os.path.dirname(BASE_DIR)
INPUT = os.path.join(
    PROJECT_DIR, '_archive', 'HadeethEnc.com_fa-v1.30.0 (1).xlsx')
OUTPUT = os.path.join(PROJECT_DIR, 'assets', 'hadeeth_enc.db')

# Excel headers -> database columns (Persian/display columns kept,
# redundant `*_ar` explanation/benefit columns dropped).
COLUMN_MAP = {
    'id': 'id',
    'title_ar': 'title_ar',
    'title': 'title',
    'hadith_text_ar': 'text_ar',
    'hadith_text': 'text',
    'explanation': 'explanation',
    'benefits': 'benefits',
    'grade': 'grade',
    'takhrij': 'takhrij',
    'link': 'link',
}

DROPPED = {'explanation_ar', 'benefits_ar', 'grade_ar', 'takhrij_ar', 'lang'}


def clean(value):
    if value is None:
        return None
    text = str(value)
    # Remove any null / control characters (keeps \n which separates
    # benefits/explanation bullets).
    text = text.replace('\x00', '')
    text = re.sub(r'[\x01-\x08\x0b\x0c\x0e-\x1f]', '', text)
    text = text.strip()
    return text if text else None


def main():
    if not os.path.exists(INPUT):
        print(f'ERROR: input not found: {INPUT}')
        return 1

    wb = openpyxl.load_workbook(INPUT, read_only=True)
    ws = wb['Worksheet']
    rows = ws.iter_rows(values_only=True)

    # Row 1 is a comment block, row 2 is the header row.
    header = next(rows)
    while header is None or (header[0] is None) or header[0] == '#' or 'id' not in header:
        header = next(rows)

    index = {name: i for i, name in enumerate(header)}

    if os.path.exists(OUTPUT):
        os.remove(OUTPUT)

    db = sqlite3.connect(OUTPUT)
    db.executescript('''
        PRAGMA journal_mode = OFF;
        PRAGMA encoding = 'UTF-8';
        PRAGMA synchronous = OFF;

        CREATE TABLE hadiths (
            id INTEGER PRIMARY KEY,
            title_ar TEXT,
            title TEXT,
            text_ar TEXT,
            text TEXT,
            explanation TEXT,
            benefits TEXT,
            grade TEXT,
            takhrij TEXT,
            link TEXT
        );

        CREATE INDEX idx_hadeeth_title ON hadiths(title);
        CREATE INDEX idx_hadeeth_grade ON hadiths(grade);
    ''')

    columns = [COLUMN_MAP[h] for h in header if h in COLUMN_MAP]
    placeholders = ','.join('?' for _ in columns)
    insert = (f'INSERT INTO hadiths ({",".join(columns)}) '
              f'VALUES ({placeholders})')

    count = 0
    for row in rows:
        if not row or row[0] is None:
            continue
        values = [clean(row[index[h]]) for h in header if h in COLUMN_MAP]
        if values[0] is None:
            continue
        try:
            db.execute(insert, values)
            count += 1
        except sqlite3.IntegrityError as e:
            print(f'  SKIP id {values[0]}: {e}')

    db.commit()
    db.execute('ANALYZE')

    stats = {}
    for col in ('title_ar', 'title', 'text_ar', 'text', 'explanation',
                'benefits', 'grade', 'takhrij'):
        stats[col] = db.execute(
            f'SELECT COUNT(*) FROM hadiths WHERE {col} IS NOT NULL').fetchone()[0]

    db.close()
    wb.close()

    size_mb = os.path.getsize(OUTPUT) / (1024 * 1024)
    print('=' * 50)
    print(f'  Converted: {count} hadiths -> {OUTPUT}')
    print(f'  Size: {size_mb:.2f} MB')
    for col, n in stats.items():
        print(f'    {col}: {n}')
    print('=' * 50)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
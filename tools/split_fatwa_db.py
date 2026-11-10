#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Splits the stored fatwa `answer` field into full_question + clean answer.

The IslamPP entries keep a short title in `question`, but the `answer` field
repeats the full question and then begins the real reply with a «جواب»/
«الحمد لله» marker. This migration adds a nullable `full_question` column and
rewrites `answer` to hold only the actual reply, so the app no longer needs to
parse it at render time.

The split logic MUST match `FatwaService.splitFatwa` in
lib/features/fatwa/services/fatwa_service.dart.

Usage:
  python tools/split_fatwa_db.py --src <fatwas.db> [--out-dir TAWHEED-EWAZ/fatwa]
"""
import argparse
import gzip
import re
import sqlite3
import sys
from pathlib import Path

# Trailing punctuation removed from the extracted full question (keeps ؟).
_TRAIL = re.compile(r'[،,:. ]+$')
# Leading reply boilerplate: optional «جواب…» then «الحمد لله»،.
_BOILER = re.compile(r'^(?:جواب[^\nالحمد]{0,20})?\s*(?:الحمد\s*لله[،,.\s]*)?')


def split_fatwa(answer: str):
    answers = []
    i = answer.find('جواب')
    if i >= 0:
        answers.append(i)
    i = answer.find('الحمد لله')
    if i >= 0:
        answers.append(i)
    i = answer.find('الحمدلله')
    if i >= 0:
        answers.append(i)
    if not answers:
        return None, answer.strip()

    boundary = min(answers)
    q = _TRAIL.sub('', answer[:boundary].strip())
    rest = answer[boundary:].strip()
    cleaned = _BOILER.sub('', rest).strip()
    if not cleaned:
        cleaned = rest
    return (q if q else None), cleaned


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--src', required=True, help='Path to current fatwas.db')
    ap.add_argument('--out-dir', default='TAWHEED-EWAZ/fatwa')
    args = ap.parse_args()

    src = Path(args.src)
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    con = sqlite3.connect(str(src))
    rows = con.execute('SELECT id, question, answer, category, q_norm, '
                       'search_norm FROM fatwas ORDER BY id').fetchall()
    con.close()

    entries = []
    no_full = 0
    for rid, q, a, cat, qn, sn in rows:
        fq, ans = split_fatwa(a)
        if fq is None:
            no_full += 1
        entries.append((rid, q, fq, ans, cat, qn, sn))

    db_path = out_dir / 'fatwas.db'
    if db_path.exists():
        db_path.unlink()
    dst = sqlite3.connect(str(db_path))
    dst.execute('CREATE TABLE fatwas ('
                'id INTEGER PRIMARY KEY, '
                'question TEXT NOT NULL, '
                'full_question TEXT, '
                'answer TEXT NOT NULL, '
                'category TEXT NOT NULL, '
                'q_norm TEXT NOT NULL, '
                'search_norm TEXT NOT NULL)')
    dst.execute('CREATE INDEX idx_fatwas_category ON fatwas(category)')
    dst.executemany(
        'INSERT INTO fatwas VALUES (?,?,?,?,?,?,?)', entries)
    dst.commit()
    dst.isolation_level = None
    dst.execute('VACUUM')
    dst.close()

    gz_path = out_dir / 'fatwas.db.gz'
    raw = db_path.read_bytes()
    with open(gz_path, 'wb') as f:
        f.write(gzip.compress(raw, 9))

    print(f'entries: {len(entries)} (no full_question: {no_full})')
    print(f'db: {db_path} ({len(raw):,} bytes), '
          f'gz: {gz_path} ({gz_path.stat().st_size:,} bytes)')
    return 0


if __name__ == '__main__':
    sys.exit(main())

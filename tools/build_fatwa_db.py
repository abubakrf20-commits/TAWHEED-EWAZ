#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Builds TAWHEED-EWAZ/fatwa/fatwas.db from the IslamPP APK database.

Usage:
  python tools/build_fatwa_db.py --src <path-to-islampp.db> [--out TAWHEED-EWAZ/fatwa]

The source is the `questions` table inside assets/databases/islampp.db of the
islampp-v2.0.apk (9,086 Persian Q&A fatwas, Ahl al-Sunnah wal-Jamaat).
Steps: clean whitespace boilerplate → auto-categorize by keyword rules →
bake search-normalized columns (same pipeline as FatwaService in Dart) →
write sqlite + gzip.
"""
import argparse
import io
import sys as _sys
import gzip
import re
import sqlite3
import sys
from pathlib import Path

# ── Text normalization — MUST match lib/features/fatwa/services/fatwa_service.dart
TASHKEEL = re.compile(r'[\u064B-\u065F\u0670\u0640]')


def normalize(s: str) -> str:
    out = []
    for ch in s:
        o = TASHKEEL.sub('', ch)
        # Zero-width non-joiner / joiner: the reader cannot see them, so they
        # must not decide whether a search matches. Kept in sync with
        # `FatwaService.normalizeText` in the Dart app.
        if o in ('\u200c', '\u200d'):
            continue
        if o in ('أ', 'إ', 'آ', 'ٱ'):
            o = 'ا'
        elif o == 'ة':
            o = 'ه'
        elif o == 'ى' or o == '\u06cc':  # arabic ya + persian ye
            o = 'ي'
        elif o == 'ؤ':
            o = 'و'
        elif o == 'ئ':
            o = 'ي'
        elif o == '\u06a9':  # persian kaf
            o = 'ك'
        out.append(o.lower())
    return ''.join(out)


def clean(s: str) -> str:
    s = str(s)
    s = s.replace('\r\n', '\n').replace('\r', '\n')
    lines = []
    for ln in s.split('\n'):
        ln = re.sub(r'[ \t]+', ' ', ln).strip()
        if not ln:
            continue
        # strip site footer boilerplate
        if 'IslamPP.Com' in ln or 'islampp.com' in ln.lower():
            continue
        if ln == 'سایت جامع فتاوای اهل سنت و جماعت':
            continue
        lines.append(ln)
    # collapse repeated blank structure into single newlines
    text = '\n'.join(lines)
    return text.strip()


# ── Auto-categorization (ordered rules; first hit wins) ──────────────
CATEGORIES = [
    ('ارث و وصیت', ['ارث', 'میراث', 'وصیت']),
    ('جهاد', ['جهاد', 'دشمن اسلام']),
    ('قرآن و تلاوت', ['قرآن', 'مصحف', 'تلاوت', 'ختم قرآن', 'ترجمه قرآن']),
    ('دعا، استخاره و رقیه', ['استخاره', 'رقیه', 'تعویذ', 'طلسم',
                              'دعای ', 'اذکار']),
    ('حج، عمره و قربانی', ['حج', 'عمره', 'احرام', 'طواف', 'سعی',
                            'عرفات', 'منا', 'قربانی', 'عقیقه', 'ذبح',
                            'کفاره']),
    ('روزه و رمضان', ['روزه', 'افطار', 'سحری', 'رمضان', 'اعتکاف',
                       'شعبان']),
    ('زکات و صدقه', ['زکات', 'زکوه', 'فطره', 'خمس', 'صدقه', 'انفاق',
                      'وقف']),
    ('طلاق و احوال شخصیه', ['طلاق', 'عدت', 'لعان', 'ظهار', 'ایلاء',
                             'خلع']),
    ('ازدواج و خانواده', ['ازدواج', 'نکاح', 'عقد ', 'مهریه', ' مهر ',
                           'خواستگاری', 'محرم', 'رضاع', 'شیردادن',
                           'حق شوهر', 'نفقه', 'همسر', 'شوهر', 'زوجه',
                           'چند زن', 'حق زن', 'فرزند', 'بچه', 'تربیت',
                           'والدین']),
    ('حجاب و پوشش', ['حجاب', 'پوشش', 'چادر', 'برقع', 'نقاب', 'صورتی',
                      'آرایش', 'بدن زن']),
    ('معاملات و امور مالی', ['خرید', 'فروش', 'بیع', 'بایع', 'قرض',
                              ' طلب', 'ربا', 'سود بانک', 'اجاره',
                              'کرایه', 'شرکت', 'ضمان', 'کفالت', 'حواله',
                              ' چک', 'سفته', 'رهن', 'گرو ', 'تجارت',
                              'دستمزد', 'اجرت', 'بیمه', 'قمار',
                              'بخت آزمایی', 'قرعه کشی', 'طلا ',
                              'پول', 'مال ']),
    ('خوراک و پوشیدنی', ['گوشت', 'خوک', 'الکل', 'خمر', 'شراب',
                          'مواد مخدر', 'سیگار', 'قلیان', 'اهل کتاب',
                          'ماهی', 'ملخ', 'حیوان', 'پشم', 'ابریشم',
                          'طلای زن']),
    ('طهارت', ['وضو', 'غسل', 'تیمم', 'جنابت', 'احتلام', 'حیض',
                'نفاس', 'استحاضه', 'نجاست', 'مس کردن قرآن', 'پاکی',
                'مستحاضه']),
    ('اخلاق و معاشرت', ['دروغ', 'غیبت', 'تهمت', 'نمیمه', 'حسادت',
                         'کینه', 'آزار', 'اذیت', 'همسایه', 'صله رحم',
                         'سلام ', 'سوگند', ' قسم', 'نذر', 'فحش',
                         'دشنام', 'شوخی', 'مسخره', 'خودکشی',
                         'خوش اخلاق', 'لبخند', 'پدر', 'مادر']),
    ('نماز و مسجد', ['نماز', 'اذان', 'اقامه', 'جماعت', 'قنوت', 'سجده',
                      'رکوع', 'تشهد', 'مسجد', 'قبله', 'جنازه',
                      'نماز میت', 'تسبیحات', 'قضا ', 'امام ']),
    ('عقاید', ['ایمان', 'کفر', 'شرک', 'توحید', 'بت ', 'توسل',
                'بدعت', 'مرتد', 'تکفیر', 'قدری', 'جبر', 'روح',
                'برزخ', 'معاد', 'عذاب قبر', 'شفاعت', 'خوارج',
                'شیعه', 'بهایی', 'قادیانی', 'وهابی', 'طاغوت',
                'دموکراسی', 'رای دادن', 'انتخابات']),
]


def categorize(text: str) -> str:
    for cat, keys in CATEGORIES:
        for k in keys:
            if k in text:
                return cat
    return 'سایر مسائل'


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--src', required=True,
                    help='Path to extracted islampp.db')
    ap.add_argument('--out-dir', default='TAWHEED-EWAZ/fatwa')
    args = ap.parse_args()

    src = Path(args.src)
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    con = sqlite3.connect(str(src))
    rows = con.execute(
        'SELECT id, question, answer FROM questions ORDER BY id').fetchall()
    con.close()

    entries = []
    for rid, q, a in rows:
        q_c, a_c = clean(q), clean(a)
        if not q_c or not a_c:
            continue
        cat = categorize(f'{q_c}\n{a_c[:4000]}')
        entries.append((rid, q_c, a_c, cat,
                        normalize(q_c),
                        normalize(q_c + chr(10) + a_c)))

    db_path = out_dir / 'fatwas.db'
    if db_path.exists():
        db_path.unlink()
    dst = sqlite3.connect(str(db_path))
    dst.execute('CREATE TABLE fatwas ('
                'id INTEGER PRIMARY KEY, '
                'question TEXT NOT NULL, '
                'answer TEXT NOT NULL, '
                'category TEXT NOT NULL, '
                'q_norm TEXT NOT NULL, '
                'search_norm TEXT NOT NULL)')
    dst.execute('CREATE INDEX idx_fatwas_category ON fatwas(category)')
    dst.executemany('INSERT INTO fatwas VALUES (?,?,?,?,?,?)', entries)
    dst.commit()
    dst.isolation_level = None
    dst.execute('VACUUM')
    dst.close()

    gz_path = out_dir / 'fatwas.db.gz'
    raw = db_path.read_bytes()
    with open(gz_path, 'wb') as f:
        f.write(gzip.compress(raw, 9))

    cats = {}
    for e in entries:
        cats[e[3]] = cats.get(e[3], 0) + 1
    print(f'entries: {len(entries)}')
    print(f'db: {db_path} ({len(raw):,} bytes), '
          f'gz: {gz_path} ({gz_path.stat().st_size:,} bytes)')
    for c, n in sorted(cats.items(), key=lambda kv: -kv[1]):
        print(f'  {c}: {n}')
    return 0


if __name__ == '__main__':
    _sys.stdout = io.TextIOWrapper(_sys.stdout.buffer,
                                   encoding='utf-8', errors='replace')
    sys.exit(main())

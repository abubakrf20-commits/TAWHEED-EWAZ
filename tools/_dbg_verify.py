import gzip
import os
import re
import shutil
import sqlite3
import sys

sys.stdout.reconfigure(encoding="utf-8")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
gz = os.path.join(ROOT, "TAWHEED-EWAZ", "hadith", "hadith.db.gz")
tmp = os.path.join(ROOT, "tools", "_verify.db")
with gzip.open(gz, "rb") as fin, open(tmp, "wb") as fout:
    shutil.copyfileobj(fin, fout)
con = sqlite3.connect(tmp)
con.create_function("REGEXP", 2,
                    lambda p, s: 1 if re.search(p, s or "") else 0)
cur = con.cursor()

cur.execute("SELECT id,title_arabic,hadith_count FROM books WHERE id=18")
print("book:", cur.fetchone())
cur.execute("""SELECT COUNT(*) FROM chapters c LEFT JOIN books b
               ON c.book_id=b.id WHERE b.id=18""")
print("chapters:", cur.fetchone()[0])

# 1) leftover publisher text / symbols
for pat, label in [(r"mowahedin|aqeedeh|نظارت علمی|گروه علمی فرهنگی",
                    "publisher leftovers"),
                   (r"[$&#@%~*_|=^`]", "stray symbols")]:
    cur.execute("SELECT COUNT(*), MAX(hadith_number) FROM hadiths "
                "WHERE book_id=18 AND arabic REGEXP ?", (pat,))
    n, mx = cur.fetchone()
    print(f"{label}: {n} rows (max hadith_number={mx})")

# 2) suspicious mid-text numbered lines (possible missed splits)
cur.execute("SELECT hadith_number, arabic FROM hadiths WHERE book_id=18")
sus = []
line_re = re.compile(r"^(\d{2,4})\s*[-–]\s*\S", re.M)
for hid, txt in cur.fetchall():
    for m in line_re.finditer(txt):
        num = int(m.group(1))
        if num >= 30:
            sus.append((hid, num, txt[m.start():m.start() + 70]))
print(f"suspect mid-text numbered lines (>=30): {len(sus)}")
for s in sus[:12]:
    print("   ", s)

# 3) spot checks
def show(ch_idx, k=0, head=340):
    cur.execute("""SELECT h.hadith_number, h.arabic FROM hadiths h
                   JOIN chapters c ON h.chapter_id=c.id
                   WHERE c.book_id=18 AND c.chapter_index=? 
                   ORDER BY h.hadith_number LIMIT 1 OFFSET ?""", (ch_idx, k))
    row = cur.fetchone()
    if row:
        print(f"\n--- bab {ch_idx} entry#{k + 1} (global #{row[0]}) ---")
        print(row[1][:head])

show(186, 0)   # اذان -> expect matn 1040
show(253, 0)   # کرامات -> unnumbered segment
show(253, 1)
show(1, 1)     # real hadith 1 of bab 1
show(366, -1 if False else 0)

# 4) tiny/empty entries
cur.execute("""SELECT h.hadith_number, LENGTH(h.arabic), substr(h.arabic,1,80)
               FROM hadiths h WHERE h.book_id=18 AND LENGTH(h.arabic)<60""")
rows = cur.fetchall()
print(f"\ntiny entries: {len(rows)}")
for r in rows[:10]:
    print("   ", r)

cur.execute("""SELECT COUNT(*) FROM hadiths h JOIN chapters c ON h.chapter_id=c.id
               WHERE c.book_id=18 AND h.arabic LIKE 'ترجمه:%'""")
print("entries starting directly with ترجمه:", cur.fetchone()[0])

con.close()
os.remove(tmp)
